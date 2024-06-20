include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gr UNLOAD='UNLOAD'
declare -gA options_values

declare -g SYSFS_CLASS_DRM='/sys/class/drm'

function drm_main()
{
  local target
  local gui_on
  local gui_off
  local gui_on_after_reboot
  local gui_off_after_reboot
  local conn_available
  local remote
  local load_module
  local unload_module
  local test_mode
  local flag

  if [[ "$*" =~ -h|--help ]]; then
    drm_help "$*"
    exit 0
  fi

  parse_drm_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']} ${target} ${gui_on} ${gui_off} ${remote_parameters['REMOTE_IP']} ${remote_parameters['REMOTE_PORT']}"
    drm_help
    return 22 # EINVAL
  fi

  target="${options_values['TARGET']}"
  gui_on="${options_values['GUI_ON']}"
  gui_off="${options_values['GUI_OFF']}"
  gui_on_after_reboot="${options_values['GUI_ON_AFTER_REBOOT']}"
  gui_off_after_reboot="${options_values['GUI_OFF_AFTER_REBOOT']}"
  conn_available="${options_values['CONN_AVAILABLE']}"
  modes_available="${options_values['MODES_AVAILABLE']}"
  help_opt="${options_values['HELP']}"
  test_mode="${options_values['TEST_MODE']}"
  load_module="${options_values['LOAD_MODULE']}"
  unload_module="${options_values['UNLOAD_MODULE']}"
  remote="${remote_parameters['REMOTE']}"

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  if [[ "$target" == "$REMOTE_TARGET" ]]; then
    # Check connection before try to work with remote
    is_ssh_connection_configured "$flag"
    if [[ "$?" != 0 ]]; then
      ssh_connection_failure_message
      exit 101 # ENETUNREACH
    fi
  fi

  if [[ -n "$load_module" ]]; then
    module_control 'LOAD' "$target" "$remote" "$load_module" "$flag"
    if [[ "$?" != 0 ]]; then
      return 22 # EINVAL
    fi
  fi

  if [[ "$gui_on" == 1 ]]; then
    gui_control 'ON' "$target" "$remote" "$flag"
  elif [[ "$gui_off" == 1 ]]; then
    gui_control 'OFF' "$target" "$remote" "$flag"
  elif [[ "$gui_on_after_reboot" == 1 ]]; then
    gui_control 'ON_AFTER_REBOOT' "$target" "$remote" "$flag"
  elif [[ "$gui_off_after_reboot" == 1 ]]; then
    gui_control 'OFF_AFTER_REBOOT' "$target" "$remote" "$flag"
  fi

  if [[ -n "$unload_module" ]]; then
    # For unload DRM drivers, we need to make sure that we turn off user GUI
    [[ "$gui_off" != 1 ]] && gui_control 'OFF' "$target" "$remote"
    module_control 'UNLOAD' "$target" "$remote" "$unload_module" "$flag"
  fi

  if [[ "$conn_available" == 1 ]]; then
    get_available_connectors "$target" "$remote" "$flag"
  fi

  if [[ "$modes_available" == 1 ]]; then
    get_supported_mode_per_connector "$target" "$remote" "$flag"
  fi

  if [[ "$help_opt" == 1 ]]; then
    drm_help
  fi
}

# This function is responsible for handling modules load and unload operations.
#
# @operations The operation can be LOAD for loading a module or UNLOAD to
#             remove it.
# @target Target can be LOCAL_TARGET, and REMOTE_TARGET.
# @unformatted_remote It is the remote location formatted as REMOTE:PORT.
# @parameters String passed via --[un]load-module=
# @flag How to display a command, see `src/lib/kwlib.sh` function `cmd_manager`.
function module_control()
{
  local operation="$1"
  local target="$2"
  local unformatted_remote="$3"
  local parameters="$4"
  local flag="$5"
  local module_cmd=''
  local remote
  local port

  flag=${flag:-'SILENT'}

  module_cmd=$(convert_module_info "$operation" "$parameters")
  if [[ "$?" != 0 ]]; then
    complain 'Wrong parameter in --[un]load-module='
    return 22 # EINVAL
  fi

  case "$target" in
    2) # LOCAL
      cmd_manager "$flag" "sudo bash -c \"${module_cmd}\""
      ;;
    3) # REMOTE
      remote=$(get_based_on_delimiter "$unformatted_remote" ':' 1)
      port=$(get_based_on_delimiter "$unformatted_remote" ':' 2)

      cmd_remotely "$flag" "$module_cmd" "$remote" "$port"
      ;;
  esac
}

# Convert user input (syntax) to a modprobe command
#
# @unload Request module removal if it is set to UNLOAD.
# @raw_modules_str User input string
#
# Returns:
# Return a string with the modprobe command assembled. In case of error return
# an errno code.
function convert_module_info()
{
  local unload="$1"
  shift
  local raw_modules_str="$*"
  local parameters_str=''
  local final_command=''
  local remove_flag=''
  local module_str=''
  local first_time=1

  if [[ "$unload" == "$UNLOAD" ]]; then
    remove_flag='-r'
  else
    remove_flag=''
  fi

  IFS=';' read -r -a modules <<< "$raw_modules_str"
  # Target event. e.g.: amdgpu_dm or amdgpu
  for module in "${modules[@]}"; do
    parameters_str=''
    module_str="modprobe ${remove_flag} ${module}"

    if [[ "$module" =~ .*':'.* ]]; then
      module_str="modprobe ${remove_flag} "
      module_str+=$(cut --delimiter=':' --fields=1 <<< "$module")

      if [[ "$unload" != "$UNLOAD" ]]; then
        # Capture module parameters
        specific_parameters_str=$(cut --delimiter=':' --fields=2 <<< "$module")
        IFS=',' read -r -a parameters_array <<< "$specific_parameters_str"
        for specific_parameter in "${parameters_array[@]}"; do
          parameters_str+="$specific_parameter "
        done

        module_str+=" ${parameters_str}"
      fi
    fi

    if [[ "$first_time" == 1 ]]; then
      final_command="$module_str"
      first_time=0
      continue
    fi
    final_command+=" && ${module_str}"
  done

  if [[ -z "$final_command" ]]; then
    return 22 # EINVAL
  fi

  printf '%s\n' "$final_command"
}

# This function is responsible for turn on and off the graphic interface based
# on the user request. By default, it uses systemctl for managing the graphic
# interface; however, the user can override the main command in the
# kworkflow.confg file.
#
# @operation It expects a string where "ON" turns on the interface and any
#            other output turn off (we use "OFF" for keeping the symmetry).
# @target Target can be VM_TARGET, LOCAL_TARGET, and REMOTE_TARGET.
# @unformatted_remote It is the remote location formatted as REMOTE:PORT.
# @flag How to display a command, see `src/lib/kwlib.sh` function `cmd_manager`.
function gui_control()
{
  local operation="$1"
  local target="$2"
  local unformatted_remote="$3"
  local flag="$4"
  local gui_control_cmd
  local vt_console
  local isolate_target
  local remote
  local port
  local set_default='false'
  local default_command

  flag=${flag:-'SILENT'}

  if [[ "$operation" == 'ON' ]]; then
    isolate_target='graphical.target'
    vt_console=1
    gui_control_cmd="${configurations[gui_on]}"
  elif [[ "$operation" == 'OFF' ]]; then
    isolate_target='multi-user.target'
    vt_console=0
    gui_control_cmd="${configurations[gui_off]}"
  elif [[ "$operation" == 'ON_AFTER_REBOOT' ]]; then
    isolate_target='graphical.target'
    vt_console=1
    gui_control_cmd="${configurations[gui_on_after_reboot]}"
    set_default='true'
    warning 'This option will take effect after reboot' >&2
  elif [[ "$operation" == 'OFF_AFTER_REBOOT' ]]; then
    isolate_target='multi-user.target'
    vt_console=0
    gui_control_cmd="${configurations[gui_off_after_reboot]}"
    set_default='true'
    warning 'This option will take effect after reboot' >&2
  fi

  # If the user does not override the turn on/off command we use the default
  # systemctl

  if [[ "$set_default" == 'true' ]]; then
    default_command="systemctl set-default ${isolate_target}"
  else
    default_command="systemctl isolate ${isolate_target}"
  fi

  gui_control_cmd=${gui_control_cmd:-"${default_command}"}
  bind_control_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" '$vt_console' > $i; done; sleep 0.5' # is this right?

  case "$target" in
    2) # LOCAL TARGET
      gui_control_cmd="sudo ${gui_control_cmd}"
      bind_control_cmd="sudo ${bind_control_cmd}"
      cmd_manager "$flag" "$gui_control_cmd"
      cmd_manager "$flag" "$bind_control_cmd"
      ;;
    3) # REMOTE TARGET
      cmd_remotely "$flag" "$gui_control_cmd" "$remote" "$port"
      cmd_remotely "$flag" "$bind_control_cmd" "$remote" "$port" '' '1'
      ;;
  esac
}

# It informs the users which type of connectors is available in the system
#
# @target Target can be VM_TARGET, LOCAL_TARGET, and REMOTE_TARGET.
# @unformatted_remote It is the remote location formatted as REMOTE:PORT.
function get_available_connectors()
{
  local target="$1"
  local unformatted_remote="$2"
  local flag="$3"
  local target_label
  local card
  local key
  local value
  local connectors
  local i
  local remote
  local port
  local find_conn_cmd
  local connector_enabled
  declare -A cards

  flag=${flag:-'SILENT'}

  # command to find all cards and for each of them append if it is enabled or not
  find_conn_cmd="find ${SYSFS_CLASS_DRM} -name 'card*-*' -exec printf '%s,' {} \; -exec cat {}/enabled \; -exec printf '\n' \;"

  case "$target" in
    2) # LOCAL TARGET
      cards_raw_list=$(cmd_manager 'SILENT' "$find_conn_cmd" | sort --dictionary-order)
      if [[ -f "$SYSFS_CLASS_DRM" ]]; then
        ret="$?"
        complain "We cannot access ${SYSFS_CLASS_DRM}"
        return "$ret" # ENOENT
      fi
      target_label='local'
      ;;
    3) # REMOTE TARGET
      cards_raw_list=$(cmd_remotely "$flag" "$find_conn_cmd" | sort --dictionary-order)
      target_label='remote'
      ;;
  esac

  while read -r card_info; do
    card_path=$(printf '%s' "$card_info" | cut --delimiter=',' --fields=1)
    connector_enabled=$(printf '%s' "$card_info" | cut --delimiter=',' --fields=2)
    card=$(basename "$card_path")
    key=$(printf '%s\n' "$card" | grep card | cut --delimiter='-' --fields=1)
    value=$(printf '%s\n' "$card" | grep card | cut --delimiter='-' --fields=2-)
    [[ "$key" == "$value" ]] && continue

    if [[ -n "$key" && -n "$value" ]]; then
      list_of_values="${cards[$key]}"

      if [[ "$connector_enabled" == 'enabled' ]]; then
        value="${value} *"
      fi

      if [[ -z "$list_of_values" ]]; then
        cards["$key"]="$value"
        continue
      fi
      cards["$key"]="${list_of_values},${value}"
    fi
  done <<< "$cards_raw_list"

  for card in "${!cards[@]}"; do
    connectors="${cards[$card]}"

    printf '%s\n' "[${target_label}] ${card^} supports:"

    IFS=',' read -r -a connectors <<< "${cards[$card]}"
    for conn in "${connectors[@]}"; do
      printf '%s\n' " ${conn}"
    done

  done
}

# Return each mode available per connector.
#
# @target Target can be VM_TARGET, LOCAL_TARGET, and REMOTE_TARGET.
# @unformatted_remote It is the remote location formatted as REMOTE:PORT.
function get_supported_mode_per_connector()
{
  local target="$1"
  local unformatted_remote="$2"
  local flag="$3"
  local cmd
  local port
  local remote

  flag=${flag:-'SILENT'}

  cmd="for f in ${SYSFS_CLASS_DRM}/*/modes;"' do c=$(< $f) && [[ ! -z $c ]] && printf "%s\n" "$f:" "$c" ""; done'

  case "$target" in
    2) # LOCAL TARGET
      if [[ -f "$SYSFS_CLASS_DRM" ]]; then
        ret="$?"
        complain "We cannot access ${SYSFS_CLASS_DRM}"
        return "$ret" # ENOENT
      fi
      modes=$(eval "$cmd")
      target_label='local'
      ;;
    3) # REMOTE TARGET
      modes=$(cmd_remotely 'SILENT' "$cmd" '' '' '' '1')
      target_label='remote'
      ;;
  esac

  modes=${modes//\/modes/}
  modes=${modes//sys\/class\/drm\//}

  say 'Modes per card'
  printf '%s\n' "$modes"
}

function parse_drm_options()
{
  local long_options='remote:,local,gui-on,gui-off,gui-on-after-reboot,gui-off-after-reboot'
  long_options+=',load-module:,unload-module:,help,verbose,conn-available,modes'
  local short_options='h'
  local raw_options="$*"
  local options
  local flag=0
  local remote
  local config_file_deploy_target

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'drm' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['GUI_ON']=''
  options_values['GUI_OFF']=''
  options_values['GUI_ON_AFTER_REBOOT']=''
  options_values['GUI_OFF_AFTER_REBOOT']=''
  options_values['CONN_AVAILABLE']=''
  options_values['HELP']=''
  options_values['LOAD_MODULE']=''
  options_values['UNLOAD_MODULE']=''
  options_values['CONN_AVAILABLE']=''
  options_values['MODES_AVAILABLE']=''
  options_values['VERBOSE']=''

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']='Something is wrong in the remote option'
    return 22 # EINVAL
  fi

  # Check default target
  if [[ -n ${deploy_config[default_deploy_target]} ]]; then
    config_file_deploy_target=${deploy_config[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
    # VM is not a valid case for drm option
    if [[ "${options_values['TARGET']}" == "$VM_TARGET" ]]; then
      options_values['TARGET']="$LOCAL_TARGET"
    fi
  else
    options_values['TARGET']="$LOCAL_TARGET"
  fi

  eval "set -- ${options}"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote)
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="$option"
          return 22 # EINVAL
        fi
        options_values['TARGET']="$REMOTE_TARGET"
        shift 2
        ;;
      --local)
        options_values['TARGET']="$LOCAL_TARGET"
        shift
        ;;
      --gui-on)
        options_values['GUI_ON']=1
        shift
        ;;
      --gui-off)
        options_values['GUI_OFF']=1
        shift
        ;;
      --gui-on-after-reboot)
        options_values['GUI_ON_AFTER_REBOOT']=1
        shift
        ;;
      --gui-off-after-reboot)
        options_values['GUI_OFF_AFTER_REBOOT']=1
        shift
        ;;
      --load-module)
        #options_values['LOAD_MODULE']=$(cut -d '=' -f2- <<< "$option")
        if [[ "$2" =~ ^-- ]]; then
          options_values['ERROR']='Load modules requires a module name name'
          return 22 # EINVAL
        fi
        options_values['LOAD_MODULE']+="$2"
        shift 2
        ;;
      --unload-module)
        #options_values['UNLOAD_MODULE']=$(cut -d '=' -f2- <<< "$option")
        if [[ "$2" =~ ^-- ]]; then
          options_values['ERROR']='Load modules requires a module name name'
          return 22 # EINVAL
        fi
        options_values['UNLOAD_MODULE']+="$2"
        shift 2
        ;;
      --conn-available)
        options_values['CONN_AVAILABLE']=1
        shift
        ;;
      --modes)
        options_values['MODES_AVAILABLE']=1
        shift
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --help | -h)
        drm_help "$1"
        exit
        ;;
      test_mode)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        options_values['ERROR']="$1"
        return 22
        ;;
    esac
  done
}

function drm_help()
{
  if [[ "$1" =~ --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'drm'
    return
  fi
  printf '%s\n' 'Usage: kw drm [options]:' \
    '  drm [--local | --remote [<remote>:<port>]] (-lm|--load-module)=<module>[:<param1>,<param2>][;<module>:...][;...]' \
    '  drm [--local | --remote [<remote>:<port>]] (-um|--unload-module)=<module>[;<module>;...]' \
    '  drm [--local | --remote [<remote>:<port>]] --gui-on' \
    '  drm [--local | --remote [<remote>:<port>]] --gui-off' \
    '  drm [--local | --remote [<remote>:<port>]] --gui-on-after-reboot' \
    '  drm [--local | --remote [<remote>:<port>]] --gui-off-after-reboot' \
    '  drm [--local | --remote [<remote>:<port>]] --conn-available' \
    '  drm [--local | --remote [<remote>:<port>]] --verbose' \
    '  drm [--local | --remote [<remote>:<port>]] --modes'
}

load_deploy_config

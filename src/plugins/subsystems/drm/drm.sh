. "$KW_LIB_DIR/kw_config_loader.sh" --source-only
. "$KW_LIB_DIR/remote.sh" --source-only
. "$KW_LIB_DIR/kwlib.sh" --source-only

declare -gr UNLOAD='UNLOAD'
declare -gA drm_options_values

SYSFS_CLASS_DRM="/sys/class/drm"

function drm_manager()
{
  local target
  local gui_on
  local gui_off
  local conn_available
  local remote
  local load_module
  local unload_module
  local test_mode

  if [[ "$*" =~ -h|--help ]]; then
    drm_help "$*"
    exit 0
  fi

  drm_parser_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${drm_options_values['ERROR']} $target $gui_on $gui_off ${remote_parameters['REMOTE_IP']} ${remote_parameters['REMOTE_PORT']}"
    drm_help
    return 22
  fi

  target="${drm_options_values['TARGET']}"
  gui_on="${drm_options_values['GUI_ON']}"
  gui_off="${drm_options_values['GUI_OFF']}"
  conn_available="${drm_options_values['CONN_AVAILABLE']}"
  modes_available="${drm_options_values['MODES_AVAILABLE']}"
  help_opt="${drm_options_values['HELP']}"
  test_mode="${drm_options_values['TEST_MODE']}"
  load_module="${drm_options_values['LOAD_MODULE']}"
  unload_module="${drm_options_values['UNLOAD_MODULE']}"

  remote="${remote_parameters['REMOTE']}"

  if [[ "$test_mode" == "TEST_MODE" ]]; then
    echo "$target $gui_on $gui_off ${remote_parameters['REMOTE_IP']} ${remote_parameters['REMOTE_PORT']}"
    return 0
  fi

  if [[ -n "$load_module" ]]; then
    module_control "LOAD" "$target" "$remote" "$load_module"
    if [[ "$?" != 0 ]]; then
      return 22
    fi
  fi

  if [[ "$gui_on" == 1 ]]; then
    gui_control "ON" "$target" "$remote"
  fi

  if [[ "$gui_off" == 1 ]]; then
    gui_control "OFF" "$target" "$remote"
  fi

  if [[ -n "$unload_module" ]]; then
    # For unload DRM drivers, we need to make sure that we turn off user GUI
    [[ "$gui_off" != 1 ]] && gui_control "OFF" "$target" "$remote"
    module_control "UNLOAD" "$target" "$remote" "$unload_module"
  fi

  if [[ "$conn_available" == 1 ]]; then
    get_available_connectors "$target" "$remote"
  fi

  if [[ "$modes_available" == 1 ]]; then
    get_supported_mode_per_connector "$target" "$remote"
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
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`.
function module_control()
{
  local operation="$1"
  local target="$2"
  local unformatted_remote="$3"
  local parameters="$4"
  local flag="$5"
  local module_cmd=""
  local remote
  local port

  module_cmd=$(convert_module_info "$operation" "$parameters")
  if [[ "$?" != 0 ]]; then
    complain "Wrong parameter in --[un]load-module="
    return 22
  fi

  case "$target" in
    2) # LOCAL
      cmd_manager "$flag" "sudo bash -c \"$module_cmd\""
      ;;
    3) # REMOTE
      remote=$(get_based_on_delimiter "$unformatted_remote" ":" 1)
      port=$(get_based_on_delimiter "$unformatted_remote" ":" 2)

      cmd_remotely "$module_cmd" "$flag" "$remote" "$port"
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
  local parameters_str=""
  local final_command=""
  local remove_flag=""
  local module_str=""
  local first_time=1

  if [[ "$unload" == "$UNLOAD" ]]; then
    remove_flag="-r"
  else
    remove_flag=""
  fi

  IFS=';' read -r -a modules <<< "$raw_modules_str"
  # Target event. e.g.: amdgpu_dm or amdgpu
  for module in "${modules[@]}"; do
    parameters_str=""
    module_str="modprobe $remove_flag $module"

    if [[ "$module" =~ .*':'.* ]]; then
      module_str="modprobe $remove_flag "
      module_str+=$(cut -d ":" -f1 <<< "$module")

      if [[ "$unload" != "$UNLOAD" ]]; then
        # Capture module parameters
        specific_parameters_str=$(cut -d ":" -f2 <<< "$module")
        IFS=',' read -r -a parameters_array <<< "$specific_parameters_str"
        for specific_parameter in "${parameters_array[@]}"; do
          parameters_str+="$specific_parameter "
        done

        module_str+=" $parameters_str"
      fi
    fi

    if [[ "$first_time" == 1 ]]; then
      final_command="$module_str"
      first_time=0
      continue
    fi
    final_command+=" && $module_str"
  done

  if [[ -z "$final_command" ]]; then
    return 22 # EINVAL
  fi

  echo "$final_command"
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
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`.
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

  if [[ "$operation" == "ON" ]]; then
    isolate_target='graphical.target'
    vt_console=1
    gui_control_cmd="${configurations[gui_on]}"
  else
    isolate_target='multi-user.target'
    vt_console=0
    gui_control_cmd="${configurations[gui_off]}"
  fi

  # If the user does not override the turn on/off command we use the default
  # systemctl
  gui_control_cmd=${gui_control_cmd:-"systemctl isolate $isolate_target"}
  bind_control_cmd='for i in /sys/class/vtconsole/*/bind; do echo '$vt_console' > $i; done; sleep 0.5'

  case "$target" in
    2) # LOCAL TARGET
      gui_control_cmd="sudo $gui_control_cmd"
      bind_control_cmd="sudo $bind_control_cmd"
      cmd_manager "$flag" "$gui_control_cmd"
      cmd_manager "$flag" "$bind_control_cmd"
      ;;
    3) # REMOTE TARGET
      remote=$(get_based_on_delimiter "$unformatted_remote" ":" 1)
      port=$(get_based_on_delimiter "$unformatted_remote" ":" 2)
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      cmd_remotely "$gui_control_cmd" "$flag" "$remote" "$port"
      cmd_remotely "$bind_control_cmd" "$flag" "$remote" "$port" "" "1"
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
  local target_label
  local card
  local key
  local value
  local connectors
  local i
  local remote
  local port
  local find_conn_cmd
  declare -A cards

  case "$target" in
    2) # LOCAL TARGET
      cards_raw_list=$(find "$SYSFS_CLASS_DRM" -name 'card*')
      if [[ -f "$SYSFS_CLASS_DRM" ]]; then
        ret="$?"
        complain "We cannot access $SYSFS_CLASS_DRM"
        return "$ret" # ENOENT
      fi
      target_label="local"
      ;;
    3) # REMOTE TARGET
      find_conn_cmd="find $SYSFS_CLASS_DRM -name 'card*'"
      remote=$(get_based_on_delimiter "$unformatted_remote" ":" 1)
      port=$(get_based_on_delimiter "$unformatted_remote" ":" 2)
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      cards_raw_list=$(cmd_remotely "$find_conn_cmd" "SILENT" "$remote" "$port")
      target_label="remote"
      ;;
  esac

  while read -r card; do
    card=$(basename "$card")
    key=$(echo "$card" | grep card | cut -d- -f1)
    value=$(echo "$card" | grep card | cut -d- -f2)
    [[ "$key" == "$value" ]] && continue

    if [[ -n "$key" && -n "$value" ]]; then
      list_of_values="${cards[$key]}"
      if [[ -z "$list_of_values" ]]; then
        cards["$key"]="$value"
        continue
      fi
      cards["$key"]="$list_of_values,$value"
    fi
  done <<< "$cards_raw_list"

  for card in "${!cards[@]}"; do
    connectors="${cards[$card]}"

    echo "[$target_label] ${card^} supports:"

    IFS=',' read -r -a connectors <<< "${cards[$card]}"
    for conn in "${connectors[@]}"; do
      echo -e " $conn"
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
  local cmd
  local port
  local remote

  cmd="for f in $SYSFS_CLASS_DRM/*/modes;"' do c=$(cat $f) && [[ ! -z $c ]] && echo "$f:\n$c\n"; done'

  case "$target" in
    2) # LOCAL TARGET
      if [[ -f "$SYSFS_CLASS_DRM" ]]; then
        ret="$?"
        complain "We cannot access $SYSFS_CLASS_DRM"
        return "$ret" # ENOENT
      fi
      modes=$(eval "$cmd")
      target_label="local"
      ;;
    3) # REMOTE TARGET
      remote=$(get_based_on_delimiter "$unformatted_remote" ":" 1)
      port=$(get_based_on_delimiter "$unformatted_remote" ":" 2)
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      modes=$(cmd_remotely "$cmd" "SILENT" "$remote" "$port" "root" "1")
      target_label="remote"
      ;;
  esac

  modes=${modes//\/modes/}
  modes=${modes//sys\/class\/drm\//}

  say "Modes per card"
  echo -e "$modes"
}

function drm_parser_options()
{
  local raw_options="$*"
  local flag=0
  local remote

  drm_options_values["GUI_ON"]=0
  drm_options_values["GUI_OFF"]=0
  drm_options_values["CONN_AVAILABLE"]=0
  drm_options_values["HELP"]=0

  # Set basic default values
  if [[ -n ${configurations[default_deploy_target]} ]]; then
    local config_file_deploy_target=${configurations[default_deploy_target]}
    drm_options_values["TARGET"]=${deploy_target_opt[$config_file_deploy_target]}
    # VM is not a valid case for drm option
    if [[ "${drm_options_values["TARGET"]}" == "$VM_TARGET" ]]; then
      drm_options_values["TARGET"]="$LOCAL_TARGET"
    fi
  else
    drm_options_values["TARGET"]="$LOCAL_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="$remote"
    return 22 # EINVAL
  fi

  drm_options_values["REMOTE"]="$remote"

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
      module_parameter=0
      unmodule_parameter=0

      case "$option" in
        --remote)
          drm_options_values["TARGET"]="$REMOTE_TARGET"
          continue
          ;;
        --local)
          drm_options_values["TARGET"]="$LOCAL_TARGET"
          continue
          ;;
        --gui-on)
          drm_options_values["GUI_ON"]=1
          continue
          ;;
        --gui-off)
          drm_options_values["GUI_OFF"]=1
          continue
          ;;
        --load-module=* | -lm=*)
          drm_options_values["LOAD_MODULE"]=$(cut -d "=" -f2- <<< "$option")
          module_parameter=1
          if [[ -z "${drm_options_values['LOAD_MODULE']}" ]]; then
            drm_options_values["ERROR"]="You need to specify at least one module name when using --load-module"
            return 22
          fi
          continue
          ;;
        --unload-module=* | -um=*)
          drm_options_values["UNLOAD_MODULE"]=$(cut -d "=" -f2- <<< "$option")
          unmodule_parameter=1
          if [[ -z "${drm_options_values['UNLOAD_MODULE']}" ]]; then
            drm_options_values["ERROR"]="You need to specify a module name when using --unload-module"
            return 22
          fi
          continue
          ;;
        --conn-available)
          drm_options_values["CONN_AVAILABLE"]=1
          continue
          ;;
        --modes)
          drm_options_values["MODES_AVAILABLE"]=1
          break
          ;;
        --help | -h | help)
          drm_options_values["HELP"]=1
          break
          ;;
        test_mode)
          drm_options_values["TEST_MODE"]="TEST_MODE"
          ;;
        *)
          drm_options_values["ERROR"]="$option"
          return 22 # EINVAL
          ;;
      esac
    else
      # Handle other sub-parameters
      if [[ "${drm_options_values['TARGET']}" == "$REMOTE_TARGET" &&
        "$module_parameter" != 1 && "$unload_module" != 1 ]]; then
        populate_remote_info "$option"
        if [[ "$?" == 22 ]]; then
          drm_options_values['ERROR']="$option"
          return 22
        fi
      fi

      if [[ "$module_parameter" == 1 ]]; then
        drm_options_values["LOAD_MODULE"]+=" $option"
      fi

      if [[ "$unmodule_parameter" == 1 ]]; then
        drm_options_values["UNLOAD_MODULE"]+=" $option"
      fi
    fi
  done

  case "${drm_options_values["TARGET"]}" in
    2 | 3) ;;

    *)
      if [[ "${drm_options_values["TARGET"]}" == 1 ]]; then
        msg=" The option --vm is not valid for drm plugin, use --remote or --local"
      fi
      drm_options_values["ERROR"]="remote option$msg"
      return 22
      ;;
  esac
}

function drm_help()
{
  if [[ "$1" =~ --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'drm'
    return
  fi
  printf '%s\n' 'Usage: kw drm [options]:' \
    '  drm [--local | --remote [<remote>:<port>]] (-lm|--load-module)=<module>[:<param1>,<param2>][;<module>:...][;...]' \
    '  drm [--local | --remote [<remote>:<port>]] (-um|--unload-module)=<module>[;<module>;...]' \
    '  drm [--local | --remote [<remote>:<port>]] --gui-on' \
    '  drm [--local | --remote [<remote>:<port>]] --gui-off' \
    '  drm [--local | --remote [<remote>:<port>]] --conn-available' \
    '  drm [--local | --remote [<remote>:<port>]] --modes'
}

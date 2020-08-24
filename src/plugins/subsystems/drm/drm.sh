. $src_script_path/kw_config_loader.sh --source-only
. $src_script_path/remote.sh --source-only
. $src_script_path/kwlib.sh --source-only

declare -A drm_options_values

SYSFS_CLASS_DRM="/sys/class/drm"

function drm_manager()
{
  local target
  local gui_on
  local gui_off
  local conn_available
  local remote
  local test_mode

  drm_parser_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${drm_options_values['ERROR']}  $target $gui_on $gui_off $remote"
    return 22
  fi

  target="${drm_options_values['TARGET']}"
  gui_on="${drm_options_values['GUI_ON']}"
  gui_off="${drm_options_values['GUI_OFF']}"
  conn_available="${drm_options_values['CONN_AVAILABLE']}"
  modes_available="${drm_options_values['MODES_AVAILABLE']}"
  help_opt="${drm_options_values['HELP']}"
  remote="${drm_options_values['REMOTE']}"
  test_mode="${drm_options_values['TEST_MODE']}"

  if [[ "$test_mode" == "TEST_MODE" ]]; then
    echo "$target $gui_on $gui_off $remote"
    return 0
  fi

  if [[ "$gui_on" == 1 ]]; then
    gui_control "ON" "$target" "$remote"
  elif [[ "$gui_off" == 1 ]]; then
    gui_control "OFF" "$target" "$remote"
  elif [[ "$conn_available" == 1 ]]; then
    get_available_connectors "$target" "$remote"
  elif [[ "$modes_available" == 1 ]]; then
    get_supported_mode_per_connector "$target" "$remote"
  elif [[ "$help_opt" == 1 ]]; then
    drm_help
  else
    complain "Invalid or incomplete command"
    drm_help
    return 22
  fi
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
      local remote=$(get_based_on_delimiter "$unformatted_remote" ":" 1)
      local port=$(get_based_on_delimiter "$unformatted_remote" ":" 2)
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      cmd_remotely "$gui_control_cmd" "$flag" "$remote" "$port"
      cmd_remotely "$bind_control_cmd" "$flag" "$remote" "$port" "root" "1"
    ;;
  esac
}

# It informs the users which type of connectors is available in the system
#
# @target Target can be VM_TARGET, LOCAL_TARGET, and REMOTE_TARGET.
# @unformatted_remote It is the remote location formatted as REMOTE:PORT.
function get_available_connectors
{
  local target="$1"
  local unformatted_remote="$2"
  local target_label
  local card
  local key
  local value
  local connectors
  local i
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
      local find_conn_cmd="find $SYSFS_CLASS_DRM -name 'card*'"
      local remote=$(get_based_on_delimiter "$unformatted_remote" ":" 1)
      local port=$(get_based_on_delimiter "$unformatted_remote" ":" 2)
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      cards_raw_list=$(cmd_remotely "$find_conn_cmd" "SILENT" "$remote" "$port")
      target_label="remote"
    ;;
  esac

  while read card
  do
    card=$(basename "$card")
    key=$(echo "$card" | grep card | cut -d- -f1)
    value=$(echo "$card" | grep card | cut -d- -f2)
    [[ "$key" == "$value" ]] && continue

    if [[ ! -z "$key" && ! -z "$value" ]]; then
      list_of_values="${cards[$key]}"
      if [[ -z "$list_of_values" ]]; then
        cards["$key"]="$value"
        continue
      fi
      cards["$key"]="$list_of_values,$value"
    fi
  done <<< "$cards_raw_list"

  for card in "${!cards[@]}"
  do
    i=1
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
function get_supported_mode_per_connector
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
      modes=$(eval $cmd)
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
  local raw_options="$@"
  local flag=0
  local remote

  drm_options_values["GUI_ON"]=0
  drm_options_values["GUI_OFF"]=0
  drm_options_values["CONN_AVAILABLE"]=0
  drm_options_values["HELP"]=0

  # Set basic default values
  if [[ ! -z ${configurations[default_deploy_target]} ]]; then
    local config_file_deploy_target=${configurations[default_deploy_target]}
    drm_options_values["TARGET"]=${deploy_target_opt[$config_file_deploy_target]}
    # VM is not a valid case for drm option
    if [[ "${drm_options_values["TARGET"]}" == "$VM_TARGET" ]]; then
      drm_options_values["TARGET"]="$LOCAL_TARGET"
    fi
  else
    drm_options_values["TARGET"]="$LOCAL_TARGET"
  fi

  remote=$(get_remote_info)
  if [[ "$?" == 22 ]]; then
    drm_options_values["ERROR"]="$remote"
    return 22 # EINVAL
  fi

  drm_options_values["REMOTE"]="$remote"

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do

    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
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
          break
          ;;
        --gui-off)
          drm_options_values["GUI_OFF"]=1
          break
          ;;
        --conn-available)
          drm_options_values["CONN_AVAILABLE"]=1
          break
          ;;
        --modes)
          drm_options_values["MODES_AVAILABLE"]=1
          break
          ;;
        --help|-h|help)
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
      if [[ "${drm_options_values['TARGET']}" == "$REMOTE_TARGET" ]]; then
        drm_options_values["REMOTE"]=$(get_remote_info "$option")
      fi
    fi
  done

  case "${drm_options_values["TARGET"]}" in
    2|3)
      ;;
    *)
      if [[ "${drm_options_values["TARGET"]}" == 1 ]]; then
        msg=" The option --vm is not valid for drm plugin, use --remote or --local"
      fi
      drm_options_values["ERROR"]="remote option$msg"
      return 22
      ;;
  esac
}

function drm_help
{
  echo -e "Usage: kw drm [options]:\n" \
    "\tdrm [--remote [REMOTE:PORT]] --gui-on\n" \
    "\tdrm [--remote [REMOTE:PORT]] --gui-off\n" \
    "\tdrm [--remote [REMOTE:PORT]] --conn-available\n" \
    "\tdrm [--remote [REMOTE:PORT]] --modes"
}

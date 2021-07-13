include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kw_config_loader.sh"

# Hash containing user options
declare -gA options_values

function kw_sendemail()
{
  local test_opts='--dry-run --annotate --cover-letter --thread --no-chain-reply-to'

  cmd="git send-email $test_opts --to=rugone1000@hotmail.com -1"

  eval "$cmd"

  return 0
}

function sendemail_setup()
{
  local count=0
  local -a missing_conf
  local -a min_conf=('user.name' 'user.email' 'sendemail.smtpencryption'
    'sendemail.smtpserver' 'sendemail.smtpuser' 'sendemail.smtpserverport')
  local set_confs

  set_confs=$(git config --list)
  for config in "${min_conf[@]}"; do
    if [[ $(grep -c "$config" "$set_confs") -eq 0 ]]; then
      missing_conf[$count]="$config"
      count=$((count + 1))
    fi
  done
  if [[ $count -gt 0 ]]; then
    complain "Missing configurations neede for sendemail: ${missing_conf[*]}"
    return 1
  fi
  return 0
}

function sendemail_parser_options()
{
  local raw_options="$*"
  local uninstall=0
  local enable_collect_param=0
  local remote

  options_values['UNINSTALL']=''
  options_values['MODULES']=0
  options_values['LS_LINE']=0
  options_values['LS']=0
  options_values['REBOOT']=0
  options_values['MENU_CONFIG']='nconfig'

  remote_parameters['REMOTE']=''

  # Set basic default values
  if [[ -n ${configurations[default_deploy_target]} ]]; then
    local config_file_deploy_target=${configurations[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$VM_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="$remote"
    return 22 # EINVAL
  fi

  if [[ ${configurations[reboot_after_deploy]} == 'yes' ]]; then
    options_values['REBOOT']=1
  fi

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
      if [[ "$enable_collect_param" == 1 ]]; then
        options_values['ERROR']='expected paramater'
        return 22
      fi

      case "$option" in
        --remote)
          options_values['TARGET']="$REMOTE_TARGET"
          continue
          ;;
        --local)
          options_values['TARGET']="$LOCAL_TARGET"
          continue
          ;;
        --vm)
          options_values['TARGET']="$VM_TARGET"
          continue
          ;;
        --reboot | -r)
          options_values['REBOOT']=1
          continue
          ;;
        --modules | -m)
          options_values['MODULES']=1
          continue
          ;;
        --list | -l)
          options_values['LS']=1
          continue
          ;;
        --ls-line | -s)
          options_values['LS_LINE']=1
          continue
          ;;
        --uninstall | -u)
          enable_collect_param=1
          uninstall=1
          continue
          ;;
        test_mode)
          options_values['TEST_MODE']='TEST_MODE'
          ;;
        *)
          options_values['ERROR']="$option"
          return 22 # EINVAL
          ;;
      esac
    else # Handle potential parameters
      if [[ "$uninstall" != 1 &&
        ${options_values['TARGET']} == "$REMOTE_TARGET" ]]; then
        populate_remote_info "$option"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="$option"
          return 22
        fi
      elif [[ "$uninstall" == 1 ]]; then
        options_values['UNINSTALL']+="$option"
        enable_collect_param=0
      else
        # Invalind option
        options_values['ERROR']="$option"
        return 22
      fi
    fi
  done

  # Uninstall requires an option
  if [[ "$uninstall" == 1 && -z "${options_values['UNINSTALL']}" ]]; then
    options_values['ERROR']='uninstall requires a kernel name'
    return 22
  fi

  case "${options_values['TARGET']}" in
    1 | 2 | 3) ;;

    *)
      options_values['ERROR']='remote option'
      return 22
      ;;
  esac
}

function build_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'send-email'
    return
  fi
  echo -e "kw send-email:\n" \
    "  send-email - Send email"
}

# Basic:
# ======

# kw mail,e

# 1) Setup
# ========
# kw mail --setup [--verify|-v][--interactive|-i][--smtpserver=""][--smtpuser=""]
# e.g.:
#   kw mail --setup -i
#    What is your mail address: joedoe@lala.com
#    ...

#   kw mail --setup
#    Template: Outlook (1) e Gmail (2)
#    Email:
#    Nome:

# kworkflow.config
# # Send-email
# ...

# kw mail --setup --verify,v
# e.g.:
#   Good case: Looks good
#   Bad case: Fail because this and that

# 2) Send
# =======
# kw mail [--send [--to=""|--cc=""][--annotate| kw mail --send --to="lala@uuu.com" SHA][]]
#  => Default: --send
#              --thread --no-chain-reply-to
#  e.g.:
#  kw mail --send --to="lala@uuu.com" SHA
#   -> Detect that we have more than one patch
#      * Add --cover-letter
#  kw mail --send --to="lala@uuu.com" -1

# kw mail SHA [--group=REVIEW]
#  -> REVIEW="name la" <namela@luuuu.com>, name 2..."

# kw mail --send --use-maintainers
#  -> kw m /path/

# Real-life examples:
# git send-email --annotate --cover-letter --thread --no-chain-reply-to --to="...PESSOAS OU LISTA DE EMAIL..." --suppress-cc=all <COMMIT>

# git send-email --annotate --cover-letter --thread --no-chain-reply-to --to="..." --cc="..." <COMMIT>

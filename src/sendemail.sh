include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kw_config_loader.sh"

# Hash containing user options
declare -gA options_values

function kw_sendemail()
{
  parse_sendemail_options "$@"

  local opts="${configurations[mail_args]} ${options_values[EX_ARGS]}"
  local recipients="${configurations[mail_recipients]}"

  cmd="git send-email $opts --to=$recipients -1"

  echo "$cmd"
  # eval "$cmd"

  return 0
}

function sendemail_setup()
{
  local count=0
  local -a missing_conf
  local -a min_conf=('user.name=' 'user.email=' 'sendemail.smtpencryption=' 'fail'
    'sendemail.smtpserver=' 'sendemail.smtpuser=' 'sendemail.smtpserverport=')
  local set_confs

  # echo "${min_conf[*]}"
  set_confs=$(git config --list)
  # echo "*****$set_confs*****"
  for config in "${min_conf[@]}"; do
    if ! echo "$set_confs" | grep -cF "$config" - &> /dev/null; then
      # printf "\n\n%s\n\n" "$config;"
      missing_conf[$count]="$config"
      count=$((count + 1))
    fi
  done
  echo "COUNT: $count"
  if [[ $count -gt 0 ]]; then
    complain "Missing configurations needed for sendemail: ${missing_conf[*]%=}"
    return 1
  fi
  return 0
}

function parse_sendemail_options()
{
  local long_options='help,send,setup,args:'
  local short_options='h,s,i,a:'

  options="$(getopt \
    --name "kw send-email" \
    --options "$short_options" \
    --longoptions "$long_options" \
    -- "$@")"

  if [[ "$?" != 0 ]]; then
    return 22 # EINVAL
  fi

  # Default values
  options_values['SEND']=''
  options_values['EX_ARGS']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        sendemail_help "$1"
        exit
        ;;
      --setup | -i)
        sendemail_setup
        exit
        ;;
      --send | -s)
        options_values['SEND']=1
        shift
        ;;
      --args | -a)
        options_values['EX_ARGS']="$2"
        shift 2
        ;;
      --)
        shift
        ;;
      *)
        complain "Invalid option: $option"
        exit 22 # EINVAL
        ;;
    esac
  done
}

function sendemail_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'sendemail'
    exit
  fi
  printf "%s\n" "kw send-email:" \
    "  send-email (-s | --send) - Send email" \
    "  send-email (-i | --setup) - Configure mailing functionality"
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

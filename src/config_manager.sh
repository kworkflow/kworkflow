. $src_script_path/kwio.sh --source-only

declare -r metadata_dir="metadata"
declare -r configs_dir="configs"

# This function handles the save operation of kernel's '.config' file. It
# checks if the '.config' exists and saves it using git (dir.:
# <kw_install_path>/configs)
#
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
# @name This option specifies a name for a target .config file. This name
#       represents the access key for .config.
# @description Description for a config file, de descrition from '-d' flag.
function save_config_file()
{
  local ret=0
  local -r force=$1
  local -r name=$2
  local -r description=$3
  local -r original_path=$PWD
  local -r dot_configs_dir="$config_files_path/configs"

  if [[ ! -f $original_path/.config ]]; then
    complain "There's no .config file in the current directory"
    exit 2 # ENOENT
  fi

  if [[ ! -d $dot_configs_dir ]]; then
    mkdir $dot_configs_dir
    cd $dot_configs_dir
    git init --quiet
    mkdir $metadata_dir $configs_dir
  fi

  cd $dot_configs_dir

  # Check if the metadata related to .config file already exists
  if [[ ! -f $metadata_dir/$name ]]; then
    touch $metadata_dir/$name
  elif [[ $force != 1 ]]; then
    if [[ $(ask_yN "$name already exists. Update?") =~ "0" ]]; then
      complain "Save operation aborted"
      cd $original_path
      exit 0
    fi
  fi

  if [[ ! -z $description ]]; then
    echo $description > $metadata_dir/$name
  fi

  cp $original_path/.config $dot_configs_dir/$configs_dir/$name
  git add $configs_dir/$name $metadata_dir/$name
  git commit -m "New config file added: $USER - $(date)" > /dev/null 2>&1

  if [[ "$?" == 1 ]]; then
    warning "Warning: $name: there's nothing new in this file"
  else
    success "Saved $name"
  fi

  cd $original_path
}

function list_configs()
{
  local -r dot_configs_dir="$config_files_path/configs"

  if [[ ! -d $dot_configs_dir ]]; then
    say "There's no tracked .config file"
    exit 0
  fi

  echo -e "Name\t\tDescription"
  echo -e "----\t\t------------"
  for filename in $dot_configs_dir/$metadata_dir/*; do
    local name=$(basename $filename)
    local content=$(cat $filename)
    echo -n $name
    echo -e "\t\t$content"
  done
}

# This function handles the options available in 'configm'.
#
# @* This parameter expects a list of parameters, such as '-n', '-d', and '-f'.
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function execute_config_manager()
{
  local name_config
  local description_config
  local force=0

  [[ "$@" =~ "-f" ]] && force=1

  case $1 in
    --save)
      shift # Skip '--save' option
      name_config=$1
      # Validate string name
      if [[ "$name_config" =~ ^- || -z "${name_config// }" ]]; then
        complain "Invalid argument"
        exit 22 # EINVAL
      fi
      # Shift name and get '-d'
      shift && description_config=$@
      save_config_file $force $name_config "$description_config"
      ;;
    --ls)
      list_configs
      ;;
    *)
      complain "Unknown option"
      exit 22 #EINVAL
      ;;
  esac
}

#!/bin/bash

. src/kwio.sh --source-only
. src/kwlib.sh --source-only

# List of dependences per distro
arch_packages=(qemu bash git tar python-docutils pulseaudio libpulse dunst python-sphinx)
debian_packages=(qemu git tar python3-docutils pulseaudio-utils dunst sphinx-doc)

SILENT=1
VERBOSE=0
FORCE=0
PREFIX="$HOME/.local"

declare -r app_name="kw"

##
## Following are the install paths
##
# Paths used during the installation process
declare -r kwbinpath="$PREFIX/bin/kw"
declare -r binpath="$PREFIX/bin"
declare -r libdir="$PREFIX/lib/$app_name"
declare -r sharedir="$PREFIX/share/"
declare -r sharedocdir="$sharedir/doc"
declare -r sharemandir="$sharedir/man"
declare -r sharesounddir="$sharedir/sound/kw"
declare -r etcdir="$PREFIX/etc/kw"
# User specific data
declare -r datadir="$HOME/.$app_name"
declare -r cachedir="$HOME/.cache/$app_name"

##
## Source code references
##
declare -r SRCDIR="src"
declare -r MAN="documentation/man/"
declare -r CONFIG_DIR="etc"
declare -r INSTALLTO="$PREFIX"
declare -r KW_CACHE_DIR="$HOME/.cache/$app_name"

declare -r SOUNDS="sounds"
declare -r BASH_AUTOCOMPLETE="bash_autocomplete"
declare -r DOCUMENTATION="documentation"

declare -r FISH_CONFIG_PATH="$HOME/.config/fish"
declare -r FISH_COMPLETION_PATH="$FISH_CONFIG_PATH/completions"

declare -r CONFIGS_PATH="configs"

function check_dependencies()
{
  local distro=$(detect_distro "/")
  local package_list=""
  local cmd=""

  if [[ "$distro" =~ "arch" ]]; then
    for package in "${arch_packages[@]}"; do
      installed=$(pacman -Qs "$package" > /dev/null)
      [[ "$?" != 0 ]] && package_list="$package $package_list"
    done
    cmd="pacman -S $package_list"
  elif [[ "$distro" =~ "debian" ]]; then
    for package in "${debian_packages[@]}"; do
      installed=$(dpkg-query -W --showformat='${Status}\n' "$package" 2>/dev/null | grep -c "ok installed")
      [[ "$installed" -eq 0 ]] && package_list="$package $package_list"
    done
    cmd="apt install $package_list"
  else
    warning "Unfortunately, we do not have official support for your distro (yet)"
    warning "Please, try to find the following packages: ${arch_packages[@]}"
    return 0
  fi

  if [[ ! -z "$package_list"  ]]; then
    if [[ "$FORCE" == 0 ]]; then
      if [[ $(ask_yN "Can we install the following dependencies $package_list ?") =~ "0" ]]; then
        return 0
      fi
    fi
    eval "sudo $cmd"
  fi
}

# TODO
# Originally, kw get installed in the ~/.config and add the kw binary in the
# path. We changed it; however, we keep this function for supporting the
# migration from the old version to the new one.
function remove_kw_from_PATH_variable()
{
  local new_path=""
  local needs_update=0

  IFS=':' read -ra ALL_PATHS <<< "$PATH"
  for path in "${ALL_PATHS[@]}"; do
    if [[ "$path" =~ "/kw" ]]; then
      needs_update=1
      continue
    fi
    # The first interaction introduce one extra ':'
    new_path="$new_path:$path"
  done

  if [[ "$needs_update" != 0 ]]; then
    # Drop ':' introduced in the above loop
    PATH="${new_path:1}"
    export PATH
  fi
}

function update_path()
{
  local new_path=""

  IFS=':' read -ra ALL_PATHS <<< "$PATH"
  for path in "${ALL_PATHS[@]}"; do
    [[ "$path" -ef "$binpath" ]] && return
  done

  echo "PATH=$HOME/.local/bin:\$PATH # kw" >> "$HOME/.bashrc"
}

function update_current_bash()
{
  exec /bin/bash
}

function cmd_output_manager()
{
  local cmd="$1"
  local unsilent_flag="$2"

  if [[ -z "$unsilent_flag" ]]; then
    cmd="$cmd >/dev/null"
  else
    echo "$cmd"
  fi

  eval "$cmd"
  return "$?"
}

function usage()
{
  say "usage: ./setup.sh option"
  say ""
  say "Where option may be one of the following:"
  say "--help      | -h     Display this usage message"
  say "--install   | -i     Install $app_name"
  say "--uninstall | -u     Uninstall $app_name"
  say "--verbose            Explain what is being done"
  say "--force              Never prompt"
  say "--completely-remove  Remove $app_name and all files under its responsibility"
  say "--docs               Build $app_name's documentation as HTML pages into ./build"
}

function confirm_complete_removal()
{
  warning "This operation will completely remove all files related to kw,"
  warning "including the kernel '.config' files under its controls."
  if [[ $(ask_yN "Do you want to proceed?") =~ "0" ]]; then
    exit 0
  fi
}

function clean_legacy()
{
  local trash=$(mktemp -d)
  local completely_remove="$1"

  local toDelete="$app_name"
  eval "sed -i '/\<$toDelete\>/d' $HOME/.bashrc"

  # Remove kw binary
  [[ -f "$kwbinpath" ]] && mv "$kwbinpath" "$trash"

  # Remove kw libriary
  [[ -d "$libdir" ]] && mv "$libdir" "$trash/lib"

  # Remove doc dir
  [[ -d "$sharedocdir" ]] && mv "$sharedocdir" "$trash"

  # Remove man
  [[ -d "$sharemandir" ]] && mv "$sharemandir" "$trash"

  # Remove sound files
  [[ -d "$sharesounddir" ]] && mv "$sharesounddir" "$trash/sound"

  # Remove etc files
  [[ -d "$etcdir" ]] && mv "$etcdir" "$trash/etc"

  # Completely remove user data
  if [[ "$completely_remove" =~ "-d" ]]; then
    mv "$datadir" "$trash/userdata"
    return 0
  fi

  # TODO: Remove me one day
  # Some old version of kw relies on a directory name `kw` at ~/, we changed
  # this behaviour but we added the below code to clean up those legacy system.
  # One day we could get rid of this code
  if [[ -d "$HOME/kw" ]]; then
    rm -rf "$HOME/kw/"
  fi

  # Remove kw from PATH variable
  remove_kw_from_PATH_variable
}

function setup_config_file()
{
  local config_files_path="$etcdir"
  local config_file_template="$config_files_path/kworkflow_template.config"
  local global_config_name="kworkflow.config"

  if [[ -f "$config_file_template" ]]; then
    cp "$config_file_template" "$config_files_path/$global_config_name"
    sed -i -e "s/USERKW/$USER/g" -e "s,SOUNDPATH,$sharesounddir,g" \
           -e "/^#?.*/d" "$config_files_path/$global_config_name"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      return "$ret"
    fi
  else
    warning "setup could not find $config_file_template"
    return 2
  fi
}

function synchronize_fish()
{
    local kw_fish_path="set -gx PATH $PATH:$kwbinpath"

    say "Fish detected. Setting up fish support."
    mkdir -p "$FISH_COMPLETION_PATH"
    cmd_output_manager "rsync -vr $SRCDIR/kw.fish $FISH_COMPLETION_PATH/kw.fish"

    if ! grep -F "$kw_fish_path" "$FISH_CONFIG_PATH"/config.fish > /dev/null ; then
       echo "$kw_fish_path" >> "$FISH_CONFIG_PATH"/config.fish
    fi
}

function ASSERT_IF_NOT_EQ_ZERO()
{
  local msg="$1"
  local ret="$2"
  if [[ "$ret" != 0 ]]; then
    complain "$msg"
    exit "$ret"
  fi
}

# Synchronize .vim and .vimrc with repository.
function synchronize_files()
{
  verbose=""

  [[ "$VERBOSE" == 1 ]] && verbose=1

  # Copy kw main file
  mkdir -p "$binpath"
  cmd_output_manager "cp $app_name $binpath" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'cp $app_name $binpath' failed" "$?"

  sed -i -e "s,##KW_INSTALL_PREFIX_TOKEN##,$PREFIX/,g" "$binpath/$app_name"
  sed -i -e "/##BEGIN-DEV-MODE##/,/##END-DEV-MODE##/ d" "$binpath/$app_name"

  # Lib files
  mkdir -p "$libdir"
  cmd_output_manager "rsync -vr $SRCDIR/ $libdir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $SRCDIR $libdir' failed" "$?"

  # Sound files
  mkdir -p "$sharesounddir"
  cmd_output_manager "rsync -vr $SOUNDS/ $sharesounddir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $SOUNDS $sharesounddir' failed" "$?"

  # Documentation files
  mkdir -p "$sharedocdir"
  cmd_output_manager "rsync -vr $DOCUMENTATION/ $sharedocdir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $DOCUMENTATION $sharedocdir' failed" "$?"

  # man file
  mkdir -p "$sharemandir"
  cmd_output_manager "rsync -vr $MAN $sharemandir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $DOCUMENTATION $sharemandir' failed" "$?"

  # etc files
  mkdir -p "$etcdir"
  cmd_output_manager "rsync -vr $CONFIG_DIR/ $etcdir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $CONFIG_DIR $INSTALLTO' failed" "$?"

  # User data
  mkdir -p "$datadir"
  mkdir -p "$datadir/statistics"
  mkdir -p "$datadir/configs"

  # Copy and setup global config file
  setup_config_file
  ASSERT_IF_NOT_EQ_ZERO "Config file failed" "$?"

  if [ -f "$HOME/.bashrc" ]; then
      # Add to bashrc
      echo "# $app_name" >> "$HOME/.bashrc"
      echo "source $libdir/$BASH_AUTOCOMPLETE.sh" >> "$HOME/.bashrc"
      update_path
  else
      warning "Unable to find a shell."
  fi

  if command -v fish &> /dev/null; then
      synchronize_fish
  fi

  say "$SEPARATOR"
  # Create ~/.cache/kw for support some of the operations
  mkdir -p "$cachedir"
  say "$app_name installed into $PREFIX"
  warning " -> For a better experience with kw, please, open a new terminal."
}

function update_version()
{
  local head_hash=$(git rev-parse --short HEAD)
  local branch_name=$(git rev-parse --short --abbrev-ref HEAD)
  local base_version=$(cat "$libdir/VERSION" | head -n 1)

  cat > "$libdir/VERSION" <<EOF
$base_version
Branch: $branch_name
Commit: $head_hash
EOF
}

function install_home()
{
  # Check Dependencies
  say "Checking dependencies ..."
  check_dependencies
  # First clean old installation
  clean_legacy
  # Synchronize source files
  say "Installing ..."
  synchronize_files
  # Update version based on the current branch
  update_version
}

# Options
for arg do
  shift
  if [ "$arg" = "--verbose" ]; then
    VERBOSE=1
    continue
  fi
  if [ "$arg" = "--force" ]; then
    FORCE=1
    continue
  fi
  if [[ "$arg" =~ "--prefix=" ]]; then
    PREFIX=${arg#*=}
    continue
  fi
  set -- "$@" "$arg"
done

case "$1" in
  --install | -i)
    install_home
    #update_current_bash
    ;;
  --uninstall | -u)
    clean_legacy
    say "kw was removed."
    ;;
    # ATTENTION: This option is dangerous because it completely removes all files
    # related to kw, e.g., '.config' file under kw controls. For this reason, we do
    # not want to add a short version, and the user has to be sure about this
    # operation.
  --completely-remove)
    confirm_complete_removal
    clean_legacy "-d"
    ;;
  --help | -h)
    usage
    ;;
  --docs)
    sphinx-build -b html documentation/ build
    ;;
  *)
    complain "Invalid number of arguments"
    exit 1
    ;;
esac

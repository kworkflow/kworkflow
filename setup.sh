#!/bin/bash
KW_LIB_DIR='src'
. 'src/kw_include.sh' --source-only
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

SILENT=1
VERBOSE=0
FORCE=0
SKIPCHECKS=0

declare -r app_name='kw'

##
## Following are the install paths
##
# Paths used during the installation process
declare -r kwbinpath="$HOME/.local/bin/$app_name"
declare -r binpath="$HOME/.local/bin"
declare -r libdir="$HOME/.local/lib/$app_name"
declare -r sharedir="${XDG_DATA_HOME:-"$HOME/.local/share"}/$app_name"
declare -r docdir="$sharedir/doc"
declare -r mandir="$sharedir/man"
declare -r sounddir="$sharedir/sound"
declare -r datadir="${XDG_DATA_HOME:-"$HOME/.local/share"}/$app_name"
declare -r etcdir="${XDG_CONFIG_HOME:-"$HOME/.config"}/$app_name"
declare -r cachedir="${XDG_CACHE_HOME:-"$HOME/.cache/$app_name"}"
declare -r dot_configs_dir="${datadir}/configs"

##
## Source code references
##
declare -r SRCDIR='src'
declare -r MAN='documentation/man/'
declare -r CONFIG_DIR='etc/'
declare -r KW_CACHE_DIR="$cachedir"

declare -r SOUNDS='sounds'
declare -r BASH_AUTOCOMPLETE='bash_autocomplete'
declare -r DOCUMENTATION='documentation'

declare -r CONFIGS_PATH='configs'

function check_dependencies()
{
  local package_list=''
  local pip_package_list=''
  local cmd=''
  local distro

  distro=$(detect_distro '/')

  if [[ "$distro" =~ 'arch' ]]; then
    while IFS='' read -r package; do
      installed=$(pacman -Ql "$package" &> /dev/null)
      [[ "$?" != 0 ]] && package_list="$package $package_list"
    done < "$DOCUMENTATION/dependencies/arch.dependencies"
    cmd="pacman -S $package_list"
  elif [[ "$distro" =~ 'debian' ]]; then
    while IFS='' read -r package; do
      installed=$(dpkg-query -W --showformat='${Status}\n' "$package" 2> /dev/null | grep -c 'ok installed')
      [[ "$installed" -eq 0 ]] && package_list="$package $package_list"
    done < "$DOCUMENTATION/dependencies/debian.dependencies"
    cmd="apt install -y $package_list"
  elif [[ "$distro" =~ 'fedora' ]]; then
    while IFS='' read -r package; do
      installed=$(rpm -q "$package" &> /dev/null)
      [[ "$?" -ne 0 ]] && package_list="$package $package_list"
    done < "$DOCUMENTATION/dependencies/fedora.dependencies"
    cmd="dnf install -y $package_list"
  else
    warning 'Unfortunately, we do not have official support for your distro (yet)'
    warning 'Please, try to find the following packages:'
    warning "$(cat "$DOCUMENTATION/dependencies/arch.dependencies")"
    return 0
  fi

  if [[ -n "$package_list" ]]; then
    if [[ "$FORCE" == 0 ]]; then
      if [[ $(ask_yN "Can we install the following dependencies $package_list?") =~ '0' ]]; then
        return 0
      fi
    fi

    # Install system packages
    if [[ "$EUID" -eq 0 ]]; then
      eval "$cmd"
    else
      eval "sudo $cmd"
    fi
  fi

  while IFS='' read -r package; do
    python3 -c "import pkg_resources; pkg_resources.require('$package')" &> /dev/null
    [[ "$?" != 0 ]] && pip_package_list="\"$package\" $pip_package_list"
  done < "$DOCUMENTATION/dependencies/pip.dependencies"

  if [[ -n "$pip_package_list" ]]; then
    if [[ "$FORCE" == 0 ]]; then
      if [[ $(ask_yN "Can we install the following pip dependencies $pip_package_list?") =~ '0' ]]; then
        return 0
      fi
    fi

    # Install pip packages
    cmd="pip install $pip_package_list"
    eval "$cmd"
  fi
}

# TODO
# Originally, kw get installed in the ~/.config and add the kw binary in the
# path. We changed it; however, we keep this function for supporting the
# migration from the old version to the new one.
function remove_kw_from_PATH_variable()
{
  local new_path=''
  local needs_update=0

  IFS=':' read -ra ALL_PATHS <<< "$PATH"
  for path in "${ALL_PATHS[@]}"; do
    if [[ "$path" =~ '/kw' ]]; then
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
  local shellrc=${1:-'.bashrc'}

  IFS=':' read -ra ALL_PATHS <<< "$PATH"
  for path in "${ALL_PATHS[@]}"; do
    [[ "$path" -ef "$binpath" ]] && return
  done

  safe_append "PATH=${HOME}/.local/bin:\$PATH # kw" "${HOME}/${shellrc}"
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
    printf '%s\n' "$cmd"
  fi

  eval "$cmd"
  return "$?"
}

# TODO: Remove me one day
# KW used git to track saved configs from kernel-config-manager.
# It changed so this function removes the unused .git folder from
# the dot_configs_dir
function remove_legacy_git_from_kernel_config_manager()
{
  local -r original_path="$PWD"

  [[ ! -d "${dot_configs_dir}"/.git ]] && return

  if pushd "$dot_configs_dir" &> /dev/null; then
    rm -rf .git/
    popd &> /dev/null || {
      complain "Could not return to original path from dot_configs_dir=$dot_configs_dir"
      exit 1
    }
  else
    complain 'Could not cd to dot_configs_dir'
    return
  fi
}

function usage()
{
  say 'usage: ./setup.sh option'
  say ''
  say 'Where option may be one of the following:'
  say '--help      | -h     Display this usage message'
  say "--install   | -i     Install $app_name"
  say "--uninstall | -u     Uninstall $app_name"
  say '--skip-checks        Skip checks (use this when packaging)'
  say '--verbose            Explain what is being done'
  say '--force              Never prompt'
  say "--completely-remove  Remove $app_name and all files under its responsibility"
  say "--docs               Build $app_name's documentation as HTML pages into ./build"
}

function confirm_complete_removal()
{
  warning 'This operation will completely remove all files related to kw,'
  warning 'including the kernel '.config' files under its controls.'
  if [[ $(ask_yN 'Do you want to proceed?') =~ '0' ]]; then
    exit 0
  fi
}

# This function moves the folders from the old directory structure to
# folders of the new one.
function legacy_folders()
{
  local prefix="$HOME/.local"

  if [[ -d "$HOME/.kw" ]]; then
    say 'Found an obsolete installation of kw:'
    say "Moving files in $HOME/.kw/ to $datadir..."
    rsync -a "$HOME/.kw/" "$datadir"

    rm -rf "$HOME/.kw"
  fi

  [[ -d "$prefix/share/doc" ]] && rm -rf "$prefix/share/doc"
  [[ -f "$prefix/share/man/kw.rst" ]] && rm -rf "$prefix/share/man/kw.rst"
  [[ -d "$prefix/share/sound/kw" ]] && rm -rf "$prefix/share/sound/kw"
  [[ -d "$prefix/share/man" ]] && rm -rf "$prefix/share/man"
  [[ -d "$prefix/share/sound" ]] && rm -rf "$prefix/share/sound"

  # Legacy global config
  if [[ -d "$prefix/etc/kw/" ]]; then
    say "Moving $prefix/etc/kw to $etcdir..."
    rsync -a "$prefix/etc/kw/" "$etcdir"
    # We already check "$prefix"
    # shellcheck disable=SC2115
    rm -rf "$prefix/etc"
  fi

}

function clean_legacy()
{
  local completely_remove="$1"
  local toDelete="$app_name"
  local trash

  trash=$(mktemp -d)

  eval "sed -i '/\<$toDelete\>/d' $HOME/.bashrc"

  # Remove kw binary
  [[ -f "$kwbinpath" ]] && mv "$kwbinpath" "$trash"

  # Remove kw libriary
  [[ -d "$libdir" ]] && mv "$libdir" "$trash/lib"

  # Remove doc dir
  [[ -d "$docdir" ]] && mv "$docdir" "$trash"

  # Remove man
  [[ -d "$mandir" ]] && mv "$mandir" "$trash"

  # Remove sound files
  [[ -d "$sounddir" ]] && mv "$sounddir" "$trash/sound"

  # Remove etc files
  [[ -d "$etcdir" ]] && mv "$etcdir" "$trash/etc"

  # Completely remove user data
  if [[ "$completely_remove" =~ '-d' ]]; then
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
  verbose=''

  [[ "$VERBOSE" == 1 ]] && verbose=1

  # Copy kw main file
  mkdir -p "$binpath"
  cmd_output_manager "cp $app_name $binpath" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'cp $app_name $binpath' failed" "$?"

  # Lib files
  mkdir -p "$libdir"
  cmd_output_manager "rsync -vr $SRCDIR/ $libdir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $SRCDIR $libdir' failed" "$?"

  # Sound files
  mkdir -p "$sounddir"
  cmd_output_manager "rsync -vr $SOUNDS/ $sounddir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $SOUNDS $sounddir' failed" "$?"
  ## TODO: Remove me one day
  # Old kworkflow.config uses complete.wav instead of bell
  ln -s "$sounddir/bell.wav" "$sounddir/complete.wav"

  # Documentation files
  mkdir -p "$docdir"
  cmd_output_manager "rsync -vr $DOCUMENTATION/ $docdir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $DOCUMENTATION $docdir' failed" "$?"

  # man file
  mkdir -p "$mandir"
  cmd_output_manager "sphinx-build -nW -b man $DOCUMENTATION $mandir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "'sphinx-build -nW -b man $DOCUMENTATION $mandir' failed" "$?"

  # etc files
  mkdir -p "$etcdir"
  cmd_output_manager "rsync -vr $CONFIG_DIR/ $etcdir" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $CONFIG_DIR/ $etcdir $verbose' failed" "$?"

  setup_global_config_file

  # User data
  mkdir -p "$datadir"
  mkdir -p "$datadir/statistics"
  mkdir -p "$datadir/configs"

  if command_exists 'bash'; then
    # Add tabcompletion to bashrc
    if [[ -f "$HOME/.bashrc" || -L "$HOME/.bashrc" ]]; then
      append_bashcompletion '.bashrc'
      update_path
    else
      warning 'Unable to find a .bashrc file.'
    fi
  fi

  if command_exists 'zsh'; then
    # Add tabcompletion to zshrc
    if [[ -f "${HOME}/.zshrc" || -L "${HOME}/.zshrc" ]]; then
      safe_append '# Enable bash completion for zsh' "${HOME}/.zshrc"
      safe_append 'autoload bashcompinit && bashcompinit' "${HOME}/.zshrc"
      append_bashcompletion '.zshrc'
      update_path '.zshrc'
    else
      warning 'Unable to find a .zshrc file.'
    fi
  fi

  say "$SEPARATOR"
  # Create ~/.cache/kw for support some of the operations
  mkdir -p "$cachedir"
  say "$app_name installed into $HOME"
  warning ' -> For a better experience with kw, please, open a new terminal.'
}

function append_bashcompletion()
{
  local shellrc="$1"

  safe_append "# ${app_name}" "${HOME}/${shellrc}"
  safe_append "source ${libdir}/${BASH_AUTOCOMPLETE}.sh" "${HOME}/${shellrc}"
}

function safe_append()
{
  if [[ $(grep -c -x "$1" "$2") == 0 ]]; then
    printf '%s\n' "$1" >> "$2"
  fi
}

function update_version()
{
  local head_hash
  local branch_name
  local base_version

  head_hash=$(git rev-parse --short HEAD)
  branch_name=$(git rev-parse --short --abbrev-ref HEAD)
  base_version=$(head -n 1 "$libdir/VERSION")

  cat > "$libdir/VERSION" << EOF
$base_version
Branch: $branch_name
Commit: $head_hash
EOF
}

function install_home()
{
  # Check Dependencies
  if [[ "$SKIPCHECKS" == 0 ]]; then
    say 'Checking dependencies ...'
    check_dependencies
  fi
  # Move old folder structure to new one
  legacy_folders
  # First clean old installation
  clean_legacy
  # Synchronize source files
  say 'Installing ...'
  synchronize_files
  # Remove old git repo to manage .config files
  remove_legacy_git_from_kernel_config_manager
  # Update version based on the current branch
  update_version
}

function setup_global_config_file()
{
  local config_files_path="$etcdir"
  local config_file_template="$config_files_path/notification_template.config"
  local global_config_name='notification.config'

  if [[ -f "$config_file_template" ]]; then
    # Default config
    cp "$config_file_template" "$config_files_path/notification.config"
    sed -i -e "s,SOUNDPATH,$sounddir,g" \
      -e "/^#?.*/d" "$config_files_path/notification.config"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      return "$ret"
    fi
  else
    warning "setup could not find $config_file_template"
    return 2
  fi
}

# Options
for arg; do
  shift
  if [ "$arg" = '--verbose' ]; then
    VERBOSE=1
    continue
  fi
  if [ "$arg" = '--force' ]; then
    FORCE=1
    continue
  fi
  if [ "$arg" = '--skip-checks' ]; then
    SKIPCHECKS=1
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
    say 'kw was removed.'
    ;;
    # ATTENTION: This option is dangerous because it completely removes all files
    # related to kw, e.g., '.config' file under kw controls. For this reason, we do
    # not want to add a short version, and the user has to be sure about this
    # operation.
  --completely-remove)
    confirm_complete_removal
    clean_legacy '-d'
    ;;
  --help | -h)
    usage
    ;;
  --docs)
    check_dependencies
    sphinx-build -nW -b html documentation/ build
    ;;
  *)
    complain 'Invalid number of arguments'
    usage
    exit 1
    ;;
esac

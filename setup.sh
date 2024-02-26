#!/bin/bash
KW_LIB_DIR='src'
. 'src/lib/kw_include.sh' --source-only
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_db.sh"
include "${KW_LIB_DIR}/help.sh"

SILENT=1
VERBOSE=0
FORCE=0
SKIPCHECKS=0
SKIPDOCS=0
SYSTEMWIDE=0
ENABLE_TRACING=0

declare -r app_name='kw'

##
## Following are the install paths
##
# Paths used during the installation process
declare BINDIR="${HOME}/.local/bin"
declare LIBDIR="${HOME}/.local/lib/${app_name}"
declare KWBINPATH="${BINDIR}/${app_name}"
declare ETCDIR="${XDG_CONFIG_HOME:-"${HOME}/.config"}/${app_name}"
declare SHAREDIR="${XDG_DATA_HOME:-"${HOME}/.local/share"}/${app_name}"
declare DOCDIR="${SHAREDIR}/doc"
declare MANDIR="${SHAREDIR}/man"
declare SOUNDDIR="${SHAREDIR}/sound"
declare DATABASEDIR="${SHAREDIR}/database"
declare -r DATADIR="${XDG_DATA_HOME:-"${HOME}/.local/share"}/${app_name}"
declare -r CACHEDIR="${XDG_CACHE_HOME:-"${HOME}/.cache/"}/${app_name}"
declare -r TRACINGDIR="${DATADIR}/tracing"
declare -r DOTCONFIGDIR="${DATADIR}/configs"

##
## Source code references
##
declare -r BASH_AUTOCOMPLETE='bash_autocomplete'
declare -r CONFIG_DIR='etc/'
declare -r CONFIGS_PATH='configs'
declare -r DATABASE='database'
declare -r DOCS_VIRTUAL_ENV='docs_virtual_env'
declare -r DOCUMENTATION='documentation'
declare -r KW_CACHE_DIR="$CACHEDIR"
declare -r MAN='documentation/man/'
declare -r SOUNDS='sounds'
declare -r SRCDIR='src'
declare -r TRACING_CODE_EXCERPTS_DIR='tracing/code_excerpts'

function check_dependencies()
{
  local package_list=''
  local cmd=''
  local distro
  local ret

  distro=$(detect_distro '/')

  if [[ "$distro" =~ 'arch' ]]; then
    while IFS='' read -r package; do
      installed=$(pacman -Ql "$package" &> /dev/null)
      [[ "$?" != 0 ]] && package_list="$package $package_list"
    done < "$DOCUMENTATION/dependencies/arch.dependencies"
    cmd="pacman -Sy --noconfirm ${package_list}"
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
      if [[ $(ask_yN "The following packages are required: ${package_list}"$'\nMay we install them?') =~ '0' ]]; then
        complain 'Aborting kw installation...'
        exit 125 # ECANCELED
      fi
    fi

    # Install system packages
    if [[ "$EUID" -eq 0 ]]; then
      eval "$cmd"
    else
      eval "sudo $cmd"
    fi
    ret="$?"

    # Installation failed...
    if [[ "$ret" -ne 0 ]]; then
      complain '[ERROR] Dependencies installation has failed. Aborting kw installation...'
      exit "$ret"
    fi

  fi
}

function generate_documentation()
{
  local ret

  python3 -m venv "$DOCS_VIRTUAL_ENV"

  # Activate python virtual env
  source "${DOCS_VIRTUAL_ENV}/bin/activate"
  say 'Creating python virtual env...'
  cmd="pip --quiet --require-virtualenv install --requirement \"${DOCUMENTATION}/dependencies/pip.dependencies\""
  eval "$cmd"
  ret="$?"

  if [[ "$ret" == 0 ]]; then
    sphinx-build -nW -b html documentation/ build
  else
    complain 'Could not install pip dependencies'
  fi
  # Deactivate python virtual env
  deactivate

  if [[ -d "$DOCS_VIRTUAL_ENV" ]]; then
    rm --recursive "$DOCS_VIRTUAL_ENV"
  fi
  return "$ret"
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

  # there is no need to update the path if the installation is system wide
  if [[ "${SYSTEMWIDE}" == 1 ]]; then
    return
  fi

  IFS=':' read -ra ALL_PATHS <<< "$PATH"
  for path in "${ALL_PATHS[@]}"; do
    [[ "$path" -ef "$BINDIR" ]] && return
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
# the DOTCONFIGDIR
function remove_legacy_git_from_kernel_config_manager()
{
  local -r original_path="$PWD"

  [[ ! -d "${DOTCONFIGDIR}"/.git ]] && return

  if pushd "$DOTCONFIGDIR" &> /dev/null; then
    rm -rf .git/
    popd &> /dev/null || {
      complain "Could not return to original path from DOTCONFIGDIR=$DOTCONFIGDIR"
      exit 1
    }
  else
    complain 'Could not cd to DOTCONFIGDIR'
    return
  fi
}

function usage()
{
  say 'usage: ./setup.sh option'
  say ''
  say 'Where option may be one of the following:'
  say '--help               | -h    Display this usage message'
  say "--install            | -i    Install ${app_name}"
  say "--uninstall          | -u    Uninstall ${app_name}"
  say "--system             | -s    Install or uninstall ${app_name} system wide"
  say '--skip-checks        | -C    Skip checks (use this when packaging)'
  say '--skip-docs          | -D    Skip creation of man pages (use this when installing)'
  say '--verbose            | -v    Explain what is being done'
  say '--force              | -f    Never prompt'
  say "--completely-remove  | -r    Remove ${app_name} and all files under its responsibility"
  say "--docs               | -d    Build ${app_name}'s documentation as HTML pages into ./build"
  say "--enable-tracing     | -t    Install ${app_name} with tracing enabled (use it with --install)"
}

function confirm_complete_removal()
{
  warning 'This operation will completely remove all files related to kw,'
  warning 'including the kernel '.config' files under its controls.'
  if [[ "$FORCE" == 0 && $(ask_yN 'Do you want to proceed?') =~ '0' ]]; then
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
    say "Moving files in $HOME/.kw/ to $DATADIR..."
    rsync -a "$HOME/.kw/" "$DATADIR"

    rm -rf "$HOME/.kw"
  fi

  [[ -d "$prefix/share/doc" ]] && rm -rf "$prefix/share/doc"
  [[ -f "$prefix/share/man/kw.rst" ]] && rm -rf "$prefix/share/man/kw.rst"
  [[ -d "$prefix/share/sound/kw" ]] && rm -rf "$prefix/share/sound/kw"
  [[ -d "$prefix/share/man" ]] && rm -rf "$prefix/share/man"
  [[ -d "$prefix/share/sound" ]] && rm -rf "$prefix/share/sound"

  # Legacy global config
  if [[ -d "$prefix/etc/kw/" ]]; then
    say "Moving $prefix/etc/kw to $ETCDIR..."
    rsync -a "$prefix/etc/kw/" "$ETCDIR"
    # We already check "$prefix"
    # shellcheck disable=SC2115
    rm -rf "$prefix/etc"
  fi

}

function clean_legacy()
{
  local completely_remove="$1"
  local toDelete="$app_name"
  local manfiles=''
  local trash

  trash=$(mktemp -d)

  eval "sed -i '/\<$toDelete\>/d' $HOME/.bashrc"

  # Remove kw binary
  [[ -f "$KWBINPATH" ]] && mv "$KWBINPATH" "${trash}/kw"

  # Remove kw libriary
  [[ -d "$LIBDIR" ]] && mv "$LIBDIR" "${trash}/lib"

  # Remove doc dir
  [[ -d "$DOCDIR" ]] && mv "$DOCDIR" "${trash}/doc"

  # Remove man
  [[ -d "$MANDIR" ]] && manfiles="$MANDIR"
  [[ "${SYSTEMWIDE}" == 1 ]] && manfiles=$(find "$MANDIR" -maxdepth 1 -type f -name 'kw-*')
  [[ -n "$manfiles" ]] && mv "$manfiles" "${trash}/man"

  # Remove sound files
  [[ -d "$SOUNDDIR" ]] && mv "$SOUNDDIR" "${trash}/sound"

  # Remove etc files
  [[ -d "$ETCDIR" ]] && mv "$ETCDIR" "${trash}/etc"

  # Completely remove user data
  if [[ "$completely_remove" =~ '-d' ]]; then
    mv "${DATADIR}" "${trash}/userdata"
    mv "${CACHEDIR}" "${trash}/cache"
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
  mkdir -p "$BINDIR"
  if [[ "$ENABLE_TRACING" == 0 ]]; then
    cmd_output_manager "cp $app_name $BINDIR" "$verbose"
    ASSERT_IF_NOT_EQ_ZERO "The command 'cp $app_name $BINDIR' failed" "$?"
  else
    sync_main_kw_file_with_tracing "$app_name" "$BINDIR" "$TRACING_CODE_EXCERPTS_DIR"
    ASSERT_IF_NOT_EQ_ZERO 'Could not sync kw main file with tracing enabled' "$?"
  fi

  # Lib files
  mkdir -p "$LIBDIR"
  if [[ "$ENABLE_TRACING" == 0 ]]; then
    cmd_output_manager "rsync -vr $SRCDIR/ $LIBDIR" "$verbose"
    ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $SRCDIR $LIBDIR' failed" "$?"
  else
    sync_kw_lib_files_with_tracing "$SRCDIR" "$LIBDIR"
    ASSERT_IF_NOT_EQ_ZERO 'Could not sync kw library files with tracing enabled' "$?"
  fi

  # Sound files
  mkdir -p "$SOUNDDIR"
  cmd_output_manager "rsync -vr $SOUNDS/ $SOUNDDIR" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $SOUNDS $SOUNDDIR' failed" "$?"
  ## TODO: Remove me one day
  # Old kworkflow.config uses complete.wav instead of bell
  ln -s "$SOUNDDIR/bell.wav" "$SOUNDDIR/complete.wav"

  # Documentation files
  mkdir -p "$DOCDIR"
  cmd_output_manager "rsync -vr $DOCUMENTATION/ $DOCDIR" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $DOCUMENTATION $DOCDIR' failed" "$?"

  # man file
  if [[ "$SKIPDOCS" == 0 ]]; then
    mkdir -p "$MANDIR"

    python3 -m venv "$DOCS_VIRTUAL_ENV"

    # Activate python virtual env
    source "${DOCS_VIRTUAL_ENV}/bin/activate"
    say 'Creating python virtual env...'
    cmd="pip --quiet --require-virtualenv install --requirement \"${DOCUMENTATION}/dependencies/pip.dependencies\""
    eval "$cmd"
    cmd_output_manager "sphinx-build -nW -b man $DOCUMENTATION $MANDIR" "$verbose"
    ASSERT_IF_NOT_EQ_ZERO "'sphinx-build -nW -b man $DOCUMENTATION $MANDIR' failed" "$?"
    # Deactivate python virtual env
    deactivate

    if [[ -d "$DOCS_VIRTUAL_ENV" ]]; then
      rm -r "$DOCS_VIRTUAL_ENV"
    fi
  fi

  # etc files
  mkdir -p "$ETCDIR"
  cmd_output_manager "rsync -vr $CONFIG_DIR/ $ETCDIR" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync -vr $CONFIG_DIR/ $ETCDIR $verbose' failed" "$?"

  # Database files
  mkdir -p "${DATABASEDIR}"
  cmd_output_manager "rsync --verbose --recursive ${DATABASE}/ ${DATABASEDIR}" "$verbose"
  ASSERT_IF_NOT_EQ_ZERO "The command 'rsync --verbose --recursive ${DATABASE} ${DATABASEDIR}' failed" "$?"

  setup_global_config_file

  # User data
  mkdir -p "$DATADIR"
  mkdir -p "$DATADIR/statistics"
  mkdir -p "$DATADIR/configs"
  if [[ -x "${DATABASEDIR}/migrate_legacy_data_20220101.sh" ]]; then
    eval "${DATABASEDIR}/migrate_legacy_data_20220101.sh"
  else
    execute_sql_script "${DATABASEDIR}/kwdb.sql"
    if [[ "$?" != 0 ]]; then
      complain 'Creation of database schema has failed.'
    fi
  fi

  if command_exists 'bash'; then
    # Add tabcompletion to bashrc
    if [[ -f "$HOME/.bashrc" || -L "$HOME/.bashrc" ]]; then
      append_bashcompletion
      update_path
    else
      warning 'Unable to find a .bashrc file.'
    fi
  fi

  if command_exists 'zsh'; then
    # Add tabcompletion to zshrc
    if [[ -f "${HOME}/.zshrc" || -L "${HOME}/.zshrc" ]]; then
      remove_legacy_zshcompletion
      append_zshcompletion
      update_path '.zshrc'
    else
      warning 'Unable to find a .zshrc file.'
    fi
  fi

  say "$SEPARATOR"
  # Create ~/.cache/kw for support some of the operations
  mkdir -p "$CACHEDIR"

  # Create ~/.local/kw/tracing for storing tracing reports of kw executions
  if [[ "$ENABLE_TRACING" == 1 ]]; then
    mkdir --parents "$TRACINGDIR"
  fi

  if [[ "$SYSTEMWIDE" == 1 ]]; then
    say "${app_name} installed system-wide."
  else
    say "${app_name} installed into ${HOME}."
  fi
}

function append_bashcompletion()
{
  safe_append "# ${app_name}" "${HOME}/.bashrc"
  safe_append "source ${LIBDIR}/${BASH_AUTOCOMPLETE}.sh" "${HOME}/.bashrc"
}

function remove_legacy_zshcompletion()
{
  safe_remove '# Enable bash completion for zsh' "${HOME}/.zshrc"
  safe_remove 'autoload bashcompinit && bashcompinit' "${HOME}/.zshrc"
  safe_remove "source ${LIBDIR}/${BASH_AUTOCOMPLETE}.sh" "${HOME}/.zshrc"
}

function append_zshcompletion()
{
  safe_append "# ${app_name}" "${HOME}/.zshrc"
  safe_append "export fpath=(${LIBDIR} \$fpath)" "${HOME}/.zshrc"
  safe_append 'autoload compinit && compinit -i' "${HOME}/.zshrc"
}

function safe_append()
{
  if [[ $(grep -c -x "$1" "$2") == 0 ]]; then
    printf '%s\n' "$1" >> "$2"
  fi
}

function safe_remove()
{
  local preprocessed_pattern
  if [[ $(grep -c -x "$1" "$2") == 1 ]]; then
    # Escape any foward slash as to not conflict with sed
    preprocessed_pattern=$(printf '%s' "$1" | sed 's_/_\\/_g')
    sed -i "/^${preprocessed_pattern}\$/d" "$2"
  fi
}

function update_version()
{
  kworkflow_version_from_repo > "${libdir}/VERSION"
}

function use_system_wide_installation_directories()
{
  # the base path for the syste-wide installation
  local base_path='/usr/share'

  # modify the default installation paths
  LIBDIR="${base_path}/kw"
  DOCDIR="${base_path}/doc/kw/html"
  MANDIR="${base_path}/man/man1"
  SOUNDDIR="${base_path}/sounds/kw"

  # The exception is the ETC directory and the BIN path. System wide config
  # files are usually located at /etc and not at /usr while binary files are
  # usually at /usr/bin
  BINDIR="/usr/bin"
  KWBINPATH="${BINDIR}/${app_name}"
  ETCDIR="/etc/${app_name}"
}

# Ask for confirmation if KW seems to be already installed.
function confirm_reinstallation()
{
  if [[ -x "${KWBINPATH}" && "${FORCE}" == 0 ]]; then
    warning 'KW seems to be already installed!'
    if [[ $(ask_yN 'Do you want to proceed anyway?') =~ '0' ]]; then
      info 'Aborting kw installation...'
      exit 0
    fi
  fi
}

function install_kw()
{
  # confirm before attempting to reinstall if that is the case.
  confirm_reinstallation

  # Check Dependencies
  if [[ "$SKIPCHECKS" == 0 ]]; then
    say 'Checking dependencies ...'
    check_dependencies
  fi
  if [[ "$SYSTEMWIDE" == 0 ]]; then
    # Move old folder structure to new one
    legacy_folders
  fi
  # First clean old installation
  clean_legacy
  # Synchronize source files
  say 'Installing ...'
  synchronize_files
  # Remove old git repo to manage .config files
  remove_legacy_git_from_kernel_config_manager
  # Update version based on the current branch
  update_version
  if [[ "$SYSTEMWIDE" == 0 ]]; then
    # Show current environment in terminal
    setup_bashrc_to_show_current_kw_env
  fi

  warning ''
  warning '-> For a better experience with kw, please, open a new terminal.'
}

function setup_bashrc_to_show_current_kw_env()
{
  local config_file_template="${ETCDIR}/kw_prompt_current_env_name.sh"

  say ''
  say ' Note: If you want to see kw env in the prompt, add something like the below line to your PS1:'
  say ' PS1="${PS1/\\$/}" && PS1+="\$(kw_get_current_env_name)$ "'

  safe_append "source ${config_file_template}" "${HOME}/.bashrc"
}

function setup_global_config_file()
{
  local config_files_path="$ETCDIR"
  local config_file_template="$config_files_path/notification_template.config"
  local global_config_name='notification.config'

  if [[ -f "$config_file_template" ]]; then
    # Default config
    cp "$config_file_template" "$config_files_path/notification.config"
    sed -i -e "s,SOUNDPATH,$SOUNDDIR,g" \
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
  case "$arg" in
    --verbose | -v)
      VERBOSE=1
      continue
      ;;
    --force | -f)
      FORCE=1
      continue
      ;;
    --system | -s)
      SYSTEMWIDE=1
      continue
      ;;
    # Usually short lowercase options enable some behavior. Thus, the option -C
    # is uppercase to sign we disable the dependency-check behavior.
    --skip-checks | -C)
      SKIPCHECKS=1
      continue
      ;;
    # Similarly, the lowercase short option -D signs we disable the default
    # behavior of generating man pages.
    --skip-docs | -D)
      SKIPDOCS=1
      continue
      ;;
    --enable-tracing | -t)
      include 'tracing/tracing.sh'
      ENABLE_TRACING=1
      continue
      ;;
  esac
  set -- "$@" "$arg"
done

# if system wide, change the installation directories.
# This approach works both for installing and uninstalling KW.
if [[ "${SYSTEMWIDE}" == 1 ]]; then
  use_system_wide_installation_directories
fi

case "$1" in
  --install | -i)
    install_kw
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
  --completely-remove | -r)
    confirm_complete_removal
    clean_legacy '-d'
    ;;
  --help | -h)
    usage
    ;;
  --docs | -d)
    generate_documentation
    ;;
  *)
    complain 'Invalid number of arguments'
    usage
    exit 1
    ;;
esac

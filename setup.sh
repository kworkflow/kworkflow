#!/usr/bin/env bash
KW_LIB_DIR='src'
. 'src/kw_include.sh' --source-only
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

VERBOSE=0
FORCE=0
SKIPCHECKS=0
COMPLETELY_REMOVE=0
INSTALL=0
UNINSTALL=0
DOCS=0
SYSTEM_INSTALL=0
declare TRASH=''

declare -r KWORKFLOW='kw'

##
## Set install paths
##
# System paths used during the installation process
declare -r sysbindir="/bin"
declare -r syslibdir="/usr/local/lib/$KWORKFLOW"
declare -r syssharedir="/usr/local/share/$KWORKFLOW"
declare -r sysdocdir="$syssharedir/doc"
declare -r sysmandir="$syssharedir/man/man1"
declare -r syssounddir="$syssharedir/sound"
declare -r sysdatadir="$syssharedir"
declare -r sysetcdir="/etc/$KWORKFLOW"
declare -r syscachedir="/var/cache/$KWORKFLOW"

# Local paths used during the installation process
declare -r localbindir="$HOME/.local/bin"
declare -r locallibdir="$HOME/.local/lib/$KWORKFLOW"
declare -r localsharedir="${XDG_DATA_HOME:-"$HOME/.local/share"}/$KWORKFLOW"
declare -r localdocdir="$localsharedir/doc"
declare -r localmandir="$localsharedir/man"
declare -r localsounddir="$localsharedir/sound"
declare -r localdatadir="${XDG_DATA_HOME:-"$localsharedir"}/$KWORKFLOW"
declare -r localetcdir="${XDG_CONFIG_HOME:-"$HOME/.config"}/$KWORKFLOW"
declare -r localcachedir="${XDG_CACHE_HOME:-"$HOME/.cache/$KWORKFLOW"}"

##
## Source code references
##
declare -r CONFIG_DIR='etc/init_templates'

declare missing_deps=()
declare missing_pip_docs_deps=()

function check_dependencies()
{
  deps_type="${1:-runtime}"

  if [[ "$SKIPCHECKS" == 0 ]]; then
    say 'Checking dependencies ...'
  fi

  local -Ar needed_runtime_commands=(
    [qemu]=qemu-img
    [git]=git
    [tar]=tar
    [pulseaudio]=pulseaudio
    [dunst]=dunst
    [graphviz]=graphml2gv
    [virtualenv]=virtualenv
    [bzip2]=bzip2
    [lzip]=lzip
    [lzop]=lzop
    [pip]=pip
    [bc]=bc
    [perl]=perl
    [sqlite3]=sqlite3
    [pv]=pv
    [rsync]=rsync
  )
  local -r needed_docs_commands=(
    ['texlive-xetex']=xetex
    [librsvg]=rsvg-convert
    ['python-sphinx']=sphinx-build
    [graphviz]=rst2html
    [dvipng]=dvipng
    [imagemagick]=convert
  )

  if [[ "$deps_type" = 'runtime' ]]; then
    for cmd in "${!needed_runtime_commands[@]}"; do
      [[ $(command_exists "$cmd") ]] ||
        missing_deps+=("${needed_runtime_commands[$cmd]}")
    done

    printf '%s\n' \
      $'#!/usr/bin/env perl\nuse Authen::SASL;\nuse IO::Socket::SSL;' > \
      .test.pl

    chmod +x .test.pl
    if [[ ! $(./.test.pl) ]]; then
      missing_deps+=(perl-authen-sasl)
      missing_deps+=(perl-io-socket-ssl)
    fi

    rm -f .test.pl

    [[ "${#missing_deps[@]}" -gt 0 ]] &&
      return 1
  else
    for cmd in "${needed_docs_commands[@]}"; do
      [[ $(command_exists "$cmd") ]] || missing_deps+=("$cmd")
    done

    while IFS='' read -r package; do
      python3 -c "import pkg_resources; pkg_resources.require('$package')" &> /dev/null
      [[ $? != 0 ]] && missing_pip_docs_deps+=("$package")
    done < "documentation/dependencies/pip-docs.dependencies"

    [[ "${#missing_deps[@]}" -gt 0 ||
      "${#missing_pip_docs_deps[@]}" -gt 0 ]] &&
      return 1
  fi

  return 0
}

function install_dependencies()
{
  deps_type="${1:-runtime}"

  local package_list=()
  local cmd=''
  local docs_str=''
  local installed_cmd=''
  local distro

  check_dependencies "$deps_type"

  ret=$?

  [[ $ret = 0 ]] && return 0

  distro=$(detect_distro '/')
  supported_distros=(
    'arch'
    'debian'
    'fedora'
  )

  if [[ ! ${supported_distros[*]} =~ $distro ]]; then
    say 'User system not officially supported'
    say 'Please install these packages:'
    for pkg in "${!missing_deps[@]}"; do
      printf '%s\n' "  - $pkg (provides ${missing_deps[$pkg]})"
    done
    if [[ "$deps_type" = 'docs' ]]; then
      say 'And those pip packages:'
      for pkg in "${!missing_pip_docs_deps[@]}"; do
        printf '%s\n' "  - $pkg (provides ${missing_pip_docs_deps[$pkg]})"
      done
    fi
    return 1
  fi

  [[ "$deps_type" != 'runtime' ]] &&
    docs_str='-docs'

  if [[ "$distro" =~ 'arch' ]]; then
    installed_cmd="pacman -Qs"
    cmd="pacman -S ${package_list[*]}"
  elif [[ "$distro" =~ 'debian' ]]; then
    installed_cmd="dpkg-query -W --showformat='${Status}\n"
    cmd="apt install -y ${package_list[*]}"
  else
    installed_cmd="dnf list installed"
    cmd="dnf install -y ${package_list[*]}"
  fi

  while IFS='' read -r package; do
    installed=$(eval "${installed_cmd} ${package}" > /dev/null)
    [[ $? != 0 ]] && package_list+=("$package")
  done < "documentation/dependencies/${distro}${docs_str}.dependencies"

  if [[ "${#package_list[@]}" -gt 0 ]]; then
    if [[ "$FORCE" = 0 &&
      $(ask_yN "Can we install the following dependencies ${package_list[*]}?") = 0 ]]; then

      # Install system packages
      eval "sudo $cmd" || return $?
    fi
  else
    warning "Could not find missing packages"
  fi

  if [[ "$deps_type" = 'docs' ]]; then
    if [[ "${#missing_pip_docs_deps[@]}" -gt 0 ]]; then
      if [[ "$FORCE" = 0 &&
        $(ask_yN "Can we install the following pip dependencies ${missing_pip_docs_deps[*]}?") = 0 ]]; then

        # Install pip packages
        eval "pip install ${missing_pip_docs_deps[*]}" || return $?
      fi
    else
      warning "Could not find missing pip packages"
    fi
  fi

  return 0
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
    # Drop ':' introduced in the loop above
    PATH="${new_path:1}"
    export PATH
  fi
}

function update_path()
{
  local shellrc=${1:-'.bashrc'}

  IFS=':' read -ra ALL_PATHS <<< "$PATH"
  for path in "${ALL_PATHS[@]}"; do
    [[ "$path" -ef "$bindir" ]] && return
  done

  safe_append "PATH=$HOME/.local/bin:\$PATH # kw" "$HOME/$shellrc"
}

function cmd_output_manager()
{
  local cmd="$1"

  if [[ $VERBOSE = 1 ]]; then
    printf '%s\n' "$cmd"
  else
    cmd="$cmd >/dev/null"
  fi

  eval "$cmd"
  return $?
}

function usage()
{
  say 'usage: ./setup.sh option'
  say ''
  say 'Where option may be one of the following:'
  say '--help      | -h     Display this usage message'
  say "--install   | -i     Install $KWORKFLOW (defaults to local install)"
  say "--uninstall | -u     Uninstall $KWORKFLOW"
  say "--system    | -s     Install $KWORKFLOW to system"
  say '--skip-checks        Skip checks (use this when packaging)'
  say '--verbose   | -v     Explain what is being done'
  say '--force              Never prompt'
  say "--completely-remove  Remove $KWORKFLOW and all files under its responsibility"
  say "--docs               Build $KWORKFLOW's documentation as HTML pages into ./build"
}

function confirm_complete_removal()
{
  warning 'This operation will completely remove all files related to kw,'
  warning 'including the kernel .config files under its controls.'
  if [[ $(ask_yN 'Do you want to proceed?') = 1 ]]; then
    COMPLETELY_REMOVE=1
  else
    exit 0
  fi
}

# This function moves the folders from the old directory structure to
# folders of the new one.
function legacy_folders()
{
  local prefix="$HOME/.local"

  if [[ -d "$HOME/.kw" ]]; then
    if [[ "$COMPLETELY_REMOVE" = 0 ]]; then
      say 'Found an obsolete installation of kw:'
      say "Moving files in $HOME/.kw/ to $datadir..."
    fi
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

function clean_previous_install()
{
  [[ -z "$TRASH" ]] && TRASH=$(mktemp -d)

  [[ -e $HOME/.bashrc ]] &&
    eval "sed -i '/\<$KWORKFLOW\>/d' $HOME/.bashrc"

  # Remove kw binary
  [[ -f "$bindir/$KWORKFLOW" ]] && mv "$bindir/$KWORKFLOW" "$TRASH"

  # Remove kw library
  [[ -d "$libdir" ]] && mv "$libdir" "$TRASH/lib"

  # Remove doc dir
  [[ -d "$docdir" ]] && mv "$docdir" "$TRASH"

  # Remove man
  [[ -d "$mandir" ]] && mv "$mandir" "$TRASH"

  # Remove sound files
  [[ -d "$sounddir" ]] && mv "$sounddir" "$TRASH/sound"

  # Remove etc files
  [[ -d "$etcdir" ]] && mv "$etcdir" "$TRASH/etc"

  # TODO: Remove me one day
  # Some old version of kw relies on a directory name `kw` at ~/, we changed
  # this behaviour but we added the code below to clean up those legacy systems.
  # One day we could get rid of this code
  [[ -d "$HOME/$KWORKFLOW" ]] &&
    rm -rf "$HOME/${KWORKFLOW:?}"

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
  local cmds=(
    # Copy kw main file
    "cp $KWORKFLOW $bindir"
    # Lib files
    "rsync -vr src/ $libdir"
    # Sound files
    "rsync -vr sounds/ $sounddir"
    # Documentation files
    "rsync -vr documentation/ $docdir"
    # man file
    "sphinx-build -nW -b man documentation $mandir"
    # etc files
    "rsync -vr $CONFIG_DIR/ $etcdir"
  )
  for cmd in "${cmds[@]}"; do
    mkdir -p "${cmd##* }"
    cmd_output_manager "$cmd"
    ASSERT_IF_NOT_EQ_ZERO "The command '$cmd' failed" "$?"
  done
}

function append_bashcompletion()
{
  local shellrc="$1"
  local msg="# $KWORKFLOW"$'\n'"source $libdir/bash_autocomplete.sh"

  safe_append "$msg" "$HOME/$shellrc"
}

function safe_append()
{
  expression="$1"
  file="$2"

  [[ $(grep -cx "$expression" "$file") == 0 ]] &&
    printf '%s\n' "$expression" >> "$file"
}

function update_version()
{
  local head_hash
  local branch_name
  local base_version
  local prepend=''

  if [[ "$SYSTEM_INSTALL" = 1 ]]; then
    prepend="sudo --user=$(env | grep "SUDO_USER" | cut -d= -f2) "
  fi
  head_hash=$(eval "$prepend"git rev-parse --short HEAD)
  branch_name=$(eval "$prepend"git rev-parse --short --abbrev-ref HEAD)
  base_version=$(head -n 1 "$libdir/VERSION")

  cat > "$libdir/VERSION" << EOF
$base_version
Branch: $branch_name
Commit: $head_hash
EOF
}

function add_completions()
{
  if [[ "$SYSTEM_INSTALL" = 1 ]]; then
    user="$(env | grep 'SUDO_USER' | cut -d= -f2)"
  else
    user="$(whoami)"
  fi
  default_shell=$(grep -q "$user" /etc/passwd | cut -d: -f7)
  default_shell=$(basename "$default_shell")
  local -r supported_shells=(
    'bash'
    'zsh'
  )

  if [[ ! ${supported_shells[*]} = "$default_shell" ]]; then
    warning "User default shell not supported"
    return 1
  fi

  if [[ $default_shell = bash ]]; then
    grep -q zsh "$HOME/.bashrc"
    ret=$?
    if [[ -e "$HOME/.bashrc" ]]; then
      [[ $ret = 0 ]] && default_shell=zsh
    else
      warning 'Unable to find a .bashrc file.'
    fi
  fi

  if [[ $default_shell = bash ]]; then
    # Add tabcompletion to bashrc
    append_bashcompletion '.bashrc'
    update_path
  else
    # Add tabcompletion to zshrc
    if [[ -e "$HOME/.zshrc" ]]; then
      local zshcomp=$'# Enable bash completion for zsh\n'
      zshcomp+='autoload bashcompinit && bashcompinit'

      safe_append "$zshcomp" "$HOME/.zshrc"
      append_bashcompletion '.zshrc'
      update_path '.zshrc'
    else
      warning 'Unable to find a .zshrc file.'
    fi
  fi
}

function set_vars()
{
  var_locale="${1:-local}"
  vars=(
    bindir
    libdir
    sharedir
    docdir
    mandir
    sounddir
    datadir
    etcdir
    cachedir
  )
  for var in "${vars[@]}"; do
    eval "$var=\$${var_locale}${var}"
  done
}

function install()
{
  # Install
  say 'Installing ...'
  # Synchronize source files
  synchronize_files

  # User data
  mkdir -p "$datadir{,statistics,configs}"

  add_completions

  # Create ~/.cache/kw for support some of the operations
  mkdir -p "$cachedir"
  if [[ "$SYSTEM_INSTALL" = 1 ]]; then
    say "$KWORKFLOW installed to system"
  else
    say "$KWORKFLOW installed into $HOME"
  fi
  warning ' -> For a better experience with kw, please, open a new terminal.'
  # Update version based on the current branch
  update_version
}

function main()
{
  if [[ "$INSTALL" = 1 ||
    "$UNINSTALL" = 1 ]]; then
    # Move old folder structure to new one
    legacy_folders

    set_vars
    clean_previous_install

    if [[ -f "$bindir/$KWORKFLOW" ]]; then
      if [[ "$(whoami)" != root ]]; then
        warning 'Please run as root using `sudo -E`'
        exit
      fi
      set_vars sys
      clean_previous_install
    fi
  fi

  if [[ "$INSTALL" = 1 ]]; then
    check_dependencies
    if [[ "$SYSTEM_INSTALL" = 1 ]]; then
      if [[ "$(whoami)" != root ]]; then
        warning 'Please run as root using `sudo -E`'
        exit 1
      fi
      set_vars sys
    fi
    install
  elif [[ "$UNINSTALL" = 1 ]]; then
    [[ "$COMPLETELY_REMOVE" = 1 ]] &&
      confirm_complete_removal

    # Completely remove user data
    if [[ "$COMPLETELY_REMOVE" = 1 ]]; then
      mv "$localdatadir" "$TRASH/userdata"
      mv "$sysdatadir" "$TRASH/userdata"
    fi

    say 'kw was removed.'
    return 0
  fi

  if [[ "$DOCS" = 1 ]]; then
    check_dependencies docs
    sphinx-build -nW -b html documentation/ build
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install | -i)
      INSTALL=1
      shift
      ;;
    --uninstall | -u)
      UNINSTALL=1
      shift
      ;;
    --verbose | -v)
      VERBOSE=1
      shift
      ;;
    --force | -f)
      FORCE=1
      shift
      ;;
    --skip-checks)
      SKIPCHECKS=1
      shift
      ;;
    --system | -s)
      SYSTEM_INSTALL=1
      shift
      ;;
      # ATTENTION: This option is dangerous because it completely removes all files
      # related to kw, e.g., '.config' file under kw controls. For this reason, we do
      # not want to add a short version, and the user has to be sure about this
      # operation.
    --completely-remove)
      COMPLETELY_REMOVE=1
      UNINSTALL=1
      shift
      ;;
    --docs)
      DOCS=1
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      complain "Unrecognized argument $1"
      usage
      exit 1
      ;;
  esac
done

main

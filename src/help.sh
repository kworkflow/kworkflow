include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

function kworkflow_help()
{
  printf '%s\n' 'Usage: kw [options]' \
    '' \
    'The current supported targets are:' \
    '  Host - this machine' \
    '  Qemu - qemu machine' \
    '  Remote - machine reachable via the network' \
    '' \
    'Commands:' \
    '  backup - Save or restore kw data\n' \
    '  bd - Build and install modules' \
    '  build,b - Build kernel' \
    '  clear-cache - Clear files generated by kw' \
    '  codestyle,c - Apply checkpatch on directory or file' \
    '  configm,g - Manage config files' \
    '  deploy,d - Deploy a new kernel image to a target machine' \
    '  device - Show basic hardware information' \
    '  diff,df - Diff files' \
    '  drm - Set of commands to work with DRM drivers ' \
    '  explore,e - Explore string patterns' \
    '  help,h - displays this help mesage' \
    '  init - Initialize kworkflow config file' \
    '  maintainers,m - Get maintainers and mailing list' \
    '  man - Show manual pages' \
    '  pomodoro,p - kw pomodoro support' \
    '  ssh,s - SSH support' \
    '  statistics - Provide basic statistics related to daily development' \
    '  vars - Show variables' \
    '  version,--version,-v - show kw version'
  '  vm - Manage partitions created with qemu-nbd'
}

# Display the man documentation that is built on install
function kworkflow_man()
{
  feature="$1"
  flag=${2:-'SILENT'}
  doc="$KW_MAN_DIR"

  if [[ -z "$feature" ]]; then
    feature='kw'
  fi

  if [[ -r "$doc/$feature.1" ]]; then
    cmd_manager "$flag" "man -l $doc/$feature.1"
    exit "$?"
  fi

  complain "Couldn't find the man page for $feature!"
  exit 2 # ENOENT
}

function kworkflow_version()
{
  local version_path="$KW_LIB_DIR/VERSION"

  cat "$version_path"
}

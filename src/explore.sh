. $src_script_path/kwio.sh --source-only

function explore()
{
  if [[ "$#" -eq 0 ]]; then
    complain "Expected path or 'log'"
    exit 1
  fi
  case "$1" in
    log)
      (
        git log -S"$2" "${@:3}"
      );;
    *)
      (
        local path=${@:2}
        local regex=$1
        if [[ $# -eq 1 ]]; then
          path="."
          regex=$1
        fi
        git grep -e $regex -nI $path
      );;
  esac
}

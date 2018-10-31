. $src_script_path/miscellaneous.sh --source-only

function kworkflow-help()
{
  echo -e "Usage: kw [target] cmd"

  echo -e "\nThe current supported targets are:\n" \
       "\t host - this machine\n" \
       "\t qemu - qemu machine\n" \
       "\t arm - arm machine"

  echo -e "\nCommands:\n" \
    "\tbuild,b - Build Kernel and modules\n" \
    "\tinstall,i - Install modules\n" \
    "\tbi - Build and install modules\n" \
    "\tprepare,p - Deploy basic environment in the VM\n" \
    "\tnew,n - Install new Kernel image\n" \
    "\tssh,s - Enter in the vm\n" \
    "\tmount,mo - Mount partition with qemu-nbd\n" \
    "\tumount,um - Umount partition created with qemu-nbd\n" \
    "\tvars,v - Show variables\n" \
    "\tup,u - Wake up vm\n" \
    "\tcodestyle,c - Apply checkpatch on directory or file\n" \
    "\tmaintainers,m [-a|--authors] - Return the maintainers and\n" \
    "\t                             the mailing list. \"-a\" also\n" \
    "\t                             prints files authors\n" \
    "\texplore,e - Search for expression on git log or directory\n" \
    "\thelp,h - displays this help mesage"
}

function explore()
{
  if [[ "$#" -eq 0 ]]; then
    complain "Expected path or 'log'"
    return 1
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

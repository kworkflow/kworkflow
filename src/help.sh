. $src_script_path/kwio.sh --source-only

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
    "\thelp,h - displays this help mesage\n" \
    "\tman - Show manual"

  echo -e "\nkw config manager:\n" \
    "\tconfigm,g --save NAME [-d 'DESCRIPTION']\n" \
    "\tconfigm,g --ls - List config files under kw management\n"
}

# Display the man documentation using rst2man, or man kw if it is already
# installed to the system
function kworkflow-man()
{
    doc="$config_files_path/documentation/man"
    ret=0

    if ! man kw > /dev/null 2>&1; then
      if [ -x "$(command -v rst2man)" ]; then
        rst2man < $doc/kw.rst | man -l -
        ret=$?
      else
        complain "There's no man support"
        ret=1
      fi
      exit $ret
    fi

    man kw
}

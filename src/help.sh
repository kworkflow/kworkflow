. $KW_LIB_DIR/kwio.sh --source-only

function kworkflow-help()
{
  echo -e "Usage: kw [options]"

  echo -e "\nThe current supported targets are:\n" \
       "\t Host - this machine\n" \
       "\t Qemu - qemu machine\n" \
       "\t Remote - machine reachable via the network"

  echo -e "\nCommands:\n" \
    "\tinit - Initialize kworkflow config file\n" \
    "\tbuild,b - Build Kernel and modules\n" \
    "\tbd - Build and install modules\n" \
    "\tmount,mo - Mount partition with qemu-nbd\n" \
    "\tumount,um - Umount partition created with qemu-nbd\n" \
    "\tvars,v - Show variables\n" \
    "\tup,u - Wake up vm\n" \
    "\tcodestyle,c - Apply checkpatch on directory or file\n" \
    "\tmaintainers,m [-a|--authors] - Return the maintainers and\n" \
    "\t                             the mailing list. \"-a\" also\n" \
    "\t                             prints files authors\n" \
    "\thelp,h - displays this help mesage\n" \
    "\tman - Show manual\n"

  echo -e "kw explore:\n" \
    "\texplore,e STRING [PATH] - Search for STRING based in PATH (./ by default) \n" \
    "\texplore,e \"STR SRT\" [PATH] - Search for strings\n" \
    "\texplore,e --log STRING - Search for STRING on git log\n" \

  echo -e "kw config manager:\n" \
    "\tconfigm,g --save NAME [-d 'DESCRIPTION']\n" \
    "\tconfigm,g --ls - List config files under kw management\n" \
    "\tconfigm,g --get NAME - Get a config file based named *NAME*\n" \
    "\tconfigm,g --rm - Remove config labeled with *NAME*\n" \

  echo -e "kw ssh|s options:\n" \
    "\tssh|s [--script|-s="SCRIPT PATH"]\n" \
    "\tssh|s [--command|-c="COMMAND"]\n"

  echo -e "kw deploy|d installs kernel and modules:\n" \
    "\tdeploy,d --remote [REMOTE:PORT] [--reboot|-r] [--modules|-m]\n" \
    "\tdeploy,d --local [--reboot|-r] [--modules|-m]\n" \
    "\tdeploy,d --vm [--reboot|-r] [--modules|-m]\n"
}

# Display the man documentation using rst2man, or man kw if it is already
# installed to the system
function kworkflow-man()
{
    doc="$KW_SHARE_DIR/documentation/man"
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

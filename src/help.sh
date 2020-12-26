. "$KW_LIB_DIR/kwio.sh" --source-only

function kworkflow-help()
{
  echo -e "Usage: kw [options]"

  echo -e "\nThe current supported targets are:\n" \
       "\t Host - this machine\n" \
       "\t Qemu - qemu machine\n" \
       "\t Remote - machine reachable via the network"

  echo -e "\nCommands:\n" \
    "\tinit - Initialize kworkflow config file\n" \
    "\tbd - Build and install modules\n" \
    "\tmount,mo - Mount partition with qemu-nbd\n" \
    "\tumount,um - Umount partition created with qemu-nbd\n" \
    "\tvars,v - Show variables\n" \
    "\tup,u - Wake up vm\n" \
    "\tcodestyle,c - Apply checkpatch on directory or file\n" \
    "\tmaintainers,m [-a|--authors] - Return the maintainers and\n" \
    "\t                             the mailing list. \"-a\" also\n" \
    "\t                             prints files authors\n" \
    "\tclear-cache - Clear files generated by kw\n" \
    "\thelp,h - displays this help mesage\n" \
    "\tversion,--version,-v - show kw version\n" \
    "\tman - Show manual\n"

  echo -e "kw build:\n" \
    "\tbuild - Build kernel \n" \
    "\tbuild [--menu|-n] - Open kernel menu config\n" \

  echo -e "kw statistics:\n" \
    "\tstatistics [--day [YEAR/MONTH/DAY]\n" \
    "\tstatistics [--week [YEAR/MONTH/DAY]\n" \
    "\tstatistics [--month [YEAR/MONTH]\n" \
    "\tstatistics [--year [YEAR]] \n" \

  echo -e "kw explore:\n" \
    "\texplore,e STRING [PATH] - Search for STRING based in PATH (./ by default) \n" \
    "\texplore,e \"STR SRT\" [PATH] - Search for strings only in files under git control\n" \
    "\texplore,e --log,-l STRING - Search for STRING on git log\n" \
    "\texplore,e --grep,-g STRING - Search for STRING using the GNU grep tool\n" \
    "\texplore,e --all,-a STRING - Search for all STRING match under or not of git management.\n" \

  echo -e "kw config manager:\n" \
    "\tconfigm,g --save NAME [-d 'DESCRIPTION']\n" \
    "\tconfigm,g --list|-l - List config files under kw management\n" \
    "\tconfigm,g --get NAME - Get a config file based named *NAME*\n" \
    "\tconfigm,g --remove|-rm - Remove config labeled with *NAME*\n" \

  echo -e "kw ssh|s options:\n" \
    "\tssh|s [--script|-s="SCRIPT PATH"]\n" \
    "\tssh|s [--command|-c="COMMAND"]\n"

  echo -e "kw deploy|d installs kernel and modules:\n" \
    "\tdeploy,d [--remote [REMOTE:PORT]|--local|--vm] [--reboot|-r] [--modules|-m]\n" \
    "\tdeploy,d [--remote [REMOTE:PORT]|--local|--vm] [--uninstall|-u KERNEL_NAME]\n" \
    "\tdeploy,d [--remote [REMOTE:PORT]|--local|--vm] [--ls-line|-s] [--ls|-l]"
}

# Display the man documentation using rst2man, or man kw if it is already
# installed to the system
function kworkflow-man()
{
    doc="$KW_SHARE_MAN_DIR"
    ret=0

    if ! man kw > /dev/null 2>&1; then
      if [ -x "$(command -v rst2man)" ]; then
        rst2man < "$doc/kw.rst" | man -l -
        ret="$?"
      else
        complain "There's no man support"
        ret=1
      fi
      exit "$ret"
    fi

    man kw
}

function kworkflow_version()
{
  local version_path="$KW_LIB_DIR/VERSION"

  cat "$version_path"
}

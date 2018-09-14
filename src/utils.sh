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
    "\tmount - Mount partition with qemu-nbd\n" \
    "\tumount - Umount partition created with qemu-nbd\n" \
    "\tvars - Show variables\n" \
    "\tup,u - Wake up vm\n" \
    "\tcodestyle - Apply checkpatch on directory or file\n" \
    "\tmaintainers - Return the maintainers and the mailing list\n" \
    "\thelp"
}

. $src_script_path/vm.sh --source-only

function vm_modules_install
{
  check_local_configuration

  # Attention: The vm code have to be loaded before this function.
  # Take a look at the beginning of kworkflow.sh.
  vm_mount
  set +e
  make INSTALL_MOD_PATH=${configurations[mount_point]} modules_install
  release=$(make kernelrelease)
  say $release
  vm_umount
}

function vm_kernel_install
{
  check_local_configuration

  vm_mount
  set +e
  sudo -E make INSTALL_PATH=${configurations[qemu_mnt]}/boot
  release=$(make kernelrelease)
  vm_umount
}

function vm_new_release_deploy
{
  vm_modules_install
  vm_kernel_install
}

function host_new_release_deploy
{
  host_modules_install
  host_kernel_install
}

function new_release_deploy
{  
  target=$(get_deploy_target $@)

  if [ "$target" == "host" ]; then
    host_new_release_deploy
  else
    vm_new_release_deploy
  fi
}

function host_kernel_install
{
  if [ -e "/etc/arch-release" ]
  then
    sudo bash $src_script_path/deploy/arch.sh linuxkw
  else
    echo "Only Arch Linux is supported. You should install the kernel manually."
  fi
}

function host_modules_install
{
  sudo make modules_install
}

function mk_build
{
  local PARALLEL_CORES=1

  if [ -x "$(command -v nproc)" ] ; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi

  PARALLEL_CORES=$(( $PARALLEL_CORES * 2 ))

  say "make -j$PARALLEL_CORES $MAKE_OPTS"
  make -j$PARALLEL_CORES $MAKE_OPTS
}

function mk_install
{
  check_local_configuration

  # FIXME: validate arch and action
  if [ ${configurations[target]} == "arm" ] ; then
    export ARCH=arm CROSS_COMPILE="ccache arm-linux-gnu-"
  fi

  case "${configurations[target]}" in
    qemu)
      vm_modules_install
      ;;
    host)
      sudo -E make modules_install
      sudo -E make install
      ;;
  esac
}

# FIXME: Here is a legacy code, however it could be really nice if we fix it
function mk_send_mail
{
  echo -e " * checking git diff...\n"
  git diff
  git diff --cached

  echo -e " * Does it build? Did you test it?\n"
  read
  echo -e " * Are you using the correct subject prefix?\n"
  read
  echo -e " * Did you need/review the cover letter?\n"
  read
  echo -e " * Did you annotate version changes?\n"
  read
  echo -e " * Is git format-patch -M needed?\n"
  read
  echo -e " * Did you review --to --cc?\n"
  read
  echo -e " * dry-run it first!\n"


  SENDLINE="git send-email --dry-run "
  while read line
  do
    SENDLINE+="$line "
  done < emails

  echo $SENDLINE
}

# FIXME: Here we have a legacy code, check if we can remove it
function mk_export_kbuild
{
  check_local_configuration

  say "export KBUILD_OUTPUT=${configurations[build_dir]}/$TARGET"
  export KBUILD_OUTPUT=${configurations[build_dir]}/$TARGET
  mkdir -p $KBUILD_OUTPUT
}

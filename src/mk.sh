function kw::vm_modules_install
{
  # Attention: The vm code have to be loaded before this function.
  # Take a look at the beginning of kworkflow.sh.
  vm_mount
  set +e
  make INSTALL_MOD_PATH=$MOUNT_POINT modules_install
  release=$(make kernelrelease)
  kw::say $release
  kw::vm_umount
}

function kw::vm_kernel_install
{
  kw::vm_mount
  set +e
  sudo -E make INSTALL_PATH=$QEMU_MNT/boot
  release=$(make kernelrelease)
  kw::vm_umount
}

function kw::vm_new_release_deploy
{
  kw::vm_modules_install
  kw::vm_kernel_install
}

function kw::mk_build
{
  local PARALLEL_CORES=1

  if [ -x "$(command -v nproc)" ] ; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi

  PARALLEL_CORES=$(( $PARALLEL_CORES * 2 ))

  kw::say "make -j$PARALLEL_CORES $MAKE_OPTS"
  make -j$PARALLEL_CORES $MAKE_OPTS
}

function mk_install
{
  # FIXME: validate arch and action
  if [ $TARGET == "arm" ] ; then
    export ARCH=arm CROSS_COMPILE="ccache arm-linux-gnu-"
  fi

  case "$TARGET" in
    qemu)
      kw::vm_modules_install
      ;;
    host)
      sudo -E make modules_install
      sudo -E make install
      ;;
  esac
}

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

function kw::mk_export_kbuild
{
  kw::say "export KBUILD_OUTPUT=$BUILD_DIR/$TARGET"
  export KBUILD_OUTPUT=$BUILD_DIR/$TARGET
  mkdir -p $KBUILD_OUTPUT
}

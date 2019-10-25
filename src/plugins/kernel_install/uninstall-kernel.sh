#!/bin/bash

function uninstall-kernel()
{
  local target="$1"
  local kernelpath="/boot/vmlinuz-$target"
  local initrdpath="/boot/initrd.img-$target"
  local modulespath="/lib/modules/$target"
  local libpath="/var/lib/initramfs-tools/$target"

  if [ -z "$target" ]; then
    echo "No parameter, nothing to do"
    exit 0
  fi

  local today=$(date "+%Y-%m-%d-%T")
  local temp_rm="/tmp/$today"
  mkdir "$today"

  if [ -f "$kernelpath" ]; then
    echo "Removing: $kernelpath"
    mv "$kernelpath" "$temp_rm"
  else
    echo "Can't find $kernelpath"
  fi

  if [ -f "$kernelpath.old" ]; then
    echo "Removing: $kernelpath.old"
    mv "$kernelpath.old" "$temp_rm"
  else
    echo "Can't find $kernelpath.old"
  fi

  if [ -f "$initrdpath" ]; then
    echo "Removing: $initrdpath"
    mv "$initrdpath" "$temp_rm"
  else
    echo "Can't find: $initrdpath"
  fi

  if [[ -d "$modulespath" && "$modulespath" != "/lib/modules" ]]; then
    echo "Removing: $modulespath"
    mv "$modulespath" "$temp_rm"
  else
    echo "Can't find $modulespath"
  fi

  if [ -f "$libpath" ]; then
    echo "Removing: $libpath"
    mv "$libpath" "$temp_rm"
  else
    echo "Cant't find $libpath"
  fi
}

uninstall-kernel "$@"

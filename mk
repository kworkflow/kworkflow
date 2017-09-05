#!/bin/bash

BASE=$HOME/p/linux-trees
TREE=$BASE/linux
BUILD_DIR=$BASE/build-linux

QEMU_ARCH="x86_64"
QEMU="qemu-system-${QEMU_ARCH}"
QEMU_OPTS="-enable-kvm -smp 2 -m 1024"
VDISK="/home/padovan/p/vdisk3.qcow2"
QEMU_MNT="/mnt/qemu"

arch="qemu"

set -e

function vm_mount_old {
	sudo mount -o loop,offset=32256 $VDISK $QEMU_MNT
}

function vm_mount {
	sudo modprobe nbd max_part=63
	sudo qemu-nbd -c /dev/nbd0 $VDISK
	sudo partprobe /dev/nbd0
	sudo mount /dev/nbd0p1 $QEMU_MNT
}
function vm_umount {
	sudo umount $QEMU_MNT &
	sleep 3
	sudo qemu-nbd -d /dev/nbd0
	sudo killall -q qemu-nbd
}

function vm_modules_install {

	vm_mount
	set +e
	sudo -E make INSTALL_MOD_PATH=$QEMU_MNT modules_install
	release=$(make kernelrelease)
	echo $release
	sudo -E chroot $QEMU_MNT depmod -a $release
	vm_umount
}

function mk_kvm {
$QEMU -hda $VDISK \
	${QEMU_OPTS} \
	-kernel $BUILD_DIR/qemu/arch/x86/boot/bzImage \
	-append "root=/dev/sda1 debug console=ttyS0 console=ttyS1 console=tty1 drm.debug=0xff" \
	-net nic -net user,hostfwd=tcp::5555-:22 \
	-serial stdio \
	-device virtio-gpu-pci,virgl -display gtk,gl=on 2> /dev/null
}

function mk_build {
	make $MAKE_OPTS
}

function mk_install {
	case "$arch" in
		qemu)
			vm_modules_install
			;;
		host)
			sudo -E make modules_install
			sudo -E make install
			;;
	esac
}

function mk_help {
	echo -e "Usage: $0 [target] cmd"

	echo -e "\nThe current supported targets are:\n" \
	     "\t host - this machine\n" \
	     "\t qemu - qemu machine\n" \
	     "\t arm - arm machine"

	echo -e "\nCommands:\n" \
		"\texport\n" \
		"\tbuild,b\n" \
		"\tinstall,i\n" \
		"\tbi\n" \
		"\tboot\n" \
		"\thelp"
}

if [ "$#" -eq 2 ] ; then
	arch=$1
	action=$2
elif [ "$#" -eq 1 ] ; then
	action=$1
else
	#FIXME: improve msg
	echo "invalid args"
	exit 1
fi

# FIXME: validate arch and action

if [ $arch == "arm" ] ; then
	export ARCH=arm CROSS_COMPILE="ccache arm-linux-gnu-"
fi

export KBUILD_OUTPUT=$BUILD_DIR/$arch

case "$action" in
	export)
		echo "export KBUILD_OUTPUT=$BUILD_DIR/$arch"
		;;
	build|b)
		mk_build
		;;
	install|i)
		mk_install
		;;
	bi)
		mk_build
		mk_install
		;;
	boot)
		mk_kvm
		;;
	help)
		mk_help
		;;
	*)
		mk_help
		exit 1
esac

exit 0



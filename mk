#!/bin/bash

BASE=$HOME/p/linux-trees
BUILD_DIR=$BASE/build-linux

QEMU_ARCH="x86_64"
QEMU="qemu-system-${QEMU_ARCH}"
QEMU_OPTS="-enable-kvm -smp 2 -m 1024"
VDISK="/home/padovan/p/vdisk3.qcow2"
QEMU_MNT="/mnt/qemu"

TARGET="qemu"

set -e

function vm_modules_install {

	vm mount
	set +e
	sudo -E make INSTALL_MOD_PATH=$QEMU_MNT modules_install
	release=$(make kernelrelease)
	echo $release
	sudo -E chroot $QEMU_MNT  depmod -a $release
	vm umount
}

function mk_build {
	make $MAKE_OPTS
}

function mk_install {
	case "$TARGET" in
		qemu)
			vm_modules_install
			;;
		host)
			sudo -E make modules_install
			sudo -E make install
			;;
	esac
}

function mk_send_mail {

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
		"\tmail - create the git send-email line from the 'emails'"\
			  "in the current dir\n" \
		"\thelp"
}

if [ "$#" -eq 1 ] ; then
	action=$1
elif [ "$#" -eq 2 ] ; then
	TARGET=$1
	action=$2
else
	#FIXME: improve msg
	echo "invalid args"
	exit 1
fi

# FIXME: validate arch and action

if [ $TARGET == "arm" ] ; then
	export ARCH=arm CROSS_COMPILE="ccache arm-linux-gnu-"
fi

export KBUILD_OUTPUT=$BUILD_DIR/$TARGET
mkdir -p $KBUILD_OUTPUT

case "$action" in
	export)
		echo "export KBUILD_OUTPUT=$BUILD_DIR/$TARGET"
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
	mail)
		mk_send_mail
		;;
	help)
		mk_help
		;;
	*)
		mk_help
		exit 1
esac

exit 0



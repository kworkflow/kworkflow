#!/bin/bash

# TODO:
# - issue when there 2 signed-off-by from the same company
# - SOB count should ignore authors
#

AUTHOR="collabora"

FORMAT="<li><a href=\"https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=%H\">%s</a></li>"

SUBDIRS="arch block crypto  Documentation drivers firmware fs include init ipc  kernel  lib  mm net  samples scripts security sound tools usr  virt" 

DRMDIRS="amd arc arm armada ast bochs bridge cirrus drm_*.c etnaviv exynos fsl-dcu gma500 hisilicon i2c i810 i915 imx lib mediatek meson mga mgag200 msm mxsfb nouveau omapdrm panel pl111 qxl r128 radeon rcar-du rockchip savage scheduler selftests shmobile sis sti stm sun4i tdfx tegra tilcdc tinydrm ttm tve200 udl vc4 vgem via virtio vmwgfx zte"

function sum_commits {
	s=$(sed -e  "s/^ *\([0-9]\+\).*/+ \1/g" | tr -d '\n' | cut -c 2-)
	if [ "$s" == "" ] ; then
		echo 0
	else
		echo "$s" | bc
	fi
}

function get_names {
	COMMITS=$(git log --grep="$2.*$AUTHOR" --format=%H $1)
	NAMES=""
	for c in $COMMITS ; do
		NAME=$(git show $c | grep "$2.*$AUTHOR" | sed -e "s/^[ ]\+$2: \(.*\) <[a-z\.]*@[a-z\.]*>.*$/\1/g" | tr -d "\n")
		if [ "$2" = "Signed-off-by" ] ; then
			if git show $c | grep -q "Author: $NAME.*" ; then
				NAME=""
			fi
		fi

		if [ "$NAME" != "" ] ; then
			NAME="$NAME\n"
		fi

		NAMES+=$NAME
	done

	echo -e $NAMES | sort | uniq | grep "[A-Z]"
}

function find_commits {

	get_names $1 $2 | while read NAME ; do
		if [ "$NAME" = "" ] ; then
			continue
		fi

		COMMITS=$(git log --grep="$2: $NAME .*$AUTHOR" --format=%H $1)
		echo -n "$NAME ("
		git log --grep="$2: $NAME .*$AUTHOR" --format=%H $1 | wc -l | tr -d "\n"
		echo "):"
		
		for c in $COMMITS ; do
			git show --no-patch --format="$FORMAT" $c | cat
		done

		echo ""
	done
}

function find_commits_sob {

	get_names $1 $2 | while read NAME ; do
		if [ "$NAME" = "" ] ; then
			continue
		fi

		COMMITS=$(git log --perl-regexp --author="^((?!$NAME).*)$" \
			--grep "Signed-off-by: $NAME.*" --format=%H $1)
		echo -n "$NAME ("
		git log --perl-regexp --author="^((?!$NAME).*)$" \
			--grep "Signed-off-by: $NAME.*" --format=%H $1 | wc -l | tr -d "\n"
		echo "):"

		for c in $COMMITS ; do
			git show --no-patch --format="$FORMAT" $c | cat
		done

		echo ""
	done
}

function ks_report {
	echo "=== Authors summary ==="
	git shortlog -ns $1  --author=$AUTHOR | cat
	echo ""

	echo "=== Authors total commits ==="
	git shortlog -ns $1  --author=$AUTHOR | sum_commits
	echo ""

	echo "=== Reviewed-by names ==="
	get_names $1 "Reviewed-by"
	echo ""

	echo "=== Reviewed-by total tags ==="
	git log --grep="Reviewed-by.*$AUTHOR" --oneline $1 | wc -l
	echo ""

	echo "=== Signed-off-by names ==="
	get_names $1 "Signed-off-by"
	echo ""

	echo "=== Signed-off-by total tags ==="
	git log --grep="Signed-off-by.*$AUTHOR" --oneline $1 | wc -l
	echo ""

	echo "=== Tested-by names ==="
	get_names $1 "Tested-by"
	echo ""

	echo "=== Tested-by total tags ==="
	git log --grep="Tested-by.*$AUTHOR" --oneline $1 | wc -l
	echo ""

	echo "=== Suggested-by names ==="
	get_names $1 "Suggested-by"
	echo ""

	echo "=== Suggested-by total tags ==="
	git log --grep="Suggested-by.*$AUTHOR" --oneline $1 | wc -l
	echo ""

	echo " === HTML report ==="
	echo ""

	echo "<h4>Here is the complete list of Collabora contributions:</h4>"
	git shortlog $1  --author=$AUTHOR --format="$FORMAT" | cat
	echo ""

	echo "<br />"
	echo "<h4>Reviewed-by:</h4>"
	find_commits $1 "Reviewed-by"
	echo ""

	echo "<br />"
	echo "<h4>Signed-off-by:</h4>"
	find_commits_sob $1 "Signed-off-by"
	echo ""

	echo "<br />"
	echo "<h4>Tested-by:</h4>"
	find_commits $1 "Tested-by"
	echo ""

	echo "<br />"
	echo "<h4>Suggested-by:</h4>"
	find_commits $1 "Suggested-by"
	echo ""
}

function per_year {
	YEAR=$(date +%Y)
	for i in $(seq 13) ; do
		git shortlog -ns \
			--after=31,Dec,$(expr $YEAR - 1) \
			--before=1,Jan,$(expr $YEAR + 1) --author=$1 | sum_commits
		let YEAR--
	done
}

function for_each_dir {
	RANGE="$1"
	AUTHOR="$2"
	DIRS="$3"
	PREFIX="$4"

	for d in $DIRS ; do
		num=$(git shortlog -ns "$RANGE" --author="$AUTHOR" -- $PREFIX$d | sum_commits)
		if [ $num -ge 10 ] ; then 
			echo "$PREFIX$d;$num"
		fi
	done
}

function per_dir {
	for_each_dir "$1" "$2" "$SUBDIRS" ""
	for_each_dir "$1" "$2" "$DRMDIRS" "drivers/gpu/drm/"
}

function help {
i	echo "no help yet"
}

case "$1" in
	report)
		ks_report "$2"
		;;
	yearly)
		per_year "$2"
		;;
	dir)
		per_dir "$2" "$3"
		;;
	help)
		ks_help
		;;
	*)
		ks_help
		exit 1
esac

exit 0


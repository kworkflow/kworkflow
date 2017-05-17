#!/bin/bash

AUTHOR="collabora"

FORMAT="<li><a href=\"https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=%H\">%s</a></li>"

function get_names {
	COMMITS=$(git log --grep="$2.*$AUTHOR" --format=%H $1)
	NAMES=""
	for c in $COMMITS ; do
		NAMES+=$(git show $c | grep "$2.*$AUTHOR" | sed -e "s/^[ ]\+$2: \(.*\) <[a-z\.]*@[a-z\.]*>/\1\\\n/g" | tr -d "\n")
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

echo "=== Authors summary ==="
git shortlog -ns $1  --author=$AUTHOR | cat
echo ""

echo "=== Authors total commits ==="
git shortlog -ns $1  --author=$AUTHOR | sed -e  "s/^ *\([0-9][0-9]\?\).*/+ \1/g" | tr -d '\n' | cut -c 2- | bc
echo ""

echo "=== Reviewed-by names ==="
get_names $1 "Reviewed-by"
echo ""

echo "=== Reviewed-by total tags ==="
git log --grep="Reviewed-by.*$AUTHOR" --oneline $1 | wc -l
echo ""

echo "=== Tested-by names ==="
get_names $1 "Tested-by"
echo ""

echo "=== Tested-by total tags ==="
git log --grep="Tested-by.*$AUTHOR" --oneline $1 | wc -l
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
echo "<h4>Tested-by:</h4>"
find_commits $1 "Tested-by"
echo ""

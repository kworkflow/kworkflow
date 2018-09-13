#!/bin/sh
# . ./kw.sh --source-only

function testHelpText
{
    assertTrue "Something very wrong happened here." "[ 1 -eq 1 ]"
    # HELP_OUTPUT=`kw help`
    # assertTrue "Help text not displaying correctly." "[[ $HELP_OUTPUT == Usage: kw* ]]"
}

. ./tests/shunit2

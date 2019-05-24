#!/bin/bash

. ./tests/utils --source-only

function suite()
{
    suite_addTest "testKwCompletion"
    suite_addTest "testNoCompletion"
    suite_addTest "testKwMCompletion"
    suite_addTest "testKwMaintainersCompletion"
    suite_addTest "testKwConfigmCompletion"
    suite_addTest "testKwGCompletion"
    suite_addTest "testKwSSHCompletion"
    suite_addTest "testKwSCompletion"
}

function getSortedCompletions()
{
    local env_path=".:/bin"
    local env_fish_complete_path=""
    local completion="./src/kw.fish"
    local cmd=$1
    local fish_cmd="set PATH $env_path;
                    set fish_complete_path $env_fish_complete_path;
                    source $completion;
                    complete -C'$1'"

    fish -c "$fish_cmd" | awk '{print $1}' | sort
}

function assertCompletion()
{
    local command="$1"
    local expected="$2"

    local sorted_expected="$(echo $expected | awk '{gsub(" ", "\n"); print $0}' | sort)"
    local sorted_observed="$(getSortedCompletions "$command")"

    if [[ "$sorted_observed" != "$sorted_expected" ]]; then
    local difference="$(diff <(echo "$sorted_expected") <(echo "$sorted_observed"))"
    echo $difference > out.out
    fail "Fish suggestions for '$command' aren't the expected:\n$difference"
    fi;
}

function testKwCompletion()
{
    local expected="explore e build b bi install i prepare p new n ssh s mount
                    mo umount um vars v up u codestyle c maintainers m help h
                    man g configm"

    assertCompletion "kw " "$expected"
}

function testNoCompletion()
{
    local without_file="build b install i bi prepare p new n mount mo umount um
                       vars v up u help h man configm g ssh s"

    for cmd in $without_file; do assertCompletion "kw $cmd " ""; done
}

function testKwMCompletion()
{
    local expected="-a --authors"
    assertCompletion "kw m -" "$expected"
}

function testKwMaintainersCompletion()
{
    local expected="-a --authors"
    assertCompletion "kw maintainers -" "$expected"
}

function testKwConfigmCompletion
{
    local expected="--save --ls"
    assertCompletion "kw configm -" "$expected"
}

function testKwGCompletion
{
    local expected="--save --ls"
    assertCompletion "kw g -" "$expected"
}

function testKwSSHCompletion
{
    local expected="--script --command"
    assertCompletion "kw ssh -" "$expected"
}

function testKwSCompletion
{
    local expected="--script --command"
    assertCompletion "kw s -" "$expected"
}

invoke_shunit

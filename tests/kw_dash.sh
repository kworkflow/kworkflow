#!/bin/bash

. ./tests/utils --source-only

function suite
{
  suite_addTest "testDash"
}

function testDash
{
  ./tests/_kw_dash.dsh
  if [ $? -ne 0 ]; then
    fail "Dash was unable to find kw"
  fi
}

invoke_shunit

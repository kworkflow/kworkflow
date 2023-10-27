#!/bin/bash

. ../src/lib/kw_include.sh --source-only
include '../src/lib/kwio.sh'
include './utils.sh'

os='debian'

function oneTimeSetUp()
{
  say 'Starting vagrant..'
  vagrant destroy -f "$os" && vagrant up "$os"
}

function oneTimeTearDown()
{
  say "Destroying ${os} VM.."
  vagrant destroy -f "$os"
}

invoke_shunit

#!/bin/bash

include './src/lib/lore.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache/"

  mkdir -p "$KW_CACHE_DIR"

  cp "${SAMPLES_DIR}/web/reduced_lore_main_page.html" "${KW_CACHE_DIR}/lore_main_page.html"
}

function test_retrieve_available_mailing_lists()
{
  local index
  local -A expected_lists=(
    ['all']='All of lore.kernel.org'
    ['lkml']='LKML Archive on lore.kernel.org'
    ['linux-parisc']='Linux-parisc Archive on lore.kernel.org'
    ['ddprobe']='List used for roundtrip monitoring'
    ['linux-pm']='Linux-PM Archive on lore.kernel.org'
    ['amd-gfx']='AMD-GFX Archive on lore.kernel.org'
    ['dri-devel']='dri-devel Archive on lore.kernel.org'
  )

  retrieve_available_mailing_lists 'TEST_MODE' &> /dev/null

  for index in "${!expected_lists[@]}"; do
    assert_equals_helper "We expected '$index' to be a valid key" "($LINENO)" \
      "${available_lore_mailing_lists["$index"]}" "${expected_lists["$index"]}"
  done

  for index in "${!available_lore_mailing_lists[@]}"; do
    assert_equals_helper "We didn't expect '$index' to be a valid key" "($LINENO)" \
      "${available_lore_mailing_lists["$index"]}" "${expected_lists["$index"]}"
  done
}

invoke_shunit

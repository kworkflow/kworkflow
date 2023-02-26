#!/bin/bash

include './src/lib/lore.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache"
  export CACHE_LORE_DIR="${KW_CACHE_DIR}/lore"
  export LIST_PAGE_PATH="${CACHE_LORE_DIR}/lore_main_page.html"

  mkdir -p "$CACHE_LORE_DIR"

  cp "${SAMPLES_DIR}/web/reduced_lore_main_page.html" "${CACHE_LORE_DIR}/lore_main_page.html"
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

function test_is_introduction_patch()
{
  local output
  local sample_url

  sample_url='https://lore.kernel.org/amd-gfx/20221228163102.468-7-mario.limonciello@amd.com/T/#u'
  is_introduction_patch "$sample_url"
  assertEquals "($LINENO)" "$?" 1

  sample_url='https://lore.kernel.org/amd-gfx/20221214202141.1721178-1-aurabindo.pillai@amd.com/T/#u'
  is_introduction_patch "$sample_url"
  assertEquals "($LINENO)" "$?" 0

  # Invalid url
  sample_url='https://lore.kernel.org/linux-media/1ae68c9f-726a-3307-65e6-e699be1fc7b9@xs4all.nl/T/#u'
  is_introduction_patch "$sample_url"
  assertEquals "($LINENO)" "$?" 1
}

function test_is_the_link_valid()
{
  is_the_link_valid ''
  assertEquals "($LINENO)" "$?" 22

  # shellcheck disable=SC2317
  function curl()
  {
    printf 'HTTP/1.1 200 OK'
  }

  is_the_link_valid 'something'
  assertEquals "($LINENO)" "$?" 0

  # shellcheck disable=SC2317
  function curl()
  {
    return 6
  }

  is_the_link_valid 'something'
  assertEquals "($LINENO)" "$?" 22
}

function test_process_name()
{
  local output
  local expected='First Second'

  output=$(process_name 'Second, First')
  assertEquals "($LINENO)" "$output" "$expected"

  output=$(process_name 'Second Third, First')
  expected='First Second Third'
  assertEquals "($LINENO)" "$output" "$expected"

  output=$(process_name 'First Second')
  expected='First Second'
  assertEquals "($LINENO)" "$output" "$expected"
}

function test_extract_metadata_from_patch_title_with_all_metadata()
{
  local output
  local sample_name
  local sample_url
  local expected

  # shellcheck disable=SC2317
  function total_patches_in_the_series()
  {
    printf '0'
  }

  sample_url='https://lore.kernel.org/dri-devel/20221230153554.105856-2-robert.foss@linaro.org/T/#u'
  expected="4${SEPARATOR_CHAR}11${SEPARATOR_CHAR}"
  expected+='dt-bindings: display: msm: Add qcom, sm8350-dpu binding'
  expected+="${SEPARATOR_CHAR}${sample_url}"

  sample_name='[PATCH v4 01/11] dt-bindings: display: msm: Add qcom, sm8350-dpu binding'

  output=$(extract_metadata_from_patch_title "$sample_name" "$sample_url")
  assertEquals "($LINENO)" "$output" "$expected"
}

function test_extract_metadata_from_patch_title_single_patch()
{
  local output
  local sample_name
  local sample_url
  local expected

  # shellcheck disable=SC2317
  function total_patches_in_the_series()
  {
    printf '0'
  }

  expected="1${SEPARATOR_CHAR}1${SEPARATOR_CHAR}"
  expected+='drm/vc4: drop all currently held locks if deadlock happens'
  expected+="${SEPARATOR_CHAR}"

  sample_name='[PATCH] drm/vc4: drop all currently held locks if deadlock happens'
  output=$(extract_metadata_from_patch_title "$sample_name")

  assertEquals "($LINENO)" "$output" "$expected"
}

function test_extract_metadata_from_patch_title_rfc()
{
  local output
  local sample_name
  local sample_url
  local expected

  # shellcheck disable=SC2317
  function total_patches_in_the_series()
  {
    printf '0'
  }

  expected="1${SEPARATOR_CHAR}20${SEPARATOR_CHAR}"
  expected+='Initial Xe driver submission'
  expected+="${SEPARATOR_CHAR}"

  sample_name='[RFC PATCH 00/20] Initial Xe driver submission'
  output=$(extract_metadata_from_patch_title "$sample_name")

  assertEquals "($LINENO)" "$output" "$expected"
}

invoke_shunit

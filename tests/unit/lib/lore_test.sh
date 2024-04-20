#!/usr/bin/env bash

include './src/lib/lore.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache"
  export CACHE_LORE_DIR="${KW_CACHE_DIR}/lore"
  export LIST_PAGE_PATH="${CACHE_LORE_DIR}/lore_main_page.html"
  export LORE_DATA_DIR="${SHUNIT_TMPDIR}/lore"
  export BOOKMARKED_SERIES_PATH="${LORE_DATA_DIR}/lore_bookmarked_series"

  mkdir -p "$CACHE_LORE_DIR"
  mkdir -p "${LORE_DATA_DIR}"

  cp "${SAMPLES_DIR}/web/reduced_lore_page_0.html" "${CACHE_LORE_DIR}/lore_page_0.html"
  cp "${SAMPLES_DIR}/web/reduced_lore_page_1.html" "${CACHE_LORE_DIR}/lore_page_1.html"
  cp "${SAMPLES_DIR}/web/reduced_lore_page_2.html" "${CACHE_LORE_DIR}/lore_page_2.html"
  cp "${SAMPLES_DIR}/lore_sample.config" "${SHUNIT_TMPDIR}/lore.config"
  cp --recursive "${SAMPLES_DIR}/lore/." "${SHUNIT_TMPDIR}/samples"
}

function setUp()
{
  export ORIGINAL_PATH="$PWD"

  touch "${BOOKMARKED_SERIES_PATH}"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown()
{
  if [[ -f "${BOOKMARKED_SERIES_PATH}" && "${BOOKMARKED_SERIES_PATH}" != '/' ]]; then
    rm "${BOOKMARKED_SERIES_PATH}"
  fi

  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
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
    ["oe-linux-nfc"]='NFC on Linux'
    ['linux-nfc']='Linux-NFC Archive on lore.kernel.org'
    ['linux-x11']='Linux X11 Discussion Archive on lore.kernel.org'
    ['ultralinux']='Ultralinux archive on lore.kernel.org'
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

function test_get_patch_metadata()
{
  local message_title
  local expected
  local output

  message_title='some/subsys: Do foo'
  expected=''
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed without patch metadata' "$LINENO" "$expected" "$output"

  message_title='[PATCH] some/subsys: Do foo'
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "PATCH" in upper case' "$LINENO" "$expected" "$output"

  message_title='[patch] some/subsys: Do foo'
  expected='[patch]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "PATCH" in lower case' "$LINENO" "$expected" "$output"

  message_title='[Patch] some/subsys: Do foo'
  expected='[Patch]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "PATCH" with starting upper case' "$LINENO" "$expected" "$output"

  message_title='[pAtcH] some/subsys: Do foo'
  expected='[pAtcH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "PATCH" with random case' "$LINENO" "$expected" "$output"

  message_title='[RFC] some/subsys: Do foo'
  expected='[RFC]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "RFC" in upper case' "$LINENO" "$expected" "$output"

  message_title='[rfc] some/subsys: Do foo'
  expected='[rfc]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "RFC" in lower case' "$LINENO" "$expected" "$output"

  message_title='[Rfc] some/subsys: Do foo'
  expected='[Rfc]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "RFC" with starting upper case' "$LINENO" "$expected" "$output"

  message_title='[rfC] some/subsys: Do foo'
  expected='[rfC]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with the word "RFC" with random case' "$LINENO" "$expected" "$output"

  message_title='[RFC PATCH] some/subsys: Do foo'
  expected='[RFC PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with with tag mixing "PATCH" and "RFC" (case 1)' "$LINENO" "$expected" "$output"

  message_title='[PATCH RFC] some/subsys: Do foo'
  expected='[PATCH RFC]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with with tag mixing "PATCH" and "RFC" (case 2)' "$LINENO" "$expected" "$output"

  message_title='[addtional tag][PATCH] some/subsys: Do foo'
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with two tags' "$LINENO" "$expected" "$output"

  message_title='[addtional tag 1][PATCH] some/subsys: Do [addtional tag 2] foo'
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with more than one tag' "$LINENO" "$expected" "$output"

  message_title='[PATCH] some/subsys: Do foo in array[0] element'
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with braces in subject' "$LINENO" "$expected" "$output"

  message_title='[PATCH] !@#$%^&*()_-+={}\|/.,:;`~"'"'"''
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with special characters' "$LINENO" "$expected" "$output"

  message_title='[v2 PATCH] some/subsys: Do foo'
  expected='[v2 PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with version in tag' "$LINENO" "$expected" "$output"

  message_title='[PATCH 4/13] some/subsys: Do foo'
  expected='[PATCH 4/13]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with numbering in tag' "$LINENO" "$expected" "$output"

  message_title='[PATCH] revert "patch"'
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with word "patch" in subject' "$LINENO" "$expected" "$output"

  message_title='[PATCH][GSoC patch] some/subsys: Do foo'
  expected='[PATCH]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with following tag with word "patch"' "$LINENO" "$expected" "$output"

  message_title='[v13 PATCH 2/3] some/subsys: Do foo'
  expected='[v13 PATCH 2/3]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with version and numbering in tag' "$LINENO" "$expected" "$output"

  message_title='[PATCH bpf-next 4.3] some/subsys: Do foo'
  expected='[PATCH bpf-next 4.3]'
  output=$(get_patch_metadata "$message_title")
  assert_equals_helper 'Failed with arbitrary string in tag' "$LINENO" "$expected" "$output"
}

function test_get_patch_version()
{
  local patch_metadata
  local output

  patch_metadata=''
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Empty patch metadata should return 2 ENOENT' "$LINENO" 2 "$?"
  assert_equals_helper 'Empty patch metadata should output "X" as version' "$LINENO" 'X' "$output"

  patch_metadata='[PATCH]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag "[PATCH]"' "$LINENO" 1 "$output"

  patch_metadata='[RFC PATCH]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag "[RFC PATCH]"' "$LINENO" 1 "$output"

  patch_metadata='[PATCH AUTOSEL]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary string' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 2718]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary integer' "$LINENO" 1 "$output"

  patch_metadata='[281.828 PATCH]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary float' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 12/13]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with numbering' "$LINENO" 1 "$output"

  patch_metadata='[PATCH v4321]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version (v)' "$LINENO" 4321 "$output"

  patch_metadata='[PATCH V1234]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version (V)' "$LINENO" 1234 "$output"

  patch_metadata='[PATCH stringV1234string]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version without space as border' "$LINENO" 1234 "$output"

  patch_metadata='[PATCH V18 56/78]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version and numbering' "$LINENO" 18 "$output"

  patch_metadata='[Very voice PATCH v1389 Vertical]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version strings starting with v/V' "$LINENO" 1389 "$output"

  patch_metadata='[PATCH v 1234]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version (v) with space separating number and letter' "$LINENO" 1234 "$output"

  patch_metadata='[PATCH V 1234]'
  output=$(get_patch_version "$patch_metadata")
  assert_equals_helper 'Failed for tag with version (V) with space separating number and letter' "$LINENO" 1234 "$output"
}

function test_get_patch_number_in_series()
{
  local patch_metadata
  local expected

  patch_metadata=''
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Empty patch metadata should return 2 ENOENT' "$LINENO" 2 "$?"
  assert_equals_helper 'Empty patch metadata should output "X" as number in the series' "$LINENO" 'X' "$output"

  patch_metadata='[PATCH]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag "[PATCH]"' "$LINENO" 1 "$output"

  patch_metadata='[RFC PATCH]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag "[RFC PATCH]"' "$LINENO" 1 "$output"

  patch_metadata='[PATCH AUTOSEL]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary string' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 2718]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary integer' "$LINENO" 1 "$output"

  patch_metadata='[281.828 PATCH]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary float' "$LINENO" 1 "$output"

  patch_metadata='[PATCH v4321]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with version' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 00/13]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag of cover letter' "$LINENO" 0 "$output"

  patch_metadata='[PATCH 1/2]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag of first patch' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 0424/2002]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag of arbitrary patch' "$LINENO" 424 "$output"

  patch_metadata='[v32 PATCH 0424/2002]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with numbering and version' "$LINENO" 424 "$output"

  patch_metadata='[PATCH 123 / 345]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with one space between numbers and foward-slash' "$LINENO" 123 "$output"

  patch_metadata='[PATCH 123       /  345]'
  output=$(get_patch_number_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary number of spaces between numbers and foward-slash' "$LINENO" 123 "$output"
}

function test_get_patch_total_in_series()
{
  local patch_metadata
  local expected

  patch_metadata=''
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Empty patch metadata should return 2 ENOENT' "$LINENO" 2 "$?"
  assert_equals_helper 'Empty patch metadata should output "X" as total in series' "$LINENO" 'X' "$output"

  patch_metadata='[PATCH]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag "[PATCH]"' "$LINENO" 1 "$output"

  patch_metadata='[RFC PATCH]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag "[RFC PATCH]"' "$LINENO" 1 "$output"

  patch_metadata='[PATCH AUTOSEL]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary string' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 2718]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary integer' "$LINENO" 1 "$output"

  patch_metadata='[281.828 PATCH]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary float' "$LINENO" 1 "$output"

  patch_metadata='[PATCH v4321]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with version' "$LINENO" 1 "$output"

  patch_metadata='[PATCH 00/13]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag of cover letter' "$LINENO" 13 "$output"

  patch_metadata='[PATCH 1/2]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag of first patch' "$LINENO" 2 "$output"

  patch_metadata='[PATCH 0424/2002]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag of arbitrary patch' "$LINENO" 2002 "$output"

  patch_metadata='[v32 PATCH 0424/2002]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with numbering and version' "$LINENO" 2002 "$output"

  patch_metadata='[PATCH 123 / 345]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with one space between numbers and foward-slash' "$LINENO" 345 "$output"

  patch_metadata='[PATCH 123       /  345]'
  output=$(get_patch_total_in_series "$patch_metadata")
  assert_equals_helper 'Failed for tag with arbitrary number of spaces between numbers and foward-slash' "$LINENO" 345 "$output"
}

function test_remove_patch_metadata_from_message_title()
{
  local message_title
  local expected
  local output

  message_title='some/subsys: Do foo'
  expected='some/subsys: Do foo'
  output=$(remove_patch_metadata_from_message_title "$message_title" '')
  assert_equals_helper 'Failed for inexistent patch metadata' "$LINENO" "$expected" "$output"

  message_title='[PATCH] some/subsys: Do foo'
  expected='some/subsys: Do foo'
  output=$(remove_patch_metadata_from_message_title "$message_title" '[PATCH]')
  assert_equals_helper 'Failed for simple patch metadata' "$LINENO" "$expected" "$output"

  message_title='[RFC PATCH v12 23/23] some/subsys: Do foo'
  expected='some/subsys: Do foo'
  output=$(remove_patch_metadata_from_message_title "$message_title" '[RFC PATCH v12 23/23]')
  assert_equals_helper 'Failed for complex patch metadata' "$LINENO" "$expected" "$output"

  message_title='[cocci][PATCH][net-dev] some/subsys: Do foo'
  expected='[cocci][net-dev] some/subsys: Do foo'
  output=$(remove_patch_metadata_from_message_title "$message_title" '[PATCH]')
  assert_equals_helper 'Failed for complex patch metadata' "$LINENO" "$expected" "$output"

  message_title='[RFC/PATCH 00/23] some/subsys: Do foo'
  expected='some/subsys: Do foo'
  output=$(remove_patch_metadata_from_message_title "$message_title" '[RFC/PATCH 00/23]')
  assert_equals_helper 'Failed for complex patch metadata' "$LINENO" "$expected" "$output"
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

function test_delete_series_from_local_storage()
{
  local download_dir_path="${SHUNIT_TMPDIR}/some/dir"
  local series_url='https://lore.kernel.org/some-list/message-id/'
  local flag='TEST_MODE'
  local output
  local expected

  mkdir -p "${download_dir_path}"

  delete_series_from_local_storage "${download_dir_path}" "${series_url}" "$flag"
  assertEquals "($LINENO) - Should return 2" 2 "$?"

  touch "${download_dir_path}/message-id.mbx"
  output=$(delete_series_from_local_storage "${download_dir_path}" "${series_url}" "$flag")
  expected="rm ${download_dir_path}/message-id.mbx"
  assert_equals_helper 'Should delete .mbx file' "$LINENO" "$expected" "$output"
}

function test_create_lore_bookmarked_file()
{
  if [[ "${BOOKMARKED_SERIES_PATH}" != '/' ]]; then
    rm "${BOOKMARKED_SERIES_PATH}"
  fi

  create_lore_bookmarked_file
  assertTrue "($LINENO) - Local bookmark database was not created" "[[ -f ${BOOKMARKED_SERIES_PATH} ]]"
}

function test_add_patchset_to_bookmarked_database()
{
  local raw_patchset1='somepatchset1'
  local raw_patchset2='somepatchset2'
  local raw_patchset3='somepatchset3'
  local download_dir_path='somedir'
  local output
  local count

  add_patchset_to_bookmarked_database "${raw_patchset1}" "${download_dir_path}"
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  printf '%s' "$output" | grep --quiet "${raw_patchset1}${SEPARATOR_CHAR}${download_dir_path}"
  assertTrue "($LINENO) - Should add series to local bookmark database" "[[ \"$?\" == 0 ]]"

  add_patchset_to_bookmarked_database "${raw_patchset1}" "${download_dir_path}"
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  count=$(printf '%s' "$output" | grep --count "${raw_patchset1}${SEPARATOR_CHAR}${download_dir_path}")
  assertEquals "($LINENO) - Should not duplicate entries " 1 "$count"

  add_patchset_to_bookmarked_database "${raw_patchset2}" "${download_dir_path}"
  add_patchset_to_bookmarked_database "${raw_patchset3}" "${download_dir_path}"
  count=$(wc --lines "${BOOKMARKED_SERIES_PATH}" | cut --delimiter ' ' -f1)
  assertEquals "($LINENO) - Should have 3 entries" 3 "$count"
}

function test_remove_patchset_from_bookmark_by_url()
{
  local output
  local expected

  {
    printf 'entry1Æhttp://lore.kernel.org/amd-gfx/0138948.2424-1-lore@kernel.org/\n'
    printf 'entry2Æhttp://lore.kernel.org/linux-staging/1676464.997845-1-lore@kernel.org/\n'
    printf 'entry3Æhttp://lore.kernel.org/git/28784575.16734-1-lore@kernel.org/\n'
  } >> "${BOOKMARKED_SERIES_PATH}"

  remove_patchset_from_bookmark_by_url 'http://lore.kernel.org/linux-staging/1676464.997845-1-lore@kernel.org/'
  expected='entry1Æhttp://lore.kernel.org/amd-gfx/0138948.2424-1-lore@kernel.org/'$'\n'
  expected+='entry3Æhttp://lore.kernel.org/git/28784575.16734-1-lore@kernel.org/'
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  assertEquals "($LINENO) - Should delete entry 2" "$expected" "$output"

  remove_patchset_from_bookmark_by_url 'http://lore.kernel.org/git/28784575.16734-1-lore@kernel.org/'
  expected='entry1Æhttp://lore.kernel.org/amd-gfx/0138948.2424-1-lore@kernel.org/'
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  assertEquals "($LINENO) - Should only have entry 1" "$expected" "$output"
}

function test_remove_series_from_bookmark_by_index()
{
  local output
  local expected

  {
    printf 'entry1\n'
    printf 'entry2\n'
    printf 'entry3\n'
  } >> "${BOOKMARKED_SERIES_PATH}"

  remove_series_from_bookmark_by_index 2
  expected='entry1'$'\n''entry3'
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  assertEquals "($LINENO) - Should delete entry 2" "$expected" "$output"

  remove_series_from_bookmark_by_index 2
  expected='entry1'
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  assertEquals "($LINENO) - Should only have entry 1" "$expected" "$output"
}

function test_get_bookmarked_series()
{
  local -a bookmarked_series=()
  local char="${SEPARATOR_CHAR}"
  local output

  {
    printf '%sTITLE1%sAUTHOR1%s%s%s%s%s%s%s%sDATE1\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char"
    printf '%sTITLE2%sAUTHOR2%s%s%s%s%s%s%s%sDATE2\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char"
    printf '%sTITLE3%sAUTHOR3%s%s%s%s%s%s%s%sDATE3\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char"
  } >> "${BOOKMARKED_SERIES_PATH}"

  get_bookmarked_series bookmarked_series

  expected=' DATE1 | TITLE1                                                       | AUTHOR1'
  assertEquals "($LINENO)" "$expected" "${bookmarked_series[0]}"
  expected=' DATE2 | TITLE2                                                       | AUTHOR2'
  assertEquals "($LINENO)" "$expected" "${bookmarked_series[1]}"
  expected=' DATE3 | TITLE3                                                       | AUTHOR3'
  assertEquals "($LINENO)" "$expected" "${bookmarked_series[2]}"
}

function test_get_bookmarked_series_by_index()
{
  local output
  local expected

  {
    printf 'entry1\n'
    printf 'entry2\n'
    printf 'entry3\n'
  } >> "${BOOKMARKED_SERIES_PATH}"

  output=$(get_bookmarked_series_by_index 1)
  expected='entry1'
  assertEquals "($LINENO) - Should get the first entry" "$expected" "$output"

  output=$(get_bookmarked_series_by_index 2)
  expected='entry2'
  assertEquals "($LINENO) - Should get the second entry" "$expected" "$output"
}

function test_get_patchset_bookmark_status()
{
  local output

  get_patchset_bookmark_status ''
  assert_equals_helper 'Empty URL should return 22' "$LINENO" 22 "$?"

  {
    printf 'entry1Æhttp://lore.kernel.org/amd-gfx/0138948.2424-1-lore@kernel.org/\n'
    printf 'entry2Æhttp://lore.kernel.org/linux-staging/1676464.997845-1-lore@kernel.org/\n'
    printf 'entry3Æhttp://lore.kernel.org/git/28784575.16734-1-lore@kernel.org/\n'
  } >> "${BOOKMARKED_SERIES_PATH}"

  output=$(get_patchset_bookmark_status 'http://lore.kernel.org/linux-staging/1676464.997845-1-lore@kernel.org/')
  assert_equals_helper 'Should output 1 (patch bookmarked)' "$LINENO" 1 "$output"

  output=$(get_patchset_bookmark_status 'http://lore.kernel.org/linux-invalid/404-1-inva@lid.url/')
  assert_equals_helper 'Should output 0 (patch not bookmarked)' "$LINENO" 0 "$output"
}

function test_download_series()
{
  local series_url='https://lore.kernel.org/some-list/1234567.789-1-email@email.com/'
  local save_to="${SHUNIT_TMPDIR}/kw_download"
  local flag='TEST_MODE'
  local output
  local expected

  download_series '' '' "$flag" > /dev/null 2>&1
  assert_equals_helper 'No arguments should return 22' "$LINENO" 22 "$?"

  download_series "$series_url" '' "$flag" > /dev/null 2>&1
  assert_equals_helper 'No output directory should return 22' "$LINENO" 22 "$?"

  download_series '' "$save_to" "$flag" > /dev/null 2>&1
  assert_equals_helper 'No series URL should return 22' "$LINENO" 22 "$?"

  output=$(download_series 'http://url/with/http/' "$save_to" "$flag")
  assertTrue "${LINENO} - Should replace 'http' for 'https'" "[[ '${output}' =~ 'https://url/with/http/' ]]"

  output=$(download_series "$series_url" "$save_to" "$flag")
  expected="mkdir --parents '${save_to}'"$'\n'
  expected+="b4 --quiet am '${series_url}' --no-cover --outdir '${save_to}' --mbox-name '1234567.789-1-email@email.com.mbx'"$'\n'
  expected+="${save_to}/1234567.789-1-email@email.com.mbx"
  assert_equals_helper 'Wrong commands issued' "$LINENO" "$expected" "$output"
}

function test_extract_message_id_from_url()
{
  local output
  local expected

  extract_message_id_from_url
  assert_equals_helper 'No URL should return 22' "$LINENO" 22 "$?"

  extract_message_id_from_url ''
  assert_equals_helper 'Empty URL should return 22' "$LINENO" 22 "$?"

  output=$(extract_message_id_from_url 'https://lore.kernel.org/some-list/1234567.789-1-email@email.com/')
  expected='1234567.789-1-email@email.com'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(extract_message_id_from_url 'https://lore.kernel.org/some-list/1234567.789-1-email@email.com/#T/#u')
  expected='1234567.789-1-email@email.com'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_save_new_lore_config()
{
  local setting
  local new_value
  local lore_config_path
  local output
  local expected

  lore_config_path=$(realpath 'some/invalid/path' 2> /dev/null)
  expected="${lore_config_path}: file doesn't exists"
  output=$(save_new_lore_config 'some_setting' 'some_value' "$lore_config_path")
  assert_equals_helper 'Invalid lore config path should return 2' "$LINENO" 2 "$?"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  lore_config_path=$(realpath 'lore.config')

  setting='download_path'
  new_value='/avenida/paulista'
  save_new_lore_config "$setting" "$new_value" "$lore_config_path"
  expected='default_ui=dialog'$'\n'
  expected+='dialog_layout=black_and_white'$'\n'
  expected+='lists='$'\n'
  expected+='download_path=/avenida/paulista'
  output=$(< "$lore_config_path")
  assert_equals_helper 'Wrong lore.config contents' "$LINENO" "$expected" "$output"

  setting='invalid_setting'
  new_value='should_not_exist'
  save_new_lore_config "$setting" "$new_value" "$lore_config_path"
  expected='default_ui=dialog'$'\n'
  expected+='dialog_layout=black_and_white'$'\n'
  expected+='lists='$'\n'
  expected+='download_path=/avenida/paulista'
  output=$(< "$lore_config_path")
  assert_equals_helper 'Wrong lore.config contents' "$LINENO" "$expected" "$output"
}

function test_compose_lore_query_url_with_verification_invalid_cases()
{
  local target_mailing_list
  local min_index

  target_mailing_list=''
  min_index='200'
  compose_lore_query_url_with_verification "$target_mailing_list" "$min_index"
  assert_equals_helper 'Empty `target_mailing_list` should return 22' "$LINENO" 22 "$?"

  target_mailing_list='amd-gfx'
  min_index=''
  upper_end_in_timestamp='2023-01-01T00:00:00Z'
  compose_lore_query_url_with_verification "$target_mailing_list" "$min_index"
  assert_equals_helper 'Empty `min_index` value should return 22' "$LINENO" 22 "$?"

  target_mailing_list='amd-gfx'
  min_index='20a0'
  compose_lore_query_url_with_verification "$target_mailing_list" "$min_index"
  assert_equals_helper 'Invalid `min_index` (not an integer) value should return 22' "$LINENO" 22 "$?"

  target_mailing_list='amd-gfx'
  min_index='200 '
  compose_lore_query_url_with_verification "$target_mailing_list" "$min_index"
  assert_equals_helper 'Invalid `min_index` (not an integer) value should return 22' "$LINENO" 22 "$?"
}

function test_compose_lore_query_url_with_verification_valid_cases()
{
  local target_mailing_list
  local additional_filters
  local min_index
  local output
  local expected

  target_mailing_list='amd-gfx'
  min_index='200'
  expected='https://lore.kernel.org/amd-gfx/?x=A&o=200&q=((s:patch+OR+s:rfc)+AND+NOT+s:re:)'
  output=$(compose_lore_query_url_with_verification "$target_mailing_list" "$min_index")
  assert_equals_helper 'Valid arguments should return 0' "$LINENO" 0 "$?"
  assert_equals_helper 'Wrong query URL outputted' "$LINENO" "$expected" "$output"

  target_mailing_list='amd-gfx'
  min_index='-200'
  expected='https://lore.kernel.org/amd-gfx/?x=A&o=-200&q=((s:patch+OR+s:rfc)+AND+NOT+s:re:)'
  output=$(compose_lore_query_url_with_verification "$target_mailing_list" "$min_index")
  assert_equals_helper 'Valid arguments should return 0' "$LINENO" 0 "$?"
  assert_equals_helper 'Wrong query URL outputted' "$LINENO" "$expected" "$output"

  target_mailing_list='amd-gfx'
  min_index='200'
  additional_filters='s:drm%2Famdgpu+AND+NOT+f:Linus%20Torvalds'
  expected='https://lore.kernel.org/amd-gfx/?x=A&o=200&q=((s:patch+OR+s:rfc)+AND+NOT+s:re:)+AND+(s:drm%2Famdgpu+AND+NOT+f:Linus%20Torvalds)'
  output=$(compose_lore_query_url_with_verification "$target_mailing_list" "$min_index" "$additional_filters")
  assert_equals_helper 'Valid arguments should return 0' "$LINENO" 0 "$?"
  assert_equals_helper 'Wrong query URL outputted' "$LINENO" "$expected" "$output"
}

function test_pre_process_raw_xml()
{
  local raw_xml
  local output
  local expected

  raw_xml=$(< "${SHUNIT_TMPDIR}/samples/query_result_sample-1.xml")
  output=$(pre_process_raw_xml "$raw_xml")
  expected=$(< "${SHUNIT_TMPDIR}/samples/pre_processed_patches_sample-1")
  assert_equals_helper 'Wrong pre-processed result for sample 1' "$LINENO" "$expected" "$output"

  raw_xml=$(< "${SHUNIT_TMPDIR}/samples/query_result_sample-2.xml")
  output=$(pre_process_raw_xml "$raw_xml")
  expected=$(< "${SHUNIT_TMPDIR}/samples/pre_processed_patches_sample-2")
  assert_equals_helper 'Wrong pre-processed result for sample 2' "$LINENO" "$expected" "$output"
}

function test_thread_for_process_individual_patch()
{
  local shared_dir_path="${SHUNIT_TMPDIR}/shared_dir"
  local message_id1='http://lore.kernel.org/foo/bar'
  local message_title1='[PATCH] some/subsys: Fix bug'
  local author_name1='Foo Bar'
  local author_email1='foo@bar.com'
  local updated1='2023/03/01 12:05'
  local line1='next-patch'
  local message_id2='http://lore.kernel.org/xpto/abc'
  local message_title2='[v3 RFC PATCH 12/13] subsys/net: Revert previous patch'
  local author_name2='Xpto Abc'
  local author_email2='xpto@abc.jp'
  local updated2='2023/12/01 12:30'
  local line2='href="http://lore.kernel.org/abc/xpto"'
  local expected

  mkdir "$shared_dir_path"

  thread_for_process_individual_patch "$message_id1" "$message_title1" "$author_name1" \
    "$author_email1" "$updated1" "$line1" 0 "$shared_dir_path" &
  thread_for_process_individual_patch "$message_id2" "$message_title2" "$author_name2" \
    "$author_email2" "$updated2" "$line2" 1 "$shared_dir_path"

  [[ -f "${shared_dir_path}/0" ]]
  # shellcheck disable=SC2319
  assert_equals_helper 'Did not generate entry for processed patch' "$LINENO" 0 "$?"
  expected='http://lore.kernel.org/foo/barÆsome/subsys: Fix bugÆFoo BarÆfoo@bar.comÆ'
  expected+='1Æ1Æ1Æ2023/03/01 12:05Æ'
  assert_equals_helper 'Wrong processed patch' "$LINENO" "$expected" "$(< "${shared_dir_path}/0")"

  [[ -f "${shared_dir_path}/0-metadata" ]]
  # shellcheck disable=SC2319
  assert_equals_helper 'Did not generate metadata entry for processed patch' "$LINENO" 0 "$?"
  expected='http://lore.kernel.org/foo/bar,1,1'
  assert_equals_helper 'Wrong processed patch metadata' "$LINENO" "$expected" "$(< "${shared_dir_path}/0-metadata")"

  [[ -f "${shared_dir_path}/1" ]]
  # shellcheck disable=SC2319
  assert_equals_helper 'Did not generate entry for processed patch' "$LINENO" 0 "$?"
  expected='http://lore.kernel.org/xpto/abcÆsubsys/net: Revert previous patchÆXpto AbcÆxpto@abc.jpÆ'
  expected+='3Æ12Æ13Æ2023/12/01 12:30Æhttp://lore.kernel.org/abc/xpto'
  assert_equals_helper 'Wrong processed patch' "$LINENO" "$expected" "$(< "${shared_dir_path}/1")"

  [[ -f "${shared_dir_path}/1-metadata" ]]
  # shellcheck disable=SC2319
  assert_equals_helper 'Did not generate metadata entry for processed patch' "$LINENO" 0 "$?"
  expected='http://lore.kernel.org/xpto/abc,3,12'
  assert_equals_helper 'Wrong processed patch metadata' "$LINENO" "$expected" "$(< "${shared_dir_path}/1-metadata")"

  rm -rf "$shared_dir_path"
}

function test_process_individual_patches()
{
  local -a individual_patches
  declare -A individual_patches_metadata
  local raw_xml
  local expected

  # Process first batch
  raw_xml=$(< "${SAMPLES_DIR}/lore/query_result_sample-1.xml")
  process_individual_patches "$raw_xml" 'individual_patches'

  # Check the list of processed individual patches
  assert_equals_helper 'Should have processed 3 individual patches' "$LINENO" 3 "${#individual_patches[@]}"
  expected='http://lore.kernel.org/mpb/introductionÆAdd Palco to MPBÆGilberto GilÆgil.gil@mpb.brÆ3Æ1Æ1Æ2023/08/09 21:27Æ'
  assert_equals_helper 'Wrong processing of patch 0' "$LINENO" "$expected" "${individual_patches[0]}"
  expected='http://lore.kernel.org/soul/sequelÆtim-maia/racional: Add Bom Senso to albumÆTim MaiaÆtim.maia@soul.brÆ1Æ3Æ9Æ2023/08/09 19:10Æhttp://lore.kernel.org/soul/introduction'
  assert_equals_helper 'Wrong processing of patch 1' "$LINENO" "$expected" "${individual_patches[1]}"
  expected='http://lore.kernel.org/rock/introductionÆIntroduce Ziggy StardustÆDavid BowieÆmajor.tom@rock.ukÆ12Æ1Æ1Æ2023/08/09 19:10Æ'
  assert_equals_helper 'Wrong processing of patch 2' "$LINENO" "$expected" "${individual_patches[2]}"

  # Check the metadata of the processed patches
  assert_equals_helper 'Should have 3 patches metadata' "$LINENO" 3 "${#individual_patches_metadata[@]}"
  expected='3,1'
  assert_equals_helper 'Wrong metadata of patch 0' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/mpb/introduction']}"
  expected='1,3'
  assert_equals_helper 'Wrong metadata of patch 1' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/soul/sequel']}"
  expected='12,1'
  assert_equals_helper 'Wrong metadata of patch 2' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/rock/introduction']}"

  # Process second batch
  raw_xml=$(< "${SAMPLES_DIR}/lore/query_result_sample-2.xml")
  process_individual_patches "$raw_xml" 'individual_patches'

  # Check the list of processed individual patches
  assert_equals_helper 'Should have processed 3 individual patches' "$LINENO" 3 "${#individual_patches[@]}"
  expected='http://lore.kernel.org/reggae/sequelÆbob-marley/survavil: Add One Drop to albumÆBob MarleyÆbob.marley@reggae.jmÆ2Æ7Æ10Æ2023/08/09 21:27Æ'
  assert_equals_helper 'Wrong processing of patch 0' "$LINENO" "$expected" "${individual_patches[0]}"
  expected='http://lore.kernel.org/punk/sequelÆcbj/camisa10: Add Só os Loucos Sabem to albumÆCharlie Brown Jr.Æcharlie.brown@punk.brÆ1Æ3Æ13Æ2023/08/09 19:10Æ'
  assert_equals_helper 'Wrong processing of patch 1' "$LINENO" "$expected" "${individual_patches[1]}"
  expected='http://lore.kernel.org/samba-pop/introductionÆRelease Músicas para Churrasco Vol.1ÆSeu JorgeÆseu.jorge@samba-pop.brÆ1Æ1Æ1Æ2023/08/09 19:10Æhttp://lore.kernel.org/samba-pop/request'
  assert_equals_helper 'Wrong processing of patch 2' "$LINENO" "$expected" "${individual_patches[2]}"

  # Check the metadata of the processed patches
  assert_equals_helper 'Should have 6 patches metadata' "$LINENO" 6 "${#individual_patches_metadata[@]}"
  expected='3,1'
  assert_equals_helper 'Wrong metadata of patch 0' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/mpb/introduction']}"
  expected='1,3'
  assert_equals_helper 'Wrong metadata of patch 1' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/soul/sequel']}"
  expected='12,1'
  assert_equals_helper 'Wrong metadata of patch 2' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/rock/introduction']}"
  expected='2,7'
  assert_equals_helper 'Wrong metadata of patch 3' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/reggae/sequel']}"
  expected='1,3'
  assert_equals_helper 'Wrong metadata of patch 4' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/punk/sequel']}"
  expected='1,1'
  assert_equals_helper 'Wrong metadata of patch 5' "$LINENO" "$expected" "${individual_patches_metadata['http://lore.kernel.org/samba-pop/introduction']}"
}

function test_process_representative_patches_general_case()
{
  declare -a representative_patches=()
  declare -A individual_patches_metadata=()
  declare -A processed_representative_patches=()
  declare REPRESENTATIVE_PATCHES_PROCESSED=0

  local -a individual_patches
  local patch1='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'
  local patch2='id2Ætitle2Æauthor2Æemail2Æ13Æ1Æ230Æupdated2Æ'
  local patch3='id3Ætitle3Æauthor3Æemail3Æ2Æ3Æ3Æupdated3Æid1'
  local patch4='id4Ætitle4Æauthor4Æemail4Æ2Æ1Æ3Æupdated4Æid1'

  individual_patches=(
    "$patch1"
    "$patch2"
    "$patch3"
    "$patch4"
  )
  individual_patches_metadata=(
    ['id1']='2,0'
    ['id2']='13,1'
    ['id3']='2,3'
    ['id4']='2,1'
  )

  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 2 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 2 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 2 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Wrong representative patch 1' "$LINENO" "$patch2" "${representative_patches[1]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"
  assert_equals_helper 'Representative patch 1 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id2']}"
}

function test_get_raw_lore_message()
{
  local expected="curl --silent 'https://domain/list/message-id/raw'"
  local output

  output=$(get_raw_lore_message 'http://domain/list/message-id/' 'TEST-MODE')
  assert_equals_helper 'Wrong command issued' "$LINENO" "$expected" "$output"

  output=$(get_raw_lore_message 'http://domain/list/message-id' 'TEST-MODE')
  assert_equals_helper 'Wrong command issued' "$LINENO" "$expected" "$output"
}

function test_process_representative_patches_subsequent_calls()
{
  declare -a representative_patches=()
  declare -A individual_patches_metadata=()
  declare -A processed_representative_patches=()
  declare REPRESENTATIVE_PATCHES_PROCESSED=0

  local -a individual_patches
  local patch1='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'
  local patch2='id2Ætitle2Æauthor2Æemail2Æ13Æ1Æ230Æupdated2Æ'
  local patch3='id3Ætitle3Æauthor3Æemail3Æ2Æ3Æ3Æupdated3Æid1'
  local patch4='id4Ætitle4Æauthor4Æemail4Æ2Æ1Æ3Æupdated4Æid1'
  local patch5='id5Ætitle5Æauthor5Æemail5Æ32Æ4Æ6Æupdated5Æ'
  local patch6='id6Ætitle6Æauthor6Æemail6Æ4Æ2Æ14Æupdated6Æ'
  local patch7='id7Ætitle7Æauthor7Æemail7Æ1Æ0Æ5Æupdated7Æ'
  local patch8='id8Ætitle8Æauthor8Æemail8Æ1Æ1Æ5Æupdated8Æid7'

  individual_patches=(
    "$patch1"
    "$patch2"
    "$patch3"
    "$patch4"
  )
  individual_patches_metadata=(
    ['id1']='2,0'
    ['id2']='13,1'
    ['id3']='2,3'
    ['id4']='2,1'
  )

  # First call
  process_representative_patches 'individual_patches'

  # Update data structs
  individual_patches=(
    "$patch5"
    "$patch6"
    "$patch7"
    "$patch8"
  )
  individual_patches_metadata['id5']='32,4'
  individual_patches_metadata['id6']='4,2'
  individual_patches_metadata['id7']='1,0'
  individual_patches_metadata['id8']='1,1'

  # Second call
  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 3 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 3 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 3 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Wrong representative patch 1' "$LINENO" "$patch2" "${representative_patches[1]}"
  assert_equals_helper 'Wrong representative patch 2' "$LINENO" "$patch7" "${representative_patches[2]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"
  assert_equals_helper 'Representative patch 1 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id2']}"
  assert_equals_helper 'Representative patch 2 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id7']}"
}

function test_process_representative_patches_duplicated_patches()
{
  declare -a representative_patches=()
  declare -A individual_patches_metadata=()
  declare -A processed_representative_patches=()
  declare REPRESENTATIVE_PATCHES_PROCESSED=0

  local -a individual_patches
  local patch1='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'
  local patch2='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'
  local patch3='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'
  local patch4='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'

  individual_patches=(
    "$patch1"
    "$patch2"
    "$patch3"
    "$patch4"
  )
  individual_patches_metadata=(
    ['id1']='2,0'
  )

  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 1 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 1 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 1 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"
}

function test_process_representative_patches_in_reply_to_not_processed()
{
  declare -a representative_patches=()
  declare -A individual_patches_metadata=()
  declare -A processed_representative_patches=()
  declare REPRESENTATIVE_PATCHES_PROCESSED=0

  local -a individual_patches
  local patch1='id1Ætitle1Æauthor1Æemail1Æ2Æ1Æ3Æupdated1Æid-not-processed'

  individual_patches=(
    "$patch1"
  )
  individual_patches_metadata=(
    ['id1']='2,1'
  )

  # Case 1: In reply isn't a patch
  # shellcheck disable=SC2317
  function get_raw_lore_message()
  {
    printf 'Subject: Some discussion'
  }
  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 1 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 1 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 1 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"

  # Case 2: In reply is patch from same patchset, but not cover letter
  # shellcheck disable=SC2317
  function get_raw_lore_message()
  {
    printf 'Subject: [PATCH v2 2/3] Some title'
  }
  representative_patches=()
  processed_representative_patches=()
  REPRESENTATIVE_PATCHES_PROCESSED=0
  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 1 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 1 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 1 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"

  # Case 3: In reply is patch from same patchset and cover letter
  # shellcheck disable=SC2317
  function get_raw_lore_message()
  {
    printf 'Subject: [PATCH v2 0/3] Some title'
  }
  representative_patches=()
  processed_representative_patches=()
  REPRESENTATIVE_PATCHES_PROCESSED=0
  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 0 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 0 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 0 "$REPRESENTATIVE_PATCHES_PROCESSED"

  # Case 4: In reply isn't patch from same patchset and isn't cover letter
  # shellcheck disable=SC2317
  function get_raw_lore_message()
  {
    printf 'Subject: [PATCH 0/3] Some title'
  }
  representative_patches=()
  processed_representative_patches=()
  REPRESENTATIVE_PATCHES_PROCESSED=0
  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 1 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 1 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 1 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"

  # Case 5: In reply isn't patch from same patchset, but is cover letter
  # shellcheck disable=SC2317
  function get_raw_lore_message()
  {
    printf 'Subject: [PATCH 0/3] Some title'
  }
  representative_patches=()
  processed_representative_patches=()
  REPRESENTATIVE_PATCHES_PROCESSED=0
  process_representative_patches 'individual_patches'

  assert_equals_helper 'Wrong size of `representative_patches` array' "$LINENO" 1 "${#representative_patches[@]}"
  assert_equals_helper 'Wrong size of `processed_representative_patches` hashtable' "$LINENO" 1 "${#processed_representative_patches[@]}"
  assert_equals_helper 'Wrong value of `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 1 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Wrong representative patch 0' "$LINENO" "$patch1" "${representative_patches[0]}"
  assert_equals_helper 'Representative patch 0 should be marked in hashtable' "$LINENO" 1 "${processed_representative_patches['id1']}"
}

function test_read_patch_into_dict()
{
  local patch
  declare -A patch_dict

  patch='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1Æ'
  read_patch_into_dict "$patch" 'patch_dict'
  assert_equals_helper 'Wrong value of messsage ID' "$LINENO" 'id1' "${patch_dict['message_id']}"
  assert_equals_helper 'Wrong value of message title' "$LINENO" 'title1' "${patch_dict['message_title']}"
  assert_equals_helper 'Wrong value of author name' "$LINENO" 'author1' "${patch_dict['author_name']}"
  assert_equals_helper 'Wrong value of author email' "$LINENO" 'email1' "${patch_dict['author_email']}"
  assert_equals_helper 'Wrong value of version' "$LINENO" 2 "${patch_dict['version']}"
  assert_equals_helper 'Wrong value of number in series' "$LINENO" 0 "${patch_dict['number_in_series']}"
  assert_equals_helper 'Wrong value of total in series' "$LINENO" 3 "${patch_dict['total_in_series']}"
  assert_equals_helper 'Wrong value of updated' "$LINENO" 'updated1' "${patch_dict['updated']}"
  assert_equals_helper 'Wrong value of in reply to' "$LINENO" '' "${patch_dict['in_reply_to']}"
  assert_equals_helper 'Wrong value of download dir path' "$LINENO" '' "${patch_dict['download_dir_path']}"
  assert_equals_helper 'Wrong value of timestamp' "$LINENO" '' "${patch_dict['timestamp']}"

  patch='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1ÆidX'
  read_patch_into_dict "$patch" 'patch_dict'
  assert_equals_helper 'Wrong value of messsage ID' "$LINENO" 'id1' "${patch_dict['message_id']}"
  assert_equals_helper 'Wrong value of message title' "$LINENO" 'title1' "${patch_dict['message_title']}"
  assert_equals_helper 'Wrong value of author name' "$LINENO" 'author1' "${patch_dict['author_name']}"
  assert_equals_helper 'Wrong value of author email' "$LINENO" 'email1' "${patch_dict['author_email']}"
  assert_equals_helper 'Wrong value of version' "$LINENO" 2 "${patch_dict['version']}"
  assert_equals_helper 'Wrong value of number in series' "$LINENO" 0 "${patch_dict['number_in_series']}"
  assert_equals_helper 'Wrong value of total in series' "$LINENO" 3 "${patch_dict['total_in_series']}"
  assert_equals_helper 'Wrong value of updated' "$LINENO" 'updated1' "${patch_dict['updated']}"
  assert_equals_helper 'Wrong value of in reply to' "$LINENO" 'idX' "${patch_dict['in_reply_to']}"
  assert_equals_helper 'Wrong value of download dir path' "$LINENO" '' "${patch_dict['download_dir_path']}"
  assert_equals_helper 'Wrong value of timestamp' "$LINENO" '' "${patch_dict['timestamp']}"

  patch='id1Ætitle1Æauthor1Æemail1Æ2Æ0Æ3Æupdated1ÆidXÆpath1Ætimestamp1'
  read_patch_into_dict "$patch" 'patch_dict'
  assert_equals_helper 'Wrong value of messsage ID' "$LINENO" 'id1' "${patch_dict['message_id']}"
  assert_equals_helper 'Wrong value of message title' "$LINENO" 'title1' "${patch_dict['message_title']}"
  assert_equals_helper 'Wrong value of author name' "$LINENO" 'author1' "${patch_dict['author_name']}"
  assert_equals_helper 'Wrong value of author email' "$LINENO" 'email1' "${patch_dict['author_email']}"
  assert_equals_helper 'Wrong value of version' "$LINENO" 2 "${patch_dict['version']}"
  assert_equals_helper 'Wrong value of number in series' "$LINENO" 0 "${patch_dict['number_in_series']}"
  assert_equals_helper 'Wrong value of total in series' "$LINENO" 3 "${patch_dict['total_in_series']}"
  assert_equals_helper 'Wrong value of updated' "$LINENO" 'updated1' "${patch_dict['updated']}"
  assert_equals_helper 'Wrong value of in reply to' "$LINENO" 'idX' "${patch_dict['in_reply_to']}"
  assert_equals_helper 'Wrong value of download dir path' "$LINENO" 'path1' "${patch_dict['download_dir_path']}"
  assert_equals_helper 'Wrong value of timestamp' "$LINENO" 'timestamp1' "${patch_dict['timestamp']}"
}

function test_reset_current_lore_fetch_session()
{

  representative_patches[0]=1
  representative_patches[1]=1
  representative_patches[2]=1
  declare -Ag individual_patches_metadata
  individual_patches_metadata['patch_1a']=1
  individual_patches_metadata['patch_1b']=1
  individual_patches_metadata['patch_1c']=1
  individual_patches_metadata['patch_2']=1
  individual_patches_metadata['patch_3a']=1
  individual_patches_metadata['patch_3b']=1
  individual_patches_metadata['patch_3c']=1
  individual_patches_metadata['patch_3d']=1
  declare -Ag processed_representative_patches
  processed_representative_patches['patch_1']=1
  processed_representative_patches['patch_2']=1
  processed_representative_patches['patch_3']=1
  REPRESENTATIVE_PATCHES_PROCESSED=3
  MIN_INDEX=200

  reset_current_lore_fetch_session
  assert_equals_helper 'Should reset `representative_patches`' "$LINENO" 0 "${#representative_patches[@]}"
  assert_equals_helper 'Should reset `REPRESENTATIVE_PATCHES_PROCESSED`' "$LINENO" 0 "$REPRESENTATIVE_PATCHES_PROCESSED"
  assert_equals_helper 'Should reset `MIN_INDEX`' "$LINENO" 0 "$MIN_INDEX"
  assert_equals_helper 'Should reset `processed_representative_patches`' "$LINENO" 0 "${#processed_representative_patches[@]}"
}

function test_format_patchsets()
{
  local -a formatted_patchsets_list
  local output

  representative_patches[0]='message-id0Ætitle0Æauthor0Æemail0Æ2Æ1Æ6Æupdated0 11:34Æin-reply-to0Ædir0Ætimestamp0'
  representative_patches[1]='message-id1Ætitle1Æauthor1Æemail1Æ1Æ0Æ3Æupdated1 12:23Æin-reply-to1Ædir1Ætimestamp1'
  representative_patches[2]='message-id2Ætitle2Æauthor2Æemail2Æ16Æ1Æ8Æupdated2 21:50Æin-reply-to2Ædir2Ætimestamp2'
  formatted_patchsets_list[0]='Vold |#old |  titleold | updatedold | authorold'

  format_patchsets 'formatted_patchsets_list' 1 2
  assert_equals_helper 'Wrong number of patchsets formatted' "$LINENO" 3 "${#formatted_patchsets_list[@]}"

  expected='Vold |#old |  titleold | updatedold | authorold'
  assert_equals_helper 'Should not overwrite out-of-range entry' "$LINENO" "$expected" "${formatted_patchsets_list[0]}"

  expected='V1  |#3  | title1                                                       | updated1 | author1'
  output=$(printf '%s' "${formatted_patchsets_list[1]}" | sed 's/ *$//') # trim trailing whitespace
  assert_equals_helper 'Wrong formatted patchset 1' "$LINENO" "$expected" "$output"

  expected='V16 |#8  | title2                                                       | updated2 | author2'
  output=$(printf '%s' "${formatted_patchsets_list[2]}" | sed 's/ *$//') # trim trailing whitespace
  assert_equals_helper 'Wrong formatted patchset 2' "$LINENO" "$expected" "$output"
}

function test_get_page_starting_index()
{
  local page
  local patchsets_per_page
  local output

  # Mocking `representative_patches` with 199 patchsets
  unset representative_patches
  declare -gA representative_patches
  for i in $(seq 0 199); do
    representative_patches["$i"]=1
  done

  page=5
  patchsets_per_page=42
  output=$(get_page_starting_index "$page" "$patchsets_per_page")
  assert_equals_helper 'Wrong starting index outputted' "$LINENO" 168 "$output"

  page=5
  patchsets_per_page=50
  output=$(get_page_starting_index "$page" "$patchsets_per_page")
  assert_equals_helper 'Wrong starting index outputted' "$LINENO" 199 "$output"
}

function test_get_page_ending_index()
{
  local page
  local patchsets_per_page
  local output

  # Mocking `representative_patches` with 199 patchsets
  unset representative_patches
  declare -gA representative_patches
  for i in $(seq 0 199); do
    representative_patches["$i"]=1
  done

  page=3
  patchsets_per_page=42
  output=$(get_page_ending_index "$page" "$patchsets_per_page")
  assert_equals_helper 'Wrong ending index outputted' "$LINENO" 125 "$output"

  page=5
  patchsets_per_page=50
  output=$(get_page_ending_index "$page" "$patchsets_per_page")
  assert_equals_helper 'Wrong ending index outputted' "$LINENO" 199 "$output"
}

invoke_shunit

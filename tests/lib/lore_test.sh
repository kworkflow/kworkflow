#!/bin/bash

include './src/lib/lore.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache"
  export CACHE_LORE_DIR="${KW_CACHE_DIR}/lore"
  export LIST_PAGE_PATH="${CACHE_LORE_DIR}/lore_main_page.html"
  export LORE_DATA_DIR="${SHUNIT_TMPDIR}/lore"
  export BOOKMARKED_SERIES_PATH="${LORE_DATA_DIR}/lore_bookmarked_series"

  mkdir -p "$CACHE_LORE_DIR"
  mkdir -p "${LORE_DATA_DIR}"

  cp "${SAMPLES_DIR}/web/reduced_lore_main_page.html" "${CACHE_LORE_DIR}/lore_main_page.html"
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

function test_add_series_to_bookmark()
{
  local target_patch1='someseries1'
  local target_patch2='someseries2'
  local target_patch3='someseries3'
  local download_dir_path='somedir'
  local output
  local count

  add_series_to_bookmark "${target_patch1}" "${download_dir_path}"
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  printf '%s' "$output" | grep --quiet "${target_patch1}${SEPARATOR_CHAR}${download_dir_path}"
  assertTrue "($LINENO) - Should add series to local bookmark database" "[[ \"$?\" == 0 ]]"

  add_series_to_bookmark "${target_patch1}" "${download_dir_path}"
  output=$(< "${BOOKMARKED_SERIES_PATH}")
  count=$(printf '%s' "$output" | grep --count "${target_patch1}${SEPARATOR_CHAR}${download_dir_path}")
  assertEquals "($LINENO) - Should not duplicate entries " 1 "$count"

  add_series_to_bookmark "${target_patch2}" "${download_dir_path}"
  add_series_to_bookmark "${target_patch3}" "${download_dir_path}"
  count=$(wc --lines "${BOOKMARKED_SERIES_PATH}" | cut --delimiter ' ' -f1)
  assertEquals "($LINENO) - Should have 3 entries" 3 "$count"
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
    printf 'AUTHOR1%s %s %s %sTITLE1%s %s %s %sDATE1\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char"
    printf 'AUTHOR2%s %s %s %sTITLE2%s %s %s %sDATE2\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char"
    printf 'AUTHOR3%s %s %s %sTITLE3%s %s %s %sDATE3\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char" "$char"
  } >> "${BOOKMARKED_SERIES_PATH}"

  get_bookmarked_series bookmarked_series

  expected=' DATE1 | TITLE1                                                                 | AUTHOR1'
  assertEquals "($LINENO)" "$expected" "${bookmarked_series[0]}"
  expected=' DATE2 | TITLE2                                                                 | AUTHOR2'
  assertEquals "($LINENO)" "$expected" "${bookmarked_series[1]}"
  expected=' DATE3 | TITLE3                                                                 | AUTHOR3'
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

function test_is_boookmarked()
{
  # The below are the sha256sum of 'entry1', 'entry2' and 'entry3', respectively
  {
    printf 'c17dd9010a5c6b0e5b2ad5a845762d8b206e6166a4e63d32deca8c5664fdfcac\n'
    printf 'ad2063741cce2d9f2862b07152b06528d175e9e658ade8f2daa416834c9c089a\n'
    printf 'a671a481a0edc8cd6eab7640f9c8e225a82e5c8e49122a86158f20fa22254409\n'
  } >> "${BOOKMARKED_SERIES_PATH}"

  is_bookmarked 'entry2'
  assertEquals "($LINENO) - Should return 0 (patch bookmarked)" 0 "$?"

  is_bookmarked 'entry1234'
  assertEquals "($LINENO) - Should return 1 (patch not bookmarked)" 1 "$?"

  if [[ "${BOOKMARKED_SERIES_PATH}" != '/' ]]; then
    rm "${BOOKMARKED_SERIES_PATH}"
  fi
  is_bookmarked 'entry3'
  assertEquals "($LINENO) - Should return 2 (local bookmark database non-existent)" 2 "$?"
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
  expected+="b4 --quiet am '${series_url}' --no-cover --outdir '${save_to}' --mbox-name '1234567.789-1-email@email.com.mbx'"
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

invoke_shunit

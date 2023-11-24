#!/bin/bash

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
    printf 'AUTHOR1%s %s %s %sTITLE1%s %s %sDATE1\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char"
    printf 'AUTHOR2%s %s %s %sTITLE2%s %s %sDATE2\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char"
    printf 'AUTHOR3%s %s %s %sTITLE3%s %s %sDATE3\n' "$char" "$char" "$char" "$char" "$char" "$char" "$char"
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

function test_get_patchset_bookmark_status()
{
  local output

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
  expected='https://lore.kernel.org/amd-gfx/?x=A&o=200&q=rt:..+AND+NOT+s:Re'
  output=$(compose_lore_query_url_with_verification "$target_mailing_list" "$min_index")
  assert_equals_helper 'Valid arguments should return 0' "$LINENO" 0 "$?"
  assert_equals_helper 'Wrong query URL outputted' "$LINENO" "$expected" "$output"

  target_mailing_list='amd-gfx'
  min_index='-200'
  expected='https://lore.kernel.org/amd-gfx/?x=A&o=-200&q=rt:..+AND+NOT+s:Re'
  output=$(compose_lore_query_url_with_verification "$target_mailing_list" "$min_index")
  assert_equals_helper 'Valid arguments should return 0' "$LINENO" 0 "$?"
  assert_equals_helper 'Wrong query URL outputted' "$LINENO" "$expected" "$output"

  target_mailing_list='amd-gfx'
  min_index='200'
  additional_filters='s:drm%2Famdgpu+AND+NOT+f:David%20Tadokoro'
  expected='https://lore.kernel.org/amd-gfx/?x=A&o=200&q=rt:..+AND+NOT+s:Re+AND+s:drm%2Famdgpu+AND+NOT+f:David%20Tadokoro'
  output=$(compose_lore_query_url_with_verification "$target_mailing_list" "$min_index" "$additional_filters")
  assert_equals_helper 'Valid arguments should return 0' "$LINENO" 0 "$?"
  assert_equals_helper 'Wrong query URL outputted' "$LINENO" "$expected" "$output"
}

function test_pre_process_xml_result()
{
  local output
  local expected

  output=$(pre_process_xml_result "${SHUNIT_TMPDIR}/samples/query_result_sample-1.xml")
  expected=$(< "${SHUNIT_TMPDIR}/samples/pre_processed_patches_sample-1")
  assert_equals_helper 'Wrong pre-processed result' "$LINENO" "$expected" "$output"
}

function test_process_patchsets()
{
  local pre_processed_patches_sample
  local expected

  # shellcheck disable=SC2317
  function is_introduction_patch()
  {
    local patch_url="$1"
    [[ "$patch_url" =~ introduction ]] && return 0
    return 1
  }

  # shellcheck disable=SC2317
  function extract_metadata_from_patch_title()
  {
    local patch_title="${1}${SEPARATOR_CHAR}"
    local patch_url="$2"
    local patchset_version="X${SEPARATOR_CHAR}"
    local total_patches="X${SEPARATOR_CHAR}"

    printf '%s%s%s%s' "$patchset_version" "$total_patches" "$patch_title" "$patch_url"
  }

  function test_first_process_patchset()
  {
    # Clear number of patchsets processed and data structure with patchsets
    reset_current_lore_fetch_session

    pre_processed_patches_sample=$(< "${SHUNIT_TMPDIR}/samples/pre_processed_patches_sample-1")
    process_patchsets "$pre_processed_patches_sample"
    assert_equals_helper 'Wrong number of patchsets processed' "$LINENO" 2 "$PATCHSETS_PROCESSED"

    expected='Gilberto GilÆgil.gil@mpb.brÆXÆXÆ[PATCH v3] Add Palco to MPBÆhttp://lore.kernel.org/mpb/introduction'
    assert_equals_helper 'Wrong processed patchset (index 0)' "$LINENO" "$expected" "${list_of_mailinglist_patches[0]}"

    expected='David BowieÆmajor.tom@rock.ukÆXÆXÆ[RFC PATCH v12] Introduce Ziggy StardustÆhttp://lore.kernel.org/rock/introduction'
    assert_equals_helper 'Wrong processed patchset (index 1)' "$LINENO" "$expected" "${list_of_mailinglist_patches[1]}"
  }

  # Process second batch of pre processed patches
  function test_second_process_patchset()
  {
    pre_processed_patches_sample=$(< "${SHUNIT_TMPDIR}/samples/pre_processed_patches_sample-2")
    process_patchsets "$pre_processed_patches_sample"
    assert_equals_helper 'Wrong number of patchsets processed' "$LINENO" 3 "$PATCHSETS_PROCESSED"

    expected='Gilberto GilÆgil.gil@mpb.brÆXÆXÆ[PATCH v3] Add Palco to MPBÆhttp://lore.kernel.org/mpb/introduction'
    assert_equals_helper 'Wrong processed patchset (index 0)' "$LINENO" "$expected" "${list_of_mailinglist_patches[0]}"

    expected='David BowieÆmajor.tom@rock.ukÆXÆXÆ[RFC PATCH v12] Introduce Ziggy StardustÆhttp://lore.kernel.org/rock/introduction'
    assert_equals_helper 'Wrong processed patchset (index 1)' "$LINENO" "$expected" "${list_of_mailinglist_patches[1]}"

    expected='Seu JorgeÆseu.jorge@samba-pop.brÆXÆXÆ[RFC] Release Músicas para Churrasco Vol.1Æhttp://lore.kernel.org/samba-pop/introduction'
    assert_equals_helper 'Wrong processed patchset (index 2)' "$LINENO" "$expected" "${list_of_mailinglist_patches[2]}"
  }

  test_first_process_patchset
  test_second_process_patchset
}

function test_process_patchsets_repeated_patches()
{
  local pre_processed_patches_sample
  local expected

  # Clear number of patchsets processed and data structure with patchsets
  reset_current_lore_fetch_session

  # Process list of repeated pre processed patches
  pre_processed_patches_sample=$(< "${SHUNIT_TMPDIR}/samples/pre_processed_patches_sample-repeated")
  process_patchsets "$pre_processed_patches_sample"
  assert_equals_helper 'Repeated patches should not be processed again' "$LINENO" 1 "$PATCHSETS_PROCESSED"

  expected='David BowieÆmajor.tom@rock.ukÆXÆXÆ[RFC PATCH v12] Introduce Ziggy StardustÆhttp://lore.kernel.org/rock/introduction'
  assert_equals_helper 'Wrong processed patchset (index 0)' "$LINENO" "$expected" "${list_of_mailinglist_patches[0]}"
}

function test_reset_current_lore_fetch_session()
{
  list_of_mailinglist_patches[0]=1
  list_of_mailinglist_patches[1]=1
  list_of_mailinglist_patches[2]=1
  PATCHSETS_PROCESSED=3
  MIN_INDEX=200

  declare -Ag processed_patchsets
  processed_patchsets['patch_1']=1
  processed_patchsets['patch_2']=1
  processed_patchsets['patch_3']=1

  reset_current_lore_fetch_session 2
  assert_equals_helper 'Should reset `list_of_mailinglist_patches`' "$LINENO" 0 "${#list_of_mailinglist_patches[@]}"
  assert_equals_helper 'Should reset `PATCHSETS_PROCESSED`' "$LINENO" 0 "$PATCHSETS_PROCESSED"
  assert_equals_helper 'Should reset `MIN_INDEX`' "$LINENO" 0 "$MIN_INDEX"
  assert_equals_helper 'Should reset `processed_patchsets`' "$LINENO" 0 "${#processed_patchsets[@]}"
}

function test_format_patchsets()
{
  local -a formatted_patchsets_list

  list_of_mailinglist_patches[0]='Jay CornwallÆjay.cornwall@amd.comÆ1Æ1Ædrm/amdkfd: Add missing tba_hi programming on aldebaranÆ'
  list_of_mailinglist_patches[0]+='http://lore.kernel.org/amd-gfx/20230809212615.137674-1-jay.cornwall@amd.com/'
  list_of_mailinglist_patches[1]='Alex DeucherÆalexander.deucher@amd.comÆ1Æ10Ædrm/amdgpu: don'"'"'t allow userspace to create a doorbell BOÆ'
  list_of_mailinglist_patches[1]+='http://lore.kernel.org/amd-gfx/20230809190956.435068-1-alexander.deucher@amd.com/'
  list_of_mailinglist_patches[2]='Juca PiramaÆjuca.pirama@jp.comÆ3Æ1Ædrm/amdgpu: improve everythingÆ'
  list_of_mailinglist_patches[2]+='http://lore.kernel.org/amd-gfx/15230802663656.432068-1-juca.pirama@jp.com/'
  formatted_patchsets_list[0]=1

  format_patchsets 'formatted_patchsets_list' 1 2
  assert_equals_helper 'Wrong number of patchsets formatted' "$LINENO" 3 "${#formatted_patchsets_list[@]}"

  expected='V1  |#10 | drm/amdgpu: don'"'"'t allow userspace to create a doorbell BO'
  [[ "${formatted_patchsets_list[1]}" =~ $expected ]] # to account for trailing whitespace
  assert_equals_helper 'Wrong formatted patchset' "$LINENO" 0 "$?"

  expected='V3  |#1  | drm/amdgpu: improve everything'
  [[ "${formatted_patchsets_list[2]}" =~ $expected ]] # to account for trailing whitespace
  assert_equals_helper 'Wrong formatted patchset' "$LINENO" 0 "$?"
}

function test_get_page_starting_index()
{
  local page
  local patchsets_per_page
  local output

  # Mocking `list_of_mailinglist_patches` with 199 patchsets
  unset list_of_mailinglist_patches
  declare -gA list_of_mailinglist_patches
  for i in $(seq 0 199); do
    list_of_mailinglist_patches["$i"]=1
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

  # Mocking `list_of_mailinglist_patches` with 199 patchsets
  unset list_of_mailinglist_patches
  declare -gA list_of_mailinglist_patches
  for i in $(seq 0 199); do
    list_of_mailinglist_patches["$i"]=1
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

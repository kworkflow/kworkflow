#!/usr/bin/env bash

include './src/ui/patch_hub/latest_patchsets_from_mailing_list.sh'
include './tests/unit/utils.sh'

function setUp() {
  export ORIGINAL_PATH="$PWD"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown() {
  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
}

invoke_shunit

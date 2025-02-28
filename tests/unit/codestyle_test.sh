#!/usr/bin/env bash

include './src/codestyle.sh'
include './tests/unit/utils.sh'

# Those variables hold the last line codestyle_main prints in a code that is
# correct, has 1 warning, has 1 erros and has 1 check, respectively. The sample
# codes used in this test are in tests/unit/samples/

function oneTimeSetUp() {
	mk_fake_kernel_root "$SHUNIT_TMPDIR"

	cp -r tests/unit/samples "$SHUNIT_TMPDIR"

	parse_configuration "$KW_CONFIG_SAMPLE"
}

function test_invalid_path() {
	local build_fake_path
	local output
	local ret

	build_fake_path=$(create_invalid_file_path)

	output=$(codestyle_main "$build_fake_path")
	ret="$?"
	assertEquals 'We forced an invalid path and we expect an error' '2' "$ret"
}

function test_no_kernel_directory() {
	local sample_one="$SAMPLES_DIR/codestyle_warning.c"
	local output

	# We want to force an unexpected condition, because of this we change the
	# basic setup but we rebuild it at the end of the test
	oneTimeTearDown

	output=$(codestyle_main "$sample_one")
	ret="$?"
	assertFalse 'We forced an invalid path and we expect an error' '[[ $ret != 22 ]]'

	oneTimeSetUp
}

function test_multiple_files_output() {
	local delimiter="$SEPARATOR"
	local array=()
	local output

	output=$(codestyle_main "$SHUNIT_TMPDIR/samples" 2>&1)

	# Reference: https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/
	s="$output$delimiter"
	while [[ "$s" ]]; do
		array+=("${s%%"$delimiter"*}")
		s=${s#*"$delimiter"}
	done

	size="${#array[@]}"
	# We use three here because we expect one $SEPARATOR from the beginning and
	# other from s="$output$delimiter"
	assertFalse 'We could not find more then two SEPARATOR sequence' '[[ $size -lt "3" ]]'
}

function test_run_codestyle_in_a_path() {
	local cmd="perl ${SHUNIT_TMPDIR}/scripts/checkpatch.pl --no-tree --color=always --strict"
	local patch_path="${TMP_TEST_DIR}/samples/test.patch"
	local patch_path="${SHUNIT_TMPDIR}/samples/test.patch"
	local output
	local real_path
	local base_msg

	real_path=$(realpath "$patch_path")
	base_msg="Running checkpatch.pl on: $real_path"

	declare -a expected_cmd=(
		"$base_msg"
		"$SEPARATOR"
		"$cmd $real_path"
	)

	output=$(codestyle_main "$patch_path" 'TEST_MODE' 2>&1)
	compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_run_codestyle_in_a_file() {
	local cmd="perl ${SHUNIT_TMPDIR}/scripts/checkpatch.pl --terse --no-tree --color=always --strict --file"
	local patch_path="${SHUNIT_TMPDIR}/samples/codestyle_correct.c"
	local output
	local real_path
	local base_msg

	real_path=$(realpath "$patch_path")
	base_msg="Running checkpatch.pl on: $real_path"

	declare -a expected_cmd=(
		"$base_msg"
		"$SEPARATOR"
		"$cmd $real_path"
	)

	output=$(codestyle_main "$patch_path" 'TEST_MODE' 2>&1)
	compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit

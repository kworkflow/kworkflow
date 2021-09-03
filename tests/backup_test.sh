#!/bin/bash

include './src/backup.sh'
include './src/kwlib.sh'
include './tests/utils.sh'

function setUp()
{
  KW_DATA_DIR="$SHUNIT_TMPDIR/data"
  decompress_path="$SHUNIT_TMPDIR/tmp-kw-backup"

  mkdir -p "$KW_DATA_DIR"
  mkdir -p "$decompress_path"

  cp -r tests/samples/configs "$KW_DATA_DIR"
  cp -r tests/samples/pomodoro_data "$KW_DATA_DIR/pomodoro"
  cp -r tests/samples/statistics "$KW_DATA_DIR"
}

function test_create_backup()
{
  local output
  local filepath
  local current_path="$PWD"
  declare -a expected_files
  declare -a tar_files

  # expected_files is an array whose elements are the files from our mock
  # KW_DATA_DIR sorted by dictonary order
  mapfile -t expected_files < <(for f in $(find "$KW_DATA_DIR" -type f | sort -d); do
    str_remove_prefix "$f" "$KW_DATA_DIR/"
  done)

  output=$(create_backup /randomly/random/path)
  assertEquals "$LINENO" "$output" 'We could not find the path'

  output=$(create_backup "$SHUNIT_TMPDIR" 'SILENT')
  filepath=$(str_remove_prefix "$output" 'Backup successfully created at ')
  assertTrue "($LINENO) - Tar file was not created" "[[ -f $filepath ]]"

  tar_files=("$(tar -taf "$filepath" | grep -e '[^/]$' | sort -d | cut -c3-)")
  compare_command_sequence 'expected_files' "${tar_files[@]}" "$LINENO"
}

function test_restore_backup()
{
  local output

  output=$(restore_backup "$SHUNIT_TMPDIR"/random/path/backup.tar.gz)
  assertEquals "($LINENO)" "$output" 'We could not find this file'

  output=$(restore_backup tests/samples/kw-backup-2021-08-07_23-42-51.tar.gz)
  assertTrue "($LINENO) Not all files were extracted" \
    "[[ -f $KW_DATA_DIR/configs/configs/config-test ]] && [[ -f $KW_DATA_DIR/configs/metadata/config-test ]]"

  rm -rf "${KW_DATA_DIR:?}"/*
  options_values['FORCE']=1
  output=$(restore_backup tests/samples/kw-backup-2021-08-07_23-42-51.tar.gz)
  assertTrue "($LINENO) Not all files were extracted" \
    "[[ -f $KW_DATA_DIR/configs/configs/config-test ]] && [[ -f $KW_DATA_DIR/configs/metadata/config-test ]]"
}

function test_restore_config()
{
  local config_2_last_line

  rm -rf "${KW_DATA_DIR:?}"/*

  restore_config

  assertTrue "($LINENO) - Config file wasn't restored" \
    "[[ -f $KW_DATA_DIR/configs/configs/config-test ]]"

  assertTrue "($LINENO) - Config metadata wasn't restored" \
    "[[ -f $KW_DATA_DIR/configs/metadata/config-test ]]"

  # Restore config with same file name and different content
  cp "$KW_DATA_DIR/configs/configs/config-test" "$KW_DATA_DIR/configs/configs/config-2"
  cp "$KW_DATA_DIR/configs/metadata/config-test" "$KW_DATA_DIR/configs/metadata/config-2"
  cp "$KW_DATA_DIR/configs/configs/config-test" "$decompress_path/configs/configs/config-2"
  cp "$KW_DATA_DIR/configs/metadata/config-test" "$decompress_path/configs/metadata/config-2"
  printf '%s\n' '# This line is different' >> "$decompress_path/configs/configs/config-2"

  config_2_last_line=$(tail -n 1 "$KW_DATA_DIR/configs/configs/config-2")
  output=$(printf '%s\n' 'n' | restore_config)
  assertEquals "$LINENO" "$(printf '%s\n' "$output" | head -n 1)" 'It looks like that the file config-2 differs from the backup version.'

  # Since we answered no above, we expect config-2 to remain the same
  assertEquals "$LINENO" "$config_2_last_line" "$(tail -n 1 "$KW_DATA_DIR/configs/configs/config-2")"

  output=$(printf '%s\n' 'y' | restore_config)
  assertEquals "$LINENO" "$(printf '%s\n' "$output" | head -n 1)" 'It looks like that the file config-2 differs from the backup version.'

  # Now config-2 should be changed, as we said yes above
  config_2_last_line=$(tail -n 1 "$KW_DATA_DIR/configs/configs/config-2")
  assertEquals "$LINENO" "$config_2_last_line" '# This line is different'
}

function test_restore_data_from_dir()
{
  declare -a expected_cmd=(
    'It looks like that the file 2021/04/04 differs from the backup version.'
    'Do you want to:'
    '(1) Replace all duplicate files with backup'
    '(2) Keep all the old files'
    '(3) Aggregate all old and backup files'
  )

  mkdir -p "$decompress_path/pomodoro/"
  cp -r tests/samples/pomodoro_data/2021 "$decompress_path/pomodoro/"

  # Test duplicate files
  printf '%s\n' '# This line is different' >> "$decompress_path/pomodoro/2021/04/04"

  output=$(printf '%s\n' '2' | restore_data_from_dir 'pomodoro')
  assertNotEquals "$LINENO" '# This line is different' "$(tail -n 1 "$KW_DATA_DIR/pomodoro/2021/04/04")"

  output=$(printf '%s\n' '1' | restore_data_from_dir 'pomodoro')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
  assertEquals "$LINENO" '# This line is different' "$(tail -n 1 "$KW_DATA_DIR/pomodoro/2021/04/04")"

  expected_cmd+=("patching file $KW_DATA_DIR/pomodoro/2021/04/04")

  printf '%s\n' '# Another different line' >> "$decompress_path/pomodoro/2021/04/04"
  output=$(printf '%s\n' '3' | restore_data_from_dir 'pomodoro')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
  assertEquals "$LINENO" '# Another different line' "$(tail -n 1 "$KW_DATA_DIR/pomodoro/2021/04/04")"
}

function test_restore_pomodoro()
{
  rm -rf "${KW_DATA_DIR:?}"/*
  mkdir -p "$decompress_path/pomodoro/"

  cp -r tests/samples/pomodoro_data/2021 "$decompress_path/pomodoro/"
  touch "$decompress_path/pomodoro/tags"

  restore_pomodoro

  assertTrue "($LINENO) - Pomodoro wasn't restored" \
    "cmp -s $KW_DATA_DIR/pomodoro/2021/04/04 $decompress_path/pomodoro/2021/04/04"
}

function test_restore_statistics()
{
  rm -rf "${KW_DATA_DIR:?}"/*
  mkdir -p "$decompress_path/statistics/"

  cp -r tests/samples/statistics "$decompress_path"

  restore_statistics

  assertTrue "($LINENO) - Statistics weren't restored" \
    "[[ -d $KW_DATA_DIR/statistics/2021/10 ]] && [[ -d $KW_DATA_DIR/statistics/2020/05 ]]"
}

function test_parse_backup_options()
{
  local output
  local current_path="$PWD"

  unset options_values
  declare -gA options_values
  parse_backup_options --restore backup.tar.gz
  assertEquals "($LINENO)" 'backup.tar.gz' "${options_values['RESTORE_PATH']}"

  unset options_values
  declare -gA options_values
  parse_backup_options -r backup.tar.gz
  assertEquals "($LINENO)" 'backup.tar.gz' "${options_values['RESTORE_PATH']}"

  unset options_values
  declare -gA options_values
  parse_backup_options --force
  assertEquals "($LINENO)" '1' "${options_values['FORCE']}"

  unset options_values
  declare -gA options_values
  parse_backup_options -f
  assertEquals "($LINENO)" '1' "${options_values['FORCE']}"

  unset options_values
  declare -gA options_values
  parse_backup_options /path
  assertEquals "($LINENO)" '/path' "${options_values['BACKUP_PATH']}"

  unset options_values
  declare -gA options_values
  parse_backup_options --restore > /dev/null
  assertEquals "($LINENO)" "kw backup: option '--restore' requires an argument" "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_backup_options -b > /dev/null
  assertEquals "($LINENO)" "kw backup: invalid option -- 'b'" "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_backup_options --ristore > /dev/null
  assertEquals "($LINENO)" "kw backup: unrecognized option '--ristore'" "${options_values['ERROR']}"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }

  unset options_values
  declare -gA options_values
  parse_backup_options
  assertEquals "($LINENO)" "$SHUNIT_TMPDIR" "${options_values['BACKUP_PATH']}"

  cd "$current_path" || {
    fail "($LINENO): It was not possible to move back from temp directory"
    return
  }
}

invoke_shunit

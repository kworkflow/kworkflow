#!/bin/bash

include './src/build_and_deploy.sh'
include './tests/unit/utils.sh'

function test_parse_build_and_deploy_options()
{
  last_commit="hash"
  deploy_args="--reboot"

  parse_build_and_deploy_options "$last_commit"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  assert_equals_helper "no arguments" "(${LINENO})" "$run_bisect" "0"

  parse_build_and_deploy_options "$last_commit" "--good"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  assert_equals_helper "good with default value: run_bisect" "(${LINENO})" "$run_bisect" 1
  assert_equals_helper "good with default value: good" "(${LINENO})" "$good" "$last_commit"
  assert_equals_helper "good with default value: bad" "(${LINENO})" "$bad" "$last_commit"

  custom_commit="hash2"
  parse_build_and_deploy_options "$last_commit" "--good $custom_commit"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  assert_equals_helper "good with custom value: run_bisect" "(${LINENO})" "$run_bisect" 1
  assert_equals_helper "good with custom value: good" "(${LINENO})" "$good" "$custom_commit"
  assert_equals_helper "good with custom value: bad" "(${LINENO})" "$bad" "$last_commit"

  parse_build_and_deploy_options "$last_commit" "--good $custom_commit --bad $custom_commit"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  assert_equals_helper "both with custom value: run_bisect" "(${LINENO})" "$run_bisect" 1
  assert_equals_helper "both with custom value: good" "(${LINENO})" "$good" "$custom_commit"
  assert_equals_helper "both with custom value: bad" "(${LINENO})" "$bad" "$custom_commit"

  parse_build_and_deploy_options "$last_commit" "--bad"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  assert_equals_helper "bad with default value: run_bisect" "(${LINENO})" "$run_bisect" 1
  assert_equals_helper "bad with default value: good" "(${LINENO})" "$good" "$last_commit"
  assert_equals_helper "bad with default value: bad" "(${LINENO})" "$bad" "$last_commit"

  parse_build_and_deploy_options "$last_commit" "--bad $custom_commit"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  assert_equals_helper "bad with custom value: run_bisect" "(${LINENO})" "$run_bisect" 1
  assert_equals_helper "bad with custom value: good" "(${LINENO})" "$good" "$last_commit"
  assert_equals_helper "bad with custom value: bad" "(${LINENO})" "$bad" "$custom_commit"

  parse_build_and_deploy_options "$last_commit" "$deploy_args"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  deploy_main_args="${options_values['DEPLOY_MAIN_ARGS']}"
  assert_equals_helper "kw bd with deploy arguments: run_bisect" "(${LINENO})" "$run_bisect" 0
  assert_equals_helper "kw bd with deploy arguments: good" "(${LINENO})" "$deploy_main_args" " --reboot"

  parse_build_and_deploy_options "$last_commit" "$deploy_args" "--good"
  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  deploy_main_args="${options_values['DEPLOY_MAIN_ARGS']}"
  assert_equals_helper "kw bd with own and deploy arguments: run_bisect" "(${LINENO})" "$run_bisect" 1
  assert_equals_helper "kw bd with own and deploy arguments: good" "(${LINENO})" "$good" "$last_commit"
  assert_equals_helper "kw bd with own and deploy arguments: bad" "(${LINENO})" "$bad" "$last_commit"
  assert_equals_helper "kw bd with own and deploy arguments: good" "(${LINENO})" "$deploy_main_args" " --reboot"

}

invoke_shunit

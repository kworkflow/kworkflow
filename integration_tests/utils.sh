function invoke_shunit()
{
  # Eat all command-line arguments before calling shunit2.
  # reference: https://github.com/kward/shunit2/wiki/Cookbook#passing-arguments-to-test-script
  shift $#

  command -v shunit2 > /dev/null
  if [[ "$?" -eq 0 ]]; then
    . shunit2
  elif [[ -d ./shunit2 ]]; then
    . ./shunit2/shunit2
  else
    echo -e "Can't find shunit2.\nDo you have it installed (or downloaded it to integration_tests/shunit2)?"
    return 1
  fi
}

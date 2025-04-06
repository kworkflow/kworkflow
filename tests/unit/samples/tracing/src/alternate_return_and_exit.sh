function foo() {
  command1 && command2 && return 0
  command3 && command4 && exit 0
}

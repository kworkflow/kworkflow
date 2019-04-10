#!/usr/bin/env fish

# reset PATH and fish_complete_path environment variables
set bash_path (dirname (whereis bash | awk '{print $2}'))
set awk_path (dirname (whereis awk | awk '{print $2}'))
set PATH ".:$bash_path:$awk_path"
set fish_complete_path ""

source "./etc/fish_completion/kw.fish"

set awk_kw_get_completions '{print $1}'

complete -C'kw ' | awk "$awk_kw_get_completions"


#!/usr/bin/env fish

# Test if the kw command has subcommands
function __fish_kw_no_commands
    set cmd (commandline -opc)
    if [ "$cmd" = "kw" ]
        return 0
    end

    return 1
end

# Disable file completion when there's no specified command
complete -c kw -n __fish_kw_no_commands -f

# kw commands
complete -c kw -n "__fish_kw_no_commands" -a "build b" -d "Build Kernel and modules"
complete -c kw -n "__fish_kw_no_commands" -a "install i" -d "Install modules"
complete -c kw -n "__fish_kw_no_commands" -a "bi" -d "Build and install modules"
complete -c kw -n "__fish_kw_no_commands" -a "new n" -d "Install new Kernel image"
complete -c kw -n "__fish_kw_no_commands" -a "ssh s" -d "Enter in the vm"
complete -c kw -n "__fish_kw_no_commands" -a "mount mo" -d "Mount partition with qemu-nbd"
complete -c kw -n "__fish_kw_no_commands" -a "umount um" -d "Umount partition created with qemu-nbd"
complete -c kw -n "__fish_kw_no_commands" -a "vars v" -d "Show variables"
complete -c kw -n "__fish_kw_no_commands" -a "up u" -d "Wake up vm"
complete -c kw -n "__fish_kw_no_commands" -a "codestyle c" -d "Apply checkpatch on directory or file"
complete -c kw -n "__fish_kw_no_commands" -a "maintainers m" -d "Return the maintainers and the mailing list"
complete -c kw -n "__fish_kw_no_commands" -a "explore e" -d "Search for expression on git log or directory"
complete -c kw -n "__fish_kw_no_commands" -a "help h" -d "Display this help mesage"

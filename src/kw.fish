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
complete -c kw -n "__fish_kw_no_commands" -a "prepare p" -d "Deploy basic environment in the VM"
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
complete -c kw -n "__fish_kw_no_commands" -a "man" -d "Display this help mesage"
complete -c kw -n "__fish_kw_no_commands" -a "configm g" -d "Config manager"

# disable file completion for commands that doesn't need them
complete -c kw -n "__fish_seen_subcommand_from build" -f
complete -c kw -n "__fish_seen_subcommand_from b" -f
complete -c kw -n "__fish_seen_subcommand_from install" -f
complete -c kw -n "__fish_seen_subcommand_from i" -f
complete -c kw -n "__fish_seen_subcommand_from bi" -f
complete -c kw -n "__fish_seen_subcommand_from prepare" -f
complete -c kw -n "__fish_seen_subcommand_from p" -f
complete -c kw -n "__fish_seen_subcommand_from new" -f
complete -c kw -n "__fish_seen_subcommand_from n" -f
complete -c kw -n "__fish_seen_subcommand_from mount" -f
complete -c kw -n "__fish_seen_subcommand_from mo" -f
complete -c kw -n "__fish_seen_subcommand_from umount" -f
complete -c kw -n "__fish_seen_subcommand_from um" -f
complete -c kw -n "__fish_seen_subcommand_from vars" -f
complete -c kw -n "__fish_seen_subcommand_from v" -f
complete -c kw -n "__fish_seen_subcommand_from up" -f
complete -c kw -n "__fish_seen_subcommand_from u" -f
complete -c kw -n "__fish_seen_subcommand_from help" -f
complete -c kw -n "__fish_seen_subcommand_from h" -f
complete -c kw -n "__fish_seen_subcommand_from man" -f
complete -c kw -n "__fish_seen_subcommand_from g" -f
complete -c kw -n "__fish_seen_subcommand_from configm" -f

# kw maintainers flags
complete -c kw -n "__fish_seen_subcommand_from maintainers" -s a -l authors -d "Print file authors"
complete -c kw -n "__fish_seen_subcommand_from m" -s a -l authors -d "Print file authors"

# kw configm flags
complete -c kw -n "__fish_seen_subcommand_from configm" -l save -d "Save config file"
complete -c kw -n "__fish_seen_subcommand_from configm" -l ls -d "List config files under kw management"
complete -c kw -n "__fish_seen_subcommand_from g" -l save -d "Save config file"
complete -c kw -n "__fish_seen_subcommand_from g" -l ls -d "List config files under kw management"

# kw ssh flags
complete -c kw -n "__fish_seen_subcommand_from ssh" -l script -d "List config files under kw management"
complete -c kw -n "__fish_seen_subcommand_from ssh" -l 'command' -d "List config files under kw management"
complete -c kw -n "__fish_seen_subcommand_from s" -l script -d "List config files under kw management"
complete -c kw -n "__fish_seen_subcommand_from s" -l 'command' -d "List config files under kw management"

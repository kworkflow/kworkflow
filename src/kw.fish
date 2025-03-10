#!/usr/bin/env fish

# Test if the kw command has subcommands
function __fish_kw_no_commands
    set cmd (commandline -opc)
    if [ "$cmd" = "kw" ]
        return 0
    end

    return 1
end

complete -c kw -f

complete -c kw -n "__fish_kw_no_commands" -a "init" -d "Initialize worktree"
complete -c kw -n "__fish_seen_subcommand_from init" -l arch -l remote -l target -l force -l template -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "build b" -d "Build Kernel and modules"
complete -c kw -n "__fish_seen_subcommand_from build b" -l help -l info -l menu -l cpu-scaling -l ccache -l llvm -l clean -l full-cleanup -l verbose -l doc -l warnings -l save-log-to -l cflags -l from-sha

complete -c kw -n "__fish_kw_no_commands" -a "deploy d" -d "Deploy kernel and modules"
complete -c kw -n "__fish_seen_subcommand_from deploy d" -l remote -l local -l reboot -l no-reboot -l modules -l list -l list-all -l ls-line -l setup -l uninstall -l verbose -l force -l create-package -l from-package

complete -c kw -n "__fish_kw_no_commands" -a "bd" -d "Build and deploy"
complete -c kw -n "__fish_seen_subcommand_from bd" -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "diff df" -d "Noninteractive diff"
complete -c kw -n "__fish_seen_subcommand_from diff df" -l no-interactive -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "ssh s" -d "Enter in the remote"
complete -c kw -n "__fish_seen_subcommand_from ssh s" -l remote -l script -l command -l verbose -l help -l send -l get -l to

complete -c kw -n "__fish_kw_no_commands" -a "self-update u" -d "Self update"
complete -c kw -n "__fish_seen_subcommand_from self-update u" -l unstable -l help -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "maintainers m" -d "Return the maintainers and the mailing list"
complete -c kw -n "__fish_seen_subcommand_from maintainers m" -l authors -l update-patch -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "kernel-config-manager k" -d "Kernel config manager"
complete -c kw -n "__fish_seen_subcommand_from kernel-config-manager k" -l force -l save -l description -l list -l get -l remove -l fetch -l output -l optimize -l remote -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "config g" -d "Adjust kworkflow config"
complete -c kw -n "__fish_seen_subcommand_from config g" -l local -l global -l show -l help -l verbose -F

complete -c kw -n "__fish_kw_no_commands" -a "remote" -d "Modify remote hosts"
complete -c kw -n "__fish_seen_subcommand_from remote" -l add -l remove -l rename -l list -l global -l set-default -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "explore e" -d "Search for expression on git log or directory"
complete -c kw -n "__fish_seen_subcommand_from explore e" -l log -l grep -l all -l only-header -l only-source -l exactly -l show-context -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "pomodoro p" -d "Pomodoro"
complete -c kw -n "__fish_seen_subcommand_from pomodoro p" -l set-timer -l check-timer -l show-tags -l tag -l description -l repeat-previous -l help -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "report r" -d "Report"
complete -c kw -n "__fish_seen_subcommand_from report r" -l day -l week -l month -l year -l output -l statistics -l pomodoro -l all -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "device" -d "Device"
complete -c kw -n "__fish_seen_subcommand_from device" -l local -l remote -l vm -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "backup" -d "Backup"
complete -c kw -n "__fish_seen_subcommand_from backup" -l restore -l force -l verbose -l help

complete -c kw -n "__fish_kw_no_commands" -a "debug" -d "Debug"
complete -c kw -n "__fish_seen_subcommand_from debug" -l remote -l local -l event -l ftrace -l dmesg -l cmd -l verbose -l history -l disable -l reset -l list -l follow -l help

complete -c kw -n "__fish_kw_no_commands" -a "send-patch" -d "send patch"
complete -c kw -n "__fish_seen_subcommand_from send-patch" -l list -l send -l to -l cc -l simulate -l setup -l email -l name -l smtpencryption -l template -l interactive -l local -l global -l private -l verify -l force -l no-interactive -l rfc -l verbose -l smtpuser -l smtpserver -l smtpserverport -l smtppass

complete -c kw -n "__fish_kw_no_commands" -a "env" -d "Environment variables"
complete -c kw -n "__fish_seen_subcommand_from env" -l list -l create -l use -l exit-env -l destroy -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "patch-hub" -d "Patch hub"
complete -c kw -n "__fish_seen_subcommand_from patch-hub"  -l help

complete -c kw -n "__fish_kw_no_commands" -a "drm" -d "Drm helpers"
complete -c kw -n "__fish_seen_subcommand_from drm" -l remote -l local -l gui-on -l gui-off -l gui-on-after-reboot -l gui-off-after-reboot -l load-module -l unload-module -l conn-available -l modes -l verbose -l help

complete -c kw -n "__fish_kw_no_commands" -a "vm" -d "VM helpers"
complete -c kw -n "__fish_seen_subcommand_from vm" -l mount -l umount -l up -l alert -l help

complete -c kw -n "__fish_kw_no_commands" -a "kernel-tag" -d "Write commit and patch trailer lines"
complete -c kw -n "__fish_seen_subcommand_from kernel-tag" -l add-signed-off-by -l add-reviewed-by -l add-acked-by -l add-fixes -l add-tested-by -l add-co-developed-by -l add-reported-by -l verbose -l help

complete -c kw -n "__fish_kw_no_commands" -a "clear-cache" -d "Clear cache"
complete -c kw -n "__fish_seen_subcommand_from clear-cache" -l verbose

complete -c kw -n "__fish_kw_no_commands" -a "codestyle c" -d "Apply checkpatch on directory or file"
complete -c kw -n "__fish_seen_subcommand_from codestyle c" -l verbose -l help

complete -c kw -n "__fish_kw_no_commands" -a "version v" -d "Show version information"

complete -c kw -n "__fish_kw_no_commands" -a "man" -d "Show manual page"

complete -c kw -n "__fish_kw_no_commands" -a "help h" -d "Display this help mesage"

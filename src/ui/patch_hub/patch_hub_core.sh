# The `patch_hub_core.sh` file centralizes the states representing the
# sequences of screen of the `patch-hub` feature. The feature is implemented
# as a state-machine that roughly follows the Model-View-Controller pattern. The roles
# being:
# - Model: `src/lib/lore.sh`
# - View: `src/lib/dialog.sh`
# - Controller: `src/ui/patch_hub`
#
# To keep the code clean and modular, it is best to break down major screen-sequences
# (like 'Settings') in small files that should reside in the Controller directory.

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/dialog_ui.sh"
include "${KW_LIB_DIR}/lib/lore.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/ui/patch_hub/lore_mailing_lists.sh"
include "${KW_LIB_DIR}/ui/patch_hub/settings.sh"
include "${KW_LIB_DIR}/ui/patch_hub/patchset_details_and_actions.sh"
include "${KW_LIB_DIR}/ui/patch_hub/latest_patchsets_from_mailing_list.sh"
include "${KW_LIB_DIR}/ui/patch_hub/search_string_in_lore.sh"

# These are references to data structures used all around the state-machine.
declare -ga bookmarked_series
declare -g current_mailing_list
declare -g additional_filters

# This associative array is used to determine the states and  topass arguments
# between states.
declare -gA screen_sequence=(
	['SHOW_SCREEN']=''
	['SHOW_SCREEN_PARAMETER']=''
	['PREVIOUS_SCREEN']=''
)

# This function is the main loop of the state-machine that represents the feature.
# It delegates the processing of states and state transitions to other functions.
function patch_hub_main_loop() {
	local ret

	# Load UI variables that define screen size, layout and others.
	ui_setup "${lore_config['dialog_layout']}"

	# "Dashboard" is the default state
	screen_sequence['SHOW_SCREEN']='dashboard'

	# In case the user doesn't have any mailing list registered, the first
	# state should be "Register/Unregister Mailing Lists"
	[[ -z "${lore_config['lists']}" ]] && screen_sequence['SHOW_SCREEN']='lore_mailing_lists'

	# Main loop of the state-machine
	while true; do
		case "${screen_sequence['SHOW_SCREEN']}" in
		'dashboard')
			show_dashboard
			ret="$?"
			;;
		'lore_mailing_lists')
			show_lore_mailing_lists
			ret="$?"
			;;
		'registered_mailing_lists')
			show_registered_mailing_lists
			ret="$?"
			;;
		'latest_patchsets_from_mailing_list')
			show_latest_patchsets_from_mailing_list
			ret="$?"
			;;
		'bookmarked_patches')
			show_bookmarked_patches
			ret="$?"
			;;
		'search_string_in_lore')
			show_search_string_in_lore
			ret="$?"
			;;
		'settings')
			show_settings_screen
			ret="$?"
			;;
		'patchset_details_and_actions')
			show_patchset_details_and_actions "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
			ret="$?"
			;;
		esac

		handle_exit "$ret"
	done
}

# Show Dashboard of patch-hub feature. This is the default starting state and main
# menu of the feature.
function show_dashboard() {
	local message_box
	local -a menu_list_string_array
	local message_box
	local ret

	menu_list_string_array=(
		'Registered mailing list'
		'Bookmarked patches'
		'Search in Lore'
		'Settings'
	)

	message_box=''

	create_menu_options 'Dashboard' "$message_box" 'menu_list_string_array'
	ret="$?"

	# Exit
	if [[ "$ret" != 0 ]]; then
		handle_exit "$ret"
	fi

	case "$menu_return_string" in
	0) # Registered mailing list
		screen_sequence['SHOW_SCREEN']='registered_mailing_lists'
		;;
	1) # Bookmarked patches
		screen_sequence['SHOW_SCREEN']='bookmarked_patches'
		;;
	2) # Search in Lore
		screen_sequence['SHOW_SCREEN']='search_string_in_lore'
		;;
	3) # Settings
		screen_sequence['SHOW_SCREEN']='settings'
		;;
	esac
}

# The bookmarked screen it is just a list of patches previously saved by the
# developer. For this reason, we just need to display the save patches.
function show_bookmarked_patches() {
	local fallback_message

	get_bookmarked_series bookmarked_series

	fallback_message='kw could not find any bookmarked patches.'$'\n'$'\n'
	fallback_message+='Try bookmarking patches in the menu "Registered mailing list"'
	list_patches 'Bookmarked patches' bookmarked_series "${fallback_message}"
}

# Show mailing lists available in lore.kernel.org that the user has registered.
# A registered mailing list is one that was selected in the 'Register/Unregister
# Mailing Lists'.
function show_registered_mailing_lists() {
	local -a registered_mailing_lists
	local message_box
	local ret
	local fallback_message

	# Load registered mailing lists from config file into array
	IFS=',' read -r -a registered_mailing_lists <<<"${lore_config['lists']}"

	if [[ "${#registered_mailing_lists[@]}" -eq 0 ]]; then
		fallback_message='kw could not find any registered mailing list.'$'\n'$'\n'
		fallback_message+='Try to register mailing lists in the menu "Settings" -> '
		fallback_message+='"Register/Unregister Mailing Lists"'

		create_message_box 'Error' "${fallback_message}"
		screen_sequence['SHOW_SCREEN']='dashboard'
		return
	fi

	message_box='Below, you can see the lore.kernel.org mailing lists that you have registered.'$'\n'
	message_box+='Select a mailing list to see the latest patchsets sent to it.'

	create_menu_options 'Registered Mailing Lists' "$message_box" 'registered_mailing_lists' '' '' 'Return'
	ret="$?"

	case "$ret" in
	0) # OK
		screen_sequence['SHOW_SCREEN']='latest_patchsets_from_mailing_list'
		screen_sequence['SHOW_SCREEN_PARAMETER']=''
		current_mailing_list="${registered_mailing_lists["$menu_return_string"]}"
		;;
	1) # Exit
		handle_exit "$ret"
		;;
	3) # Return
		screen_sequence['SHOW_SCREEN']='dashboard'
		;;
	esac
}

# This is a generic function used to show a list of patches. If the user select
# one specific patch, this function will set the next screen to be
# show_patch_details with the patch index saved in the SHOW_SCREEN_PARAMETER
# option.
#
# @message_box: Text description to the list of patches
# @_target_array_list: List of patches to be displayed
# @fallback_message: Message for when there are no patches to display
function list_patches() {
	local menu_title="$1"
	local -n _target_array_list="$2"
	local fallback_message="$3"
	local ret

	if [[ -z "${_target_array_list}" ]]; then
		create_message_box 'Error' "${fallback_message}"
		screen_sequence['SHOW_SCREEN']='dashboard'
		return "$?"
	fi

	create_menu_options "${menu_title}" '' '_target_array_list' '' '' 'Return'
	ret="$?"

	case "$ret" in
	0) # OK
		case "${screen_sequence['SHOW_SCREEN']}" in
		'latest_patchsets_from_mailing_list')
			screen_sequence['PREVIOUS_SCREEN']='latest_patchsets_from_mailing_list'
			screen_sequence['SHOW_SCREEN_PARAMETER']=${representative_patches["$menu_return_string"]}
			;;
		'bookmarked_patches')
			screen_sequence['PREVIOUS_SCREEN']='bookmarked_patches'
			menu_return_string=$((menu_return_string + 1))
			screen_sequence['SHOW_SCREEN_PARAMETER']=$(get_bookmarked_series_by_index "$menu_return_string")
			;;
		esac
		screen_sequence['SHOW_SCREEN']='patchset_details_and_actions'
		;;
	1) # Exit
		handle_exit "$ret"
		;;
	3) # Return
		screen_sequence['SHOW_SCREEN']='dashboard'
		;;
	esac
}

load_lore_config

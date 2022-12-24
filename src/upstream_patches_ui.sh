# The upstream_patches_ui.sh file is responsible for centralizing all the UI
# and logic parts for the interface between developers and the public mailing
# list. We try not to add UI-specific technology here since we want to be able
# to plug in a new interface in the future. Also, this file connects the lore
# API with the UI.

include "${KW_LIB_DIR}/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/dialog_ui.sh"
include "${KW_LIB_DIR}/lib/lore.sh"
include "${KW_LIB_DIR}/kwio.sh"

declare -ga registered_lists

# TODO: Bookmarked patches must come from local database
declare -ga bookmarked_patches=(
  '2022-11-10 | #1   | drm/amd/pm: Enable bad memory page/channel recording support for smu v13_0_0'
  '2021-05-10 | #255 | DC Patches November 19, 2022'
  '2000-01-29 | #12  | drm/amdgpu: add drv_vram_usage_va for virt data exchange'
  '2022-07-01 | #7   | drm/amdgpu: fix pci device refcount leak'
)

# To make it easier to change between different screens, we implement a
# mechanism that uses this associative array to indicate the current screen to
# be shown.
declare -gr SEPARATOR_CHAR='Æ'

# This is a global array that we use to store the list of new patches from a
# target mailing list. After we parse the data from lore, we will have a list
# that follows this pattern:
#
#  Author, email, version, total patches, patch title, link
#
# Note: To separate those elements, we use the variable SEPARATOR_CHAR, which
# can be a ',' but by default, we use 'Æ'. We used ',' in the example for make
# it easy to undertand.
# TODO: Array populated with dummy data
declare -ga patch_list_with_metadata=(
  'Joe DoeÆjoedoe@lala.comÆV1Æ1Ædrm/amd/pm: Enable bad memory page/channel recording support for smu v13_0_0Æhttp://something.la'
  'Juca PiramaÆjucapirama@xpto.comÆV1Æ255ÆDC Patches November 19, 2022Æhttp://anotherthing.la'
  'Machado de AssisÆmachado@literatura.comÆV2Æ1Ædrm/amdgpu: add drv_vram_usage_va for virt data exchangeÆhttp://machado.good.books.la'
  'Racionais McÆvidaloka@abc.comÆV2Æ1Ædrm/amdgpu: fix pci device refcount leakÆhttp://racionais.mc.vida.loka'
)

declare -gA screen_sequence=(
  ['SHOW_SCREEN']='register'
  ['SHOW_SCREEN_PARAMETER']=''
)

# This function is responsible for managing the UI interface loop; here, it is
# possible to use the screen sequence used by this feature.
upstream_patches_ui_main()
{
  local all_registered_list="${lore_config['lists']}"
  local ret

  ui_setup "${lore_config['dialog_layout']}"

  IFS=',' read -r -a registered_lists <<< "$all_registered_list"
  if [[ "${#registered_lists[@]}" != 0 ]]; then
    screen_sequence['SHOW_SCREEN']='dashboard'
  fi

  # Main loop
  while true; do
    case "${screen_sequence['SHOW_SCREEN']}" in
      'register')
        # First time here? Let's register some public mailing list
        register_mailing_list 'SILENT'
        ret="$?"
        ;;
      'dashboard')
        # Main menu
        dashboard_entry_menu
        ret="$?"
        ;;
      'registered_mailing_list')
        registered_mailing_list
        ret="$?"
        ;;
      'bookmarked_patches')
        show_bookmarked_patches
        ret="$?"
        ;;
      'show_series_details')
        show_series_details "${screen_sequence['SHOW_SCREEN_PARAMETER']}" patch_list_with_metadata
        ret="$?"
        ;;
    esac

    handle_exit "$ret"
  done
}

# Build the bookmark screen. Developers may want to save some patch for
# verification later, and the bookmark page address this requirement by
# providing a list of patches saved by the developers.
function dashboard_entry_menu()
{
  local message_box
  local -a menu_list_string_array
  local ret

  # TODO: Get list from liblore
  menu_list_string_array=('Registered mailing list' 'Bookmarked patches')

  message_box="It looks like that you don't have any lore list registered; please"
  message_box+=' select one or more of the below list:'

  create_menu_options 'Dashboard' "$message_box" 'menu_list_string_array'
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'Something went wrong when kw tried to display the Dashboad screen.'
    return "$ret"
  fi

  case "$menu_return_string" in
    1) # Registered mailing list
      screen_sequence['SHOW_SCREEN']='registered_mailing_list'
      ;;
    2) # Bookmarked patches
      screen_sequence['SHOW_SCREEN']='bookmarked_patches'
      ;;
  esac
}

# The bookmarked screen it is just a list of patches previously saved by the
# developer. For this reason, we just need to display the save patches.
function show_bookmarked_patches()
{
  # TODO: Get bookmarked_patches from the local database
  list_patches 'Bookmarked patches' bookmarked_patches
}

# Show all mailing list that the developer is registered
function registered_mailing_list()
{
  local message_box

  # TODO: Get list from liblore
  message_box='Below you can see all the mailing lists that you are registered:'

  create_menu_options 'Mailing lists' "$message_box" 'registered_lists'
}

# Screen resposible for show a specific patch details
#
# @patch_index: Patch index
# @_target_patch_metadata: List with patches metadata
function show_series_details()
{
  local patch_index="$1"
  local -n _target_patch_metadata="$2"
  local -a action_list
  local patch_metadata
  local target_patch
  local message_box

  action_list=('Bookmark patch' 'Download patch' 'Apply patch')

  target_patch=${_target_patch_metadata["$patch_index"]}
  IFS="${SEPARATOR_CHAR}" read -r -a columns <<< "$target_patch"

  patch_metadata=$(prettify_string 'Series:' "${columns[4]}")
  patch_metadata+=$(prettify_string 'Author:' "${columns[0]}")
  patch_metadata+=$(prettify_string 'Version:' "${columns[2]}")
  patch_metadata+=$(prettify_string 'Patches:' "${columns[3]}")

  message_box="$patch_metadata"

  create_simple_checklist 'Patch(es) info and actions' "$message_box" 'action_list'
}

# This is a generic function used to show a list of patches. If the user select
# one specific patch, this function will set the next screen to be
# show_patch_details with the patch index saved in the SHOW_SCREEN_PARAMETER
# option.
#
# @message_box: Text description to the list of patches
# @_target_array_list: List of patches to be displayed
function list_patches()
{
  local message_box="$1"
  local -n _target_array_list="$2"
  local selected_patch

  # TODO: Get list from local store
  # Format patche like this:
  # printf 'V%-2s |#%-3s| %-100s' "$patch_version" "$total_patches" "$patch_title"

  message_box='List of bookmarked patches'

  create_menu_options 'Bookmarked patches' "$message_box" '_target_array_list'

  selected_patch="$menu_return_string"

  if [[ -n "$selected_patch" ]]; then
    screen_sequence['SHOW_SCREEN']='show_series_details'
    screen_sequence['SHOW_SCREEN_PARAMETER']="$selected_patch"
  fi
}

# Screen used to register to a new mailing list
function register_mailing_list()
{
  local flag="$1"
  local message_box
  local new_list
  local -a menu_list_string_array
  local lore_config_path="${PWD}/.kw/lore.config"

  if [[ ! -f "${lore_config_path}" ]]; then
    lore_config_path="${KW_ETC_DIR}/lore.config"
  fi

  retrieve_available_mailing_lists "$flag"

  for mailing_list in "${!available_lore_mailing_lists[@]}"; do
    menu_list_string_array+=("$mailing_list")
  done

  message_box="It looks like that you don't have any lore list registered; please"
  message_box+=" select one or more of the below list:"

  create_simple_checklist 'Lore list' "$message_box" 'menu_list_string_array'

  new_list=$(printf '%s' "$menu_return_string" | tr -s '[:blank:]' ',')

  if [[ -n "$new_list" ]]; then
    screen_sequence['SHOW_SCREEN']='dashboard'
    lore_config['lists']="${new_list}"
    IFS=',' read -r -a registered_lists <<< "$new_list"
    sed -i -r "s<(lists=).*<\1${new_list}<" "$lore_config_path"
  fi
}

load_lore_config

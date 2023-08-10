include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

function show_new_patches_in_the_mailing_list()
{
  local -a new_patches
  local fallback_message

  # If returning from a 'patchset_details_and_actions' screen, i.e., we already fetched the
  # information needed to render this screen.
  if [[ -n "${screen_sequence['RETURNING']}" ]]; then
    # Avoiding stale value
    screen_sequence['RETURNING']=''
  else
    current_mailing_list="$1"
    create_loading_screen_notification "Loading patches from ${current_mailing_list} list"
    # Query patches from mailing list, this info will be saved at "${list_of_mailinglist_patches[@]}".
    get_patches_from_mailing_list "$current_mailing_list" patches_from_mailing_list
  fi

  fallback_message='kw could not retrieve patches from this mailing list'
  list_patches "Patches from ${current_mailing_list}" patches_from_mailing_list "${fallback_message}"
}

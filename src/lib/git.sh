#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Git helper functions for kworkflow

# This function checks if the repository is in a safe state to perform operations
# like rebase, merge, etc.
# Return:
# 0 if safe, 125 (ECANCELED) otherwise.
kw_git_is_repo_safe()
{
  if [[ -d .git/rebase-merge ]]; then
    warning 'ERROR: Abort the repository rebase before continuing with build from sha (use "git rebase --abort")!'
    return 125 # ECANCELED
  elif [[ -f .git/MERGE_HEAD ]]; then
    warning 'ERROR: Abort the repository merge before continuing with build from sha (use "git rebase --abort")!'
    return 125 # ECANCELED
  elif [[ -f .git/BISECT_LOG ]]; then
    warning 'ERROR: Stop the repository bisect before continuing with build from sha (use "git bisect reset")!'
    return 125 # ECANCELED
  elif [[ -d .git/rebase-apply ]]; then
    printf 'ERROR: Abort the repository patch apply before continuing with build from sha (use "git am --abort")!'
    return 125 # ECANCELED
  fi
}

# Check if given SHA represents real commit
# @from_sha_arg: The SHA to be checked
# Return:
# 0 if valid, 22 (EINVAL) otherwise.
kw_git_is_valid_commit()
{
  local from_sha_arg="$1"
  cmd_manager 'SILENT' "git cat-file -e ${from_sha_arg}^{commit} 2> /dev/null"
  if [[ "$?" != 0 ]]; then
    complain "ERROR: The given SHA (${from_sha_arg}) does not represent a valid commit sha."
    return 22 # EINVAL
  fi
}

# Check if given SHA is in working tree and ancestor of HEAD.
# @from_sha_arg: The SHA to be checked
# @head: The head reference (usually HEAD)
# Return:
# 0 if valid, 22 (EINVAL) otherwise.
kw_git_is_ancestor()
{
  local from_sha_arg="$1"
  local head="$2"
  local sha_base
  local merge_base

  sha_base=$(git rev-parse --verify "$from_sha_arg")
  merge_base=$(git merge-base "$from_sha_arg" "$head")
  if [[ "$sha_base" != "$merge_base" ]]; then
    complain "ERROR: Given SHA (${from_sha_arg}) is invalid. Check if it is an ancestor of the branch head."
    return 22 # EINVAL
  fi
}

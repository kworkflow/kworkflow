#!bin/bash

#Git helper functions for  kworkflow

#Get the current HEAD commit hash  (short)
function kw_git_get_head_hash() {
     local repo_path="$1"
      git -C "${repo_path}" rev-parse --short HEAD
}

#Get the current branch name
function kw_git_get_branch_name() {
     local repo_path="$1"
     git -C "${repo_path}" rev-parse --abbrev-ref HEAD
}

# get verbose list of branches
function kw_git_verbose_branches() {
      local repo="$1"
      git -C "$repo" branch --verbose
}
function kw_git_get_remote_commit_hash(){
      local repo="$1"
      local branch="$2"
      git -C "repo" rev-parse --short origin/"$branch"
}


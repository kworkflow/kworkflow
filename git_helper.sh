#!/bin/bash

function kw_git_get_head_hash() {
   local repo_path="$1"
   git -C "${repo_path}" rev-parse --short HEAD
}

function kw_git_get_branch_name() {
   local repo_path="$1"
   git -C "${repo_path}" rev-parse --abbrev-ref HEAD
}

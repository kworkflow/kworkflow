#!/bin/bash

# This file handles the migration of user data, from the old folders and files
# storage, to the new database model

KW_LIB_DIR='src'
KW_DB_DIR='database'
. 'src/kw_include.sh' --source-only
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kw_string.sh"
include "$KW_LIB_DIR/kw_db.sh"

declare -r app_name='kw'
declare -r datadir="${XDG_DATA_HOME:-"$HOME/.local/share"}/$app_name"

declare -gr KW_DATA_DIR=${KW_DATA_DIR:-"$datadir"}

function migrate_statistics()
{
  local -a file_list
  local start_date
  local label_name
  local status
  local elapsed_time_in_secs
  local rows
  local columns='("date","label_name","status","elapsed_time_in_secs")'
  local count=0
  local -a values=()

  file_list=$(find "${datadir}/statistics" -type f | sort)

  for file in $file_list; do
    # This line converts the file path into a usable date value
    # E.g.: ${datadir}/statistics/2021/10/05 -> 2021-10-05
    start_date=$(printf '%s\n' "$file" | sed -e 's/.*statistics\///' -e 's/\//-/g')
    while IFS=' ' read -r label_name elapsed_time_in_secs; do
      status='success'
      # The new database stores execution status, making this label unnecessary
      if [[ "$label_name" == 'build_failure' ]]; then
        status='failure'
        label_name='build'
      fi
      label_name="$(str_lowercase "$label_name")"
      values+=("$start_date" "$label_name" "$status" "$elapsed_time_in_secs")
      ((count++))
      # insert statements have a limit on the amount of values being inserted
      # at once, this ensures that limit is never reached
      if [[ "$count" -ge 100 ]]; then
        rows="$(format_values_db 4 "${values[@]}")"
        insert_into '"statistics_report"' "$columns" "$rows"

        values=()
        count=0
      fi
    done < "$file"
  done

  # insert_values '"statistics_report"' "$columns" 4 "${values[@]}"

  # if there are no values left, return, otherwise insert them
  [[ "${#values}" == 0 ]] && return

  rows="$(format_values_db 4 "${values[@]}")"
  insert_into '"statistics_report"' "$columns" "$rows"
}

function migrate_pomodoro()
{
  local -a file_list
  local line
  local tag
  local start_date
  local start_time
  local duration
  local description
  local rows
  local columns='("tag","date","time","duration","description")'
  local count=0
  local -a values=()

  file_list=$(find "${datadir}/pomodoro" -type f | sort)

  for file in $file_list; do
    # avoid processing tags file
    [[ "$file" =~ tags$ ]] && continue
    # This line converts the file path into a usable date value
    # E.g.: ${datadir}/pomodoro/2021/10/05 -> 2021-10-05
    start_date=$(printf '%s\n' "$file" | sed -e 's/.*pomodoro\///' -e 's/\//-/g')
    while read -r line; do
      tag=$(printf '%s\n' "$line" | cut -d ',' -f1)
      duration=$(printf '%s\n' "$line" | cut -d ',' -f2)
      start_time=$(printf '%s\n' "$line" | cut -d ',' -f3)
      description=$(printf '%s\n' "$line" | cut -d ',' -f1,2,3 --complement)

      [[ -z "$description" ]] && description='NULL'
      duration=$(timebox_to_sec "$duration")

      values+=("$tag" "$start_date" "$start_time" "$duration" "$description")
      ((count++))
      # insert statements have a limit on the amount of values being inserted
      # at once, this ensures that limit is never reached
      if [[ "$count" -ge 100 ]]; then
        rows="$(format_values_db 5 "${values[@]}")"
        insert_into '"pomodoro_report"' "$columns" "$rows"

        values=()
        count=0
      fi
    done < "$file"
  done

  # insert_values '"pomodoro_report"' "$columns" 5 "${values[@]}"

  # if there are no values left, return, otherwise insert them
  [[ "${#values}" == 0 ]] && return

  rows="$(format_values_db 5 "${values[@]}")"

  insert_into '"pomodoro_report"' "$columns" "$rows"
}

function migrate_configs()
{
  local -a file_list
  local line
  local name
  local path
  local description
  local rows
  local columns='("name","description","path")'
  local count=0
  local -a values=()

  local configs_dir="${datadir}/configs/configs"
  local metadata_dir="${datadir}/configs/metadata"

  file_list=$(find "$configs_dir" -type f | sort)

  for file in $file_list; do
    path="$file"
    name="${path##*/}" # get just the file name
    description=$(cat "${metadata_dir}/${name}")

    [[ -z "$description" ]] && description='NULL'

    values+=("$name" "$description" "$path")
    ((count++))
    # insert statements have a limit on the amount of values being inserted
    # at once, this ensures that limit is never reached
    if [[ "$count" -ge 100 ]]; then
      rows="$(format_values_db 3 "${values[@]}")"
      insert_into '"config"' "$columns" "$rows"

      values=()
      count=0
    fi
  done

  # insert_values '"config"' "$columns" 3 "${values[@]}"

  # if there are no values left, return, otherwise insert them
  [[ "${#values}" == 0 ]] && return

  rows="$(format_values_db 3 "${values[@]}")"

  insert_into '"config"' "$columns" "$rows"
}

function timebox_to_sec()
{
  local timebox="$1"
  local time_type
  local time_value

  time_type=$(last_char "$timebox")
  time_value=$(chop "$timebox")

  case "$time_type" in
    h)
      time_value=$((3600 * time_value))
      ;;
    m)
      time_value=$((60 * time_value))
      ;;
    s)
      : # Do nothing
      ;;
  esac

  printf '%s\n' "$time_value"
}

function insert_values()
{
  local table="$1"
  local columns="$2"
  local length="$3"
  shift 3
  local rows
  local n

  n="$((100 * length))"

  # inserts values in increments of 100 values at a time to avoid problems when
  # users have lots of entries
  while [[ "$#" -gt 0 ]]; do
    rows="$(format_values_db "$length" "${@:1:$n}")"
    insert_into "$table" "$columns" "$rows"

    shift "$n"
  done
}

function db_migration()
{
  execute_sql_script "$KW_DB_DIR/kwdb.sql"

  migrate_statistics
  migrate_pomodoro
  migrate_configs

  execute_command_db 'PRAGMA optimize;'
}

db_migration

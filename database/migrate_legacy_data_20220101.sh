#!/bin/bash

# This file handles the migration of legacy user data, from the old directories and files
# storage, to the new database model

declare -r KW_LIB_DIR='src'

. "${KW_LIB_DIR}/kw_include.sh" --source-only
include "${KW_LIB_DIR}/kwio.sh"
include "${KW_LIB_DIR}/kwlib.sh"
include "${KW_LIB_DIR}/kw_string.sh"
include "${KW_LIB_DIR}/kw_db.sh"

declare -r KW_DB_DIR='database'
declare -r app_name='kw'
declare -r datadir="${XDG_DATA_HOME:-"${HOME}/.local/share"}/${app_name}"
declare -gr KW_DATA_DIR=${KW_DATA_DIR:-"$datadir"}

function db_migration_main()
{
  execute_sql_script "${KW_DB_DIR}/kwdb.sql"
  if [[ "$?" != 0 ]]; then
    complain 'Creation of database schema has failed. Aborting migration.'
    return 1 # EPERM
  fi

  say 'Checking for legacy data...'

  migrate_statistics || {
    complain 'Migration of statistics reports has failed. Aborting migration.'
    return 1 # EPERM
  }

  migrate_pomodoro || {
    complain 'Migration of pomodoro reports has failed. Aborting migration.'
    return 1 # EPERM
  }

  migrate_kernel_configs || {
    complain 'Migration of kernel configs has failed. Aborting migration.'
    return 1 # EPERM
  }

  execute_command_db 'PRAGMA optimize;'
}

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

  # if there are no statistics reports to migrate, return
  [[ ! -d "${datadir}/statistics" ]] && return 0

  warning 'Legacy statistics data found. Migrating...'

  file_list=$(find "${datadir}/statistics" -type f | sort --dictionary-order)
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
      elif [[ "$label_name" == 'deploy_failure' ]]; then
        status='failure'
        label_name='deploy'
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

  # if there are values left, insert them
  if [[ "${#values}" != 0 ]]; then
    rows="$(format_values_db 4 "${values[@]}")"
    insert_into '"statistics_report"' "$columns" "$rows"
  fi

  # mark migrated directory to avoid duplicated data
  cmd_manager 'SILENT' "mv ${datadir}/statistics ${datadir}/legacy_statistics"
  if [[ "$?" != 0 ]]; then
    complain "Couldn't rename ${datadir}/statistics ${datadir}/legacy_statistics"
    return 1 #EPERM
  fi

  warning "'${datadir}/statistics' renamed to '${datadir}/legacy_statistics'"
  success 'Statistics data migration completed!'
}

function migrate_pomodoro()
{
  local -a file_list
  local line
  local tag_name
  local start_date
  local start_time
  local duration
  local description
  local rows
  local columns='("tag_name","date","time","duration","description")'
  local count=0
  local -a values=()

  # if there are no pomodoro reports to migrate, return
  [[ ! -d "${datadir}/pomodoro" ]] && return 0

  warning 'Legacy Pomodoro data found. Migrating...'

  file_list=$(find "${datadir}/pomodoro" -type f | sort --dictionary-order)
  for file in $file_list; do
    # avoid processing tags file
    [[ "$file" =~ tags$ ]] && continue
    # This line converts the file path into a usable date value
    # E.g.: ${datadir}/pomodoro/2021/10/05 -> 2021-10-05
    start_date=$(printf '%s\n' "$file" | sed -e 's/.*pomodoro\///' -e 's/\//-/g')
    while read -r line; do
      tag_name=$(printf '%s\n' "$line" | cut -d ',' -f1)
      duration=$(printf '%s\n' "$line" | cut -d ',' -f2)
      start_time=$(printf '%s\n' "$line" | cut -d ',' -f3)
      description=$(printf '%s\n' "$line" | cut -d ',' -f1,2,3 --complement)

      [[ -z "$description" ]] && description='NULL'
      duration=$(timebox_to_sec "$duration")

      values+=("$tag_name" "$start_date" "$start_time" "$duration" "$description")
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

  # if there are values left, insert them
  if [[ "${#values}" != 0 ]]; then
    rows="$(format_values_db 5 "${values[@]}")"
    insert_into '"pomodoro_report"' "$columns" "$rows"
  fi

  # mark migrated directory to avoid duplicated data
  cmd_manager 'SILENT' "mv ${datadir}/pomodoro ${datadir}/legacy_pomodoro"
  if [[ "$?" != 0 ]]; then
    complain "Couldn't rename ${datadir}/pomodoro ${datadir}/legacy_pomodoro"
    return 1 #EPERM
  fi

  warning "'${datadir}/pomodoro' was renamed to '${datadir}/legacy_pomodoro'"
  success 'Pomodoro data migration completed!'
}

function migrate_kernel_configs()
{
  local -a file_list
  local line
  local name
  local path
  local description
  local rows
  local columns='("name","description","path","last_updated_datetime")'
  local count=0
  local -a values=()
  local configs_dir="${datadir}/configs/configs"
  local metadata_dir="${datadir}/configs/metadata"

  # if there are no kernel config files to migrate, return
  [[ ! -d "$configs_dir" || ! -d "$metadata_dir" ]] && return 0

  warning 'Legacy kernel configs data found. Migrating...'

  file_list=$(find "$configs_dir" -type f | sort --dictionary-order)
  for file in $file_list; do
    # the kernel config files will reside in 'KW_DATA_DIR/configs', so update path
    path=$(printf '%s' "$file" | sed 's/configs\///')
    name="${path##*/}" # get just the file name
    description=$(< "${metadata_dir}/${name}")
    last_updated_datetime=$(date '+%Y-%m-%d %H:%M:%S')

    [[ -z "$description" ]] && description='NULL'

    values+=("$name" "$description" "$path" "$last_updated_datetime")
    ((count++))
    # insert statements have a limit on the amount of values being inserted
    # at once, this ensures that limit is never reached
    if [[ "$count" -ge 100 ]]; then
      rows="$(format_values_db 4 "${values[@]}")"
      insert_into '"kernel_config"' "$columns" "$rows"

      values=()
      count=0
    fi
  done

  # if there are values left, insert them
  if [[ "${#values}" != 0 ]]; then
    rows="$(format_values_db 4 "${values[@]}")"
    insert_into '"kernel_config"' "$columns" "$rows"
  fi

  # copy the kernel config files to the parent directory ('KW_DATA_DIR/configs')
  cmd_manager 'SILENT' "cp -r ${configs_dir}/. ${datadir}/configs"
  if [[ "$?" != 0 ]]; then
    complain "Couldn't copy kernel config files from ${configs_dir} to ${datadir}/configs"
    return 1 #EPERM
  fi

  # mark migrated directories to avoid duplicated data
  cmd_manager 'SILENT' "mv ${datadir}/configs/configs ${datadir}/configs/legacy_configs"
  if [[ "$?" != 0 ]]; then
    complain "Couldn't rename ${datadir}/configs/configs to ${datadir}/configs/legacy_configs"
    return 1 #EPERM
  fi

  cmd_manager 'SILENT' "mv ${datadir}/configs/metadata ${datadir}/configs/legacy_metadata"
  if [[ "$?" != 0 ]]; then
    complain "Couldn't rename ${datadir}/configs/metadata to ${datadir}/configs/legacy_metadata"
    return 1 #EPERM
  fi

  warning "'${configs_dir}' was renamed to '${datadir}/configs/legacy_configs'"
  warning "'${metadata_dir}' was renamed to '${datadir}/configs/legacy_metadata'"
  success 'Kernel configs data migration completed!'
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

db_migration_main

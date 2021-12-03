# This file handles the interactions with the kw database

include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

declare -g DB_NAME='kw.db'

# This function reads and executes a SQL script in the database
#
# @sql_path:  Path to SQL script
# @db:        Name of the database file
# @db_folder: Path to the folder that contains @db
#
# Return:
# 0 if succesful; non-zero otherwise
function execute_sql_script()
{
  local sql_path="$1"
  local db="${2:-"$DB_NAME"}"
  local db_folder="${3:-"$KW_DATA_DIR"}"
  local db_path

  db_path="$(join_path "$db_folder" "$db")"

  if [[ ! -f "$sql_path" ]]; then
    complain "Could not find the file: $sql_path"
    return 2
  fi

  [[ -f "$db_path" ]] || warning "Creating database: $db_path"

  sqlite3 "$db_path" < "$sql_path"
}

# This function reads and executes a SQL script in the database
#
# @sql_cmd:   SQL command to be executed on @db
# @db:        Name of the database file
# @db_folder: Path to the folder that contains @db
#
# Return:
# 2 if db doesn't exist;
# 0 if succesful; non-zero otherwise
function execute_command_db()
{
  local sql_cmd="$1"
  local db="${2:-"$DB_NAME"}"
  local db_folder="${3:-"$KW_DATA_DIR"}"
  local db_path

  db_path="$(join_path "$db_folder" "$db")"

  if [[ ! -f "$db_path" ]]; then
    complain 'Database does not exist'
    return 2
  fi

  sqlite3 "$db_path" -bail -batch "$sql_cmd"
}

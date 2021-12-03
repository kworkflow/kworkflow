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

# This function inserts values into table of given database
#
# @table:     Table to insert data into
# @entries:   Columns on the table where to add the data
# @values:    Rows of data to be added
# @db:        Name of the database file
# @db_folder: Path to the folder that contains @db
#
# Return:
# 2 if db doesn't exist;
# 0 if succesful; non-zero otherwise
function insert_into()
{
  local table="$1"
  local entries="$2"
  local values="$3"
  local db="${4:-"$DB_NAME"}"
  local db_folder="${5:-"$KW_DATA_DIR"}"
  local db_path

  db_path="$(join_path "$db_folder" "$db")"

  if [[ ! -f "$db_path" ]]; then
    complain 'Database does not exist'
    return 2
  fi

  if [[ -z "$table" || -z "$values" ]]; then
    complain 'Empty table or values.'
    return 22 # EINVAL
  fi

  [[ -n "$entries" && ! "$entries" =~ ^\(.*\)$ ]] && entries="($entries)"

  sqlite3 "$db_path" -batch "INSERT INTO $table $entries VALUES $values;"
}

# This function takes arguments and assembles them into the correct format to
# be used as values in SQL commands
#
# @length: Number of arguments per group
# @@:      Values to be formatted
#
# Return:
# The arguments in formatted string to be used as values in an INSERT command
# 22 if no arguments are given
function format_values_db()
{
  local length="$1"
  shift
  local values=''
  local val
  local count=0

  if [[ "$#" == 0 ]]; then
    complain 'No arguments given'
    return 22
  fi

  for val in "$@"; do
    [[ "$count" -eq 0 ]] && values+='('
    # check if not a sqlite function
    if [[ ! "$val" =~ ^[[:alnum:]_]+\(.*\)$ ]]; then
      val="'${val//\'/\'\'}'" # escapes single quotes and enclose
    fi
    values+="$val"
    ((count++))
    if [[ "$count" -eq "$length" ]]; then
      values+=')'
      count=0
    fi
    values+=','
  done

  printf '%s\n' "${values%?}" # removes last comma
}

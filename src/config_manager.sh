declare -A paths
declare -A comments

DB_PATH=$DEFAULT_CONFIG_PATH/configdb

function load_configs()
{
  local i=0

  while read line
  do
    if echo $line | grep -F = &>/dev/null
    then
      i=$(($i+1))
      paths[$i]=$(echo $line | cut -d '=' -f 1 | tr -d '[:space:]')
      comments[$i]=$(echo "$line" | cut -d '=' -f 2-)
    fi
  done < $DB_PATH
}

function register_config()
{
  load_configs

  if [ $# -eq 0 ] ; then
    complain "Usage: kw register_config <PATH> <COMMENT>"
    return 1
  fi

  local path=$1
  local comment=$path

  if [ $# -ge 2 ] ; then
    shift
    comment="$@"
  fi
 
  grep -v $path $DB_PATH > /tmp/temp_kw 
  mv /tmp/temp_kw $DB_PATH

  echo "$path=$comment" >> $DB_PATH
}

function show_configs()
{
  load_configs

  for i in ${!paths[*]}
  do
    echo "$i) ${comments[$i]}"
  done
}

function get_config()
{
  load_configs

  if [ $# -ne 1 ] ; then
    complain "Missing config number. Run 'kw show_configs'"
    return 1
  fi

  for i in ${!paths[*]}
  do
    if [ $1 -eq $i ] ; then
     cp ${paths[$i]} . 
    fi
  done
}

#!/usr/bin/env bash
set -Eeuo pipefail

shopt -s nullglob

mysql_home="${MYSQL_HOME:-/usr/local/mysql}"
mysqld="${mysql_home}/bin/mysqld"
mysql="${mysql_home}/bin/mysql"
mysqladmin="${mysql_home}/bin/mysqladmin"
tzinfo_to_sql="${mysql_home}/bin/mysql_tzinfo_to_sql"

log() {
  echo "[Entrypoint] $*"
}

file_env() {
  local var="$1"
  local file_var="${var}_FILE"
  local def="${2:-}"
  local val="${!var:-}"
  local file="${!file_var:-}"

  if [[ -n "$val" && -n "$file" ]]; then
    echo "error: both $var and $file_var are set" >&2
    exit 1
  fi
  if [[ -n "$file" ]]; then
    val="$(<"$file")"
  elif [[ -z "$val" ]]; then
    val="$def"
  fi
  export "$var=$val"
  unset "$file_var"
}

sql_escape_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\'/\'\'}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}

sql_escape_identifier() {
  local value="$1"
  value="${value//\`/\`\`}"
  printf '%s' "$value"
}

mysql_get_config() {
  local key="$1"
  shift
  local temp_index
  temp_index="$(mktemp -u)"
  "$@" --verbose --help --log-bin-index="$temp_index" 2>/dev/null \
    | awk -v key="$key" '$1 == key { print $2; exit }'
}

mysql_check_config() {
  local temp_index
  temp_index="$(mktemp -u)"
  "$@" --verbose --help --log-bin-index="$temp_index" >/dev/null
}

mysql_process_init_files() {
  local file
  for file in /docker-entrypoint-initdb.d/*; do
    case "$file" in
      *.sh)
        if [[ -x "$file" ]]; then
          log "running $file"
          "$file"
        else
          log "sourcing $file"
          # shellcheck disable=SC1090
          . "$file"
        fi
        ;;
      *.sql)
        log "running $file"
        "$mysql" --defaults-extra-file="$MYSQL_DEFAULTS_FILE" < "$file"
        ;;
      *.sql.bz2)
        log "running $file"
        bzip2 -dc "$file" | "$mysql" --defaults-extra-file="$MYSQL_DEFAULTS_FILE"
        ;;
      *.sql.gz)
        log "running $file"
        gzip -dc "$file" | "$mysql" --defaults-extra-file="$MYSQL_DEFAULTS_FILE"
        ;;
      *.sql.xz)
        log "running $file"
        xz -dc "$file" | "$mysql" --defaults-extra-file="$MYSQL_DEFAULTS_FILE"
        ;;
      *.sql.zst)
        log "running $file"
        zstd -dc "$file" | "$mysql" --defaults-extra-file="$MYSQL_DEFAULTS_FILE"
        ;;
      *)
        log "ignoring $file"
        ;;
    esac
  done
}

if [[ "${1:-}" == -* ]]; then
  set -- mysqld "$@"
fi

if [[ "${1:-}" != "mysqld" ]]; then
  exec "$@"
fi

if [[ "${2:-}" == "--help" || "${2:-}" == "--verbose" || "${2:-}" == "--version" ]]; then
  exec "$mysqld" "${@:2}"
fi

server_args=("${@:2}")

file_env MYSQL_ROOT_PASSWORD
file_env MYSQL_ROOT_HOST '%'
file_env MYSQL_DATABASE
file_env MYSQL_USER
file_env MYSQL_PASSWORD
file_env MYSQL_ALLOW_EMPTY_PASSWORD
file_env MYSQL_RANDOM_ROOT_PASSWORD
file_env MYSQL_ONETIME_PASSWORD
file_env MYSQL_INITDB_SKIP_TZINFO

mysql_check_config "$mysqld" "${server_args[@]}"

datadir="${MYSQL_DATADIR:-$(mysql_get_config datadir "$mysqld" "${server_args[@]}")}"
socket="${MYSQL_UNIX_PORT:-$(mysql_get_config socket "$mysqld" "${server_args[@]}")}"
socket_dir="$(dirname "$socket")"

if [[ "$(id -u)" == 0 ]]; then
  mkdir -p "$datadir" "$socket_dir" /var/lib/mysql-files /var/run/mysqld
  chown -R mysql:mysql "$datadir" "$socket_dir" /var/lib/mysql-files /var/run/mysqld
  chmod 1777 "$socket_dir"
  exec runuser --preserve-environment --user mysql -- "$0" "$@"
fi

if [[ ! -d "$datadir/mysql" ]]; then
  if [[ -n "${MYSQL_ROOT_PASSWORD:-}" && "${MYSQL_ALLOW_EMPTY_PASSWORD:-}" == 'yes' ]]; then
    echo "error: MYSQL_ROOT_PASSWORD and MYSQL_ALLOW_EMPTY_PASSWORD cannot be set together" >&2
    exit 1
  fi
  if [[ -z "${MYSQL_ROOT_PASSWORD:-}" && "${MYSQL_ALLOW_EMPTY_PASSWORD:-}" != 'yes' && "${MYSQL_RANDOM_ROOT_PASSWORD:-}" != 'yes' ]]; then
    echo "error: set MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD=yes, or MYSQL_RANDOM_ROOT_PASSWORD=yes" >&2
    exit 1
  fi

  if [[ "${MYSQL_RANDOM_ROOT_PASSWORD:-}" == 'yes' ]]; then
    MYSQL_ROOT_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 || true)"
    export MYSQL_ROOT_PASSWORD
    log "GENERATED ROOT PASSWORD: ${MYSQL_ROOT_PASSWORD}"
  fi

  log "initializing database"
  "$mysqld" "${server_args[@]}" --initialize-insecure --default-time-zone=SYSTEM

  defaults_file="$(mktemp)"
  MYSQL_DEFAULTS_FILE="$defaults_file"
  export MYSQL_DEFAULTS_FILE
  chmod 600 "$defaults_file"
  trap 'rm -f "$MYSQL_DEFAULTS_FILE"' EXIT
  cat > "$defaults_file" <<EOF
[client]
protocol=socket
socket=${socket}
user=root
EOF

  log "starting temporary server"
  "$mysqld" "${server_args[@]}" --daemonize --skip-networking --socket="$socket" \
    --pid-file=/var/run/mysqld/mysqld.pid --default-time-zone=SYSTEM

  for attempt in {1..60}; do
    if "$mysqladmin" --defaults-extra-file="$defaults_file" ping --silent; then
      break
    fi
    if [[ "$attempt" == 60 ]]; then
      echo "error: temporary server did not start" >&2
      exit 1
    fi
    sleep 1
  done

  root_password="$(sql_escape_string "${MYSQL_ROOT_PASSWORD:-}")"
  root_host="$(sql_escape_string "${MYSQL_ROOT_HOST:-}")"
  mysql_password="$(sql_escape_string "${MYSQL_PASSWORD:-}")"
  database_name="$(sql_escape_identifier "${MYSQL_DATABASE:-}")"

  "$mysql" --defaults-extra-file="$defaults_file" --database=mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';
${root_host:+CREATE USER 'root'@'${root_host}' IDENTIFIED BY '${root_password}'; GRANT ALL ON *.* TO 'root'@'${root_host}' WITH GRANT OPTION;}
FLUSH PRIVILEGES;
SQL

  if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    printf 'password=%s\n' "$MYSQL_ROOT_PASSWORD" >> "$defaults_file"
  fi

  if [[ -n "${MYSQL_DATABASE:-}" ]]; then
    "$mysql" --defaults-extra-file="$defaults_file" --database=mysql \
      -e "CREATE DATABASE IF NOT EXISTS \`${database_name}\`;"
  fi

  if [[ -n "${MYSQL_USER:-}" ]]; then
    user_name="$(sql_escape_string "$MYSQL_USER")"
    "$mysql" --defaults-extra-file="$defaults_file" --database=mysql <<SQL
CREATE USER '${user_name}'@'%' IDENTIFIED BY '${mysql_password}';
${MYSQL_DATABASE:+GRANT ALL ON \`${database_name}\`.* TO '${user_name}'@'%';}
FLUSH PRIVILEGES;
SQL
  fi

  if [[ "${MYSQL_INITDB_SKIP_TZINFO:-}" != 'yes' && -x "$tzinfo_to_sql" ]]; then
    "$tzinfo_to_sql" /usr/share/zoneinfo \
      | "$mysql" --defaults-extra-file="$defaults_file" --force mysql
  fi

  mysql_process_init_files

  if [[ "${MYSQL_ONETIME_PASSWORD:-}" == 'yes' ]]; then
    "$mysql" --defaults-extra-file="$defaults_file" --database=mysql \
      -e "ALTER USER 'root'@'localhost' PASSWORD EXPIRE;"
  fi

  log "stopping temporary server"
  "$mysqladmin" --defaults-extra-file="$defaults_file" shutdown
  rm -f "$defaults_file"
  trap - EXIT
  unset MYSQL_DEFAULTS_FILE
  log "database initialized"
fi

exec "$mysqld" "${server_args[@]}"

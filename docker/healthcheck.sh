#!/usr/bin/env bash
set -Eeuo pipefail

socket="${MYSQL_UNIX_PORT:-/var/lib/mysql/mysql.sock}"
args=(--protocol=socket --socket="$socket" --host=localhost --user=root)

if [[ -n "${MYSQL_ROOT_PASSWORD_FILE:-}" ]]; then
  MYSQL_ROOT_PASSWORD="$(<"$MYSQL_ROOT_PASSWORD_FILE")"
fi
if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  args+=("--password=${MYSQL_ROOT_PASSWORD}")
fi

exec /usr/local/mysql/bin/mysqladmin "${args[@]}" ping --silent


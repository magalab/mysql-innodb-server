#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
phase="${1:-}"
source_dir="${2:-}"

if [[ "$phase" != "optional" && "$phase" != "user" && "$phase" != "strict" ]]; then
  echo "usage: CONFIRM_PRUNE=yes $0 {optional|user|strict} SOURCE_DIR" >&2
  exit 2
fi
if [[ -z "$source_dir" || ! -f "$source_dir/CMakeLists.txt" ]]; then
  echo "usage: CONFIRM_PRUNE=yes $0 $phase SOURCE_DIR" >&2
  exit 2
fi
if [[ "${CONFIRM_PRUNE:-}" != "yes" ]]; then
  echo "refusing to delete source directories; set CONFIRM_PRUNE=yes" >&2
  exit 2
fi

source_dir="$(cd "$source_dir" && pwd)"
if [[ "$source_dir" == "$repo_root" || "$source_dir" == / ]]; then
  echo "refusing unsafe SOURCE_DIR: $source_dir" >&2
  exit 2
fi

optional_dirs=(
  storage/archive
  storage/blackhole
  storage/federated
  storage/ndb
  storage/example
  storage/secondary_engine_mock
  sql/dd/ndbinfo_schema
)
user_dirs=(
  storage/csv
  storage/myisam
  storage/myisammrg
)
strict_dirs=(
  storage/heap
  storage/temptable
  storage/perfschema
)

dirs=("${optional_dirs[@]}")
if [[ "$phase" == "user" || "$phase" == "strict" ]]; then
  dirs+=("${user_dirs[@]}")
fi
if [[ "$phase" == "strict" ]]; then
  dirs+=("${strict_dirs[@]}")
fi

for relative_dir in "${dirs[@]}"; do
  target="$source_dir/$relative_dir"
  if [[ -e "$target" ]]; then
    echo "removing $relative_dir"
    rm -rf -- "$target"
  fi
done

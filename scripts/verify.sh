#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:-}"
build_dir="${2:-}"

if [[ -z "$source_dir" || ! -f "$source_dir/CMakeLists.txt" ]]; then
  echo "usage: $0 SOURCE_DIR [BUILD_DIR]" >&2
  exit 2
fi

for relative_dir in \
  storage/archive \
  storage/blackhole \
  storage/federated \
  storage/ndb \
  storage/example \
  storage/secondary_engine_mock \
  sql/dd/ndbinfo_schema \
  storage/csv \
  storage/myisam \
  storage/myisammrg; do
  if [[ -e "$source_dir/$relative_dir" ]]; then
    echo "unexpected source directory: $relative_dir" >&2
    exit 1
  fi
done

echo "optional component source check: OK"

if [[ -n "$build_dir" && -f "$build_dir/CMakeCache.txt" ]]; then
  for engine in ARCHIVE BLACKHOLE FEDERATED NDBCLUSTER; do
    if rg -q "WITH_${engine}_STORAGE_ENGINE:.*=(ON|1)" "$build_dir/CMakeCache.txt"; then
      echo "unexpected enabled engine in CMake cache: $engine" >&2
      exit 1
    fi
  done
  echo "optional component CMake check: OK"

  builtin_file="$build_dir/sql/sql_builtin.cc"
  if [[ -f "$builtin_file" ]]; then
    for plugin in builtin_myisam_plugin builtin_csv_plugin \
      builtin_myisammrg_plugin builtin_ndbcluster_plugin; do
      if rg -q "$plugin" "$builtin_file"; then
        echo "unexpected builtin plugin: $plugin" >&2
        exit 1
      fi
    done
    echo "builtin plugin check: OK"
  fi
fi

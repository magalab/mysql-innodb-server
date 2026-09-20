#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:-}"
build_dir="${2:-}"

if [[ -z "$source_dir" || -z "$build_dir" || ! -f "$source_dir/CMakeLists.txt" ]]; then
  echo "usage: $0 SOURCE_DIR BUILD_DIR [extra cmake arguments...]" >&2
  exit 2
fi

cmake -S "$source_dir" -B "$build_dir" \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_UNIT_TESTS=OFF \
  -DWITH_ROUTER=OFF \
  -DWITH_NDB=OFF \
  -DWITHOUT_NDBCLUSTER_STORAGE_ENGINE=ON \
  -DWITHOUT_ARCHIVE_STORAGE_ENGINE=ON \
  -DWITHOUT_BLACKHOLE_STORAGE_ENGINE=ON \
  -DWITHOUT_FEDERATED_STORAGE_ENGINE=ON \
  -DWITH_MYSQLX=OFF \
  -DWITH_NGRAM_PARSER=OFF \
  -DWITH_FIDO=none \
  -DWITH_CURL=none \
  "$@"

cmake --build "$build_dir" --parallel "${CMAKE_BUILD_PARALLEL_LEVEL:-2}"

#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${1:-}"

if [[ -z "$source_dir" || ! -f "$source_dir/CMakeLists.txt" ]]; then
  echo "usage: $0 SOURCE_DIR" >&2
  exit 2
fi

source_dir="$(cd "$source_dir" && pwd)"
if [[ "$source_dir" == "$repo_root" ]]; then
  echo "refusing to use the patch repository itself as SOURCE_DIR" >&2
  exit 2
fi

shopt -s nullglob
patches=("$repo_root"/patches/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "no patches found"
  exit 0
fi

for patch_file in "${patches[@]}"; do
  echo "checking $(basename "$patch_file")"
  (cd "$source_dir" && git apply --check "$patch_file")
done

for patch_file in "${patches[@]}"; do
  echo "applying $(basename "$patch_file")"
  (cd "$source_dir" && git apply "$patch_file")
done

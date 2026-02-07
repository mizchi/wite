#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT_DIR/bench/corpus/manifest.tsv"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi
if ! command -v shasum >/dev/null 2>&1; then
  echo "shasum is required" >&2
  exit 1
fi

repo_url() {
  local repo="$1"
  local commit="$2"
  local path="$3"
  case "$repo" in
    binaryen)
      echo "https://raw.githubusercontent.com/WebAssembly/binaryen/$commit/$path"
      ;;
    wac)
      echo "https://raw.githubusercontent.com/bytecodealliance/wac/$commit/$path"
      ;;
    *)
      echo "unknown repo: $repo" >&2
      return 1
      ;;
  esac
}

while IFS=$'\t' read -r kind repo commit upstream_path dest_path sha256; do
  if [[ -z "${kind:-}" || "$kind" == \#* ]]; then
    continue
  fi

  url="$(repo_url "$repo" "$commit" "$upstream_path")"
  tmp_file="$(mktemp)"

  curl -fsSL "$url" -o "$tmp_file"
  actual_sha256="$(shasum -a 256 "$tmp_file" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$sha256" ]]; then
    echo "sha256 mismatch: $dest_path" >&2
    echo "  expected: $sha256" >&2
    echo "  actual  : $actual_sha256" >&2
    rm -f "$tmp_file"
    exit 1
  fi

  mkdir -p "$(dirname "$ROOT_DIR/$dest_path")"
  mv "$tmp_file" "$ROOT_DIR/$dest_path"
  echo "synced: $dest_path"
done < "$MANIFEST"

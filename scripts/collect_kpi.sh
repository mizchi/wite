#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/bench/kpi"
SIZE_TSV="$OUT_DIR/size.tsv"
COMPONENT_DCE_TSV="$OUT_DIR/component_dce.tsv"
RUNTIME_TSV="$OUT_DIR/runtime.tsv"
BENCH_RAW_LOG="$OUT_DIR/bench.raw.log"
LATEST_MD="$OUT_DIR/latest.md"

mkdir -p "$OUT_DIR"

tmp_wasm="$(mktemp)"
tmp_runtime="$(mktemp)"
tmp_component="$(mktemp)"
cleanup() {
  rm -f "$tmp_wasm" "$tmp_runtime" "$tmp_component"
}
trap cleanup EXIT

echo -e "file\tbefore_bytes\tafter_bytes\treduction_ratio_pct" > "$SIZE_TSV"

total_before=0
total_after=0

while IFS= read -r file; do
  rel="${file#$ROOT_DIR/}"
  line="$(
    moon run src/main --target js -- optimize "$rel" "$tmp_wasm" -O1 2>&1 |
      awk '/^optimized: / { print; exit }'
  )"
  if [[ -z "${line:-}" ]]; then
    echo "failed to parse optimize output: $rel" >&2
    exit 1
  fi

  before="$(echo "$line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\1/')"
  after="$(echo "$line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\2/')"
  if [[ ! "$before" =~ ^[0-9]+$ || ! "$after" =~ ^[0-9]+$ ]]; then
    echo "invalid optimize output: $line" >&2
    exit 1
  fi

  ratio_pct="$(awk -v b="$before" -v a="$after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
  echo -e "$rel\t$before\t$after\t$ratio_pct" >> "$SIZE_TSV"

  total_before=$((total_before + before))
  total_after=$((total_after + after))
done < <(find "$ROOT_DIR/bench/corpus/core/binaryen" -type f -name '*.wasm' | sort)

total_ratio_pct="$(awk -v b="$total_before" -v a="$total_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"

echo -e "file\tcomponent_bytes\tcore_before_bytes\tcore_after_bytes\treduction_ratio_pct\tcore_module_count\troot_count" > "$COMPONENT_DCE_TSV"

component_total_component_bytes=0
component_total_before=0
component_total_after=0

while IFS= read -r file; do
  rel="${file#$ROOT_DIR/}"
  moon run src/main --target js -- component-dce-kpi "$rel" > "$tmp_component"

  component_bytes="$(awk -F '=' '/^kpi-total-component-bytes=/{print $2; exit}' "$tmp_component")"
  core_before="$(awk -F '=' '/^kpi-total-core-before-bytes=/{print $2; exit}' "$tmp_component")"
  core_after="$(awk -F '=' '/^kpi-total-core-after-bytes=/{print $2; exit}' "$tmp_component")"
  core_module_count="$(awk -F '=' '/^kpi-core-module-count=/{print $2; exit}' "$tmp_component")"
  root_count="$(awk -F '=' '/^kpi-root-count=/{print $2; exit}' "$tmp_component")"
  if [[ ! "$component_bytes" =~ ^[0-9]+$ || ! "$core_before" =~ ^[0-9]+$ || ! "$core_after" =~ ^[0-9]+$ || ! "$core_module_count" =~ ^[0-9]+$ || ! "$root_count" =~ ^[0-9]+$ ]]; then
    echo "failed to parse component-dce-kpi output: $rel" >&2
    cat "$tmp_component" >&2
    exit 1
  fi

  ratio_pct="$(awk -v b="$core_before" -v a="$core_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
  echo -e "$rel\t$component_bytes\t$core_before\t$core_after\t$ratio_pct\t$core_module_count\t$root_count" >> "$COMPONENT_DCE_TSV"

  component_total_component_bytes=$((component_total_component_bytes + component_bytes))
  component_total_before=$((component_total_before + core_before))
  component_total_after=$((component_total_after + core_after))
done < <(find "$ROOT_DIR/bench/corpus/component-dce" -type f -name '*.wasm' | sort)

component_total_ratio_pct="$(awk -v b="$component_total_before" -v a="$component_total_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"

moon bench --target js > "$BENCH_RAW_LOG"

echo -e "benchmark\tmean\tunit" > "$RUNTIME_TSV"
awk '
/\("bench: / {
  name = $0
  sub(/.*\("bench: /, "", name)
  sub(/"\).*/, "", name)
  next
}
/time \(mean/ {
  if (getline <= 0) {
    next
  }
  line = $0
  gsub(/^[ \t]+/, "", line)
  n = split(line, a, /[ \t]+/)
  if (name != "" && n >= 2) {
    printf "%s\t%s\t%s\n", name, a[1], a[2]
  }
}
' "$BENCH_RAW_LOG" > "$tmp_runtime"

while IFS=$'\t' read -r name mean unit; do
  if [[ -z "${name:-}" ]]; then
    continue
  fi
  unit_ascii="$(printf '%s' "$unit" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$unit")"
  unit_ascii="$(echo "$unit_ascii" | sed -E 's/[^a-zA-Z0-9]+//g')"
  unit_ascii="$(echo "$unit_ascii" | tr 'A-Z' 'a-z')"
  if [[ -z "${unit_ascii:-}" ]]; then
    unit_ascii="unknown"
  fi
  if [[ "$unit_ascii" == "uss" || "$unit_ascii" == "mus" || "$unit_ascii" == "micros" ]]; then
    unit_ascii="us"
  fi
  if [[ "$unit_ascii" == "s" && "$unit" != "s" ]]; then
    unit_ascii="us"
  fi
  echo -e "$name\t$mean\t$unit_ascii" >> "$RUNTIME_TSV"
done < "$tmp_runtime"

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
{
  echo "# KPI Report"
  echo
  echo "- generated_at_utc: $timestamp"
  echo "- primary_kpi: size_reduction_ratio_o1_core_corpus"
  echo "- primary_kpi_component_dce: size_reduction_ratio_component_dce_core_modules"
  echo "- secondary_kpi: moon_bench_mean"
  echo
  echo "## Size KPI (priority 1)"
  echo
  echo "- total_before_bytes: $total_before"
  echo "- total_after_bytes: $total_after"
  echo "- total_reduction_ratio_pct: $total_ratio_pct"
  echo
  echo "| file | before_bytes | after_bytes | reduction_ratio_pct |"
  echo "| --- | ---: | ---: | ---: |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4 }' "$SIZE_TSV"
  echo
  echo "## Component-model DCE Size KPI (priority 1)"
  echo
  echo "- total_component_bytes: $component_total_component_bytes"
  echo "- total_core_before_bytes: $component_total_before"
  echo "- total_core_after_bytes: $component_total_after"
  echo "- total_core_reduction_ratio_pct: $component_total_ratio_pct"
  echo
  echo "| file | component_bytes | core_before_bytes | core_after_bytes | reduction_ratio_pct | core_module_count | root_count |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7 }' "$COMPONENT_DCE_TSV"
  echo
  echo "## Runtime KPI (priority 2)"
  echo
  echo "| benchmark | mean | unit |"
  echo "| --- | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s |\n", $1, $2, $3 }' "$RUNTIME_TSV"
} > "$LATEST_MD"

echo "kpi report written:"
echo "  $LATEST_MD"
echo "  $SIZE_TSV"
echo "  $COMPONENT_DCE_TSV"
echo "  $RUNTIME_TSV"
echo "  $BENCH_RAW_LOG"

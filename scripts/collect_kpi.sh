#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/bench/kpi"
SIZE_TSV="$OUT_DIR/size.tsv"
RUNTIME_TSV="$OUT_DIR/runtime.tsv"
BENCH_RAW_LOG="$OUT_DIR/bench.raw.log"
LATEST_MD="$OUT_DIR/latest.md"

mkdir -p "$OUT_DIR"

tmp_wasm="$(mktemp)"
tmp_runtime="$(mktemp)"
cleanup() {
  rm -f "$tmp_wasm" "$tmp_runtime"
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
  echo "## Runtime KPI (priority 2)"
  echo
  echo "| benchmark | mean | unit |"
  echo "| --- | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s |\n", $1, $2, $3 }' "$RUNTIME_TSV"
} > "$LATEST_MD"

echo "kpi report written:"
echo "  $LATEST_MD"
echo "  $SIZE_TSV"
echo "  $RUNTIME_TSV"
echo "  $BENCH_RAW_LOG"

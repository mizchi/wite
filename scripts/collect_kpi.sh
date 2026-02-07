#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/bench/kpi"
SIZE_TSV="$OUT_DIR/size.tsv"
COMPONENT_DCE_TSV="$OUT_DIR/component_dce.tsv"
DIRECTIZE_CHAIN_TSV="$OUT_DIR/directize_chain.tsv"
RUNTIME_TSV="$OUT_DIR/runtime.tsv"
BENCH_RAW_LOG="$OUT_DIR/bench.raw.log"
LATEST_MD="$OUT_DIR/latest.md"
WASM_OPT_BIN="${WASM_OPT_BIN:-}"
WASM_OPT_ARGS=(
  -Oz
  --all-features
  --strip-debug
  --strip-dwarf
  --strip-target-features
)
PRIMARY_GAP_EXCLUDED_BASENAMES=(
  "gc_target_feature.wasm"
)
PRIMARY_GAP_SCOPE="core corpus excluding gc_target_feature.wasm"
REFERENCE_GAP_SCOPE="all core corpus files (includes gc_target_feature.wasm)"

if [[ -z "$WASM_OPT_BIN" ]]; then
  WASM_OPT_BIN="$(command -v wasm-opt || true)"
fi

HAS_WASM_OPT=0
if [[ -n "$WASM_OPT_BIN" ]]; then
  HAS_WASM_OPT=1
fi

mkdir -p "$OUT_DIR"

tmp_wasm="$(mktemp)"
tmp_wasm_opt="$(mktemp)"
tmp_runtime="$(mktemp)"
tmp_component="$(mktemp)"
cleanup() {
  rm -f "$tmp_wasm" "$tmp_wasm_opt" "$tmp_runtime" "$tmp_component"
}
trap cleanup EXIT

echo -e "file\tbefore_bytes\twalyze_after_bytes\twalyze_reduction_ratio_pct\twasm_opt_after_bytes\twasm_opt_reduction_ratio_pct\tgap_to_wasm_opt_bytes\tgap_to_wasm_opt_ratio_pct\twasm_opt_status" > "$SIZE_TSV"
echo -e "file\tbefore_bytes\tpre_dce_after_bytes\tpost_dce_after_bytes\tpost_rume_after_bytes\tdce_gain_bytes\trume_gain_bytes\ttotal_gain_bytes\tdirectize_calls\tstatus" > "$DIRECTIZE_CHAIN_TSV"

total_before=0
total_after=0
core_file_count=0
primary_gap_before=0
primary_gap_after=0
primary_gap_file_count=0

wasm_opt_total_before=0
wasm_opt_total_walyze_after=0
wasm_opt_total_after=0
wasm_opt_success_files=0
primary_gap_wasm_opt_total_before=0
primary_gap_wasm_opt_total_walyze_after=0
primary_gap_wasm_opt_total_after=0
primary_gap_wasm_opt_success_files=0

directize_total_before=0
directize_total_pre_dce_after=0
directize_total_post_dce_after=0
directize_total_post_rume_after=0
directize_total_dce_gain=0
directize_total_rume_gain=0
directize_total_gain=0
directize_total_calls=0
directize_success_files=0

while IFS= read -r file; do
  core_file_count=$((core_file_count + 1))
  rel="${file#$ROOT_DIR/}"
  base="$(basename "$file")"
  primary_gap_included=1
  for excluded in "${PRIMARY_GAP_EXCLUDED_BASENAMES[@]}"; do
    if [[ "$base" == "$excluded" ]]; then
      primary_gap_included=0
      break
    fi
  done
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

  pre_dce_before="NA"
  pre_dce_after="NA"
  post_dce_after="NA"
  post_rume_after="NA"
  dce_gain_bytes="NA"
  rume_gain_bytes="NA"
  total_gain_bytes="NA"
  directize_calls="NA"
  directize_status="ok"

  if pre_dce_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=2 2>&1)"; then
    pre_dce_line="$(printf '%s\n' "$pre_dce_output" | awk '/^optimized: / { print; exit }')"
    pre_dce_before="$(echo "$pre_dce_line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\1/')"
    pre_dce_after="$(echo "$pre_dce_line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\2/')"
    if [[ ! "$pre_dce_before" =~ ^[0-9]+$ || ! "$pre_dce_after" =~ ^[0-9]+$ ]]; then
      directize_status="pre-dce-parse-error"
      pre_dce_before="NA"
      pre_dce_after="NA"
    fi
  else
    directize_status="pre-dce-error"
  fi

  if [[ "$directize_status" == "ok" ]]; then
    if post_dce_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=2 --dce-apply --dfe-apply --msf-apply 2>&1)"; then
      post_dce_line="$(printf '%s\n' "$post_dce_output" | awk '/^optimized: / { print; exit }')"
      post_dce_after="$(echo "$post_dce_line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\2/')"
      if [[ ! "$post_dce_after" =~ ^[0-9]+$ ]]; then
        directize_status="post-dce-parse-error"
        post_dce_after="NA"
      fi
    else
      directize_status="post-dce-error"
    fi
  fi

  if [[ "$directize_status" == "ok" ]]; then
    if post_rume_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=2 --dce-apply --dfe-apply --msf-apply --rume-apply 2>&1)"; then
      post_rume_line="$(printf '%s\n' "$post_rume_output" | awk '/^optimized: / { print; exit }')"
      post_rume_after="$(echo "$post_rume_line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\2/')"
      if [[ ! "$post_rume_after" =~ ^[0-9]+$ ]]; then
        directize_status="post-rume-parse-error"
        post_rume_after="NA"
      fi
    else
      directize_status="post-rume-error"
    fi
  fi

  if [[ "$directize_status" == "ok" ]]; then
    directize_calls="$(printf '%s\n' "$post_dce_output" | sed -nE 's/.*directize:calls:([0-9]+).*/\1/p' | head -n 1)"
    if [[ -z "${directize_calls:-}" ]]; then
      directize_calls=0
    fi
    dce_gain_bytes=$((pre_dce_after - post_dce_after))
    rume_gain_bytes=$((post_dce_after - post_rume_after))
    total_gain_bytes=$((pre_dce_after - post_rume_after))
  fi

  wasm_opt_after="NA"
  wasm_opt_ratio_pct="NA"
  gap_to_wasm_opt_bytes="NA"
  gap_to_wasm_opt_ratio_pct="NA"
  wasm_opt_status="missing"

  if [[ "$HAS_WASM_OPT" -eq 1 ]]; then
    if "$WASM_OPT_BIN" "$file" -o "$tmp_wasm_opt" "${WASM_OPT_ARGS[@]}" >/dev/null 2>&1; then
      wasm_opt_after="$(wc -c < "$tmp_wasm_opt" | tr -d '[:space:]')"
      if [[ "$wasm_opt_after" =~ ^[0-9]+$ ]]; then
        wasm_opt_ratio_pct="$(awk -v b="$before" -v a="$wasm_opt_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
        gap_to_wasm_opt_bytes=$((after - wasm_opt_after))
        gap_to_wasm_opt_ratio_pct="$(awk -v w="$ratio_pct" -v o="$wasm_opt_ratio_pct" 'BEGIN { printf "%.4f", (w - o) }')"
        wasm_opt_status="ok"

        wasm_opt_total_before=$((wasm_opt_total_before + before))
        wasm_opt_total_walyze_after=$((wasm_opt_total_walyze_after + after))
        wasm_opt_total_after=$((wasm_opt_total_after + wasm_opt_after))
        wasm_opt_success_files=$((wasm_opt_success_files + 1))
        if [[ "$primary_gap_included" -eq 1 ]]; then
          primary_gap_wasm_opt_total_before=$((primary_gap_wasm_opt_total_before + before))
          primary_gap_wasm_opt_total_walyze_after=$((primary_gap_wasm_opt_total_walyze_after + after))
          primary_gap_wasm_opt_total_after=$((primary_gap_wasm_opt_total_after + wasm_opt_after))
          primary_gap_wasm_opt_success_files=$((primary_gap_wasm_opt_success_files + 1))
        fi
      else
        wasm_opt_status="invalid-output"
        wasm_opt_after="NA"
      fi
    else
      wasm_opt_status="error"
    fi
  fi

  echo -e "$rel\t$before\t$after\t$ratio_pct\t$wasm_opt_after\t$wasm_opt_ratio_pct\t$gap_to_wasm_opt_bytes\t$gap_to_wasm_opt_ratio_pct\t$wasm_opt_status" >> "$SIZE_TSV"
  echo -e "$rel\t$pre_dce_before\t$pre_dce_after\t$post_dce_after\t$post_rume_after\t$dce_gain_bytes\t$rume_gain_bytes\t$total_gain_bytes\t$directize_calls\t$directize_status" >> "$DIRECTIZE_CHAIN_TSV"

  total_before=$((total_before + before))
  total_after=$((total_after + after))
  if [[ "$primary_gap_included" -eq 1 ]]; then
    primary_gap_before=$((primary_gap_before + before))
    primary_gap_after=$((primary_gap_after + after))
    primary_gap_file_count=$((primary_gap_file_count + 1))
  fi
  if [[ "$directize_status" == "ok" ]]; then
    directize_total_before=$((directize_total_before + pre_dce_before))
    directize_total_pre_dce_after=$((directize_total_pre_dce_after + pre_dce_after))
    directize_total_post_dce_after=$((directize_total_post_dce_after + post_dce_after))
    directize_total_post_rume_after=$((directize_total_post_rume_after + post_rume_after))
    directize_total_dce_gain=$((directize_total_dce_gain + dce_gain_bytes))
    directize_total_rume_gain=$((directize_total_rume_gain + rume_gain_bytes))
    directize_total_gain=$((directize_total_gain + total_gain_bytes))
    directize_total_calls=$((directize_total_calls + directize_calls))
    directize_success_files=$((directize_success_files + 1))
  fi
done < <(find "$ROOT_DIR/bench/corpus/core/binaryen" -type f -name '*.wasm' | sort)

total_ratio_pct="$(awk -v b="$total_before" -v a="$total_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
wasm_opt_total_ratio_pct="NA"
wasm_opt_total_walyze_ratio_pct="NA"
wasm_opt_total_gap_bytes="NA"
wasm_opt_total_gap_ratio_pct="NA"
primary_gap_ratio_pct="$(awk -v b="$primary_gap_before" -v a="$primary_gap_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
primary_gap_wasm_opt_ratio_pct="NA"
primary_gap_wasm_opt_walyze_ratio_pct="NA"
primary_gap_to_wasm_opt_bytes="NA"
primary_gap_to_wasm_opt_ratio_pct="NA"
if [[ "$wasm_opt_success_files" -gt 0 ]]; then
  wasm_opt_total_ratio_pct="$(awk -v b="$wasm_opt_total_before" -v a="$wasm_opt_total_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
  wasm_opt_total_walyze_ratio_pct="$(awk -v b="$wasm_opt_total_before" -v a="$wasm_opt_total_walyze_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
  wasm_opt_total_gap_bytes=$((wasm_opt_total_walyze_after - wasm_opt_total_after))
  wasm_opt_total_gap_ratio_pct="$(awk -v w="$wasm_opt_total_walyze_ratio_pct" -v o="$wasm_opt_total_ratio_pct" 'BEGIN { printf "%.4f", (w - o) }')"
fi
if [[ "$primary_gap_wasm_opt_success_files" -gt 0 ]]; then
  primary_gap_wasm_opt_ratio_pct="$(awk -v b="$primary_gap_wasm_opt_total_before" -v a="$primary_gap_wasm_opt_total_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
  primary_gap_wasm_opt_walyze_ratio_pct="$(awk -v b="$primary_gap_wasm_opt_total_before" -v a="$primary_gap_wasm_opt_total_walyze_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
  primary_gap_to_wasm_opt_bytes=$((primary_gap_wasm_opt_total_walyze_after - primary_gap_wasm_opt_total_after))
  primary_gap_to_wasm_opt_ratio_pct="$(awk -v w="$primary_gap_wasm_opt_walyze_ratio_pct" -v o="$primary_gap_wasm_opt_ratio_pct" 'BEGIN { printf "%.4f", (w - o) }')"
fi

directize_total_post_rume_reduction_ratio_pct="$(awk -v b="$directize_total_before" -v a="$directize_total_post_rume_after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }')"
directize_total_dce_gain_ratio_pct="$(awk -v b="$directize_total_pre_dce_after" -v g="$directize_total_dce_gain" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", (g * 100.0) / b } }')"
directize_total_rume_gain_ratio_pct="$(awk -v b="$directize_total_post_dce_after" -v g="$directize_total_rume_gain" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", (g * 100.0) / b } }')"
directize_total_gain_ratio_pct="$(awk -v b="$directize_total_pre_dce_after" -v g="$directize_total_gain" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", (g * 100.0) / b } }')"

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
  echo "- primary_gap_scope: $PRIMARY_GAP_SCOPE"
  echo "- primary_gap_excluded_files: ${PRIMARY_GAP_EXCLUDED_BASENAMES[*]}"
  echo "- total_before_bytes: $primary_gap_before"
  echo "- total_after_bytes: $primary_gap_after"
  echo "- total_reduction_ratio_pct: $primary_gap_ratio_pct"
  if [[ "$HAS_WASM_OPT" -eq 1 ]]; then
    echo "- wasm_opt_reference: \`$WASM_OPT_BIN ${WASM_OPT_ARGS[*]}\`"
  else
    echo '- wasm_opt_reference: unavailable (`wasm-opt` not found; install Binaryen or set `WASM_OPT_BIN`)'
  fi
  echo "- wasm_opt_success_files: $primary_gap_wasm_opt_success_files/$primary_gap_file_count"
  if [[ "$primary_gap_wasm_opt_success_files" -gt 0 ]]; then
    echo "- wasm_opt_total_after_bytes: $primary_gap_wasm_opt_total_after"
    echo "- wasm_opt_total_reduction_ratio_pct: $primary_gap_wasm_opt_ratio_pct"
    echo "- gap_to_wasm_opt_bytes: $primary_gap_to_wasm_opt_bytes"
    echo "- gap_to_wasm_opt_ratio_pct: $primary_gap_to_wasm_opt_ratio_pct"
  fi
  echo "- reference_scope: $REFERENCE_GAP_SCOPE"
  echo "- reference_total_before_bytes: $total_before"
  echo "- reference_total_after_bytes: $total_after"
  echo "- reference_total_reduction_ratio_pct: $total_ratio_pct"
  echo "- reference_wasm_opt_success_files: $wasm_opt_success_files/$core_file_count"
  if [[ "$wasm_opt_success_files" -gt 0 ]]; then
    echo "- reference_wasm_opt_total_after_bytes: $wasm_opt_total_after"
    echo "- reference_wasm_opt_total_reduction_ratio_pct: $wasm_opt_total_ratio_pct"
    echo "- reference_gap_to_wasm_opt_bytes: $wasm_opt_total_gap_bytes"
    echo "- reference_gap_to_wasm_opt_ratio_pct: $wasm_opt_total_gap_ratio_pct"
  fi
  echo
  echo "| file | before_bytes | walyze_after_bytes | walyze_reduction_ratio_pct | wasm_opt_after_bytes | wasm_opt_reduction_ratio_pct | gap_to_wasm_opt_bytes | gap_to_wasm_opt_ratio_pct | wasm_opt_status |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9 }' "$SIZE_TSV"
  echo
  echo "## Directize -> DCE -> RUME Delta (priority 1 diagnostics)"
  echo
  echo "- stage_config: \`--strip-debug --strip-dwarf --strip-target-features --rounds=2\` + \`--dce-apply --dfe-apply --msf-apply\` (+ optional \`--rume-apply\`)"
  echo "- success_files: $directize_success_files/$core_file_count"
  echo "- total_before_bytes: $directize_total_before"
  echo "- total_pre_dce_after_bytes: $directize_total_pre_dce_after"
  echo "- total_post_dce_after_bytes: $directize_total_post_dce_after"
  echo "- total_post_rume_after_bytes: $directize_total_post_rume_after"
  echo "- total_post_rume_reduction_ratio_pct: $directize_total_post_rume_reduction_ratio_pct"
  echo "- dce_gain_bytes: $directize_total_dce_gain"
  echo "- dce_gain_ratio_pct: $directize_total_dce_gain_ratio_pct"
  echo "- rume_gain_bytes: $directize_total_rume_gain"
  echo "- rume_gain_ratio_pct: $directize_total_rume_gain_ratio_pct"
  echo "- total_gain_bytes: $directize_total_gain"
  echo "- total_gain_ratio_pct: $directize_total_gain_ratio_pct"
  echo "- directize_calls_total: $directize_total_calls"
  echo
  echo "| file | before_bytes | pre_dce_after_bytes | post_dce_after_bytes | post_rume_after_bytes | dce_gain_bytes | rume_gain_bytes | total_gain_bytes | directize_calls | status |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 }' "$DIRECTIZE_CHAIN_TSV"
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
echo "  $DIRECTIZE_CHAIN_TSV"
echo "  $COMPONENT_DCE_TSV"
echo "  $RUNTIME_TSV"
echo "  $BENCH_RAW_LOG"

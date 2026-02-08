#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/bench/kpi"
SIZE_TSV="$OUT_DIR/size.tsv"
COMPONENT_DCE_TSV="$OUT_DIR/component_dce.tsv"
ANALYZE_ONLY_TSV="$OUT_DIR/analyze_only.tsv"
DIRECTIZE_CHAIN_TSV="$OUT_DIR/directize_chain.tsv"
HEATMAP_TSV="$OUT_DIR/heatmap.tsv"
PASS_WATERFALL_TSV="$OUT_DIR/pass_waterfall.tsv"
NO_CHANGE_REASON_TSV="$OUT_DIR/no_change_reasons.tsv"
NO_CHANGE_TRIAGE_TSV="$OUT_DIR/no_change_triage.tsv"
MIGRATION_TOP3_TSV="$OUT_DIR/migration_top3.tsv"
MIGRATION_TOP3_MD="$OUT_DIR/migration_top3.md"
ZLIB_GAP_MD="$OUT_DIR/zlib_gap.md"
ZLIB_FUNCTION_GAP_TSV="$OUT_DIR/zlib_function_gap.tsv"
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
REFERENCE_GAP_SCOPE="all files under bench/corpus/core (includes gc_target_feature.wasm)"

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
tmp_zlib_wite="$(mktemp)"
tmp_zlib_wasm_opt="$(mktemp)"
tmp_zlib_before_sections="$(mktemp)"
tmp_zlib_wite_sections="$(mktemp)"
tmp_zlib_wasm_opt_sections="$(mktemp)"
tmp_zlib_section_delta_wite="$(mktemp)"
tmp_zlib_section_delta_wasm_opt="$(mktemp)"
tmp_zlib_fn_before="$(mktemp)"
tmp_zlib_fn_wite="$(mktemp)"
tmp_zlib_fn_wasm_opt="$(mktemp)"
tmp_zlib_function_gap_raw="$(mktemp)"
tmp_zlib_block_before="$(mktemp)"
tmp_zlib_block_wite="$(mktemp)"
tmp_zlib_block_wasm_opt="$(mktemp)"
tmp_no_change_triage="$(mktemp)"
tmp_migration_candidates="$(mktemp)"
cleanup() {
  rm -f \
    "$tmp_wasm" "$tmp_wasm_opt" "$tmp_runtime" "$tmp_component" \
    "$tmp_zlib_wite" "$tmp_zlib_wasm_opt" \
    "$tmp_zlib_before_sections" "$tmp_zlib_wite_sections" "$tmp_zlib_wasm_opt_sections" \
    "$tmp_zlib_section_delta_wite" "$tmp_zlib_section_delta_wasm_opt" \
    "$tmp_zlib_fn_before" "$tmp_zlib_fn_wite" "$tmp_zlib_fn_wasm_opt" "$tmp_zlib_function_gap_raw" \
    "$tmp_zlib_block_before" "$tmp_zlib_block_wite" "$tmp_zlib_block_wasm_opt" \
    "$tmp_no_change_triage" "$tmp_migration_candidates"
}
trap cleanup EXIT

ratio_pct() {
  local before="$1"
  local after="$2"
  awk -v b="$before" -v a="$after" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", ((b - a) * 100.0) / b } }'
}

gain_ratio_pct() {
  local base="$1"
  local gain="$2"
  awk -v b="$base" -v g="$gain" 'BEGIN { if (b == 0) { printf "0.0000" } else { printf "%.4f", (g * 100.0) / b } }'
}

extract_optimized_line() {
  local output="$1"
  printf '%s\n' "$output" | awk '/^optimized: / { print; exit }'
}

parse_optimized_before_after() {
  local line="$1"
  local before after
  before="$(echo "$line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\1/')"
  after="$(echo "$line" | sed -E 's/^optimized: ([0-9]+) -> ([0-9]+) bytes$/\2/')"
  if [[ ! "$before" =~ ^[0-9]+$ || ! "$after" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  echo "$before $after"
}

parse_profile_code_body_bytes() {
  local wasm_path="$1"
  moon run src/main --target js -- profile "$wasm_path" 2>/dev/null |
    awk -F ': ' '/^  code_body_bytes: / { print $2; exit }'
}

parse_block_total_instruction_bytes() {
  local wasm_path="$1"
  moon run src/main --target js -- block-sizes "$wasm_path" 0 2>/dev/null |
    awk -F ': ' '/^  total_instruction_bytes: / { print $2; exit }'
}

is_uint() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

is_int() {
  local value="$1"
  [[ "$value" =~ ^-?[0-9]+$ ]]
}

int_or_zero() {
  local value="$1"
  if is_int "$value"; then
    echo "$value"
  else
    echo "0"
  fi
}

core_optimize_corpus_files() {
  find "$ROOT_DIR/bench/corpus/core" -type f -name '*.wasm' | sort
}

core_analyze_only_corpus_files() {
  find "$ROOT_DIR/bench/corpus/core-analyze" -type f -name '*.wasm' | sort
}

parse_section_sizes_to_tsv() {
  local wasm_path="$1"
  local out_tsv="$2"
  moon run src/main --target js -- analyze "$wasm_path" 2>/dev/null |
    awk '
      /^[[:space:]]+[^:][^:]*: [0-9]+ bytes( \([0-9.]+%\))?$/ {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        bytes = line
        sub(/^.*: /, "", bytes)
        sub(/ \([0-9.]+%\)$/, "", bytes)
        sub(/ bytes$/, "", bytes)
        key = line
        sub(/: [0-9]+ bytes( \([0-9.]+%\))?$/, "", key)
        printf "%s\t%s\n", key, bytes
      }
    ' | sort > "$out_tsv"
}

build_section_delta_tsv() {
  local before_tsv="$1"
  local after_tsv="$2"
  local out_tsv="$3"
  awk -F '\t' '
    FNR == NR {
      before[$1] = $2
      keys[$1] = 1
      next
    }
    {
      after[$1] = $2
      keys[$1] = 1
    }
    END {
      for (k in keys) {
        b = ((k in before) ? before[k] : 0) + 0
        a = ((k in after) ? after[k] : 0) + 0
        g = b - a
        r = (b == 0) ? 0 : ((g * 100.0) / b)
        printf "%s\t%.0f\t%.0f\t%.0f\t%.4f\n", k, b, a, g, r
      }
    }
  ' "$before_tsv" "$after_tsv" | sort -t $'\t' -k4,4nr -k1,1 > "$out_tsv"
}

heat_bar_from_ratio_pct() {
  local ratio_pct="$1"
  awk -v r="$ratio_pct" 'BEGIN {
    v = r + 0.0
    sign = v < 0 ? "-" : "+"
    if (v < 0) v = -v
    level = 0
    if (v >= 0.25) level = 1
    if (v >= 0.50) level = 2
    if (v >= 1.00) level = 3
    if (v >= 2.00) level = 4
    if (v >= 4.00) level = 5
    if (v >= 8.00) level = 6
    if (v >= 12.00) level = 7
    if (v >= 20.00) level = 8
    bar = ""
    for (i = 0; i < level; i++) bar = bar "#"
    if (bar == "") bar = "."
    printf "%s%s", sign, bar
  }'
}

section_gain_from_delta_tsv() {
  local delta_tsv="$1"
  local section_name="$2"
  awk -F '\t' -v section="$section_name" '
    $1 == section { print $4; found = 1; exit }
    END { if (!found) print "NA" }
  ' "$delta_tsv"
}

normalize_no_change_reason() {
  local reason="$1"
  case "$reason" in
    *"no custom section exists for strip passes"*)
      echo "strip:no-custom-section"
      ;;
    *"configured custom-section strip targets were not present"*)
      echo "strip:target-not-present"
      ;;
    *"no code section exists for code-level passes"*)
      echo "code:no-code-section"
      ;;
    *"code-level passes found no reducible instruction patterns"*)
      echo "code:no-reducible-pattern"
      ;;
    *"dce skipped: partial call graph"*)
      echo "dce:partial-callgraph"
      ;;
    *"dce found no removable functions"*)
      echo "dce:no-removable-functions"
      ;;
    *"dce analysis failed"*)
      echo "dce:analysis-failed"
      ;;
    *"unable to inspect section layout for no-change diagnostics"*)
      echo "diag:section-inspect-failed"
      ;;
    *"module is already optimized for active passes"*)
      echo "common:already-optimized"
      ;;
    *"size-neutral rewrite only (bytes changed but size unchanged)"*)
      echo "common:size-neutral-rewrite"
      ;;
    *"no optimization pass is enabled in config"*)
      echo "common:no-pass-enabled"
      ;;
    *)
      echo "other"
      ;;
  esac
}

classify_no_change_category() {
  local category="$1"
  case "$category" in
    strip:no-custom-section|strip:target-not-present|code:no-code-section|common:already-optimized|common:no-pass-enabled)
      echo -e "out-of-scope\tmonitor-only\tP3\tS\tno-action"
      ;;
    common:size-neutral-rewrite)
      echo -e "in-scope\ttuning\tP2\tM\tP5: optimize-instructions encoding"
      ;;
    code:no-reducible-pattern)
      echo -e "in-scope\tcode-pass-extension\tP1\tM\tP5: precompute extension (eqz(eqz)/logic)"
      ;;
    dce:partial-callgraph)
      echo -e "in-scope\tdce-precision\tP1\tL\tP2: signature-refining / cfp"
      ;;
    dce:no-removable-functions)
      echo -e "in-scope\tdce-coverage\tP1\tM\tP2: signature-refining / cfp"
      ;;
    dce:analysis-failed)
      echo -e "in-scope\tbugfix\tP0\tS\tN8: module-elements/index rewrite boundary tests"
      ;;
    diag:section-inspect-failed)
      echo -e "in-scope\tdiagnostics\tP1\tS\tA2: diagnostic hardening"
      ;;
    *)
      echo -e "unknown\tmanual-triage\tP2\tM\tA2: manual classification"
      ;;
  esac
}

sum_reason_count_by_category() {
  local category="$1"
  awk -F '\t' -v category="$category" 'NR > 1 && $2 == category { sum += $4 } END { print sum + 0 }' "$NO_CHANGE_REASON_TSV"
}

sum_reason_count_by_scope() {
  local scope="$1"
  awk -F '\t' -v scope="$scope" 'NR > 1 && $5 == scope { sum += $4 } END { print sum + 0 }' "$NO_CHANGE_TRIAGE_TSV"
}

generate_no_change_triage() {
  echo -e "stage\tcategory\treason\tcount\tscope\taction\tpriority\testimate\ttodo_target\tsample_files" > "$NO_CHANGE_TRIAGE_TSV"
  : > "$tmp_no_change_triage"
  awk -F '\t' 'NR > 1 { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 }' "$NO_CHANGE_REASON_TSV" |
    while IFS=$'\t' read -r stage category reason count sample_files; do
      classification="$(classify_no_change_category "$category")"
      IFS=$'\t' read -r scope action priority estimate todo_target <<< "$classification"
      echo -e "$stage\t$category\t$reason\t$count\t$scope\t$action\t$priority\t$estimate\t$todo_target\t$sample_files" >> "$tmp_no_change_triage"
    done
  sort -t $'\t' -k7,7 -k4,4nr -k1,1 -k2,2 "$tmp_no_change_triage" >> "$NO_CHANGE_TRIAGE_TSV"
}

generate_migration_top3_report() {
  local zlib_code_gap zlib_function_gap zlib_type_gap primary_gap
  local zlib_fn_gap_top_abs zlib_fn_gap_positive_sum
  local code_no_pattern_count dce_no_remove_count dce_partial_count dce_fail_count
  local rume_issue_count waterfall_code_gain waterfall_dce_gain waterfall_rume_gain
  zlib_code_gap="$(int_or_zero "$zlib_gap_code_section_to_wasm_opt_bytes")"
  zlib_function_gap="$(int_or_zero "$zlib_gap_function_section_to_wasm_opt_bytes")"
  zlib_type_gap="$(int_or_zero "$zlib_gap_type_section_to_wasm_opt_bytes")"
  primary_gap="$(int_or_zero "$primary_gap_to_wasm_opt_bytes")"
  zlib_fn_gap_top_abs="$(int_or_zero "$zlib_function_gap_top_abs_bytes")"
  zlib_fn_gap_positive_sum="$(int_or_zero "$zlib_function_gap_positive_sum_bytes")"
  code_no_pattern_count="$(sum_reason_count_by_category "code:no-reducible-pattern")"
  dce_no_remove_count="$(sum_reason_count_by_category "dce:no-removable-functions")"
  dce_partial_count="$(sum_reason_count_by_category "dce:partial-callgraph")"
  dce_fail_count="$(sum_reason_count_by_category "dce:analysis-failed")"
  rume_issue_count="$(awk -F '\t' 'NR > 1 && $12 != "ok" { sum += 1 } END { print sum + 0 }' "$PASS_WATERFALL_TSV")"
  waterfall_code_gain="$(int_or_zero "$waterfall_total_code_gain")"
  waterfall_dce_gain="$(int_or_zero "$waterfall_total_dce_gain")"
  waterfall_rume_gain="$(int_or_zero "$waterfall_total_rume_gain")"

  if [[ "$zlib_code_gap" -lt 0 ]]; then zlib_code_gap=0; fi
  if [[ "$zlib_function_gap" -lt 0 ]]; then zlib_function_gap=0; fi
  if [[ "$zlib_type_gap" -lt 0 ]]; then zlib_type_gap=0; fi
  if [[ "$primary_gap" -lt 0 ]]; then primary_gap=0; fi
  if [[ "$zlib_fn_gap_top_abs" -lt 0 ]]; then zlib_fn_gap_top_abs=0; fi
  if [[ "$zlib_fn_gap_positive_sum" -lt 0 ]]; then zlib_fn_gap_positive_sum=0; fi

  : > "$tmp_migration_candidates"
  score_signature_refining=$((primary_gap + waterfall_dce_gain * 4 + (dce_no_remove_count + dce_partial_count) * 192 + dce_fail_count * 256 + zlib_fn_gap_positive_sum * 2))
  echo -e "$score_signature_refining\tP2 signature-refining/cfp\tDCE precision + callgraph\tP1\tL\tprimary_gap=${primary_gap},dce_gain=${waterfall_dce_gain},dce_reasons=$((dce_no_remove_count + dce_partial_count + dce_fail_count)),fn_gap_positive=${zlib_fn_gap_positive_sum}\tTODO:P2 signature-refining/cfp" >> "$tmp_migration_candidates"

  score_precompute=$((zlib_code_gap + waterfall_code_gain * 16 + code_no_pattern_count * 160 + zlib_fn_gap_top_abs * 4))
  echo -e "$score_precompute\tP5 precompute extension\tcode simplification coverage\tP1\tM\tzlib_code_gap=${zlib_code_gap},code_gain=${waterfall_code_gain},code_no_pattern=${code_no_pattern_count},fn_gap_top=${zlib_fn_gap_top_abs}\tTODO:P5 precompute extension" >> "$tmp_migration_candidates"

  score_rume_guard=$((waterfall_rume_gain * 24 + rume_issue_count * 320 + dce_fail_count * 192))
  echo -e "$score_rume_guard\tN8 module-elements/index rewrite hardening\tRUME safety + removability\tP1\tS\twaterfall_rume_gain=${waterfall_rume_gain},rume_issues=${rume_issue_count}\tTODO:N8 remove-unused-module-elements tests" >> "$tmp_migration_candidates"

  score_gc_type_refine=$((zlib_type_gap * 32 + zlib_function_gap * 8))
  echo -e "$score_gc_type_refine\tN5 GC hierarchy type-refining\tGC type pruning\tP2\tM\tzlib_type_gap=${zlib_type_gap},zlib_function_gap=${zlib_function_gap}\tTODO:N5 GC hierarchy type-refining" >> "$tmp_migration_candidates"

  score_duplicate_import=$((zlib_function_gap * 2 + waterfall_code_gain))
  echo -e "$score_duplicate_import\tP5 duplicate-import-elimination\timport/function section cleanup\tP3\tS\tzlib_function_gap=${zlib_function_gap},code_gain=${waterfall_code_gain}\tTODO:P5 duplicate-import-elimination" >> "$tmp_migration_candidates"

  echo -e "rank\tcandidate\tfocus\tpriority\testimate\tscore\tevidence\ttodo_target" > "$MIGRATION_TOP3_TSV"
  sort -t $'\t' -k1,1nr "$tmp_migration_candidates" |
    head -n 3 |
    awk -F '\t' '{ printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", NR, $2, $3, $4, $5, $1, $6, $7 }' >> "$MIGRATION_TOP3_TSV"

  {
    echo "# wasm-opt Migration Top3"
    echo
    echo "- primary_gap_to_wasm_opt_bytes: $primary_gap_to_wasm_opt_bytes"
    echo "- zlib_code_gap_to_wasm_opt_bytes: $zlib_gap_code_section_to_wasm_opt_bytes"
    echo "- zlib_function_gap_to_wasm_opt_bytes: $zlib_gap_function_section_to_wasm_opt_bytes"
    echo "- zlib_type_gap_to_wasm_opt_bytes: $zlib_gap_type_section_to_wasm_opt_bytes"
    echo "- zlib_function_gap_top_abs_bytes: $zlib_function_gap_top_abs_bytes"
    echo "- zlib_function_gap_positive_sum_bytes: $zlib_function_gap_positive_sum_bytes"
    echo
    echo "| rank | candidate | focus | priority | estimate | score | evidence | todo_target |"
    echo "| ---: | --- | --- | --- | --- | ---: | --- | --- |"
    awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8 }' "$MIGRATION_TOP3_TSV"
  } > "$MIGRATION_TOP3_MD"
}

declare -A NO_CHANGE_REASON_COUNT=()
declare -A NO_CHANGE_REASON_EXAMPLE=()

record_no_change_reasons() {
  local output="$1"
  local stage="$2"
  local rel="$3"
  local reason_line
  reason_line="$(printf '%s\n' "$output" | awk '/^no-change reasons: / { sub(/^no-change reasons: /, ""); print; exit }')"
  if [[ -z "${reason_line:-}" ]]; then
    return
  fi
  local reason
  IFS=',' read -ra reasons <<< "$reason_line"
  for reason in "${reasons[@]}"; do
    reason="$(echo "$reason" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    if [[ -z "$reason" ]]; then
      continue
    fi
    local category
    category="$(normalize_no_change_reason "$reason")"
    local key="${stage}|${category}|${reason}"
    local prev_count="${NO_CHANGE_REASON_COUNT[$key]:-0}"
    NO_CHANGE_REASON_COUNT[$key]=$((prev_count + 1))
    local prev_example="${NO_CHANGE_REASON_EXAMPLE[$key]:-}"
    if [[ -z "$prev_example" ]]; then
      NO_CHANGE_REASON_EXAMPLE[$key]="$rel"
    elif [[ ",$prev_example," != *",$rel,"* ]]; then
      local count_examples
      count_examples="$(printf '%s\n' "$prev_example" | awk -F ', ' '{ print NF }')"
      if [[ "$count_examples" -lt 3 ]]; then
        NO_CHANGE_REASON_EXAMPLE[$key]="$prev_example, $rel"
      fi
    fi
  done
}

generate_zlib_gap_report() {
  local zlib_rel="bench/corpus/core/binaryen/zlib.wasm"
  local zlib_abs="$ROOT_DIR/$zlib_rel"
  if [[ ! -f "$zlib_abs" ]]; then
    {
      echo "# zlib Gap Report"
      echo
      echo "- status: missing fixture"
      echo "- file: $zlib_rel"
    } > "$ZLIB_GAP_MD"
    return
  fi

  zlib_gap_before_bytes="$(wc -c < "$zlib_abs" | tr -d '[:space:]')"

  local zlib_o1_output zlib_line parsed_before_after
  if zlib_o1_output="$(moon run src/main --target js -- optimize "$zlib_rel" "$tmp_zlib_wite" -O1 --verbose 2>&1)"; then
    zlib_line="$(extract_optimized_line "$zlib_o1_output")"
    if [[ -n "${zlib_line:-}" ]] && parsed_before_after="$(parse_optimized_before_after "$zlib_line")"; then
      local zlib_before_from_opt
      read -r zlib_before_from_opt zlib_gap_wite_after_bytes <<< "$parsed_before_after"
      if is_uint "$zlib_before_from_opt"; then
        zlib_gap_before_bytes="$zlib_before_from_opt"
      fi
      if is_uint "$zlib_gap_before_bytes" && is_uint "$zlib_gap_wite_after_bytes"; then
        zlib_gap_wite_ratio_pct="$(ratio_pct "$zlib_gap_before_bytes" "$zlib_gap_wite_after_bytes")"
      fi
    fi
  fi

  if [[ "$HAS_WASM_OPT" -eq 1 ]]; then
    if "$WASM_OPT_BIN" "$zlib_abs" -o "$tmp_zlib_wasm_opt" "${WASM_OPT_ARGS[@]}" >/dev/null 2>&1; then
      zlib_gap_wasm_opt_after_bytes="$(wc -c < "$tmp_zlib_wasm_opt" | tr -d '[:space:]')"
      if is_uint "$zlib_gap_before_bytes" && is_uint "$zlib_gap_wasm_opt_after_bytes"; then
        zlib_gap_wasm_opt_ratio_pct="$(ratio_pct "$zlib_gap_before_bytes" "$zlib_gap_wasm_opt_after_bytes")"
      fi
    fi
  fi
  if is_uint "$zlib_gap_wite_after_bytes" && is_uint "$zlib_gap_wasm_opt_after_bytes"; then
    zlib_gap_to_wasm_opt_bytes=$((zlib_gap_wite_after_bytes - zlib_gap_wasm_opt_after_bytes))
    if [[ "$zlib_gap_wite_ratio_pct" != "NA" && "$zlib_gap_wasm_opt_ratio_pct" != "NA" ]]; then
      zlib_gap_to_wasm_opt_ratio_pct="$(awk -v w="$zlib_gap_wite_ratio_pct" -v o="$zlib_gap_wasm_opt_ratio_pct" 'BEGIN { printf "%.4f", (w - o) }')"
    fi
  fi

  zlib_gap_code_before_bytes="$(parse_profile_code_body_bytes "$zlib_rel" || true)"
  zlib_gap_code_wite_bytes="$(parse_profile_code_body_bytes "$tmp_zlib_wite" || true)"
  if is_uint "$zlib_gap_wasm_opt_after_bytes"; then
    zlib_gap_code_wasm_opt_bytes="$(parse_profile_code_body_bytes "$tmp_zlib_wasm_opt" || true)"
  fi
  if ! is_uint "$zlib_gap_code_before_bytes"; then zlib_gap_code_before_bytes="NA"; fi
  if ! is_uint "$zlib_gap_code_wite_bytes"; then zlib_gap_code_wite_bytes="NA"; fi
  if ! is_uint "$zlib_gap_code_wasm_opt_bytes"; then zlib_gap_code_wasm_opt_bytes="NA"; fi

  zlib_gap_block_before_bytes="$(parse_block_total_instruction_bytes "$zlib_rel" || true)"
  zlib_gap_block_wite_bytes="$(parse_block_total_instruction_bytes "$tmp_zlib_wite" || true)"
  if is_uint "$zlib_gap_wasm_opt_after_bytes"; then
    zlib_gap_block_wasm_opt_bytes="$(parse_block_total_instruction_bytes "$tmp_zlib_wasm_opt" || true)"
  fi
  if ! is_uint "$zlib_gap_block_before_bytes"; then zlib_gap_block_before_bytes="NA"; fi
  if ! is_uint "$zlib_gap_block_wite_bytes"; then zlib_gap_block_wite_bytes="NA"; fi
  if ! is_uint "$zlib_gap_block_wasm_opt_bytes"; then zlib_gap_block_wasm_opt_bytes="NA"; fi

  if parse_section_sizes_to_tsv "$zlib_rel" "$tmp_zlib_before_sections"; then
    if parse_section_sizes_to_tsv "$tmp_zlib_wite" "$tmp_zlib_wite_sections"; then
      build_section_delta_tsv "$tmp_zlib_before_sections" "$tmp_zlib_wite_sections" "$tmp_zlib_section_delta_wite"
    else
      : > "$tmp_zlib_section_delta_wite"
    fi
    if is_uint "$zlib_gap_wasm_opt_after_bytes" && parse_section_sizes_to_tsv "$tmp_zlib_wasm_opt" "$tmp_zlib_wasm_opt_sections"; then
      build_section_delta_tsv "$tmp_zlib_before_sections" "$tmp_zlib_wasm_opt_sections" "$tmp_zlib_section_delta_wasm_opt"
    else
      : > "$tmp_zlib_section_delta_wasm_opt"
    fi
  else
    : > "$tmp_zlib_section_delta_wite"
    : > "$tmp_zlib_section_delta_wasm_opt"
  fi

  local zlib_code_gain_wite zlib_code_gain_wasm_opt
  local zlib_function_gain_wite zlib_function_gain_wasm_opt
  local zlib_type_gain_wite zlib_type_gain_wasm_opt
  zlib_code_gain_wite="$(section_gain_from_delta_tsv "$tmp_zlib_section_delta_wite" "code")"
  zlib_code_gain_wasm_opt="$(section_gain_from_delta_tsv "$tmp_zlib_section_delta_wasm_opt" "code")"
  zlib_function_gain_wite="$(section_gain_from_delta_tsv "$tmp_zlib_section_delta_wite" "function")"
  zlib_function_gain_wasm_opt="$(section_gain_from_delta_tsv "$tmp_zlib_section_delta_wasm_opt" "function")"
  zlib_type_gain_wite="$(section_gain_from_delta_tsv "$tmp_zlib_section_delta_wite" "type")"
  zlib_type_gain_wasm_opt="$(section_gain_from_delta_tsv "$tmp_zlib_section_delta_wasm_opt" "type")"
  if is_int "$zlib_code_gain_wite" && is_int "$zlib_code_gain_wasm_opt"; then
    zlib_gap_code_section_to_wasm_opt_bytes=$((zlib_code_gain_wasm_opt - zlib_code_gain_wite))
  fi
  if is_int "$zlib_function_gain_wite" && is_int "$zlib_function_gain_wasm_opt"; then
    zlib_gap_function_section_to_wasm_opt_bytes=$((zlib_function_gain_wasm_opt - zlib_function_gain_wite))
  fi
  if is_int "$zlib_type_gain_wite" && is_int "$zlib_type_gain_wasm_opt"; then
    zlib_gap_type_section_to_wasm_opt_bytes=$((zlib_type_gain_wasm_opt - zlib_type_gain_wite))
  fi

  moon run src/main --target js -- top-functions "$zlib_rel" 20 > "$tmp_zlib_fn_before" 2>&1 || true
  moon run src/main --target js -- top-functions "$tmp_zlib_wite" 20 > "$tmp_zlib_fn_wite" 2>&1 || true
  if is_uint "$zlib_gap_wasm_opt_after_bytes"; then
    moon run src/main --target js -- top-functions "$tmp_zlib_wasm_opt" 20 > "$tmp_zlib_fn_wasm_opt" 2>&1 || true
  else
    echo "wasm-opt unavailable" > "$tmp_zlib_fn_wasm_opt"
  fi
  echo -e "rank\tkind\tkey\tleft_idx\tright_idx\tleft_body_bytes\tright_body_bytes\tdelta_bytes\tabs_gap_bytes\tleft_exports\tright_exports" > "$ZLIB_FUNCTION_GAP_TSV"
  if is_uint "$zlib_gap_wasm_opt_after_bytes"; then
    moon run src/main --target js -- function-gap "$tmp_zlib_wite" "$tmp_zlib_wasm_opt" 20 > "$tmp_zlib_function_gap_raw" 2>&1 || true
    awk -F '\t' '
      /^[[:space:]]*tsv\t/ {
        rank += 1
        printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", rank, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
      }
    ' "$tmp_zlib_function_gap_raw" >> "$ZLIB_FUNCTION_GAP_TSV"
    zlib_function_gap_entry_count="$(awk 'NR > 1 { count += 1 } END { print count + 0 }' "$ZLIB_FUNCTION_GAP_TSV")"
    zlib_function_gap_top_abs_bytes="$(awk 'NR == 2 { print $9; exit }' "$ZLIB_FUNCTION_GAP_TSV")"
    zlib_function_gap_positive_sum_bytes="$(awk 'NR > 1 { d = $8 + 0; if (d > 0) sum += d } END { print sum + 0 }' "$ZLIB_FUNCTION_GAP_TSV")"
  else
    zlib_function_gap_entry_count="0"
    zlib_function_gap_top_abs_bytes="NA"
    zlib_function_gap_positive_sum_bytes="NA"
  fi

  moon run src/main --target js -- block-sizes "$zlib_rel" 20 > "$tmp_zlib_block_before" 2>&1 || true
  moon run src/main --target js -- block-sizes "$tmp_zlib_wite" 20 > "$tmp_zlib_block_wite" 2>&1 || true
  if is_uint "$zlib_gap_wasm_opt_after_bytes"; then
    moon run src/main --target js -- block-sizes "$tmp_zlib_wasm_opt" 20 > "$tmp_zlib_block_wasm_opt" 2>&1 || true
  else
    echo "wasm-opt unavailable" > "$tmp_zlib_block_wasm_opt"
  fi

  {
    echo "# zlib Gap Report"
    echo
    echo "- file: $zlib_rel"
    echo "- wasm_opt_reference: $(if [[ "$HAS_WASM_OPT" -eq 1 ]]; then printf '`%s %s`' "$WASM_OPT_BIN" "${WASM_OPT_ARGS[*]}"; else echo "unavailable"; fi)"
    echo
    echo "## Summary"
    echo
    echo "| metric | before | wite(-O1) | wasm-opt(-Oz) |"
    echo "| --- | ---: | ---: | ---: |"
    echo "| module_bytes | $zlib_gap_before_bytes | $zlib_gap_wite_after_bytes | $zlib_gap_wasm_opt_after_bytes |"
    echo "| reduction_ratio_pct | - | $zlib_gap_wite_ratio_pct | $zlib_gap_wasm_opt_ratio_pct |"
    echo "| code_body_bytes | $zlib_gap_code_before_bytes | $zlib_gap_code_wite_bytes | $zlib_gap_code_wasm_opt_bytes |"
    echo "| block_instruction_bytes | $zlib_gap_block_before_bytes | $zlib_gap_block_wite_bytes | $zlib_gap_block_wasm_opt_bytes |"
    echo
    echo "- gap_to_wasm_opt_bytes: $zlib_gap_to_wasm_opt_bytes"
    echo "- gap_to_wasm_opt_ratio_pct: $zlib_gap_to_wasm_opt_ratio_pct"
    echo "- function_gap_entry_count: $zlib_function_gap_entry_count"
    echo "- function_gap_top_abs_bytes: $zlib_function_gap_top_abs_bytes"
    echo "- function_gap_positive_sum_bytes: $zlib_function_gap_positive_sum_bytes"
    echo
    echo "## Section Delta (before -> wite)"
    echo
    if [[ -s "$tmp_zlib_section_delta_wite" ]]; then
      echo "| section | before_bytes | after_bytes | gain_bytes | gain_ratio_pct |"
      echo "| --- | ---: | ---: | ---: | ---: |"
      awk -F '\t' '{ printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }' "$tmp_zlib_section_delta_wite"
    else
      echo "(unavailable)"
    fi
    echo
    echo "## Section Delta (before -> wasm-opt)"
    echo
    if [[ -s "$tmp_zlib_section_delta_wasm_opt" ]]; then
      echo "| section | before_bytes | after_bytes | gain_bytes | gain_ratio_pct |"
      echo "| --- | ---: | ---: | ---: | ---: |"
      awk -F '\t' '{ printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }' "$tmp_zlib_section_delta_wasm_opt"
    else
      echo "(unavailable)"
    fi
    echo
    echo "## Function Gap (wite -> wasm-opt)"
    echo
    if [[ "$(awk 'END { print NR }' "$ZLIB_FUNCTION_GAP_TSV")" -gt 1 ]]; then
      echo "| rank | kind | key | left_idx | right_idx | left_body_bytes | right_body_bytes | delta_bytes | abs_gap_bytes | left_exports | right_exports |"
      echo "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |"
      awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11 }' "$ZLIB_FUNCTION_GAP_TSV"
    else
      echo "(unavailable)"
    fi
    echo
    echo "## Top Functions Snapshot"
    echo
    echo "### before"
    echo '```text'
    cat "$tmp_zlib_fn_before"
    echo '```'
    echo
    echo "### wite(-O1)"
    echo '```text'
    cat "$tmp_zlib_fn_wite"
    echo '```'
    echo
    echo "### wasm-opt(-Oz)"
    echo '```text'
    cat "$tmp_zlib_fn_wasm_opt"
    echo '```'
    echo
    echo "## Top Blocks Snapshot"
    echo
    echo "### before"
    echo '```text'
    cat "$tmp_zlib_block_before"
    echo '```'
    echo
    echo "### wite(-O1)"
    echo '```text'
    cat "$tmp_zlib_block_wite"
    echo '```'
    echo
    echo "### wasm-opt(-Oz)"
    echo '```text'
    cat "$tmp_zlib_block_wasm_opt"
    echo '```'
  } > "$ZLIB_GAP_MD"
}

echo -e "file\tbefore_bytes\twite_after_bytes\twite_reduction_ratio_pct\twasm_opt_after_bytes\twasm_opt_reduction_ratio_pct\tgap_to_wasm_opt_bytes\tgap_to_wasm_opt_ratio_pct\twasm_opt_status" > "$SIZE_TSV"
echo -e "file\tbefore_bytes\tpre_dce_after_bytes\tpost_dce_after_bytes\tpost_rume_after_bytes\tdce_gain_bytes\trume_gain_bytes\ttotal_gain_bytes\tdirectize_calls\tstatus" > "$DIRECTIZE_CHAIN_TSV"
echo -e "file\tbefore_bytes\tafter_bytes\tsection_gain_bytes\tsection_gain_ratio_pct\tfunction_before_bytes\tfunction_after_bytes\tfunction_gain_bytes\tfunction_gain_ratio_pct\tblock_before_instruction_bytes\tblock_after_instruction_bytes\tblock_gain_bytes\tblock_gain_ratio_pct\theat_section\theat_function\theat_block\tstatus" > "$HEATMAP_TSV"
echo -e "file\tbefore_bytes\tstrip_after_bytes\tcode_after_bytes\tdce_after_bytes\trume_after_bytes\tstrip_gain_bytes\tcode_gain_bytes\tdce_gain_bytes\trume_gain_bytes\ttotal_gain_bytes\tstatus" > "$PASS_WATERFALL_TSV"

total_before=0
total_after=0
core_file_count=0
primary_gap_before=0
primary_gap_after=0
primary_gap_file_count=0

wasm_opt_total_before=0
wasm_opt_total_wite_after=0
wasm_opt_total_after=0
wasm_opt_success_files=0
primary_gap_wasm_opt_total_before=0
primary_gap_wasm_opt_total_wite_after=0
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

heatmap_total_section_gain=0
heatmap_total_function_before=0
heatmap_total_function_after=0
heatmap_total_function_gain=0
heatmap_total_block_before=0
heatmap_total_block_after=0
heatmap_total_block_gain=0
heatmap_success_files=0

waterfall_total_before=0
waterfall_total_strip_after=0
waterfall_total_code_after=0
waterfall_total_dce_after=0
waterfall_total_rume_after=0
waterfall_total_strip_gain=0
waterfall_total_code_gain=0
waterfall_total_dce_gain=0
waterfall_total_rume_gain=0
waterfall_total_gain=0
waterfall_success_files=0

zlib_gap_before_bytes="NA"
zlib_gap_wite_after_bytes="NA"
zlib_gap_wasm_opt_after_bytes="NA"
zlib_gap_wite_ratio_pct="NA"
zlib_gap_wasm_opt_ratio_pct="NA"
zlib_gap_to_wasm_opt_bytes="NA"
zlib_gap_to_wasm_opt_ratio_pct="NA"
zlib_gap_code_before_bytes="NA"
zlib_gap_code_wite_bytes="NA"
zlib_gap_code_wasm_opt_bytes="NA"
zlib_gap_block_before_bytes="NA"
zlib_gap_block_wite_bytes="NA"
zlib_gap_block_wasm_opt_bytes="NA"
zlib_gap_code_section_to_wasm_opt_bytes="NA"
zlib_gap_function_section_to_wasm_opt_bytes="NA"
zlib_gap_type_section_to_wasm_opt_bytes="NA"
zlib_function_gap_top_abs_bytes="NA"
zlib_function_gap_positive_sum_bytes="NA"
zlib_function_gap_entry_count="0"

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
  if ! o1_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" -O1 --verbose 2>&1)"; then
    echo "failed to optimize with -O1: $rel" >&2
    exit 1
  fi
  record_no_change_reasons "$o1_output" "o1" "$rel"
  line="$(extract_optimized_line "$o1_output")"
  if [[ -z "${line:-}" ]]; then
    echo "failed to parse optimize output: $rel" >&2
    exit 1
  fi

  if ! parsed_before_after="$(parse_optimized_before_after "$line")"; then
    echo "invalid optimize output: $line" >&2
    exit 1
  fi
  read -r before after <<< "$parsed_before_after"

  ratio_pct="$(ratio_pct "$before" "$after")"

  strip_after="NA"
  pre_dce_before="NA"
  pre_dce_after="NA"
  post_dce_after="NA"
  post_rume_after="NA"
  dce_gain_bytes="NA"
  rume_gain_bytes="NA"
  total_gain_bytes="NA"
  directize_calls="NA"
  directize_status="ok"
  waterfall_status="ok"
  strip_gain_bytes="NA"
  code_gain_bytes="NA"
  waterfall_total_gain_bytes="NA"

  if strip_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=1 --no-peephole --no-vacuum --no-merge-blocks --no-remove-unused-brs --verbose 2>&1)"; then
    record_no_change_reasons "$strip_output" "strip" "$rel"
    strip_line="$(extract_optimized_line "$strip_output")"
    if [[ -n "${strip_line:-}" ]] && parsed_before_after="$(parse_optimized_before_after "$strip_line")"; then
      read -r strip_before strip_after <<< "$parsed_before_after"
      if [[ "$strip_before" != "$before" ]]; then
        waterfall_status="strip-before-mismatch"
      fi
    else
      waterfall_status="strip-parse-error"
      strip_after="NA"
    fi
  else
    waterfall_status="strip-error"
  fi

  if pre_dce_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=2 --verbose 2>&1)"; then
    record_no_change_reasons "$pre_dce_output" "code" "$rel"
    pre_dce_line="$(extract_optimized_line "$pre_dce_output")"
    if [[ -n "${pre_dce_line:-}" ]] && parsed_before_after="$(parse_optimized_before_after "$pre_dce_line")"; then
      read -r pre_dce_before pre_dce_after <<< "$parsed_before_after"
    else
      directize_status="pre-dce-parse-error"
      waterfall_status="code-parse-error"
      pre_dce_before="NA"
      pre_dce_after="NA"
    fi
  else
    directize_status="pre-dce-error"
    waterfall_status="code-error"
  fi

  if [[ "$directize_status" == "ok" ]]; then
    if post_dce_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=2 --dce-apply --dfe-apply --msf-apply --verbose 2>&1)"; then
      record_no_change_reasons "$post_dce_output" "dce" "$rel"
      post_dce_line="$(extract_optimized_line "$post_dce_output")"
      if [[ -n "${post_dce_line:-}" ]] && parsed_before_after="$(parse_optimized_before_after "$post_dce_line")"; then
        read -r post_dce_before post_dce_after <<< "$parsed_before_after"
      else
        directize_status="post-dce-parse-error"
        waterfall_status="dce-parse-error"
        post_dce_after="NA"
      fi
    else
      directize_status="post-dce-error"
      waterfall_status="dce-error"
    fi
  fi

  if [[ "$directize_status" == "ok" ]]; then
    if post_rume_output="$(moon run src/main --target js -- optimize "$rel" "$tmp_wasm" --strip-debug --strip-dwarf --strip-target-features --rounds=2 --dce-apply --dfe-apply --msf-apply --rume-apply --verbose 2>&1)"; then
      record_no_change_reasons "$post_rume_output" "rume" "$rel"
      post_rume_line="$(extract_optimized_line "$post_rume_output")"
      if [[ -n "${post_rume_line:-}" ]] && parsed_before_after="$(parse_optimized_before_after "$post_rume_line")"; then
        read -r post_rume_before post_rume_after <<< "$parsed_before_after"
      else
        directize_status="post-rume-parse-error"
        waterfall_status="rume-parse-error"
        post_rume_after="NA"
      fi
    else
      directize_status="post-rume-error"
      waterfall_status="rume-error"
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

  if [[ "$waterfall_status" == "ok" && "$strip_after" =~ ^[0-9]+$ && "$pre_dce_after" =~ ^[0-9]+$ && "$post_dce_after" =~ ^[0-9]+$ && "$post_rume_after" =~ ^[0-9]+$ ]]; then
    strip_gain_bytes=$((before - strip_after))
    code_gain_bytes=$((strip_after - pre_dce_after))
    waterfall_dce_gain_bytes=$((pre_dce_after - post_dce_after))
    waterfall_rume_gain_bytes=$((post_dce_after - post_rume_after))
    waterfall_total_gain_bytes=$((before - post_rume_after))
  else
    if [[ "$waterfall_status" == "ok" ]]; then
      waterfall_status="waterfall-parse-error"
    fi
    waterfall_dce_gain_bytes="NA"
    waterfall_rume_gain_bytes="NA"
  fi

  function_before_bytes="$(parse_profile_code_body_bytes "$rel" || true)"
  function_after_bytes="$(parse_profile_code_body_bytes "$tmp_wasm" || true)"
  block_before_instruction_bytes="$(parse_block_total_instruction_bytes "$rel" || true)"
  block_after_instruction_bytes="$(parse_block_total_instruction_bytes "$tmp_wasm" || true)"
  heat_status="ok"
  section_gain_bytes=$((before - after))
  section_gain_ratio_pct="$(gain_ratio_pct "$before" "$section_gain_bytes")"
  function_gain_bytes="NA"
  function_gain_ratio_pct="NA"
  block_gain_bytes="NA"
  block_gain_ratio_pct="NA"
  heat_section="$(heat_bar_from_ratio_pct "$section_gain_ratio_pct")"
  heat_function="NA"
  heat_block="NA"

  if [[ ! "$function_before_bytes" =~ ^[0-9]+$ || ! "$function_after_bytes" =~ ^[0-9]+$ ]]; then
    heat_status="profile-parse-error"
  else
    function_gain_bytes=$((function_before_bytes - function_after_bytes))
    function_gain_ratio_pct="$(gain_ratio_pct "$function_before_bytes" "$function_gain_bytes")"
    heat_function="$(heat_bar_from_ratio_pct "$function_gain_ratio_pct")"
  fi

  if [[ ! "$block_before_instruction_bytes" =~ ^[0-9]+$ || ! "$block_after_instruction_bytes" =~ ^[0-9]+$ ]]; then
    if [[ "$heat_status" == "ok" ]]; then
      heat_status="block-parse-error"
    fi
  else
    block_gain_bytes=$((block_before_instruction_bytes - block_after_instruction_bytes))
    block_gain_ratio_pct="$(gain_ratio_pct "$block_before_instruction_bytes" "$block_gain_bytes")"
    heat_block="$(heat_bar_from_ratio_pct "$block_gain_ratio_pct")"
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
        wasm_opt_total_wite_after=$((wasm_opt_total_wite_after + after))
        wasm_opt_total_after=$((wasm_opt_total_after + wasm_opt_after))
        wasm_opt_success_files=$((wasm_opt_success_files + 1))
        if [[ "$primary_gap_included" -eq 1 ]]; then
          primary_gap_wasm_opt_total_before=$((primary_gap_wasm_opt_total_before + before))
          primary_gap_wasm_opt_total_wite_after=$((primary_gap_wasm_opt_total_wite_after + after))
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
  echo -e "$rel\t$before\t$after\t$section_gain_bytes\t$section_gain_ratio_pct\t$function_before_bytes\t$function_after_bytes\t$function_gain_bytes\t$function_gain_ratio_pct\t$block_before_instruction_bytes\t$block_after_instruction_bytes\t$block_gain_bytes\t$block_gain_ratio_pct\t$heat_section\t$heat_function\t$heat_block\t$heat_status" >> "$HEATMAP_TSV"
  echo -e "$rel\t$before\t$strip_after\t$pre_dce_after\t$post_dce_after\t$post_rume_after\t$strip_gain_bytes\t$code_gain_bytes\t$waterfall_dce_gain_bytes\t$waterfall_rume_gain_bytes\t$waterfall_total_gain_bytes\t$waterfall_status" >> "$PASS_WATERFALL_TSV"

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
  if [[ "$heat_status" == "ok" ]]; then
    heatmap_total_section_gain=$((heatmap_total_section_gain + section_gain_bytes))
    heatmap_total_function_before=$((heatmap_total_function_before + function_before_bytes))
    heatmap_total_function_after=$((heatmap_total_function_after + function_after_bytes))
    heatmap_total_function_gain=$((heatmap_total_function_gain + function_gain_bytes))
    heatmap_total_block_before=$((heatmap_total_block_before + block_before_instruction_bytes))
    heatmap_total_block_after=$((heatmap_total_block_after + block_after_instruction_bytes))
    heatmap_total_block_gain=$((heatmap_total_block_gain + block_gain_bytes))
    heatmap_success_files=$((heatmap_success_files + 1))
  fi
  if [[ "$waterfall_status" == "ok" ]]; then
    waterfall_total_before=$((waterfall_total_before + before))
    waterfall_total_strip_after=$((waterfall_total_strip_after + strip_after))
    waterfall_total_code_after=$((waterfall_total_code_after + pre_dce_after))
    waterfall_total_dce_after=$((waterfall_total_dce_after + post_dce_after))
    waterfall_total_rume_after=$((waterfall_total_rume_after + post_rume_after))
    waterfall_total_strip_gain=$((waterfall_total_strip_gain + strip_gain_bytes))
    waterfall_total_code_gain=$((waterfall_total_code_gain + code_gain_bytes))
    waterfall_total_dce_gain=$((waterfall_total_dce_gain + waterfall_dce_gain_bytes))
    waterfall_total_rume_gain=$((waterfall_total_rume_gain + waterfall_rume_gain_bytes))
    waterfall_total_gain=$((waterfall_total_gain + waterfall_total_gain_bytes))
    waterfall_success_files=$((waterfall_success_files + 1))
  fi
done < <(core_optimize_corpus_files)

total_ratio_pct="$(ratio_pct "$total_before" "$total_after")"
wasm_opt_total_ratio_pct="NA"
wasm_opt_total_wite_ratio_pct="NA"
wasm_opt_total_gap_bytes="NA"
wasm_opt_total_gap_ratio_pct="NA"
primary_gap_ratio_pct="$(ratio_pct "$primary_gap_before" "$primary_gap_after")"
primary_gap_wasm_opt_ratio_pct="NA"
primary_gap_wasm_opt_wite_ratio_pct="NA"
primary_gap_to_wasm_opt_bytes="NA"
primary_gap_to_wasm_opt_ratio_pct="NA"
if [[ "$wasm_opt_success_files" -gt 0 ]]; then
  wasm_opt_total_ratio_pct="$(ratio_pct "$wasm_opt_total_before" "$wasm_opt_total_after")"
  wasm_opt_total_wite_ratio_pct="$(ratio_pct "$wasm_opt_total_before" "$wasm_opt_total_wite_after")"
  wasm_opt_total_gap_bytes=$((wasm_opt_total_wite_after - wasm_opt_total_after))
  wasm_opt_total_gap_ratio_pct="$(awk -v w="$wasm_opt_total_wite_ratio_pct" -v o="$wasm_opt_total_ratio_pct" 'BEGIN { printf "%.4f", (w - o) }')"
fi
if [[ "$primary_gap_wasm_opt_success_files" -gt 0 ]]; then
  primary_gap_wasm_opt_ratio_pct="$(ratio_pct "$primary_gap_wasm_opt_total_before" "$primary_gap_wasm_opt_total_after")"
  primary_gap_wasm_opt_wite_ratio_pct="$(ratio_pct "$primary_gap_wasm_opt_total_before" "$primary_gap_wasm_opt_total_wite_after")"
  primary_gap_to_wasm_opt_bytes=$((primary_gap_wasm_opt_total_wite_after - primary_gap_wasm_opt_total_after))
  primary_gap_to_wasm_opt_ratio_pct="$(awk -v w="$primary_gap_wasm_opt_wite_ratio_pct" -v o="$primary_gap_wasm_opt_ratio_pct" 'BEGIN { printf "%.4f", (w - o) }')"
fi

directize_total_post_rume_reduction_ratio_pct="$(ratio_pct "$directize_total_before" "$directize_total_post_rume_after")"
directize_total_dce_gain_ratio_pct="$(gain_ratio_pct "$directize_total_pre_dce_after" "$directize_total_dce_gain")"
directize_total_rume_gain_ratio_pct="$(gain_ratio_pct "$directize_total_post_dce_after" "$directize_total_rume_gain")"
directize_total_gain_ratio_pct="$(gain_ratio_pct "$directize_total_pre_dce_after" "$directize_total_gain")"

heatmap_total_section_gain_ratio_pct="$(gain_ratio_pct "$total_before" "$heatmap_total_section_gain")"
heatmap_total_function_gain_ratio_pct="$(gain_ratio_pct "$heatmap_total_function_before" "$heatmap_total_function_gain")"
heatmap_total_block_gain_ratio_pct="$(gain_ratio_pct "$heatmap_total_block_before" "$heatmap_total_block_gain")"
heatmap_total_section_heat="$(heat_bar_from_ratio_pct "$heatmap_total_section_gain_ratio_pct")"
heatmap_total_function_heat="$(heat_bar_from_ratio_pct "$heatmap_total_function_gain_ratio_pct")"
heatmap_total_block_heat="$(heat_bar_from_ratio_pct "$heatmap_total_block_gain_ratio_pct")"

waterfall_total_strip_gain_ratio_pct="$(gain_ratio_pct "$waterfall_total_before" "$waterfall_total_strip_gain")"
waterfall_total_code_gain_ratio_pct="$(gain_ratio_pct "$waterfall_total_strip_after" "$waterfall_total_code_gain")"
waterfall_total_dce_gain_ratio_pct="$(gain_ratio_pct "$waterfall_total_code_after" "$waterfall_total_dce_gain")"
waterfall_total_rume_gain_ratio_pct="$(gain_ratio_pct "$waterfall_total_dce_after" "$waterfall_total_rume_gain")"
waterfall_total_gain_ratio_pct="$(gain_ratio_pct "$waterfall_total_before" "$waterfall_total_gain")"

echo -e "stage\tcategory\treason\tcount\tsample_files" > "$NO_CHANGE_REASON_TSV"
if [[ "${#NO_CHANGE_REASON_COUNT[@]}" -gt 0 ]]; then
  for key in "${!NO_CHANGE_REASON_COUNT[@]}"; do
    IFS='|' read -r stage category reason <<< "$key"
    count="${NO_CHANGE_REASON_COUNT[$key]}"
    sample_files="${NO_CHANGE_REASON_EXAMPLE[$key]:-}"
    echo -e "$stage\t$category\t$reason\t$count\t$sample_files"
  done | sort -t $'\t' -k4,4nr -k1,1 -k2,2 >> "$NO_CHANGE_REASON_TSV"
fi

generate_no_change_triage
generate_zlib_gap_report
generate_migration_top3_report

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

echo -e "file\tmodule_bytes\tcode_body_bytes\timport_count\texport_count\tlocal_function_count\tcallgraph_imported_function_count\tcallgraph_local_function_count\treachable_function_count\tdead_function_count\thas_indirect_calls\tpartial\treachable_body_bytes\tdead_body_bytes\tstatus" > "$ANALYZE_ONLY_TSV"

analyze_only_file_count=0
analyze_only_success_files=0
analyze_only_total_module_bytes=0
analyze_only_total_code_body_bytes=0

while IFS= read -r file; do
  analyze_only_file_count=$((analyze_only_file_count + 1))
  rel="${file#$ROOT_DIR/}"

  module_bytes="NA"
  code_body_bytes="NA"
  import_count="NA"
  export_count="NA"
  local_function_count="NA"
  callgraph_imported_function_count="NA"
  callgraph_local_function_count="NA"
  reachable_function_count="NA"
  dead_function_count="NA"
  has_indirect_calls="NA"
  partial="NA"
  reachable_body_bytes="NA"
  dead_body_bytes="NA"
  status="ok"

  if profile_output="$(moon run src/main --target js -- profile "$rel" 2>&1)"; then
    module_bytes="$(awk -F ': ' '/^  total_bytes: / { print $2; exit }' <<< "$profile_output")"
    code_body_bytes="$(awk -F ': ' '/^  code_body_bytes: / { print $2; exit }' <<< "$profile_output")"
    import_count="$(awk -F ': ' '/^  import_count: / { print $2; exit }' <<< "$profile_output")"
    export_count="$(awk -F ': ' '/^  export_count: / { print $2; exit }' <<< "$profile_output")"
    local_function_count="$(awk -F ': ' '/^  function_count: / { print $2; exit }' <<< "$profile_output")"
  else
    status="profile-error"
  fi

  if [[ "$status" == "ok" ]]; then
    if analyze_output="$(moon run src/main --target js -- analyze "$rel" 2>&1)"; then
      callgraph_line="$(awk '/^  functions: imported=/ { print; exit }' <<< "$analyze_output")"
      if [[ "$callgraph_line" =~ imported=([0-9]+)[[:space:]]+local=([0-9]+)[[:space:]]+reachable=([0-9]+)[[:space:]]+dead=([0-9]+) ]]; then
        callgraph_imported_function_count="${BASH_REMATCH[1]}"
        callgraph_local_function_count="${BASH_REMATCH[2]}"
        reachable_function_count="${BASH_REMATCH[3]}"
        dead_function_count="${BASH_REMATCH[4]}"
      else
        status="analyze-parse-error"
      fi
      has_indirect_calls="$(awk -F ': ' '/^  has_indirect_calls: / { print $2; exit }' <<< "$analyze_output")"
      partial="$(awk -F ': ' '/^  partial: / { print $2; exit }' <<< "$analyze_output")"
      reachable_body_bytes="$(awk -F ': ' '/^  reachable_body_bytes: / { print $2; exit }' <<< "$analyze_output" | sed -E 's/[[:space:]].*$//')"
      dead_body_bytes="$(awk -F ': ' '/^  dead_body_bytes: / { print $2; exit }' <<< "$analyze_output" | sed -E 's/[[:space:]].*$//')"
      if [[ ! "$has_indirect_calls" =~ ^(true|false)$ || ! "$partial" =~ ^(true|false)$ || ! "$reachable_body_bytes" =~ ^[0-9]+$ || ! "$dead_body_bytes" =~ ^[0-9]+$ ]]; then
        status="analyze-parse-error"
      fi
    else
      status="analyze-error"
    fi
  fi

  if [[ "$status" == "ok" && "$module_bytes" =~ ^[0-9]+$ && "$code_body_bytes" =~ ^[0-9]+$ ]]; then
    analyze_only_success_files=$((analyze_only_success_files + 1))
    analyze_only_total_module_bytes=$((analyze_only_total_module_bytes + module_bytes))
    analyze_only_total_code_body_bytes=$((analyze_only_total_code_body_bytes + code_body_bytes))
  fi

  echo -e "$rel\t$module_bytes\t$code_body_bytes\t$import_count\t$export_count\t$local_function_count\t$callgraph_imported_function_count\t$callgraph_local_function_count\t$reachable_function_count\t$dead_function_count\t$has_indirect_calls\t$partial\t$reachable_body_bytes\t$dead_body_bytes\t$status" >> "$ANALYZE_ONLY_TSV"
done < <(core_analyze_only_corpus_files)

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
  echo "- zlib_gap_report: \`bench/kpi/zlib_gap.md\`"
  echo "- zlib_gap_before_bytes: $zlib_gap_before_bytes"
  echo "- zlib_gap_wite_after_bytes: $zlib_gap_wite_after_bytes"
  echo "- zlib_gap_wasm_opt_after_bytes: $zlib_gap_wasm_opt_after_bytes"
  echo "- zlib_gap_to_wasm_opt_bytes: $zlib_gap_to_wasm_opt_bytes"
  echo "- zlib_gap_to_wasm_opt_ratio_pct: $zlib_gap_to_wasm_opt_ratio_pct"
  echo "- zlib_function_gap_report: \`bench/kpi/zlib_function_gap.tsv\`"
  echo "- zlib_function_gap_entry_count: $zlib_function_gap_entry_count"
  echo "- zlib_function_gap_top_abs_bytes: $zlib_function_gap_top_abs_bytes"
  echo "- zlib_function_gap_positive_sum_bytes: $zlib_function_gap_positive_sum_bytes"
  echo
  echo "| file | before_bytes | wite_after_bytes | wite_reduction_ratio_pct | wasm_opt_after_bytes | wasm_opt_reduction_ratio_pct | gap_to_wasm_opt_bytes | gap_to_wasm_opt_ratio_pct | wasm_opt_status |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9 }' "$SIZE_TSV"
  echo
  echo "## Analyze-only Core Corpus"
  echo
  echo "- target_scope: bench/corpus/core-analyze/**/*.wasm"
  echo "- success_files: $analyze_only_success_files/$analyze_only_file_count"
  echo "- total_module_bytes: $analyze_only_total_module_bytes"
  echo "- total_code_body_bytes: $analyze_only_total_code_body_bytes"
  echo
  echo "| file | module_bytes | code_body_bytes | import_count | export_count | local_function_count | callgraph_imported_function_count | callgraph_local_function_count | reachable_function_count | dead_function_count | has_indirect_calls | partial | reachable_body_bytes | dead_body_bytes | status |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15 }' "$ANALYZE_ONLY_TSV"
  echo
  echo "## Function Gap to wasm-opt (A6)"
  echo
  echo "- source: \`bench/kpi/zlib_function_gap.tsv\` (left=wite -O1, right=wasm-opt -Oz, zlib)"
  echo "- entry_count: $zlib_function_gap_entry_count"
  echo "- top_abs_gap_bytes: $zlib_function_gap_top_abs_bytes"
  echo "- positive_delta_sum_bytes: $zlib_function_gap_positive_sum_bytes"
  echo
  if [[ "$(awk 'END { print NR }' "$ZLIB_FUNCTION_GAP_TSV")" -gt 1 ]]; then
    echo "| rank | kind | key | left_idx | right_idx | left_body_bytes | right_body_bytes | delta_bytes | abs_gap_bytes | left_exports | right_exports |"
    echo "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |"
    awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11 }' "$ZLIB_FUNCTION_GAP_TSV"
  else
    echo "(unavailable)"
  fi
  echo
  echo "## Before/After Diff Heatmap (section -> function -> block)"
  echo
  echo "- success_files: $heatmap_success_files/$core_file_count"
  echo "- total_section_gain_bytes: $heatmap_total_section_gain"
  echo "- total_section_gain_ratio_pct: $heatmap_total_section_gain_ratio_pct"
  echo "- total_section_heat: $heatmap_total_section_heat"
  echo "- total_function_gain_bytes: $heatmap_total_function_gain"
  echo "- total_function_gain_ratio_pct: $heatmap_total_function_gain_ratio_pct"
  echo "- total_function_heat: $heatmap_total_function_heat"
  echo "- total_block_gain_bytes: $heatmap_total_block_gain"
  echo "- total_block_gain_ratio_pct: $heatmap_total_block_gain_ratio_pct"
  echo "- total_block_heat: $heatmap_total_block_heat"
  echo
  echo "| file | section_gain_bytes | section_gain_ratio_pct | section_heat | function_gain_bytes | function_gain_ratio_pct | function_heat | block_gain_bytes | block_gain_ratio_pct | block_heat | status |"
  echo "| --- | ---: | ---: | --- | ---: | ---: | --- | ---: | ---: | --- | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $4, $5, $14, $8, $9, $15, $12, $13, $16, $17 }' "$HEATMAP_TSV"
  echo
  echo "## Pass Waterfall (priority 1 diagnostics)"
  echo
  echo "- stage_order: strip -> code -> dce -> rume"
  echo "- success_files: $waterfall_success_files/$core_file_count"
  echo "- total_strip_gain_bytes: $waterfall_total_strip_gain"
  echo "- total_strip_gain_ratio_pct: $waterfall_total_strip_gain_ratio_pct"
  echo "- total_code_gain_bytes: $waterfall_total_code_gain"
  echo "- total_code_gain_ratio_pct: $waterfall_total_code_gain_ratio_pct"
  echo "- total_dce_gain_bytes: $waterfall_total_dce_gain"
  echo "- total_dce_gain_ratio_pct: $waterfall_total_dce_gain_ratio_pct"
  echo "- total_rume_gain_bytes: $waterfall_total_rume_gain"
  echo "- total_rume_gain_ratio_pct: $waterfall_total_rume_gain_ratio_pct"
  echo "- total_gain_bytes: $waterfall_total_gain"
  echo "- total_gain_ratio_pct: $waterfall_total_gain_ratio_pct"
  echo
  echo "| file | before_bytes | strip_after_bytes | code_after_bytes | dce_after_bytes | rume_after_bytes | strip_gain_bytes | code_gain_bytes | dce_gain_bytes | rume_gain_bytes | total_gain_bytes | status |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12 }' "$PASS_WATERFALL_TSV"
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
  echo "## No-Change Reason Dashboard"
  echo
  echo "| stage | category | reason | count | sample_files |"
  echo "| --- | --- | --- | ---: | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }' "$NO_CHANGE_REASON_TSV"
  echo
  echo "## No-Change Triage (A2)"
  echo
  triage_in_scope_count="$(sum_reason_count_by_scope "in-scope")"
  triage_out_scope_count="$(sum_reason_count_by_scope "out-of-scope")"
  triage_unknown_count="$(sum_reason_count_by_scope "unknown")"
  echo "- triage_in_scope_count: $triage_in_scope_count"
  echo "- triage_out_of_scope_count: $triage_out_scope_count"
  echo "- triage_unknown_count: $triage_unknown_count"
  echo
  echo "| stage | category | count | scope | action | priority | estimate | todo_target | sample_files |"
  echo "| --- | --- | ---: | --- | --- | --- | --- | --- | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $4, $5, $6, $7, $8, $9, $10 }' "$NO_CHANGE_TRIAGE_TSV"
  echo
  echo "## wasm-opt Migration Top3 (A3)"
  echo
  echo "- source: pass waterfall + no-change triage + zlib section gap + zlib function gap"
  echo "- detail_report: \`bench/kpi/migration_top3.md\`"
  echo
  echo "| rank | candidate | focus | priority | estimate | score | evidence | todo_target |"
  echo "| ---: | --- | --- | --- | --- | ---: | --- | --- |"
  awk -F '\t' 'NR > 1 { printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6, $7, $8 }' "$MIGRATION_TOP3_TSV"
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
echo "  $HEATMAP_TSV"
echo "  $PASS_WATERFALL_TSV"
echo "  $DIRECTIZE_CHAIN_TSV"
echo "  $NO_CHANGE_REASON_TSV"
echo "  $NO_CHANGE_TRIAGE_TSV"
echo "  $MIGRATION_TOP3_TSV"
echo "  $MIGRATION_TOP3_MD"
echo "  $ZLIB_GAP_MD"
echo "  $ZLIB_FUNCTION_GAP_TSV"
echo "  $ANALYZE_ONLY_TSV"
echo "  $COMPONENT_DCE_TSV"
echo "  $RUNTIME_TSV"
echo "  $BENCH_RAW_LOG"

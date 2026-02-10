///|
pub(all) suberror WiteError {
  UnexpectedEof
  InvalidMagic
  UnsupportedVersion(String)
  InvalidFormat(String)
}

///|
fn wite_error_to_string(err : WiteError) -> String {
  match err {
    WiteError::UnexpectedEof => "unexpected eof"
    WiteError::InvalidMagic => "invalid wasm magic"
    WiteError::UnsupportedVersion(msg) => "unsupported version: " + msg
    WiteError::InvalidFormat(msg) => "invalid format: " + msg
  }
}

///|
pub fn error_to_string(err : WiteError) -> String {
  wite_error_to_string(err)
}

///|
pub(all) struct SectionSize {
  key : String
  section_id : UInt
  total_bytes : UInt
}

///|
pub(all) struct OptimizeConfig {
  strip_all_custom : Bool
  strip_name_section : Bool
  strip_producers_section : Bool
  strip_debug_sections : Bool
  strip_dwarf_sections : Bool
  strip_target_features_section : Bool
  keep_custom_sections : Array[String]
  pass_rounds : UInt
  enable_peephole : Bool
  peephole_remove_nop : Bool
  peephole_remove_const_drop : Bool
  enable_vacuum : Bool
  enable_merge_blocks : Bool
  enable_remove_unused_brs : Bool
  enable_dce : Bool
  enable_dfe : Bool
  enable_merge_similar_functions : Bool
  enable_remove_unused_module_elements : Bool
  closed_world : Bool
  closed_world_root_exports : Array[String]
  safe_mode : Bool
}

///|
pub fn OptimizeConfig::default() -> Self {
  {
    strip_all_custom: false,
    strip_name_section: true,
    strip_producers_section: true,
    strip_debug_sections: false,
    strip_dwarf_sections: false,
    strip_target_features_section: false,
    keep_custom_sections: [],
    pass_rounds: 1U,
    enable_peephole: true,
    peephole_remove_nop: true,
    peephole_remove_const_drop: true,
    enable_vacuum: true,
    enable_merge_blocks: true,
    enable_remove_unused_brs: true,
    enable_dce: false,
    enable_dfe: false,
    enable_merge_similar_functions: false,
    enable_remove_unused_module_elements: false,
    closed_world: false,
    closed_world_root_exports: [],
    safe_mode: false,
  }
}

///|
pub fn OptimizeConfig::aggressive() -> Self {
  {
    strip_all_custom: true,
    strip_name_section: true,
    strip_producers_section: true,
    strip_debug_sections: true,
    strip_dwarf_sections: true,
    strip_target_features_section: true,
    keep_custom_sections: [],
    pass_rounds: 1U,
    enable_peephole: true,
    peephole_remove_nop: true,
    peephole_remove_const_drop: true,
    enable_vacuum: true,
    enable_merge_blocks: true,
    enable_remove_unused_brs: true,
    enable_dce: false,
    enable_dfe: false,
    enable_merge_similar_functions: false,
    enable_remove_unused_module_elements: false,
    closed_world: false,
    closed_world_root_exports: [],
    safe_mode: false,
  }
}

///|
pub fn OptimizeConfig::o0() -> Self {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    keep_custom_sections=[],
    pass_rounds=1U,
    enable_peephole=false,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
}

///|
/// Shrink-first preset.
/// By default this strips debug/dwarf/target-features metadata in addition to code optimizations.
pub fn OptimizeConfig::o1() -> Self {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    keep_custom_sections=[],
    pass_rounds=2U,
    enable_peephole=true,
    peephole_remove_nop=true,
    peephole_remove_const_drop=true,
    enable_vacuum=true,
    enable_merge_blocks=true,
    enable_remove_unused_brs=true,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=true,
  )
}

///|
/// Throughput/balance presets.
/// By default these keep debug/custom metadata unless explicit strip flags are enabled by CLI.
pub fn OptimizeConfig::o2() -> Self {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    keep_custom_sections=[],
    pass_rounds=2U,
    enable_peephole=true,
    peephole_remove_nop=true,
    peephole_remove_const_drop=true,
    enable_vacuum=true,
    enable_merge_blocks=true,
    enable_remove_unused_brs=true,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
}

///|
pub fn OptimizeConfig::o3() -> Self {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    keep_custom_sections=[],
    pass_rounds=3U,
    enable_peephole=true,
    peephole_remove_nop=true,
    peephole_remove_const_drop=true,
    enable_vacuum=true,
    enable_merge_blocks=true,
    enable_remove_unused_brs=true,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=true,
  )
}

///|
pub fn OptimizeConfig::os() -> Self {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    keep_custom_sections=[],
    pass_rounds=3U,
    enable_peephole=true,
    peephole_remove_nop=true,
    peephole_remove_const_drop=true,
    enable_vacuum=true,
    enable_merge_blocks=true,
    enable_remove_unused_brs=true,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=true,
  )
}

///|
pub fn OptimizeConfig::oz() -> Self {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    keep_custom_sections=[],
    pass_rounds=8U,
    enable_peephole=true,
    peephole_remove_nop=true,
    peephole_remove_const_drop=true,
    enable_vacuum=true,
    enable_merge_blocks=true,
    enable_remove_unused_brs=true,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=true,
  )
}

///|
pub fn optimize_config_from_opt_level(level : String) -> OptimizeConfig? {
  match level {
    "-O0" => Some(OptimizeConfig::o0())
    "-O1" => Some(OptimizeConfig::o1())
    "-O" | "-O2" => Some(OptimizeConfig::o2())
    "-O3" | "-O4" => Some(OptimizeConfig::o3())
    "-Os" => Some(OptimizeConfig::os())
    "-Oz" => Some(OptimizeConfig::oz())
    _ => None
  }
}

///|
pub fn make_optimize_config(
  strip_all_custom? : Bool = false,
  strip_name_section? : Bool = true,
  strip_producers_section? : Bool = true,
  strip_debug_sections? : Bool = false,
  strip_dwarf_sections? : Bool = false,
  strip_target_features_section? : Bool = false,
  keep_custom_sections? : Array[String] = [],
  pass_rounds? : UInt = 1U,
  enable_peephole? : Bool = true,
  peephole_remove_nop? : Bool = true,
  peephole_remove_const_drop? : Bool = true,
  enable_vacuum? : Bool = true,
  enable_merge_blocks? : Bool = true,
  enable_remove_unused_brs? : Bool = true,
  enable_dce? : Bool = false,
  enable_dfe? : Bool = false,
  enable_merge_similar_functions? : Bool = false,
  enable_remove_unused_module_elements? : Bool = false,
  closed_world? : Bool = false,
  closed_world_root_exports? : Array[String] = [],
  safe_mode? : Bool = false,
) -> OptimizeConfig {
  {
    strip_all_custom,
    strip_name_section,
    strip_producers_section,
    strip_debug_sections,
    strip_dwarf_sections,
    strip_target_features_section,
    keep_custom_sections,
    pass_rounds,
    enable_peephole,
    peephole_remove_nop,
    peephole_remove_const_drop,
    enable_vacuum,
    enable_merge_blocks,
    enable_remove_unused_brs,
    enable_dce,
    enable_dfe,
    enable_merge_similar_functions,
    enable_remove_unused_module_elements,
    closed_world,
    closed_world_root_exports,
    safe_mode,
  }
}

///|
pub(all) struct OptimizeResult {
  bytes : Bytes
  before_size : UInt
  after_size : UInt
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
pub(all) struct ModuleProfile {
  total_bytes : UInt
  function_count : UInt
  import_count : UInt
  export_count : UInt
  code_body_count : UInt
  code_body_bytes : UInt
  sections : Array[SectionSize]
}

///|
pub(all) struct FunctionSize {
  function_index : UInt
  body_bytes : UInt
  name : String?
  export_names : Array[String]
}

///|
pub(all) struct FunctionGapEntry {
  match_kind : String
  match_key : String
  left_function_index : UInt?
  right_function_index : UInt?
  left_name : String?
  right_name : String?
  left_export_names : Array[String]
  right_export_names : Array[String]
  left_body_bytes : UInt
  right_body_bytes : UInt
  left_minus_right_bytes : Int
  abs_gap_bytes : UInt
}

///|
pub(all) struct FunctionGapReport {
  left_total_body_bytes : UInt
  right_total_body_bytes : UInt
  left_minus_right_total_bytes : Int
  unmatched_left_count : UInt
  unmatched_right_count : UInt
  entries : Array[FunctionGapEntry]
}

///|
pub(all) struct CodeBlockSize {
  function_index : UInt
  function_name : String?
  export_names : Array[String]
  block_index : UInt
  depth : UInt
  kind : String
  start_offset : UInt
  end_offset : UInt
  instruction_count : UInt
  total_bytes : UInt
}

///|
pub(all) struct CodeBlockSizeReport {
  partial : Bool
  function_count : UInt
  block_count : UInt
  total_body_bytes : UInt
  total_instruction_bytes : UInt
  blocks : Array[CodeBlockSize]
}

///|
pub(all) struct CustomSectionBreakdown {
  name : String
  count : UInt
  total_bytes : UInt
  payload_bytes : UInt
  content_bytes : UInt
}

///|
pub(all) struct OpcodeStat {
  key : String
  mnemonic : String
  count : UInt
  total_bytes : UInt
}

///|
pub(all) struct WasmBreakdownReport {
  total_bytes : UInt
  sections : Array[SectionSize]
  custom_sections : Array[CustomSectionBreakdown]
  imported_function_count : UInt
  local_function_count : UInt
  top_functions : Array[FunctionSize]
  block_count : UInt
  top_blocks : Array[CodeBlockSize]
  instruction_count : UInt
  instruction_bytes : UInt
  opcode_partial : Bool
  opcodes : Array[OpcodeStat]
  callgraph_partial : Bool
  has_indirect_calls : Bool
  reachable_body_bytes : UInt
  dead_body_bytes : UInt
}

///|
pub(all) struct CallGraphNode {
  function_index : UInt
  body_bytes : UInt
  name : String?
  export_names : Array[String]
  direct_callees : Array[UInt]
  reachable_from_roots : Bool
}

///|
pub(all) struct CallGraphReport {
  imported_function_count : UInt
  local_function_count : UInt
  roots : Array[UInt]
  has_indirect_calls : Bool
  partial : Bool
  reachable_body_bytes : UInt
  dead_body_bytes : UInt
  nodes : Array[CallGraphNode]
}

///|
pub(all) struct CallGraphSummary {
  imported_function_count : UInt
  local_function_count : UInt
  roots : Array[UInt]
  has_indirect_calls : Bool
  partial : Bool
  reachable_function_count : UInt
  dead_function_count : UInt
  reachable_body_bytes : UInt
  dead_body_bytes : UInt
}

///|
pub(all) struct HostCodeHint {
  kind : String
  function_index : UInt
  function_name : String?
  target_function_index : UInt
  target_function_name : String?
  export_names : Array[String]
  appended_i32_const_count : UInt
  dropped_param_count : UInt
}

///|
pub(all) struct HostGeneratedCodeReport {
  imported_function_count : UInt
  local_function_count : UInt
  param_forwarding_thunk_count : UInt
  const_forwarding_thunk_count : UInt
  signature_refinable_thunk_count : UInt
  directize_candidate_call_count : UInt
  dce_removable_function_count : UInt
  dce_removable_body_bytes : UInt
  dce_partial : Bool
  hints : Array[HostCodeHint]
}

///|
pub(all) struct FunctionSizeDiff {
  function_index : UInt
  before_body_bytes : UInt
  after_body_bytes : UInt
  gain_bytes : UInt
  regression_bytes : UInt
  before_name : String?
  after_name : String?
  export_names : Array[String]
}

///|
pub(all) struct OptimizeStageMetadata {
  stage : String
  before_size : UInt
  after_size : UInt
  gain_bytes : UInt
  regression_bytes : UInt
  function_gain_bytes : UInt
  function_regression_bytes : UInt
  function_diffs : Array[FunctionSizeDiff]
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
pub(all) struct OptimizeMetadataReport {
  before_size : UInt
  after_size : UInt
  total_gain_bytes : UInt
  total_regression_bytes : UInt
  stages : Array[OptimizeStageMetadata]
}

///|
pub(all) struct DceReport {
  roots : Array[UInt]
  partial : Bool
  removable_function_count : UInt
  removable_body_bytes : UInt
  removable_functions : Array[FunctionSize]
}

///|
pub(all) struct ComponentProfile {
  total_bytes : UInt
  import_count : UInt
  export_count : UInt
  core_module_count : UInt
  nested_component_count : UInt
  sections : Array[SectionSize]
  core_modules : Array[ModuleProfile]
}

///|
pub(all) struct ComponentFunctionSizeReport {
  module_index : UInt
  function_count : UInt
  total_body_bytes : UInt
  functions : Array[FunctionSize]
}

///|
pub(all) struct ComponentCallGraphReport {
  module_index : UInt
  graph : CallGraphReport
}

///|
pub(all) struct ComponentCoreOptimizeEntry {
  module_index : UInt
  before_bytes : UInt
  after_bytes : UInt
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
pub(all) struct ComponentCoreOptimizeReport {
  total_component_bytes : UInt
  core_module_count : UInt
  total_core_before_bytes : UInt
  total_core_after_bytes : UInt
  entries : Array[ComponentCoreOptimizeEntry]
}

///|
pub(all) struct ContractReport {
  component_imports : Array[String]
  component_exports : Array[String]
  wit_imports : Array[String]
  wit_exports : Array[String]
  missing_component_imports : Array[String]
  missing_component_exports : Array[String]
}

///|
pub(all) struct KeepReasonEntry {
  function_index : UInt
  name : String?
  export_names : Array[String]
  reasons : Array[String]
}

///|
pub(all) struct KeepReasonReport {
  partial : Bool
  entries : Array[KeepReasonEntry]
}

///|
pub(all) struct RetainPathEntry {
  function_index : UInt
  name : String?
  export_names : Array[String]
  body_bytes : UInt
  root_reasons : Array[String]
  path : Array[UInt]
}

///|
pub(all) struct RetainPathReport {
  partial : Bool
  roots : Array[UInt]
  entries : Array[RetainPathEntry]
}

///|
pub(all) struct HotnessSizeEntry {
  export_name : String
  function_index : UInt?
  function_name : String?
  body_bytes : UInt
  calls : UInt
  total_ns : UInt64
  average_ns : UInt64
  bucket : String
  unresolved_reason : String?
  unresolved_detail : String?
}

///|
pub(all) struct HotnessSizeBucket {
  bucket : String
  count : UInt
  body_bytes : UInt
  total_ns : UInt64
}

///|
pub(all) struct HotnessUnresolvedReasonCount {
  reason : String
  count : UInt
}

///|
pub(all) struct HotnessSizeMatrixReport {
  iterations : UInt
  instantiate_ns : UInt64
  hot_threshold_ns : UInt64
  large_threshold_bytes : UInt
  unresolved_exports : Array[String]
  unresolved_reason_counts : Array[HotnessUnresolvedReasonCount]
  buckets : Array[HotnessSizeBucket]
  entries : Array[HotnessSizeEntry]
}

///|
pub(all) struct ComponentRootPolicyReport {
  component_imports : Array[String]
  component_exports : Array[String]
  wit_imports : Array[String]
  wit_exports : Array[String]
  canonical_abi_roots : Array[String]
  root_name_candidates : Array[String]
}

///|
pub(all) struct RuntimeFunctionProfile {
  name : String
  calls : UInt
  total_ns : UInt64
  average_ns : UInt64
}

///|
pub(all) struct RuntimeUnresolvedExport {
  export_name : String
  reason : String
  detail : String
}

///|
pub(all) struct RuntimeProfileScenario {
  export_name : String
  args : Array[Int]
}

///|
pub fn make_runtime_profile_scenario(
  export_name : String,
  args? : Array[Int] = [],
) -> RuntimeProfileScenario {
  { export_name, args }
}

///|
pub(all) struct RuntimeProfile {
  instantiate_ns : UInt64
  iterations : UInt
  functions : Array[RuntimeFunctionProfile]
  skipped_exports : Array[String]
  unresolved_exports : Array[RuntimeUnresolvedExport]
}

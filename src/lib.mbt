///|
pub suberror WalyzeError {
  UnexpectedEof
  InvalidMagic
  UnsupportedVersion(String)
  InvalidFormat(String)
}

///|
fn walyze_error_to_string(err : WalyzeError) -> String {
  match err {
    WalyzeError::UnexpectedEof => "unexpected eof"
    WalyzeError::InvalidMagic => "invalid wasm magic"
    WalyzeError::UnsupportedVersion(msg) => "unsupported version: " + msg
    WalyzeError::InvalidFormat(msg) => "invalid format: " + msg
  }
}

///|
pub fn error_to_string(err : WalyzeError) -> String {
  walyze_error_to_string(err)
}

///|
pub struct SectionSize {
  key : String
  section_id : UInt
  total_bytes : UInt
}

///|
pub struct OptimizeConfig {
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
pub struct OptimizeResult {
  bytes : Bytes
  before_size : UInt
  after_size : UInt
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
pub struct ModuleProfile {
  total_bytes : UInt
  function_count : UInt
  import_count : UInt
  export_count : UInt
  code_body_count : UInt
  code_body_bytes : UInt
  sections : Array[SectionSize]
}

///|
pub struct FunctionSize {
  function_index : UInt
  body_bytes : UInt
  name : String?
  export_names : Array[String]
}

///|
pub struct CodeBlockSize {
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
pub struct CodeBlockSizeReport {
  partial : Bool
  function_count : UInt
  block_count : UInt
  total_body_bytes : UInt
  total_instruction_bytes : UInt
  blocks : Array[CodeBlockSize]
}

///|
pub struct CustomSectionBreakdown {
  name : String
  count : UInt
  total_bytes : UInt
  payload_bytes : UInt
  content_bytes : UInt
}

///|
pub struct OpcodeStat {
  key : String
  mnemonic : String
  count : UInt
  total_bytes : UInt
}

///|
pub struct WasmBreakdownReport {
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
pub struct CallGraphNode {
  function_index : UInt
  body_bytes : UInt
  name : String?
  export_names : Array[String]
  direct_callees : Array[UInt]
  reachable_from_roots : Bool
}

///|
pub struct CallGraphReport {
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
pub struct DceReport {
  roots : Array[UInt]
  partial : Bool
  removable_function_count : UInt
  removable_body_bytes : UInt
  removable_functions : Array[FunctionSize]
}

///|
pub struct ComponentProfile {
  total_bytes : UInt
  import_count : UInt
  export_count : UInt
  core_module_count : UInt
  nested_component_count : UInt
  sections : Array[SectionSize]
  core_modules : Array[ModuleProfile]
}

///|
pub struct ComponentFunctionSizeReport {
  module_index : UInt
  function_count : UInt
  total_body_bytes : UInt
  functions : Array[FunctionSize]
}

///|
pub struct ComponentCallGraphReport {
  module_index : UInt
  graph : CallGraphReport
}

///|
pub struct ComponentCoreOptimizeEntry {
  module_index : UInt
  before_bytes : UInt
  after_bytes : UInt
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
pub struct ComponentCoreOptimizeReport {
  total_component_bytes : UInt
  core_module_count : UInt
  total_core_before_bytes : UInt
  total_core_after_bytes : UInt
  entries : Array[ComponentCoreOptimizeEntry]
}

///|
pub struct ContractReport {
  component_imports : Array[String]
  component_exports : Array[String]
  wit_imports : Array[String]
  wit_exports : Array[String]
  missing_component_imports : Array[String]
  missing_component_exports : Array[String]
}

///|
pub struct KeepReasonEntry {
  function_index : UInt
  name : String?
  export_names : Array[String]
  reasons : Array[String]
}

///|
pub struct KeepReasonReport {
  partial : Bool
  entries : Array[KeepReasonEntry]
}

///|
pub struct ComponentRootPolicyReport {
  component_imports : Array[String]
  component_exports : Array[String]
  wit_imports : Array[String]
  wit_exports : Array[String]
  canonical_abi_roots : Array[String]
  root_name_candidates : Array[String]
}

///|
pub struct RuntimeFunctionProfile {
  name : String
  calls : UInt
  total_ns : UInt64
  average_ns : UInt64
}

///|
pub struct RuntimeProfile {
  instantiate_ns : UInt64
  iterations : UInt
  functions : Array[RuntimeFunctionProfile]
  skipped_exports : Array[String]
}

///|
priv struct Cursor {
  bytes : Bytes
  mut pos : Int
}

///|
fn Cursor::new(bytes : Bytes) -> Self {
  { bytes, pos: 0 }
}

///|
fn Cursor::eof(self : Cursor) -> Bool {
  self.pos >= self.bytes.length()
}

///|
fn Cursor::get_pos(self : Cursor) -> Int {
  self.pos
}

///|
fn Cursor::set_pos(self : Cursor, pos : Int) -> Unit {
  self.pos = pos
}

///|
fn Cursor::read_byte(self : Cursor) -> Byte raise WalyzeError {
  if self.pos < self.bytes.length() {
    let b = self.bytes.unsafe_get(self.pos)
    self.pos = self.pos + 1
    b
  } else {
    raise WalyzeError::UnexpectedEof
  }
}

///|
fn Cursor::read_u32_leb128(self : Cursor) -> UInt raise WalyzeError {
  fn read_loop(shift : Int, result : UInt) -> UInt raise WalyzeError {
    let byte = self.read_byte()
    if shift >= 28 && (byte & 0x80) != 0 {
      raise WalyzeError::InvalidFormat("LEB128 u32 overflow")
    }
    if shift >= 28 && byte > 0x0F {
      raise WalyzeError::InvalidFormat("LEB128 u32 value overflow")
    }
    let value = byte.land(0x7f).to_uint() << shift
    let next = result | value
    if (byte & 0x80) == 0 {
      next
    } else {
      read_loop(shift + 7, next)
    }
  }

  read_loop(0, 0U)
}

///|
fn Cursor::skip(self : Cursor, n : Int) -> Unit raise WalyzeError {
  if n < 0 {
    raise WalyzeError::InvalidFormat("negative skip")
  }
  if self.pos + n <= self.bytes.length() {
    self.pos = self.pos + n
  } else {
    raise WalyzeError::UnexpectedEof
  }
}

///|
priv struct RawSection {
  section_id : UInt
  section_start : Int
  payload_start : Int
  section_end : Int
  custom_name : String?
}

///|
fn ensure_core_header(bytes : Bytes) -> Unit raise WalyzeError {
  if bytes.length() < 8 {
    raise WalyzeError::UnexpectedEof
  }
  if bytes[0] != 0x00U.to_byte() ||
    bytes[1] != 0x61U.to_byte() ||
    bytes[2] != 0x73U.to_byte() ||
    bytes[3] != 0x6dU.to_byte() {
    raise WalyzeError::InvalidMagic
  }
  if bytes[4] != 0x01U.to_byte() ||
    bytes[5] != 0x00U.to_byte() ||
    bytes[6] != 0x00U.to_byte() ||
    bytes[7] != 0x00U.to_byte() {
    raise WalyzeError::UnsupportedVersion("expected core wasm version 1")
  }
}

///|
fn ensure_component_header(bytes : Bytes) -> Unit raise WalyzeError {
  if bytes.length() < 8 {
    raise WalyzeError::UnexpectedEof
  }
  if bytes[0] != 0x00U.to_byte() ||
    bytes[1] != 0x61U.to_byte() ||
    bytes[2] != 0x73U.to_byte() ||
    bytes[3] != 0x6dU.to_byte() {
    raise WalyzeError::InvalidMagic
  }
  if bytes[4] != 0x0dU.to_byte() ||
    bytes[5] != 0x00U.to_byte() ||
    bytes[6] != 0x01U.to_byte() ||
    bytes[7] != 0x00U.to_byte() {
    raise WalyzeError::UnsupportedVersion(
      "expected component wasm header 0d 00 01 00",
    )
  }
}

///|
fn parse_custom_section_name(payload : Bytes) -> String raise WalyzeError {
  let parser = Cursor::new(payload)
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WalyzeError::InvalidFormat("custom section name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len
  if end_ > payload.length() {
    raise WalyzeError::UnexpectedEof
  }
  let out : Array[Char] = []
  for b in payload[start:end_] {
    match b.to_int().to_char() {
      Some(ch) => out.push(ch)
      None => out.push('?')
    }
  }
  String::from_array(out[:])
}

///|
fn parse_sections_from(
  bytes : Bytes,
  start : Int,
) -> Array[RawSection] raise WalyzeError {
  let parser = Cursor::new(bytes)
  parser.set_pos(start)
  let sections : Array[RawSection] = []
  while not(parser.eof()) {
    let section_start = parser.get_pos()
    let section_id = parser.read_byte().to_uint()
    let payload_size_u = parser.read_u32_leb128()
    let payload_size = UInt::reinterpret_as_int(payload_size_u)
    if payload_size < 0 {
      raise WalyzeError::InvalidFormat("section size overflow")
    }
    let payload_start = parser.get_pos()
    let section_end = payload_start + payload_size
    if section_end > bytes.length() {
      raise WalyzeError::UnexpectedEof
    }
    let custom_name = if section_id == 0U {
      let payload = bytes[payload_start:section_end].to_bytes()
      Some(parse_custom_section_name(payload))
    } else {
      None
    }
    sections.push({
      section_id,
      section_start,
      payload_start,
      section_end,
      custom_name,
    })
    parser.set_pos(section_end)
  }
  sections
}

///|
fn parse_core_sections_raise(
  bytes : Bytes,
) -> Array[RawSection] raise WalyzeError {
  ensure_core_header(bytes)
  parse_sections_from(bytes, 8)
}

///|
fn parse_component_sections_raise(
  bytes : Bytes,
) -> Array[RawSection] raise WalyzeError {
  ensure_component_header(bytes)
  parse_sections_from(bytes, 8)
}

///|
fn section_total_bytes(section : RawSection) -> UInt {
  (section.section_end - section.section_start).reinterpret_as_uint()
}

///|
fn core_section_name(section_id : UInt) -> String {
  match section_id {
    1U => "type"
    2U => "import"
    3U => "function"
    4U => "table"
    5U => "memory"
    6U => "global"
    7U => "export"
    8U => "start"
    9U => "element"
    10U => "code"
    11U => "data"
    12U => "data_count"
    13U => "tag"
    _ => "section-" + section_id.to_string()
  }
}

///|
fn component_section_name(section_id : UInt) -> String {
  match section_id {
    1U => "core"
    2U => "core-instance"
    3U => "core-type"
    4U => "component"
    5U => "instance"
    6U => "alias"
    7U => "type"
    8U => "canon"
    9U => "start"
    10U => "import"
    11U => "export"
    12U => "value"
    _ => "section-" + section_id.to_string()
  }
}

///|
fn section_key(section : RawSection, component : Bool) -> String {
  if section.section_id == 0U {
    match section.custom_name {
      Some(name) => "custom:" + name
      None => "custom:(anon)"
    }
  } else if component {
    component_section_name(section.section_id)
  } else {
    core_section_name(section.section_id)
  }
}

///|
fn summarize_sections(
  sections : Array[RawSection],
  component : Bool,
) -> Array[SectionSize] {
  let grouped : Map[String, SectionSize] = {}
  for section in sections {
    let key = section_key(section, component)
    let size = section_total_bytes(section)
    match grouped.get(key) {
      Some(prev) =>
        grouped.set(key, {
          key,
          section_id: prev.section_id,
          total_bytes: prev.total_bytes + size,
        })
      None =>
        grouped.set(key, {
          key,
          section_id: section.section_id,
          total_bytes: size,
        })
    }
  }
  let out : Array[SectionSize] = []
  grouped.each((_, value) => out.push(value))
  out.sort_by((a, b) => if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else {
    a.key.compare(b.key)
  })
  out
}

///|
fn parse_vec_count(payload : Bytes) -> UInt raise WalyzeError {
  let parser = Cursor::new(payload)
  parser.read_u32_leb128()
}

///|
fn parse_code_section_metrics(
  payload : Bytes,
) -> (UInt, UInt) raise WalyzeError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let mut total_body_bytes = 0U
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WalyzeError::InvalidFormat("code body size overflow")
    }
    total_body_bytes += body_size_u
    parser.skip(body_size)
  }
  (body_count, total_body_bytes)
}

///|
fn read_name_string(parser : Cursor) -> String raise WalyzeError {
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WalyzeError::InvalidFormat("name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len
  if end_ > parser.bytes.length() {
    raise WalyzeError::UnexpectedEof
  }
  let out : Array[Char] = []
  for b in parser.bytes[start:end_] {
    match b.to_int().to_char() {
      Some(ch) => out.push(ch)
      None => out.push('?')
    }
  }
  parser.set_pos(end_)
  String::from_array(out[:])
}

///|
fn bytes_to_name_string(bytes : Bytes) -> String {
  let out : Array[Char] = []
  for b in bytes {
    match b.to_int().to_char() {
      Some(ch) => out.push(ch)
      None => out.push('?')
    }
  }
  String::from_array(out[:])
}

///|
fn parse_code_body_sizes(payload : Bytes) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let body_sizes : Array[UInt] = []
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WalyzeError::InvalidFormat("code body size overflow")
    }
    body_sizes.push(body_size_u)
    parser.skip(body_size)
  }
  body_sizes
}

///|
fn parse_code_bodies(payload : Bytes) -> Array[Bytes] raise WalyzeError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let out : Array[Bytes] = []
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WalyzeError::InvalidFormat("code body size overflow")
    }
    let start = parser.get_pos()
    let end_ = start + body_size
    if end_ > payload.length() {
      raise WalyzeError::UnexpectedEof
    }
    out.push(payload[start:end_].to_bytes())
    parser.set_pos(end_)
  }
  out
}

///|
fn parse_start_function_index(payload : Bytes) -> UInt raise WalyzeError {
  let parser = Cursor::new(payload)
  parser.read_u32_leb128()
}

///|
fn parse_limits(parser : Cursor) -> Unit raise WalyzeError {
  let flags = parser.read_u32_leb128()
  ignore(parser.read_u32_leb128())
  if (flags & 0x01U) != 0U {
    ignore(parser.read_u32_leb128())
  }
}

///|
fn parse_import_function_count(payload : Bytes) -> UInt raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let mut function_import_count = 0U
  for _ in 0U..<count {
    ignore(read_name_string(parser))
    ignore(read_name_string(parser))
    let kind = parser.read_byte().to_uint()
    match kind {
      0x00U => {
        function_import_count += 1U
        ignore(parser.read_u32_leb128())
      }
      0x01U => {
        skip_heap_type(parser)
        parse_limits(parser)
      }
      0x02U => parse_limits(parser)
      0x03U => {
        ignore(parser.read_byte())
        ignore(parser.read_byte())
      }
      0x04U => {
        ignore(parser.read_byte())
        ignore(parser.read_u32_leb128())
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported import descriptor kind: " + kind.to_string(),
        )
    }
  }
  function_import_count
}

///|
priv struct ImportSectionEntry {
  bytes : Bytes
  kind : UInt
  kind_index : UInt
}

///|
fn parse_import_section_entries_raise(
  payload : Bytes,
) -> Array[ImportSectionEntry] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[ImportSectionEntry] = []
  let mut function_import_index = 0U
  let mut table_import_index = 0U
  let mut memory_import_index = 0U
  let mut global_import_index = 0U
  let mut tag_import_index = 0U
  for _ in 0U..<count {
    let start = parser.get_pos()
    ignore(read_name_string(parser))
    ignore(read_name_string(parser))
    let kind = parser.read_byte().to_uint()
    let kind_index = match kind {
      0x00U => {
        let current = function_import_index
        function_import_index += 1U
        ignore(parser.read_u32_leb128())
        current
      }
      0x01U => {
        let current = table_import_index
        table_import_index += 1U
        skip_heap_type(parser)
        parse_limits(parser)
        current
      }
      0x02U => {
        let current = memory_import_index
        memory_import_index += 1U
        parse_limits(parser)
        current
      }
      0x03U => {
        let current = global_import_index
        global_import_index += 1U
        ignore(parser.read_byte())
        ignore(parser.read_byte())
        current
      }
      0x04U => {
        let current = tag_import_index
        tag_import_index += 1U
        ignore(parser.read_byte())
        ignore(parser.read_u32_leb128())
        current
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported import descriptor kind: " + kind.to_string(),
        )
    }
    let end_ = parser.get_pos()
    out.push({ bytes: payload[start:end_].to_bytes(), kind, kind_index })
  }
  out
}

///|
fn rewrite_import_section_payload_for_keep_raise(
  payload : Bytes,
  keep_table_imports : Array[Bool],
  keep_memory_imports : Array[Bool],
  keep_global_imports : Array[Bool],
) -> (Bytes, UInt) raise WalyzeError {
  let entries = parse_import_section_entries_raise(payload)
  let kept_entries : Array[Bytes] = []
  let mut removed_count = 0U
  for entry in entries {
    let mut keep = true
    if entry.kind == 1U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_table_imports.length() {
        raise WalyzeError::InvalidFormat("table import keep index out of range")
      }
      keep = keep_table_imports[index]
    } else if entry.kind == 2U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_memory_imports.length() {
        raise WalyzeError::InvalidFormat(
          "memory import keep index out of range",
        )
      }
      keep = keep_memory_imports[index]
    } else if entry.kind == 3U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_global_imports.length() {
        raise WalyzeError::InvalidFormat(
          "global import keep index out of range",
        )
      }
      keep = keep_global_imports[index]
    }
    if keep {
      kept_entries.push(entry.bytes)
    } else {
      removed_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_count)
}

///|
fn rewrite_import_section_payload_for_keep_kinds_raise(
  payload : Bytes,
  keep_function_imports : Array[Bool],
  keep_table_imports : Array[Bool],
  keep_memory_imports : Array[Bool],
  keep_global_imports : Array[Bool],
) -> (Bytes, UInt) raise WalyzeError {
  let entries = parse_import_section_entries_raise(payload)
  let kept_entries : Array[Bytes] = []
  let mut removed_count = 0U
  for entry in entries {
    let mut keep = true
    if entry.kind == 0U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_function_imports.length() {
        raise WalyzeError::InvalidFormat(
          "function import keep index out of range",
        )
      }
      keep = keep_function_imports[index]
    } else if entry.kind == 1U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_table_imports.length() {
        raise WalyzeError::InvalidFormat("table import keep index out of range")
      }
      keep = keep_table_imports[index]
    } else if entry.kind == 2U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_memory_imports.length() {
        raise WalyzeError::InvalidFormat(
          "memory import keep index out of range",
        )
      }
      keep = keep_memory_imports[index]
    } else if entry.kind == 3U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_global_imports.length() {
        raise WalyzeError::InvalidFormat(
          "global import keep index out of range",
        )
      }
      keep = keep_global_imports[index]
    }
    if keep {
      kept_entries.push(entry.bytes)
    } else {
      removed_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_count)
}

///|
fn parse_import_function_type_indices(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    ignore(read_name_string(parser))
    ignore(read_name_string(parser))
    let kind = parser.read_byte().to_uint()
    match kind {
      0x00U => out.push(parser.read_u32_leb128())
      0x01U => {
        skip_heap_type(parser)
        parse_limits(parser)
      }
      0x02U => parse_limits(parser)
      0x03U => {
        ignore(parser.read_byte())
        ignore(parser.read_byte())
      }
      0x04U => {
        ignore(parser.read_byte())
        ignore(parser.read_u32_leb128())
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported import descriptor kind: " + kind.to_string(),
        )
    }
  }
  out
}

///|
fn map_push_string_array(
  grouped : Map[UInt, Array[String]],
  key : UInt,
  value : String,
) -> Unit {
  match grouped.get(key) {
    Some(prev) => {
      let next = prev.copy()
      next.push(value)
      grouped.set(key, next)
    }
    None => grouped.set(key, [value])
  }
}

///|
fn parse_export_function_names(
  payload : Bytes,
) -> Map[UInt, Array[String]] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Map[UInt, Array[String]] = {}
  for _ in 0U..<count {
    let name = read_name_string(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    if kind == 0U {
      map_push_string_array(out, index, name)
    }
  }
  out
}

///|
fn parse_export_table_indices(payload : Bytes) -> Array[UInt] raise WalyzeError {
  parse_export_indices_by_kind(payload, 1U)
}

///|
fn parse_export_memory_indices(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  parse_export_indices_by_kind(payload, 2U)
}

///|
fn parse_export_global_indices(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  parse_export_indices_by_kind(payload, 3U)
}

///|
fn parse_export_indices_by_kind(
  payload : Bytes,
  kind_filter : UInt,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    ignore(read_name_string(parser))
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    if kind == kind_filter {
      push_unique_u32(out, index)
    }
  }
  out
}

///|
fn merge_export_function_names(
  target : Map[UInt, Array[String]],
  source : Map[UInt, Array[String]],
) -> Unit {
  source.each((index, names) => for name in names {
    map_push_string_array(target, index, name)
  })
}

///|
fn parse_custom_section_name_prefix_end(
  payload : Bytes,
) -> Int raise WalyzeError {
  let parser = Cursor::new(payload)
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WalyzeError::InvalidFormat("custom section name length overflow")
  }
  parser.skip(name_len)
  parser.get_pos()
}

///|
fn parse_name_section_function_names(
  payload : Bytes,
) -> Map[UInt, String] raise WalyzeError {
  let parser = Cursor::new(payload)
  parser.set_pos(parse_custom_section_name_prefix_end(payload))
  let out : Map[UInt, String] = {}
  while not(parser.eof()) {
    let subsection_id = parser.read_byte().to_uint()
    let subsection_size_u = parser.read_u32_leb128()
    let subsection_size = UInt::reinterpret_as_int(subsection_size_u)
    if subsection_size < 0 {
      raise WalyzeError::InvalidFormat("name subsection size overflow")
    }
    let subsection_start = parser.get_pos()
    let subsection_end = subsection_start + subsection_size
    if subsection_end > payload.length() {
      raise WalyzeError::UnexpectedEof
    }
    if subsection_id == 1U {
      let count = parser.read_u32_leb128()
      for _ in 0U..<count {
        let function_index = parser.read_u32_leb128()
        let name = read_name_string(parser)
        out.set(function_index, name)
      }
    }
    if parser.get_pos() < subsection_end {
      parser.set_pos(subsection_end)
    }
  }
  out
}

///|
fn encode_u32_leb128(value : UInt) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut current = value
  while true {
    let low = current & 0x7fU
    current = current >> 7
    if current == 0U {
      out.push(low.to_byte())
      break
    }
    out.push((low | 0x80U).to_byte())
  }
  out
}

///|
fn encode_nonnegative_i32_leb128(value : UInt) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut current = value
  while true {
    let low = current & 0x7fU
    current = current >> 7
    let sign_set = (low & 0x40U) != 0U
    if current == 0U && not(sign_set) {
      out.push(low.to_byte())
      break
    }
    out.push((low | 0x80U).to_byte())
  }
  out
}

///|
fn append_encoded_section(
  out : Array[Byte],
  section_id : UInt,
  payload : Bytes,
) -> Unit {
  out.push(section_id.to_byte())
  out.append(encode_u32_leb128(payload.length().reinterpret_as_uint())[:])
  out.append(payload[:].to_array())
}

///|
fn skip_sleb_immediate(
  parser : Cursor,
  max_bytes : Int,
) -> Unit raise WalyzeError {
  let mut consumed = 0
  while true {
    let b = parser.read_byte()
    consumed += 1
    if consumed > max_bytes {
      raise WalyzeError::InvalidFormat("sleb immediate overflow")
    }
    if (b & 0x80) == 0 {
      break
    }
  }
}

///|
fn skip_block_type(parser : Cursor) -> Unit raise WalyzeError {
  let first = parser.read_byte()
  match first.to_uint() {
    0x40U | 0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    _ =>
      if (first & 0x80) != 0 {
        let mut consumed = 1
        while true {
          let b = parser.read_byte()
          consumed += 1
          if consumed > 5 {
            raise WalyzeError::InvalidFormat("block type s33 overflow")
          }
          if (b & 0x80) == 0 {
            break
          }
        }
      }
  }
}

///|
fn skip_heap_type(parser : Cursor) -> Unit raise WalyzeError {
  let first = parser.read_byte()
  match first.to_uint() {
    0x70U | 0x6fU => ()
    _ =>
      if (first & 0x80) != 0 {
        let mut consumed = 1
        while true {
          let b = parser.read_byte()
          consumed += 1
          if consumed > 5 {
            raise WalyzeError::InvalidFormat("heap type s33 overflow")
          }
          if (b & 0x80) == 0 {
            break
          }
        }
      }
  }
}

///|
fn skip_memarg(parser : Cursor) -> Unit raise WalyzeError {
  ignore(parser.read_u32_leb128())
  ignore(parser.read_u32_leb128())
}

///|
fn skip_memarg_lane(parser : Cursor) -> Unit raise WalyzeError {
  skip_memarg(parser)
  ignore(parser.read_byte())
}

///|
fn skip_fc_prefixed_immediate(parser : Cursor) -> Unit raise WalyzeError {
  let subopcode = parser.read_u32_leb128()
  match subopcode {
    0U..=7U => ()
    8U => {
      ignore(parser.read_u32_leb128())
      ignore(parser.read_u32_leb128())
    }
    9U => ignore(parser.read_u32_leb128())
    10U => {
      ignore(parser.read_u32_leb128())
      ignore(parser.read_u32_leb128())
    }
    11U => ignore(parser.read_u32_leb128())
    12U => {
      ignore(parser.read_u32_leb128())
      ignore(parser.read_u32_leb128())
    }
    13U => ignore(parser.read_u32_leb128())
    14U => {
      ignore(parser.read_u32_leb128())
      ignore(parser.read_u32_leb128())
    }
    15U | 16U | 17U => ignore(parser.read_u32_leb128())
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported 0xfc subopcode in parser: " + subopcode.to_string(),
      )
  }
}

///|
fn skip_fd_prefixed_immediate(parser : Cursor) -> Unit raise WalyzeError {
  let subopcode = parser.read_u32_leb128()
  match subopcode {
    0x00U..=0x0bU | 0x5cU | 0x5dU => skip_memarg(parser)
    0x0cU | 0x0dU => parser.skip(16)
    0x15U..=0x22U => ignore(parser.read_byte())
    0x54U..=0x5bU => skip_memarg_lane(parser)
    0x0eU..=0x14U | 0x23U..=0x53U | 0x5eU..=0xffU => ()
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported 0xfd subopcode in parser: " + subopcode.to_string(),
      )
  }
}

///|
fn skip_instruction_immediate_raise(
  parser : Cursor,
  opcode : UInt,
) -> Unit raise WalyzeError {
  match opcode {
    0x02U | 0x03U | 0x04U => skip_block_type(parser)
    0x0cU
    | 0x0dU
    | 0x10U
    | 0x20U
    | 0x21U
    | 0x22U
    | 0x23U
    | 0x24U
    | 0x25U
    | 0x26U
    | 0xd2U => ignore(parser.read_u32_leb128())
    0x11U => {
      ignore(parser.read_u32_leb128())
      ignore(parser.read_u32_leb128())
    }
    0x0eU => {
      let count = parser.read_u32_leb128()
      for _ in 0U..<count {
        ignore(parser.read_u32_leb128())
      }
      ignore(parser.read_u32_leb128())
    }
    0x1cU => {
      let count = parser.read_u32_leb128()
      for _ in 0U..<count {
        ignore(parser.read_byte())
      }
    }
    0x28U..=0x3eU => {
      ignore(parser.read_u32_leb128())
      ignore(parser.read_u32_leb128())
    }
    0x3fU | 0x40U => ignore(parser.read_byte())
    0x41U => skip_sleb_immediate(parser, 5)
    0x42U => skip_sleb_immediate(parser, 10)
    0x43U => parser.skip(4)
    0x44U => parser.skip(8)
    0xfcU => skip_fc_prefixed_immediate(parser)
    0xfdU => skip_fd_prefixed_immediate(parser)
    0xd0U => skip_heap_type(parser)
    0x00U | 0x01U | 0x05U | 0x0bU | 0x0fU | 0x1aU | 0x1bU | 0xd1U => ()
    0x45U..=0xc4U => ()
    _ => raise WalyzeError::InvalidFormat("unsupported opcode in parser")
  }
}

///|
priv struct InstrSpan {
  start : Int
  end_ : Int
  opcode : UInt
}

///|
priv struct OpenCodeBlock {
  entry_index : Int
  start_span_index : Int
  start_offset : Int
}

///|
fn parse_instruction_spans_raise(
  instr_bytes : Bytes,
) -> Array[InstrSpan] raise WalyzeError {
  let parser = Cursor::new(instr_bytes)
  let spans : Array[InstrSpan] = []
  while not(parser.eof()) {
    let start = parser.get_pos()
    let opcode = parser.read_byte().to_uint()
    skip_instruction_immediate_raise(parser, opcode)
    let end_ = parser.get_pos()
    spans.push({ start, end_, opcode })
  }
  spans
}

///|
fn parse_instruction_spans(instr_bytes : Bytes) -> Array[InstrSpan]? {
  let result = try? parse_instruction_spans_raise(instr_bytes)
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn decode_u32_leb128_bytes(bytes : Bytes) -> UInt? {
  let parser = Cursor::new(bytes)
  let result = try? parser.read_u32_leb128()
  match result {
    Ok(v) => if parser.eof() { Some(v) } else { None }
    Err(_) => None
  }
}

///|
fn collect_direct_callees(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> (Array[UInt], Bool) {
  let callees : Array[UInt] = []
  let callee_seen : Map[UInt, Bool] = {}
  let mut has_indirect = false
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ > span.start + 1 {
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        match decode_u32_leb128_bytes(imm) {
          Some(index) =>
            if callee_seen.get(index) is None {
              callee_seen.set(index, true)
              callees.push(index)
            }
          None => ()
        }
      }
    } else if span.opcode == 0x11U {
      has_indirect = true
    }
  }
  (callees, has_indirect)
}

///|
fn read_name_bytes(parser : Cursor) -> Bytes raise WalyzeError {
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WalyzeError::InvalidFormat("name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len
  if end_ > parser.bytes.length() {
    raise WalyzeError::UnexpectedEof
  }
  parser.set_pos(end_)
  parser.bytes[start:end_].to_bytes()
}

///|
fn append_name_bytes(out : Array[Byte], name : Bytes) -> Unit {
  out.append(encode_u32_leb128(name.length().reinterpret_as_uint())[:])
  out.append(name[:].to_array())
}

///|
fn remap_function_index_raise(
  index : UInt,
  index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "dce remap missing function index: " + index.to_string(),
      )
  }
}

///|
fn remap_type_index_raise(
  index : UInt,
  type_index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match type_index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "type remap missing index: " + index.to_string(),
      )
  }
}

///|
fn read_val_type_bytes_raise(parser : Cursor) -> Bytes raise WalyzeError {
  let start = parser.get_pos()
  let code = parser.read_byte().to_uint()
  match code {
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U => skip_heap_type(parser)
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported value type in global section: " + code.to_string(),
      )
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
fn read_ref_type_bytes_raise(parser : Cursor) -> Bytes raise WalyzeError {
  let start = parser.get_pos()
  let code = parser.read_byte().to_uint()
  match code {
    0x70U | 0x6fU => ()
    0x63U | 0x64U => skip_heap_type(parser)
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported reference type in element section: " + code.to_string(),
      )
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
fn decode_heap_type_ref_index_bytes(heap_type_bytes : Bytes) -> UInt? {
  if heap_type_bytes.length() == 0 {
    return None
  }
  let last = heap_type_bytes[heap_type_bytes.length() - 1].to_uint()
  // Signed heaptype immediates with sign bit set are negative builtins.
  if (last & 0x40U) != 0U {
    return None
  }
  decode_u32_leb128_bytes(heap_type_bytes)
}

///|
fn decode_ref_type_index_from_type_bytes(type_bytes : Bytes) -> UInt? {
  if type_bytes.length() < 2 {
    return None
  }
  let code = type_bytes[0].to_uint()
  if code != 0x63U && code != 0x64U {
    return None
  }
  decode_heap_type_ref_index_bytes(type_bytes[1:type_bytes.length()].to_bytes())
}

///|
fn remap_gc_type_index_for_refine(
  index : UInt,
  gc_type_canonical_map : Map[UInt, UInt],
) -> UInt {
  match gc_type_canonical_map.get(index) {
    Some(v) => v
    None => index
  }
}

///|
fn type_bytes_equal_with_gc_canonical_map(
  left : Bytes,
  right : Bytes,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  if bytes_equal(left, right) {
    return true
  }
  if left.length() == 0 || right.length() == 0 {
    return false
  }
  let left_code = left[0].to_uint()
  let right_code = right[0].to_uint()
  if left_code != right_code {
    return false
  }
  let left_index = match decode_ref_type_index_from_type_bytes(left) {
    Some(v) => v
    None => return false
  }
  let right_index = match decode_ref_type_index_from_type_bytes(right) {
    Some(v) => v
    None => return false
  }
  remap_gc_type_index_for_refine(left_index, gc_type_canonical_map) ==
  remap_gc_type_index_for_refine(right_index, gc_type_canonical_map)
}

///|
fn read_storage_type_bytes_raise(
  parser : Cursor,
  context : String,
) -> Bytes raise WalyzeError {
  let start = parser.get_pos()
  let code = parser.read_byte().to_uint()
  match code {
    0x78U | 0x77U => ()
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U => skip_heap_type(parser)
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported storage type in " + context + ": " + code.to_string(),
      )
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
priv struct ParsedGcTypeField {
  storage_type : Bytes
  mutability : Byte
}

///|
priv struct ParsedGcTypeEntry {
  form : UInt
  fields : Array[ParsedGcTypeField]
}

///|
fn parse_gc_non_function_type_entry_from_raw_raise(
  raw : Bytes,
  context : String,
) -> ParsedGcTypeEntry raise WalyzeError {
  let parser = Cursor::new(raw)
  let form = parser.read_byte().to_uint()
  let fields : Array[ParsedGcTypeField] = []
  match form {
    0x5fU => {
      let field_count = parser.read_u32_leb128()
      for _ in 0U..<field_count {
        let storage_type = read_storage_type_bytes_raise(parser, context)
        let mutability = parser.read_byte().to_uint()
        if mutability > 1U {
          raise WalyzeError::InvalidFormat(
            "invalid field mutability in " +
            context +
            ": " +
            mutability.to_string(),
          )
        }
        fields.push({ storage_type, mutability: mutability.to_byte() })
      }
    }
    0x5eU => {
      let storage_type = read_storage_type_bytes_raise(parser, context)
      let mutability = parser.read_byte().to_uint()
      if mutability > 1U {
        raise WalyzeError::InvalidFormat(
          "invalid array field mutability in " +
          context +
          ": " +
          mutability.to_string(),
        )
      }
      fields.push({ storage_type, mutability: mutability.to_byte() })
    }
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported gc type form in " + context + ": " + form.to_string(),
      )
  }
  if not(parser.eof()) {
    raise WalyzeError::InvalidFormat(
      "trailing bytes in gc type entry in " + context,
    )
  }
  { form, fields }
}

///|
fn gc_type_entries_equal_with_canonical_map_raise(
  left_raw : Bytes,
  right_raw : Bytes,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool raise WalyzeError {
  if bytes_equal(left_raw, right_raw) {
    return true
  }
  let left = parse_gc_non_function_type_entry_from_raw_raise(
    left_raw, "type-refine-gc-compare",
  )
  let right = parse_gc_non_function_type_entry_from_raw_raise(
    right_raw, "type-refine-gc-compare",
  )
  if left.form != right.form || left.fields.length() != right.fields.length() {
    return false
  }
  for i in 0..<left.fields.length() {
    if left.fields[i].mutability != right.fields[i].mutability {
      return false
    }
    if not(
        type_bytes_equal_with_gc_canonical_map(
          left.fields[i].storage_type,
          right.fields[i].storage_type,
          gc_type_canonical_map,
        ),
      ) {
      return false
    }
  }
  true
}

///|
fn read_const_expr_bytes_raise(
  parser : Cursor,
  payload : Bytes,
) -> Bytes raise WalyzeError {
  let start = parser.get_pos()
  while true {
    let opcode = parser.read_byte().to_uint()
    skip_instruction_immediate_raise(parser, opcode)
    if opcode == 0x0bU {
      let end_ = parser.get_pos()
      return payload[start:end_].to_bytes()
    }
  }
  b""
}

///|
fn rewrite_const_expr_function_indices_raise(
  expr_bytes : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  rewrite_instruction_function_indices_raise(expr_bytes, spans, index_map)
}

///|
fn push_unique_u32(out : Array[UInt], value : UInt) -> Unit {
  if not(out.contains(value)) {
    out.push(value)
  }
}

///|
fn collect_ref_func_indices_from_expr_raise(
  expr_bytes : Bytes,
) -> Array[UInt] raise WalyzeError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0xd2U {
      match decode_span_u32_immediate(expr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode ref.func immediate in const expr",
          )
      }
    }
  }
  out
}

///|
fn collect_ref_func_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0xd2U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode ref.func immediate in code",
          )
      }
    }
  }
  out
}

///|
fn collect_ref_func_indices_from_code_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  let bodies = parse_code_bodies(payload)
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for
      index in collect_ref_func_indices_from_instruction_raise(
        instr_bytes, spans,
      ) {
      push_unique_u32(out, index)
    }
  }
  out
}

///|
fn collect_global_get_indices_from_expr_raise(
  expr_bytes : Bytes,
) -> Array[UInt] raise WalyzeError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x23U {
      match decode_span_u32_immediate(expr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode global.get immediate in const expr",
          )
      }
    }
  }
  out
}

///|
fn remap_global_index_raise(
  index : UInt,
  global_index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match global_index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "global remap missing index: " + index.to_string(),
      )
  }
}

///|
fn remap_memory_index_raise(
  index : UInt,
  memory_index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match memory_index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "memory remap missing index: " + index.to_string(),
      )
  }
}

///|
fn rewrite_const_expr_global_indices_raise(
  expr_bytes : Bytes,
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x23U {
      match decode_span_u32_immediate(expr_bytes, span) {
        Some(index) => {
          out.push(0x23U.to_byte())
          out.append(
            encode_u32_leb128(remap_global_index_raise(index, global_index_map))[:],
          )
        }
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode global.get immediate",
          )
      }
    } else {
      out.append(expr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn parse_global_section_function_refs_raise(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    ignore(read_val_type_bytes_raise(parser))
    ignore(parser.read_byte())
    let expr = read_const_expr_bytes_raise(parser, payload)
    for index in collect_ref_func_indices_from_expr_raise(expr) {
      push_unique_u32(out, index)
    }
  }
  out
}

///|
fn parse_element_section_function_refs_raise(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      1U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      2U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      3U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      5U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      6U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      7U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported element segment flags in parser: " + flags.to_string(),
        )
    }
  }
  out
}

///|
fn collect_used_global_indices_from_element_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      1U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      2U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      3U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      5U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      6U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      7U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported element segment flags in global parser: " +
          flags.to_string(),
        )
    }
  }
  out
}

///|
fn rewrite_global_section_payload_for_index_map_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let val_type = read_val_type_bytes_raise(parser)
    out.append(val_type[:].to_array())
    let mutability = parser.read_byte()
    out.push(mutability)
    let expr_bytes = read_const_expr_bytes_raise(parser, payload)
    let rewritten = rewrite_const_expr_function_indices_raise(
      expr_bytes, index_map,
    )
    out.append(rewritten[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_element_section_payload_for_index_map_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(segment_count)[:])
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    out.append(encode_u32_leb128(flags)[:])
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      1U => {
        out.push(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      2U => {
        let table_index = parser.read_u32_leb128()
        out.append(encode_u32_leb128(table_index)[:])
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        out.push(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      3U => {
        out.push(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      5U => {
        out.append(read_ref_type_bytes_raise(parser)[:].to_array())
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      6U => {
        let table_index = parser.read_u32_leb128()
        out.append(encode_u32_leb128(table_index)[:])
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        out.append(read_ref_type_bytes_raise(parser)[:].to_array())
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      7U => {
        out.append(read_ref_type_bytes_raise(parser)[:].to_array())
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported element segment flags in rewrite: " + flags.to_string(),
        )
    }
  }
  Bytes::from_array(out[:])
}

///|
priv struct GlobalSectionEntry {
  val_type : Bytes
  mutability : Byte
  init_expr : Bytes
  init_global_refs : Array[UInt]
}

///|
fn parse_global_section_entries_with_refs_raise(
  payload : Bytes,
) -> Array[GlobalSectionEntry] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[GlobalSectionEntry] = []
  for _ in 0U..<count {
    let val_type = read_val_type_bytes_raise(parser)
    let mutability = parser.read_byte()
    let init_expr = read_const_expr_bytes_raise(parser, payload)
    out.push({
      val_type,
      mutability,
      init_expr,
      init_global_refs: collect_global_get_indices_from_expr_raise(init_expr),
    })
  }
  out
}

///|
fn rewrite_global_section_payload_for_keep_local_and_global_index_map_raise(
  payload : Bytes,
  keep_local : Array[Bool],
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let entries = parse_global_section_entries_with_refs_raise(payload)
  if entries.length() != keep_local.length() {
    raise WalyzeError::InvalidFormat(
      "global section length mismatch: global=" +
      entries.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_entries : Array[GlobalSectionEntry] = []
  for i in 0..<entries.length() {
    if keep_local[i] {
      kept_entries.push(entries[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry.val_type[:].to_array())
    out.push(entry.mutability)
    out.append(
      rewrite_const_expr_global_indices_raise(entry.init_expr, global_index_map)[:].to_array(),
    )
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_global_section_payload_for_local_order_and_global_index_map_raise(
  payload : Bytes,
  local_order : Array[UInt],
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let entries = parse_global_section_entries_with_refs_raise(payload)
  if entries.length() != local_order.length() {
    raise WalyzeError::InvalidFormat(
      "global section length mismatch for reorder: global=" +
      entries.length().to_string() +
      " order=" +
      local_order.length().to_string(),
    )
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(local_order.length().reinterpret_as_uint())[:])
  for old_local_index_u in local_order {
    let old_local_index = UInt::reinterpret_as_int(old_local_index_u)
    if old_local_index < 0 || old_local_index >= entries.length() {
      raise WalyzeError::InvalidFormat(
        "global reorder index out of range: " + old_local_index_u.to_string(),
      )
    }
    let entry = entries[old_local_index]
    out.append(entry.val_type[:].to_array())
    out.push(entry.mutability)
    out.append(
      rewrite_const_expr_global_indices_raise(entry.init_expr, global_index_map)[:].to_array(),
    )
  }
  Bytes::from_array(out[:])
}

///|
fn parse_memory_section_entries_raise(
  payload : Bytes,
) -> Array[Bytes] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Bytes] = []
  for _ in 0U..<count {
    let start = parser.get_pos()
    parse_limits(parser)
    let end_ = parser.get_pos()
    out.push(payload[start:end_].to_bytes())
  }
  out
}

///|
fn rewrite_memory_section_payload_for_keep_local_raise(
  payload : Bytes,
  keep_local : Array[Bool],
) -> Bytes raise WalyzeError {
  let entries = parse_memory_section_entries_raise(payload)
  if entries.length() != keep_local.length() {
    raise WalyzeError::InvalidFormat(
      "memory section length mismatch: memory=" +
      entries.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_entries : Array[Bytes] = []
  for i in 0..<entries.length() {
    if keep_local[i] {
      kept_entries.push(entries[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_memory_section_payload_for_local_order_raise(
  payload : Bytes,
  local_order : Array[UInt],
) -> Bytes raise WalyzeError {
  let entries = parse_memory_section_entries_raise(payload)
  if entries.length() != local_order.length() {
    raise WalyzeError::InvalidFormat(
      "memory section length mismatch for reorder: memory=" +
      entries.length().to_string() +
      " order=" +
      local_order.length().to_string(),
    )
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(local_order.length().reinterpret_as_uint())[:])
  for old_local_index_u in local_order {
    let old_local_index = UInt::reinterpret_as_int(old_local_index_u)
    if old_local_index < 0 || old_local_index >= entries.length() {
      raise WalyzeError::InvalidFormat(
        "memory reorder index out of range: " + old_local_index_u.to_string(),
      )
    }
    out.append(entries[old_local_index][:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn parse_table_section_entries_raise(
  payload : Bytes,
) -> Array[Bytes] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Bytes] = []
  for _ in 0U..<count {
    let start = parser.get_pos()
    ignore(read_ref_type_bytes_raise(parser))
    parse_limits(parser)
    let end_ = parser.get_pos()
    out.push(payload[start:end_].to_bytes())
  }
  out
}

///|
fn rewrite_table_section_payload_for_keep_local_raise(
  payload : Bytes,
  keep_local : Array[Bool],
) -> Bytes raise WalyzeError {
  let entries = parse_table_section_entries_raise(payload)
  if entries.length() != keep_local.length() {
    raise WalyzeError::InvalidFormat(
      "table section length mismatch: table=" +
      entries.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let out : Array[Byte] = []
  let mut kept_count = 0U
  let kept_entries : Array[Bytes] = []
  for i in 0..<entries.length() {
    if keep_local[i] {
      kept_entries.push(entries[i])
      kept_count += 1U
    }
  }
  out.append(encode_u32_leb128(kept_count)[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn remap_table_index_raise(
  index : UInt,
  table_index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match table_index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "table remap missing index: " + index.to_string(),
      )
  }
}

///|
fn remap_element_segment_index_raise(
  index : UInt,
  element_index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match element_index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "element segment remap missing index: " + index.to_string(),
      )
  }
}

///|
fn remap_data_segment_index_raise(
  index : UInt,
  data_index_map : Map[UInt, UInt],
) -> UInt raise WalyzeError {
  match data_index_map.get(index) {
    Some(v) => v
    None =>
      raise WalyzeError::InvalidFormat(
        "data segment remap missing index: " + index.to_string(),
      )
  }
}

///|
fn make_identity_index_map(count : UInt) -> Map[UInt, UInt] {
  let out : Map[UInt, UInt] = {}
  for i in 0U..<count {
    out.set(i, i)
  }
  out
}

///|
priv struct ImportKindCounts {
  table_count : UInt
  memory_count : UInt
  global_count : UInt
}

///|
fn count_import_kinds(entries : Array[ImportSectionEntry]) -> ImportKindCounts {
  let mut table_count = 0U
  let mut memory_count = 0U
  let mut global_count = 0U
  for entry in entries {
    match entry.kind {
      1U => table_count += 1U
      2U => memory_count += 1U
      3U => global_count += 1U
      _ => ()
    }
  }
  { table_count, memory_count, global_count }
}

///|
fn count_reordered_local_indices(local_order : Array[UInt]) -> UInt {
  let mut moved = 0U
  for i in 0..<local_order.length() {
    if local_order[i] != i.reinterpret_as_uint() {
      moved += 1U
    }
  }
  moved
}

///|
fn increment_index_count_in_array(counts : Array[UInt], index : UInt) -> Unit {
  let pos = UInt::reinterpret_as_int(index)
  if pos >= 0 && pos < counts.length() {
    counts[pos] += 1U
  }
}

///|
fn index_count_in_array(counts : Array[UInt], index : UInt) -> UInt {
  let pos = UInt::reinterpret_as_int(index)
  if pos < 0 || pos >= counts.length() {
    return 0U
  }
  counts[pos]
}

///|
fn collect_used_table_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    match span.opcode {
      0x11U => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat("invalid call_indirect immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        ignore(parser.read_u32_leb128())
        push_unique_u32(out, parser.read_u32_leb128())
      }
      0x25U | 0x26U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => push_unique_u32(out, index)
          None =>
            raise WalyzeError::InvalidFormat(
              "failed to decode table index immediate",
            )
        }
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat("invalid 0xfc immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        match subopcode {
          12U => {
            ignore(parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          14U => {
            push_unique_u32(out, parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          15U | 16U | 17U => push_unique_u32(out, parser.read_u32_leb128())
          _ => ()
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn collect_used_table_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? {
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_used_table_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn opcode_fd_uses_memory(subopcode : UInt) -> Bool {
  (subopcode >= 0x00U && subopcode <= 0x0bU) ||
  (subopcode >= 0x54U && subopcode <= 0x5bU) ||
  subopcode == 0x5cU ||
  subopcode == 0x5dU
}

///|
fn collect_used_global_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x23U || span.opcode == 0x24U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode global index immediate",
          )
      }
    }
  }
  out
}

///|
fn collect_used_memory_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    match span.opcode {
      0x28U..=0x3eU => push_unique_u32(out, 0U)
      0x3fU | 0x40U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => push_unique_u32(out, index)
          None =>
            raise WalyzeError::InvalidFormat(
              "failed to decode memory.size/memory.grow immediate",
            )
        }
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat("invalid 0xfc immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        match subopcode {
          8U => {
            ignore(parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          10U => {
            push_unique_u32(out, parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          11U => push_unique_u32(out, parser.read_u32_leb128())
          _ => ()
        }
      }
      0xfdU => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat("invalid 0xfd immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        if opcode_fd_uses_memory(parser.read_u32_leb128()) {
          push_unique_u32(out, 0U)
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn collect_used_global_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? {
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_used_global_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn collect_used_memory_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? {
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_used_memory_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn rewrite_instruction_module_indices_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
  element_index_map : Map[UInt, UInt],
  data_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let out : Array[Byte] = []
  for span in spans {
    match span.opcode {
      0x11U => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat("invalid call_indirect immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let type_index = parser.read_u32_leb128()
        let table_index = parser.read_u32_leb128()
        out.push(0x11U.to_byte())
        out.append(encode_u32_leb128(type_index)[:])
        out.append(
          encode_u32_leb128(
            remap_table_index_raise(table_index, table_index_map),
          )[:],
        )
      }
      0x23U | 0x24U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => {
            out.push(span.opcode.to_byte())
            out.append(
              encode_u32_leb128(
                remap_global_index_raise(index, global_index_map),
              )[:],
            )
          }
          None =>
            raise WalyzeError::InvalidFormat(
              "failed to decode global index immediate",
            )
        }
      0x25U | 0x26U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => {
            out.push(span.opcode.to_byte())
            out.append(
              encode_u32_leb128(remap_table_index_raise(index, table_index_map))[:],
            )
          }
          None =>
            raise WalyzeError::InvalidFormat(
              "failed to decode table index immediate",
            )
        }
      0x28U..=0x3eU => {
        if remap_memory_index_raise(0U, memory_index_map) != 0U {
          raise WalyzeError::InvalidFormat(
            "implicit memory index remapped to non-zero",
          )
        }
        out.append(instr_bytes[span.start:span.end_].to_array())
      }
      0x3fU | 0x40U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => {
            out.push(span.opcode.to_byte())
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(index, memory_index_map),
              )[:],
            )
          }
          None =>
            raise WalyzeError::InvalidFormat(
              "failed to decode memory.size/memory.grow immediate",
            )
        }
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat("invalid 0xfc immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        let rest_start = parser.get_pos()
        out.push(0xfcU.to_byte())
        out.append(encode_u32_leb128(subopcode)[:])
        match subopcode {
          8U => {
            let data_index = parser.read_u32_leb128()
            let memory_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_data_segment_index_raise(data_index, data_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(memory_index, memory_index_map),
              )[:],
            )
          }
          9U => {
            let data_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_data_segment_index_raise(data_index, data_index_map),
              )[:],
            )
          }
          10U => {
            let dst_memory = parser.read_u32_leb128()
            let src_memory = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(dst_memory, memory_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(src_memory, memory_index_map),
              )[:],
            )
          }
          11U => {
            let memory_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(memory_index, memory_index_map),
              )[:],
            )
          }
          12U => {
            let elem_index = parser.read_u32_leb128()
            let table_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_element_segment_index_raise(elem_index, element_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(table_index, table_index_map),
              )[:],
            )
          }
          13U => {
            let elem_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_element_segment_index_raise(elem_index, element_index_map),
              )[:],
            )
          }
          14U => {
            let dst_table = parser.read_u32_leb128()
            let src_table = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(dst_table, table_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(src_table, table_index_map),
              )[:],
            )
          }
          15U | 16U | 17U => {
            let table_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(table_index, table_index_map),
              )[:],
            )
          }
          _ => out.append(imm[rest_start:imm.length()].to_array())
        }
      }
      _ => out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_module_index_map_raise(
  body : Bytes,
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
  element_index_map : Map[UInt, UInt],
  data_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let prefix_end = parse_local_decl_prefix_end(body)
  let instr_bytes = body[prefix_end:body.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_module_indices_raise(
    instr_bytes, spans, table_index_map, memory_index_map, global_index_map, element_index_map,
    data_index_map,
  )
  let out : Array[Byte] = body[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_module_index_map_raise(
  payload : Bytes,
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
  element_index_map : Map[UInt, UInt],
  data_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(bodies.length().reinterpret_as_uint())[:])
  for body in bodies {
    let rewritten = rewrite_code_body_for_module_index_map_raise(
      body, table_index_map, memory_index_map, global_index_map, element_index_map,
      data_index_map,
    )
    out.append(encode_u32_leb128(rewritten.length().reinterpret_as_uint())[:])
    out.append(rewritten[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_export_section_payload_for_module_index_maps_raise(
  payload : Bytes,
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  let mut kept_count = 0U
  let mut removed_count = 0U
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    let mapped = match kind {
      1U =>
        match table_index_map.get(index) {
          Some(v) => Some(v)
          None => None
        }
      2U =>
        match memory_index_map.get(index) {
          Some(v) => Some(v)
          None => None
        }
      3U =>
        match global_index_map.get(index) {
          Some(v) => Some(v)
          None => None
        }
      _ => Some(index)
    }
    match mapped {
      Some(remapped) => {
        kept_count += 1U
        append_name_bytes(out, name)
        out.push(kind.to_byte())
        out.append(encode_u32_leb128(remapped)[:])
      }
      None => removed_count += 1U
    }
  }
  let encoded : Array[Byte] = []
  encoded.append(encode_u32_leb128(kept_count)[:])
  encoded.append(out[:])
  (Bytes::from_array(encoded[:]), removed_count)
}

///|
fn read_function_index_vector_bytes_raise(
  parser : Cursor,
) -> Bytes raise WalyzeError {
  let start = parser.get_pos()
  let count = parser.read_u32_leb128()
  for _ in 0U..<count {
    ignore(parser.read_u32_leb128())
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
fn rewrite_const_expr_vector_global_indices_raise(
  parser : Cursor,
  payload : Bytes,
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let expr = read_const_expr_bytes_raise(parser, payload)
    out.append(
      rewrite_const_expr_global_indices_raise(expr, global_index_map)[:].to_array(),
    )
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_element_section_payload_for_table_index_map_raise(
  payload : Bytes,
  table_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
) -> (Bytes, UInt, Map[UInt, UInt]) raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let kept_segments : Array[Bytes] = []
  let element_index_map : Map[UInt, UInt] = {}
  let mut removed_segment_count = 0U
  for old_segment_index in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    let segment_out : Array[Byte] = []
    let mut keep_segment = true
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let function_indices = read_function_index_vector_bytes_raise(parser)
        if table_index_map.get(0U) is None {
          keep_segment = false
        } else {
          segment_out.append(encode_u32_leb128(0U)[:])
          segment_out.append(
            rewrite_const_expr_global_indices_raise(
              offset_expr, global_index_map,
            )[:].to_array(),
          )
          segment_out.append(function_indices[:].to_array())
        }
      }
      1U => {
        let elem_kind = parser.read_byte()
        let function_indices = read_function_index_vector_bytes_raise(parser)
        segment_out.append(encode_u32_leb128(1U)[:])
        segment_out.push(elem_kind)
        segment_out.append(function_indices[:].to_array())
      }
      2U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let elem_kind = parser.read_byte()
        let function_indices = read_function_index_vector_bytes_raise(parser)
        match table_index_map.get(table_index) {
          Some(remapped) => {
            segment_out.append(encode_u32_leb128(2U)[:])
            segment_out.append(encode_u32_leb128(remapped)[:])
            segment_out.append(
              rewrite_const_expr_global_indices_raise(
                offset_expr, global_index_map,
              )[:].to_array(),
            )
            segment_out.push(elem_kind)
            segment_out.append(function_indices[:].to_array())
          }
          None => keep_segment = false
        }
      }
      3U => {
        let elem_kind = parser.read_byte()
        let function_indices = read_function_index_vector_bytes_raise(parser)
        segment_out.append(encode_u32_leb128(3U)[:])
        segment_out.push(elem_kind)
        segment_out.append(function_indices[:].to_array())
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        if table_index_map.get(0U) is None {
          keep_segment = false
        } else {
          segment_out.append(encode_u32_leb128(4U)[:])
          segment_out.append(
            rewrite_const_expr_global_indices_raise(
              offset_expr, global_index_map,
            )[:].to_array(),
          )
          segment_out.append(exprs[:].to_array())
        }
      }
      5U => {
        let ref_type = read_ref_type_bytes_raise(parser)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        segment_out.append(encode_u32_leb128(5U)[:])
        segment_out.append(ref_type[:].to_array())
        segment_out.append(exprs[:].to_array())
      }
      6U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let ref_type = read_ref_type_bytes_raise(parser)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        match table_index_map.get(table_index) {
          Some(remapped) => {
            segment_out.append(encode_u32_leb128(6U)[:])
            segment_out.append(encode_u32_leb128(remapped)[:])
            segment_out.append(
              rewrite_const_expr_global_indices_raise(
                offset_expr, global_index_map,
              )[:].to_array(),
            )
            segment_out.append(ref_type[:].to_array())
            segment_out.append(exprs[:].to_array())
          }
          None => keep_segment = false
        }
      }
      7U => {
        let ref_type = read_ref_type_bytes_raise(parser)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        segment_out.append(encode_u32_leb128(7U)[:])
        segment_out.append(ref_type[:].to_array())
        segment_out.append(exprs[:].to_array())
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported element segment flags in table rewrite: " +
          flags.to_string(),
        )
    }
    if keep_segment {
      element_index_map.set(
        old_segment_index,
        kept_segments.length().reinterpret_as_uint(),
      )
      kept_segments.push(Bytes::from_array(segment_out[:]))
    } else {
      removed_segment_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_segments.length().reinterpret_as_uint())[:])
  for segment in kept_segments {
    out.append(segment[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_segment_count, element_index_map)
}

///|
fn read_data_init_bytes_raise(
  parser : Cursor,
  payload : Bytes,
) -> Bytes raise WalyzeError {
  let start = parser.get_pos()
  let size_u = parser.read_u32_leb128()
  let size = UInt::reinterpret_as_int(size_u)
  if size < 0 {
    raise WalyzeError::InvalidFormat("data init size overflow")
  }
  parser.skip(size)
  let end_ = parser.get_pos()
  payload[start:end_].to_bytes()
}

///|
fn collect_used_memory_and_global_indices_from_data_section_raise(
  payload : Bytes,
) -> (Array[UInt], Array[UInt]) raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let memory_indices : Array[UInt] = []
  let global_indices : Array[UInt] = []
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        push_unique_u32(memory_indices, 0U)
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(global_indices, index)
        }
        ignore(read_data_init_bytes_raise(parser, payload))
      }
      1U => ignore(read_data_init_bytes_raise(parser, payload))
      2U => {
        let memory_index = parser.read_u32_leb128()
        push_unique_u32(memory_indices, memory_index)
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(global_indices, index)
        }
        ignore(read_data_init_bytes_raise(parser, payload))
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported data segment flags in parser: " + flags.to_string(),
        )
    }
  }
  (memory_indices, global_indices)
}

///|
fn rewrite_data_section_payload_for_memory_global_index_map_raise(
  payload : Bytes,
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
) -> (Bytes, UInt, Map[UInt, UInt]) raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let kept_segments : Array[Bytes] = []
  let data_index_map : Map[UInt, UInt] = {}
  let mut removed_segment_count = 0U
  for old_segment_index in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    let segment_out : Array[Byte] = []
    let mut keep_segment = true
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let data_init = read_data_init_bytes_raise(parser, payload)
        match memory_index_map.get(0U) {
          Some(remapped_memory_index) =>
            if remapped_memory_index == 0U {
              segment_out.append(encode_u32_leb128(0U)[:])
              segment_out.append(
                rewrite_const_expr_global_indices_raise(
                  offset_expr, global_index_map,
                )[:].to_array(),
              )
              segment_out.append(data_init[:].to_array())
            } else {
              segment_out.append(encode_u32_leb128(2U)[:])
              segment_out.append(encode_u32_leb128(remapped_memory_index)[:])
              segment_out.append(
                rewrite_const_expr_global_indices_raise(
                  offset_expr, global_index_map,
                )[:].to_array(),
              )
              segment_out.append(data_init[:].to_array())
            }
          None => keep_segment = false
        }
      }
      1U => {
        let data_init = read_data_init_bytes_raise(parser, payload)
        segment_out.append(encode_u32_leb128(1U)[:])
        segment_out.append(data_init[:].to_array())
      }
      2U => {
        let memory_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let data_init = read_data_init_bytes_raise(parser, payload)
        match memory_index_map.get(memory_index) {
          Some(remapped_memory_index) => {
            segment_out.append(encode_u32_leb128(2U)[:])
            segment_out.append(encode_u32_leb128(remapped_memory_index)[:])
            segment_out.append(
              rewrite_const_expr_global_indices_raise(
                offset_expr, global_index_map,
              )[:].to_array(),
            )
            segment_out.append(data_init[:].to_array())
          }
          None => keep_segment = false
        }
      }
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported data segment flags in rewrite: " + flags.to_string(),
        )
    }
    if keep_segment {
      data_index_map.set(
        old_segment_index,
        kept_segments.length().reinterpret_as_uint(),
      )
      kept_segments.push(Bytes::from_array(segment_out[:]))
    } else {
      removed_segment_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_segments.length().reinterpret_as_uint())[:])
  for segment in kept_segments {
    out.append(segment[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_segment_count, data_index_map)
}

///|
fn rewrite_export_section_payload_for_dce_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let kept_entries : Array[Bytes] = []
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    let entry : Array[Byte] = []
    append_name_bytes(entry, name)
    entry.push(kind.to_byte())
    if kind == 0U {
      match index_map.get(index) {
        Some(remapped) => {
          entry.append(encode_u32_leb128(remapped)[:])
          kept_entries.push(Bytes::from_array(entry[:]))
        }
        None => ()
      }
    } else {
      entry.append(encode_u32_leb128(index)[:])
      kept_entries.push(Bytes::from_array(entry[:]))
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_export_section_payload_for_keep_names_raise(
  payload : Bytes,
  keep_names : Array[String],
) -> (Bytes, UInt) raise WalyzeError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let kept_entries : Array[Bytes] = []
  let mut removed_count = 0U
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let name_string = bytes_to_name_string(name)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    if keep_names.contains(name_string) {
      let entry : Array[Byte] = []
      append_name_bytes(entry, name)
      entry.push(kind.to_byte())
      entry.append(encode_u32_leb128(index)[:])
      kept_entries.push(Bytes::from_array(entry[:]))
    } else {
      removed_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_count)
}

///|
fn rewrite_start_section_payload_for_dce_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let start_index = parser.read_u32_leb128()
  let remapped = remap_function_index_raise(start_index, index_map)
  Bytes::from_array(encode_u32_leb128(remapped))
}

///|
fn parse_function_type_indices(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    out.push(parser.read_u32_leb128())
  }
  out
}

///|
priv struct ParsedTypeSectionEntry {
  raw : Bytes
  form : UInt
  referenced_type_indices : Array[UInt]
}

///|
fn maybe_collect_heap_type_ref_index(
  heap_type_bytes : Array[Byte],
  referenced_type_indices : Array[UInt],
) -> Unit {
  if heap_type_bytes.length() == 0 {
    return
  }
  let last = heap_type_bytes[heap_type_bytes.length() - 1].to_uint()
  // Signed heaptype immediates with sign bit set are negative builtins.
  if (last & 0x40U) != 0U {
    return
  }
  match decode_u32_leb128_bytes(Bytes::from_array(heap_type_bytes[:])) {
    Some(type_index) => push_unique_u32(referenced_type_indices, type_index)
    None => ()
  }
}

///|
fn read_heap_type_and_collect_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WalyzeError {
  let bytes : Array[Byte] = []
  let first = parser.read_byte()
  bytes.push(first)
  if (first & 0x80) != 0 {
    let mut consumed = 1
    while true {
      let b = parser.read_byte()
      bytes.push(b)
      consumed += 1
      if consumed > 5 {
        raise WalyzeError::InvalidFormat("heap type s33 overflow in " + context)
      }
      if (b & 0x80) == 0 {
        break
      }
    }
  }
  maybe_collect_heap_type_ref_index(bytes, referenced_type_indices)
}

///|
fn read_type_entry_val_type_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WalyzeError {
  let code = parser.read_byte().to_uint()
  match code {
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U =>
      read_heap_type_and_collect_refs_raise(
        parser, referenced_type_indices, context,
      )
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported value type in " + context + ": " + code.to_string(),
      )
  }
}

///|
fn read_type_entry_storage_type_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WalyzeError {
  let code = parser.read_byte().to_uint()
  match code {
    0x78U | 0x77U => ()
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U =>
      read_heap_type_and_collect_refs_raise(
        parser, referenced_type_indices, context,
      )
    _ =>
      raise WalyzeError::InvalidFormat(
        "unsupported storage type in " + context + ": " + code.to_string(),
      )
  }
}

///|
fn read_type_entry_field_type_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WalyzeError {
  read_type_entry_storage_type_refs_raise(
    parser, referenced_type_indices, context,
  )
  let mutability = parser.read_byte().to_uint()
  if mutability > 1U {
    raise WalyzeError::InvalidFormat(
      "invalid field mutability in " + context + ": " + mutability.to_string(),
    )
  }
}

///|
fn parse_type_section_entries_with_refs_raise(
  payload : Bytes,
  context : String,
) -> Array[ParsedTypeSectionEntry] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[ParsedTypeSectionEntry] = []
  for _ in 0U..<count {
    let start = parser.get_pos()
    let form = parser.read_byte().to_uint()
    let referenced_type_indices : Array[UInt] = []
    match form {
      0x60U => {
        let param_count = parser.read_u32_leb128()
        for _ in 0U..<param_count {
          read_type_entry_val_type_refs_raise(
            parser, referenced_type_indices, context,
          )
        }
        let result_count = parser.read_u32_leb128()
        for _ in 0U..<result_count {
          read_type_entry_val_type_refs_raise(
            parser, referenced_type_indices, context,
          )
        }
      }
      0x5fU => {
        let field_count = parser.read_u32_leb128()
        for _ in 0U..<field_count {
          read_type_entry_field_type_refs_raise(
            parser, referenced_type_indices, context,
          )
        }
      }
      0x5eU =>
        read_type_entry_field_type_refs_raise(
          parser, referenced_type_indices, context,
        )
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported type form in " + context + ": " + form.to_string(),
        )
    }
    let end_ = parser.get_pos()
    out.push({
      raw: payload[start:end_].to_bytes(),
      form,
      referenced_type_indices,
    })
  }
  out
}

///|
fn parse_type_section_entries_raise(
  payload : Bytes,
) -> Array[Bytes] raise WalyzeError {
  let parsed = parse_type_section_entries_with_refs_raise(
    payload, "type parser",
  )
  let out : Array[Bytes] = []
  for entry in parsed {
    out.push(entry.raw)
  }
  out
}

///|
priv struct FunctionTypeEntry {
  params : Array[Bytes]
  results : Array[Bytes]
}

///|
fn parse_function_type_entries_raise(
  payload : Bytes,
  context : String,
) -> Array[FunctionTypeEntry] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[FunctionTypeEntry] = []
  for _ in 0U..<count {
    let form = parser.read_byte().to_uint()
    if form != 0x60U {
      raise WalyzeError::InvalidFormat(
        "unsupported type form in " + context + ": " + form.to_string(),
      )
    }
    let param_count = parser.read_u32_leb128()
    let params : Array[Bytes] = []
    for _ in 0U..<param_count {
      params.push(read_val_type_bytes_raise(parser))
    }
    let result_count = parser.read_u32_leb128()
    let results : Array[Bytes] = []
    for _ in 0U..<result_count {
      results.push(read_val_type_bytes_raise(parser))
    }
    out.push({ params, results })
  }
  out
}

///|
fn parse_function_type_entry_from_raw_raise(
  raw : Bytes,
  context : String,
) -> FunctionTypeEntry raise WalyzeError {
  let parser = Cursor::new(raw)
  let form = parser.read_byte().to_uint()
  if form != 0x60U {
    raise WalyzeError::InvalidFormat(
      "unsupported type form in " + context + ": " + form.to_string(),
    )
  }
  let param_count = parser.read_u32_leb128()
  let params : Array[Bytes] = []
  for _ in 0U..<param_count {
    params.push(read_val_type_bytes_raise(parser))
  }
  let result_count = parser.read_u32_leb128()
  let results : Array[Bytes] = []
  for _ in 0U..<result_count {
    results.push(read_val_type_bytes_raise(parser))
  }
  if not(parser.eof()) {
    raise WalyzeError::InvalidFormat(
      "trailing bytes in function type raw entry in " + context,
    )
  }
  { params, results }
}

///|
fn parse_function_type_param_count_from_raw_raise(
  raw : Bytes,
  context : String,
) -> UInt raise WalyzeError {
  let parser = Cursor::new(raw)
  let form = parser.read_byte().to_uint()
  if form != 0x60U {
    raise WalyzeError::InvalidFormat(
      "unsupported type form in " + context + ": " + form.to_string(),
    )
  }
  let param_count = parser.read_u32_leb128()
  for _ in 0U..<param_count {
    ignore(read_val_type_bytes_raise(parser))
  }
  let result_count = parser.read_u32_leb128()
  for _ in 0U..<result_count {
    ignore(read_val_type_bytes_raise(parser))
  }
  if not(parser.eof()) {
    raise WalyzeError::InvalidFormat(
      "trailing bytes in function type raw entry in " + context,
    )
  }
  param_count
}

///|
fn encode_function_type_entry(
  params : Array[Bytes],
  results : Array[Bytes],
) -> Bytes {
  let out : Array[Byte] = [0x60U.to_byte()]
  out.append(encode_u32_leb128(params.length().reinterpret_as_uint())[:])
  for param in params {
    out.append(param[:].to_array())
  }
  out.append(encode_u32_leb128(results.length().reinterpret_as_uint())[:])
  for result in results {
    out.append(result[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn encode_type_section_payload(entries : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(entries.length().reinterpret_as_uint())[:])
  for entry in entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn find_type_entry_index(entries : Array[Bytes], target : Bytes) -> UInt? {
  for i in 0..<entries.length() {
    if bytes_equal(entries[i], target) {
      return Some(i.reinterpret_as_uint())
    }
  }
  None
}

///|
fn encode_function_section_payload_from_type_indices(
  type_indices : Array[UInt],
) -> Bytes {
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(type_indices.length().reinterpret_as_uint())[:])
  for type_index in type_indices {
    out.append(encode_u32_leb128(type_index)[:])
  }
  Bytes::from_array(out[:])
}

///|
fn encode_code_section_payload_from_bodies(bodies : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(bodies.length().reinterpret_as_uint())[:])
  for body in bodies {
    out.append(encode_u32_leb128(body.length().reinterpret_as_uint())[:])
    out.append(body[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_type_section_payload_for_keep_raise(
  payload : Bytes,
  keep_types : Array[Bool],
) -> Bytes raise WalyzeError {
  let entries = parse_type_section_entries_raise(payload)
  if entries.length() != keep_types.length() {
    raise WalyzeError::InvalidFormat(
      "type section length mismatch: type=" +
      entries.length().to_string() +
      " keep=" +
      keep_types.length().to_string(),
    )
  }
  let kept_entries : Array[Bytes] = []
  for i in 0..<entries.length() {
    if keep_types[i] {
      kept_entries.push(entries[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_function_section_payload_for_dce_raise(
  payload : Bytes,
  keep_local : Array[Bool],
) -> Bytes raise WalyzeError {
  let types = parse_function_type_indices(payload)
  if types.length() != keep_local.length() {
    raise WalyzeError::InvalidFormat(
      "dce function section length mismatch: function=" +
      types.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_types : Array[UInt] = []
  for i in 0..<types.length() {
    if keep_local[i] {
      kept_types.push(types[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_types.length().reinterpret_as_uint())[:])
  for type_index in kept_types {
    out.append(encode_u32_leb128(type_index)[:])
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_function_section_payload_for_type_index_map_raise(
  payload : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let old_type = parser.read_u32_leb128()
    out.append(
      encode_u32_leb128(remap_type_index_raise(old_type, type_index_map))[:],
    )
  }
  Bytes::from_array(out[:])
}

///|
fn collect_used_type_indices_from_import_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    ignore(read_name_bytes(parser))
    ignore(read_name_bytes(parser))
    let kind = parser.read_byte().to_uint()
    match kind {
      0U => push_unique_u32(out, parser.read_u32_leb128())
      1U => {
        skip_heap_type(parser)
        parse_limits(parser)
      }
      2U => parse_limits(parser)
      3U => {
        ignore(read_val_type_bytes_raise(parser))
        ignore(parser.read_byte())
      }
      4U =>
        raise WalyzeError::InvalidFormat(
          "tag import is not supported in remove-unused-types",
        )
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported import descriptor kind in remove-unused-types: " +
          kind.to_string(),
        )
    }
  }
  out
}

///|
fn rewrite_import_section_payload_for_type_index_map_raise(
  payload : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let module_name = read_name_bytes(parser)
    let field_name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    append_name_bytes(out, module_name)
    append_name_bytes(out, field_name)
    out.push(kind.to_byte())
    match kind {
      0U => {
        let old_type = parser.read_u32_leb128()
        out.append(
          encode_u32_leb128(remap_type_index_raise(old_type, type_index_map))[:],
        )
      }
      1U => {
        let start = parser.get_pos()
        skip_heap_type(parser)
        parse_limits(parser)
        let end_ = parser.get_pos()
        out.append(payload[start:end_].to_array())
      }
      2U => {
        let start = parser.get_pos()
        parse_limits(parser)
        let end_ = parser.get_pos()
        out.append(payload[start:end_].to_array())
      }
      3U => {
        out.append(read_val_type_bytes_raise(parser)[:].to_array())
        out.push(parser.read_byte())
      }
      4U =>
        raise WalyzeError::InvalidFormat(
          "tag import is not supported in remove-unused-types",
        )
      _ =>
        raise WalyzeError::InvalidFormat(
          "unsupported import descriptor kind in remove-unused-types: " +
          kind.to_string(),
        )
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_instruction_function_indices_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x10U || span.opcode == 0xd2U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call/ref.func immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let old_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode function index immediate",
          )
      }
      let new_index = remap_function_index_raise(old_index, index_map)
      out.push(span.opcode.to_byte())
      out.append(encode_u32_leb128(new_index)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_dce_raise(
  body_bytes : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => raise WalyzeError::InvalidFormat("unsupported opcode in dce apply")
  }
  let rewritten_instr = rewrite_instruction_function_indices_raise(
    instr_bytes, spans, index_map,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_dce_raise(
  payload : Bytes,
  keep_local : Array[Bool],
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  if bodies.length() != keep_local.length() {
    raise WalyzeError::InvalidFormat(
      "dce code section length mismatch: code=" +
      bodies.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_bodies : Array[Bytes] = []
  for i in 0..<bodies.length() {
    if keep_local[i] {
      kept_bodies.push(rewrite_code_body_for_dce_raise(bodies[i], index_map))
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_bodies.length().reinterpret_as_uint())[:])
  for body in kept_bodies {
    out.append(encode_u32_leb128(body.length().reinterpret_as_uint())[:])
    out.append(body[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn decode_call_indirect_immediate(imm : Bytes) -> (UInt, UInt)? {
  let parser = Cursor::new(imm)
  let result = try? {
    let type_index = parser.read_u32_leb128()
    let table_index = parser.read_u32_leb128()
    if not(parser.eof()) {
      raise WalyzeError::InvalidFormat(
        "call_indirect immediate has trailing bytes",
      )
    }
    (type_index, table_index)
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn collect_used_type_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x11U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call_indirect immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      match decode_call_indirect_immediate(imm) {
        Some((type_index, _table_index)) => push_unique_u32(out, type_index)
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode call_indirect immediate",
          )
      }
    }
  }
  out
}

///|
fn collect_used_type_indices_from_code_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  let bodies = parse_code_bodies(payload)
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for
      type_index in collect_used_type_indices_from_instruction_raise(
        instr_bytes, spans,
      ) {
      push_unique_u32(out, type_index)
    }
  }
  out
}

///|
fn rewrite_instruction_type_indices_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x11U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call_indirect immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let (old_type_index, table_index) = match
        decode_call_indirect_immediate(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode call_indirect immediate",
          )
      }
      out.push(0x11U.to_byte())
      out.append(
        encode_u32_leb128(
          remap_type_index_raise(old_type_index, type_index_map),
        )[:],
      )
      out.append(encode_u32_leb128(table_index)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_type_index_map_raise(
  body_bytes : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_type_indices_raise(
    instr_bytes, spans, type_index_map,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_type_index_map_raise(
  payload : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(bodies.length().reinterpret_as_uint())[:])
  for body in bodies {
    let rewritten = rewrite_code_body_for_type_index_map_raise(
      body, type_index_map,
    )
    out.append(encode_u32_leb128(rewritten.length().reinterpret_as_uint())[:])
    out.append(rewritten[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn collect_used_param_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  param_count : UInt,
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(local_index) =>
          if local_index < param_count {
            push_unique_u32(out, local_index)
          }
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode local index immediate",
          )
      }
    }
  }
  out
}

///|
fn compute_removed_trailing_param_count(
  param_count : UInt,
  used_param_indices : Array[UInt],
) -> UInt {
  let mut keep_param_count = param_count
  while keep_param_count > 0U {
    let trailing = keep_param_count - 1U
    if used_param_indices.contains(trailing) {
      break
    }
    keep_param_count -= 1U
  }
  param_count - keep_param_count
}

///|
fn remap_local_index_for_signature_pruning_raise(
  local_index : UInt,
  old_param_count : UInt,
  removed_param_count : UInt,
) -> UInt raise WalyzeError {
  if removed_param_count == 0U {
    return local_index
  }
  if old_param_count < removed_param_count {
    raise WalyzeError::InvalidFormat(
      "invalid signature-prune param count: old=" +
      old_param_count.to_string() +
      " removed=" +
      removed_param_count.to_string(),
    )
  }
  let kept_param_count = old_param_count - removed_param_count
  if local_index < kept_param_count {
    return local_index
  }
  if local_index < old_param_count {
    raise WalyzeError::InvalidFormat(
      "signature-prune touched removed param index: " + local_index.to_string(),
    )
  }
  local_index - removed_param_count
}

///|
fn rewrite_instruction_local_indices_for_signature_pruning_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  old_param_count : UInt,
  removed_param_count : UInt,
) -> Bytes raise WalyzeError {
  if removed_param_count == 0U {
    return instr_bytes
  }
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid local immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let local_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode local index immediate",
          )
      }
      let remapped = remap_local_index_for_signature_pruning_raise(
        local_index, old_param_count, removed_param_count,
      )
      out.push(span.opcode.to_byte())
      out.append(encode_u32_leb128(remapped)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_signature_pruning_raise(
  body_bytes : Bytes,
  old_param_count : UInt,
  removed_param_count : UInt,
) -> Bytes raise WalyzeError {
  if removed_param_count == 0U {
    return body_bytes
  }
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_local_indices_for_signature_pruning_raise(
    instr_bytes, spans, old_param_count, removed_param_count,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_instruction_calls_for_signature_pruning_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  removed_param_count_by_function : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat("failed to decode call immediate")
      }
      let removed_param_count = match
        removed_param_count_by_function.get(target) {
        Some(v) => v
        None => 0U
      }
      for _ in 0U..<removed_param_count {
        out.push(0x1aU.to_byte())
      }
      out.append(instr_bytes[span.start:span.end_].to_array())
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_calls_for_signature_pruning_raise(
  body_bytes : Bytes,
  removed_param_count_by_function : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_calls_for_signature_pruning_raise(
    instr_bytes, spans, removed_param_count_by_function,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn is_single_i32_val_type(val_type : Bytes) -> Bool {
  val_type.length() == 1 && val_type[0].to_uint() == 0x7fU
}

///|
fn extract_inlining_replacement_instr_raise(
  body_bytes : Bytes,
  type_entry : FunctionTypeEntry,
) -> Bytes? raise WalyzeError {
  if type_entry.params.length() > 0 {
    return None
  }
  let prefix = parse_local_decl_prefix_raise(body_bytes)
  if prefix.local_types.length() > 0 {
    return None
  }
  let instr_bytes = body_bytes[prefix.prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  if type_entry.results.length() == 1 &&
    is_single_i32_val_type(type_entry.results[0]) &&
    spans.length() == 2 &&
    spans[0].opcode == 0x41U &&
    spans[1].opcode == 0x0bU {
    return Some(instr_bytes[spans[0].start:spans[0].end_].to_bytes())
  }
  None
}

///|
fn rewrite_instruction_calls_for_inlining_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  replacement_by_function_index : Map[UInt, Bytes],
) -> (Bytes, UInt) raise WalyzeError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call immediate in inlining")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode call immediate in inlining",
          )
      }
      match replacement_by_function_index.get(target) {
        Some(replacement) => {
          let call_span_len = (span.end_ - span.start).reinterpret_as_uint()
          let replacement_len = replacement.length().reinterpret_as_uint()
          if replacement_len <= call_span_len {
            out.append(replacement[:].to_array())
            rewritten_call_count += 1U
          } else {
            out.append(instr_bytes[span.start:span.end_].to_array())
          }
        }
        None => out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
priv struct InliningApplyResult {
  bytes : Bytes
  inlined_call_count : UInt
}

///|
fn apply_inlining_optimizing(bytes : Bytes) -> InliningApplyResult {
  let result = try? apply_inlining_optimizing_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, inlined_call_count: 0U }
  }
}

///|
fn apply_inlining_optimizing_raise(
  bytes : Bytes,
) -> InliningApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  let mut imported_function_count = 0U
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      2U => imported_function_count += parse_import_function_count(payload)
      3U => function_section_payload = Some(payload)
      10U => code_section_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, inlined_call_count: 0U }
  }
  let function_payload = match function_section_payload {
    Some(v) => v
    None => return { bytes, inlined_call_count: 0U }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, inlined_call_count: 0U }
  }
  let type_entries = parse_function_type_entries_raise(type_payload, "inlining")
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  if function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for inlining: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let type_count_u = type_entries.length().reinterpret_as_uint()
  let replacement_by_function_index : Map[UInt, Bytes] = {}
  for i in 0..<code_bodies.length() {
    let type_index = function_type_indices[i]
    if type_index >= type_count_u {
      raise WalyzeError::InvalidFormat(
        "type index out of range in inlining: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= type_entries.length() {
      raise WalyzeError::InvalidFormat(
        "type index position out of range in inlining: " +
        type_index.to_string(),
      )
    }
    match
      extract_inlining_replacement_instr_raise(
        code_bodies[i],
        type_entries[type_pos],
      ) {
      Some(replacement) =>
        replacement_by_function_index.set(
          imported_function_count + i.reinterpret_as_uint(),
          replacement,
        )
      None => ()
    }
  }
  let mut has_candidate = false
  replacement_by_function_index.each((_, _) => has_candidate = true)
  if not(has_candidate) {
    return { bytes, inlined_call_count: 0U }
  }
  let rewritten_bodies : Array[Bytes] = []
  let mut inlined_call_count = 0U
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_call_count) = rewrite_instruction_calls_for_inlining_raise(
      instr_bytes, spans, replacement_by_function_index,
    )
    inlined_call_count += rewritten_call_count
    if rewritten_call_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  if inlined_call_count == 0U {
    return { bytes, inlined_call_count: 0U }
  }
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), inlined_call_count }
}

///|
fn is_dae_pure_producer_opcode(opcode : UInt) -> Bool {
  is_drop_elidable_producer_opcode(opcode)
}

///|
fn is_dae_pure_i32_unary_opcode(opcode : UInt) -> Bool {
  opcode == 0x45U || opcode == 0x67U || opcode == 0x68U || opcode == 0x69U
}

///|
fn is_dae_pure_i32_binary_opcode(opcode : UInt) -> Bool {
  opcode == 0x46U ||
  opcode == 0x47U ||
  opcode == 0x48U ||
  opcode == 0x49U ||
  opcode == 0x4aU ||
  opcode == 0x4bU ||
  opcode == 0x4cU ||
  opcode == 0x4dU ||
  opcode == 0x4eU ||
  opcode == 0x4fU ||
  opcode == 0x50U ||
  opcode == 0x51U ||
  opcode == 0x52U ||
  opcode == 0x53U ||
  opcode == 0x54U ||
  opcode == 0x55U ||
  opcode == 0x56U ||
  opcode == 0x57U ||
  opcode == 0x58U ||
  opcode == 0x59U ||
  opcode == 0x5aU ||
  opcode == 0x5bU ||
  opcode == 0x5cU ||
  opcode == 0x5dU ||
  opcode == 0x5eU ||
  opcode == 0x5fU ||
  opcode == 0x60U ||
  opcode == 0x61U ||
  opcode == 0x62U ||
  opcode == 0x63U ||
  opcode == 0x64U ||
  opcode == 0x65U ||
  opcode == 0x66U ||
  opcode == 0x6aU ||
  opcode == 0x6bU ||
  opcode == 0x6cU ||
  opcode == 0x71U ||
  opcode == 0x72U ||
  opcode == 0x73U ||
  opcode == 0x74U ||
  opcode == 0x75U ||
  opcode == 0x76U ||
  opcode == 0x77U ||
  opcode == 0x78U
}

///|
fn rewrite_instruction_for_dae_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> (Bytes, UInt) {
  let out : Array[Byte] = []
  let mut removed_instr_count = 0U
  let mut i = 0
  while i < spans.length() {
    if i + 3 < spans.length() &&
      is_dae_pure_producer_opcode(spans[i].opcode) &&
      is_dae_pure_producer_opcode(spans[i + 1].opcode) &&
      is_dae_pure_i32_binary_opcode(spans[i + 2].opcode) &&
      spans[i + 3].opcode == 0x1aU {
      removed_instr_count += 4U
      i += 4
      continue
    }
    if i + 2 < spans.length() &&
      is_dae_pure_producer_opcode(spans[i].opcode) &&
      is_dae_pure_i32_unary_opcode(spans[i + 1].opcode) &&
      spans[i + 2].opcode == 0x1aU {
      removed_instr_count += 3U
      i += 3
      continue
    }
    if i + 1 < spans.length() &&
      is_dae_pure_producer_opcode(spans[i].opcode) &&
      spans[i + 1].opcode == 0x1aU {
      removed_instr_count += 2U
      i += 2
      continue
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  (Bytes::from_array(out[:]), removed_instr_count)
}

///|
fn apply_dae_instruction_bytes_raise(
  instr_bytes : Bytes,
) -> (Bytes, UInt) raise WalyzeError {
  let mut current = instr_bytes
  let mut removed_instr_count = 0U
  let mut rounds = 0
  while rounds < 16 {
    let spans = parse_instruction_spans_raise(current)
    let (rewritten, removed) = rewrite_instruction_for_dae_raise(current, spans)
    if removed == 0U {
      break
    }
    current = rewritten
    removed_instr_count += removed
    rounds += 1
  }
  (current, removed_instr_count)
}

///|
priv struct DaeApplyResult {
  bytes : Bytes
  removed_instr_count : UInt
}

///|
fn apply_dae_optimizing(bytes : Bytes) -> DaeApplyResult {
  let result = try? apply_dae_optimizing_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, removed_instr_count: 0U }
  }
}

///|
fn apply_dae_optimizing_raise(
  bytes : Bytes,
) -> DaeApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut code_section_payload : Bytes? = None
  for section in sections {
    if section.section_id == 10U {
      code_section_payload = Some(
        bytes[section.payload_start:section.section_end].to_bytes(),
      )
      break
    }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, removed_instr_count: 0U }
  }
  let code_bodies = parse_code_bodies(code_payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut removed_instr_count = 0U
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let (rewritten_instr, removed) = apply_dae_instruction_bytes_raise(
      instr_bytes,
    )
    removed_instr_count += removed
    if removed > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  if removed_instr_count == 0U {
    return { bytes, removed_instr_count: 0U }
  }
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), removed_instr_count }
}

///|
fn is_const_opcode(opcode : UInt) -> Bool {
  opcode == 0x41U || opcode == 0x42U || opcode == 0x43U || opcode == 0x44U
}

///|
fn is_drop_elidable_producer_opcode(opcode : UInt) -> Bool {
  is_const_opcode(opcode) ||
  opcode == 0x20U ||
  opcode == 0x23U ||
  opcode == 0xd0U ||
  opcode == 0xd2U
}

///|
fn is_drop_elidable_producer_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> Bool {
  if is_drop_elidable_producer_opcode(span.opcode) || span.opcode == 0x3fU {
    return true
  }
  if span.opcode == 0xfcU {
    match parse_prefixed_opcode_subopcode(instr_bytes, span) {
      Some(16U) => return true
      _ => ()
    }
  }
  false
}

///|
fn is_block_start_opcode(opcode : UInt) -> Bool {
  opcode == 0x02U || opcode == 0x03U || opcode == 0x04U
}

///|
fn is_branch_opcode(opcode : UInt) -> Bool {
  opcode == 0x0cU || opcode == 0x0dU || opcode == 0x0eU
}

///|
fn decode_span_u32_immediate(instr_bytes : Bytes, span : InstrSpan) -> UInt? {
  if span.end_ <= span.start + 1 {
    return None
  }
  let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
  decode_u32_leb128_bytes(imm)
}

///|
fn decode_nonnegative_i32_leb128_bytes(bytes : Bytes) -> UInt? {
  if bytes.length() == 0 || bytes.length() > 5 {
    return None
  }
  let last = bytes[bytes.length() - 1].to_uint()
  if (last & 0x80U) != 0U {
    return None
  }
  if (last & 0x40U) != 0U {
    return None
  }
  decode_u32_leb128_bytes(bytes)
}

///|
fn decode_i32_const_nonnegative_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0x41U || span.end_ <= span.start + 1 {
    return None
  }
  let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
  decode_nonnegative_i32_leb128_bytes(imm)
}

///|
fn decode_i32_const_small_nonnegative_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.end_ != span.start + 2 {
    return None
  }
  match decode_i32_const_nonnegative_from_span(instr_bytes, span) {
    Some(value) => if value <= 63U { Some(value) } else { None }
    None => None
  }
}

///|
fn decode_i32_const_small_signed_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> Int? {
  if span.opcode != 0x41U || span.end_ != span.start + 2 {
    return None
  }
  let raw = instr_bytes[span.start + 1].to_uint()
  if (raw & 0x80U) != 0U {
    return None
  }
  if (raw & 0x40U) == 0U {
    Some(raw.reinterpret_as_int())
  } else {
    Some(raw.reinterpret_as_int() - 128)
  }
}

///|
fn decode_local_index_immediate_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0x20U && span.opcode != 0x21U && span.opcode != 0x22U {
    return None
  }
  decode_span_u32_immediate(instr_bytes, span)
}

///|
fn instr_spans_to_bytes(instr_bytes : Bytes, spans : Array[InstrSpan]) -> Bytes {
  let out : Array[Byte] = []
  for span in spans {
    out.append(instr_bytes[span.start:span.end_].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn append_i32_const_small(out : Array[Byte], value : UInt) -> Unit {
  out.push(0x41U.to_byte())
  out.push(value.to_byte())
}

///|
fn is_i32_shift_rotate_opcode(opcode : UInt) -> Bool {
  opcode == 0x74U || // i32.shl
  opcode == 0x75U || // i32.shr_s
  opcode == 0x76U || // i32.shr_u
  opcode == 0x77U || // i32.rotl
  opcode == 0x78U // i32.rotr
}

///|
fn is_optimize_instructions_i32_identity_opcode(
  rhs_const : UInt,
  opcode : UInt,
) -> Bool {
  if is_i32_shift_rotate_opcode(opcode) && rhs_const % 32U == 0U {
    return true
  }
  match rhs_const {
    0U =>
      opcode == 0x6aU || // i32.add
      opcode == 0x6bU || // i32.sub
      opcode == 0x72U || // i32.or
      opcode == 0x73U || // i32.xor
      is_i32_shift_rotate_opcode(opcode)
    1U => opcode == 0x6cU // i32.mul
    _ => false
  }
}

///|
fn apply_optimize_instructions_i32_identity_ops(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() && spans[i].opcode == 0x41U {
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i]) {
        Some(-1) =>
          if spans[i + 1].opcode == 0x71U {
            i += 2
            continue
          }
        _ => ()
      }
    }
    if i + 1 < spans.length() && spans[i].opcode == 0x41U {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(rhs_const) =>
          if is_optimize_instructions_i32_identity_opcode(
              rhs_const,
              spans[i + 1].opcode,
            ) {
            i += 2
            continue
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn is_optimize_instructions_i32_get_opcode(opcode : UInt) -> Bool {
  opcode == 0x20U || opcode == 0x23U
}

///|
fn apply_optimize_instructions_i32_const_cmp_bitwise(
  instr_bytes : Bytes,
) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      is_optimize_instructions_i32_get_opcode(spans[i].opcode) &&
      spans[i + 1].opcode == 0x41U {
      let lhs = instr_bytes[spans[i].start:spans[i].end_]
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i + 1]) {
        Some(0U) =>
          match spans[i + 2].opcode {
            0x71U
            // i32.and
            | 0x49U => { // i32.lt_u
              append_i32_const_small(out, 0U)
              i += 3
              continue
            }
            0x4fU => { // i32.ge_u
              append_i32_const_small(out, 1U)
              i += 3
              continue
            }
            0x46U | 0x4dU => { // i32.eq / i32.le_u => i32.eqz
              out.append(lhs.to_array())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            0x47U | 0x4bU => { // i32.ne / i32.gt_u => i32.eqz; i32.eqz
              out.append(lhs.to_array())
              out.push(0x45U.to_byte())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            _ => ()
          }
        _ => ()
      }
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i + 1]) {
        Some(-1) =>
          if spans[i + 2].opcode == 0x71U {
            // x & -1 => x
            out.append(lhs.to_array())
            i += 3
            continue
          }
        _ => ()
      }
    }
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x41U &&
      is_optimize_instructions_i32_get_opcode(spans[i + 1].opcode) {
      let rhs = instr_bytes[spans[i + 1].start:spans[i + 1].end_]
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(0U) =>
          match spans[i + 2].opcode {
            0x71U
            // i32.and
            | 0x6cU
            // i32.mul
            | 0x74U
            // i32.shl
            | 0x75U
            // i32.shr_s
            | 0x76U
            // i32.shr_u
            | 0x77U
            // i32.rotl
            | 0x78U => { // i32.rotr
              append_i32_const_small(out, 0U)
              i += 3
              continue
            }
            0x6aU | 0x72U | 0x73U => {
              // 0 + x / 0 | x / 0 ^ x => x
              out.append(rhs.to_array())
              i += 3
              continue
            }
            0x46U => { // 0 == x => x.eqz
              out.append(rhs.to_array())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            0x47U => { // 0 != x => x.eqz; i32.eqz
              out.append(rhs.to_array())
              out.push(0x45U.to_byte())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            _ => ()
          }
        Some(1U) =>
          if spans[i + 2].opcode == 0x6cU {
            // 1 * x => x
            out.append(rhs.to_array())
            i += 3
            continue
          }
        _ => ()
      }
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i]) {
        Some(-1) =>
          match spans[i + 2].opcode {
            0x71U => {
              // -1 & x => x
              out.append(rhs.to_array())
              i += 3
              continue
            }
            0x72U => {
              // -1 | x => -1
              out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
              i += 3
              continue
            }
            _ => ()
          }
        _ => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_optimize_instructions_same_local_get_pair(
  instr_bytes : Bytes,
) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(first_local) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(second_local) =>
              if first_local == second_local {
                match spans[i + 2].opcode {
                  0x71U | 0x72U => {
                    // local.get x; local.get x; i32.and/or => local.get x
                    out.append(
                      instr_bytes[spans[i].start:spans[i].end_].to_array(),
                    )
                    i += 3
                    continue
                  }
                  0x46U | 0x4cU | 0x4dU | 0x4eU | 0x4fU => {
                    // x==x / x<=x / x>=x => 1
                    append_i32_const_small(out, 1U)
                    i += 3
                    continue
                  }
                  0x47U | 0x48U | 0x49U | 0x4aU | 0x4bU | 0x6bU | 0x73U => {
                    // x!=x / x<x / x>x / x-x / x^x => 0
                    append_i32_const_small(out, 0U)
                    i += 3
                    continue
                  }
                  _ => ()
                }
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_i32_add(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x41U &&
      spans[i + 2].opcode == 0x6aU {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(lhs) =>
          match
            decode_i32_const_small_nonnegative_from_span(
              instr_bytes,
              spans[i + 1],
            ) {
            Some(rhs) => {
              let sum = lhs + rhs
              if sum <= 63U {
                out.push(0x41U.to_byte())
                out.push(sum.to_byte())
                i += 3
                continue
              }
            }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_i32_identity_ops(instr_bytes : Bytes) -> Bytes {
  apply_optimize_instructions_i32_identity_ops(instr_bytes)
}

///|
fn apply_precompute_i32_eqz_const(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x45U {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(value) => {
          append_i32_const_small(out, if value == 0U { 1U } else { 0U })
          i += 2
          continue
        }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_i32_double_eqz_br_if(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x45U &&
      spans[i + 1].opcode == 0x45U &&
      spans[i + 2].opcode == 0x0dU {
      out.append(instr_bytes[spans[i + 2].start:spans[i + 2].end_].to_array())
      i += 3
      continue
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn is_local_const_propagation_barrier(opcode : UInt) -> Bool {
  opcode == 0x00U || // unreachable
  opcode == 0x02U || // block
  opcode == 0x03U || // loop
  opcode == 0x04U || // if
  opcode == 0x05U || // else
  opcode == 0x0bU || // end
  opcode == 0x0cU || // br
  opcode == 0x0dU || // br_if
  opcode == 0x0eU || // br_table
  opcode == 0x0fU
}

///|
fn known_local_const_get(known : Map[UInt, UInt], local_index : UInt) -> UInt? {
  match known.get(local_index) {
    Some(value) => if value == 0xffffffffU { None } else { Some(value) }
    None => None
  }
}

///|
fn apply_precompute_local_const_propagation(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut known_local_consts : Map[UInt, UInt] = {}
  for i in 0..<spans.length() {
    let span = spans[i]
    if span.opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, span) {
        Some(local_index) => {
          let mut adjacent_set_same_local = false
          if i > 0 && spans[i - 1].opcode == 0x21U {
            match
              decode_local_index_immediate_from_span(instr_bytes, spans[i - 1]) {
              Some(prev_set_index) =>
                if prev_set_index == local_index {
                  adjacent_set_same_local = true
                }
              None => ()
            }
          }
          if not(adjacent_set_same_local) {
            match known_local_const_get(known_local_consts, local_index) {
              Some(value) => {
                append_i32_const_small(out, value)
                if is_local_const_propagation_barrier(span.opcode) {
                  known_local_consts = {}
                }
                continue
              }
              None => ()
            }
          }
        }
        None => ()
      }
    } else if span.opcode == 0x21U || span.opcode == 0x22U {
      match decode_local_index_immediate_from_span(instr_bytes, span) {
        Some(local_index) => {
          let mut assigned_const : UInt? = None
          if i > 0 {
            assigned_const = decode_i32_const_small_nonnegative_from_span(
              instr_bytes,
              spans[i - 1],
            )
          }
          match assigned_const {
            Some(value) => known_local_consts.set(local_index, value)
            None => known_local_consts.set(local_index, 0xffffffffU)
          }
        }
        None => ()
      }
    }
    out.append(instr_bytes[span.start:span.end_].to_array())
    if is_local_const_propagation_barrier(span.opcode) {
      known_local_consts = {}
    }
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_br_if_const(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x0dU {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(0U) => {
          i += 2
          continue
        }
        Some(_) =>
          if spans[i + 1].end_ > spans[i + 1].start + 1 {
            out.push(0x0cU.to_byte())
            out.append(
              instr_bytes[spans[i + 1].start + 1:spans[i + 1].end_].to_array(),
            )
            i += 2
            continue
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_set_get_to_tee(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x21U &&
      spans[i + 1].opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(set_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(get_index) =>
              if set_index == get_index && spans[i].end_ > spans[i].start + 1 {
                out.push(0x22U.to_byte())
                out.append(
                  instr_bytes[spans[i].start + 1:spans[i].end_].to_array(),
                )
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_get_set_noop(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x21U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(get_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(set_index) =>
              if get_index == set_index {
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_get_tee_to_get(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x22U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(get_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(tee_index) =>
              if get_index == tee_index {
                out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_local_cse_get_set_get(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x21U &&
      spans[i + 2].opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(first_get_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 2]) {
            Some(second_get_index) =>
              if first_get_index == second_get_index &&
                spans[i + 1].end_ > spans[i + 1].start + 1 {
                out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
                out.push(0x22U.to_byte())
                out.append(
                  instr_bytes[spans[i + 1].start + 1:spans[i + 1].end_].to_array(),
                )
                i += 3
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_tee_drop_to_set(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x22U &&
      spans[i + 1].opcode == 0x1aU &&
      spans[i].end_ > spans[i].start + 1 {
      out.push(0x21U.to_byte())
      out.append(instr_bytes[spans[i].start + 1:spans[i].end_].to_array())
      i += 2
      continue
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_rse_local_tee_set_same(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x22U &&
      spans[i + 1].opcode == 0x21U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(tee_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(set_index) =>
              if tee_index == set_index && spans[i].end_ > spans[i].start + 1 {
                out.push(0x21U.to_byte())
                out.append(
                  instr_bytes[spans[i].start + 1:spans[i].end_].to_array(),
                )
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_basic_peephole_to_spans(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  config : OptimizeConfig,
) -> Array[InstrSpan] {
  let out : Array[InstrSpan] = []
  let mut i = 0
  while i < spans.length() {
    let span = spans[i]
    if config.peephole_remove_nop && span.opcode == 0x01U {
      i += 1
      continue
    }
    if config.peephole_remove_const_drop &&
      i + 1 < spans.length() &&
      is_drop_elidable_producer_span(instr_bytes, span) &&
      spans[i + 1].opcode == 0x1aU {
      i += 2
      continue
    }
    out.push(span)
    i += 1
  }
  out
}

///|
fn apply_vacuum_to_spans(spans : Array[InstrSpan]) -> Array[InstrSpan] {
  let out : Array[InstrSpan] = []
  let mut dead = false
  let mut dead_depth = 0
  for span in spans {
    if dead {
      match span.opcode {
        0x02U | 0x03U | 0x04U => dead_depth += 1
        0x05U =>
          if dead_depth == 0 {
            out.push(span)
            dead = false
          }
        0x0bU =>
          if dead_depth == 0 {
            out.push(span)
            dead = false
          } else {
            dead_depth -= 1
          }
        _ => ()
      }
      continue
    }
    out.push(span)
    if span.opcode == 0x00U || span.opcode == 0x0fU || span.opcode == 0x0cU {
      dead = true
      dead_depth = 0
    }
  }
  out
}

///|
fn compute_matching_end_indices(spans : Array[InstrSpan]) -> Map[Int, Int] {
  let out : Map[Int, Int] = {}
  let stack : Array[Int] = []
  for i in 0..<spans.length() {
    let opcode = spans[i].opcode
    if is_block_start_opcode(opcode) {
      stack.push(i)
    } else if opcode == 0x0bU && stack.length() > 0 {
      let start = stack[stack.length() - 1]
      ignore(stack.pop())
      out.set(start, i)
    }
  }
  out
}

///|
fn has_branch_between(
  spans : Array[InstrSpan],
  start : Int,
  end_ : Int,
) -> Bool {
  for i in start..<end_ {
    if is_branch_opcode(spans[i].opcode) {
      return true
    }
  }
  false
}

///|
fn apply_merge_blocks_to_spans(spans : Array[InstrSpan]) -> Array[InstrSpan] {
  let matching_end = compute_matching_end_indices(spans)
  let remove : Array[Bool] = []
  for _ in 0..<spans.length() {
    remove.push(false)
  }
  for i in 0..<spans.length() {
    let opcode = spans[i].opcode
    if opcode == 0x02U || opcode == 0x03U {
      match matching_end.get(i) {
        Some(end_index) =>
          if not(has_branch_between(spans, i + 1, end_index)) {
            remove[i] = true
            remove[end_index] = true
          }
        None => ()
      }
    }
  }
  let out : Array[InstrSpan] = []
  for i in 0..<spans.length() {
    if not(remove[i]) {
      out.push(spans[i])
    }
  }
  out
}

///|
fn apply_remove_unused_brs_to_spans(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[InstrSpan] {
  let out : Array[InstrSpan] = []
  let label_stack : Array[Int] = [1]
  for i in 0..<spans.length() {
    let span = spans[i]
    let top_label = if label_stack.length() > 0 {
      label_stack[label_stack.length() - 1]
    } else {
      1
    }
    let mut remove_current = false
    if span.opcode == 0x0cU &&
      i + 1 < spans.length() &&
      spans[i + 1].opcode == 0x0bU &&
      top_label != 2 {
      if decode_span_u32_immediate(instr_bytes, span) is Some(0U) {
        remove_current = true
      }
    }
    if not(remove_current) {
      out.push(span)
    }
    match span.opcode {
      0x02U => label_stack.push(1)
      0x03U => label_stack.push(2)
      0x04U => label_stack.push(1)
      0x0bU => if label_stack.length() > 0 { ignore(label_stack.pop()) }
      _ => ()
    }
  }
  out
}

///|
fn optimize_instruction_bytes(
  instr_bytes : Bytes,
  config : OptimizeConfig,
) -> Bytes {
  let mut current_bytes = instr_bytes
  if config.enable_peephole {
    let mut local_simplify_round = 0
    while local_simplify_round < 6 {
      let before_local_simplify = current_bytes
      current_bytes = apply_precompute_i32_add(current_bytes)
      current_bytes = apply_precompute_i32_identity_ops(current_bytes)
      current_bytes = apply_precompute_i32_eqz_const(current_bytes)
      current_bytes = apply_precompute_i32_double_eqz_br_if(current_bytes)
      current_bytes = apply_precompute_local_const_propagation(current_bytes)
      current_bytes = apply_precompute_i32_add(current_bytes)
      current_bytes = apply_precompute_i32_double_eqz_br_if(current_bytes)
      current_bytes = apply_precompute_br_if_const(current_bytes)
      current_bytes = apply_optimize_instructions_i32_identity_ops(
        current_bytes,
      )
      current_bytes = apply_optimize_instructions_i32_const_cmp_bitwise(
        current_bytes,
      )
      current_bytes = apply_optimize_instructions_same_local_get_pair(
        current_bytes,
      )
      current_bytes = apply_simplify_local_set_get_to_tee(current_bytes)
      current_bytes = apply_simplify_local_tee_drop_to_set(current_bytes)
      current_bytes = apply_rse_local_tee_set_same(current_bytes)
      current_bytes = apply_simplify_local_get_set_noop(current_bytes)
      current_bytes = apply_simplify_local_get_tee_to_get(current_bytes)
      current_bytes = apply_local_cse_get_set_get(current_bytes)
      current_bytes = apply_simplify_local_tee_drop_to_set(current_bytes)
      current_bytes = apply_rse_local_tee_set_same(current_bytes)
      if bytes_equal(before_local_simplify, current_bytes) {
        break
      }
      local_simplify_round += 1
    }
  }
  let spans = match parse_instruction_spans(current_bytes) {
    Some(v) => v
    None => return current_bytes
  }
  let mut current = spans.copy()
  if config.enable_vacuum {
    current = apply_vacuum_to_spans(current)
  }
  if config.peephole_remove_nop || config.peephole_remove_const_drop {
    current = apply_basic_peephole_to_spans(current_bytes, current, config)
  }
  if config.enable_remove_unused_brs {
    current = apply_remove_unused_brs_to_spans(current_bytes, current)
  }
  if config.enable_merge_blocks {
    current = apply_merge_blocks_to_spans(current)
  }
  if config.enable_vacuum {
    current = apply_vacuum_to_spans(current)
  }
  instr_spans_to_bytes(current_bytes, current)
}

///|
priv struct LocalDeclPrefixParseResult {
  prefix_end : Int
  local_types : Array[Byte]
}

///|
fn parse_local_decl_prefix_raise(
  body_bytes : Bytes,
) -> LocalDeclPrefixParseResult raise WalyzeError {
  let parser = Cursor::new(body_bytes)
  let local_group_count = parser.read_u32_leb128()
  let local_types : Array[Byte] = []
  for _ in 0U..<local_group_count {
    let count = parser.read_u32_leb128()
    let val_type = parser.read_byte()
    for _ in 0U..<count {
      local_types.push(val_type)
    }
  }
  { prefix_end: parser.get_pos(), local_types }
}

///|
fn parse_local_decl_prefix_end(body_bytes : Bytes) -> Int raise WalyzeError {
  parse_local_decl_prefix_raise(body_bytes).prefix_end
}

///|
fn encode_local_decl_prefix_from_local_types(
  local_types : Array[Byte],
) -> Bytes {
  let out : Array[Byte] = []
  if local_types.length() == 0 {
    out.append(encode_u32_leb128(0U)[:])
    return Bytes::from_array(out[:])
  }
  let counts : Array[UInt] = []
  let values : Array[Byte] = []
  let mut current = local_types[0]
  let mut current_count = 1U
  for i in 1..<local_types.length() {
    let v = local_types[i]
    if v == current {
      current_count += 1U
    } else {
      counts.push(current_count)
      values.push(current)
      current = v
      current_count = 1U
    }
  }
  counts.push(current_count)
  values.push(current)
  out.append(encode_u32_leb128(counts.length().reinterpret_as_uint())[:])
  for i in 0..<counts.length() {
    out.append(encode_u32_leb128(counts[i])[:])
    out.push(values[i])
  }
  Bytes::from_array(out[:])
}

///|
fn optimize_code_body_bytes(
  body_bytes : Bytes,
  config : OptimizeConfig,
) -> Bytes {
  let prefix_result = try? parse_local_decl_prefix_end(body_bytes)
  let prefix_end = match prefix_result {
    Ok(v) => v
    Err(_) => return body_bytes
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let optimized_instr = optimize_instruction_bytes(instr_bytes, config)
  if optimized_instr.length() >= instr_bytes.length() {
    return body_bytes
  }
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(optimized_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn optimize_code_section_payload_raise(
  payload : Bytes,
  config : OptimizeConfig,
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let bodies : Array[Bytes] = []
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WalyzeError::InvalidFormat("code body size overflow")
    }
    let start = parser.get_pos()
    let end_ = start + body_size
    if end_ > payload.length() {
      raise WalyzeError::UnexpectedEof
    }
    let body_bytes = payload[start:end_].to_bytes()
    bodies.push(optimize_code_body_bytes(body_bytes, config))
    parser.set_pos(end_)
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(body_count)[:])
  for body in bodies {
    out.append(encode_u32_leb128(body.length().reinterpret_as_uint())[:])
    out.append(body[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn optimize_code_section_payload(
  payload : Bytes,
  config : OptimizeConfig,
) -> Bytes {
  let result = try? optimize_code_section_payload_raise(payload, config)
  match result {
    Ok(v) => v
    Err(_) => payload
  }
}

///|
fn collect_used_local_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WalyzeError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode local immediate in coalesce-locals",
          )
      }
    }
  }
  out
}

///|
fn rewrite_instruction_local_indices_for_coalesce_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  param_count : UInt,
  local_index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid local immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let old_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode local index immediate in coalesce-locals",
          )
      }
      let new_index = if old_index < param_count {
        old_index
      } else {
        match local_index_map.get(old_index) {
          Some(v) => v
          None =>
            raise WalyzeError::InvalidFormat(
              "coalesce-locals remap missing local index: " +
              old_index.to_string(),
            )
        }
      }
      out.push(span.opcode.to_byte())
      out.append(encode_u32_leb128(new_index)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
priv struct CoalesceLocalsApplyResult {
  bytes : Bytes
  removed_local_count : UInt
}

///|
fn apply_coalesce_locals_raise(
  bytes : Bytes,
) -> CoalesceLocalsApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      3U => function_section_payload = Some(payload)
      10U => code_section_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, removed_local_count: 0U }
  }
  let function_payload = match function_section_payload {
    Some(v) => v
    None => return { bytes, removed_local_count: 0U }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, removed_local_count: 0U }
  }
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  if function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for coalesce-locals: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let type_entries = parse_function_type_entries_raise(
    type_payload, "coalesce-locals",
  )
  let rewritten_code_bodies = code_bodies.copy()
  let mut removed_local_count = 0U
  for i in 0..<code_bodies.length() {
    let type_index = function_type_indices[i]
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= type_entries.length() {
      raise WalyzeError::InvalidFormat(
        "type index out of range in coalesce-locals: " + type_index.to_string(),
      )
    }
    let param_count = type_entries[type_pos].params
      .length()
      .reinterpret_as_uint()
    let body = code_bodies[i]
    let prefix = parse_local_decl_prefix_raise(body)
    if prefix.local_types.length() == 0 {
      continue
    }
    let instr_bytes = body[prefix.prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let used_local_indices = collect_used_local_indices_from_instruction_raise(
      instr_bytes, spans,
    )
    let kept_local_types : Array[Byte] = []
    let local_index_map : Map[UInt, UInt] = {}
    let mut next_local = 0U
    for j in 0..<prefix.local_types.length() {
      let old_local_index = param_count + j.reinterpret_as_uint()
      if used_local_indices.contains(old_local_index) {
        let new_local_index = param_count + next_local
        local_index_map.set(old_local_index, new_local_index)
        kept_local_types.push(prefix.local_types[j])
        next_local += 1U
      }
    }
    if kept_local_types.length() == prefix.local_types.length() {
      continue
    }
    removed_local_count += (prefix.local_types.length() -
    kept_local_types.length()).reinterpret_as_uint()
    let rewritten_instr = rewrite_instruction_local_indices_for_coalesce_raise(
      instr_bytes, spans, param_count, local_index_map,
    )
    let rewritten_prefix = encode_local_decl_prefix_from_local_types(
      kept_local_types,
    )
    let rewritten_body : Array[Byte] = rewritten_prefix[:].to_array()
    rewritten_body.append(rewritten_instr[:].to_array())
    rewritten_code_bodies[i] = Bytes::from_array(rewritten_body[:])
  }
  if removed_local_count == 0U {
    return { bytes, removed_local_count }
  }
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_code_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), removed_local_count }
}

///|
fn apply_duplicate_import_elimination(
  bytes : Bytes,
) -> DuplicateImportElimApplyResult {
  let result = try? apply_duplicate_import_elimination_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) =>
      {
        bytes,
        removed_import_count: 0U,
        removed_function_import_count: 0U,
        removed_table_import_count: 0U,
        removed_memory_import_count: 0U,
        removed_global_import_count: 0U,
        dropped_name_section: false,
      }
  }
}

///|
fn apply_duplicate_import_elimination_raise(
  bytes : Bytes,
) -> DuplicateImportElimApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut table_section_payload : Bytes? = None
  let mut memory_section_payload : Bytes? = None
  let mut global_section_payload : Bytes? = None
  let mut element_section_payload : Bytes? = None
  let mut data_section_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_section_payload = Some(payload)
      3U => function_section_payload = Some(payload)
      4U => table_section_payload = Some(payload)
      5U => memory_section_payload = Some(payload)
      6U => global_section_payload = Some(payload)
      9U => element_section_payload = Some(payload)
      11U => data_section_payload = Some(payload)
      _ => ()
    }
  }
  let import_payload = match import_section_payload {
    Some(v) => v
    None =>
      return {
        bytes,
        removed_import_count: 0U,
        removed_function_import_count: 0U,
        removed_table_import_count: 0U,
        removed_memory_import_count: 0U,
        removed_global_import_count: 0U,
        dropped_name_section: false,
      }
  }
  let import_entries = parse_import_section_entries_raise(import_payload)
  if import_entries.length() <= 1 {
    return {
      bytes,
      removed_import_count: 0U,
      removed_function_import_count: 0U,
      removed_table_import_count: 0U,
      removed_memory_import_count: 0U,
      removed_global_import_count: 0U,
      dropped_name_section: false,
    }
  }
  let mut imported_function_count = 0U
  let mut imported_table_count = 0U
  let mut imported_memory_count = 0U
  let mut imported_global_count = 0U
  for entry in import_entries {
    match entry.kind {
      0U => imported_function_count += 1U
      1U => imported_table_count += 1U
      2U => imported_memory_count += 1U
      3U => imported_global_count += 1U
      _ => ()
    }
  }
  let keep_function_imports : Array[Bool] = []
  for _ in 0U..<imported_function_count {
    keep_function_imports.push(true)
  }
  let keep_table_imports : Array[Bool] = []
  for _ in 0U..<imported_table_count {
    keep_table_imports.push(true)
  }
  let keep_memory_imports : Array[Bool] = []
  for _ in 0U..<imported_memory_count {
    keep_memory_imports.push(true)
  }
  let keep_global_imports : Array[Bool] = []
  for _ in 0U..<imported_global_count {
    keep_global_imports.push(true)
  }
  let unique_function_import_entries : Array[Bytes] = []
  let unique_function_import_indices : Array[UInt] = []
  let canonical_function_import_index : Map[UInt, UInt] = {}
  let unique_table_import_entries : Array[Bytes] = []
  let unique_table_import_indices : Array[UInt] = []
  let canonical_table_import_index : Map[UInt, UInt] = {}
  let unique_memory_import_entries : Array[Bytes] = []
  let unique_memory_import_indices : Array[UInt] = []
  let canonical_memory_import_index : Map[UInt, UInt] = {}
  let unique_global_import_entries : Array[Bytes] = []
  let unique_global_import_indices : Array[UInt] = []
  let canonical_global_import_index : Map[UInt, UInt] = {}
  let mut removed_function_import_count = 0U
  let mut removed_table_import_count = 0U
  let mut removed_memory_import_count = 0U
  let mut removed_global_import_count = 0U
  for entry in import_entries {
    match entry.kind {
      0U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_function_import_entries.length() {
          if bytes_equal(unique_function_import_entries[i], entry.bytes) {
            canonical = unique_function_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_function_import_entries.push(entry.bytes)
          unique_function_import_indices.push(entry.kind_index)
        }
        canonical_function_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_function_imports.length() {
            raise WalyzeError::InvalidFormat(
              "function import dedupe index out of range",
            )
          }
          keep_function_imports[old_pos] = false
          removed_function_import_count += 1U
        }
      }
      1U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_table_import_entries.length() {
          if bytes_equal(unique_table_import_entries[i], entry.bytes) {
            canonical = unique_table_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_table_import_entries.push(entry.bytes)
          unique_table_import_indices.push(entry.kind_index)
        }
        canonical_table_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_table_imports.length() {
            raise WalyzeError::InvalidFormat(
              "table import dedupe index out of range",
            )
          }
          keep_table_imports[old_pos] = false
          removed_table_import_count += 1U
        }
      }
      2U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_memory_import_entries.length() {
          if bytes_equal(unique_memory_import_entries[i], entry.bytes) {
            canonical = unique_memory_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_memory_import_entries.push(entry.bytes)
          unique_memory_import_indices.push(entry.kind_index)
        }
        canonical_memory_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_memory_imports.length() {
            raise WalyzeError::InvalidFormat(
              "memory import dedupe index out of range",
            )
          }
          keep_memory_imports[old_pos] = false
          removed_memory_import_count += 1U
        }
      }
      3U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_global_import_entries.length() {
          if bytes_equal(unique_global_import_entries[i], entry.bytes) {
            canonical = unique_global_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_global_import_entries.push(entry.bytes)
          unique_global_import_indices.push(entry.kind_index)
        }
        canonical_global_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_global_imports.length() {
            raise WalyzeError::InvalidFormat(
              "global import dedupe index out of range",
            )
          }
          keep_global_imports[old_pos] = false
          removed_global_import_count += 1U
        }
      }
      _ => ()
    }
  }
  let removed_import_count = removed_function_import_count +
    removed_table_import_count +
    removed_memory_import_count +
    removed_global_import_count
  if removed_import_count == 0U {
    return {
      bytes,
      removed_import_count: 0U,
      removed_function_import_count: 0U,
      removed_table_import_count: 0U,
      removed_memory_import_count: 0U,
      removed_global_import_count: 0U,
      dropped_name_section: false,
    }
  }
  let local_function_count = match function_section_payload {
    Some(payload) => parse_vec_count(payload)
    None => 0U
  }
  let local_table_count = match table_section_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_memory_count = match memory_section_payload {
    Some(payload) =>
      parse_memory_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_global_count = match global_section_payload {
    Some(payload) =>
      parse_global_section_entries_with_refs_raise(payload)
      .length()
      .reinterpret_as_uint()
    None => 0U
  }
  let function_index_map : Map[UInt, UInt] = {}
  let mut kept_function_import_count = 0U
  for i in 0U..<imported_function_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_function_imports.length() {
      raise WalyzeError::InvalidFormat(
        "function import keep index out of range in dedupe map",
      )
    }
    if keep_function_imports[i_pos] {
      function_index_map.set(i, kept_function_import_count)
      kept_function_import_count += 1U
    }
  }
  for i in 0U..<imported_function_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_function_imports.length() {
      raise WalyzeError::InvalidFormat(
        "function import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_function_imports[i_pos]) {
      let canonical = match canonical_function_import_index.get(i) {
        Some(v) => v
        None => i
      }
      function_index_map.set(
        i,
        remap_function_index_raise(canonical, function_index_map),
      )
    }
  }
  for i in 0U..<local_function_count {
    let old_index = imported_function_count + i
    function_index_map.set(old_index, kept_function_import_count + i)
  }
  let table_index_map : Map[UInt, UInt] = {}
  let mut kept_table_import_count = 0U
  for i in 0U..<imported_table_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_table_imports.length() {
      raise WalyzeError::InvalidFormat(
        "table import keep index out of range in dedupe map",
      )
    }
    if keep_table_imports[i_pos] {
      table_index_map.set(i, kept_table_import_count)
      kept_table_import_count += 1U
    }
  }
  for i in 0U..<imported_table_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_table_imports.length() {
      raise WalyzeError::InvalidFormat(
        "table import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_table_imports[i_pos]) {
      let canonical = match canonical_table_import_index.get(i) {
        Some(v) => v
        None => i
      }
      table_index_map.set(
        i,
        remap_table_index_raise(canonical, table_index_map),
      )
    }
  }
  for i in 0U..<local_table_count {
    let old_index = imported_table_count + i
    table_index_map.set(old_index, kept_table_import_count + i)
  }
  let memory_index_map : Map[UInt, UInt] = {}
  let mut kept_memory_import_count = 0U
  for i in 0U..<imported_memory_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_memory_imports.length() {
      raise WalyzeError::InvalidFormat(
        "memory import keep index out of range in dedupe map",
      )
    }
    if keep_memory_imports[i_pos] {
      memory_index_map.set(i, kept_memory_import_count)
      kept_memory_import_count += 1U
    }
  }
  for i in 0U..<imported_memory_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_memory_imports.length() {
      raise WalyzeError::InvalidFormat(
        "memory import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_memory_imports[i_pos]) {
      let canonical = match canonical_memory_import_index.get(i) {
        Some(v) => v
        None => i
      }
      memory_index_map.set(
        i,
        remap_memory_index_raise(canonical, memory_index_map),
      )
    }
  }
  for i in 0U..<local_memory_count {
    let old_index = imported_memory_count + i
    memory_index_map.set(old_index, kept_memory_import_count + i)
  }
  let global_index_map : Map[UInt, UInt] = {}
  let mut kept_global_import_count = 0U
  for i in 0U..<imported_global_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_global_imports.length() {
      raise WalyzeError::InvalidFormat(
        "global import keep index out of range in dedupe map",
      )
    }
    if keep_global_imports[i_pos] {
      global_index_map.set(i, kept_global_import_count)
      kept_global_import_count += 1U
    }
  }
  for i in 0U..<imported_global_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_global_imports.length() {
      raise WalyzeError::InvalidFormat(
        "global import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_global_imports[i_pos]) {
      let canonical = match canonical_global_import_index.get(i) {
        Some(v) => v
        None => i
      }
      global_index_map.set(
        i,
        remap_global_index_raise(canonical, global_index_map),
      )
    }
  }
  for i in 0U..<local_global_count {
    let old_index = imported_global_count + i
    global_index_map.set(old_index, kept_global_import_count + i)
  }
  let keep_local_functions : Array[Bool] = []
  for _ in 0U..<local_function_count {
    keep_local_functions.push(true)
  }
  let keep_local_globals : Array[Bool] = []
  for _ in 0U..<local_global_count {
    keep_local_globals.push(true)
  }
  let element_index_map = match element_section_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let data_index_map = match data_section_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let (rewritten_import_payload, removed_by_rewrite) = rewrite_import_section_payload_for_keep_kinds_raise(
    import_payload, keep_function_imports, keep_table_imports, keep_memory_imports,
    keep_global_imports,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U =>
        if parse_vec_count(rewritten_import_payload) > 0U {
          append_encoded_section(out, 2U, rewritten_import_payload)
        }
      6U => {
        let rewritten_function = rewrite_global_section_payload_for_index_map_raise(
          payload, function_index_map,
        )
        let rewritten = rewrite_global_section_payload_for_keep_local_and_global_index_map_raise(
          rewritten_function, keep_local_globals, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 6U, rewritten)
        }
      }
      7U => {
        let rewritten_function = rewrite_export_section_payload_for_dce_raise(
          payload, function_index_map,
        )
        let (rewritten, _) = rewrite_export_section_payload_for_module_index_maps_raise(
          rewritten_function, table_index_map, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 7U, rewritten)
        }
      }
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(
            payload, function_index_map,
          ),
        )
      9U => {
        let rewritten_function = rewrite_element_section_payload_for_index_map_raise(
          payload, function_index_map,
        )
        let (rewritten, _, _) = rewrite_element_section_payload_for_table_index_map_raise(
          rewritten_function, table_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 9U, rewritten)
        }
      }
      10U => {
        let rewritten_function = rewrite_code_section_payload_for_dce_raise(
          payload, keep_local_functions, function_index_map,
        )
        let rewritten = rewrite_code_section_payload_for_module_index_map_raise(
          rewritten_function, table_index_map, memory_index_map, global_index_map,
          element_index_map, data_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 10U, rewritten)
        }
      }
      11U => {
        let (rewritten, _, _) = rewrite_data_section_payload_for_memory_global_index_map_raise(
          payload, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 11U, rewritten)
        }
      }
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" && removed_function_import_count > 0U {
              dropped_name_section = true
            } else {
              out.append(
                bytes[section.section_start:section.section_end].to_array(),
              )
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_import_count: removed_by_rewrite,
    removed_function_import_count,
    removed_table_import_count,
    removed_memory_import_count,
    removed_global_import_count,
    dropped_name_section,
  }
}

///|
fn decode_const_expr_i32_const_nonnegative_offset_raise(
  expr_bytes : Bytes,
) -> UInt? raise WalyzeError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  if spans.length() != 2 {
    return None
  }
  if spans[1].opcode != 0x0bU {
    return None
  }
  decode_i32_const_nonnegative_from_span(expr_bytes, spans[0])
}

///|
fn collect_static_table_function_map_from_element_section_raise(
  payload : Bytes,
  target_table_index : UInt,
) -> Map[UInt, UInt]? raise WalyzeError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let table_map : Map[UInt, UInt] = {}
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    let (table_index, offset_expr, function_count) = match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let function_count = parser.read_u32_leb128()
        (0U, offset_expr, function_count)
      }
      2U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        if parser.read_byte().to_uint() != 0U {
          return None
        }
        let function_count = parser.read_u32_leb128()
        (table_index, offset_expr, function_count)
      }
      _ => return None
    }
    let offset = match
      decode_const_expr_i32_const_nonnegative_offset_raise(offset_expr) {
      Some(v) => v
      None => return None
    }
    for i in 0U..<function_count {
      let function_index = parser.read_u32_leb128()
      if table_index == target_table_index {
        let slot = offset + i
        if slot < offset {
          return None
        }
        match table_map.get(slot) {
          Some(prev) => if prev != function_index { return None }
          None => table_map.set(slot, function_index)
        }
      }
    }
  }
  Some(table_map)
}

///|
fn has_disallowed_table_ops_in_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Bool raise WalyzeError {
  for span in spans {
    match span.opcode {
      0x25U | 0x26U => return true
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WalyzeError::InvalidFormat(
            "invalid 0xfc immediate in directize",
          )
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        if subopcode >= 12U && subopcode <= 17U {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn rewrite_instruction_call_indirect_to_direct_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  table_map : Map[UInt, UInt],
  function_type_by_index : Array[UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x11U {
      match decode_i32_const_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(slot) =>
          if spans[i + 1].end_ > spans[i + 1].start + 1 {
            let imm = instr_bytes[spans[i + 1].start + 1:spans[i + 1].end_].to_bytes()
            match decode_call_indirect_immediate(imm) {
              Some((type_index, table_index)) =>
                if table_index == 0U {
                  match table_map.get(slot) {
                    Some(target) => {
                      let target_pos = UInt::reinterpret_as_int(target)
                      if target_pos >= 0 &&
                        target_pos < function_type_by_index.length() &&
                        function_type_by_index[target_pos] == type_index {
                        out.push(0x10U.to_byte())
                        out.append(encode_u32_leb128(target)[:])
                        rewritten_call_count += 1U
                        i += 2
                        continue
                      }
                    }
                    None => ()
                  }
                }
              None =>
                raise WalyzeError::InvalidFormat(
                  "failed to decode call_indirect immediate in directize",
                )
            }
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
fn rewrite_code_section_payload_for_directize_raise(
  payload : Bytes,
  table_map : Map[UInt, UInt],
  function_type_by_index : Array[UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_call_indirect_to_direct_raise(
      instr_bytes, spans, table_map, function_type_by_index,
    )
    rewritten_call_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_call_count,
  )
}

///|
priv struct DirectizeApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct SimplifyGlobalsApplyResult {
  bytes : Bytes
  rewritten_global_get_count : UInt
}

///|
priv struct ReorderGlobalsApplyResult {
  bytes : Bytes
  reordered_local_count : UInt
}

///|
priv struct MemoryPackingApplyResult {
  bytes : Bytes
  reordered_local_count : UInt
}

///|
fn apply_directize_raise(
  bytes : Bytes,
) -> DirectizeApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut table_payload : Bytes? = None
  let mut element_payload : Bytes? = None
  let mut export_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  let mut imported_table_count = 0U
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => {
        import_payload = Some(payload)
        let entries = parse_import_section_entries_raise(payload)
        for entry in entries {
          if entry.kind == 1U {
            imported_table_count += 1U
          }
        }
      }
      3U => function_payload = Some(payload)
      4U => table_payload = Some(payload)
      7U => export_payload = Some(payload)
      9U => element_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  if imported_table_count > 0U {
    return { bytes, rewritten_call_count: 0U }
  }
  let local_table_count = match table_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  if local_table_count != 1U {
    return { bytes, rewritten_call_count: 0U }
  }
  let exported_table_indices = match export_payload {
    Some(payload) => parse_export_table_indices(payload)
    None => []
  }
  if exported_table_indices.length() > 0 {
    return { bytes, rewritten_call_count: 0U }
  }
  let element_payload = match element_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let table_map = match
    collect_static_table_function_map_from_element_section_raise(
      element_payload, 0U,
    ) {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let mut has_table_entry = false
  table_map.each((_, _value) => has_table_entry = true)
  if not(has_table_entry) {
    return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_bodies = parse_code_bodies(code_payload)
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    if has_disallowed_table_ops_in_instruction_raise(instr_bytes, spans) {
      return { bytes, rewritten_call_count: 0U }
    }
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  if local_function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for directize: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_directize_raise(
    code_payload, table_map, function_type_by_index,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_call_count }
}

///|
fn collect_global_usage_counts_from_code_section_raise(
  payload : Bytes,
  counts : Array[UInt],
) -> Unit raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for span in spans {
      if span.opcode == 0x23U || span.opcode == 0x24U {
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => increment_index_count_in_array(counts, index)
          None =>
            raise WalyzeError::InvalidFormat(
              "failed to decode global index immediate in reorder-globals",
            )
        }
      }
    }
  }
}

///|
fn rewrite_instruction_global_get_to_i32_const_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  global_i32_const_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let out : Array[Byte] = []
  let mut rewritten_global_get_count = 0U
  for span in spans {
    if span.opcode == 0x23U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) =>
          match global_i32_const_map.get(index) {
            Some(value) => {
              let replacement : Array[Byte] = [0x41U.to_byte()]
              replacement.append(encode_nonnegative_i32_leb128(value)[:])
              if replacement.length() <= span.end_ - span.start {
                out.append(replacement[:])
                rewritten_global_get_count += 1U
                continue
              }
            }
            None => ()
          }
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode global.get immediate in simplify-globals",
          )
      }
    }
    out.append(instr_bytes[span.start:span.end_].to_array())
  }
  (Bytes::from_array(out[:]), rewritten_global_get_count)
}

///|
fn rewrite_code_section_payload_for_simplify_globals_raise(
  payload : Bytes,
  global_i32_const_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_global_get_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_global_get_to_i32_const_raise(
      instr_bytes, spans, global_i32_const_map,
    )
    rewritten_global_get_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_global_get_count,
  )
}

///|
fn apply_simplify_globals_raise(
  bytes : Bytes,
) -> SimplifyGlobalsApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut global_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_payload = Some(payload)
      6U => global_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let global_payload = match global_payload {
    Some(v) => v
    None => return { bytes, rewritten_global_get_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_global_get_count: 0U }
  }
  let import_entries = match import_payload {
    Some(payload) => parse_import_section_entries_raise(payload)
    None => []
  }
  let imported_global_count = count_import_kinds(import_entries).global_count
  let local_global_entries = parse_global_section_entries_with_refs_raise(
    global_payload,
  )
  if local_global_entries.length() == 0 {
    return { bytes, rewritten_global_get_count: 0U }
  }
  let global_i32_const_map : Map[UInt, UInt] = {}
  let mut candidate_count = 0U
  for i in 0..<local_global_entries.length() {
    let entry = local_global_entries[i]
    if entry.val_type.length() == 1 &&
      entry.val_type[0].to_uint() == 0x7fU &&
      entry.mutability.to_uint() == 0U {
      match
        decode_const_expr_i32_const_nonnegative_offset_raise(entry.init_expr) {
        Some(value) => {
          global_i32_const_map.set(
            imported_global_count + i.reinterpret_as_uint(),
            value,
          )
          candidate_count += 1U
        }
        None => ()
      }
    }
  }
  if candidate_count == 0U {
    return { bytes, rewritten_global_get_count: 0U }
  }
  let (rewritten_code_payload, rewritten_global_get_count) = rewrite_code_section_payload_for_simplify_globals_raise(
    code_payload, global_i32_const_map,
  )
  if rewritten_global_get_count == 0U {
    return { bytes, rewritten_global_get_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_global_get_count }
}

///|
fn apply_simplify_globals(bytes : Bytes) -> SimplifyGlobalsApplyResult {
  let result = try? apply_simplify_globals_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, rewritten_global_get_count: 0U }
  }
}

///|
fn apply_reorder_globals_raise(
  bytes : Bytes,
) -> ReorderGlobalsApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut table_payload : Bytes? = None
  let mut memory_payload : Bytes? = None
  let mut global_payload : Bytes? = None
  let mut export_payload : Bytes? = None
  let mut element_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  let mut data_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_payload = Some(payload)
      4U => table_payload = Some(payload)
      5U => memory_payload = Some(payload)
      6U => global_payload = Some(payload)
      7U => export_payload = Some(payload)
      9U => element_payload = Some(payload)
      10U => code_payload = Some(payload)
      11U => data_payload = Some(payload)
      _ => ()
    }
  }
  let global_payload = match global_payload {
    Some(v) => v
    None => return { bytes, reordered_local_count: 0U }
  }
  let import_entries = match import_payload {
    Some(payload) => parse_import_section_entries_raise(payload)
    None => []
  }
  let import_counts = count_import_kinds(import_entries)
  let imported_table_count = import_counts.table_count
  let imported_memory_count = import_counts.memory_count
  let imported_global_count = import_counts.global_count
  let local_global_entries = parse_global_section_entries_with_refs_raise(
    global_payload,
  )
  if local_global_entries.length() <= 1 {
    return { bytes, reordered_local_count: 0U }
  }
  // Avoid creating potentially invalid forward references across local globals.
  for entry in local_global_entries {
    for dep in entry.init_global_refs {
      if dep >= imported_global_count {
        return { bytes, reordered_local_count: 0U }
      }
    }
  }
  let local_global_count = local_global_entries.length().reinterpret_as_uint()
  let total_global_count = imported_global_count + local_global_count
  let usage_counts : Array[UInt] = []
  for _ in 0U..<total_global_count {
    usage_counts.push(0U)
  }
  match code_payload {
    Some(payload) =>
      collect_global_usage_counts_from_code_section_raise(payload, usage_counts)
    None => ()
  }
  match export_payload {
    Some(payload) =>
      for index in parse_export_global_indices(payload) {
        increment_index_count_in_array(usage_counts, index)
      }
    None => ()
  }
  match element_payload {
    Some(payload) =>
      for
        index in collect_used_global_indices_from_element_section_raise(payload) {
        increment_index_count_in_array(usage_counts, index)
      }
    None => ()
  }
  match data_payload {
    Some(payload) => {
      let (_, global_indices) = collect_used_memory_and_global_indices_from_data_section_raise(
        payload,
      )
      for index in global_indices {
        increment_index_count_in_array(usage_counts, index)
      }
    }
    None => ()
  }
  for entry in local_global_entries {
    for dep in entry.init_global_refs {
      increment_index_count_in_array(usage_counts, dep)
    }
  }
  let local_order : Array[UInt] = []
  for i in 0..<local_global_entries.length() {
    local_order.push(i.reinterpret_as_uint())
  }
  local_order.sort_by((a, b) => {
    let a_count = index_count_in_array(usage_counts, imported_global_count + a)
    let b_count = index_count_in_array(usage_counts, imported_global_count + b)
    if a_count > b_count {
      -1
    } else if a_count < b_count {
      1
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  let reordered_local_count = count_reordered_local_indices(local_order)
  if reordered_local_count == 0U {
    return { bytes, reordered_local_count: 0U }
  }
  let global_index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_global_count {
    global_index_map.set(i, i)
  }
  for new_local_pos in 0..<local_order.length() {
    let old_local_pos = local_order[new_local_pos]
    global_index_map.set(
      imported_global_count + old_local_pos,
      imported_global_count + new_local_pos.reinterpret_as_uint(),
    )
  }
  let local_table_count = match table_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_memory_count = match memory_payload {
    Some(payload) =>
      parse_memory_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let table_index_map = make_identity_index_map(
    imported_table_count + local_table_count,
  )
  let memory_index_map = make_identity_index_map(
    imported_memory_count + local_memory_count,
  )
  let element_index_map = match element_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let data_index_map = match data_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      6U => {
        let rewritten = rewrite_global_section_payload_for_local_order_and_global_index_map_raise(
          payload, local_order, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 6U, rewritten)
        }
      }
      7U => {
        let (rewritten, _) = rewrite_export_section_payload_for_module_index_maps_raise(
          payload, table_index_map, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 7U, rewritten)
        }
      }
      9U => {
        let (rewritten, _, _) = rewrite_element_section_payload_for_table_index_map_raise(
          payload, table_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 9U, rewritten)
        }
      }
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_module_index_map_raise(
            payload, table_index_map, memory_index_map, global_index_map, element_index_map,
            data_index_map,
          ),
        )
      11U => {
        let (rewritten, _, _) = rewrite_data_section_payload_for_memory_global_index_map_raise(
          payload, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 11U, rewritten)
        }
      }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), reordered_local_count }
}

///|
fn apply_reorder_globals(bytes : Bytes) -> ReorderGlobalsApplyResult {
  let result = try? apply_reorder_globals_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, reordered_local_count: 0U }
  }
}

///|
fn is_memory_index_marked_used(used_flags : Array[Bool], index : UInt) -> Bool {
  let pos = UInt::reinterpret_as_int(index)
  pos >= 0 && pos < used_flags.length() && used_flags[pos]
}

///|
fn apply_memory_packing_raise(
  bytes : Bytes,
) -> MemoryPackingApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut table_payload : Bytes? = None
  let mut memory_payload : Bytes? = None
  let mut global_payload : Bytes? = None
  let mut export_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  let mut data_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_payload = Some(payload)
      4U => table_payload = Some(payload)
      5U => memory_payload = Some(payload)
      6U => global_payload = Some(payload)
      7U => export_payload = Some(payload)
      10U => code_payload = Some(payload)
      11U => data_payload = Some(payload)
      _ => ()
    }
  }
  let memory_payload = match memory_payload {
    Some(v) => v
    None => return { bytes, reordered_local_count: 0U }
  }
  let import_entries = match import_payload {
    Some(payload) => parse_import_section_entries_raise(payload)
    None => []
  }
  let import_counts = count_import_kinds(import_entries)
  let imported_table_count = import_counts.table_count
  let imported_memory_count = import_counts.memory_count
  let imported_global_count = import_counts.global_count
  let local_memory_entries = parse_memory_section_entries_raise(memory_payload)
  if local_memory_entries.length() <= 1 {
    return { bytes, reordered_local_count: 0U }
  }
  let used_memory_indices : Array[UInt] = []
  match export_payload {
    Some(payload) =>
      for index in parse_export_memory_indices(payload) {
        push_unique_u32(used_memory_indices, index)
      }
    None => ()
  }
  match code_payload {
    Some(payload) =>
      match collect_used_memory_indices_from_code_section(payload) {
        Some(indices) =>
          for index in indices {
            push_unique_u32(used_memory_indices, index)
          }
        None => return { bytes, reordered_local_count: 0U }
      }
    None => ()
  }
  match data_payload {
    Some(payload) => {
      let (memory_indices, _) = collect_used_memory_and_global_indices_from_data_section_raise(
        payload,
      )
      for index in memory_indices {
        push_unique_u32(used_memory_indices, index)
      }
    }
    None => ()
  }
  let total_memory_count = imported_memory_count +
    local_memory_entries.length().reinterpret_as_uint()
  let used_flags : Array[Bool] = []
  for _ in 0U..<total_memory_count {
    used_flags.push(false)
  }
  for index in used_memory_indices {
    let pos = UInt::reinterpret_as_int(index)
    if pos >= 0 && pos < used_flags.length() {
      used_flags[pos] = true
    }
  }
  let local_order : Array[UInt] = []
  let sortable_local_indices : Array[UInt] = []
  let fixed_local_pos = if imported_memory_count == 0U { 0 } else { -1 }
  for i in 0..<local_memory_entries.length() {
    if i == fixed_local_pos {
      local_order.push(i.reinterpret_as_uint())
    } else {
      sortable_local_indices.push(i.reinterpret_as_uint())
    }
  }
  sortable_local_indices.sort_by((a, b) => {
    let a_used = is_memory_index_marked_used(
      used_flags,
      imported_memory_count + a,
    )
    let b_used = is_memory_index_marked_used(
      used_flags,
      imported_memory_count + b,
    )
    if a_used && not(b_used) {
      -1
    } else if not(a_used) && b_used {
      1
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  local_order.append(sortable_local_indices[:])
  let reordered_local_count = count_reordered_local_indices(local_order)
  if reordered_local_count == 0U {
    return { bytes, reordered_local_count: 0U }
  }
  let memory_index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_memory_count {
    memory_index_map.set(i, i)
  }
  for new_local_pos in 0..<local_order.length() {
    let old_local_pos = local_order[new_local_pos]
    memory_index_map.set(
      imported_memory_count + old_local_pos,
      imported_memory_count + new_local_pos.reinterpret_as_uint(),
    )
  }
  if remap_memory_index_raise(0U, memory_index_map) != 0U {
    return { bytes, reordered_local_count: 0U }
  }
  let local_table_count = match table_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_global_count = match global_payload {
    Some(payload) =>
      parse_global_section_entries_with_refs_raise(payload)
      .length()
      .reinterpret_as_uint()
    None => 0U
  }
  let table_index_map = make_identity_index_map(
    imported_table_count + local_table_count,
  )
  let global_index_map = make_identity_index_map(
    imported_global_count + local_global_count,
  )
  let element_index_map = make_identity_index_map(0U)
  let data_index_map = match data_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      5U => {
        let rewritten = rewrite_memory_section_payload_for_local_order_raise(
          payload, local_order,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 5U, rewritten)
        }
      }
      7U => {
        let (rewritten, _) = rewrite_export_section_payload_for_module_index_maps_raise(
          payload, table_index_map, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 7U, rewritten)
        }
      }
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_module_index_map_raise(
            payload, table_index_map, memory_index_map, global_index_map, element_index_map,
            data_index_map,
          ),
        )
      11U => {
        let (rewritten, _, _) = rewrite_data_section_payload_for_memory_global_index_map_raise(
          payload, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 11U, rewritten)
        }
      }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), reordered_local_count }
}

///|
fn apply_memory_packing(bytes : Bytes) -> MemoryPackingApplyResult {
  let result = try? apply_memory_packing_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, reordered_local_count: 0U }
  }
}

///|
fn is_dwarf_custom_section_name(name : String) -> Bool {
  name.has_prefix(".debug_") || name.has_prefix("reloc..debug_")
}

///|
fn is_debug_custom_section_name(name : String) -> Bool {
  name == "sourceMappingURL" ||
  name == "external_debug_info" ||
  is_dwarf_custom_section_name(name)
}

///|
fn keep_custom_section(section : RawSection, config : OptimizeConfig) -> Bool {
  if section.section_id != 0U {
    return true
  }
  let name = match section.custom_name {
    Some(v) => v
    None => ""
  }
  if config.keep_custom_sections.contains(name) {
    return true
  }
  if config.strip_all_custom {
    return false
  }
  if config.strip_name_section && name == "name" {
    return false
  }
  if config.strip_producers_section && name == "producers" {
    return false
  }
  if config.strip_target_features_section && name == "target_features" {
    return false
  }
  if config.strip_dwarf_sections && is_dwarf_custom_section_name(name) {
    return false
  }
  if config.strip_debug_sections && is_debug_custom_section_name(name) {
    return false
  }
  true
}

///|
fn should_optimize_code_section(config : OptimizeConfig) -> Bool {
  config.enable_peephole ||
  config.enable_vacuum ||
  config.enable_merge_blocks ||
  config.enable_remove_unused_brs
}

///|
fn should_remove_unused_types(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_refine_types(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_signature_prune(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions
}

///|
fn should_duplicate_import_eliminate(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_simplify_globals(config : OptimizeConfig) -> Bool {
  should_optimize_code_section(config) ||
  config.enable_dce ||
  config.enable_remove_unused_module_elements
}

///|
fn should_reorder_globals(config : OptimizeConfig) -> Bool {
  config.enable_dce || config.enable_remove_unused_module_elements
}

///|
fn should_memory_pack(config : OptimizeConfig) -> Bool {
  config.enable_dce || config.enable_remove_unused_module_elements
}

///|
fn custom_strip_pass_requested(config : OptimizeConfig) -> Bool {
  config.strip_all_custom ||
  config.strip_name_section ||
  config.strip_producers_section ||
  config.strip_target_features_section ||
  config.strip_dwarf_sections ||
  config.strip_debug_sections
}

///|
fn any_optimization_pass_requested(config : OptimizeConfig) -> Bool {
  custom_strip_pass_requested(config) ||
  should_optimize_code_section(config) ||
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements ||
  should_refine_types(config) ||
  should_signature_prune(config) ||
  should_remove_unused_types(config)
}

///|
fn push_reason(reasons : Array[String], reason : String) -> Unit {
  if not(reasons.contains(reason)) {
    reasons.push(reason)
  }
}

///|
fn collect_optimize_no_change_reasons(
  before : Bytes,
  after : Bytes,
  config : OptimizeConfig,
) -> Array[String] {
  let reasons : Array[String] = []
  if before.length() != after.length() {
    return reasons
  }
  if not(bytes_equal(before, after)) {
    reasons.push("size-neutral rewrite only (bytes changed but size unchanged)")
    return reasons
  }
  if not(any_optimization_pass_requested(config)) {
    reasons.push("no optimization pass is enabled in config")
    return reasons
  }
  let sections_result = try? parse_core_sections_raise(before)
  match sections_result {
    Ok(sections) => {
      if custom_strip_pass_requested(config) {
        let mut has_custom_section = false
        let mut has_removable_custom_section = false
        for section in sections {
          if section.section_id == 0U {
            has_custom_section = true
            if not(keep_custom_section(section, config)) {
              has_removable_custom_section = true
            }
          }
        }
        if not(has_custom_section) {
          push_reason(reasons, "no custom section exists for strip passes")
        } else if not(has_removable_custom_section) {
          push_reason(
            reasons, "configured custom-section strip targets were not present",
          )
        }
      }
      if should_optimize_code_section(config) {
        if not(sections.any(s => s.section_id == 10U)) {
          push_reason(reasons, "no code section exists for code-level passes")
        } else {
          push_reason(
            reasons, "code-level passes found no reducible instruction patterns",
          )
        }
      }
    }
    Err(_) =>
      push_reason(
        reasons, "unable to inspect section layout for no-change diagnostics",
      )
  }
  if config.enable_dce {
    match analyze_dce_report(before) {
      Ok(report) =>
        if report.partial {
          push_reason(reasons, "dce skipped: partial call graph")
        } else if report.removable_function_count == 0U {
          push_reason(reasons, "dce found no removable functions")
        }
      Err(_) => push_reason(reasons, "dce analysis failed")
    }
  }
  if reasons.length() == 0 {
    reasons.push("module is already optimized for active passes")
  }
  reasons
}

///|
priv struct OptimizeRoundResult {
  bytes : Bytes
  removed_sections : Array[String]
}

///|
fn optimize_for_size_round_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> OptimizeRoundResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let stage1_out : Array[Byte] = bytes[0:8].to_array()
  let removed_sections : Array[String] = []
  for section in sections {
    if section.section_id == 0U && not(keep_custom_section(section, config)) {
      removed_sections.push(section_key(section, false))
    } else if section.section_id == 10U && should_optimize_code_section(config) {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      let optimized_payload = optimize_code_section_payload(payload, config)
      append_encoded_section(stage1_out, section.section_id, optimized_payload)
    } else {
      stage1_out.append(
        bytes[section.section_start:section.section_end].to_array(),
      )
    }
  }
  let mut optimized_bytes = Bytes::from_array(stage1_out[:])
  if config.enable_peephole {
    let coalesce = apply_coalesce_locals_raise(optimized_bytes)
    optimized_bytes = coalesce.bytes
    if coalesce.removed_local_count > 0U {
      removed_sections.push(
        "coalesce-locals:removed:" + coalesce.removed_local_count.to_string(),
      )
    }
  }
  if should_duplicate_import_eliminate(config) {
    let duplicate_import_elim = apply_duplicate_import_elimination(
      optimized_bytes,
    )
    optimized_bytes = duplicate_import_elim.bytes
    if duplicate_import_elim.removed_import_count > 0U {
      removed_sections.push(
        "dup-imports:imports:" +
        duplicate_import_elim.removed_import_count.to_string() +
        " funcs:" +
        duplicate_import_elim.removed_function_import_count.to_string() +
        " tables:" +
        duplicate_import_elim.removed_table_import_count.to_string() +
        " memories:" +
        duplicate_import_elim.removed_memory_import_count.to_string() +
        " globals:" +
        duplicate_import_elim.removed_global_import_count.to_string(),
      )
    }
    if duplicate_import_elim.dropped_name_section {
      removed_sections.push("custom:name(dup-imports)")
    }
  }
  if config.enable_dce {
    let directize = apply_directize_raise(optimized_bytes)
    optimized_bytes = directize.bytes
    if directize.rewritten_call_count > 0U {
      removed_sections.push(
        "directize:calls:" + directize.rewritten_call_count.to_string(),
      )
    }
    let cfp_const = apply_const_call_forwarding_propagation_raise(
      optimized_bytes,
    )
    optimized_bytes = cfp_const.bytes
    if cfp_const.rewritten_call_count > 0U {
      removed_sections.push(
        "cfp-const:calls:" + cfp_const.rewritten_call_count.to_string(),
      )
    }
    let cfp = apply_call_forwarding_propagation_raise(optimized_bytes)
    optimized_bytes = cfp.bytes
    if cfp.rewritten_call_count > 0U {
      removed_sections.push("cfp:calls:" + cfp.rewritten_call_count.to_string())
    }
    let signature_refine = apply_signature_refining_raise(optimized_bytes)
    optimized_bytes = signature_refine.bytes
    if signature_refine.rewritten_call_count > 0U {
      removed_sections.push(
        "signature-refine:calls:" +
        signature_refine.rewritten_call_count.to_string(),
      )
    }
    let dce = apply_dce_raise(optimized_bytes, config)
    optimized_bytes = dce.bytes
    if dce.removed_function_count > 0U {
      removed_sections.push(
        "dce:functions:" +
        dce.removed_function_count.to_string() +
        " bodies:" +
        dce.removed_body_bytes.to_string(),
      )
    }
    if dce.dropped_name_section {
      removed_sections.push("custom:name(dce)")
    }
  }
  if should_refine_types(config) {
    let type_refine = apply_type_refining(optimized_bytes)
    optimized_bytes = type_refine.bytes
    if type_refine.refined_type_count > 0U {
      removed_sections.push(
        "type-refine:types:" + type_refine.refined_type_count.to_string(),
      )
    }
  }
  if should_signature_prune(config) {
    let signature_prune = apply_signature_pruning(optimized_bytes)
    optimized_bytes = signature_prune.bytes
    if signature_prune.pruned_function_count > 0U {
      removed_sections.push(
        "signature-prune:functions:" +
        signature_prune.pruned_function_count.to_string() +
        " params:" +
        signature_prune.pruned_param_count.to_string(),
      )
    }
  }
  if config.enable_dfe {
    let dfe = apply_dfe_raise(optimized_bytes)
    optimized_bytes = dfe.bytes
    if dfe.removed_function_count > 0U {
      removed_sections.push(
        "dfe:functions:" +
        dfe.removed_function_count.to_string() +
        " bodies:" +
        dfe.removed_body_bytes.to_string(),
      )
    }
    if dfe.dropped_name_section {
      removed_sections.push("custom:name(dfe)")
    }
  }
  if config.enable_merge_similar_functions {
    let msf = apply_merge_similar_functions_raise(optimized_bytes)
    optimized_bytes = msf.bytes
    if msf.removed_function_count > 0U {
      removed_sections.push(
        "msf:functions:" +
        msf.removed_function_count.to_string() +
        " bodies:" +
        msf.removed_body_bytes.to_string(),
      )
    }
    if msf.dropped_name_section {
      removed_sections.push("custom:name(msf)")
    }
  }
  if config.enable_remove_unused_module_elements {
    let rume = apply_remove_unused_module_elements(optimized_bytes, config)
    optimized_bytes = rume.bytes
    if rume.removed_import_count > 0U ||
      rume.removed_table_count > 0U ||
      rume.removed_memory_count > 0U ||
      rume.removed_global_count > 0U ||
      rume.removed_element_count > 0U ||
      rume.removed_data_count > 0U ||
      rume.removed_export_count > 0U {
      removed_sections.push(
        "rume:imports:" +
        rume.removed_import_count.to_string() +
        " tables:" +
        rume.removed_table_count.to_string() +
        " memories:" +
        rume.removed_memory_count.to_string() +
        " globals:" +
        rume.removed_global_count.to_string() +
        " elements:" +
        rume.removed_element_count.to_string() +
        " data:" +
        rume.removed_data_count.to_string() +
        " exports:" +
        rume.removed_export_count.to_string(),
      )
    }
  }
  if should_simplify_globals(config) {
    let simplify_globals = apply_simplify_globals(optimized_bytes)
    optimized_bytes = simplify_globals.bytes
    if simplify_globals.rewritten_global_get_count > 0U {
      removed_sections.push(
        "simplify-globals:gets:" +
        simplify_globals.rewritten_global_get_count.to_string(),
      )
    }
  }
  if should_reorder_globals(config) {
    let reorder_globals = apply_reorder_globals(optimized_bytes)
    optimized_bytes = reorder_globals.bytes
    if reorder_globals.reordered_local_count > 0U {
      removed_sections.push(
        "reorder-globals:locals:" +
        reorder_globals.reordered_local_count.to_string(),
      )
    }
  }
  if should_memory_pack(config) {
    let memory_pack = apply_memory_packing(optimized_bytes)
    optimized_bytes = memory_pack.bytes
    if memory_pack.reordered_local_count > 0U {
      removed_sections.push(
        "memory-packing:locals:" + memory_pack.reordered_local_count.to_string(),
      )
    }
  }
  if should_remove_unused_types(config) {
    let remove_unused_types = apply_remove_unused_types(optimized_bytes)
    optimized_bytes = remove_unused_types.bytes
    if remove_unused_types.removed_type_count > 0U {
      removed_sections.push(
        "types:" + remove_unused_types.removed_type_count.to_string(),
      )
    }
  }
  if config.enable_dce {
    let inlining = apply_inlining_optimizing(optimized_bytes)
    optimized_bytes = inlining.bytes
    if inlining.inlined_call_count > 0U {
      removed_sections.push(
        "inlining:calls:" + inlining.inlined_call_count.to_string(),
      )
    }
    let dae = apply_dae_optimizing(optimized_bytes)
    optimized_bytes = dae.bytes
    if dae.removed_instr_count > 0U {
      removed_sections.push("dae:instrs:" + dae.removed_instr_count.to_string())
    }
  }
  { bytes: optimized_bytes, removed_sections }
}

///|
pub fn analyze_section_sizes(
  bytes : Bytes,
) -> Result[Array[SectionSize], WalyzeError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    summarize_sections(sections, false)
  }
}

///|
pub fn optimize_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[OptimizeResult, WalyzeError] {
  try? {
    let rounds = if config.pass_rounds == 0U { 1U } else { config.pass_rounds }
    let mut current = bytes
    let removed_sections : Array[String] = []
    for _ in 0U..<rounds {
      let round = optimize_for_size_round_raise(current, config)
      let changed = not(bytes_equal(round.bytes, current))
      current = round.bytes
      removed_sections.append(round.removed_sections[:])
      if not(changed) {
        break
      }
    }
    let no_change_reasons = collect_optimize_no_change_reasons(
      bytes, current, config,
    )
    {
      bytes: current,
      before_size: bytes.length().reinterpret_as_uint(),
      after_size: current.length().reinterpret_as_uint(),
      removed_sections,
      no_change_reasons,
    }
  }
}

///|
pub fn profile_module(bytes : Bytes) -> Result[ModuleProfile, WalyzeError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut function_count = 0U
    let mut import_count = 0U
    let mut export_count = 0U
    let mut code_body_count = 0U
    let mut code_body_bytes = 0U
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => import_count += parse_vec_count(payload)
        3U => function_count += parse_vec_count(payload)
        7U => export_count += parse_vec_count(payload)
        10U => {
          let (count, total_bytes) = parse_code_section_metrics(payload)
          code_body_count += count
          code_body_bytes += total_bytes
        }
        _ => ()
      }
    }
    {
      total_bytes: bytes.length().reinterpret_as_uint(),
      function_count,
      import_count,
      export_count,
      code_body_count,
      code_body_bytes,
      sections: summarize_sections(sections, false),
    }
  }
}

///|
pub fn analyze_function_sizes(
  bytes : Bytes,
) -> Result[Array[FunctionSize], WalyzeError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_body_sizes : Array[UInt] = []
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count += parse_vec_count(payload)
        7U =>
          merge_export_function_names(
            export_names,
            parse_export_function_names(payload),
          )
        10U => code_body_sizes = parse_code_body_sizes(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    if code_body_sizes.length().reinterpret_as_uint() != local_function_count {
      raise WalyzeError::InvalidFormat(
        "function/code section count mismatch: function=" +
        local_function_count.to_string() +
        " code=" +
        code_body_sizes.length().to_string(),
      )
    }
    let functions : Array[FunctionSize] = []
    for i in 0..<code_body_sizes.length() {
      let function_index = imported_function_count + i.reinterpret_as_uint()
      functions.push({
        function_index,
        body_bytes: code_body_sizes[i],
        name: function_names.get(function_index),
        export_names: match export_names.get(function_index) {
          Some(v) => v
          None => []
        },
      })
    }
    functions.sort_by((a, b) => if a.body_bytes > b.body_bytes {
      -1
    } else if a.body_bytes < b.body_bytes {
      1
    } else if a.function_index < b.function_index {
      -1
    } else if a.function_index > b.function_index {
      1
    } else {
      0
    })
    functions
  }
}

///|
fn code_block_kind_from_opcode(opcode : UInt) -> String? {
  match opcode {
    0x02U => Some("block")
    0x03U => Some("loop")
    0x04U => Some("if")
    _ => None
  }
}

///|
fn collect_function_code_blocks(
  function_index : UInt,
  function_name : String?,
  export_names : Array[String],
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> (Array[CodeBlockSize], Bool) {
  let entries : Array[CodeBlockSize] = []
  let instr_size = instr_bytes.length().reinterpret_as_uint()
  entries.push({
    function_index,
    function_name,
    export_names,
    block_index: 0U,
    depth: 0U,
    kind: "function",
    start_offset: 0U,
    end_offset: instr_size,
    instruction_count: spans.length().reinterpret_as_uint(),
    total_bytes: instr_size,
  })
  let mut next_block_index = 1U
  let open_stack : Array[OpenCodeBlock] = []
  for i in 0..<spans.length() {
    let span = spans[i]
    match code_block_kind_from_opcode(span.opcode) {
      Some(kind) => {
        let depth = open_stack.length().reinterpret_as_uint() + 1U
        let start_offset = span.start.reinterpret_as_uint()
        entries.push({
          function_index,
          function_name,
          export_names,
          block_index: next_block_index,
          depth,
          kind,
          start_offset,
          end_offset: start_offset,
          instruction_count: 0U,
          total_bytes: 0U,
        })
        open_stack.push({
          entry_index: entries.length() - 1,
          start_span_index: i,
          start_offset: span.start,
        })
        next_block_index += 1U
      }
      None => ()
    }
    if span.opcode == 0x0bU && open_stack.length() > 0 {
      let open = open_stack[open_stack.length() - 1]
      ignore(open_stack.pop())
      let prev = entries[open.entry_index]
      entries[open.entry_index] = {
        function_index: prev.function_index,
        function_name: prev.function_name,
        export_names: prev.export_names,
        block_index: prev.block_index,
        depth: prev.depth,
        kind: prev.kind,
        start_offset: prev.start_offset,
        end_offset: span.end_.reinterpret_as_uint(),
        instruction_count: (i - open.start_span_index + 1).reinterpret_as_uint(),
        total_bytes: (span.end_ - open.start_offset).reinterpret_as_uint(),
      }
    }
  }
  if open_stack.length() == 0 {
    return (entries, true)
  }
  let filtered : Array[CodeBlockSize] = []
  for entry in entries {
    if entry.kind == "function" || entry.total_bytes > 0U {
      filtered.push(entry)
    }
  }
  (filtered, false)
}

///|
pub fn analyze_code_block_sizes(
  bytes : Bytes,
) -> Result[CodeBlockSizeReport, WalyzeError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_bodies : Array[Bytes] = []
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count += parse_vec_count(payload)
        7U =>
          merge_export_function_names(
            export_names,
            parse_export_function_names(payload),
          )
        10U => code_bodies = parse_code_bodies(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    if code_bodies.length().reinterpret_as_uint() != local_function_count {
      raise WalyzeError::InvalidFormat(
        "function/code section count mismatch: function=" +
        local_function_count.to_string() +
        " code=" +
        code_bodies.length().to_string(),
      )
    }
    let blocks : Array[CodeBlockSize] = []
    let mut partial = false
    let mut total_body_bytes = 0U
    let mut total_instruction_bytes = 0U
    for i in 0..<code_bodies.length() {
      let function_index = imported_function_count + i.reinterpret_as_uint()
      let body = code_bodies[i]
      total_body_bytes += body.length().reinterpret_as_uint()
      let prefix_end_result = try? parse_local_decl_prefix_end(body)
      match prefix_end_result {
        Ok(prefix_end) => {
          let instr_bytes = body[prefix_end:body.length()].to_bytes()
          total_instruction_bytes += instr_bytes.length().reinterpret_as_uint()
          match parse_instruction_spans(instr_bytes) {
            Some(spans) => {
              let exports = match export_names.get(function_index) {
                Some(v) => v
                None => []
              }
              let (function_blocks, complete) = collect_function_code_blocks(
                function_index,
                function_names.get(function_index),
                exports,
                instr_bytes,
                spans,
              )
              blocks.append(function_blocks[:])
              if not(complete) {
                partial = true
              }
            }
            None => partial = true
          }
        }
        Err(_) => partial = true
      }
    }
    blocks.sort_by((a, b) => if a.total_bytes > b.total_bytes {
      -1
    } else if a.total_bytes < b.total_bytes {
      1
    } else if a.function_index < b.function_index {
      -1
    } else if a.function_index > b.function_index {
      1
    } else if a.block_index < b.block_index {
      -1
    } else if a.block_index > b.block_index {
      1
    } else {
      0
    })
    {
      partial,
      function_count: local_function_count,
      block_count: blocks.length().reinterpret_as_uint(),
      total_body_bytes,
      total_instruction_bytes,
      blocks,
    }
  }
}

///|
fn summarize_custom_sections_raise(
  sections : Array[RawSection],
  bytes : Bytes,
) -> Array[CustomSectionBreakdown] raise WalyzeError {
  let grouped : Map[String, CustomSectionBreakdown] = {}
  for section in sections {
    if section.section_id != 0U {
      continue
    }
    let name = match section.custom_name {
      Some(v) => v
      None => "(anon)"
    }
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    let payload_bytes = payload.length().reinterpret_as_uint()
    let prefix_end = parse_custom_section_name_prefix_end(payload)
    let content_bytes = (payload.length() - prefix_end).reinterpret_as_uint()
    let total_bytes = section_total_bytes(section)
    match grouped.get(name) {
      Some(prev) =>
        grouped.set(name, {
          name: prev.name,
          count: prev.count + 1U,
          total_bytes: prev.total_bytes + total_bytes,
          payload_bytes: prev.payload_bytes + payload_bytes,
          content_bytes: prev.content_bytes + content_bytes,
        })
      None =>
        grouped.set(name, {
          name,
          count: 1U,
          total_bytes,
          payload_bytes,
          content_bytes,
        })
    }
  }
  let out : Array[CustomSectionBreakdown] = []
  grouped.each((_, value) => out.push(value))
  out.sort_by((a, b) => if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else if a.count > b.count {
    -1
  } else if a.count < b.count {
    1
  } else {
    a.name.compare(b.name)
  })
  out
}

///|
fn to_hex_digit(v : Int) -> Char {
  match v {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    15 => 'f'
    _ => '0'
  }
}

///|
fn format_opcode_hex(opcode : UInt) -> String {
  let value = (opcode & 0xffU).reinterpret_as_int()
  let hi = value / 16
  let lo = value % 16
  String::from_array(['0', 'x', to_hex_digit(hi), to_hex_digit(lo)])
}

///|
fn parse_prefixed_opcode_subopcode(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0xfcU && span.opcode != 0xfdU {
    return None
  }
  if span.end_ <= span.start + 1 {
    return None
  }
  let parser = Cursor::new(instr_bytes)
  parser.set_pos(span.start + 1)
  let result = try? parser.read_u32_leb128()
  match result {
    Ok(v) => if parser.get_pos() <= span.end_ { Some(v) } else { None }
    Err(_) => None
  }
}

///|
fn opcode_stat_key(opcode : UInt, subopcode : UInt?) -> String {
  let base = format_opcode_hex(opcode)
  if opcode == 0xfcU || opcode == 0xfdU {
    match subopcode {
      Some(v) => base + "." + v.to_string()
      None => base
    }
  } else {
    base
  }
}

///|
fn opcode_mnemonic_or_key(
  opcode : UInt,
  subopcode : UInt?,
  key : String,
) -> String {
  match opcode {
    0x00U => "unreachable"
    0x01U => "nop"
    0x02U => "block"
    0x03U => "loop"
    0x04U => "if"
    0x05U => "else"
    0x0bU => "end"
    0x0cU => "br"
    0x0dU => "br_if"
    0x0eU => "br_table"
    0x0fU => "return"
    0x10U => "call"
    0x11U => "call_indirect"
    0x1aU => "drop"
    0x1bU => "select"
    0x20U => "local.get"
    0x21U => "local.set"
    0x22U => "local.tee"
    0x23U => "global.get"
    0x24U => "global.set"
    0x28U => "i32.load"
    0x36U => "i32.store"
    0x3fU => "memory.size"
    0x40U => "memory.grow"
    0x41U => "i32.const"
    0x42U => "i64.const"
    0x43U => "f32.const"
    0x44U => "f64.const"
    0x45U => "i32.eqz"
    0x46U => "i32.eq"
    0x47U => "i32.ne"
    0x48U => "i32.lt_s"
    0x49U => "i32.lt_u"
    0x4aU => "i32.gt_s"
    0x4bU => "i32.gt_u"
    0x4cU => "i32.le_s"
    0x4dU => "i32.le_u"
    0x4eU => "i32.ge_s"
    0x4fU => "i32.ge_u"
    0x67U => "i32.clz"
    0x68U => "i32.ctz"
    0x69U => "i32.popcnt"
    0x6aU => "i32.add"
    0x6bU => "i32.sub"
    0x6cU => "i32.mul"
    0x71U => "i32.and"
    0x72U => "i32.or"
    0x73U => "i32.xor"
    0x74U => "i32.shl"
    0x75U => "i32.shr_s"
    0x76U => "i32.shr_u"
    0xd0U => "ref.null"
    0xd1U => "ref.is_null"
    0xd2U => "ref.func"
    0xfcU =>
      match subopcode {
        Some(0U) => "i32.trunc_sat_f32_s"
        Some(1U) => "i32.trunc_sat_f32_u"
        Some(2U) => "i32.trunc_sat_f64_s"
        Some(3U) => "i32.trunc_sat_f64_u"
        Some(4U) => "i64.trunc_sat_f32_s"
        Some(5U) => "i64.trunc_sat_f32_u"
        Some(6U) => "i64.trunc_sat_f64_s"
        Some(7U) => "i64.trunc_sat_f64_u"
        Some(8U) => "memory.init"
        Some(9U) => "data.drop"
        Some(10U) => "memory.copy"
        Some(11U) => "memory.fill"
        Some(12U) => "table.init"
        Some(13U) => "elem.drop"
        Some(14U) => "table.copy"
        Some(15U) => "table.grow"
        Some(16U) => "table.size"
        Some(17U) => "table.fill"
        _ => key
      }
    0xfdU =>
      match subopcode {
        Some(0U) => "v128.load"
        Some(11U) => "v128.store"
        _ => key
      }
    _ => key
  }
}

///|
priv struct OpcodeCounter {
  opcode : UInt
  subopcode : UInt?
  count : UInt
  total_bytes : UInt
}

///|
fn compare_function_size(a : FunctionSize, b : FunctionSize) -> Int {
  if a.body_bytes > b.body_bytes {
    -1
  } else if a.body_bytes < b.body_bytes {
    1
  } else if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else {
    0
  }
}

///|
fn compare_code_block_size(a : CodeBlockSize, b : CodeBlockSize) -> Int {
  if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else if a.block_index < b.block_index {
    -1
  } else if a.block_index > b.block_index {
    1
  } else {
    0
  }
}

///|
fn push_unique_u32_with_seen(
  out : Array[UInt],
  seen : Map[UInt, Bool],
  value : UInt,
) -> Unit {
  if seen.get(value) is Some(_) {
    return
  }
  seen.set(value, true)
  out.push(value)
}

///|
fn push_function_size_with_limit(
  out : Array[FunctionSize],
  entry : FunctionSize,
  top_limit : UInt,
) -> Unit {
  if top_limit == 0U {
    out.push(entry)
    return
  }
  if out.length().reinterpret_as_uint() < top_limit {
    out.push(entry)
    return
  }
  let mut worst = 0
  for i in 1..<out.length() {
    if compare_function_size(out[worst], out[i]) < 0 {
      worst = i
    }
  }
  if compare_function_size(entry, out[worst]) < 0 {
    out[worst] = entry
  }
}

///|
fn push_code_block_size_with_limit(
  out : Array[CodeBlockSize],
  entry : CodeBlockSize,
  top_limit : UInt,
) -> Unit {
  if top_limit == 0U {
    out.push(entry)
    return
  }
  if out.length().reinterpret_as_uint() < top_limit {
    out.push(entry)
    return
  }
  let mut worst = 0
  for i in 1..<out.length() {
    if compare_code_block_size(out[worst], out[i]) < 0 {
      worst = i
    }
  }
  if compare_code_block_size(entry, out[worst]) < 0 {
    out[worst] = entry
  }
}

///|
fn add_opcode_counter_base(
  grouped : Map[UInt, OpcodeCounter],
  opcode : UInt,
  span_size : UInt,
) -> Unit {
  match grouped.get(opcode) {
    Some(prev) =>
      grouped.set(opcode, {
        opcode,
        subopcode: None,
        count: prev.count + 1U,
        total_bytes: prev.total_bytes + span_size,
      })
    None =>
      grouped.set(opcode, {
        opcode,
        subopcode: None,
        count: 1U,
        total_bytes: span_size,
      })
  }
}

///|
fn add_opcode_counter_prefixed(
  grouped : Map[String, OpcodeCounter],
  opcode : UInt,
  subopcode : UInt?,
  span_size : UInt,
) -> Unit {
  let key = opcode_stat_key(opcode, subopcode)
  match grouped.get(key) {
    Some(prev) =>
      grouped.set(key, {
        opcode,
        subopcode,
        count: prev.count + 1U,
        total_bytes: prev.total_bytes + span_size,
      })
    None =>
      grouped.set(key, { opcode, subopcode, count: 1U, total_bytes: span_size })
  }
}

///|
fn opcode_stats_from_counters(
  base_grouped : Map[UInt, OpcodeCounter],
  prefixed_grouped : Map[String, OpcodeCounter],
) -> Array[OpcodeStat] {
  let out : Array[OpcodeStat] = []
  base_grouped.each((_opcode, counter) => {
    let key = format_opcode_hex(counter.opcode)
    out.push({
      key,
      mnemonic: opcode_mnemonic_or_key(counter.opcode, None, key),
      count: counter.count,
      total_bytes: counter.total_bytes,
    })
  })
  prefixed_grouped.each((key, counter) => out.push({
    key,
    mnemonic: opcode_mnemonic_or_key(counter.opcode, counter.subopcode, key),
    count: counter.count,
    total_bytes: counter.total_bytes,
  }))
  out.sort_by((a, b) => if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else if a.count > b.count {
    -1
  } else if a.count < b.count {
    1
  } else {
    a.key.compare(b.key)
  })
  out
}

///|
pub fn analyze_wasm_breakdown(
  bytes : Bytes,
  top_limit? : UInt = 0U,
) -> Result[WasmBreakdownReport, WalyzeError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let section_sizes = summarize_sections(sections, false)
    let custom_sections = summarize_custom_sections_raise(sections, bytes)
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    let roots : Array[UInt] = []
    let root_seen : Map[UInt, Bool] = {}
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_bodies : Array[Bytes] = []
    let mut callgraph_partial = false
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count = parse_vec_count(payload)
        7U => {
          let parsed = parse_export_function_names(payload)
          merge_export_function_names(export_names, parsed)
          parsed.each((index, _names) => push_unique_u32_with_seen(
            roots, root_seen, index,
          ))
        }
        8U =>
          push_unique_u32_with_seen(
            roots,
            root_seen,
            parse_start_function_index(payload),
          )
        6U => {
          let refs_result = try? parse_global_section_function_refs_raise(
            payload,
          )
          match refs_result {
            Ok(indices) =>
              for index in indices {
                push_unique_u32_with_seen(roots, root_seen, index)
              }
            Err(_) => callgraph_partial = true
          }
        }
        9U => {
          let refs_result = try? parse_element_section_function_refs_raise(
            payload,
          )
          match refs_result {
            Ok(indices) =>
              for index in indices {
                push_unique_u32_with_seen(roots, root_seen, index)
              }
            Err(_) => callgraph_partial = true
          }
        }
        10U => code_bodies = parse_code_bodies(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    if code_bodies.length().reinterpret_as_uint() != local_function_count {
      raise WalyzeError::InvalidFormat(
        "function/code section count mismatch: function=" +
        local_function_count.to_string() +
        " code=" +
        code_bodies.length().to_string(),
      )
    }
    let top_functions : Array[FunctionSize] = []
    let top_blocks : Array[CodeBlockSize] = []
    let local_function_indices : Array[UInt] = []
    let direct_callees_map : Map[UInt, Array[UInt]] = {}
    let body_bytes_map : Map[UInt, UInt] = {}
    let base_opcode_grouped : Map[UInt, OpcodeCounter] = {}
    let prefixed_opcode_grouped : Map[String, OpcodeCounter] = {}
    let mut block_count = 0U
    let mut instruction_count = 0U
    let mut instruction_bytes = 0U
    let mut opcode_partial = false
    let mut has_indirect_calls = false
    for i in 0..<code_bodies.length() {
      let function_index = imported_function_count + i.reinterpret_as_uint()
      let body = code_bodies[i]
      let body_bytes = body.length().reinterpret_as_uint()
      let exports = match export_names.get(function_index) {
        Some(v) => v
        None => []
      }
      local_function_indices.push(function_index)
      body_bytes_map.set(function_index, body_bytes)
      push_function_size_with_limit(
        top_functions,
        {
          function_index,
          body_bytes,
          name: function_names.get(function_index),
          export_names: exports,
        },
        top_limit,
      )
      let mut direct_callees : Array[UInt] = []
      let prefix_result = try? parse_local_decl_prefix_end(body)
      match prefix_result {
        Ok(prefix_end) => {
          let instr_bytes = body[prefix_end:body.length()].to_bytes()
          instruction_bytes += instr_bytes.length().reinterpret_as_uint()
          match parse_instruction_spans(instr_bytes) {
            Some(spans) => {
              instruction_count += spans.length().reinterpret_as_uint()
              let (function_blocks, complete) = collect_function_code_blocks(
                function_index,
                function_names.get(function_index),
                exports,
                instr_bytes,
                spans,
              )
              block_count += function_blocks.length().reinterpret_as_uint()
              for block in function_blocks {
                push_code_block_size_with_limit(top_blocks, block, top_limit)
              }
              if not(complete) {
                opcode_partial = true
              }
              let (callees, body_has_indirect) = collect_direct_callees(
                instr_bytes, spans,
              )
              direct_callees = callees
              if body_has_indirect {
                has_indirect_calls = true
              }
              for span in spans {
                let span_size = (span.end_ - span.start).reinterpret_as_uint()
                if span.opcode == 0xfcU || span.opcode == 0xfdU {
                  add_opcode_counter_prefixed(
                    prefixed_opcode_grouped,
                    span.opcode,
                    parse_prefixed_opcode_subopcode(instr_bytes, span),
                    span_size,
                  )
                } else {
                  add_opcode_counter_base(
                    base_opcode_grouped,
                    span.opcode,
                    span_size,
                  )
                }
              }
            }
            None => {
              opcode_partial = true
              callgraph_partial = true
            }
          }
        }
        Err(_) => {
          opcode_partial = true
          callgraph_partial = true
        }
      }
      direct_callees_map.set(function_index, direct_callees)
    }
    top_functions.sort_by(compare_function_size)
    top_blocks.sort_by(compare_code_block_size)
    let opcodes = opcode_stats_from_counters(
      base_opcode_grouped, prefixed_opcode_grouped,
    )
    let visited : Map[UInt, Bool] = {}
    let queue = roots.copy()
    let mut head = 0
    while head < queue.length() {
      let index = queue[head]
      head += 1
      if visited.get(index) is Some(_) {
        continue
      }
      visited.set(index, true)
      match direct_callees_map.get(index) {
        Some(callees) =>
          for callee in callees {
            if visited.get(callee) is None {
              queue.push(callee)
            }
          }
        None => ()
      }
    }
    let mut reachable_body_bytes = 0U
    let mut dead_body_bytes = 0U
    for function_index in local_function_indices {
      let body_bytes = match body_bytes_map.get(function_index) {
        Some(v) => v
        None => 0U
      }
      if visited.get(function_index) is Some(_) {
        reachable_body_bytes += body_bytes
      } else {
        dead_body_bytes += body_bytes
      }
    }
    {
      total_bytes: bytes.length().reinterpret_as_uint(),
      sections: section_sizes,
      custom_sections,
      imported_function_count,
      local_function_count,
      top_functions,
      block_count,
      top_blocks,
      instruction_count,
      instruction_bytes,
      opcode_partial,
      opcodes,
      callgraph_partial,
      has_indirect_calls,
      reachable_body_bytes,
      dead_body_bytes,
    }
  }
}

///|
fn should_include_export_root(
  names : Array[String],
  export_root_names : Array[String]?,
) -> Bool {
  match export_root_names {
    Some(allowed) => names.any(name => allowed.contains(name))
    None => true
  }
}

///|
fn analyze_call_graph_raise(
  bytes : Bytes,
  export_root_names : Array[String]?,
) -> CallGraphReport raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut local_function_count = 0U
  let mut code_bodies : Array[Bytes] = []
  let export_names : Map[UInt, Array[String]] = {}
  let function_names : Map[UInt, String] = {}
  let roots : Array[UInt] = []
  let root_seen : Map[UInt, Bool] = {}
  let mut partial = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => local_function_count += parse_vec_count(payload)
      7U => {
        let parsed = parse_export_function_names(payload)
        merge_export_function_names(export_names, parsed)
        parsed.each((index, names) => if should_include_export_root(
            names, export_root_names,
          ) {
          push_unique_u32_with_seen(roots, root_seen, index)
        })
      }
      8U => {
        let start_index = parse_start_function_index(payload)
        push_unique_u32_with_seen(roots, root_seen, start_index)
      }
      6U => {
        let refs_result = try? parse_global_section_function_refs_raise(payload)
        match refs_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32_with_seen(roots, root_seen, index)
            }
          Err(_) => partial = true
        }
      }
      9U => {
        let refs_result = try? parse_element_section_function_refs_raise(
          payload,
        )
        match refs_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32_with_seen(roots, root_seen, index)
            }
          Err(_) => partial = true
        }
      }
      10U => code_bodies = parse_code_bodies(payload)
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
              parse_name_section_function_names(payload).each((
                index,
                function_name,
              ) => function_names.set(index, function_name))
            }
          None => ()
        }
      _ => ()
    }
  }
  if code_bodies.length().reinterpret_as_uint() != local_function_count {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch: function=" +
      local_function_count.to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let nodes : Array[CallGraphNode] = []
  let index_to_pos : Map[UInt, Int] = {}
  let mut has_indirect_calls = false
  for i in 0..<code_bodies.length() {
    let function_index = imported_function_count + i.reinterpret_as_uint()
    let body = code_bodies[i]
    let mut direct_callees : Array[UInt] = []
    let prefix_result = try? parse_local_decl_prefix_end(body)
    match prefix_result {
      Ok(prefix_end) => {
        let instr_bytes = body[prefix_end:body.length()].to_bytes()
        match parse_instruction_spans(instr_bytes) {
          Some(spans) => {
            let (callees, body_has_indirect) = collect_direct_callees(
              instr_bytes, spans,
            )
            direct_callees = callees
            if body_has_indirect {
              has_indirect_calls = true
            }
          }
          None => partial = true
        }
      }
      Err(_) => partial = true
    }
    index_to_pos.set(function_index, nodes.length())
    nodes.push({
      function_index,
      body_bytes: body.length().reinterpret_as_uint(),
      name: function_names.get(function_index),
      export_names: match export_names.get(function_index) {
        Some(v) => v
        None => []
      },
      direct_callees,
      reachable_from_roots: false,
    })
  }
  let visited : Map[UInt, Bool] = {}
  let queue = roots.copy()
  let mut head = 0
  while head < queue.length() {
    let index = queue[head]
    head += 1
    if visited.get(index) is Some(_) {
      continue
    }
    visited.set(index, true)
    match index_to_pos.get(index) {
      Some(pos) =>
        for callee in nodes[pos].direct_callees {
          if visited.get(callee) is None {
            queue.push(callee)
          }
        }
      None => ()
    }
  }
  let mut reachable_body_bytes = 0U
  let mut dead_body_bytes = 0U
  for i in 0..<nodes.length() {
    let node = nodes[i]
    let reachable = visited.get(node.function_index) is Some(_)
    if reachable {
      reachable_body_bytes += node.body_bytes
    } else {
      dead_body_bytes += node.body_bytes
    }
    nodes[i] = {
      function_index: node.function_index,
      body_bytes: node.body_bytes,
      name: node.name,
      export_names: node.export_names,
      direct_callees: node.direct_callees,
      reachable_from_roots: reachable,
    }
  }
  {
    imported_function_count,
    local_function_count,
    roots,
    has_indirect_calls,
    partial,
    reachable_body_bytes,
    dead_body_bytes,
    nodes,
  }
}

///|
pub fn analyze_call_graph(
  bytes : Bytes,
) -> Result[CallGraphReport, WalyzeError] {
  try? analyze_call_graph_raise(bytes, None)
}

///|
fn export_root_names_from_config(config : OptimizeConfig) -> Array[String]? {
  if config.closed_world &&
    not(config.safe_mode) &&
    config.closed_world_root_exports.length() > 0 {
    Some(config.closed_world_root_exports)
  } else {
    None
  }
}

///|
pub fn analyze_keep_reasons(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[KeepReasonReport, WalyzeError] {
  try? {
    let export_root_names = export_root_names_from_config(config)
    let graph = analyze_call_graph_raise(bytes, export_root_names)
    let reasons_map : Map[UInt, Array[String]] = {}
    let sections = parse_core_sections_raise(bytes)
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        7U => {
          let exports = parse_export_function_names(payload)
          exports.each((index, names) => if should_include_export_root(
              names, export_root_names,
            ) {
            for export_name in names {
              map_push_string_array(reasons_map, index, "export:" + export_name)
            }
          })
        }
        8U => {
          let start_index = parse_start_function_index(payload)
          map_push_string_array(reasons_map, start_index, "start")
        }
        6U => {
          let result = try? parse_global_section_function_refs_raise(payload)
          match result {
            Ok(indices) =>
              for index in indices {
                map_push_string_array(reasons_map, index, "global-ref.func")
              }
            Err(_) => ()
          }
        }
        9U => {
          let result = try? parse_element_section_function_refs_raise(payload)
          match result {
            Ok(indices) =>
              for index in indices {
                map_push_string_array(reasons_map, index, "element-ref.func")
              }
            Err(_) => ()
          }
        }
        _ => ()
      }
    }
    let index_to_pos : Map[UInt, Int] = {}
    for i in 0..<graph.nodes.length() {
      index_to_pos.set(graph.nodes[i].function_index, i)
    }
    let visited : Map[UInt, Bool] = {}
    let parent_map : Map[UInt, UInt] = {}
    let queue = graph.roots.copy()
    let mut head = 0
    while head < queue.length() {
      let current = queue[head]
      head += 1
      if visited.get(current) is Some(_) {
        continue
      }
      visited.set(current, true)
      match index_to_pos.get(current) {
        Some(pos) =>
          for callee in graph.nodes[pos].direct_callees {
            if visited.get(callee) is None {
              if parent_map.get(callee) is None {
                parent_map.set(callee, current)
              }
              queue.push(callee)
            }
          }
        None => ()
      }
    }
    let entries : Array[KeepReasonEntry] = []
    for node in graph.nodes {
      if node.reachable_from_roots {
        let reasons = match reasons_map.get(node.function_index) {
          Some(v) => v.copy()
          None => []
        }
        if reasons.length() == 0 {
          match parent_map.get(node.function_index) {
            Some(parent) => reasons.push("call:" + parent.to_string())
            None => reasons.push("reachable")
          }
        }
        reasons.sort()
        reasons.dedup()
        entries.push({
          function_index: node.function_index,
          name: node.name,
          export_names: node.export_names,
          reasons,
        })
      }
    }
    entries.sort_by((a, b) => if a.function_index < b.function_index {
      -1
    } else if a.function_index > b.function_index {
      1
    } else {
      0
    })
    { partial: graph.partial, entries }
  }
}

///|
pub fn analyze_dce_report(bytes : Bytes) -> Result[DceReport, WalyzeError] {
  match analyze_call_graph(bytes) {
    Ok(graph) => {
      let removable_functions : Array[FunctionSize] = []
      for node in graph.nodes {
        if not(node.reachable_from_roots) {
          removable_functions.push({
            function_index: node.function_index,
            body_bytes: node.body_bytes,
            name: node.name,
            export_names: node.export_names,
          })
        }
      }
      removable_functions.sort_by((a, b) => if a.body_bytes > b.body_bytes {
        -1
      } else if a.body_bytes < b.body_bytes {
        1
      } else if a.function_index < b.function_index {
        -1
      } else if a.function_index > b.function_index {
        1
      } else {
        0
      })
      Ok({
        roots: graph.roots,
        partial: graph.partial,
        removable_function_count: removable_functions
        .length()
        .reinterpret_as_uint(),
        removable_body_bytes: graph.dead_body_bytes,
        removable_functions,
      })
    }
    Err(e) => Err(e)
  }
}

///|
priv struct DceApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct DfeApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct CfpApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct CfpConstApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct SignatureRefineApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct DuplicateImportElimApplyResult {
  bytes : Bytes
  removed_import_count : UInt
  removed_function_import_count : UInt
  removed_table_import_count : UInt
  removed_memory_import_count : UInt
  removed_global_import_count : UInt
  dropped_name_section : Bool
}

///|
priv struct MsfApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct RumeApplyResult {
  bytes : Bytes
  removed_import_count : UInt
  removed_table_count : UInt
  removed_memory_count : UInt
  removed_global_count : UInt
  removed_element_count : UInt
  removed_data_count : UInt
  removed_export_count : UInt
}

///|
priv struct TypeRefineApplyResult {
  bytes : Bytes
  refined_type_count : UInt
}

///|
priv struct RemoveUnusedTypesApplyResult {
  bytes : Bytes
  removed_type_count : UInt
}

///|
priv struct SignaturePruneApplyResult {
  bytes : Bytes
  pruned_function_count : UInt
  pruned_param_count : UInt
}

///|
fn bytes_equal(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

fn parse_forward_call_target_with_param_count(
  body_bytes : Bytes,
  param_count : UInt,
) -> UInt? {
  let prefix_result = try? parse_local_decl_prefix_raise(body_bytes)
  let prefix = match prefix_result {
    Ok(v) => v
    Err(_) => return None
  }
  let prefix_end = prefix.prefix_end
  let param_count_i = UInt::reinterpret_as_int(param_count)
  if param_count_i < 0 {
    return None
  }
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  match prefix_end_result {
    Ok(v) => if v != prefix_end { return None }
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  if spans.length() != param_count_i + 2 {
    return None
  }
  let call_pos = spans.length() - 2
  if spans[call_pos].opcode != 0x10U || spans[call_pos + 1].opcode != 0x0bU {
    return None
  }
  for i in 0..<param_count_i {
    if spans[i].opcode != 0x20U {
      return None
    }
    match decode_span_u32_immediate(instr_bytes, spans[i]) {
      Some(local_index) =>
        if local_index != i.reinterpret_as_uint() {
          return None
        }
      None => return None
    }
  }
  decode_span_u32_immediate(instr_bytes, spans[call_pos])
}

///|
priv struct SignatureRefineAlias {
  target : UInt
  dropped_param_count : UInt
}

///|
fn parse_forward_call_target_with_prefix_param_count(
  body_bytes : Bytes,
) -> (UInt, UInt)? {
  let prefix_result = try? parse_local_decl_prefix_raise(body_bytes)
  let prefix = match prefix_result {
    Ok(v) => v
    Err(_) => return None
  }
  let prefix_end = prefix.prefix_end
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  match prefix_end_result {
    Ok(v) => if v != prefix_end { return None }
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  if spans.length() < 2 {
    return None
  }
  let call_pos = spans.length() - 2
  if spans[call_pos].opcode != 0x10U || spans[call_pos + 1].opcode != 0x0bU {
    return None
  }
  for i in 0..<call_pos {
    if spans[i].opcode != 0x20U {
      return None
    }
    match decode_span_u32_immediate(instr_bytes, spans[i]) {
      Some(local_index) =>
        if local_index != i.reinterpret_as_uint() {
          return None
        }
      None => return None
    }
  }
  match decode_span_u32_immediate(instr_bytes, spans[call_pos]) {
    Some(target) => Some((target, call_pos.reinterpret_as_uint()))
    None => None
  }
}

///|
fn parse_forward_call_target_with_appended_i32_consts(
  body_bytes : Bytes,
  wrapper_param_count : UInt,
) -> (UInt, Array[Bytes])? {
  let prefix_result = try? parse_local_decl_prefix_raise(body_bytes)
  let prefix = match prefix_result {
    Ok(v) => v
    Err(_) => return None
  }
  let prefix_end = prefix.prefix_end
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  match prefix_end_result {
    Ok(v) => if v != prefix_end { return None }
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  if spans.length() < 3 {
    return None
  }
  let wrapper_param_count_i = UInt::reinterpret_as_int(wrapper_param_count)
  if wrapper_param_count_i < 0 {
    return None
  }
  let call_pos = spans.length() - 2
  if call_pos <= wrapper_param_count_i {
    return None
  }
  if spans[call_pos].opcode != 0x10U || spans[call_pos + 1].opcode != 0x0bU {
    return None
  }
  for i in 0..<wrapper_param_count_i {
    if spans[i].opcode != 0x20U {
      return None
    }
    match decode_span_u32_immediate(instr_bytes, spans[i]) {
      Some(local_index) =>
        if local_index != i.reinterpret_as_uint() {
          return None
        }
      None => return None
    }
  }
  let appended_i32_const_instrs : Array[Bytes] = []
  for i in wrapper_param_count_i..<call_pos {
    let span = spans[i]
    if span.opcode != 0x41U {
      return None
    }
    appended_i32_const_instrs.push(
      instr_bytes[span.start:span.end_].to_bytes(),
    )
  }
  if appended_i32_const_instrs.length() == 0 {
    return None
  }
  match decode_span_u32_immediate(instr_bytes, spans[call_pos]) {
    Some(target) => Some((target, appended_i32_const_instrs))
    None => None
  }
}

///|
fn function_type_results_equal(
  a : FunctionTypeEntry,
  b : FunctionTypeEntry,
) -> Bool {
  if a.results.length() != b.results.length() {
    return false
  }
  for i in 0..<a.results.length() {
    if not(bytes_equal(a.results[i], b.results[i])) {
      return false
    }
  }
  true
}

///|
fn is_i32_value_type(value_type : Bytes) -> Bool {
  value_type.length() == 1 && value_type[0] == 0x7fU.to_byte()
}

///|
fn can_const_forward_with_appended_i32_to_target(
  wrapper_type : FunctionTypeEntry,
  target_type : FunctionTypeEntry,
  appended_i32_const_count : UInt,
) -> Bool {
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  if target_param_count != wrapper_param_count + appended_i32_const_count {
    return false
  }
  if not(function_type_results_equal(wrapper_type, target_type)) {
    return false
  }
  for i in 0..<wrapper_type.params.length() {
    if not(bytes_equal(wrapper_type.params[i], target_type.params[i])) {
      return false
    }
  }
  for i in wrapper_type.params.length()..<target_type.params.length() {
    if not(is_i32_value_type(target_type.params[i])) {
      return false
    }
  }
  true
}

///|
fn function_type_entries_equal_with_gc_canonical_map(
  a : FunctionTypeEntry,
  b : FunctionTypeEntry,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  if a.params.length() != b.params.length() ||
    a.results.length() != b.results.length() {
    return false
  }
  for i in 0..<a.params.length() {
    if not(
        type_bytes_equal_with_gc_canonical_map(
          a.params[i],
          b.params[i],
          gc_type_canonical_map,
        ),
      ) {
      return false
    }
  }
  for i in 0..<a.results.length() {
    if not(
        type_bytes_equal_with_gc_canonical_map(
          a.results[i],
          b.results[i],
          gc_type_canonical_map,
        ),
      ) {
      return false
    }
  }
  true
}

///|
fn can_signature_refine_forward_to_target(
  wrapper_type : FunctionTypeEntry,
  target_type : FunctionTypeEntry,
  forwarded_param_count : UInt,
) -> UInt? {
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  if forwarded_param_count != target_param_count {
    return None
  }
  if wrapper_param_count <= target_param_count {
    return None
  }
  if not(function_type_results_equal(wrapper_type, target_type)) {
    return None
  }
  let target_param_count_i = UInt::reinterpret_as_int(target_param_count)
  for i in 0..<target_param_count_i {
    if not(bytes_equal(wrapper_type.params[i], target_type.params[i])) {
      return None
    }
  }
  Some(wrapper_param_count - target_param_count)
}

///|
priv struct CfpConstAlias {
  target : UInt
  appended_i32_const_instrs : Array[Bytes]
}

///|
fn collect_const_call_forwarding_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
) -> Map[UInt, CfpConstAlias] {
  let alias_candidate : Map[UInt, CfpConstAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 || old_pos >= function_type_by_index.length() {
      continue
    }
    let wrapper_type_index = function_type_by_index[old_pos]
    let wrapper_type = match
      function_type_entry_by_type_index.get(wrapper_type_index) {
      Some(v) => v
      None => continue
    }
    let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
    match
      parse_forward_call_target_with_appended_i32_consts(
        code_bodies[i],
        wrapper_param_count,
      ) {
      Some((target, appended_i32_const_instrs)) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let target_type_index = function_type_by_index[target_pos]
            match function_type_entry_by_type_index.get(target_type_index) {
              Some(target_type) =>
                if can_const_forward_with_appended_i32_to_target(
                    wrapper_type,
                    target_type,
                    appended_i32_const_instrs.length().reinterpret_as_uint(),
                  ) {
                  alias_candidate.set(old_index, {
                    target,
                    appended_i32_const_instrs,
                  })
                }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  let resolved_alias : Map[UInt, CfpConstAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_alias) => {
        let seen : Map[UInt, Bool] = {}
        let mut current_target = initial_alias.target
        let appended_i32_const_instrs = initial_alias.appended_i32_const_instrs
          .copy()
        let mut valid = true
        while true {
          if current_target == old_index {
            valid = false
            break
          }
          if seen.get(current_target) is Some(_) {
            valid = false
            break
          }
          seen.set(current_target, true)
          match alias_candidate.get(current_target) {
            Some(next_alias) => {
              appended_i32_const_instrs.append(
                next_alias.appended_i32_const_instrs[:],
              )
              current_target = next_alias.target
            }
            None => break
          }
        }
        if valid {
          resolved_alias.set(old_index, {
            target: current_target,
            appended_i32_const_instrs,
          })
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn collect_call_forwarding_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_param_count_by_index : Array[UInt],
) -> Map[UInt, UInt] {
  let alias_candidate : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 ||
      old_pos >= function_type_by_index.length() ||
      old_pos >= function_param_count_by_index.length() {
      continue
    }
    let param_count = function_param_count_by_index[old_pos]
    match
      parse_forward_call_target_with_param_count(code_bodies[i], param_count) {
      Some(target) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 &&
            target_pos < function_type_by_index.length() &&
            function_type_by_index[old_pos] ==
            function_type_by_index[target_pos] {
            alias_candidate.set(old_index, target)
          }
        }
      None => ()
    }
  }
  let resolved_alias : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_target) => {
        let seen : Map[UInt, Bool] = {}
        let mut current = initial_target
        let mut valid = true
        while true {
          if current == old_index {
            valid = false
            break
          }
          if seen.get(current) is Some(_) {
            valid = false
            break
          }
          seen.set(current, true)
          match alias_candidate.get(current) {
            Some(next) => current = next
            None => break
          }
        }
        if valid {
          resolved_alias.set(old_index, current)
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn rewrite_instruction_calls_for_call_forwarding_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  alias_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call immediate in cfp")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode call immediate in cfp",
          )
      }
      let rewritten_target = match alias_map.get(target) {
        Some(v) => v
        None => target
      }
      if rewritten_target != target {
        rewritten_call_count += 1U
      }
      out.push(0x10U.to_byte())
      out.append(encode_u32_leb128(rewritten_target)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
fn rewrite_instruction_calls_for_const_call_forwarding_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  alias_map : Map[UInt, CfpConstAlias],
) -> (Bytes, UInt) raise WalyzeError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat("invalid call immediate in cfp-const")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode call immediate in cfp-const",
          )
      }
      match alias_map.get(target) {
        Some(alias_info) => {
          for const_instr in alias_info.appended_i32_const_instrs {
            out.append(const_instr[:].to_array())
          }
          out.push(0x10U.to_byte())
          out.append(encode_u32_leb128(alias_info.target)[:])
          rewritten_call_count += 1U
        }
        None => out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
fn rewrite_code_section_payload_for_const_call_forwarding_raise(
  payload : Bytes,
  alias_map : Map[UInt, CfpConstAlias],
) -> (Bytes, UInt) raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_calls_for_const_call_forwarding_raise(
      instr_bytes,
      spans,
      alias_map,
    )
    rewritten_call_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_call_count,
  )
}

///|
fn apply_const_call_forwarding_propagation_raise(
  bytes : Bytes,
) -> CfpConstApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U => import_payload = Some(payload)
      3U => function_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for cfp-const: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "cfp-const",
  )
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      function_type_entry_by_type_index.set(
        i.reinterpret_as_uint(),
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "cfp-const",
        ),
      )
    }
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let alias_map = collect_const_call_forwarding_alias_map(
    code_bodies,
    imported_function_count,
    function_type_by_index,
    function_type_entry_by_type_index,
  )
  let mut has_alias = false
  alias_map.each((_, _target) => has_alias = true)
  if not(has_alias) {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_const_call_forwarding_raise(
    code_payload,
    alias_map,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_call_count }
}

///|
fn rewrite_code_section_payload_for_call_forwarding_raise(
  payload : Bytes,
  alias_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_calls_for_call_forwarding_raise(
      instr_bytes, spans, alias_map,
    )
    rewritten_call_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_call_count,
  )
}

///|
fn apply_call_forwarding_propagation_raise(
  bytes : Bytes,
) -> CfpApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U => import_payload = Some(payload)
      3U => function_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for cfp: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "cfp",
  )
  let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let function_param_count_by_index : Array[UInt] = []
  for type_index in function_type_by_index {
    if type_index >= type_count_u {
      raise WalyzeError::InvalidFormat(
        "type index out of range in cfp: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= parsed_type_entries.length() {
      raise WalyzeError::InvalidFormat(
        "type index position out of range in cfp: " + type_index.to_string(),
      )
    }
    if parsed_type_entries[type_pos].form != 0x60U {
      raise WalyzeError::InvalidFormat(
        "non-function type index used by function in cfp: " +
        type_index.to_string(),
      )
    }
    function_param_count_by_index.push(
      parse_function_type_param_count_from_raw_raise(
        parsed_type_entries[type_pos].raw,
        "cfp",
      ),
    )
  }
  let alias_map = collect_call_forwarding_alias_map(
    code_bodies, imported_function_count, function_type_by_index, function_param_count_by_index,
  )
  let mut has_alias = false
  alias_map.each((_, _target) => has_alias = true)
  if not(has_alias) {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_call_forwarding_raise(
    code_payload, alias_map,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_call_count }
}

///|
fn collect_signature_refine_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
) -> Map[UInt, SignatureRefineAlias] {
  let alias_candidate : Map[UInt, SignatureRefineAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 || old_pos >= function_type_by_index.length() {
      continue
    }
    let wrapper_type_index = function_type_by_index[old_pos]
    let wrapper_type = match
      function_type_entry_by_type_index.get(wrapper_type_index) {
      Some(v) => v
      None => continue
    }
    match parse_forward_call_target_with_prefix_param_count(code_bodies[i]) {
      Some((target, forwarded_param_count)) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let target_type_index = function_type_by_index[target_pos]
            match function_type_entry_by_type_index.get(target_type_index) {
              Some(target_type) =>
                match
                  can_signature_refine_forward_to_target(
                    wrapper_type, target_type, forwarded_param_count,
                  ) {
                  Some(dropped_param_count) =>
                    alias_candidate.set(old_index, {
                      target,
                      dropped_param_count,
                    })
                  None => ()
                }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  let resolved_alias : Map[UInt, SignatureRefineAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_alias) => {
        let seen : Map[UInt, Bool] = {}
        let mut current_target = initial_alias.target
        let mut dropped_param_count = initial_alias.dropped_param_count
        let mut valid = true
        while true {
          if current_target == old_index {
            valid = false
            break
          }
          if seen.get(current_target) is Some(_) {
            valid = false
            break
          }
          seen.set(current_target, true)
          match alias_candidate.get(current_target) {
            Some(next_alias) => {
              dropped_param_count += next_alias.dropped_param_count
              current_target = next_alias.target
            }
            None => break
          }
        }
        if valid {
          resolved_alias.set(old_index, {
            target: current_target,
            dropped_param_count,
          })
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn rewrite_instruction_calls_for_signature_refining_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  alias_map : Map[UInt, SignatureRefineAlias],
) -> (Bytes, UInt) raise WalyzeError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WalyzeError::InvalidFormat(
          "invalid call immediate in signature-refine",
        )
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "failed to decode call immediate in signature-refine",
          )
      }
      match alias_map.get(target) {
        Some(alias_info) => {
          for _ in 0U..<alias_info.dropped_param_count {
            out.push(0x1aU.to_byte())
          }
          out.push(0x10U.to_byte())
          out.append(encode_u32_leb128(alias_info.target)[:])
          rewritten_call_count += 1U
        }
        None => out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
fn rewrite_code_section_payload_for_signature_refining_raise(
  payload : Bytes,
  alias_map : Map[UInt, SignatureRefineAlias],
) -> (Bytes, UInt) raise WalyzeError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_calls_for_signature_refining_raise(
      instr_bytes, spans, alias_map,
    )
    rewritten_call_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_call_count,
  )
}

///|
fn apply_signature_refining_raise(
  bytes : Bytes,
) -> SignatureRefineApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U => import_payload = Some(payload)
      3U => function_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for signature-refine: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "signature-refine",
  )
  let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      let type_index = i.reinterpret_as_uint()
      function_type_entry_by_type_index.set(
        type_index,
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "signature-refine",
        ),
      )
    }
  }
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  for type_index in function_type_by_index {
    if type_index >= type_count_u {
      raise WalyzeError::InvalidFormat(
        "type index out of range in signature-refine: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= parsed_type_entries.length() {
      raise WalyzeError::InvalidFormat(
        "type index position out of range in signature-refine: " +
        type_index.to_string(),
      )
    }
    if parsed_type_entries[type_pos].form != 0x60U {
      raise WalyzeError::InvalidFormat(
        "non-function type index used by function in signature-refine: " +
        type_index.to_string(),
      )
    }
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let alias_map = collect_signature_refine_alias_map(
    code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
  )
  let mut has_alias = false
  alias_map.each((_index, _alias) => has_alias = true)
  if not(has_alias) {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_signature_refining_raise(
    code_payload, alias_map,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_call_count }
}

///|
fn apply_remove_unused_module_elements(
  bytes : Bytes,
  config : OptimizeConfig,
) -> RumeApplyResult {
  let result = try? apply_remove_unused_module_elements_raise(bytes, config)
  match result {
    Ok(v) => v
    Err(_) =>
      {
        bytes,
        removed_import_count: 0U,
        removed_table_count: 0U,
        removed_memory_count: 0U,
        removed_global_count: 0U,
        removed_element_count: 0U,
        removed_data_count: 0U,
        removed_export_count: 0U,
      }
  }
}

///|
fn apply_remove_unused_module_elements_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> RumeApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_section_payload : Bytes? = None
  let mut export_section_payload : Bytes? = None
  let mut table_section_payload : Bytes? = None
  let mut memory_section_payload : Bytes? = None
  let mut global_section_payload : Bytes? = None
  let mut element_section_payload : Bytes? = None
  let mut data_section_payload : Bytes? = None
  let mut import_entries : Array[ImportSectionEntry] = []
  let used_table_indices : Array[UInt] = []
  let used_memory_indices : Array[UInt] = []
  let global_root_indices : Array[UInt] = []
  let mut removed_export_by_name_count = 0U
  let mut analysis_complete = true
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => {
        import_section_payload = Some(payload)
        import_entries = parse_import_section_entries_raise(payload)
      }
      4U => table_section_payload = Some(payload)
      5U => memory_section_payload = Some(payload)
      6U => global_section_payload = Some(payload)
      7U => {
        let mut effective_export_payload = payload
        if config.closed_world &&
          not(config.safe_mode) &&
          config.closed_world_root_exports.length() > 0 {
          let (filtered, removed) = rewrite_export_section_payload_for_keep_names_raise(
            payload,
            config.closed_world_root_exports,
          )
          effective_export_payload = filtered
          removed_export_by_name_count += removed
        }
        export_section_payload = Some(effective_export_payload)
        for index in parse_export_table_indices(effective_export_payload) {
          push_unique_u32(used_table_indices, index)
        }
        for index in parse_export_memory_indices(effective_export_payload) {
          push_unique_u32(used_memory_indices, index)
        }
        for index in parse_export_global_indices(effective_export_payload) {
          push_unique_u32(global_root_indices, index)
        }
      }
      9U => {
        element_section_payload = Some(payload)
        let global_result = try? collect_used_global_indices_from_element_section_raise(
          payload,
        )
        match global_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32(global_root_indices, index)
            }
          Err(_) => analysis_complete = false
        }
      }
      10U => {
        match collect_used_table_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32(used_table_indices, index)
            }
          None => analysis_complete = false
        }
        match collect_used_memory_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32(used_memory_indices, index)
            }
          None => analysis_complete = false
        }
        match collect_used_global_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32(global_root_indices, index)
            }
          None => analysis_complete = false
        }
      }
      11U => {
        data_section_payload = Some(payload)
        let data_result = try? collect_used_memory_and_global_indices_from_data_section_raise(
          payload,
        )
        match data_result {
          Ok((memory_indices, global_indices)) => {
            for index in memory_indices {
              push_unique_u32(used_memory_indices, index)
            }
            for index in global_indices {
              push_unique_u32(global_root_indices, index)
            }
          }
          Err(_) => analysis_complete = false
        }
      }
      _ => ()
    }
  }
  if not(analysis_complete) {
    return {
      bytes,
      removed_import_count: 0U,
      removed_table_count: 0U,
      removed_memory_count: 0U,
      removed_global_count: 0U,
      removed_element_count: 0U,
      removed_data_count: 0U,
      removed_export_count: 0U,
    }
  }
  let mut imported_table_count = 0U
  let mut imported_memory_count = 0U
  let mut imported_global_count = 0U
  for entry in import_entries {
    match entry.kind {
      1U => imported_table_count += 1U
      2U => imported_memory_count += 1U
      3U => imported_global_count += 1U
      _ => ()
    }
  }
  let keep_import_tables : Array[Bool] = []
  for i in 0U..<imported_table_count {
    keep_import_tables.push(used_table_indices.contains(i))
  }
  let keep_import_memories : Array[Bool] = []
  for i in 0U..<imported_memory_count {
    keep_import_memories.push(used_memory_indices.contains(i))
  }
  let local_table_entries = match table_section_payload {
    Some(payload) => parse_table_section_entries_raise(payload)
    None => []
  }
  let local_memory_entries = match memory_section_payload {
    Some(payload) => parse_memory_section_entries_raise(payload)
    None => []
  }
  let local_global_entries : Array[GlobalSectionEntry] = match
    global_section_payload {
    Some(payload) => parse_global_section_entries_with_refs_raise(payload)
    None => []
  }
  let used_global_indices : Array[UInt] = []
  for index in global_root_indices {
    push_unique_u32(used_global_indices, index)
  }
  let queue : Array[UInt] = used_global_indices.copy()
  let mut queue_index = 0
  while queue_index < queue.length() {
    let current = queue[queue_index]
    queue_index += 1
    if current < imported_global_count {
      continue
    }
    let local_index_u = current - imported_global_count
    let local_index = UInt::reinterpret_as_int(local_index_u)
    if local_index >= 0 && local_index < local_global_entries.length() {
      for dep in local_global_entries[local_index].init_global_refs {
        if not(used_global_indices.contains(dep)) {
          push_unique_u32(used_global_indices, dep)
          queue.push(dep)
        }
      }
    }
  }
  let keep_import_globals : Array[Bool] = []
  for i in 0U..<imported_global_count {
    keep_import_globals.push(used_global_indices.contains(i))
  }
  let table_index_map : Map[UInt, UInt] = {}
  let mut kept_imported_table_count = 0U
  for i in 0U..<imported_table_count {
    let index = UInt::reinterpret_as_int(i)
    if index < 0 || index >= keep_import_tables.length() {
      raise WalyzeError::InvalidFormat("table import keep index out of range")
    }
    if keep_import_tables[index] {
      table_index_map.set(i, kept_imported_table_count)
      kept_imported_table_count += 1U
    }
  }
  let keep_local_tables : Array[Bool] = []
  let mut kept_local_table_count = 0U
  let mut removed_table_count = 0U
  for i in 0..<local_table_entries.length() {
    let old_index = imported_table_count + i.reinterpret_as_uint()
    if used_table_indices.contains(old_index) {
      keep_local_tables.push(true)
      table_index_map.set(
        old_index,
        kept_imported_table_count + kept_local_table_count,
      )
      kept_local_table_count += 1U
    } else {
      keep_local_tables.push(false)
      removed_table_count += 1U
    }
  }
  let memory_index_map : Map[UInt, UInt] = {}
  let mut kept_imported_memory_count = 0U
  for i in 0U..<imported_memory_count {
    let index = UInt::reinterpret_as_int(i)
    if index < 0 || index >= keep_import_memories.length() {
      raise WalyzeError::InvalidFormat("memory import keep index out of range")
    }
    if keep_import_memories[index] {
      memory_index_map.set(i, kept_imported_memory_count)
      kept_imported_memory_count += 1U
    }
  }
  let keep_local_memories : Array[Bool] = []
  let mut kept_local_memory_count = 0U
  let mut removed_memory_count = 0U
  for i in 0..<local_memory_entries.length() {
    let old_index = imported_memory_count + i.reinterpret_as_uint()
    if used_memory_indices.contains(old_index) {
      keep_local_memories.push(true)
      memory_index_map.set(
        old_index,
        kept_imported_memory_count + kept_local_memory_count,
      )
      kept_local_memory_count += 1U
    } else {
      keep_local_memories.push(false)
      removed_memory_count += 1U
    }
  }
  let global_index_map : Map[UInt, UInt] = {}
  let mut kept_imported_global_count = 0U
  for i in 0U..<imported_global_count {
    let index = UInt::reinterpret_as_int(i)
    if index < 0 || index >= keep_import_globals.length() {
      raise WalyzeError::InvalidFormat("global import keep index out of range")
    }
    if keep_import_globals[index] {
      global_index_map.set(i, kept_imported_global_count)
      kept_imported_global_count += 1U
    }
  }
  let keep_local_globals : Array[Bool] = []
  let mut kept_local_global_count = 0U
  let mut removed_global_count = 0U
  for i in 0..<local_global_entries.length() {
    let old_index = imported_global_count + i.reinterpret_as_uint()
    if used_global_indices.contains(old_index) {
      keep_local_globals.push(true)
      global_index_map.set(
        old_index,
        kept_imported_global_count + kept_local_global_count,
      )
      kept_local_global_count += 1U
    } else {
      keep_local_globals.push(false)
      removed_global_count += 1U
    }
  }
  let mut removed_import_count = 0U
  let mut rewritten_import_payload : Bytes? = None
  match import_section_payload {
    Some(payload) => {
      let (rewritten, removed) = rewrite_import_section_payload_for_keep_raise(
        payload, keep_import_tables, keep_import_memories, keep_import_globals,
      )
      rewritten_import_payload = Some(rewritten)
      removed_import_count = removed
    }
    None => ()
  }
  let mut removed_element_count = 0U
  let mut rewritten_element_payload : Bytes? = None
  let element_index_map : Map[UInt, UInt] = {}
  match element_section_payload {
    Some(payload) => {
      let (rewritten, removed_segments, segment_index_map) = rewrite_element_section_payload_for_table_index_map_raise(
        payload, table_index_map, global_index_map,
      )
      rewritten_element_payload = Some(rewritten)
      removed_element_count = removed_segments
      segment_index_map.each((key, value) => element_index_map.set(key, value))
    }
    None => ()
  }
  let mut removed_data_count = 0U
  let mut rewritten_data_payload : Bytes? = None
  let data_index_map : Map[UInt, UInt] = {}
  match data_section_payload {
    Some(payload) => {
      let (rewritten, removed_segments, segment_index_map) = rewrite_data_section_payload_for_memory_global_index_map_raise(
        payload, memory_index_map, global_index_map,
      )
      rewritten_data_payload = Some(rewritten)
      removed_data_count = removed_segments
      segment_index_map.each((key, value) => data_index_map.set(key, value))
    }
    None => ()
  }
  let mut removed_export_count = removed_export_by_name_count
  let mut rewritten_export_payload : Bytes? = None
  match export_section_payload {
    Some(payload) => {
      let (rewritten, removed) = rewrite_export_section_payload_for_module_index_maps_raise(
        payload, table_index_map, memory_index_map, global_index_map,
      )
      rewritten_export_payload = Some(rewritten)
      removed_export_count += removed
    }
    None => ()
  }
  if removed_import_count == 0U &&
    removed_table_count == 0U &&
    removed_memory_count == 0U &&
    removed_global_count == 0U &&
    removed_element_count == 0U &&
    removed_data_count == 0U &&
    removed_export_count == 0U {
    return {
      bytes,
      removed_import_count,
      removed_table_count,
      removed_memory_count,
      removed_global_count,
      removed_element_count,
      removed_data_count,
      removed_export_count,
    }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U =>
        match rewritten_import_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 2U, rewritten)
            }
          None => ()
        }
      4U => {
        let rewritten = rewrite_table_section_payload_for_keep_local_raise(
          payload, keep_local_tables,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 4U, rewritten)
        }
      }
      5U => {
        let rewritten = rewrite_memory_section_payload_for_keep_local_raise(
          payload, keep_local_memories,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 5U, rewritten)
        }
      }
      6U => {
        let rewritten = rewrite_global_section_payload_for_keep_local_and_global_index_map_raise(
          payload, keep_local_globals, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 6U, rewritten)
        }
      }
      7U =>
        match rewritten_export_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 7U, rewritten)
            }
          None => ()
        }
      9U =>
        match rewritten_element_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 9U, rewritten)
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_module_index_map_raise(
            payload, table_index_map, memory_index_map, global_index_map, element_index_map,
            data_index_map,
          ),
        )
      11U =>
        match rewritten_data_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 11U, rewritten)
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_import_count,
    removed_table_count,
    removed_memory_count,
    removed_global_count,
    removed_element_count,
    removed_data_count,
    removed_export_count,
  }
}

///|
fn apply_type_refining(bytes : Bytes) -> TypeRefineApplyResult {
  let result = try? apply_type_refining_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, refined_type_count: 0U }
  }
}

///|
fn apply_type_refining_raise(
  bytes : Bytes,
) -> TypeRefineApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  for section in sections {
    match section.section_id {
      1U =>
        type_section_payload = Some(
          bytes[section.payload_start:section.section_end].to_bytes(),
        )
      13U =>
        raise WalyzeError::InvalidFormat(
          "tag section is not supported in type-refine",
        )
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, refined_type_count: 0U }
  }
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "type-refine",
  )
  if parsed_type_entries.length() <= 1 {
    return { bytes, refined_type_count: 0U }
  }
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  let gc_type_canonical_map : Map[UInt, UInt] = {}
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let entry = parsed_type_entries[i]
    if entry.form == 0x60U {
      function_type_entry_by_type_index.set(
        old_type_index,
        parse_function_type_entry_from_raw_raise(entry.raw, "type-refine"),
      )
      continue
    }
    let mut canonical = old_type_index
    for j in 0..<i {
      if parsed_type_entries[j].form == entry.form &&
        parsed_type_entries[j].form != 0x60U &&
        gc_type_entries_equal_with_canonical_map_raise(
          entry.raw,
          parsed_type_entries[j].raw,
          gc_type_canonical_map,
        ) {
        canonical = remap_gc_type_index_for_refine(
          j.reinterpret_as_uint(),
          gc_type_canonical_map,
        )
        break
      }
    }
    gc_type_canonical_map.set(old_type_index, canonical)
  }
  let keep_types : Array[Bool] = []
  let canonical_function_type_for_old : Map[UInt, UInt] = {}
  let mut refined_type_count = 0U
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let entry = parsed_type_entries[i]
    if entry.form != 0x60U {
      keep_types.push(true)
      continue
    }
    let current_function_type = match
      function_type_entry_by_type_index.get(old_type_index) {
      Some(v) => v
      None =>
        raise WalyzeError::InvalidFormat(
          "missing function type entry in type-refine: " +
          old_type_index.to_string(),
        )
    }
    let mut canonical = old_type_index
    for j in 0..<i {
      if parsed_type_entries[j].form != 0x60U {
        continue
      }
      let candidate_type_index = j.reinterpret_as_uint()
      let candidate_function_type = match
        function_type_entry_by_type_index.get(candidate_type_index) {
        Some(v) => v
        None =>
          raise WalyzeError::InvalidFormat(
            "missing candidate function type entry in type-refine: " +
            candidate_type_index.to_string(),
          )
      }
      if function_type_entries_equal_with_gc_canonical_map(
          current_function_type, candidate_function_type, gc_type_canonical_map,
        ) {
        canonical = candidate_type_index
        break
      }
    }
    if canonical == old_type_index {
      keep_types.push(true)
    } else {
      keep_types.push(false)
      canonical_function_type_for_old.set(old_type_index, canonical)
      refined_type_count += 1U
    }
  }
  let type_index_map : Map[UInt, UInt] = {}
  let mut new_type_count = 0U
  for i in 0..<keep_types.length() {
    if keep_types[i] {
      type_index_map.set(i.reinterpret_as_uint(), new_type_count)
      new_type_count += 1U
    }
  }
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    match canonical_function_type_for_old.get(old_type_index) {
      Some(canonical) =>
        type_index_map.set(
          old_type_index,
          remap_type_index_raise(canonical, type_index_map),
        )
      None => ()
    }
  }
  if refined_type_count == 0U {
    return { bytes, refined_type_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => {
        let rewritten = rewrite_type_section_payload_for_keep_raise(
          payload, keep_types,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 1U, rewritten)
        }
      }
      2U =>
        append_encoded_section(
          out,
          2U,
          rewrite_import_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), refined_type_count }
}

///|
fn apply_signature_pruning(bytes : Bytes) -> SignaturePruneApplyResult {
  let result = try? apply_signature_pruning_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
}

///|
fn apply_signature_pruning_raise(
  bytes : Bytes,
) -> SignaturePruneApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut type_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  let protected_function_indices : Array[UInt] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      2U => imported_function_count += parse_import_function_count(payload)
      3U => function_section_payload = Some(payload)
      6U =>
        for index in parse_global_section_function_refs_raise(payload) {
          push_unique_u32(protected_function_indices, index)
        }
      7U => {
        let exports = parse_export_function_names(payload)
        exports.each((index, _names) => push_unique_u32(
          protected_function_indices, index,
        ))
      }
      8U =>
        push_unique_u32(
          protected_function_indices,
          parse_start_function_index(payload),
        )
      9U =>
        for index in parse_element_section_function_refs_raise(payload) {
          push_unique_u32(protected_function_indices, index)
        }
      10U => code_section_payload = Some(payload)
      13U =>
        raise WalyzeError::InvalidFormat(
          "tag section is not supported in signature-prune",
        )
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  let function_payload = match function_section_payload {
    Some(v) => v
    None => return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  if function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for signature-prune: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "signature-prune",
  )
  let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      function_type_entry_by_type_index.set(
        i.reinterpret_as_uint(),
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "signature-prune",
        ),
      )
    }
  }
  for type_index in function_type_indices {
    if type_index >= type_count_u {
      raise WalyzeError::InvalidFormat(
        "type index out of range in signature-prune: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= parsed_type_entries.length() {
      raise WalyzeError::InvalidFormat(
        "type index position out of range in signature-prune: " +
        type_index.to_string(),
      )
    }
    if parsed_type_entries[type_pos].form != 0x60U {
      raise WalyzeError::InvalidFormat(
        "non-function type index used by function in signature-prune: " +
        type_index.to_string(),
      )
    }
  }
  for index in collect_ref_func_indices_from_code_section_raise(code_payload) {
    push_unique_u32(protected_function_indices, index)
  }
  let rewritten_type_entries : Array[Bytes] = []
  for entry in parsed_type_entries {
    rewritten_type_entries.push(entry.raw)
  }
  let rewritten_function_type_indices = function_type_indices.copy()
  let rewritten_code_bodies = code_bodies.copy()
  let old_param_count_by_local_pos : Map[UInt, UInt] = {}
  let removed_param_count_by_local_pos : Map[UInt, UInt] = {}
  let removed_param_count_by_function : Map[UInt, UInt] = {}
  let mut pruned_function_count = 0U
  let mut pruned_param_count = 0U
  for i in 0..<code_bodies.length() {
    let function_index = imported_function_count + i.reinterpret_as_uint()
    if protected_function_indices.contains(function_index) {
      continue
    }
    let type_index = function_type_indices[i]
    let type_entry = match function_type_entry_by_type_index.get(type_index) {
      Some(v) => v
      None =>
        raise WalyzeError::InvalidFormat(
          "non-function type index used by function in signature-prune: " +
          type_index.to_string(),
        )
    }
    let old_param_count = type_entry.params.length().reinterpret_as_uint()
    if old_param_count == 0U {
      continue
    }
    let body = code_bodies[i]
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let used_param_indices = collect_used_param_indices_from_instruction_raise(
      instr_bytes, spans, old_param_count,
    )
    let removed_param_count = compute_removed_trailing_param_count(
      old_param_count, used_param_indices,
    )
    if removed_param_count == 0U {
      continue
    }
    let new_param_count = old_param_count - removed_param_count
    let new_param_count_i = UInt::reinterpret_as_int(new_param_count)
    if new_param_count_i < 0 || new_param_count_i > type_entry.params.length() {
      raise WalyzeError::InvalidFormat(
        "invalid param trim count in signature-prune: old=" +
        old_param_count.to_string() +
        " removed=" +
        removed_param_count.to_string(),
      )
    }
    let new_params : Array[Bytes] = []
    for j in 0..<new_param_count_i {
      new_params.push(type_entry.params[j])
    }
    let new_type_entry = encode_function_type_entry(
      new_params,
      type_entry.results,
    )
    let new_type_index = match
      find_type_entry_index(rewritten_type_entries, new_type_entry) {
      Some(v) => v
      None => {
        let idx = rewritten_type_entries.length().reinterpret_as_uint()
        rewritten_type_entries.push(new_type_entry)
        idx
      }
    }
    rewritten_function_type_indices[i] = new_type_index
    let local_pos = i.reinterpret_as_uint()
    old_param_count_by_local_pos.set(local_pos, old_param_count)
    removed_param_count_by_local_pos.set(local_pos, removed_param_count)
    removed_param_count_by_function.set(function_index, removed_param_count)
    pruned_function_count += 1U
    pruned_param_count += removed_param_count
  }
  if pruned_function_count == 0U {
    return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  for i in 0..<rewritten_code_bodies.length() {
    let local_pos = i.reinterpret_as_uint()
    match removed_param_count_by_local_pos.get(local_pos) {
      Some(removed_param_count) =>
        if removed_param_count > 0U {
          let old_param_count = match
            old_param_count_by_local_pos.get(local_pos) {
            Some(v) => v
            None =>
              raise WalyzeError::InvalidFormat(
                "signature-prune local metadata missing",
              )
          }
          rewritten_code_bodies[i] = rewrite_code_body_for_signature_pruning_raise(
            rewritten_code_bodies[i],
            old_param_count,
            removed_param_count,
          )
        }
      None => ()
    }
  }
  for i in 0..<rewritten_code_bodies.length() {
    rewritten_code_bodies[i] = rewrite_code_body_calls_for_signature_pruning_raise(
      rewritten_code_bodies[i],
      removed_param_count_by_function,
    )
  }
  let rewritten_type_payload = encode_type_section_payload(
    rewritten_type_entries,
  )
  let rewritten_function_payload = encode_function_section_payload_from_type_indices(
    rewritten_function_type_indices,
  )
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_code_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    match section.section_id {
      1U => append_encoded_section(out, 1U, rewritten_type_payload)
      3U => append_encoded_section(out, 3U, rewritten_function_payload)
      10U => append_encoded_section(out, 10U, rewritten_code_payload)
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    pruned_function_count,
    pruned_param_count,
  }
}

///|
fn apply_remove_unused_types(bytes : Bytes) -> RemoveUnusedTypesApplyResult {
  let result = try? apply_remove_unused_types_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, removed_type_count: 0U }
  }
}

///|
fn apply_remove_unused_types_raise(
  bytes : Bytes,
) -> RemoveUnusedTypesApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  let mut import_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      2U => import_section_payload = Some(payload)
      3U => function_section_payload = Some(payload)
      10U => code_section_payload = Some(payload)
      13U =>
        raise WalyzeError::InvalidFormat(
          "tag section is not supported in remove-unused-types",
        )
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, removed_type_count: 0U }
  }
  let type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "remove-unused-types",
  )
  if type_entries.length() == 0 {
    return { bytes, removed_type_count: 0U }
  }
  let used_type_indices : Array[UInt] = []
  match import_section_payload {
    Some(payload) =>
      for
        type_index in collect_used_type_indices_from_import_section_raise(
          payload,
        ) {
        push_unique_u32(used_type_indices, type_index)
      }
    None => ()
  }
  match function_section_payload {
    Some(payload) =>
      for type_index in parse_function_type_indices(payload) {
        push_unique_u32(used_type_indices, type_index)
      }
    None => ()
  }
  match code_section_payload {
    Some(payload) =>
      for
        type_index in collect_used_type_indices_from_code_section_raise(payload) {
        push_unique_u32(used_type_indices, type_index)
      }
    None => ()
  }
  let type_count_u = type_entries.length().reinterpret_as_uint()
  for type_index in used_type_indices {
    if type_index >= type_count_u {
      raise WalyzeError::InvalidFormat(
        "type index out of range in remove-unused-types: " +
        type_index.to_string(),
      )
    }
  }
  let queue = used_type_indices.copy()
  let mut queue_head = 0
  while queue_head < queue.length() {
    let current = queue[queue_head]
    queue_head += 1
    let current_pos = UInt::reinterpret_as_int(current)
    if current_pos < 0 || current_pos >= type_entries.length() {
      raise WalyzeError::InvalidFormat(
        "type index position out of range in remove-unused-types: " +
        current.to_string(),
      )
    }
    for dep in type_entries[current_pos].referenced_type_indices {
      if dep >= type_count_u {
        raise WalyzeError::InvalidFormat(
          "referenced type index out of range in remove-unused-types: " +
          dep.to_string(),
        )
      }
      if not(used_type_indices.contains(dep)) {
        push_unique_u32(used_type_indices, dep)
        queue.push(dep)
      }
    }
  }
  let keep_types : Array[Bool] = []
  let type_index_map : Map[UInt, UInt] = {}
  let mut kept_type_count = 0U
  for i in 0..<type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let keep = used_type_indices.contains(old_type_index)
    keep_types.push(keep)
    if keep {
      type_index_map.set(old_type_index, kept_type_count)
      kept_type_count += 1U
    }
  }
  let removed_type_count = type_count_u - kept_type_count
  if removed_type_count == 0U {
    return { bytes, removed_type_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => {
        let rewritten = rewrite_type_section_payload_for_keep_raise(
          payload, keep_types,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 1U, rewritten)
        }
      }
      2U =>
        append_encoded_section(
          out,
          2U,
          rewrite_import_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), removed_type_count }
}

///|
fn apply_dce_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> DceApplyResult raise WalyzeError {
  let export_root_names = export_root_names_from_config(config)
  let call_graph = analyze_call_graph_raise(bytes, export_root_names)
  if call_graph.partial {
    return {
      bytes,
      removed_function_count: 0U,
      removed_body_bytes: 0U,
      dropped_name_section: false,
    }
  }
  let local_count = UInt::reinterpret_as_int(call_graph.local_function_count)
  if local_count < 0 {
    raise WalyzeError::InvalidFormat("local function count overflow")
  }
  if local_count != call_graph.nodes.length() {
    raise WalyzeError::InvalidFormat(
      "call graph node length mismatch: expected=" +
      local_count.to_string() +
      " actual=" +
      call_graph.nodes.length().to_string(),
    )
  }
  let keep_local : Array[Bool] = []
  let index_map : Map[UInt, UInt] = {}
  for i in 0U..<call_graph.imported_function_count {
    index_map.set(i, i)
  }
  let mut kept_local_count = 0U
  let mut removed_function_count = 0U
  for node in call_graph.nodes {
    keep_local.push(node.reachable_from_roots)
    if node.reachable_from_roots {
      index_map.set(
        node.function_index,
        call_graph.imported_function_count + kept_local_count,
      )
      kept_local_count += 1U
    } else {
      removed_function_count += 1U
    }
  }
  if removed_function_count == 0U {
    return {
      bytes,
      removed_function_count,
      removed_body_bytes: 0U,
      dropped_name_section: false,
    }
  }
  let sections = parse_core_sections_raise(bytes)
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      3U => {
        let rewritten = rewrite_function_section_payload_for_dce_raise(
          payload, keep_local,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 3U, rewritten)
        }
      }
      7U =>
        append_encoded_section(
          out,
          7U,
          rewrite_export_section_payload_for_dce_raise(payload, index_map),
        )
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(payload, index_map),
        )
      10U => {
        let rewritten = rewrite_code_section_payload_for_dce_raise(
          payload, keep_local, index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 10U, rewritten)
        }
      }
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
              dropped_name_section = true
            } else {
              out.append(
                bytes[section.section_start:section.section_end].to_array(),
              )
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      6U =>
        append_encoded_section(
          out,
          6U,
          rewrite_global_section_payload_for_index_map_raise(payload, index_map),
        )
      9U =>
        append_encoded_section(
          out,
          9U,
          rewrite_element_section_payload_for_index_map_raise(
            payload, index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_function_count,
    removed_body_bytes: call_graph.dead_body_bytes,
    dropped_name_section,
  }
}

///|
fn apply_dfe_raise(bytes : Bytes) -> DfeApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut function_type_indices : Array[UInt] = []
  let mut code_bodies : Array[Bytes] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => function_type_indices = parse_function_type_indices(payload)
      10U => code_bodies = parse_code_bodies(payload)
      _ => ()
    }
  }
  if function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for dfe: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let keep_local : Array[Bool] = []
  let index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_function_count {
    index_map.set(i, i)
  }
  let mut kept_local_count = 0U
  let mut removed_function_count = 0U
  let mut removed_body_bytes = 0U
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let mut canonical_pos : Int? = None
    for j in 0..<i {
      if keep_local[j] &&
        function_type_indices[j] == function_type_indices[i] &&
        bytes_equal(code_bodies[j], code_bodies[i]) {
        canonical_pos = Some(j)
        break
      }
    }
    match canonical_pos {
      Some(pos) => {
        keep_local.push(false)
        let canonical_old_index = imported_function_count +
          pos.reinterpret_as_uint()
        let canonical_new_index = remap_function_index_raise(
          canonical_old_index, index_map,
        )
        index_map.set(old_index, canonical_new_index)
        removed_function_count += 1U
        removed_body_bytes += code_bodies[i].length().reinterpret_as_uint()
      }
      None => {
        keep_local.push(true)
        index_map.set(old_index, imported_function_count + kept_local_count)
        kept_local_count += 1U
      }
    }
  }
  if removed_function_count == 0U {
    return {
      bytes,
      removed_function_count,
      removed_body_bytes,
      dropped_name_section: false,
    }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_dce_raise(payload, keep_local),
        )
      7U =>
        append_encoded_section(
          out,
          7U,
          rewrite_export_section_payload_for_dce_raise(payload, index_map),
        )
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(payload, index_map),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_dce_raise(
            payload, keep_local, index_map,
          ),
        )
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
              dropped_name_section = true
            } else {
              out.append(
                bytes[section.section_start:section.section_end].to_array(),
              )
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      6U =>
        append_encoded_section(
          out,
          6U,
          rewrite_global_section_payload_for_index_map_raise(payload, index_map),
        )
      9U =>
        append_encoded_section(
          out,
          9U,
          rewrite_element_section_payload_for_index_map_raise(
            payload, index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_function_count,
    removed_body_bytes,
    dropped_name_section,
  }
}

///|
fn apply_merge_similar_functions_raise(
  bytes : Bytes,
) -> MsfApplyResult raise WalyzeError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut imported_function_type_indices : Array[UInt] = []
  let mut local_function_type_indices : Array[UInt] = []
  let mut code_bodies : Array[Bytes] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U =>
        imported_function_type_indices = parse_import_function_type_indices(
          payload,
        )
      3U => local_function_type_indices = parse_function_type_indices(payload)
      10U => code_bodies = parse_code_bodies(payload)
      _ => ()
    }
  }
  if local_function_type_indices.length() != code_bodies.length() {
    raise WalyzeError::InvalidFormat(
      "function/code section count mismatch for msf: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let function_param_count_by_index : Array[UInt] = []
  if function_type_by_index.length() > 0 {
    let type_payload = match type_payload {
      Some(v) => v
      None =>
        raise WalyzeError::InvalidFormat("type section is missing for msf")
    }
    let parsed_type_entries = parse_type_section_entries_with_refs_raise(
      type_payload, "msf",
    )
    let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
    for type_index in function_type_by_index {
      if type_index >= type_count_u {
        raise WalyzeError::InvalidFormat(
          "type index out of range in msf: " + type_index.to_string(),
        )
      }
      let type_pos = UInt::reinterpret_as_int(type_index)
      if type_pos < 0 || type_pos >= parsed_type_entries.length() {
        raise WalyzeError::InvalidFormat(
          "type index position out of range in msf: " + type_index.to_string(),
        )
      }
      if parsed_type_entries[type_pos].form != 0x60U {
        raise WalyzeError::InvalidFormat(
          "non-function type index used by function in msf: " +
          type_index.to_string(),
        )
      }
      function_param_count_by_index.push(
        parse_function_type_param_count_from_raw_raise(
          parsed_type_entries[type_pos].raw,
          "msf",
        ),
      )
    }
  }
  let alias_candidate : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 ||
      old_pos >= function_type_by_index.length() ||
      old_pos >= function_param_count_by_index.length() {
      continue
    }
    let param_count = function_param_count_by_index[old_pos]
    match parse_forward_call_target_with_param_count(
      code_bodies[i], param_count,
    ) {
      Some(target) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 &&
            target_pos < function_type_by_index.length() &&
            function_type_by_index[old_pos] ==
            function_type_by_index[target_pos] {
            alias_candidate.set(old_index, target)
          }
        }
      None => ()
    }
  }
  let keep_local : Array[Bool] = []
  let resolved_target_for_local : Array[UInt?] = []
  for i in 0..<local_function_type_indices.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_target) => {
        let seen : Map[UInt, Bool] = {}
        let mut current = initial_target
        let mut valid = true
        while true {
          if current == old_index {
            valid = false
            break
          }
          if seen.get(current) is Some(_) {
            valid = false
            break
          }
          seen.set(current, true)
          match alias_candidate.get(current) {
            Some(next) => current = next
            None => break
          }
        }
        if valid {
          keep_local.push(false)
          resolved_target_for_local.push(Some(current))
        } else {
          keep_local.push(true)
          resolved_target_for_local.push(None)
        }
      }
      None => {
        keep_local.push(true)
        resolved_target_for_local.push(None)
      }
    }
  }
  let index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_function_count {
    index_map.set(i, i)
  }
  let mut kept_local_count = 0U
  for i in 0..<keep_local.length() {
    if keep_local[i] {
      index_map.set(
        imported_function_count + i.reinterpret_as_uint(),
        imported_function_count + kept_local_count,
      )
      kept_local_count += 1U
    }
  }
  let mut removed_function_count = 0U
  let mut removed_body_bytes = 0U
  for i in 0..<resolved_target_for_local.length() {
    match resolved_target_for_local[i] {
      Some(target_old_index) => {
        let old_index = imported_function_count + i.reinterpret_as_uint()
        let target_new_index = remap_function_index_raise(
          target_old_index, index_map,
        )
        index_map.set(old_index, target_new_index)
        removed_function_count += 1U
        removed_body_bytes += code_bodies[i].length().reinterpret_as_uint()
      }
      None => ()
    }
  }
  if removed_function_count == 0U {
    return {
      bytes,
      removed_function_count,
      removed_body_bytes,
      dropped_name_section: false,
    }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_dce_raise(payload, keep_local),
        )
      7U =>
        append_encoded_section(
          out,
          7U,
          rewrite_export_section_payload_for_dce_raise(payload, index_map),
        )
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(payload, index_map),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_dce_raise(
            payload, keep_local, index_map,
          ),
        )
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
              dropped_name_section = true
            } else {
              out.append(
                bytes[section.section_start:section.section_end].to_array(),
              )
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      6U =>
        append_encoded_section(
          out,
          6U,
          rewrite_global_section_payload_for_index_map_raise(payload, index_map),
        )
      9U =>
        append_encoded_section(
          out,
          9U,
          rewrite_element_section_payload_for_index_map_raise(
            payload, index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_function_count,
    removed_body_bytes,
    dropped_name_section,
  }
}

///|
fn unique_sorted(xs : Array[String]) -> Array[String] {
  let out = xs.copy()
  out.sort()
  out.dedup()
  out
}

///|
fn merge_root_names(
  base : Array[String],
  extra : Array[String],
) -> Array[String] {
  let merged = base.copy()
  merged.append(extra[:])
  unique_sorted(merged)
}

///|
fn clone_optimize_config(
  config : OptimizeConfig,
  pass_rounds? : UInt = config.pass_rounds,
  closed_world_root_exports? : Array[String] = config.closed_world_root_exports,
) -> OptimizeConfig {
  make_optimize_config(
    strip_all_custom=config.strip_all_custom,
    strip_name_section=config.strip_name_section,
    strip_producers_section=config.strip_producers_section,
    strip_debug_sections=config.strip_debug_sections,
    strip_dwarf_sections=config.strip_dwarf_sections,
    strip_target_features_section=config.strip_target_features_section,
    keep_custom_sections=config.keep_custom_sections,
    pass_rounds~,
    enable_peephole=config.enable_peephole,
    peephole_remove_nop=config.peephole_remove_nop,
    peephole_remove_const_drop=config.peephole_remove_const_drop,
    enable_vacuum=config.enable_vacuum,
    enable_merge_blocks=config.enable_merge_blocks,
    enable_remove_unused_brs=config.enable_remove_unused_brs,
    enable_dce=config.enable_dce,
    enable_dfe=config.enable_dfe,
    enable_merge_similar_functions=config.enable_merge_similar_functions,
    enable_remove_unused_module_elements=config.enable_remove_unused_module_elements,
    closed_world=config.closed_world,
    closed_world_root_exports~,
    safe_mode=config.safe_mode,
  )
}

///|
pub fn make_component_optimize_config(
  base? : OptimizeConfig = OptimizeConfig::default(),
  root_name_candidates? : Array[String] = [],
  exclude? : Array[String] = [],
) -> OptimizeConfig {
  let merged_roots = merge_root_names(
    merge_root_names(base.closed_world_root_exports, root_name_candidates),
    exclude,
  )
  clone_optimize_config(base, closed_world_root_exports=merged_roots)
}

///|
fn with_additional_closed_world_roots(
  config : OptimizeConfig,
  extra_roots : Array[String],
) -> OptimizeConfig {
  if extra_roots.length() == 0 {
    return config
  }
  make_component_optimize_config(base=config, exclude=extra_roots)
}

///|
fn is_core_module_payload(payload : Bytes) -> Bool {
  payload.length() >= 8 &&
  payload[0] == 0x00U.to_byte() &&
  payload[1] == 0x61U.to_byte() &&
  payload[2] == 0x73U.to_byte() &&
  payload[3] == 0x6dU.to_byte() &&
  payload[4] == 0x01U.to_byte() &&
  payload[5] == 0x00U.to_byte() &&
  payload[6] == 0x00U.to_byte() &&
  payload[7] == 0x00U.to_byte()
}

///|
fn world_keys(xs : Map[String, @wit.RWorldItem]) -> Array[String] {
  let out : Array[String] = []
  xs.each((key, _) => out.push(key))
  out
}

///|
pub fn profile_component(bytes : Bytes) -> Result[ComponentProfile, String] {
  let sections_result = try? parse_component_sections_raise(bytes)
  let sections = match sections_result {
    Ok(v) => v
    Err(e) =>
      return Err("component section parse failed: " + walyze_error_to_string(e))
  }
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let core_modules : Array[ModuleProfile] = []
  for i in 0..<detail.core_modules.length() {
    let core_bytes = detail.core_modules[i]
    match profile_module(core_bytes) {
      Ok(profile) => core_modules.push(profile)
      Err(e) =>
        return Err(
          "core module profile failed at index " +
          i.to_string() +
          ": " +
          walyze_error_to_string(e),
        )
    }
  }
  Ok({
    total_bytes: bytes.length().reinterpret_as_uint(),
    import_count: detail.imports.length().reinterpret_as_uint(),
    export_count: detail.exports.length().reinterpret_as_uint(),
    core_module_count: detail.core_modules.length().reinterpret_as_uint(),
    nested_component_count: detail.components.length().reinterpret_as_uint(),
    sections: summarize_sections(sections, true),
    core_modules,
  })
}

///|
pub fn analyze_component_function_sizes(
  bytes : Bytes,
) -> Result[Array[ComponentFunctionSizeReport], String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let reports : Array[ComponentFunctionSizeReport] = []
  for i in 0..<detail.core_modules.length() {
    let core_bytes = detail.core_modules[i]
    let functions = match analyze_function_sizes(core_bytes) {
      Ok(v) => v
      Err(e) =>
        return Err(
          "core module function-size analysis failed at index " +
          i.to_string() +
          ": " +
          walyze_error_to_string(e),
        )
    }
    let mut total_body_bytes = 0U
    for fn_size in functions {
      total_body_bytes += fn_size.body_bytes
    }
    reports.push({
      module_index: i.reinterpret_as_uint(),
      function_count: functions.length().reinterpret_as_uint(),
      total_body_bytes,
      functions,
    })
  }
  Ok(reports)
}

///|
pub fn analyze_component_call_graphs(
  bytes : Bytes,
) -> Result[Array[ComponentCallGraphReport], String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let reports : Array[ComponentCallGraphReport] = []
  for i in 0..<detail.core_modules.length() {
    let core_bytes = detail.core_modules[i]
    let graph = match analyze_call_graph(core_bytes) {
      Ok(v) => v
      Err(e) =>
        return Err(
          "core module call graph failed at index " +
          i.to_string() +
          ": " +
          walyze_error_to_string(e),
        )
    }
    reports.push({ module_index: i.reinterpret_as_uint(), graph })
  }
  Ok(reports)
}

///|
priv struct ComponentOptimizeRoundResult {
  bytes : Bytes
  core_module_count : UInt
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
fn optimize_component_for_size_round(
  bytes : Bytes,
  config : OptimizeConfig,
) -> Result[ComponentOptimizeRoundResult, String] {
  let sections_result = try? parse_component_sections_raise(bytes)
  let sections = match sections_result {
    Ok(v) => v
    Err(e) =>
      return Err("component section parse failed: " + walyze_error_to_string(e))
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  let removed_sections : Array[String] = []
  let no_change_reasons : Array[String] = []
  let mut core_module_index = 0
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    if section.section_id == 1U && is_core_module_payload(payload) {
      let optimized = match optimize_for_size(payload, config~) {
        Ok(v) => v
        Err(e) =>
          return Err(
            "core module optimize failed at index " +
            core_module_index.to_string() +
            ": " +
            walyze_error_to_string(e),
          )
      }
      append_encoded_section(out, 1U, optimized.bytes)
      for removed in optimized.removed_sections {
        removed_sections.push(
          "core#" + core_module_index.to_string() + ":" + removed,
        )
      }
      for reason in optimized.no_change_reasons {
        no_change_reasons.push(
          "core#" + core_module_index.to_string() + ":" + reason,
        )
      }
      core_module_index += 1
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  if core_module_index == 0 {
    push_reason(
      no_change_reasons, "component has no embedded core module sections",
    )
  }
  Ok({
    bytes: Bytes::from_array(out[:]),
    core_module_count: core_module_index.reinterpret_as_uint(),
    removed_sections,
    no_change_reasons,
  })
}

///|
fn filter_prefixed_items(
  items : Array[String],
  prefix : String,
) -> Array[String] {
  let out : Array[String] = []
  for item in items {
    match item.strip_prefix(prefix) {
      Some(rest) => out.push(rest.to_string())
      None => ()
    }
  }
  out
}

///|
fn sum_core_module_bytes(core_modules : Array[Bytes]) -> UInt {
  let mut total = 0U
  for core_bytes in core_modules {
    total += core_bytes.length().reinterpret_as_uint()
  }
  total
}

///|
pub fn analyze_component_core_optimize(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[ComponentCoreOptimizeReport, String] {
  let before_detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let optimized_component = match
    optimize_component_for_size(bytes, config~, exclude~) {
    Ok(v) => v
    Err(e) => return Err("component optimize failed: " + e)
  }
  let after_detail = match
    @mwac_component.parse_component_detail(optimized_component.bytes) {
    Ok(v) => v
    Err(e) =>
      return Err("optimized component detail parse failed: " + e.to_string())
  }
  if before_detail.core_modules.length() != after_detail.core_modules.length() {
    return Err(
      "core module count mismatch after optimize: before=" +
      before_detail.core_modules.length().to_string() +
      " after=" +
      after_detail.core_modules.length().to_string(),
    )
  }
  let entries : Array[ComponentCoreOptimizeEntry] = []
  for i in 0..<before_detail.core_modules.length() {
    let before_bytes = before_detail.core_modules[i]
      .length()
      .reinterpret_as_uint()
    let after_bytes = after_detail.core_modules[i]
      .length()
      .reinterpret_as_uint()
    let prefix = "core#" + i.to_string() + ":"
    entries.push({
      module_index: i.reinterpret_as_uint(),
      before_bytes,
      after_bytes,
      removed_sections: filter_prefixed_items(
        optimized_component.removed_sections,
        prefix,
      ),
      no_change_reasons: filter_prefixed_items(
        optimized_component.no_change_reasons,
        prefix,
      ),
    })
  }
  Ok({
    total_component_bytes: bytes.length().reinterpret_as_uint(),
    core_module_count: before_detail.core_modules.length().reinterpret_as_uint(),
    total_core_before_bytes: sum_core_module_bytes(before_detail.core_modules),
    total_core_after_bytes: sum_core_module_bytes(after_detail.core_modules),
    entries,
  })
}

///|
pub fn optimize_component_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  let effective_config = with_additional_closed_world_roots(config, exclude)
  let rounds = if effective_config.pass_rounds == 0U {
    1U
  } else {
    effective_config.pass_rounds
  }
  let per_round_config = clone_optimize_config(effective_config, pass_rounds=1U)
  let mut current = bytes
  let removed_sections : Array[String] = []
  let no_change_reasons : Array[String] = []
  let mut converged = false
  for i in 0U..<rounds {
    let round_result = match
      optimize_component_for_size_round(current, per_round_config) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let before_size = current.length().reinterpret_as_uint()
    let after_size = round_result.bytes.length().reinterpret_as_uint()
    let changed = not(bytes_equal(round_result.bytes, current))
    if after_size < before_size || (after_size == before_size && changed) {
      current = round_result.bytes
      removed_sections.append(round_result.removed_sections[:])
      continue
    }
    converged = true
    removed_sections.push(
      "component-converge:no-improve:" + (i + 1U).to_string(),
    )
    for reason in round_result.no_change_reasons {
      push_reason(no_change_reasons, reason)
    }
    if round_result.core_module_count == 0U {
      push_reason(
        no_change_reasons, "component has no embedded core module sections",
      )
    }
    break
  }
  if not(converged) {
    removed_sections.push("component-converge:round-cap:" + rounds.to_string())
  }
  if current.length() == bytes.length() && no_change_reasons.length() == 0 {
    no_change_reasons.push("component optimization produced no size change")
  }
  Ok({
    bytes: current,
    before_size: bytes.length().reinterpret_as_uint(),
    after_size: current.length().reinterpret_as_uint(),
    removed_sections,
    no_change_reasons,
  })
}

///|
pub fn optimize_binary_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  if bytes.length() >= 8 &&
    bytes[0] == 0x00U.to_byte() &&
    bytes[1] == 0x61U.to_byte() &&
    bytes[2] == 0x73U.to_byte() &&
    bytes[3] == 0x6dU.to_byte() &&
    bytes[4] == 0x0dU.to_byte() &&
    bytes[5] == 0x00U.to_byte() &&
    bytes[6] == 0x01U.to_byte() &&
    bytes[7] == 0x00U.to_byte() {
    optimize_component_for_size(bytes, config~, exclude~)
  } else {
    match optimize_for_size(bytes, config~) {
      Ok(v) => Ok(v)
      Err(e) => Err(walyze_error_to_string(e))
    }
  }
}

///|
pub fn analyze_component_contract(
  bytes : Bytes,
  resolved : @wit.ResolveInput,
) -> Result[ContractReport, String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  if resolved.world_id < 0 ||
    resolved.world_id >= resolved.resolve.worlds.length() {
    return Err("invalid world id: " + resolved.world_id.to_string())
  }
  let world = resolved.resolve.worlds[resolved.world_id]
  let component_imports = unique_sorted(
    detail.imports.map(item => item.name.to_string()),
  )
  let component_exports = unique_sorted(
    detail.exports.map(item => item.name.to_string()),
  )
  let wit_imports = unique_sorted(world_keys(world.imports))
  let wit_exports = unique_sorted(world_keys(world.exports))
  let missing_component_imports : Array[String] = []
  for name in wit_imports {
    if not(component_imports.contains(name)) {
      missing_component_imports.push(name)
    }
  }
  let missing_component_exports : Array[String] = []
  for name in wit_exports {
    if not(component_exports.contains(name)) {
      missing_component_exports.push(name)
    }
  }
  Ok({
    component_imports,
    component_exports,
    wit_imports,
    wit_exports,
    missing_component_imports,
    missing_component_exports,
  })
}

///|
fn collect_canonical_abi_root_names(
  component_exports : Array[String],
  wit_exports : Array[String],
) -> Array[String] {
  let roots : Array[String] = ["cabi_realloc"]
  for name in component_exports {
    match name.strip_prefix("cabi_") {
      Some(_) => roots.push(name)
      None => ()
    }
  }
  for name in wit_exports {
    roots.push("cabi_post_" + name)
  }
  unique_sorted(roots)
}

///|
pub fn analyze_component_root_policy(
  bytes : Bytes,
  resolved_wit? : @wit.ResolveInput? = None,
  exclude? : Array[String] = [],
) -> Result[ComponentRootPolicyReport, String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let component_imports = unique_sorted(
    detail.imports.map(item => item.name.to_string()),
  )
  let component_exports = unique_sorted(
    detail.exports.map(item => item.name.to_string()),
  )
  let mut wit_imports : Array[String] = []
  let mut wit_exports : Array[String] = []
  match resolved_wit {
    Some(resolved) => {
      if resolved.world_id < 0 ||
        resolved.world_id >= resolved.resolve.worlds.length() {
        return Err("invalid world id: " + resolved.world_id.to_string())
      }
      let world = resolved.resolve.worlds[resolved.world_id]
      wit_imports = unique_sorted(world_keys(world.imports))
      wit_exports = unique_sorted(world_keys(world.exports))
    }
    None => ()
  }
  let canonical_abi_roots = collect_canonical_abi_root_names(
    component_exports, wit_exports,
  )
  let root_name_candidates = component_exports.copy()
  root_name_candidates.append(wit_exports[:])
  root_name_candidates.append(canonical_abi_roots[:])
  root_name_candidates.append(exclude[:])
  Ok({
    component_imports,
    component_exports,
    wit_imports,
    wit_exports,
    canonical_abi_roots,
    root_name_candidates: unique_sorted(root_name_candidates),
  })
}

///|
fn split_string(s : String, delim : String) -> Array[String] {
  let out : Array[String] = []
  for part in s.split(delim) {
    out.push(part.to_string())
  }
  out
}

///|
fn split_non_empty(s : String, delim : String) -> Array[String] {
  if s.is_empty() {
    return []
  }
  let out : Array[String] = []
  for part in s.split(delim) {
    let item = part.to_string()
    if not(item.is_empty()) {
      out.push(item)
    }
  }
  out
}

///|
fn parse_uint_decimal(text : String) -> UInt? {
  if text.is_empty() {
    return None
  }
  let mut value = 0U
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10U + (code - 48).reinterpret_as_uint()
  }
  Some(value)
}

///|
fn parse_u64_decimal(text : String) -> UInt64? {
  if text.is_empty() {
    return None
  }
  let mut value = 0UL
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10UL + (code - 48).to_uint64()
  }
  Some(value)
}

///|
extern "js" fn js_profile_zero_arg_exports(
  bytes : Bytes,
  iterations : Int,
) -> String =
  #| (bytes, iterations) => {
  #|   try {
  #|     const raw = bytes instanceof Uint8Array
  #|       ? bytes
  #|       : (Array.isArray(bytes) ? Uint8Array.from(bytes) : new Uint8Array(bytes));
  #|     const rounds = Math.max(1, iterations | 0);
  #|     const t0 = process.hrtime.bigint();
  #|     const module = new WebAssembly.Module(raw);
  #|     const instance = new WebAssembly.Instance(module, {});
  #|     const t1 = process.hrtime.bigint();
  #|     const instantiateNs = (t1 - t0).toString();
  #|     const profiled = [];
  #|     const skipped = [];
  #|     for (const [name, value] of Object.entries(instance.exports)) {
  #|       if (typeof value !== 'function') continue;
  #|       if (value.length !== 0) {
  #|         skipped.push(name);
  #|         continue;
  #|       }
  #|       let total = 0n;
  #|       for (let i = 0; i < rounds; i++) {
  #|         const s = process.hrtime.bigint();
  #|         value();
  #|         total += (process.hrtime.bigint() - s);
  #|       }
  #|       profiled.push(name + ',' + rounds + ',' + total.toString());
  #|     }
  #|     return 'ok|' + instantiateNs + '|' + profiled.join(';') + '|' + skipped.join(',');
  #|   } catch (e) {
  #|     const msg = e && e.message ? e.message : String(e);
  #|     return 'err|' + msg;
  #|   }
  #| }

///|
pub fn profile_runtime_zero_arg_exports(
  bytes : Bytes,
  iterations? : UInt = 50U,
) -> Result[RuntimeProfile, String] {
  let raw = js_profile_zero_arg_exports(
    bytes,
    UInt::reinterpret_as_int(iterations),
  )
  let parts = split_string(raw, "|")
  if parts.length() < 2 {
    return Err("invalid runtime profile response")
  }
  if parts[0] == "err" {
    return Err("runtime profile failed: " + parts[1])
  }
  if parts[0] != "ok" {
    return Err("unknown runtime profile status: " + parts[0])
  }
  if parts.length() < 3 {
    return Err("runtime profile response is missing fields")
  }
  let instantiate_ns = match parse_u64_decimal(parts[1]) {
    Some(v) => v
    None => return Err("failed to parse instantiate time: " + parts[1])
  }
  let functions : Array[RuntimeFunctionProfile] = []
  let profile_entries = if parts.length() >= 3 { parts[2] } else { "" }
  for entry in split_non_empty(profile_entries, ";") {
    let fields = split_string(entry, ",")
    if fields.length() != 3 {
      return Err("invalid function profile entry: " + entry)
    }
    let calls = match parse_uint_decimal(fields[1]) {
      Some(v) => v
      None => return Err("invalid call count in profile entry: " + entry)
    }
    let total_ns = match parse_u64_decimal(fields[2]) {
      Some(v) => v
      None => return Err("invalid total ns in profile entry: " + entry)
    }
    let average_ns = if calls == 0U {
      0UL
    } else {
      total_ns / calls.to_uint64()
    }
    functions.push({ name: fields[0], calls, total_ns, average_ns })
  }
  let skipped_exports = if parts.length() >= 4 {
    split_non_empty(parts[3], ",")
  } else {
    []
  }
  Ok({ instantiate_ns, iterations, functions, skipped_exports })
}

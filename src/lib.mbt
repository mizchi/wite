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
}

///|
pub fn OptimizeConfig::default() -> Self {
  {
    strip_all_custom: false,
    strip_name_section: true,
    strip_producers_section: true,
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
  }
}

///|
pub fn OptimizeConfig::aggressive() -> Self {
  {
    strip_all_custom: true,
    strip_name_section: true,
    strip_producers_section: true,
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
  }
}

///|
pub fn make_optimize_config(
  strip_all_custom? : Bool = false,
  strip_name_section? : Bool = true,
  strip_producers_section? : Bool = true,
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
) -> OptimizeConfig {
  {
    strip_all_custom,
    strip_name_section,
    strip_producers_section,
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
  }
}

///|
pub struct OptimizeResult {
  bytes : Bytes
  before_size : UInt
  after_size : UInt
  removed_sections : Array[String]
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
pub struct ContractReport {
  component_imports : Array[String]
  component_exports : Array[String]
  wit_imports : Array[String]
  wit_exports : Array[String]
  missing_component_imports : Array[String]
  missing_component_exports : Array[String]
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
priv struct InstrSpan {
  start : Int
  end_ : Int
  opcode : UInt
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
      _ => raise WalyzeError::InvalidFormat("unsupported opcode in peephole")
    }
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
  let mut has_indirect = false
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ > span.start + 1 {
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        match decode_u32_leb128_bytes(imm) {
          Some(index) => if not(callees.contains(index)) { callees.push(index) }
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
fn rewrite_export_section_payload_for_dce_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WalyzeError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(export_count)[:])
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    append_name_bytes(out, name)
    out.push(kind.to_byte())
    let remapped = if kind == 0U {
      remap_function_index_raise(index, index_map)
    } else {
      index
    }
    out.append(encode_u32_leb128(remapped)[:])
  }
  Bytes::from_array(out[:])
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
fn is_const_opcode(opcode : UInt) -> Bool {
  opcode == 0x41U || opcode == 0x42U || opcode == 0x43U || opcode == 0x44U
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
fn instr_spans_to_bytes(instr_bytes : Bytes, spans : Array[InstrSpan]) -> Bytes {
  let out : Array[Byte] = []
  for span in spans {
    out.append(instr_bytes[span.start:span.end_].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn apply_basic_peephole_to_spans(
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
      is_const_opcode(span.opcode) &&
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
  spans : Array[InstrSpan],
  config : OptimizeConfig,
) -> Bytes {
  let mut current = spans.copy()
  if config.enable_vacuum {
    current = apply_vacuum_to_spans(current)
  }
  if config.peephole_remove_nop || config.peephole_remove_const_drop {
    current = apply_basic_peephole_to_spans(current, config)
  }
  if config.enable_remove_unused_brs {
    current = apply_remove_unused_brs_to_spans(instr_bytes, current)
  }
  if config.enable_merge_blocks {
    current = apply_merge_blocks_to_spans(current)
  }
  if config.enable_vacuum {
    current = apply_vacuum_to_spans(current)
  }
  instr_spans_to_bytes(instr_bytes, current)
}

///|
fn parse_local_decl_prefix_end(body_bytes : Bytes) -> Int raise WalyzeError {
  let parser = Cursor::new(body_bytes)
  let local_group_count = parser.read_u32_leb128()
  for _ in 0U..<local_group_count {
    ignore(parser.read_u32_leb128())
    ignore(parser.read_byte())
  }
  parser.get_pos()
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
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return body_bytes
  }
  let optimized_instr = optimize_instruction_bytes(instr_bytes, spans, config)
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
  if config.enable_dce {
    let dce = apply_dce_raise(optimized_bytes)
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
    {
      bytes: current,
      before_size: bytes.length().reinterpret_as_uint(),
      after_size: current.length().reinterpret_as_uint(),
      removed_sections,
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
pub fn analyze_call_graph(
  bytes : Bytes,
) -> Result[CallGraphReport, WalyzeError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_bodies : Array[Bytes] = []
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    let roots : Array[UInt] = []
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count += parse_vec_count(payload)
        7U => {
          let parsed = parse_export_function_names(payload)
          merge_export_function_names(export_names, parsed)
          parsed.each((index, _) => if not(roots.contains(index)) {
            roots.push(index)
          })
        }
        8U => {
          let start_index = parse_start_function_index(payload)
          if not(roots.contains(start_index)) {
            roots.push(start_index)
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
    let mut partial = false
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
priv struct MsfApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
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

///|
fn parse_forward_call_target(body_bytes : Bytes) -> UInt? {
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  let prefix_end = match prefix_end_result {
    Ok(v) => v
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  if spans.length() != 2 {
    return None
  }
  if spans[0].opcode != 0x10U || spans[1].opcode != 0x0bU {
    return None
  }
  decode_span_u32_immediate(instr_bytes, spans[0])
}

///|
fn apply_dce_raise(bytes : Bytes) -> DceApplyResult raise WalyzeError {
  let call_graph = match analyze_call_graph(bytes) {
    Ok(v) => v
    Err(e) => raise e
  }
  if call_graph.partial {
    raise WalyzeError::InvalidFormat(
      "dce apply requires complete call graph (partial=false)",
    )
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
      // Global/Element may contain ref.func references and need extra remap handling.
      6U | 9U =>
        raise WalyzeError::InvalidFormat(
          "dce apply does not yet support global/element sections",
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
      // Global/Element may contain ref.func references and need extra remap handling.
      6U | 9U =>
        raise WalyzeError::InvalidFormat(
          "dfe apply does not yet support global/element sections",
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
  let mut imported_function_type_indices : Array[UInt] = []
  let mut local_function_type_indices : Array[UInt] = []
  let mut code_bodies : Array[Bytes] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
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
  let function_type_index_map : Map[UInt, UInt] = {}
  for i in 0..<imported_function_type_indices.length() {
    function_type_index_map.set(
      i.reinterpret_as_uint(),
      imported_function_type_indices[i],
    )
  }
  for i in 0..<local_function_type_indices.length() {
    function_type_index_map.set(
      imported_function_count + i.reinterpret_as_uint(),
      local_function_type_indices[i],
    )
  }
  let alias_candidate : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match parse_forward_call_target(code_bodies[i]) {
      Some(target) =>
        if target != old_index {
          match
            (
              function_type_index_map.get(old_index),
              function_type_index_map.get(target),
            ) {
            (Some(lhs), Some(rhs)) =>
              if lhs == rhs {
                alias_candidate.set(old_index, target)
              }
            _ => ()
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
      // Global/Element may contain ref.func references and need extra remap handling.
      6U | 9U =>
        raise WalyzeError::InvalidFormat(
          "merge-similar-functions does not yet support global/element sections",
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

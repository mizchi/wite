///|
pub fn Cursor::new(bytes : Bytes) -> Self {
  { bytes, pos: 0 }
}

///|
pub fn Cursor::eof(self : Cursor) -> Bool {
  self.pos >= self.bytes.length()
}

///|
pub fn Cursor::get_pos(self : Cursor) -> Int {
  self.pos
}

///|
pub fn Cursor::set_pos(self : Cursor, pos : Int) -> Unit {
  self.pos = pos
}

///|
pub fn Cursor::read_byte(self : Cursor) -> Byte raise WiteError {
  if self.pos < self.bytes.length() {
    let b = self.bytes.unsafe_get(self.pos)
    self.pos = self.pos + 1
    b
  } else {
    raise WiteError::UnexpectedEof
  }
}

///|
pub fn Cursor::read_u32_leb128(self : Cursor) -> UInt raise WiteError {
  fn read_loop(shift : Int, result : UInt) -> UInt raise WiteError {
    let byte = self.read_byte()
    if shift >= 28 && (byte & 0x80) != 0 {
      raise WiteError::InvalidFormat("LEB128 u32 overflow")
    }
    if shift >= 28 && byte > 0x0F {
      raise WiteError::InvalidFormat("LEB128 u32 value overflow")
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
pub fn Cursor::skip(self : Cursor, n : Int) -> Unit raise WiteError {
  if n < 0 {
    raise WiteError::InvalidFormat("negative skip")
  }
  if self.pos + n <= self.bytes.length() {
    self.pos = self.pos + n
  } else {
    raise WiteError::UnexpectedEof
  }
}

///|
pub(all) struct RawSection {
  section_id : UInt
  section_start : Int
  payload_start : Int
  section_end : Int
  custom_name : String?
}

///|
fn ensure_core_header(bytes : Bytes) -> Unit raise WiteError {
  if bytes.length() < 8 {
    raise WiteError::UnexpectedEof
  }
  if bytes[0] != 0x00U.to_byte() ||
    bytes[1] != 0x61U.to_byte() ||
    bytes[2] != 0x73U.to_byte() ||
    bytes[3] != 0x6dU.to_byte() {
    raise WiteError::InvalidMagic
  }
  if bytes[4] != 0x01U.to_byte() ||
    bytes[5] != 0x00U.to_byte() ||
    bytes[6] != 0x00U.to_byte() ||
    bytes[7] != 0x00U.to_byte() {
    raise WiteError::UnsupportedVersion("expected core wasm version 1")
  }
}

///|
fn ensure_component_header(bytes : Bytes) -> Unit raise WiteError {
  if bytes.length() < 8 {
    raise WiteError::UnexpectedEof
  }
  if bytes[0] != 0x00U.to_byte() ||
    bytes[1] != 0x61U.to_byte() ||
    bytes[2] != 0x73U.to_byte() ||
    bytes[3] != 0x6dU.to_byte() {
    raise WiteError::InvalidMagic
  }
  if bytes[4] != 0x0dU.to_byte() ||
    bytes[5] != 0x00U.to_byte() ||
    bytes[6] != 0x01U.to_byte() ||
    bytes[7] != 0x00U.to_byte() {
    raise WiteError::UnsupportedVersion(
      "expected component wasm header 0d 00 01 00",
    )
  }
}

///|
fn parse_custom_section_name(payload : Bytes) -> String raise WiteError {
  let parser = Cursor::new(payload)
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WiteError::InvalidFormat("custom section name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len
  if end_ > payload.length() {
    raise WiteError::UnexpectedEof
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
) -> Array[RawSection] raise WiteError {
  let parser = Cursor::new(bytes)
  parser.set_pos(start)
  let sections : Array[RawSection] = []
  while !parser.eof() {
    let section_start = parser.get_pos()
    let section_id = parser.read_byte().to_uint()
    let payload_size_u = parser.read_u32_leb128()
    let payload_size = UInt::reinterpret_as_int(payload_size_u)
    if payload_size < 0 {
      raise WiteError::InvalidFormat("section size overflow")
    }
    let payload_start = parser.get_pos()
    let section_end = payload_start + payload_size
    if section_end > bytes.length() {
      raise WiteError::UnexpectedEof
    }
    let custom_name = if section_id == 0U {
      let payload = bytes[payload_start:section_end].to_bytes()
      payload |> parse_custom_section_name |> Some
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
pub fn parse_core_sections_raise(
  bytes : Bytes,
) -> Array[RawSection] raise WiteError {
  ensure_core_header(bytes)
  parse_sections_from(bytes, 8)
}

///|
pub fn parse_component_sections_raise(
  bytes : Bytes,
) -> Array[RawSection] raise WiteError {
  ensure_component_header(bytes)
  parse_sections_from(bytes, 8)
}

///|
pub fn section_total_bytes(section : RawSection) -> UInt {
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
pub fn summarize_sections(
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
  out.sort_by((a, b) => {
    if a.total_bytes > b.total_bytes {
      -1
    } else if a.total_bytes < b.total_bytes {
      1
    } else {
      a.key.compare(b.key)
    }
  })
  out
}

///|
pub fn parse_vec_count(payload : Bytes) -> UInt raise WiteError {
  let parser = Cursor::new(payload)
  parser.read_u32_leb128()
}

///|
pub fn parse_code_section_metrics(
  payload : Bytes,
) -> (UInt, UInt) raise WiteError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let mut total_body_bytes = 0U
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WiteError::InvalidFormat("code body size overflow")
    }
    total_body_bytes += body_size_u
    parser.skip(body_size)
  }
  (body_count, total_body_bytes)
}

///|
fn read_name_string(parser : Cursor) -> String raise WiteError {
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WiteError::InvalidFormat("name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len
  if end_ > parser.bytes.length() {
    raise WiteError::UnexpectedEof
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
fn skip_name_string(parser : Cursor) -> Unit raise WiteError {
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WiteError::InvalidFormat("name length overflow")
  }
  parser.skip(name_len)
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
pub fn parse_code_body_sizes(payload : Bytes) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let body_sizes : Array[UInt] = []
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WiteError::InvalidFormat("code body size overflow")
    }
    body_sizes.push(body_size_u)
    parser.skip(body_size)
  }
  body_sizes
}

///|
pub fn parse_code_bodies(payload : Bytes) -> Array[Bytes] raise WiteError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let out : Array[Bytes] = []
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WiteError::InvalidFormat("code body size overflow")
    }
    let start = parser.get_pos()
    let end_ = start + body_size
    if end_ > payload.length() {
      raise WiteError::UnexpectedEof
    }
    out.push(payload[start:end_].to_bytes())
    parser.set_pos(end_)
  }
  out
}

///|
pub fn parse_start_function_index(payload : Bytes) -> UInt raise WiteError {
  let parser = Cursor::new(payload)
  parser.read_u32_leb128()
}

///|
fn parse_limits(parser : Cursor) -> Unit raise WiteError {
  let flags = parser.read_u32_leb128()
  ignore(parser.read_u32_leb128())
  if (flags & 0x01U) != 0U {
    ignore(parser.read_u32_leb128())
  }
}

///|
pub fn parse_import_function_count(payload : Bytes) -> UInt raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let mut function_import_count = 0U
  for _ in 0U..<count {
    parser |> read_name_string |> ignore
    parser |> read_name_string |> ignore
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
        raise WiteError::InvalidFormat(
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
) -> Array[ImportSectionEntry] raise WiteError {
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
    parser |> read_name_string |> ignore
    parser |> read_name_string |> ignore
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
        raise WiteError::InvalidFormat(
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
) -> (Bytes, UInt) raise WiteError {
  let entries = parse_import_section_entries_raise(payload)
  let kept_entries : Array[Bytes] = []
  let mut removed_count = 0U
  for entry in entries {
    let mut keep = true
    if entry.kind == 1U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_table_imports.length() {
        raise WiteError::InvalidFormat("table import keep index out of range")
      }
      keep = keep_table_imports[index]
    } else if entry.kind == 2U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_memory_imports.length() {
        raise WiteError::InvalidFormat("memory import keep index out of range")
      }
      keep = keep_memory_imports[index]
    } else if entry.kind == 3U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_global_imports.length() {
        raise WiteError::InvalidFormat("global import keep index out of range")
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
) -> (Bytes, UInt) raise WiteError {
  let entries = parse_import_section_entries_raise(payload)
  let kept_entries : Array[Bytes] = []
  let mut removed_count = 0U
  for entry in entries {
    let mut keep = true
    if entry.kind == 0U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_function_imports.length() {
        raise WiteError::InvalidFormat(
          "function import keep index out of range",
        )
      }
      keep = keep_function_imports[index]
    } else if entry.kind == 1U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_table_imports.length() {
        raise WiteError::InvalidFormat("table import keep index out of range")
      }
      keep = keep_table_imports[index]
    } else if entry.kind == 2U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_memory_imports.length() {
        raise WiteError::InvalidFormat("memory import keep index out of range")
      }
      keep = keep_memory_imports[index]
    } else if entry.kind == 3U {
      let index = UInt::reinterpret_as_int(entry.kind_index)
      if index < 0 || index >= keep_global_imports.length() {
        raise WiteError::InvalidFormat("global import keep index out of range")
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
pub fn parse_import_function_type_indices(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    parser |> read_name_string |> ignore
    parser |> read_name_string |> ignore
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
        raise WiteError::InvalidFormat(
          "unsupported import descriptor kind: " + kind.to_string(),
        )
    }
  }
  out
}

///|
pub fn map_push_string_array(
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
pub fn parse_export_function_names(
  payload : Bytes,
) -> Map[UInt, Array[String]] raise WiteError {
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
fn parse_export_table_indices(payload : Bytes) -> Array[UInt] raise WiteError {
  parse_export_indices_by_kind(payload, 1U)
}

///|
fn parse_export_memory_indices(payload : Bytes) -> Array[UInt] raise WiteError {
  parse_export_indices_by_kind(payload, 2U)
}

///|
fn parse_export_global_indices(payload : Bytes) -> Array[UInt] raise WiteError {
  parse_export_indices_by_kind(payload, 3U)
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
pub fn parse_export_indices_by_kind(
  payload : Bytes,
  kind_filter : UInt,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  let seen : Map[UInt, Bool] = {}
  for _ in 0U..<count {
    skip_name_string(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    if kind == kind_filter {
      push_unique_u32_with_seen(out, seen, index)
    }
  }
  out
}

///|
pub fn merge_export_function_names(
  target : Map[UInt, Array[String]],
  source : Map[UInt, Array[String]],
) -> Unit {
  source.each((index, names) => {
    for name in names {
      map_push_string_array(target, index, name)
    }
  })
}

///|
pub fn parse_custom_section_name_prefix_end(
  payload : Bytes,
) -> Int raise WiteError {
  let parser = Cursor::new(payload)
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WiteError::InvalidFormat("custom section name length overflow")
  }
  parser.skip(name_len)
  parser.get_pos()
}

///|
pub fn parse_name_section_function_names(
  payload : Bytes,
) -> Map[UInt, String] raise WiteError {
  let parser = Cursor::new(payload)
  parser.set_pos(parse_custom_section_name_prefix_end(payload))
  let out : Map[UInt, String] = {}
  while !parser.eof() {
    let subsection_id = parser.read_byte().to_uint()
    let subsection_size_u = parser.read_u32_leb128()
    let subsection_size = UInt::reinterpret_as_int(subsection_size_u)
    if subsection_size < 0 {
      raise WiteError::InvalidFormat("name subsection size overflow")
    }
    let subsection_start = parser.get_pos()
    let subsection_end = subsection_start + subsection_size
    if subsection_end > payload.length() {
      raise WiteError::UnexpectedEof
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
    if current == 0U && !sign_set {
      out.push(low.to_byte())
      break
    }
    out.push((low | 0x80U).to_byte())
  }
  out
}

///|
pub fn append_encoded_section(
  out : Array[Byte],
  section_id : UInt,
  payload : Bytes,
) -> Unit {
  out
  ..push(section_id.to_byte())
  ..append(encode_u32_leb128(payload.length().reinterpret_as_uint())[:])
  .append(payload[:].to_array())
}

///|
fn skip_sleb_immediate(
  parser : Cursor,
  max_bytes : Int,
) -> Unit raise WiteError {
  let mut consumed = 0
  while true {
    let b = parser.read_byte()
    consumed += 1
    if consumed > max_bytes {
      raise WiteError::InvalidFormat("sleb immediate overflow")
    }
    if (b & 0x80) == 0 {
      break
    }
  }
}

///|
fn skip_block_type(parser : Cursor) -> Unit raise WiteError {
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
            raise WiteError::InvalidFormat("block type s33 overflow")
          }
          if (b & 0x80) == 0 {
            break
          }
        }
      }
  }
}

///|
fn skip_heap_type(parser : Cursor) -> Unit raise WiteError {
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
            raise WiteError::InvalidFormat("heap type s33 overflow")
          }
          if (b & 0x80) == 0 {
            break
          }
        }
      }
  }
}

///|
fn skip_memarg(parser : Cursor) -> Unit raise WiteError {
  ignore(parser.read_u32_leb128())
  ignore(parser.read_u32_leb128())
}

///|
fn skip_memarg_lane(parser : Cursor) -> Unit raise WiteError {
  skip_memarg(parser)
  ignore(parser.read_byte())
}

///|
fn skip_fc_prefixed_immediate(parser : Cursor) -> Unit raise WiteError {
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
      raise WiteError::InvalidFormat(
        "unsupported 0xfc subopcode in parser: " + subopcode.to_string(),
      )
  }
}

///|
fn skip_fd_prefixed_immediate(parser : Cursor) -> Unit raise WiteError {
  let subopcode = parser.read_u32_leb128()
  match subopcode {
    0x00U..=0x0bU | 0x5cU | 0x5dU => skip_memarg(parser)
    0x0cU | 0x0dU => parser.skip(16)
    0x15U..=0x22U => ignore(parser.read_byte())
    0x54U..=0x5bU => skip_memarg_lane(parser)
    0x0eU..=0x14U | 0x23U..=0x53U | 0x5eU..=0xffU => ()
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported 0xfd subopcode in parser: " + subopcode.to_string(),
      )
  }
}

///|
fn skip_instruction_immediate_raise(
  parser : Cursor,
  opcode : UInt,
) -> Unit raise WiteError {
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
    _ => raise WiteError::InvalidFormat("unsupported opcode in parser")
  }
}

///|
pub(all) struct InstrSpan {
  start : Int
  end_ : Int
  opcode : UInt
}

///|
pub(all) struct OpenCodeBlock {
  entry_index : Int
  start_span_index : Int
  start_offset : Int
}

///|
fn parse_instruction_spans_raise(
  instr_bytes : Bytes,
) -> Array[InstrSpan] raise WiteError {
  let parser = Cursor::new(instr_bytes)
  let spans : Array[InstrSpan] = []
  while !parser.eof() {
    let start = parser.get_pos()
    let opcode = parser.read_byte().to_uint()
    skip_instruction_immediate_raise(parser, opcode)
    let end_ = parser.get_pos()
    spans.push({ start, end_, opcode })
  }
  spans
}

///|
fn val_type_name(b : Byte) -> String {
  match b.to_uint() {
    0x7fU => "i32"
    0x7eU => "i64"
    0x7dU => "f32"
    0x7cU => "f64"
    0x7bU => "v128"
    0x70U => "funcref"
    0x6fU => "externref"
    _ => "unknown"
  }
}

///|
fn export_kind_name(kind : UInt) -> String {
  match kind {
    0U => "function"
    1U => "table"
    2U => "memory"
    3U => "global"
    _ => "unknown"
  }
}

///|
fn import_kind_name(kind : UInt) -> String {
  match kind {
    0U => "function"
    1U => "table"
    2U => "memory"
    3U => "global"
    4U => "tag"
    _ => "unknown"
  }
}

///|
fn escape_json_string(s : String) -> String {
  let out : Array[Char] = []
  for ch in s {
    match ch {
      '"' => {
        out.push('\\')
        out.push('"')
      }
      '\\' => {
        out.push('\\')
        out.push('\\')
      }
      '\n' => {
        out.push('\\')
        out.push('n')
      }
      '\r' => {
        out.push('\\')
        out.push('r')
      }
      '\t' => {
        out.push('\\')
        out.push('t')
      }
      _ => out.push(ch)
    }
  }
  String::from_array(out[:])
}

///|
fn is_component_header(bytes : Bytes) -> Bool {
  bytes.length() >= 8 &&
  bytes[0] == b'\x00' &&
  bytes[1] == b'\x61' &&
  bytes[2] == b'\x73' &&
  bytes[3] == b'\x6d' &&
  bytes[4] == b'\x0d' &&
  bytes[5] == b'\x00' &&
  bytes[6] == b'\x01' &&
  bytes[7] == b'\x00'
}

///|
struct ExportEntry {
  name : String
  kind : UInt
  index : UInt
}

///|
struct ImportEntry {
  mod_name : String
  name : String
  kind : UInt
  type_index : UInt?
}

///|
fn parse_exports_full(
  payload : Bytes,
) -> Array[ExportEntry] raise @wite.WiteError {
  let parser = @wite_optimize.Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[ExportEntry] = []
  for _ in 0U..<count {
    let name = read_name(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    out.push({ name, kind, index })
  }
  out
}

///|
fn read_name(parser : @wite_optimize.Cursor) -> String raise @wite.WiteError {
  let name_len = parser.read_u32_leb128()
  let name_len_int = UInt::reinterpret_as_int(name_len)
  if name_len_int < 0 {
    raise @wite.WiteError::InvalidFormat("name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len_int
  parser.skip(name_len_int)
  let out : Array[Char] = []
  for i in start..<end_ {
    match parser.bytes.unsafe_get(i).to_int().to_char() {
      Some(ch) => out.push(ch)
      None => out.push('?')
    }
  }
  String::from_array(out[:])
}

///|
fn skip_limits(parser : @wite_optimize.Cursor) -> Unit raise @wite.WiteError {
  let flags = parser.read_u32_leb128()
  ignore(parser.read_u32_leb128())
  if (flags & 0x01U) != 0U {
    ignore(parser.read_u32_leb128())
  }
}

///|
fn skip_heap_type(parser : @wite_optimize.Cursor) -> Unit raise @wite.WiteError {
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
            raise @wite.WiteError::InvalidFormat("heap type overflow")
          }
          if (b & 0x80) == 0 {
            break
          }
        }
      }
  }
}

///|
fn parse_imports_full(
  payload : Bytes,
) -> Array[ImportEntry] raise @wite.WiteError {
  let parser = @wite_optimize.Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[ImportEntry] = []
  for _ in 0U..<count {
    let mod_name = read_name(parser)
    let name = read_name(parser)
    let kind = parser.read_byte().to_uint()
    let type_index : UInt? = match kind {
      0x00U => {
        let idx = parser.read_u32_leb128()
        Some(idx)
      }
      0x01U => {
        skip_heap_type(parser)
        skip_limits(parser)
        None
      }
      0x02U => {
        skip_limits(parser)
        None
      }
      0x03U => {
        ignore(parser.read_byte())
        ignore(parser.read_byte())
        None
      }
      0x04U => {
        ignore(parser.read_byte())
        ignore(parser.read_u32_leb128())
        None
      }
      _ =>
        raise @wite.WiteError::InvalidFormat(
          "unsupported import kind: " + kind.to_string(),
        )
    }
    out.push({ mod_name, name, kind, type_index })
  }
  out
}

///|
struct FuncSig {
  params : Array[String]
  results : Array[String]
}

///|
fn parse_func_types(payload : Bytes) -> Array[FuncSig] raise @wite.WiteError {
  let parser = @wite_optimize.Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[FuncSig] = []
  for _ in 0U..<count {
    let form = parser.read_byte().to_uint()
    if form != 0x60U {
      // Skip non-function types (struct 0x5f, array 0x5e)
      // by using the raw entry parser fallback
      out.push({ params: [], results: [] })
      // skip remaining bytes for this entry
      match form {
        0x5fU => {
          let field_count = parser.read_u32_leb128()
          for _ in 0U..<field_count {
            ignore(parser.read_byte()) // field type
            ignore(parser.read_byte()) // mutability
          }
        }
        0x5eU => {
          ignore(parser.read_byte()) // element type
          ignore(parser.read_byte()) // mutability
        }
        _ =>
          raise @wite.WiteError::InvalidFormat(
            "unsupported type form: " + form.to_string(),
          )
      }
      continue
    }
    let param_count = parser.read_u32_leb128()
    let params : Array[String] = []
    for _ in 0U..<param_count {
      params.push(val_type_name(parser.read_byte()))
    }
    let result_count = parser.read_u32_leb128()
    let results : Array[String] = []
    for _ in 0U..<result_count {
      results.push(val_type_name(parser.read_byte()))
    }
    out.push({ params, results })
  }
  out
}

///|
fn parse_function_type_indices(
  payload : Bytes,
) -> Array[UInt] raise @wite.WiteError {
  let parser = @wite_optimize.Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    out.push(parser.read_u32_leb128())
  }
  out
}

///|
fn json_string_array(arr : Array[String]) -> String {
  let parts : Array[String] = []
  for item in arr {
    parts.push("\"" + escape_json_string(item) + "\"")
  }
  "[" + parts.join(",") + "]"
}

///|
pub fn parse_wasm_metadata(bytes : Bytes) -> String {
  if is_component_header(bytes) {
    return "{\"isComponent\":true,\"types\":[],\"imports\":[],\"exports\":[],\"functions\":[]}"
  }
  // Parse core module
  let sections = @wite_optimize.parse_core_sections_raise(bytes) catch {
    err =>
      return "{\"error\":\"" +
        escape_json_string(@wite.error_to_string(err)) +
        "\"}"
  }
  let mut types : Array[FuncSig] = []
  let mut imports : Array[ImportEntry] = []
  let mut exports : Array[ExportEntry] = []
  let mut functions : Array[UInt] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U =>
        try {
          types = parse_func_types(payload)
        } catch {
          _ => ()
        }
      2U =>
        try {
          imports = parse_imports_full(payload)
        } catch {
          _ => ()
        }
      3U =>
        try {
          functions = parse_function_type_indices(payload)
        } catch {
          _ => ()
        }
      7U =>
        try {
          exports = parse_exports_full(payload)
        } catch {
          _ => ()
        }
      _ => ()
    }
  }
  // Build JSON manually
  let out : Array[String] = []
  out.push("{\"isComponent\":false")
  // Types
  let type_parts : Array[String] = []
  for t in types {
    type_parts.push(
      "{\"params\":" +
      json_string_array(t.params) +
      ",\"results\":" +
      json_string_array(t.results) +
      "}",
    )
  }
  out.push(",\"types\":[" + type_parts.join(",") + "]")
  // Imports
  let import_parts : Array[String] = []
  for imp in imports {
    let mut s = "{\"module\":\"" + escape_json_string(imp.mod_name) + "\""
    s = s + ",\"name\":\"" + escape_json_string(imp.name) + "\""
    s = s + ",\"kind\":\"" + import_kind_name(imp.kind) + "\""
    match imp.type_index {
      Some(idx) => s = s + ",\"typeIndex\":" + idx.to_string()
      None => ()
    }
    s = s + "}"
    import_parts.push(s)
  }
  out.push(",\"imports\":[" + import_parts.join(",") + "]")
  // Exports
  let export_parts : Array[String] = []
  for exp in exports {
    export_parts.push(
      "{\"name\":\"" +
      escape_json_string(exp.name) +
      "\",\"kind\":\"" +
      export_kind_name(exp.kind) +
      "\",\"index\":" +
      exp.index.to_string() +
      "}",
    )
  }
  out.push(",\"exports\":[" + export_parts.join(",") + "]")
  // Functions (type index mapping for code-section functions)
  let func_parts : Array[String] = []
  for idx in functions {
    func_parts.push(idx.to_string())
  }
  out.push(",\"functions\":[" + func_parts.join(",") + "]")
  out.push("}")
  out.join("")
}

///|
fn is_core_module_header(bytes : Bytes) -> Bool {
  bytes.length() >= 8 &&
  bytes[0] == b'\x00' &&
  bytes[1] == b'\x61' &&
  bytes[2] == b'\x73' &&
  bytes[3] == b'\x6d' &&
  bytes[4] == b'\x01' &&
  bytes[5] == b'\x00' &&
  bytes[6] == b'\x00' &&
  bytes[7] == b'\x00'
}

///|
pub fn extract_first_core_module(bytes : Bytes) -> Bytes {
  if !is_component_header(bytes) {
    return Bytes::new(0)
  }
  let sections = @wite_optimize.parse_component_sections_raise(bytes) catch {
    _ => return Bytes::new(0)
  }
  for section in sections {
    if section.section_id == 1U {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      if is_core_module_header(payload) {
        return payload
      }
    }
  }
  Bytes::new(0)
}

///|
fn main {
  // Entry point required for is-main package; not used in library mode
}

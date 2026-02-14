///|
fn section_payload(bytes : Bytes, section : @wite.RawSection) -> Bytes {
  bytes[section.payload_start:section.section_end].to_bytes()
}

///|
fn find_section(
  sections : Array[@wite.RawSection],
  section_id : UInt,
) -> @wite.RawSection? {
  for section in sections {
    if section.section_id == section_id {
      return Some(section)
    }
  }
  None
}

///|
fn string_to_utf8_bytes(s : String) -> Bytes {
  let out : Array[Byte] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      out.push(cp.to_byte())
    } else if cp < 0x800 {
      out.push((0xC0 | (cp >> 6)).to_byte())
      out.push((0x80 | (cp & 0x3F)).to_byte())
    } else if cp < 0x10000 {
      out.push((0xE0 | (cp >> 12)).to_byte())
      out.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      out.push((0x80 | (cp & 0x3F)).to_byte())
    } else {
      out.push((0xF0 | (cp >> 18)).to_byte())
      out.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
      out.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      out.push((0x80 | (cp & 0x3F)).to_byte())
    }
  }
  Bytes::from_array(out[:])
}

///|
/// Map core wasm value type byte to component model value type byte.
/// i32 (0x7F) → s32 (0x7A)
/// i64 (0x7E) → s64 (0x78)
/// f32 (0x7D) → f32 (0x76)
/// f64 (0x7C) → f64 (0x75)
fn core_valtype_to_component(core_type : Bytes) -> Result[Byte, String] {
  if core_type.length() != 1 {
    return Err("unsupported multi-byte core wasm type")
  }
  match core_type[0].to_uint() {
    0x7FU => Ok(0x7AU.to_byte())
    0x7EU => Ok(0x78U.to_byte())
    0x7DU => Ok(0x76U.to_byte())
    0x7CU => Ok(0x75U.to_byte())
    _ =>
      Err(
        "unsupported core wasm value type: 0x" +
        core_type[0].to_uint().to_string(),
      )
  }
}

///|
fn leb128(value : UInt) -> Array[Byte] {
  @mwac_component.encode_u32_leb128(value)
}

///|
fn append_arr(dst : Array[Byte], src : Array[Byte]) -> Unit {
  @mwac_component.append_bytes(dst, src)
}

///|
fn append_name_to(dst : Array[Byte], name : Bytes) -> Unit {
  append_arr(dst, leb128(name.length().reinterpret_as_uint()))
  for b in name {
    dst.push(b)
  }
}

///|
/// Encode a component function type definition.
/// functype = 0x40 params resultlist
fn encode_component_functype(
  params : Array[Bytes],
  results : Array[Bytes],
) -> Result[Array[Byte], String] {
  let out : Array[Byte] = []
  out.push(0x40U.to_byte())
  // params: vec(param) where param = name valtype
  append_arr(out, leb128(params.length().reinterpret_as_uint()))
  for i, param in params {
    let name = "p" + i.to_string()
    let name_bytes = string_to_utf8_bytes(name)
    append_name_to(out, name_bytes)
    match core_valtype_to_component(param) {
      Ok(b) => out.push(b)
      Err(e) => return Err(e)
    }
  }
  // resultlist
  match results.length() {
    0 => {
      // 0x01 followed by vec of 0 results
      out.push(0x01U.to_byte())
      append_arr(out, leb128(0U))
    }
    1 => {
      // 0x00 followed by single valtype (unnamed)
      out.push(0x00U.to_byte())
      match core_valtype_to_component(results[0]) {
        Ok(b) => out.push(b)
        Err(e) => return Err(e)
      }
    }
    _ => {
      // 0x01 followed by vec of named results
      out.push(0x01U.to_byte())
      append_arr(out, leb128(results.length().reinterpret_as_uint()))
      for i, result in results {
        let name = "r" + i.to_string()
        let name_bytes = string_to_utf8_bytes(name)
        append_name_to(out, name_bytes)
        match core_valtype_to_component(result) {
          Ok(b) => out.push(b)
          Err(e) => return Err(e)
        }
      }
    }
  }
  Ok(out)
}

///|
/// Encode a core alias for a function export from a core instance.
/// sort = 0x00 0x00 (core func), target = 0x00 (export), instance_idx, name
fn encode_core_func_alias(instance_idx : UInt, name : Bytes) -> Array[Byte] {
  let out : Array[Byte] = []
  out.push(0x00U.to_byte()) // core prefix
  out.push(0x00U.to_byte()) // core func sort
  out.push(0x00U.to_byte()) // target: export
  append_arr(out, leb128(instance_idx))
  append_name_to(out, name)
  out
}

///|
/// Encode a canonical lift entry.
/// 0x00 0x00 core_func_idx 0x00(options_count) type_idx
fn encode_canon_lift(core_func_idx : UInt, type_idx : UInt) -> Array[Byte] {
  let out : Array[Byte] = []
  out.push(0x00U.to_byte()) // lift
  out.push(0x00U.to_byte()) // core func
  append_arr(out, leb128(core_func_idx))
  append_arr(out, leb128(0U)) // 0 options
  append_arr(out, leb128(type_idx))
  out
}

///|
pub(all) struct ComponentizeResult {
  bytes : Bytes
  exported_functions : Array[String]
}

///|
/// Convert a core wasm module to a component wasm binary.
/// Only supports numeric types (i32, i64, f32, f64) in function signatures.
/// The core module must have no imports.
pub fn componentize_core_module(
  core_bytes : Bytes,
) -> Result[ComponentizeResult, String] {
  // 1. Parse core sections
  let sections = @wite.parse_core_sections_raise(core_bytes) catch {
    e => return Err("failed to parse core module: " + @wite.error_to_string(e))
  }

  // 2. Check for imports (v1 doesn't support modules with imports)
  match find_section(sections, 2U) {
    Some(s) => {
      let total_imports = @wite.parse_vec_count(section_payload(core_bytes, s)) catch {
        _ => 0U
      }
      if total_imports > 0U {
        return Err(
          "componentize v1 does not support core modules with imports (found " +
          total_imports.to_string() +
          " imports)",
        )
      }
    }
    None => ()
  }

  // 3. Parse type section
  let type_section = match find_section(sections, 1U) {
    Some(s) => s
    None => return Err("core module has no type section")
  }
  let type_entries = @wite.parse_type_section_entries_with_refs_raise(
    section_payload(core_bytes, type_section),
    "componentize",
  ) catch {
    e => return Err("failed to parse type section: " + @wite.error_to_string(e))
  }

  // 4. Parse function section
  let func_section = match find_section(sections, 3U) {
    Some(s) => s
    None => return Err("core module has no function section")
  }
  let func_type_indices = @wite.parse_function_type_indices(
    section_payload(core_bytes, func_section),
  ) catch {
    e =>
      return Err(
        "failed to parse function section: " + @wite.error_to_string(e),
      )
  }

  // 5. Parse export section
  let export_section = match find_section(sections, 7U) {
    Some(s) => s
    None => return Err("core module has no export section")
  }
  let export_fn_map = @wite.parse_export_function_names(
    section_payload(core_bytes, export_section),
  ) catch {
    e =>
      return Err("failed to parse export section: " + @wite.error_to_string(e))
  }

  // 6. Collect function exports as (name, func_index) pairs
  let func_exports : Array[(String, UInt)] = []
  export_fn_map.each(fn(index, names) {
    for name in names {
      func_exports.push((name, index))
    }
  })
  func_exports.sort_by(fn(a, b) { a.1.compare(b.1) })

  if func_exports.is_empty() {
    return Err("core module has no function exports")
  }

  // 7. Parse function types for each export
  let export_type_entries : Array[@wite.FunctionTypeEntry] = []
  for i = 0; i < func_exports.length(); i = i + 1 {
    let (_, func_index) = func_exports[i]
    let local_index = func_index.reinterpret_as_int()
    if local_index < 0 || local_index >= func_type_indices.length() {
      return Err(
        "function index " +
        func_index.to_string() +
        " out of range for function section",
      )
    }
    let type_index = func_type_indices[local_index]
    let type_index_int = type_index.reinterpret_as_int()
    if type_index_int < 0 || type_index_int >= type_entries.length() {
      return Err(
        "type index " +
        type_index.to_string() +
        " out of range for type section",
      )
    }
    let entry = @wite.parse_function_type_entry_from_raw_raise(
      type_entries[type_index_int].raw,
      "componentize",
    ) catch {
      e =>
        return Err("failed to parse function type: " + @wite.error_to_string(e))
    }
    export_type_entries.push(entry)
  }

  // 8. Build component binary
  let out : Array[Byte] = []

  // Component header: \0asm + version 0d 00 01 00
  out
  ..push(0x00U.to_byte())
  ..push(0x61U.to_byte())
  ..push(0x73U.to_byte())
  ..push(0x6dU.to_byte())
  ..push(0x0dU.to_byte())
  ..push(0x00U.to_byte())
  ..push(0x01U.to_byte())
  .push(0x00U.to_byte())

  // Section 1: core:module (embed core wasm bytes)
  let module_payload : Array[Byte] = []
  for b in core_bytes {
    module_payload.push(b)
  }
  @mwac_component.push_section(out, 1U, module_payload)

  // Section 2: core:instance (instantiate module 0 with 0 args)
  let instance_payload : Array[Byte] = []
  append_arr(instance_payload, leb128(1U)) // count = 1
  instance_payload.push(0x00U.to_byte()) // instantiate
  append_arr(instance_payload, leb128(0U)) // module idx = 0
  append_arr(instance_payload, leb128(0U)) // 0 args
  @mwac_component.push_section(out, 2U, instance_payload)

  // Section 6: alias (alias core function exports from core instance 0)
  let alias_payload : Array[Byte] = []
  append_arr(alias_payload, leb128(func_exports.length().reinterpret_as_uint()))
  for i = 0; i < func_exports.length(); i = i + 1 {
    let (name, _) = func_exports[i]
    let name_bytes = string_to_utf8_bytes(name)
    let alias_entry = encode_core_func_alias(0U, name_bytes)
    append_arr(alias_payload, alias_entry)
  }
  @mwac_component.push_section(out, 6U, alias_payload)

  // Section 7: type (component function types)
  let type_payload : Array[Byte] = []
  append_arr(type_payload, leb128(func_exports.length().reinterpret_as_uint()))
  for i = 0; i < func_exports.length(); i = i + 1 {
    let entry = export_type_entries[i]
    match encode_component_functype(entry.params, entry.results) {
      Ok(functype) => append_arr(type_payload, functype)
      Err(e) => return Err(e)
    }
  }
  @mwac_component.push_section(out, 7U, type_payload)

  // Section 8: canon (canonical lift)
  let canon_payload : Array[Byte] = []
  append_arr(canon_payload, leb128(func_exports.length().reinterpret_as_uint()))
  for i = 0; i < func_exports.length(); i = i + 1 {
    let core_func_idx = i.reinterpret_as_uint()
    let type_idx = i.reinterpret_as_uint()
    let lift_entry = encode_canon_lift(core_func_idx, type_idx)
    append_arr(canon_payload, lift_entry)
  }
  @mwac_component.push_section(out, 8U, canon_payload)

  // Section 11: export (component exports)
  let export_payload : Array[Byte] = []
  append_arr(
    export_payload,
    leb128(func_exports.length().reinterpret_as_uint()),
  )
  for i = 0; i < func_exports.length(); i = i + 1 {
    let (name, _) = func_exports[i]
    let name_bytes = string_to_utf8_bytes(name)
    let export_entry = @mwac_component.encode_export(
      name_bytes,
      @mwac_component.ExternKind::Func,
      i.reinterpret_as_uint(),
    )
    append_arr(export_payload, export_entry)
  }
  @mwac_component.push_section(out, 11U, export_payload)

  let exported_names : Array[String] = []
  for i = 0; i < func_exports.length(); i = i + 1 {
    exported_names.push(func_exports[i].0)
  }
  Ok({ bytes: Bytes::from_array(out[:]), exported_functions: exported_names })
}

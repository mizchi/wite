///|
fn core_section_name_for_dump(id : UInt) -> String {
  match id {
    0U => "Custom"
    1U => "Type"
    2U => "Import"
    3U => "Function"
    4U => "Table"
    5U => "Memory"
    6U => "Global"
    7U => "Export"
    8U => "Start"
    9U => "Element"
    10U => "Code"
    11U => "Data"
    12U => "DataCount"
    _ => "Unknown(" + id.to_string() + ")"
  }
}

///|
fn format_hex_offset(offset : Int) -> String {
  let mut value = offset
  if value < 0 {
    return "0x0"
  }
  let digits : Array[Char] = []
  if value == 0 {
    return "0x0"
  }
  while value > 0 {
    let d = value % 16
    let ch = match d {
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
      _ => 'f'
    }
    digits.push(ch)
    value = value / 16
  }
  let out : Array[Char] = ['0', 'x']
  let mut i = digits.length() - 1
  while i >= 0 {
    out.push(digits[i])
    i -= 1
  }
  String::from_array(out)
}

///|
fn run_dump(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("usage: wite dump <file.wasm> [options]")
    println("")
    println("options:")
    println("  --headers    Section headers with offsets (default)")
    println("  --details    Imports, exports, types, functions")
    println("  --disassemble  Disassemble code section")
    println("  --raw        Hex dump of section contents")
    println("  --section=N  Limit --raw/--disassemble to section id N")
    println("  --all        All information")
    @sys.exit(1)
  }
  let input_path = args[2]
  let mut show_headers = false
  let mut show_details = false
  let mut show_disasm = false
  let mut show_raw = false
  let mut section_filter : Int? = None
  for i in 3..<args.length() {
    let arg = args[i]
    match arg {
      "--headers" | "-h" => show_headers = true
      "--details" | "-x" => show_details = true
      "--disassemble" | "-d" => show_disasm = true
      "--raw" | "-s" => show_raw = true
      "--all" | "-a" => {
        show_headers = true
        show_details = true
        show_disasm = true
      }
      _ =>
        if arg.strip_prefix("--section=") is Some(id_str) {
          section_filter = Some(
            parse_uint_or_exit(id_str.to_string(), "section").reinterpret_as_int(),
          )
        } else {
          println("unknown dump option: " + arg)
          @sys.exit(1)
        }
    }
  }
  if !show_headers && !show_details && !show_disasm && !show_raw {
    show_headers = true
    show_details = true
  }
  let bytes = read_bytes_or_exit(input_path)
  let is_component = bytes.length() >= 8 &&
    bytes[4] == b'\x0D' &&
    bytes[5] == b'\x00' &&
    bytes[6] == b'\x01' &&
    bytes[7] == b'\x00'
  println(input_path + ":")
  println("  file size: " + bytes.length().to_string() + " bytes")
  println("  type: " + (if is_component { "component" } else { "core module" }))
  println("")
  if is_component {
    dump_component(bytes, show_headers, show_details)
    if show_raw {
      dump_raw_sections(bytes, section_filter, true)
    }
  } else {
    dump_core(bytes, show_headers, show_details)
    if show_raw {
      dump_raw_sections(bytes, section_filter, false)
    }
    if show_disasm {
      dump_disassemble(bytes, section_filter)
    }
  }
}

///|
fn dump_core(bytes : Bytes, show_headers : Bool, show_details : Bool) -> Unit {
  let sections = @wite_optimize.parse_core_sections_raise(bytes) catch {
    e => {
      println("parse failed: " + @wite_core.error_to_string(e))
      @sys.exit(1)
      return
    }
  }
  if show_headers {
    println("Sections:")
    println(
      "  " +
      pad_right("Id", 4) +
      pad_right("Name", 16) +
      pad_right("Start", 10) +
      pad_right("End", 10) +
      pad_right("Size", 10) +
      "Extra",
    )
    for section in sections {
      let size = section.section_end - section.section_start
      let extra = match section.custom_name {
        Some(name) => "\"" + name + "\""
        None => ""
      }
      println(
        "  " +
        pad_right(section.section_id.to_string(), 4) +
        pad_right(core_section_name_for_dump(section.section_id), 16) +
        pad_right(format_hex_offset(section.section_start), 10) +
        pad_right(format_hex_offset(section.section_end), 10) +
        pad_right(size.to_string(), 10) +
        extra,
      )
    }
    println("")
  }
  if show_details {
    // Imports
    let mut import_count = 0U
    let mut type_count = 0U
    let mut func_count = 0U
    let mut export_count = 0U
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        1U => {
          // Type section
          let count_result = try? @wite_analyze.parse_vec_count(payload)
          match count_result {
            Ok(count) => type_count = count
            Err(_) => ()
          }
        }
        2U => {
          let count_result = try? @wite_analyze.parse_import_function_count(
            payload,
          )
          match count_result {
            Ok(count) => import_count = count
            Err(_) => ()
          }
        }
        3U => {
          let count_result = try? @wite_analyze.parse_vec_count(payload)
          match count_result {
            Ok(count) => func_count = count
            Err(_) => ()
          }
        }
        7U => {
          let count_result = try? @wite_analyze.parse_vec_count(payload)
          match count_result {
            Ok(count) => export_count = count
            Err(_) => ()
          }
        }
        _ => ()
      }
    }
    println("Summary:")
    println("  types: " + type_count.to_string())
    println("  imports: " + import_count.to_string())
    println("  functions: " + func_count.to_string())
    println("  exports: " + export_count.to_string())
    println("")
    // Function details
    match @wite_analyze.analyze_function_sizes(bytes) {
      Ok(functions) => {
        println("Functions (" + functions.length().to_string() + "):")
        for f in functions {
          let label = match f.name {
            Some(name) => name
            None => ""
          }
          let exports = if f.export_names.length() > 0 {
            " [" + f.export_names.join(", ") + "]"
          } else {
            ""
          }
          println(
            "  func[" +
            f.function_index.to_string() +
            "] " +
            label +
            " size=" +
            f.body_bytes.to_string() +
            exports,
          )
        }
        println("")
      }
      Err(_) => ()
    }
    // Export details
    match @wite_analyze.analyze_call_graph(bytes) {
      Ok(report) => {
        let export_list : Array[String] = []
        for node in report.nodes {
          if node.export_names.length() > 0 {
            let node_label = if node.body_bytes > 0U {
              " size=" + node.body_bytes.to_string()
            } else {
              ""
            }
            for export_name in node.export_names {
              export_list.push(
                "  export[" +
                export_name +
                "] -> func[" +
                node.function_index.to_string() +
                "]" +
                node_label,
              )
            }
          }
        }
        if export_list.length() > 0 {
          println("Exports (" + export_list.length().to_string() + "):")
          for line in export_list {
            println(line)
          }
          println("")
        }
      }
      Err(_) => ()
    }
  }
}

///|
fn dump_component(
  bytes : Bytes,
  show_headers : Bool,
  _show_details : Bool,
) -> Unit {
  let sections = @wite_optimize.parse_component_sections_raise(bytes) catch {
    e => {
      println("parse failed: " + @wite_core.error_to_string(e))
      @sys.exit(1)
      return
    }
  }
  if show_headers {
    println("Component Sections:")
    println(
      "  " +
      pad_right("Id", 4) +
      pad_right("Start", 10) +
      pad_right("End", 10) +
      pad_right("Size", 10),
    )
    for section in sections {
      let size = section.section_end - section.section_start
      println(
        "  " +
        pad_right(section.section_id.to_string(), 4) +
        pad_right(format_hex_offset(section.section_start), 10) +
        pad_right(format_hex_offset(section.section_end), 10) +
        pad_right(size.to_string(), 10),
      )
    }
    println("")
  }
  // Component profile
  match @wite_core.profile_component(bytes) {
    Ok(profile) => {
      println("Component Summary:")
      println("  core modules: " + profile.core_module_count.to_string())
      println(
        "  nested components: " + profile.nested_component_count.to_string(),
      )
      println("  imports: " + profile.import_count.to_string())
      println("  exports: " + profile.export_count.to_string())
      println("")
    }
    Err(_) => ()
  }
}

///|
fn hex_byte(b : Byte) -> String {
  let hi = b.to_int() / 16
  let lo = b.to_int() % 16
  let hex_char = fn(v : Int) -> Char {
    if v < 10 {
      Int::unsafe_to_char(48 + v)
    } else {
      Int::unsafe_to_char(87 + v)
    }
  }
  String::from_array([hex_char(hi), hex_char(lo)])
}

///|
fn dump_hex_line(bytes : Bytes, offset : Int, len : Int) -> Unit {
  let mut line = format_hex_offset(offset)
  // Pad to 8 chars
  let mut pad_count = 0
  for _ in line {
    pad_count += 1
  }
  while pad_count < 8 {
    line = " " + line
    pad_count += 1
  }
  line = line + ": "
  let mut ascii = ""
  let actual_len = if offset + len > bytes.length() {
    bytes.length() - offset
  } else {
    len
  }
  for i in 0..<actual_len {
    line = line + hex_byte(bytes[offset + i])
    if i % 2 == 1 {
      line = line + " "
    }
    let ch = bytes[offset + i].to_int()
    ascii = ascii +
      (if ch >= 32 && ch < 127 {
        String::from_array([Int::unsafe_to_char(ch)])
      } else {
        "."
      })
  }
  // Pad hex part for short lines
  let mut hex_chars = 0
  for _ in line {
    hex_chars += 1
  }
  while hex_chars < 50 {
    line = line + " "
    hex_chars += 1
  }
  println(line + " " + ascii)
}

///|
fn dump_raw_sections(
  bytes : Bytes,
  section_filter : Int?,
  is_component : Bool,
) -> Unit {
  let sections = if is_component {
    @wite_optimize.parse_component_sections_raise(bytes) catch {
      _ => return
    }
  } else {
    @wite_optimize.parse_core_sections_raise(bytes) catch {
      _ => return
    }
  }
  for section in sections {
    let id = section.section_id.reinterpret_as_int()
    match section_filter {
      Some(filter_id) => if id != filter_id { continue }
      None => ()
    }
    let name = if is_component {
      "section " + id.to_string()
    } else {
      core_section_name_for_dump(section.section_id)
    }
    let extra = match section.custom_name {
      Some(n) => " \"" + n + "\""
      None => ""
    }
    let size = section.section_end - section.payload_start
    println("Raw: " + name + extra + " (" + size.to_string() + " bytes)")
    let max_dump = 256
    let dump_size = if size > max_dump { max_dump } else { size }
    let mut offset = section.payload_start
    while offset < section.payload_start + dump_size {
      let line_len = if offset + 16 > section.payload_start + dump_size {
        section.payload_start + dump_size - offset
      } else {
        16
      }
      dump_hex_line(bytes, offset, line_len)
      offset += 16
    }
    if size > max_dump {
      println("  ... (" + (size - max_dump).to_string() + " more bytes)")
    }
    println("")
  }
}

///|
fn wasm_opcode_mnemonic(opcode : UInt) -> String {
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
    0x29U => "i64.load"
    0x2aU => "f32.load"
    0x2bU => "f64.load"
    0x36U => "i32.store"
    0x37U => "i64.store"
    0x38U => "f32.store"
    0x39U => "f64.store"
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
    0x6aU => "i32.add"
    0x6bU => "i32.sub"
    0x6cU => "i32.mul"
    0x6dU => "i32.div_s"
    0x6eU => "i32.div_u"
    0x71U => "i32.and"
    0x72U => "i32.or"
    0x73U => "i32.xor"
    0x74U => "i32.shl"
    0x75U => "i32.shr_s"
    0x76U => "i32.shr_u"
    0xd0U => "ref.null"
    0xd1U => "ref.is_null"
    0xd2U => "ref.func"
    _ => "op:" + format_hex_offset(opcode.reinterpret_as_int())
  }
}

///|
fn dump_disassemble(bytes : Bytes, section_filter : Int?) -> Unit {
  // Only disassemble code section (id=10) unless overridden
  let target_id = match section_filter {
    Some(id) => id.reinterpret_as_uint()
    None => 10U
  }
  let sections = @wite_optimize.parse_core_sections_raise(bytes) catch {
    _ => return
  }
  let mut imported_count = 0U
  for section in sections {
    if section.section_id == 2U {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      let count_result = try? @wite_analyze.parse_import_function_count(payload)
      match count_result {
        Ok(c) => imported_count = c
        Err(_) => ()
      }
    }
  }
  for section in sections {
    if section.section_id != target_id {
      continue
    }
    if section.section_id == 10U {
      // Code section: parse bodies and disassemble each
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      let bodies = @wite_analyze.parse_code_bodies(payload) catch {
        _ => return
      }
      // Get function names if available
      let func_names : Map[UInt, String] = {}
      for s in sections {
        if s.section_id == 0U && s.custom_name == Some("name") {
          let name_payload = bytes[s.payload_start:s.section_end].to_bytes()
          let parsed = try? @wite_analyze.parse_name_section_function_names(
            name_payload,
          )
          match parsed {
            Ok(names) => names.each((idx, name) => func_names.set(idx, name))
            Err(_) => ()
          }
        }
      }
      // Get export names
      let export_names : Map[UInt, Array[String]] = {}
      for s in sections {
        if s.section_id == 7U {
          let exp_payload = bytes[s.payload_start:s.section_end].to_bytes()
          let parsed = try? @wite_analyze.parse_export_function_names(
            exp_payload,
          )
          match parsed {
            Ok(names) =>
              @wite_analyze.merge_export_function_names(export_names, names)
            Err(_) => ()
          }
        }
      }
      println("Disassembly (" + bodies.length().to_string() + " functions):")
      println("")
      for i in 0..<bodies.length() {
        let func_idx = imported_count + i.reinterpret_as_uint()
        let label = match func_names.get(func_idx) {
          Some(name) => name
          None => ""
        }
        let exports = match export_names.get(func_idx) {
          Some(names) => " [" + names.join(", ") + "]"
          None => ""
        }
        let body = bodies[i]
        println(
          "func[" +
          func_idx.to_string() +
          "] " +
          label +
          exports +
          " (" +
          body.length().to_string() +
          " bytes):",
        )
        // Parse prefix (locals)
        let prefix_end = @wite_analyze.parse_local_decl_prefix_end(body) catch {
          _ => {
            println("  (failed to parse locals)")
            println("")
            continue
          }
        }
        let instr_bytes = body[prefix_end:body.length()].to_bytes()
        match @wite_optimize.parse_instruction_spans(instr_bytes) {
          Some(spans) => {
            let mut depth = 0
            for span in spans {
              let mnemonic = wasm_opcode_mnemonic(span.opcode)
              // Adjust depth for block-end
              if span.opcode == 0x0bU && depth > 0 {
                depth -= 1
              }
              if span.opcode == 0x05U && depth > 0 {
                depth -= 1
              }
              let mut indent = "  "
              for _ in 0..<depth {
                indent = indent + "  "
              }
              let span_size = span.end_ - span.start
              let hex = if span_size <= 8 {
                let parts : Array[String] = []
                for j in span.start..<span.end_ {
                  parts.push(hex_byte(instr_bytes[j]))
                }
                parts.join(" ")
              } else {
                hex_byte(instr_bytes[span.start]) + " ..."
              }
              println(indent + pad_right(mnemonic, 20) + " ; " + hex)
              // Adjust depth for block-start
              if span.opcode == 0x02U ||
                span.opcode == 0x03U ||
                span.opcode == 0x04U {
                depth += 1
              }
              if span.opcode == 0x05U {
                depth += 1
              }
            }
          }
          None => println("  (failed to parse instructions)")
        }
        println("")
      }
    }
  }
}

///|
fn pad_right(s : String, width : Int) -> String {
  let mut out = s
  let mut len = 0
  for _ in s {
    len += 1
  }
  while len < width {
    out = out + " "
    len += 1
  }
  out
}

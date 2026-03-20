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
    println("  --all        All information")
    @sys.exit(1)
  }
  let input_path = args[2]
  let mut show_headers = false
  let mut show_details = false
  for i in 3..<args.length() {
    match args[i] {
      "--headers" | "-h" => show_headers = true
      "--details" | "-x" => show_details = true
      "--all" | "-a" => {
        show_headers = true
        show_details = true
      }
      _ => {
        println("unknown dump option: " + args[i])
        @sys.exit(1)
      }
    }
  }
  if !show_headers && !show_details {
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
  println(
    "  file size: " + bytes.length().to_string() + " bytes",
  )
  println(
    "  type: " + (if is_component { "component" } else { "core module" }),
  )
  println("")
  if is_component {
    dump_component(bytes, show_headers, show_details)
  } else {
    dump_core(bytes, show_headers, show_details)
  }
}

///|
fn dump_core(
  bytes : Bytes,
  show_headers : Bool,
  show_details : Bool,
) -> Unit {
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
        println(
          "Functions (" + functions.length().to_string() + "):",
        )
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
          println(
            "Exports (" + export_list.length().to_string() + "):",
          )
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

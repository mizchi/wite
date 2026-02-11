///|
pub fn analyze_section_sizes(
  bytes : Bytes,
) -> Result[Array[SectionSize], WiteError] {
  try? ({
    let sections = parse_core_sections_raise(bytes)
    summarize_sections(sections, false)
  })
}

///|
pub fn optimize_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[OptimizeResult, WiteError] {
  @wite_optimize.optimize_for_size(bytes, config~)
}

///|
pub fn profile_module(bytes : Bytes) -> Result[ModuleProfile, WiteError] {
  try? ({
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
  })
}

///|
pub fn analyze_function_sizes(
  bytes : Bytes,
) -> Result[Array[FunctionSize], WiteError] {
  try? ({
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
      raise WiteError::InvalidFormat(
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
    functions.sort_by((a, b) => {
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
    })
    functions
  })
}

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
fn collect_root_reasons_raise(
  bytes : Bytes,
  export_root_names : Array[String]?,
) -> (Map[UInt, Array[String]], Bool) raise WiteError {
  let reasons_map : Map[UInt, Array[String]] = {}
  let sections = parse_core_sections_raise(bytes)
  let mut partial = false
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
          Err(_) => partial = true
        }
      }
      9U => {
        let result = try? parse_element_section_function_refs_raise(payload)
        match result {
          Ok(indices) =>
            for index in indices {
              map_push_string_array(reasons_map, index, "element-ref.func")
            }
          Err(_) => partial = true
        }
      }
      _ => ()
    }
  }
  (reasons_map, partial)
}

///|
fn build_retain_path_from_parent_map(
  target : UInt,
  parent_map : Map[UInt, UInt],
) -> Array[UInt] {
  let reversed : Array[UInt] = [target]
  let mut current = target
  while true {
    match parent_map.get(current) {
      Some(parent) => {
        reversed.push(parent)
        current = parent
      }
      None => break
    }
  }
  let path : Array[UInt] = []
  for i in 0..<reversed.length() {
    path.push(reversed[reversed.length() - 1 - i])
  }
  path
}

///|
fn compare_retain_path_entry(a : RetainPathEntry, b : RetainPathEntry) -> Int {
  if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else {
    0
  }
}

///|
pub fn analyze_keep_reasons(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[KeepReasonReport, WiteError] {
  try? {
    let export_root_names = export_root_names_from_config(config)
    let graph = analyze_call_graph_raise(bytes, export_root_names)
    let (reasons_map, reasons_partial) = collect_root_reasons_raise(
      bytes, export_root_names,
    )
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
    { partial: graph.partial || reasons_partial, entries }
  }
}

///|
pub fn analyze_retain_paths(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[RetainPathReport, WiteError] {
  try? {
    let export_root_names = export_root_names_from_config(config)
    let graph = analyze_call_graph_raise(bytes, export_root_names)
    let (root_reasons_map, root_reason_partial) = collect_root_reasons_raise(
      bytes, export_root_names,
    )
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
    let entries : Array[RetainPathEntry] = []
    for node in graph.nodes {
      if not(node.reachable_from_roots) {
        continue
      }
      let path = build_retain_path_from_parent_map(
        node.function_index,
        parent_map,
      )
      let root_index = if path.length() > 0 {
        path[0]
      } else {
        node.function_index
      }
      let root_reasons = match root_reasons_map.get(root_index) {
        Some(v) => v.copy()
        None => []
      }
      if root_reasons.length() == 0 {
        root_reasons.push("reachable")
      }
      root_reasons.sort()
      root_reasons.dedup()
      entries.push({
        function_index: node.function_index,
        name: node.name,
        export_names: node.export_names,
        body_bytes: node.body_bytes,
        root_reasons,
        path,
      })
    }
    entries.sort_by(compare_retain_path_entry)
    {
      partial: graph.partial || root_reason_partial,
      roots: graph.roots,
      entries,
    }
  }
}

///|
pub fn analyze_dce_report(bytes : Bytes) -> Result[DceReport, WiteError] {
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

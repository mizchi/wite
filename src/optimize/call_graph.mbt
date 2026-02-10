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
fn analyze_call_graph_raise(
  bytes : Bytes,
  export_root_names : Array[String]?,
) -> CallGraphReport raise WiteError {
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
    raise WiteError::InvalidFormat(
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
    let direct_result = try? collect_direct_callees_from_body_raise(body)
    match direct_result {
      Ok((callees, body_has_indirect)) => {
        direct_callees = callees
        if body_has_indirect {
          has_indirect_calls = true
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
  let total_function_count_u = imported_function_count + local_function_count
  let total_function_count = UInt::reinterpret_as_int(total_function_count_u)
  if total_function_count < 0 {
    raise WiteError::InvalidFormat(
      "function count overflow in analyze-call-graph",
    )
  }
  let visited = make_bool_array(total_function_count, false)
  let queue = roots.copy()
  let mut head = 0
  while head < queue.length() {
    let index = queue[head]
    head += 1
    if not(mark_visited_function_index(visited, index)) {
      continue
    }
    match index_to_pos.get(index) {
      Some(pos) =>
        for callee in nodes[pos].direct_callees {
          if not(is_visited_function_index(visited, callee)) {
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
    let reachable = is_visited_function_index(visited, node.function_index)
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

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
fn map_merge_unique_u32_array(
  target : Map[UInt, Array[UInt]],
  source : Map[UInt, Array[UInt]],
) -> Unit {
  source.each((key, values) => {
    match target.get(key) {
      Some(prev) => {
        let next = prev.copy()
        for value in values {
          if !next.contains(value) {
            next.push(value)
          }
        }
        target.set(key, next)
      }
      None => target.set(key, values.copy())
    }
  })
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
  let element_refs_by_table : Map[UInt, Array[UInt]] = {}
  let used_table_indices : Array[UInt] = []
  let used_table_seen : Map[UInt, Bool] = {}
  let mut partial = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => local_function_count += parse_vec_count(payload)
      7U => {
        let parsed = parse_export_function_names(payload)
        merge_export_function_names(export_names, parsed)
        parsed.each((index, names) => {
          if should_include_export_root(names, export_root_names) {
            push_unique_u32_with_seen(roots, root_seen, index)
          }
        })
        for index in parse_export_indices_by_kind(payload, 1U) {
          push_unique_u32_with_seen(used_table_indices, used_table_seen, index)
        }
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
        let refs_result = try? parse_element_section_table_function_refs_raise(
          payload,
        )
        match refs_result {
          Ok(grouped) =>
            map_merge_unique_u32_array(element_refs_by_table, grouped)
          Err(_) => partial = true
        }
      }
      10U => {
        code_bodies = parse_code_bodies(payload)
        match collect_call_indirect_table_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32_with_seen(
                used_table_indices, used_table_seen, index,
              )
            }
          None => partial = true
        }
      }
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
  if has_indirect_calls || used_table_indices.length() > 0 {
    for table_index in used_table_indices {
      match element_refs_by_table.get(table_index) {
        Some(indices) =>
          for index in indices {
            push_unique_u32_with_seen(roots, root_seen, index)
          }
        None => ()
      }
    }
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
    if !mark_visited_function_index(visited, index) {
      continue
    }
    match index_to_pos.get(index) {
      Some(pos) =>
        for callee in nodes[pos].direct_callees {
          if !is_visited_function_index(visited, callee) {
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

///|
fn analyze_call_graph_summary_raise(
  bytes : Bytes,
) -> CallGraphSummary raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut local_function_count = 0U
  let mut code_bodies : Array[Bytes] = []
  let roots : Array[UInt] = []
  let root_seen : Map[UInt, Bool] = {}
  let element_refs_by_table : Map[UInt, Array[UInt]] = {}
  let used_table_indices : Array[UInt] = []
  let used_table_seen : Map[UInt, Bool] = {}
  let mut partial = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => local_function_count += parse_vec_count(payload)
      7U => {
        for index in parse_export_indices_by_kind(payload, 0U) {
          push_unique_u32_with_seen(roots, root_seen, index)
        }
        for index in parse_export_indices_by_kind(payload, 1U) {
          push_unique_u32_with_seen(used_table_indices, used_table_seen, index)
        }
      }
      8U =>
        push_unique_u32_with_seen(
          roots,
          root_seen,
          parse_start_function_index(payload),
        )
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
        let refs_result = try? parse_element_section_table_function_refs_raise(
          payload,
        )
        match refs_result {
          Ok(grouped) =>
            map_merge_unique_u32_array(element_refs_by_table, grouped)
          Err(_) => partial = true
        }
      }
      10U => {
        code_bodies = parse_code_bodies(payload)
        match collect_call_indirect_table_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32_with_seen(
                used_table_indices, used_table_seen, index,
              )
            }
          None => partial = true
        }
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
  let local_body_bytes : Array[UInt] = []
  let direct_callees_by_local : Array[Array[UInt]] = []
  let mut has_indirect_calls = false
  for body in code_bodies {
    local_body_bytes.push(body.length().reinterpret_as_uint())
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
    direct_callees_by_local.push(direct_callees)
  }
  if has_indirect_calls || used_table_indices.length() > 0 {
    for table_index in used_table_indices {
      match element_refs_by_table.get(table_index) {
        Some(indices) =>
          for index in indices {
            push_unique_u32_with_seen(roots, root_seen, index)
          }
        None => ()
      }
    }
  }
  let total_function_count_u = imported_function_count + local_function_count
  let total_function_count = UInt::reinterpret_as_int(total_function_count_u)
  if total_function_count < 0 {
    raise WiteError::InvalidFormat(
      "function count overflow in analyze-call-graph-summary",
    )
  }
  let visited = make_bool_array(total_function_count, false)
  let queue = roots.copy()
  let mut head = 0
  while head < queue.length() {
    let index = queue[head]
    head += 1
    if !mark_visited_function_index(visited, index) {
      continue
    }
    if index < imported_function_count {
      continue
    }
    let local_index = index - imported_function_count
    let pos = UInt::reinterpret_as_int(local_index)
    if pos < 0 || pos >= direct_callees_by_local.length() {
      continue
    }
    for callee in direct_callees_by_local[pos] {
      if !is_visited_function_index(visited, callee) {
        queue.push(callee)
      }
    }
  }
  let mut reachable_function_count = 0U
  let mut reachable_body_bytes = 0U
  let mut dead_body_bytes = 0U
  for i in 0..<local_body_bytes.length() {
    let function_index = imported_function_count + i.reinterpret_as_uint()
    if is_visited_function_index(visited, function_index) {
      reachable_function_count += 1U
      reachable_body_bytes += local_body_bytes[i]
    } else {
      dead_body_bytes += local_body_bytes[i]
    }
  }
  {
    imported_function_count,
    local_function_count,
    roots,
    has_indirect_calls,
    partial,
    reachable_function_count,
    dead_function_count: local_function_count - reachable_function_count,
    reachable_body_bytes,
    dead_body_bytes,
  }
}

///|
pub fn analyze_call_graph(bytes : Bytes) -> Result[CallGraphReport, WiteError] {
  try? analyze_call_graph_raise(bytes, None)
}

///|
pub fn analyze_call_graph_summary(
  bytes : Bytes,
) -> Result[CallGraphSummary, WiteError] {
  try? analyze_call_graph_summary_raise(bytes)
}

///|
fn compare_host_code_hint(a : HostCodeHint, b : HostCodeHint) -> Int {
  if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else {
    a.kind.compare(b.kind)
  }
}

///|
fn size_gain_bytes(before_size : UInt, after_size : UInt) -> UInt {
  if before_size > after_size {
    before_size - after_size
  } else {
    0U
  }
}

///|
fn size_regression_bytes(before_size : UInt, after_size : UInt) -> UInt {
  if after_size > before_size {
    after_size - before_size
  } else {
    0U
  }
}

///|
pub fn analyze_host_generated_code(
  bytes : Bytes,
) -> Result[HostGeneratedCodeReport, WiteError] {
  try? ({
    let sections = parse_core_sections_raise(bytes)
    let mut type_payload : Bytes? = None
    let mut import_payload : Bytes? = None
    let mut function_payload : Bytes? = None
    let mut code_payload : Bytes? = None
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        1U => type_payload = Some(payload)
        2U => import_payload = Some(payload)
        3U => function_payload = Some(payload)
        7U => {
          let parsed = parse_export_function_names(payload)
          merge_export_function_names(export_names, parsed)
        }
        10U => code_payload = Some(payload)
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
    let imported_function_type_indices = match import_payload {
      Some(payload) => parse_import_function_type_indices(payload)
      None => []
    }
    let imported_function_count = imported_function_type_indices
      .length()
      .reinterpret_as_uint()
    let mut local_function_count = 0U
    let mut param_forwarding_thunk_count = 0U
    let mut const_forwarding_thunk_count = 0U
    let mut signature_refinable_thunk_count = 0U
    let hints : Array[HostCodeHint] = []
    match (type_payload, function_payload, code_payload) {
      (Some(type_payload), Some(function_payload), Some(code_payload)) => {
        let local_function_type_indices = parse_function_type_indices(
          function_payload,
        )
        local_function_count = local_function_type_indices
          .length()
          .reinterpret_as_uint()
        let code_bodies = parse_code_bodies(code_payload)
        if local_function_type_indices.length() != code_bodies.length() {
          raise WiteError::InvalidFormat(
            "function/code section count mismatch for analyze-host: function=" +
            local_function_type_indices.length().to_string() +
            " code=" +
            code_bodies.length().to_string(),
          )
        }
        let function_type_by_index = imported_function_type_indices.copy()
        function_type_by_index.append(local_function_type_indices[:])
        let parsed_type_entries = parse_type_section_entries_with_refs_raise(
          type_payload, "analyze-host",
        )
        let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
        let gc_type_canonical_map = collect_gc_type_canonical_map_from_entries_raise(
          parsed_type_entries,
        )
        let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
        for i in 0..<parsed_type_entries.length() {
          if parsed_type_entries[i].form == 0x60U {
            function_type_entry_by_type_index.set(
              i.reinterpret_as_uint(),
              parse_function_type_entry_from_raw_raise(
                parsed_type_entries[i].raw,
                "analyze-host",
              ),
            )
          }
        }
        let function_param_count_by_index : Array[UInt] = []
        for type_index in function_type_by_index {
          if type_index >= type_count_u {
            raise WiteError::InvalidFormat(
              "type index out of range in analyze-host: " +
              type_index.to_string(),
            )
          }
          let type_pos = UInt::reinterpret_as_int(type_index)
          if type_pos < 0 || type_pos >= parsed_type_entries.length() {
            raise WiteError::InvalidFormat(
              "type index position out of range in analyze-host: " +
              type_index.to_string(),
            )
          }
          if parsed_type_entries[type_pos].form != 0x60U {
            raise WiteError::InvalidFormat(
              "non-function type index used by function in analyze-host: " +
              type_index.to_string(),
            )
          }
          function_param_count_by_index.push(
            parse_function_type_param_count_from_raw_raise(
              parsed_type_entries[type_pos].raw,
              "analyze-host",
            ),
          )
        }
        let param_alias_map = collect_call_forwarding_alias_map(
          code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
          function_param_count_by_index, gc_type_canonical_map,
        )
        param_alias_map.each((function_index, target_function_index) => {
          param_forwarding_thunk_count += 1U
          hints.push({
            kind: "param-forward",
            function_index,
            function_name: function_names.get(function_index),
            target_function_index,
            target_function_name: function_names.get(target_function_index),
            export_names: match export_names.get(function_index) {
              Some(v) => v
              None => []
            },
            appended_i32_const_count: 0U,
            dropped_param_count: 0U,
          })
        })
        let const_alias_map = collect_const_call_forwarding_alias_map(
          code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
          gc_type_canonical_map,
        )
        const_alias_map.each((function_index, alias_info) => {
          const_forwarding_thunk_count += 1U
          hints.push({
            kind: "const-forward",
            function_index,
            function_name: function_names.get(function_index),
            target_function_index: alias_info.target,
            target_function_name: function_names.get(alias_info.target),
            export_names: match export_names.get(function_index) {
              Some(v) => v
              None => []
            },
            appended_i32_const_count: alias_info.appended_i32_const_instrs
            .length()
            .reinterpret_as_uint(),
            dropped_param_count: 0U,
          })
        })
        let signature_alias_map = collect_signature_refine_alias_map(
          code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
          gc_type_canonical_map,
        )
        signature_alias_map.each((function_index, alias_info) => {
          signature_refinable_thunk_count += 1U
          hints.push({
            kind: "signature-refine",
            function_index,
            function_name: function_names.get(function_index),
            target_function_index: alias_info.target,
            target_function_name: function_names.get(alias_info.target),
            export_names: match export_names.get(function_index) {
              Some(v) => v
              None => []
            },
            appended_i32_const_count: alias_info.appended_i32_const_instrs
            .length()
            .reinterpret_as_uint(),
            dropped_param_count: alias_info.dropped_param_count,
          })
        })
      }
      _ => ()
    }
    hints.sort_by(compare_host_code_hint)
    let directize_result = apply_directize_raise(bytes)
    let dce_report = match analyze_dce_report(bytes) {
      Ok(v) => v
      Err(e) => raise e
    }
    {
      imported_function_count,
      local_function_count,
      param_forwarding_thunk_count,
      const_forwarding_thunk_count,
      signature_refinable_thunk_count,
      directize_candidate_call_count: directize_result.rewritten_call_count,
      dce_removable_function_count: dce_report.removable_function_count,
      dce_removable_body_bytes: dce_report.removable_body_bytes,
      dce_partial: dce_report.partial,
      hints,
    }
  })
}

///|
pub fn make_component_optimize_config(
  base? : OptimizeConfig = OptimizeConfig::default(),
  root_name_candidates? : Array[String] = [],
  exclude? : Array[String] = [],
) -> OptimizeConfig {
  let merged_roots = merge_root_names(
    merge_root_names(base.closed_world_root_exports, root_name_candidates),
    exclude,
  )
  clone_optimize_config(base, closed_world_root_exports=merged_roots)
}

///|
fn with_additional_closed_world_roots(
  config : OptimizeConfig,
  extra_roots : Array[String],
) -> OptimizeConfig {
  if extra_roots.length() == 0 {
    return config
  }
  make_component_optimize_config(base=config, exclude=extra_roots)
}

///|
fn is_core_module_payload(payload : Bytes) -> Bool {
  payload.length() >= 8 &&
  payload[0] == 0x00U.to_byte() &&
  payload[1] == 0x61U.to_byte() &&
  payload[2] == 0x73U.to_byte() &&
  payload[3] == 0x6dU.to_byte() &&
  payload[4] == 0x01U.to_byte() &&
  payload[5] == 0x00U.to_byte() &&
  payload[6] == 0x00U.to_byte() &&
  payload[7] == 0x00U.to_byte()
}

///|
priv struct ComponentOptimizeRoundResult {
  bytes : Bytes
  core_module_count : UInt
  removed_sections : Array[String]
  no_change_reasons : Array[String]
}

///|
fn optimize_component_for_size_round(
  bytes : Bytes,
  config : OptimizeConfig,
) -> Result[ComponentOptimizeRoundResult, String] {
  let sections_result = try? parse_component_sections_raise(bytes)
  let sections = match sections_result {
    Ok(v) => v
    Err(e) =>
      return Err("component section parse failed: " + error_to_string(e))
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  let removed_sections : Array[String] = []
  let no_change_reasons : Array[String] = []
  let mut core_module_index = 0
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    if section.section_id == 1U && is_core_module_payload(payload) {
      let optimized = match optimize_for_size(payload, config~) {
        Ok(v) => v
        Err(e) =>
          return Err(
            "core module optimize failed at index " +
            core_module_index.to_string() +
            ": " +
            error_to_string(e),
          )
      }
      append_encoded_section(out, 1U, optimized.bytes)
      for removed in optimized.removed_sections {
        removed_sections.push(
          "core#" + core_module_index.to_string() + ":" + removed,
        )
      }
      for reason in optimized.no_change_reasons {
        no_change_reasons.push(
          "core#" + core_module_index.to_string() + ":" + reason,
        )
      }
      core_module_index += 1
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  if core_module_index == 0 {
    push_reason(
      no_change_reasons, "component has no embedded core module sections",
    )
  }
  Ok({
    bytes: Bytes::from_array(out[:]),
    core_module_count: core_module_index.reinterpret_as_uint(),
    removed_sections,
    no_change_reasons,
  })
}

///|
pub fn optimize_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[OptimizeResult, WiteError] {
  try? ({
    let rounds = if config.pass_rounds == 0U { 1U } else { config.pass_rounds }
    let mut current = bytes
    let removed_sections : Array[String] = []
    for _ in 0U..<rounds {
      let before_round_size = current.length().reinterpret_as_uint()
      let round = optimize_for_size_round_raise(current, config)
      let after_round_size = round.bytes.length().reinterpret_as_uint()
      let changed = if after_round_size != before_round_size {
        true
      } else {
        !bytes_equal(round.bytes, current)
      }
      current = round.bytes
      removed_sections.append(round.removed_sections[:])
      if !changed {
        break
      }
      // Stop fixed-point rounds once a round regresses size.
      // Keep size-neutral rounds because they can unlock later DCE.
      if after_round_size > before_round_size {
        break
      }
    }
    let no_change_reasons = collect_optimize_no_change_reasons(
      bytes, current, config,
    )
    {
      bytes: current,
      before_size: bytes.length().reinterpret_as_uint(),
      after_size: current.length().reinterpret_as_uint(),
      removed_sections,
      no_change_reasons,
    }
  })
}

///|
pub fn optimize_auto_for_size(
  bytes : Bytes,
  config : OptimizeConfig,
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  optimize_binary_for_size(bytes, config~, exclude~)
}

///|
pub fn optimize_core_for_size(
  bytes : Bytes,
  config : OptimizeConfig,
) -> Result[OptimizeResult, String] {
  match optimize_for_size(bytes, config~) {
    Ok(result) => Ok(result)
    Err(e) => e |> error_to_string |> Err
  }
}

///|
pub fn optimize_component_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  let effective_config = with_additional_closed_world_roots(config, exclude)
  let rounds = if effective_config.pass_rounds == 0U {
    1U
  } else {
    effective_config.pass_rounds
  }
  let per_round_config = clone_optimize_config(effective_config, pass_rounds=1U)
  let mut current = bytes
  let removed_sections : Array[String] = []
  let no_change_reasons : Array[String] = []
  let mut converged = false
  for i in 0U..<rounds {
    let round_result = match
      optimize_component_for_size_round(current, per_round_config) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let before_size = current.length().reinterpret_as_uint()
    let after_size = round_result.bytes.length().reinterpret_as_uint()
    let changed = if after_size != before_size {
      true
    } else {
      !bytes_equal(round_result.bytes, current)
    }
    if after_size < before_size || (after_size == before_size && changed) {
      current = round_result.bytes
      removed_sections.append(round_result.removed_sections[:])
      continue
    }
    converged = true
    removed_sections.push(
      "component-converge:no-improve:" + (i + 1U).to_string(),
    )
    for reason in round_result.no_change_reasons {
      push_reason(no_change_reasons, reason)
    }
    if round_result.core_module_count == 0U {
      push_reason(
        no_change_reasons, "component has no embedded core module sections",
      )
    }
    break
  }
  if !converged {
    removed_sections.push("component-converge:round-cap:" + rounds.to_string())
  }
  if current.length() == bytes.length() && no_change_reasons.length() == 0 {
    no_change_reasons.push("component optimization produced no size change")
  }
  Ok({
    bytes: current,
    before_size: bytes.length().reinterpret_as_uint(),
    after_size: current.length().reinterpret_as_uint(),
    removed_sections,
    no_change_reasons,
  })
}

///|
pub fn optimize_binary_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  if bytes.length() >= 8 &&
    bytes[0] == 0x00U.to_byte() &&
    bytes[1] == 0x61U.to_byte() &&
    bytes[2] == 0x73U.to_byte() &&
    bytes[3] == 0x6dU.to_byte() &&
    bytes[4] == 0x0dU.to_byte() &&
    bytes[5] == 0x00U.to_byte() &&
    bytes[6] == 0x01U.to_byte() &&
    bytes[7] == 0x00U.to_byte() {
    optimize_component_for_size(bytes, config~, exclude~)
  } else {
    optimize_core_for_size(bytes, config)
  }
}

///|
pub fn optimize_with_kind(
  bytes : Bytes,
  kind : OptimizeKind,
  config : OptimizeConfig,
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  match kind {
    OptimizeKind::Auto => optimize_auto_for_size(bytes, config, exclude~)
    OptimizeKind::Core => optimize_core_for_size(bytes, config)
    OptimizeKind::Component =>
      optimize_component_for_size(bytes, config~, exclude~)
  }
}

///|
fn is_dwarf_custom_section_name(name : String) -> Bool {
  name.has_prefix(".debug_") || name.has_prefix("reloc..debug_")
}

///|
fn is_debug_custom_section_name(name : String) -> Bool {
  name == "sourceMappingURL" ||
  name == "external_debug_info" ||
  is_dwarf_custom_section_name(name)
}

///|
fn keep_custom_section(section : RawSection, config : OptimizeConfig) -> Bool {
  if section.section_id != 0U {
    return true
  }
  let name = match section.custom_name {
    Some(v) => v
    None => ""
  }
  if config.keep_custom_sections.contains(name) {
    return true
  }
  if config.strip_all_custom {
    return false
  }
  if config.strip_name_section && name == "name" {
    return false
  }
  if config.strip_producers_section && name == "producers" {
    return false
  }
  if config.strip_target_features_section && name == "target_features" {
    return false
  }
  if config.strip_dwarf_sections && is_dwarf_custom_section_name(name) {
    return false
  }
  if config.strip_debug_sections && is_debug_custom_section_name(name) {
    return false
  }
  true
}

///|
fn should_optimize_code_section(config : OptimizeConfig) -> Bool {
  config.enable_peephole ||
  config.enable_vacuum ||
  config.enable_merge_blocks ||
  config.enable_remove_unused_brs
}

///|
fn should_remove_unused_types(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_refine_types(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_signature_prune(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions
}

///|
fn should_duplicate_import_eliminate(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_simplify_globals(config : OptimizeConfig) -> Bool {
  should_optimize_code_section(config) ||
  config.enable_dce ||
  config.enable_remove_unused_module_elements
}

///|
fn should_reorder_globals(config : OptimizeConfig) -> Bool {
  config.enable_dce || config.enable_remove_unused_module_elements
}

///|
fn should_memory_pack(config : OptimizeConfig) -> Bool {
  config.enable_dce || config.enable_remove_unused_module_elements
}

///|
fn custom_strip_pass_requested(config : OptimizeConfig) -> Bool {
  config.strip_all_custom ||
  config.strip_name_section ||
  config.strip_producers_section ||
  config.strip_target_features_section ||
  config.strip_dwarf_sections ||
  config.strip_debug_sections
}

///|
fn any_optimization_pass_requested(config : OptimizeConfig) -> Bool {
  custom_strip_pass_requested(config) ||
  should_optimize_code_section(config) ||
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements ||
  should_refine_types(config) ||
  should_signature_prune(config) ||
  should_remove_unused_types(config)
}

///|
fn push_reason(reasons : Array[String], reason : String) -> Unit {
  if not(reasons.contains(reason)) {
    reasons.push(reason)
  }
}

///|
fn collect_optimize_no_change_reasons(
  before : Bytes,
  after : Bytes,
  config : OptimizeConfig,
) -> Array[String] {
  let reasons : Array[String] = []
  if before.length() != after.length() {
    return reasons
  }
  if not(bytes_equal(before, after)) {
    reasons.push("size-neutral rewrite only (bytes changed but size unchanged)")
    return reasons
  }
  if not(any_optimization_pass_requested(config)) {
    reasons.push("no optimization pass is enabled in config")
    return reasons
  }
  let sections_result = try? parse_core_sections_raise(before)
  match sections_result {
    Ok(sections) => {
      if custom_strip_pass_requested(config) {
        let mut has_custom_section = false
        let mut has_removable_custom_section = false
        for section in sections {
          if section.section_id == 0U {
            has_custom_section = true
            if not(keep_custom_section(section, config)) {
              has_removable_custom_section = true
            }
          }
        }
        if not(has_custom_section) {
          push_reason(reasons, "no custom section exists for strip passes")
        } else if not(has_removable_custom_section) {
          push_reason(
            reasons, "configured custom-section strip targets were not present",
          )
        }
      }
      if should_optimize_code_section(config) {
        if not(sections.any(s => s.section_id == 10U)) {
          push_reason(reasons, "no code section exists for code-level passes")
        } else {
          push_reason(
            reasons, "code-level passes found no reducible instruction patterns",
          )
        }
      }
    }
    Err(_) =>
      push_reason(
        reasons, "unable to inspect section layout for no-change diagnostics",
      )
  }
  if config.enable_dce {
    match analyze_dce_report(before) {
      Ok(report) =>
        if report.partial {
          push_reason(reasons, "dce skipped: partial call graph")
        } else if report.removable_function_count == 0U {
          push_reason(reasons, "dce found no removable functions")
        }
      Err(_) => push_reason(reasons, "dce analysis failed")
    }
  }
  if reasons.length() == 0 {
    reasons.push("module is already optimized for active passes")
  }
  reasons
}

///|
priv struct OptimizeRoundResult {
  bytes : Bytes
  removed_sections : Array[String]
}

///|
fn optimize_for_size_round_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> OptimizeRoundResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let stage1_out : Array[Byte] = bytes[0:8].to_array()
  let removed_sections : Array[String] = []
  for section in sections {
    if section.section_id == 0U && not(keep_custom_section(section, config)) {
      removed_sections.push(section_key(section, false))
    } else if section.section_id == 10U && should_optimize_code_section(config) {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      let optimized_payload = optimize_code_section_payload(payload, config)
      append_encoded_section(stage1_out, section.section_id, optimized_payload)
    } else {
      stage1_out.append(
        bytes[section.section_start:section.section_end].to_array(),
      )
    }
  }
  let mut optimized_bytes = Bytes::from_array(stage1_out[:])
  if config.enable_peephole {
    let coalesce = apply_coalesce_locals_raise(optimized_bytes)
    optimized_bytes = coalesce.bytes
    if coalesce.removed_local_count > 0U {
      removed_sections.push(
        "coalesce-locals:removed:" + coalesce.removed_local_count.to_string(),
      )
    }
  }
  if should_duplicate_import_eliminate(config) {
    let duplicate_import_elim = apply_duplicate_import_elimination(
      optimized_bytes,
    )
    optimized_bytes = duplicate_import_elim.bytes
    if duplicate_import_elim.removed_import_count > 0U {
      removed_sections.push(
        "dup-imports:imports:" +
        duplicate_import_elim.removed_import_count.to_string() +
        " funcs:" +
        duplicate_import_elim.removed_function_import_count.to_string() +
        " tables:" +
        duplicate_import_elim.removed_table_import_count.to_string() +
        " memories:" +
        duplicate_import_elim.removed_memory_import_count.to_string() +
        " globals:" +
        duplicate_import_elim.removed_global_import_count.to_string(),
      )
    }
    if duplicate_import_elim.dropped_name_section {
      removed_sections.push("custom:name(dup-imports)")
    }
  }
  if config.enable_dce {
    let dce_cluster_before = optimized_bytes
    let dce_cluster_removed_sections : Array[String] = []
    let directize = apply_directize_raise(optimized_bytes)
    optimized_bytes = directize.bytes
    if directize.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "directize:calls:" + directize.rewritten_call_count.to_string(),
      )
    }
    let cfp_const = apply_const_call_forwarding_propagation_raise(
      optimized_bytes,
    )
    optimized_bytes = cfp_const.bytes
    if cfp_const.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "cfp-const:calls:" + cfp_const.rewritten_call_count.to_string(),
      )
    }
    let cfp = apply_call_forwarding_propagation_raise(optimized_bytes)
    optimized_bytes = cfp.bytes
    if cfp.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "cfp:calls:" + cfp.rewritten_call_count.to_string(),
      )
    }
    let signature_refine = apply_signature_refining_raise(optimized_bytes)
    optimized_bytes = signature_refine.bytes
    if signature_refine.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "signature-refine:calls:" +
        signature_refine.rewritten_call_count.to_string(),
      )
    }
    let dce = apply_dce_raise(optimized_bytes, config)
    optimized_bytes = dce.bytes
    if dce.removed_function_count > 0U {
      dce_cluster_removed_sections.push(
        "dce:functions:" +
        dce.removed_function_count.to_string() +
        " bodies:" +
        dce.removed_body_bytes.to_string(),
      )
    }
    if dce.dropped_name_section {
      dce_cluster_removed_sections.push("custom:name(dce)")
    }
    let dce_cluster_before_size = dce_cluster_before
      .length()
      .reinterpret_as_uint()
    let dce_cluster_after_size = optimized_bytes.length().reinterpret_as_uint()
    if dce_cluster_after_size > dce_cluster_before_size {
      optimized_bytes = dce_cluster_before
      removed_sections.push(
        "dce-cluster:rollback:size-regress:" +
        dce_cluster_before_size.to_string() +
        "->" +
        dce_cluster_after_size.to_string(),
      )
    } else {
      removed_sections.append(dce_cluster_removed_sections[:])
    }
  }
  if should_refine_types(config) {
    let type_refine = apply_type_refining(optimized_bytes)
    optimized_bytes = type_refine.bytes
    if type_refine.refined_type_count > 0U {
      removed_sections.push(
        "type-refine:types:" + type_refine.refined_type_count.to_string(),
      )
    }
  }
  if should_signature_prune(config) {
    let signature_prune = apply_signature_pruning(optimized_bytes)
    optimized_bytes = signature_prune.bytes
    if signature_prune.pruned_function_count > 0U {
      removed_sections.push(
        "signature-prune:functions:" +
        signature_prune.pruned_function_count.to_string() +
        " params:" +
        signature_prune.pruned_param_count.to_string(),
      )
    }
  }
  if config.enable_dfe {
    let dfe = apply_dfe_raise(optimized_bytes)
    optimized_bytes = dfe.bytes
    if dfe.removed_function_count > 0U {
      removed_sections.push(
        "dfe:functions:" +
        dfe.removed_function_count.to_string() +
        " bodies:" +
        dfe.removed_body_bytes.to_string(),
      )
    }
    if dfe.dropped_name_section {
      removed_sections.push("custom:name(dfe)")
    }
  }
  if config.enable_merge_similar_functions {
    let msf = apply_merge_similar_functions_raise(optimized_bytes)
    optimized_bytes = msf.bytes
    if msf.removed_function_count > 0U {
      removed_sections.push(
        "msf:functions:" +
        msf.removed_function_count.to_string() +
        " bodies:" +
        msf.removed_body_bytes.to_string(),
      )
    }
    if msf.dropped_name_section {
      removed_sections.push("custom:name(msf)")
    }
  }
  if config.enable_remove_unused_module_elements {
    let rume = apply_remove_unused_module_elements(optimized_bytes, config)
    optimized_bytes = rume.bytes
    if rume.removed_import_count > 0U ||
      rume.removed_table_count > 0U ||
      rume.removed_memory_count > 0U ||
      rume.removed_global_count > 0U ||
      rume.removed_element_count > 0U ||
      rume.removed_data_count > 0U ||
      rume.removed_export_count > 0U {
      removed_sections.push(
        "rume:imports:" +
        rume.removed_import_count.to_string() +
        " tables:" +
        rume.removed_table_count.to_string() +
        " memories:" +
        rume.removed_memory_count.to_string() +
        " globals:" +
        rume.removed_global_count.to_string() +
        " elements:" +
        rume.removed_element_count.to_string() +
        " data:" +
        rume.removed_data_count.to_string() +
        " exports:" +
        rume.removed_export_count.to_string(),
      )
    }
  }
  if should_simplify_globals(config) {
    let simplify_globals = apply_simplify_globals(optimized_bytes)
    optimized_bytes = simplify_globals.bytes
    if simplify_globals.rewritten_global_get_count > 0U {
      removed_sections.push(
        "simplify-globals:gets:" +
        simplify_globals.rewritten_global_get_count.to_string(),
      )
    }
  }
  if should_reorder_globals(config) {
    let reorder_globals = apply_reorder_globals(optimized_bytes)
    optimized_bytes = reorder_globals.bytes
    if reorder_globals.reordered_local_count > 0U {
      removed_sections.push(
        "reorder-globals:locals:" +
        reorder_globals.reordered_local_count.to_string(),
      )
    }
  }
  if should_memory_pack(config) {
    let memory_pack = apply_memory_packing(optimized_bytes)
    optimized_bytes = memory_pack.bytes
    if memory_pack.reordered_local_count > 0U {
      removed_sections.push(
        "memory-packing:locals:" + memory_pack.reordered_local_count.to_string(),
      )
    }
  }
  if should_remove_unused_types(config) {
    let remove_unused_types = apply_remove_unused_types(optimized_bytes)
    optimized_bytes = remove_unused_types.bytes
    if remove_unused_types.removed_type_count > 0U {
      removed_sections.push(
        "types:" + remove_unused_types.removed_type_count.to_string(),
      )
    }
  }
  if config.enable_dce {
    let inlining = apply_inlining_optimizing(optimized_bytes)
    optimized_bytes = inlining.bytes
    if inlining.inlined_call_count > 0U {
      removed_sections.push(
        "inlining:calls:" + inlining.inlined_call_count.to_string(),
      )
    }
    let dae = apply_dae_optimizing(optimized_bytes)
    optimized_bytes = dae.bytes
    if dae.removed_instr_count > 0U {
      removed_sections.push("dae:instrs:" + dae.removed_instr_count.to_string())
    }
  }
  { bytes: optimized_bytes, removed_sections }
}

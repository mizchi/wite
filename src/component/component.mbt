///|
pub fn read_bytes_or_exit(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    e => {
      println("failed to read file: " + path + " (" + e.to_string() + ")")
      @sys.exit(1)
      b""
    }
  }
}

///|
pub fn verify_component_interface(
  component_bytes : Bytes,
  wit_path : String,
  world? : String,
) -> Result[Unit, String] {
  let resolved = match world {
    Some(world_name) =>
      match @wit.resolve_path(wit_path, world=world_name) {
        Ok(v) => v
        Err(e) => return Err("wit resolve failed: " + e.to_string())
      }
    None =>
      match @wit.resolve_path(wit_path) {
        Ok(v) => v
        Err(e) => return Err("wit resolve failed: " + e.to_string())
      }
  }
  match @mwac_component.check_component_targets(component_bytes, resolved) {
    Ok(_) => Ok(())
    Err(msg) => Err("interface verify failed: " + msg)
  }
}

///|
fn print_section_sizes(sections : Array[@wite.SectionSize]) -> Unit {
  for section in sections {
    println(
      "  " + section.key + ": " + section.total_bytes.to_string() + " bytes",
    )
  }
}

///|
fn print_function_sizes(
  functions : Array[@wite.FunctionSize],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for fn_size in functions {
    if printed >= limit {
      break
    }
    let label = match fn_size.name {
      Some(name) => name
      None => "#\{fn_size.function_index.to_string()}"
    }
    let exports = match fn_size.export_names {
      [] => ""
      [_, ..] => " exports=" + fn_size.export_names.join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      fn_size.function_index.to_string() +
      " body=" +
      fn_size.body_bytes.to_string() +
      exports,
    )
    printed += 1U
  }
}

///|
fn print_call_graph_nodes(
  nodes : Array[@wite.CallGraphNode],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for node in nodes {
    if printed >= limit {
      break
    }
    let label = match node.name {
      Some(name) => name
      None => "#\{node.function_index.to_string()}"
    }
    let status = if node.reachable_from_roots { "reachable" } else { "dead" }
    let export_part = match node.export_names {
      [] => ""
      [_, ..] => " exports=" + node.export_names.join(",")
    }
    let callee_part = match node.direct_callees {
      [] => ""
      [_, ..] =>
        " callees=" + node.direct_callees.map(i => i.to_string()).join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      node.function_index.to_string() +
      " body=" +
      node.body_bytes.to_string() +
      " " +
      status +
      export_part +
      callee_part,
    )
    printed += 1U
  }
}

///|
pub fn run_component_profile(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.profile_component(bytes) {
    Ok(profile) => {
      println("component profile:")
      println("  total_bytes: " + profile.total_bytes.to_string())
      println("  import_count: " + profile.import_count.to_string())
      println("  export_count: " + profile.export_count.to_string())
      println("  core_module_count: " + profile.core_module_count.to_string())
      println(
        "  nested_component_count: " +
        profile.nested_component_count.to_string(),
      )
      println("  sections:")
      print_section_sizes(profile.sections)
      println("  core modules:")
      for i in 0..<profile.core_modules.length() {
        let core = profile.core_modules[i]
        println(
          "    #" +
          i.to_string() +
          " total=" +
          core.total_bytes.to_string() +
          " funcs=" +
          core.function_count.to_string() +
          " code=" +
          core.code_body_bytes.to_string(),
        )
      }
    }
    Err(msg) => {
      println("component profile failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
pub fn run_component_top_functions(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_component_function_sizes(bytes) {
    Ok(reports) => {
      println("component top functions:")
      println("  core_modules: " + reports.length().to_string())
      for report in reports {
        println(
          "  core module #" +
          report.module_index.to_string() +
          " function_count=" +
          report.function_count.to_string() +
          " total_body_bytes=" +
          report.total_body_bytes.to_string(),
        )
        print_function_sizes(report.functions, limit)
      }
    }
    Err(msg) => {
      println("component-top-functions failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
pub fn run_component_callgraph(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_component_call_graphs(bytes) {
    Ok(reports) => {
      println("component call graph:")
      println("  core_modules: " + reports.length().to_string())
      for report in reports {
        println("  core module #" + report.module_index.to_string())
        println(
          "    functions: imported=" +
          report.graph.imported_function_count.to_string() +
          " local=" +
          report.graph.local_function_count.to_string(),
        )
        println(
          "    reachable_body_bytes=" +
          report.graph.reachable_body_bytes.to_string() +
          " dead_body_bytes=" +
          report.graph.dead_body_bytes.to_string(),
        )
        println("    partial=" + report.graph.partial.to_string())
        print_call_graph_nodes(report.graph.nodes, limit)
      }
    }
    Err(msg) => {
      println("component-callgraph failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
pub fn run_component_dce_kpi_with_options(
  component_path : String,
  wit_path : String?,
  excludes : Array[String],
  closed_world_root_exports : Array[String],
  safe_mode : Bool,
  verbose : Bool,
) -> Unit {
  let bytes = read_bytes_or_exit(component_path)
  let resolved_wit : @wit.ResolveInput? = wit_path.bind(path => {
    match @wit.resolve_path(path) {
      Ok(v) => Some(v)
      Err(e) => {
        println("wit resolve failed: " + e.to_string())
        @sys.exit(1)
        None
      }
    }
  })
  let policy_result = match resolved_wit {
    Some(resolved) =>
      @wite.analyze_component_root_policy(
        bytes,
        resolved_wit=resolved,
        exclude=excludes,
      )
    None => @wite.analyze_component_root_policy(bytes, exclude=excludes)
  }
  let policy = match policy_result {
    Ok(v) => v
    Err(msg) => {
      println("component-dce-kpi root policy failed: " + msg)
      @sys.exit(1)
      return
    }
  }
  let roots = policy.root_name_candidates.copy()
  roots.append(closed_world_root_exports[:])
  roots.sort()
  roots.dedup()
  let config = @wite.make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=true,
    closed_world=true,
    closed_world_root_exports=roots,
    safe_mode~,
  )
  match @wite.analyze_component_core_optimize(bytes, config~) {
    Ok(report) => {
      println("component dce kpi:")
      println(
        "  total_component_bytes: " + report.total_component_bytes.to_string(),
      )
      println("  core_module_count: " + report.core_module_count.to_string())
      println(
        "  total_core_before_bytes: " +
        report.total_core_before_bytes.to_string(),
      )
      println(
        "  total_core_after_bytes: " + report.total_core_after_bytes.to_string(),
      )
      println("  root_count: " + roots.length().to_string())
      println("  exclude_count: " + excludes.length().to_string())
      for entry in report.entries {
        println(
          "  core module #" +
          entry.module_index.to_string() +
          " " +
          entry.before_bytes.to_string() +
          " -> " +
          entry.after_bytes.to_string() +
          " bytes",
        )
        if verbose && entry.no_change_reasons.length() > 0 {
          println(
            "    no-change reasons: " + entry.no_change_reasons.join(", "),
          )
        }
      }
      println(
        "kpi-total-component-bytes=" + report.total_component_bytes.to_string(),
      )
      println(
        "kpi-total-core-before-bytes=" +
        report.total_core_before_bytes.to_string(),
      )
      println(
        "kpi-total-core-after-bytes=" +
        report.total_core_after_bytes.to_string(),
      )
      println("kpi-core-module-count=" + report.core_module_count.to_string())
      println("kpi-root-count=" + roots.length().to_string())
      println("kpi-exclude-count=" + excludes.length().to_string())
    }
    Err(msg) => {
      println("component-dce-kpi failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
pub fn run_contract(component_path : String, wit_path : String) -> Unit {
  let bytes = read_bytes_or_exit(component_path)
  match @wit.resolve_path(wit_path) {
    Ok(resolved) =>
      match @wite.analyze_component_contract(bytes, resolved) {
        Ok(report) => {
          println("component imports: " + report.component_imports.join(", "))
          println("component exports: " + report.component_exports.join(", "))
          println("wit imports: " + report.wit_imports.join(", "))
          println("wit exports: " + report.wit_exports.join(", "))
          println(
            "missing component imports: " +
            report.missing_component_imports.join(", "),
          )
          println(
            "missing component exports: " +
            report.missing_component_exports.join(", "),
          )
        }
        Err(msg) => {
          println("contract analyze failed: " + msg)
          @sys.exit(1)
        }
      }
    Err(e) => {
      println("wit resolve failed: " + e.to_string())
      @sys.exit(1)
    }
  }
}

///|
pub fn run_interface_with_options(
  component_path : String,
  wit_path : String?,
  world : String?,
  strict : Bool,
) -> Unit {
  let bytes = read_bytes_or_exit(component_path)
  let policy_result = match wit_path {
    Some(path) => {
      let resolved = match world {
        Some(world_name) =>
          match @wit.resolve_path(path, world=world_name) {
            Ok(v) => v
            Err(e) => {
              println("wit resolve failed: " + e.to_string())
              @sys.exit(1)
              return
            }
          }
        None =>
          match @wit.resolve_path(path) {
            Ok(v) => v
            Err(e) => {
              println("wit resolve failed: " + e.to_string())
              @sys.exit(1)
              return
            }
          }
      }
      @wite.analyze_component_root_policy(bytes, resolved_wit=resolved)
    }
    None => @wite.analyze_component_root_policy(bytes)
  }
  let policy = match policy_result {
    Ok(v) => v
    Err(msg) => {
      println("interface analyze failed: " + msg)
      @sys.exit(1)
      return
    }
  }
  println("component imports: " + policy.component_imports.join(", "))
  println("component exports: " + policy.component_exports.join(", "))
  if wit_path is Some(path) {
    println("wit imports: " + policy.wit_imports.join(", "))
    println("wit exports: " + policy.wit_exports.join(", "))
    let verify_result = match world {
      Some(world_name) =>
        verify_component_interface(bytes, path, world=world_name)
      None => verify_component_interface(bytes, path)
    }
    match verify_result {
      Ok(_) => println("interface verify: ok")
      Err(msg) => {
        println("interface verify: fail")
        println(msg)
        if strict {
          @sys.exit(1)
        }
      }
    }
  } else if strict {
    println("--strict requires [wit-dir]")
    @sys.exit(1)
  }
}

///|
pub fn run_root_policy_with_options(
  component_path : String,
  wit_path : String?,
  excludes : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(component_path)
  let resolved_wit : @wit.ResolveInput? = wit_path.bind(path => {
    match @wit.resolve_path(path) {
      Ok(v) => Some(v)
      Err(e) => {
        println("wit resolve failed: " + e.to_string())
        @sys.exit(1)
        None
      }
    }
  })
  let policy_result = match resolved_wit {
    Some(resolved) =>
      @wite.analyze_component_root_policy(
        bytes,
        resolved_wit=resolved,
        exclude=excludes,
      )
    None => @wite.analyze_component_root_policy(bytes, exclude=excludes)
  }
  match policy_result {
    Ok(policy) => {
      println("component imports: " + policy.component_imports.join(", "))
      println("component exports: " + policy.component_exports.join(", "))
      println("wit imports: " + policy.wit_imports.join(", "))
      println("wit exports: " + policy.wit_exports.join(", "))
      println("canonical abi roots: " + policy.canonical_abi_roots.join(", "))
      println("dce excludes: " + excludes.join(", "))
      println("root candidates: " + policy.root_name_candidates.join(", "))
    }
    Err(msg) => {
      println("root-policy analyze failed: " + msg)
      @sys.exit(1)
    }
  }
}

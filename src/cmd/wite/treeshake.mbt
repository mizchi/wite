///|
fn run_treeshake(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("usage: wite treeshake <input.wasm> [options]")
    println("")
    println("options:")
    println("  -o <output.wasm>     Output file (default: <input>.treeshake.wasm)")
    println("  --exports=a,b,c      Export names to keep (comma-separated)")
    println("  --kind=auto|core|component")
    println("  -Oz|-Os|-O1|-O2|-O3  Optimization level (default: -O1)")
    println("  --verbose            Show no-change reasons")
    @sys.exit(1)
  }
  let input_path = args[2]
  let mut output_path : String? = None
  let kept_exports : Array[String] = []
  let mut opt_level = "-O1"
  let mut kind = BinaryKind::Auto
  let mut verbose = false
  let mut i = 3
  while i < args.length() {
    let arg = args[i]
    if arg == "-o" {
      if i + 1 >= args.length() {
        println("missing output path after -o")
        @sys.exit(1)
      }
      output_path = Some(args[i + 1])
      i += 2
      continue
    }
    if arg.strip_prefix("--exports=") is Some(names) {
      for part in names.split(",") {
        let name = part.to_string()
        if !name.is_empty() {
          kept_exports.push(name)
        }
      }
      i += 1
      continue
    }
    if arg.strip_prefix("--kind=") is Some(value) {
      kind = parse_binary_kind_or_exit(value.to_string(), "treeshake kind")
      i += 1
      continue
    }
    if arg == "--verbose" {
      verbose = true
      i += 1
      continue
    }
    if arg.has_prefix("-O") {
      opt_level = arg
      i += 1
      continue
    }
    println("unknown treeshake option: " + arg)
    @sys.exit(1)
  }
  if kept_exports.length() == 0 {
    println("error: --exports is required")
    println("  example: wite treeshake app.wasm --exports=main,malloc,free")
    @sys.exit(1)
  }
  let out = match output_path {
    Some(p) => p
    None =>
      if input_path.has_suffix(".wasm") {
        input_path[:input_path.length() - 5].to_string() + ".treeshake.wasm"
      } else {
        input_path + ".treeshake.wasm"
      }
  }
  // Build config: closed-world with explicit root exports
  let base_config = match @wite_core.optimize_config_from_opt_level(
    normalize_opt_level_token(opt_level),
  ) {
    Some(c) => c
    None => {
      println("invalid optimization level: " + opt_level)
      @sys.exit(1)
      @wite_core.OptimizeConfig::o1()
    }
  }
  let config = @wite_core.make_optimize_config(
    strip_all_custom=base_config.strip_all_custom,
    strip_name_section=base_config.strip_name_section,
    strip_producers_section=base_config.strip_producers_section,
    strip_debug_sections=base_config.strip_debug_sections,
    strip_dwarf_sections=base_config.strip_dwarf_sections,
    strip_target_features_section=base_config.strip_target_features_section,
    pass_rounds=base_config.pass_rounds,
    enable_peephole=base_config.enable_peephole,
    peephole_remove_nop=base_config.peephole_remove_nop,
    peephole_remove_const_drop=base_config.peephole_remove_const_drop,
    enable_vacuum=base_config.enable_vacuum,
    enable_merge_blocks=base_config.enable_merge_blocks,
    enable_remove_unused_brs=base_config.enable_remove_unused_brs,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=base_config.enable_merge_similar_functions,
    enable_remove_unused_module_elements=true,
    closed_world=true,
    closed_world_root_exports=kept_exports,
  )
  let bytes = read_bytes_or_exit(input_path)
  match optimize_with_kind(bytes, kind, config, []) {
    Ok(result) => {
      write_output_or_exit(out, result.bytes)
      println(
        "treeshake: " +
        result.before_size.to_string() +
        " -> " +
        result.after_size.to_string() +
        " bytes",
      )
      let saved = if result.before_size > result.after_size {
        result.before_size - result.after_size
      } else {
        0U
      }
      if saved > 0U {
        println("  removed: " + saved.to_string() + " bytes")
      }
      if result.removed_sections.length() > 0 {
        println("  passes: " + result.removed_sections.join(", "))
      }
      if verbose && result.no_change_reasons.length() > 0 {
        println("  no-change: " + result.no_change_reasons.join(", "))
      }
      println("  kept exports: " + kept_exports.join(", "))
      println("  output: " + out)
    }
    Err(msg) => {
      println("treeshake failed: " + msg)
      @sys.exit(1)
    }
  }
}

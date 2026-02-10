///|
fn write_output_or_exit(output_path : String, bytes : Bytes) -> Unit {
  js_ensure_parent_dir_for_file(output_path)
  @fs.write_bytes_to_file(output_path, bytes) catch {
    e => {
      println(
        "failed to write file: " + output_path + " (" + e.to_string() + ")",
      )
      @sys.exit(1)
    }
  }
}

///|
fn run_optimize(args : Array[String]) -> Unit {
  if args.length() < 4 {
    print_usage()
    @sys.exit(1)
  }
  let input_path = args[2]
  let output_path = args[3]
  let flags : Array[String] = []
  for i in 4..<args.length() {
    flags.push(args[i])
  }
  let kind_flags = extract_binary_kind_flags(
    flags,
    BinaryKind::Auto,
    "optimize kind",
  )
  let options = parse_optimize_cli_options(kind_flags.flags)
  let bytes = read_bytes_or_exit(input_path)
  match
    optimize_with_kind(
      bytes,
      kind_flags.kind,
      options.config,
      options.excluded_roots,
    ) {
    Ok(result) => {
      write_output_or_exit(output_path, result.bytes)
      println(
        "optimized: " +
        result.before_size.to_string() +
        " -> " +
        result.after_size.to_string() +
        " bytes",
      )
      if result.removed_sections.length() > 0 {
        println("removed sections: " + result.removed_sections.join(", "))
      }
      if options.verbose && result.no_change_reasons.length() > 0 {
        println("no-change reasons: " + result.no_change_reasons.join(", "))
      }
      println("kind: " + binary_kind_name(kind_flags.kind))
    }
    Err(msg) => {
      println("optimize failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn to_optimize_kind(kind : BinaryKind) -> @wite_optimize.OptimizeKind {
  match kind {
    BinaryKind::Auto => @wite_optimize.optimize_kind_auto()
    BinaryKind::Core => @wite_optimize.optimize_kind_core()
    BinaryKind::Component => @wite_optimize.optimize_kind_component()
  }
}

///|
fn optimize_with_kind(
  bytes : Bytes,
  kind : BinaryKind,
  config : @wite.OptimizeConfig,
  excluded_roots : Array[String],
) -> Result[@wite.OptimizeResult, String] {
  @wite_optimize.optimize_with_kind(
    bytes,
    to_optimize_kind(kind),
    config,
    exclude=excluded_roots,
  )
}

///|
async fn run_build(args : Array[String]) -> Unit {
  let default_input = pick_default_build_input_path(
    @fs.path_exists("main.wac"),
    @fs.path_exists("main.wasm"),
  )
  let resolved = match resolve_build_input_from_args(args, default_input) {
    Ok(value) => value
    Err(_) => {
      // defer error until after config check — config.input may resolve it
      // extract flags from args[2:] (skipping "wite" "build")
      let fallback_flags : Array[String] = []
      for i in 2..<args.length() {
        fallback_flags.push(args[i])
      }
      { input_path: "", raw_flags: fallback_flags, explicit_input: false }
    }
  }
  let raw_flags = resolved.raw_flags
  let config_selection = @wite_config.parse_config_selection_flags(raw_flags)
  let config_file = @wite_config.resolve_wite_config_or_default(
    config_selection,
  )
  // Resolve input: CLI > config.input > filesystem default
  let config_dir = path_dirname(config_selection.config_path)
  let input_path = if resolved.explicit_input {
    resolved.input_path
  } else {
    match @wite_config.config_input_single_path(config_file.input) {
      Some(config_input) =>
        resolve_path_from_config_dir(config_dir, config_input)
      None =>
        if default_input is Some(_) {
          resolved.input_path
        } else {
          println(
            "build requires entry.(wac|wasm), config input, or main.wac/main.wasm in cwd",
          )
          print_usage()
          @sys.exit(1)
          ""
        }
    }
  }
  let has_config_input = not(
    config_file.input is @wite_config.ConfigInput::None,
  )
  let is_wac_input = input_path.has_suffix(".wac")
  if not(is_wac_input) {
    auto_sync_deps_from_config_if_needed(config_selection)
  }
  let merged_flags = @wite_config.merge_command_flags(
    config_file.build_flags,
    config_selection.remaining_flags,
  )
  let mut output_path : String? = None
  let mut best_effort = false
  let mut compose_dce = true
  let mut kind = from_config_binary_kind(config_file.build_kind)
  let optimize_flags : Array[String] = []
  let mut i = 0
  while i < merged_flags.length() {
    let arg = merged_flags[i]
    if arg == "-o" || arg == "--out" {
      if i + 1 >= merged_flags.length() {
        println("missing output path after " + arg)
        @sys.exit(1)
      }
      output_path = Some(merged_flags[i + 1])
      i += 2
      continue
    }
    match arg.strip_prefix("--out=") {
      Some(path) => {
        output_path = Some(path.to_string())
        i += 1
        continue
      }
      None => ()
    }
    if arg == "--best-effort" {
      best_effort = true
      i += 1
      continue
    }
    if arg == "--no-compose-dce" {
      compose_dce = false
      i += 1
      continue
    }
    if arg == "--kind" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(merged_flags[i + 1], "build kind")
      i += 2
      continue
    }
    match arg.strip_prefix("--kind=") {
      Some(value) => {
        kind = parse_binary_kind_or_exit(value.to_string(), "build kind")
        i += 1
        continue
      }
      None => ()
    }
    optimize_flags.push(arg)
    i += 1
  }
  let out = match output_path {
    Some(path) => path
    None =>
      if has_config_input {
        // config に input がある場合: config_dir/output.dir + basename
        let basename = derive_build_output_path(path_basename(input_path))
        let output_dir = resolve_path_from_config_dir(
          config_dir,
          config_file.output.dir,
        )
        output_dir + "/" + basename
      } else if resolved.explicit_input {
        derive_build_output_path(input_path)
      } else {
        derive_implicit_build_output_path(input_path)
      }
  }
  if is_wac_input &&
    config_selection.use_config &&
    @fs.path_exists(config_selection.config_path) {
    match
      @wite_deps.materialize_wac_dependencies_from_config(
        config_selection.config_path,
        input_path,
        best_effort,
      ) {
      Ok(synced) =>
        if synced > 0U {
          println("materialized wac deps: " + synced.to_string() + " entries")
        }
      Err(msg) => {
        println("build failed: " + msg)
        @sys.exit(1)
      }
    }
  }
  let built = if is_wac_input {
    match
      @wite_bundle.compose_wac_file(input_path, best_effort~, dce=compose_dce) {
      Ok(bytes) => bytes
      Err(msg) => {
        println("build failed: " + msg)
        @sys.exit(1)
        b""
      }
    }
  } else {
    read_bytes_or_exit(input_path)
  }
  let options = parse_optimize_cli_options(optimize_flags)
  match
    optimize_with_kind(built, kind, options.config, options.excluded_roots) {
    Ok(result) => {
      write_output_or_exit(out, result.bytes)
      println(
        "built: " +
        result.before_size.to_string() +
        " -> " +
        result.after_size.to_string() +
        " bytes",
      )
      if result.removed_sections.length() > 0 {
        println("removed sections: " + result.removed_sections.join(", "))
      }
      if options.verbose && result.no_change_reasons.length() > 0 {
        println("no-change reasons: " + result.no_change_reasons.join(", "))
      }
      println("kind: " + binary_kind_name(kind))
      println("output: " + out)
    }
    Err(msg) => {
      println("build failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|

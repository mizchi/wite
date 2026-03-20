///|
fn replace_suffix(text : String, from : String, to : String) -> String {
  if !text.has_suffix(from) {
    return text + to
  }
  let prefix = text[:text.length() - from.length()].to_string()
  prefix + to
}

///|
fn derive_build_output_path(input_path : String) -> String {
  if input_path.has_suffix(".wac") {
    replace_suffix(input_path, ".wac", ".wasm")
  } else if input_path.has_suffix(".wasm") {
    replace_suffix(input_path, ".wasm", ".min.wasm")
  } else {
    input_path + ".wasm"
  }
}

///|
fn derive_implicit_build_output_path(input_path : String) -> String {
  if input_path == "main.wac" {
    "composed.wasm"
  } else {
    derive_build_output_path(input_path)
  }
}

///|
fn path_basename(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => path[index + 1:].to_string()
    None => path
  }
}

///|
fn path_dirname(path : String) -> String {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let index = match (slash, backslash) {
    (Some(a), Some(b)) => if a >= b { Some(a) } else { Some(b) }
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  match index {
    Some(i) =>
      if i == 0 {
        if path.has_prefix("\\") {
          "\\"
        } else {
          "/"
        }
      } else {
        path[:i].to_string()
      }
    None => "."
  }
}

///|
fn is_absolute_path(path : String) -> Bool {
  if path.has_prefix("/") || path.has_prefix("\\") {
    return true
  }
  match path.find(":") {
    Some(i) if i == 1 && path.length() >= 3 => {
      let sep = path[2:3].to_string()
      sep == "/" || sep == "\\"
    }
    _ => false
  }
}

///|
fn resolve_path_from_config_dir(config_dir : String, path : String) -> String {
  if config_dir == "." || config_dir.is_empty() || is_absolute_path(path) {
    return path
  }
  if config_dir == "/" || config_dir == "\\" {
    return config_dir + path
  }
  config_dir + "/" + path
}

///|
priv struct BuildInputResolution {
  input_path : String
  raw_flags : Array[String]
  explicit_input : Bool
}

///|
priv struct BuildFlagParseResult {
  output_path : String?
  best_effort : Bool
  compose_dce : Bool
  kind : BinaryKind
  optimize_flags : Array[String]
  interface_path : String?
  interface_world : String?
}

///|
fn pick_default_build_input_path(
  has_main_wac : Bool,
  has_main_wasm : Bool,
) -> String? {
  if has_main_wac {
    Some("main.wac")
  } else if has_main_wasm {
    Some("main.wasm")
  } else {
    None
  }
}

///|
fn resolve_build_input_from_args(
  args : Array[String],
  default_input : String?,
) -> Result[BuildInputResolution, String] {
  if args.length() < 3 {
    return match default_input {
      Some(input_path) =>
        Ok({ input_path, raw_flags: [], explicit_input: false })
      None =>
        Err("build requires entry.(wac|wasm) or main.wac/main.wasm in cwd")
    }
  }
  let token = args[2]
  if token.has_prefix("-") {
    return match default_input {
      Some(input_path) => {
        let raw_flags : Array[String] = []
        for i in 2..<args.length() {
          raw_flags.push(args[i])
        }
        Ok({ input_path, raw_flags, explicit_input: false })
      }
      None =>
        Err("build requires entry.(wac|wasm) or main.wac/main.wasm in cwd")
    }
  }
  let raw_flags : Array[String] = []
  for i in 3..<args.length() {
    raw_flags.push(args[i])
  }
  Ok({ input_path: token, raw_flags, explicit_input: true })
}

///|
fn parse_build_flags(
  merged_flags : Array[String],
  default_kind : BinaryKind,
) -> BuildFlagParseResult {
  let mut output_path : String? = None
  let mut best_effort = false
  let mut compose_dce = true
  let mut kind = default_kind
  let mut interface_path : String? = None
  let mut interface_world : String? = None
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
    if arg.strip_prefix("--out=") is Some(path) {
      output_path = Some(path.to_string())
      i += 1
      continue
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
    if arg.strip_prefix("--kind=") is Some(value) {
      kind = parse_binary_kind_or_exit(value.to_string(), "build kind")
      i += 1
      continue
    }
    if arg == "--interface" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --interface")
        @sys.exit(1)
      }
      interface_path = Some(merged_flags[i + 1])
      i += 2
      continue
    }
    if arg.strip_prefix("--interface=") is Some(value) {
      interface_path = Some(value.to_string())
      i += 1
      continue
    }
    if arg == "--world" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --world")
        @sys.exit(1)
      }
      interface_world = Some(merged_flags[i + 1])
      i += 2
      continue
    }
    if arg.strip_prefix("--world=") is Some(value) {
      interface_world = Some(value.to_string())
      i += 1
      continue
    }
    optimize_flags.push(arg)
    i += 1
  }
  if interface_world is Some(_) && interface_path is None {
    println("--world requires --interface")
    @sys.exit(1)
  }
  {
    output_path,
    best_effort,
    compose_dce,
    kind,
    optimize_flags,
    interface_path,
    interface_world,
  }
}

///|
fn is_component_wasm(bytes : Bytes) -> Bool {
  bytes.length() >= 8 &&
  bytes[0] == 0x00 &&
  bytes[1] == 0x61 &&
  bytes[2] == 0x73 &&
  bytes[3] == 0x6d &&
  bytes[4] == 0x0d &&
  bytes[5] == 0x00 &&
  bytes[6] == 0x01 &&
  bytes[7] == 0x00
}

///|
fn build_single_entry(
  input_path : String,
  out : String,
  parsed_flags : BuildFlagParseResult,
) -> Unit {
  let is_wac_input = input_path.has_suffix(".wac")
  let built = if is_wac_input {
    match
      @wite_bundle.compose_wac_file(
        input_path,
        best_effort=parsed_flags.best_effort,
        dce=parsed_flags.compose_dce,
      ) {
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
  let options = parse_optimize_cli_options(parsed_flags.optimize_flags)
  match
    optimize_with_kind(
      built,
      parsed_flags.kind,
      options.config,
      options.excluded_roots,
    ) {
    Ok(result) => {
      if parsed_flags.interface_path is Some(interface_path) {
        if !is_component_wasm(result.bytes) {
          println("build failed: --interface requires component output")
          @sys.exit(1)
        }
        let verify_result = match parsed_flags.interface_world {
          Some(world) =>
            @wite_component.verify_component_interface(
              result.bytes,
              interface_path,
              world~,
            )
          None =>
            @wite_component.verify_component_interface(
              result.bytes,
              interface_path,
            )
        }
        match verify_result {
          Ok(_) => {
            let world_suffix = match parsed_flags.interface_world {
              Some(world) => " world=" + world
              None => ""
            }
            println("interface verified: " + interface_path + world_suffix)
          }
          Err(msg) => {
            println("build failed: " + msg)
            @sys.exit(1)
          }
        }
      }
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
      println("kind: " + binary_kind_name(parsed_flags.kind))
      println("output: " + out)
    }
    Err(msg) => {
      println("build failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn materialize_wac_deps_if_needed(
  config_path : String,
  use_config : Bool,
  input_path : String,
  best_effort : Bool,
) -> Unit {
  if input_path.has_suffix(".wac") && use_config && @fs.path_exists(config_path) {
    match
      @wite_deps.materialize_wac_dependencies_from_config(
        config_path, input_path, best_effort,
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
}

///|
async fn run_chunk_build_command(
  chunk_name : String,
  chunk : @wite_config.ChunkConfig,
  config_dir : String,
) -> Unit {
  match chunk.build {
    None => {
      // No build command — output must already exist
      let output_path = resolve_path_from_config_dir(config_dir, chunk.output)
      if !@fs.path_exists(output_path) {
        println(
          "chunk '" +
          chunk_name +
          "' has no build command and output not found: " +
          output_path,
        )
        @sys.exit(1)
      }
    }
    Some(cmd) => {
      // Parse build command: first token is the command, rest are args
      let parts : Array[String] = []
      for part in cmd.split(" ") {
        let s = part.to_string()
        if !s.is_empty() {
          parts.push(s)
        }
      }
      if parts.length() == 0 {
        println("chunk '" + chunk_name + "' has empty build command")
        @sys.exit(1)
        return
      }
      let bin = parts[0]
      let args : Array[String] = []
      for i in 1..<parts.length() {
        args.push(parts[i])
      }
      println("chunk '" + chunk_name + "': " + cmd)
      let cwd : StringView? = if config_dir == "." {
        None
      } else {
        Some(config_dir)
      }
      let exit_code = @xprocess.run(bin, args[:], cwd?)
      if exit_code != 0 {
        println(
          "chunk '" +
          chunk_name +
          "' build failed (exit " +
          exit_code.to_string() +
          ")",
        )
        @sys.exit(1)
      }
    }
  }
}

///|
async fn componentize_chunk(
  chunk_name : String,
  chunk : @wite_config.ChunkConfig,
  config_dir : String,
) -> Unit {
  let wit_path = match chunk.wit {
    Some(path) => path
    None => return // Already a component or no WIT specified
  }
  let output_path = resolve_path_from_config_dir(config_dir, chunk.output)
  let bytes = read_bytes_or_exit(output_path)
  if is_component_wasm(bytes) {
    // Already a component, skip componentize
    return
  }
  // Run: wasm-tools component embed <wit> --output <tmp> <core.wasm>
  //      wasm-tools component new <tmp> -o <output>
  let resolved_wit = resolve_path_from_config_dir(config_dir, wit_path)
  let component_path = output_path + ".component.wasm"
  // Step 1: embed WIT
  let embed_args : Array[String] = [
    "component", "embed", resolved_wit, output_path, "--encoding", "utf8", "--output",
    component_path,
  ]
  match chunk.world {
    Some(world) => {
      embed_args.push("--world")
      embed_args.push(world)
    }
    None => ()
  }
  let (embed_exit, _, embed_stderr) = @xprocess.collect_output(
    "wasm-tools",
    embed_args[:],
  )
  if embed_exit != 0 {
    let err = embed_stderr.text() catch { _ => "" }
    println("chunk '" + chunk_name + "' embed failed: " + err)
    @sys.exit(1)
  }
  // Step 2: create component from embedded module
  let new_args : Array[String] = [
    "component", "new", component_path, "-o", output_path,
  ]
  let (new_exit, _, new_stderr) = @xprocess.collect_output(
    "wasm-tools",
    new_args[:],
  )
  if new_exit != 0 {
    let err = new_stderr.text() catch { _ => "" }
    println("chunk '" + chunk_name + "' componentize failed: " + err)
    @sys.exit(1)
  }
  // Cleanup intermediate file
  @fs.remove_file(component_path) catch {
    _ => ()
  }
  println("chunk '" + chunk_name + "': componentized (" + output_path + ")")
}

///|
fn get_file_size(path : String) -> Int {
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return 0 }
  bytes.length()
}

///|
fn chunk_needs_rebuild(
  chunk : @wite_config.ChunkConfig,
  config_dir : String,
) -> Bool {
  match chunk.build {
    None => true // No build command, always "ready" (just check existence)
    Some(_) => {
      let output_path = resolve_path_from_config_dir(config_dir, chunk.output)
      // If output doesn't exist, must rebuild
      !@fs.path_exists(output_path)
    }
  }
}

///|
async fn build_chunks(
  config_file : @wite_config.WiteConfigFile,
  config_dir : String,
) -> Unit {
  let chunk_names = @wite_config.chunk_names(config_file)
  if chunk_names.length() == 0 {
    return
  }
  for name in chunk_names {
    let chunk = config_file.chunks[name]
    let output_path = resolve_path_from_config_dir(config_dir, chunk.output)
    // Build step
    if chunk_needs_rebuild(chunk, config_dir) {
      run_chunk_build_command(name, chunk, config_dir)
    } else {
      println("chunk '" + name + "': up-to-date (" + output_path + ")")
      // Still need to componentize if WIT is specified
    }
    if !@fs.path_exists(output_path) {
      println(
        "chunk '" +
        name +
        "' build completed but output not found: " +
        output_path,
      )
      @sys.exit(1)
    }
    // Componentize step (core → component via WIT)
    componentize_chunk(name, chunk, config_dir)
    let size = get_file_size(output_path)
    println("chunk '" + name + "': ready (" + size.to_string() + " bytes)")
  }
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
  let config_selection = parse_config_selection_flags_or_exit(raw_flags)
  let config_file = resolve_config_or_default(config_selection)
  let config_dir = path_dirname(config_selection.config_path)
  // --all-envs: build all configured environments
  if config_selection.all_envs {
    let env_defs = @wite_config.resolve_all_environments(config_file)
    // Build chunks first (shared across environments)
    build_chunks(config_file, config_dir)
    for env_def in env_defs {
      println("=== environment: " + env_def.name + " ===")
      let env_flags = match env_def.optimize {
        Some(level) => [level]
        None => []
      }
      let merged = @wite_config.merge_command_flags(
        config_file.build_flags,
        @wite_config.merge_command_flags(
          env_flags,
          config_selection.remaining_flags,
        ),
      )
      let env_kind = from_config_binary_kind(env_def.kind)
      let parsed_flags = parse_build_flags(merged, env_kind)
      let input_path = match
        @wite_config.config_input_single_path(env_def.input) {
        Some(p) => resolve_path_from_config_dir(config_dir, p)
        None =>
          match default_input {
            Some(_) => resolved.input_path
            None => {
              println(
                "environment '" + env_def.name + "' has no input",
              )
              continue
            }
          }
      }
      let output_dir = resolve_path_from_config_dir(
        config_dir,
        env_def.output.dir,
      )
      let basename = input_path
        |> path_basename
        |> derive_build_output_path
      let out = output_dir + "/" + basename
      materialize_wac_deps_if_needed(
        config_selection.config_path,
        config_selection.use_config,
        input_path,
        parsed_flags.best_effort,
      )
      build_single_entry(input_path, out, parsed_flags)
    }
    return
  }
  // Resolve environment if --env is specified
  let resolved_env = match
    @wite_config.resolve_environment(config_file, config_selection.env_name) {
    Ok(env) => Some(env)
    Err(msg) => {
      if config_selection.env_name is Some(_) {
        println(msg)
        @sys.exit(1)
      }
      None
    }
  }
  let env_build_flags = match resolved_env {
    Some(env) =>
      match env.optimize {
        Some(level) => [level]
        None => []
      }
    None => []
  }
  let merged_flags = @wite_config.merge_command_flags(
    config_file.build_flags,
    @wite_config.merge_command_flags(
      env_build_flags,
      config_selection.remaining_flags,
    ),
  )
  let env_kind = match resolved_env {
    Some(env) => from_config_binary_kind(env.kind)
    None => from_config_binary_kind(config_file.build_kind)
  }
  let parsed_flags = parse_build_flags(merged_flags, env_kind)
  // Build chunks first (before compose)
  build_chunks(config_file, config_dir)
  // Effective input/output considering environment overrides
  let effective_input = match resolved_env {
    Some(env) =>
      match env.input {
        @wite_config.ConfigInput::None => config_file.input
        _ => env.input
      }
    None => config_file.input
  }
  let effective_output_dir = match resolved_env {
    Some(env) => env.output.dir
    None => config_file.output.dir
  }
  // Multi-entry: Named input with multiple entries and no explicit CLI input
  let entries = @wite_config.config_input_entries(effective_input)
  if entries.length() > 1 && !resolved.explicit_input {
    let output_dir = resolve_path_from_config_dir(
      config_dir, effective_output_dir,
    )
    // Materialize wac deps for all entries first
    for entry in entries {
      let (_, input_rel) = entry
      let entry_input = resolve_path_from_config_dir(config_dir, input_rel)
      materialize_wac_deps_if_needed(
        config_selection.config_path,
        config_selection.use_config,
        entry_input,
        parsed_flags.best_effort,
      )
    }
    // Build each entry
    for entry in entries {
      let (name, input_rel) = entry
      let entry_input = resolve_path_from_config_dir(config_dir, input_rel)
      let entry_output = output_dir + "/" + name + ".wasm"
      build_single_entry(entry_input, entry_output, parsed_flags)
    }
    return
  }
  // Single-entry path
  // Resolve input: CLI > env.input > config.input > filesystem default
  let input_path = if resolved.explicit_input {
    resolved.input_path
  } else {
    match @wite_config.config_input_single_path(effective_input) {
      Some(config_input) =>
        resolve_path_from_config_dir(config_dir, config_input)
      None =>
        match default_input {
          Some(_) => resolved.input_path
          None => {
            println(
              "build requires entry.(wac|wasm), config input, or main.wac/main.wasm in cwd",
            )
            print_usage()
            @sys.exit(1)
            ""
          }
        }
    }
  }
  let has_config_input = !(effective_input is @wite_config.ConfigInput::None)
  let is_wac_input = input_path.has_suffix(".wac")
  if !is_wac_input {
    auto_sync_deps_from_config_if_needed(config_selection)
  }
  let out = match parsed_flags.output_path {
    Some(path) => path
    None =>
      if has_config_input {
        let basename = input_path |> path_basename |> derive_build_output_path
        let output_dir = resolve_path_from_config_dir(
          config_dir, effective_output_dir,
        )
        output_dir + "/" + basename
      } else if resolved.explicit_input {
        derive_build_output_path(input_path)
      } else {
        derive_implicit_build_output_path(input_path)
      }
  }
  materialize_wac_deps_if_needed(
    config_selection.config_path,
    config_selection.use_config,
    input_path,
    parsed_flags.best_effort,
  )
  build_single_entry(input_path, out, parsed_flags)
}

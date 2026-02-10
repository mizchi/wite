///|
fn parse_wasm_opt_level_or_exit(token : String) -> String {
  let normalized = normalize_opt_level_token(token)
  match normalized {
    "-O" | "-O0" | "-O1" | "-O2" | "-O3" | "-O4" | "-Os" | "-Oz" => normalized
    _ => {
      println("invalid baseline-opt-level: " + token)
      @sys.exit(1)
      "-Oz"
    }
  }
}

///|
fn resolve_wasm_opt_bin(cli_value : String?) -> String {
  match cli_value {
    Some(path) => path
    None =>
      match @sys.get_env_var("WASM_OPT_BIN") {
        Some(path) => path
        None => "wasm-opt"
      }
  }
}

///|
fn run_wasm_opt_baseline_or_exit(
  input_path : String,
  output_path : String,
  wasm_opt_bin : String,
  baseline_opt_level : String,
  extra_args : Array[String],
) -> Unit {
  let args = [
    baseline_opt_level, "--all-features", "--strip-debug", "--strip-dwarf", "--strip-target-features",
  ]
  args.append(extra_args[:])
  let result = js_run_wasm_opt_cli(
    wasm_opt_bin,
    args.join("\t"),
    input_path,
    output_path,
  )
  let parts = split_string(result, "\t")
  if parts.length() == 0 || parts[0] != "ok" {
    let stage = if parts.length() >= 2 { parts[1] } else { "unknown" }
    let detail = if parts.length() >= 3 { parts[2] } else { result }
    println("wasm-opt baseline failed (" + stage + "): " + detail)
    @sys.exit(1)
  }
}

///|
fn parse_keep_custom(args : Array[String], start : Int) -> Array[String] {
  let keep : Array[String] = []
  for i in start..<args.length() {
    let arg = args[i]
    match arg.strip_prefix("--keep-custom=") {
      Some(name) => keep.push(name.to_string())
      None => ()
    }
  }
  keep
}

///|
fn parse_closed_world_roots(args : Array[String], start : Int) -> Array[String] {
  let roots : Array[String] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--closed-world-root=") {
      Some(name) => if not(name.is_empty()) { roots.push(name.to_string()) }
      None => ()
    }
  }
  roots
}

///|
fn parse_excluded_roots(args : Array[String], start : Int) -> Array[String] {
  let excludes : Array[String] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--exclude=") {
      Some(name) => if not(name.is_empty()) { excludes.push(name.to_string()) }
      None => ()
    }
  }
  excludes
}

///|
fn parse_uint_or_exit(text : String, name : String) -> UInt {
  if text.is_empty() {
    println("invalid " + name + ": empty string")
    @sys.exit(1)
    return 0U
  }
  let mut value = 0U
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      println("invalid " + name + ": " + text)
      @sys.exit(1)
      return 0U
    }
    value = value * 10U + (code - 48).reinterpret_as_uint()
  }
  value
}

///|
fn split_string(s : String, delim : String) -> Array[String] {
  let out : Array[String] = []
  for part in s.split(delim) {
    out.push(part.to_string())
  }
  out
}

///|
fn parse_int_or_exit(text : String, name : String) -> Int {
  if text.is_empty() {
    println("invalid " + name + ": empty string")
    @sys.exit(1)
    return 0
  }
  let mut negative = false
  let mut has_digit = false
  let mut value = 0
  let mut index = 0
  for ch in text {
    let code = ch.to_int()
    if index == 0 && code == 45 {
      negative = true
      index += 1
      continue
    }
    if code < 48 || code > 57 {
      println("invalid " + name + ": " + text)
      @sys.exit(1)
      return 0
    }
    value = value * 10 + (code - 48)
    has_digit = true
    index += 1
  }
  if not(has_digit) {
    println("invalid " + name + ": " + text)
    @sys.exit(1)
    return 0
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
fn parse_runtime_profile_scenarios(
  args : Array[String],
  start : Int,
) -> Array[@wite.RuntimeProfileScenario] {
  let scenarios : Array[@wite.RuntimeProfileScenario] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--scenario=") {
      Some(spec_text) => {
        let spec = spec_text.to_string()
        if spec.is_empty() {
          println("invalid scenario: empty spec")
          @sys.exit(1)
        }
        let parts = split_string(spec, ":")
        if parts.length() == 0 || parts[0].is_empty() {
          println("invalid scenario: " + spec)
          @sys.exit(1)
        }
        if parts.length() > 2 {
          println("invalid scenario format: " + spec)
          @sys.exit(1)
        }
        let export_name = parts[0]
        let scenario_args : Array[Int] = []
        if parts.length() == 2 && not(parts[1].is_empty()) {
          for raw_arg in split_string(parts[1], ",") {
            if raw_arg.is_empty() {
              continue
            }
            scenario_args.push(parse_int_or_exit(raw_arg, "scenario-arg"))
          }
        }
        scenarios.push(
          @wite.make_runtime_profile_scenario(export_name, args=scenario_args),
        )
      }
      None => ()
    }
  }
  scenarios
}

///|
priv struct OptimizeCliOptions {
  config : @wite.OptimizeConfig
  excluded_roots : Array[String]
  verbose : Bool
}

///|
fn parse_wasm_opt_optimize_level_or_exit(text : String) -> UInt {
  let value = parse_uint_or_exit(text, "optimize-level")
  if value > 4U {
    println("invalid optimize-level: " + text + " (expected 0..4)")
    @sys.exit(1)
  }
  value
}

///|
fn parse_wasm_opt_shrink_level_or_exit(text : String) -> UInt {
  let value = parse_uint_or_exit(text, "shrink-level")
  if value > 2U {
    println("invalid shrink-level: " + text + " (expected 0..2)")
    @sys.exit(1)
  }
  value
}

///|
fn wasm_opt_preset_from_optimize_level(level : UInt) -> @wite.OptimizeConfig {
  match level {
    0U => @wite.OptimizeConfig::o0()
    1U => @wite.OptimizeConfig::o1()
    2U => @wite.OptimizeConfig::o2()
    3U => @wite.OptimizeConfig::o3()
    _ => @wite.OptimizeConfig::aggressive()
  }
}

///|
fn derive_preset_from_wasm_opt_levels(
  optimize_level : UInt?,
  shrink_level : UInt?,
) -> @wite.OptimizeConfig? {
  match shrink_level {
    Some(level) =>
      if level >= 2U {
        Some(@wite.OptimizeConfig::oz())
      } else if level == 1U {
        Some(@wite.OptimizeConfig::os())
      } else {
        match optimize_level {
          Some(v) => Some(wasm_opt_preset_from_optimize_level(v))
          None => None
        }
      }
    None =>
      match optimize_level {
        Some(v) => Some(wasm_opt_preset_from_optimize_level(v))
        None => None
      }
  }
}

///|
fn parse_optimize_cli_options(flags : Array[String]) -> OptimizeCliOptions {
  let mut strip_all_custom = false
  let mut strip_name_section = true
  let mut strip_producers_section = true
  let mut strip_debug_sections = false
  let mut strip_dwarf_sections = false
  let mut strip_target_features_section = false
  let mut enable_peephole = true
  let mut enable_vacuum = true
  let mut enable_merge_blocks = true
  let mut enable_remove_unused_brs = true
  let mut pass_rounds = 1U
  let mut enable_dce = false
  let mut enable_dfe = false
  let mut enable_merge_similar_functions = false
  let mut enable_remove_unused_module_elements = false
  let mut closed_world = false
  let mut safe_mode = false
  let mut verbose = false
  let mut wasm_opt_optimize_level : UInt? = None
  let mut wasm_opt_shrink_level : UInt? = None
  let mut i = 0
  while i < flags.length() {
    let flag = flags[i]
    match
      @wite.optimize_config_from_opt_level(normalize_opt_level_token(flag)) {
      Some(preset) => {
        strip_all_custom = preset.strip_all_custom
        strip_name_section = preset.strip_name_section
        strip_producers_section = preset.strip_producers_section
        strip_debug_sections = preset.strip_debug_sections
        strip_dwarf_sections = preset.strip_dwarf_sections
        strip_target_features_section = preset.strip_target_features_section
        pass_rounds = preset.pass_rounds
        enable_peephole = preset.enable_peephole
        enable_vacuum = preset.enable_vacuum
        enable_merge_blocks = preset.enable_merge_blocks
        enable_remove_unused_brs = preset.enable_remove_unused_brs
        enable_dce = preset.enable_dce
        enable_dfe = preset.enable_dfe
        enable_merge_similar_functions = preset.enable_merge_similar_functions
        enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
        closed_world = preset.closed_world
        safe_mode = preset.safe_mode
      }
      None => ()
    }
    if flag == "--optimize-level" || flag == "-ol" {
      if i + 1 >= flags.length() {
        println("missing value after " + flag)
        @sys.exit(1)
      }
      wasm_opt_optimize_level = Some(
        parse_wasm_opt_optimize_level_or_exit(flags[i + 1]),
      )
      match
        derive_preset_from_wasm_opt_levels(
          wasm_opt_optimize_level, wasm_opt_shrink_level,
        ) {
        Some(preset) => {
          strip_all_custom = preset.strip_all_custom
          strip_name_section = preset.strip_name_section
          strip_producers_section = preset.strip_producers_section
          strip_debug_sections = preset.strip_debug_sections
          strip_dwarf_sections = preset.strip_dwarf_sections
          strip_target_features_section = preset.strip_target_features_section
          pass_rounds = preset.pass_rounds
          enable_peephole = preset.enable_peephole
          enable_vacuum = preset.enable_vacuum
          enable_merge_blocks = preset.enable_merge_blocks
          enable_remove_unused_brs = preset.enable_remove_unused_brs
          enable_dce = preset.enable_dce
          enable_dfe = preset.enable_dfe
          enable_merge_similar_functions = preset.enable_merge_similar_functions
          enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
          closed_world = preset.closed_world
          safe_mode = preset.safe_mode
        }
        None => ()
      }
      i += 2
      continue
    }
    match flag.strip_prefix("--optimize-level=") {
      Some(value) => {
        wasm_opt_optimize_level = Some(
          parse_wasm_opt_optimize_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    match flag.strip_prefix("-ol=") {
      Some(value) => {
        wasm_opt_optimize_level = Some(
          parse_wasm_opt_optimize_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    if flag == "--shrink-level" || flag == "-s" {
      if i + 1 >= flags.length() {
        println("missing value after " + flag)
        @sys.exit(1)
      }
      wasm_opt_shrink_level = Some(
        parse_wasm_opt_shrink_level_or_exit(flags[i + 1]),
      )
      match
        derive_preset_from_wasm_opt_levels(
          wasm_opt_optimize_level, wasm_opt_shrink_level,
        ) {
        Some(preset) => {
          strip_all_custom = preset.strip_all_custom
          strip_name_section = preset.strip_name_section
          strip_producers_section = preset.strip_producers_section
          strip_debug_sections = preset.strip_debug_sections
          strip_dwarf_sections = preset.strip_dwarf_sections
          strip_target_features_section = preset.strip_target_features_section
          pass_rounds = preset.pass_rounds
          enable_peephole = preset.enable_peephole
          enable_vacuum = preset.enable_vacuum
          enable_merge_blocks = preset.enable_merge_blocks
          enable_remove_unused_brs = preset.enable_remove_unused_brs
          enable_dce = preset.enable_dce
          enable_dfe = preset.enable_dfe
          enable_merge_similar_functions = preset.enable_merge_similar_functions
          enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
          closed_world = preset.closed_world
          safe_mode = preset.safe_mode
        }
        None => ()
      }
      i += 2
      continue
    }
    match flag.strip_prefix("--shrink-level=") {
      Some(value) => {
        wasm_opt_shrink_level = Some(
          parse_wasm_opt_shrink_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    match flag.strip_prefix("-s=") {
      Some(value) => {
        wasm_opt_shrink_level = Some(
          parse_wasm_opt_shrink_level_or_exit(value.to_string()),
        )
        match
          derive_preset_from_wasm_opt_levels(
            wasm_opt_optimize_level, wasm_opt_shrink_level,
          ) {
          Some(preset) => {
            strip_all_custom = preset.strip_all_custom
            strip_name_section = preset.strip_name_section
            strip_producers_section = preset.strip_producers_section
            strip_debug_sections = preset.strip_debug_sections
            strip_dwarf_sections = preset.strip_dwarf_sections
            strip_target_features_section = preset.strip_target_features_section
            pass_rounds = preset.pass_rounds
            enable_peephole = preset.enable_peephole
            enable_vacuum = preset.enable_vacuum
            enable_merge_blocks = preset.enable_merge_blocks
            enable_remove_unused_brs = preset.enable_remove_unused_brs
            enable_dce = preset.enable_dce
            enable_dfe = preset.enable_dfe
            enable_merge_similar_functions = preset.enable_merge_similar_functions
            enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
            closed_world = preset.closed_world
            safe_mode = preset.safe_mode
          }
          None => ()
        }
        i += 1
        continue
      }
      None => ()
    }
    if flag == "--strip" {
      strip_debug_sections = true
      strip_name_section = true
    }
    if flag == "--strip-all-custom" {
      strip_all_custom = true
    }
    if flag == "--strip-producers" {
      strip_producers_section = true
    }
    if flag == "--strip-debug" {
      strip_debug_sections = true
    }
    if flag == "--strip-dwarf" {
      strip_dwarf_sections = true
    }
    if flag == "--strip-target-features" {
      strip_target_features_section = true
    }
    if flag == "--no-peephole" {
      enable_peephole = false
    }
    if flag == "--peephole" {
      enable_peephole = true
    }
    if flag == "--no-vacuum" {
      enable_vacuum = false
    }
    if flag == "--vacuum" {
      enable_vacuum = true
    }
    if flag == "--no-merge-blocks" {
      enable_merge_blocks = false
    }
    if flag == "--merge-blocks" {
      enable_merge_blocks = true
    }
    if flag == "--no-remove-unused-brs" {
      enable_remove_unused_brs = false
    }
    if flag == "--remove-unused-brs" {
      enable_remove_unused_brs = true
    }
    if flag == "--debuginfo" || flag == "-g" {
      strip_name_section = false
      strip_debug_sections = false
    }
    if flag == "--converge" {
      pass_rounds = 8U
    }
    if flag == "-c" {
      pass_rounds = 8U
    }
    if flag == "--rounds" {
      if i + 1 >= flags.length() {
        println("missing value after --rounds")
        @sys.exit(1)
      }
      pass_rounds = parse_uint_or_exit(flags[i + 1], "rounds")
      i += 2
      continue
    }
    match flag.strip_prefix("--rounds=") {
      Some(value) =>
        pass_rounds = parse_uint_or_exit(value.to_string(), "rounds")
      None => ()
    }
    if flag == "--dce" || flag == "--dce-apply" {
      enable_dce = true
    }
    if flag == "--duplicate-function-elimination" || flag == "--dfe-apply" {
      enable_dfe = true
    }
    if flag == "--merge-similar-functions" || flag == "--msf-apply" {
      enable_merge_similar_functions = true
    }
    if flag == "--remove-unused-module-elements" || flag == "--rume-apply" {
      enable_remove_unused_module_elements = true
    }
    if flag == "-cw" {
      closed_world = true
    }
    if flag == "--all-features" || flag == "-all" {
      i += 1
      continue
    }
    if flag.has_prefix("--enable-") || flag.has_prefix("--disable-") {
      i += 1
      continue
    }
    if flag == "--mvp-features" || flag == "-mvp" || flag == "--detect-features" {
      i += 1
      continue
    }
    if flag == "--closed-world" {
      closed_world = true
    }
    if flag == "--safe-mode" {
      safe_mode = true
    }
    if flag == "--verbose" {
      verbose = true
    }
    i += 1
  }
  let keep_custom_sections = parse_keep_custom(flags, 0)
  let closed_world_root_exports = parse_closed_world_roots(flags, 0)
  let excluded_roots = parse_excluded_roots(flags, 0)
  let config = @wite.make_optimize_config(
    strip_all_custom~,
    strip_name_section~,
    strip_producers_section~,
    strip_debug_sections~,
    strip_dwarf_sections~,
    strip_target_features_section~,
    keep_custom_sections~,
    pass_rounds~,
    enable_peephole~,
    enable_vacuum~,
    enable_merge_blocks~,
    enable_remove_unused_brs~,
    enable_dce~,
    enable_dfe~,
    enable_merge_similar_functions~,
    enable_remove_unused_module_elements~,
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  { config, excluded_roots, verbose }
}

///|

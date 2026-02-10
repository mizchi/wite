///|
fn analyze_view_name(view : AnalyzeView) -> String {
  match view {
    AnalyzeView::Summary => "summary"
    AnalyzeView::Deep => "deep"
    AnalyzeView::Functions => "functions"
    AnalyzeView::Blocks => "blocks"
    AnalyzeView::Callgraph => "callgraph"
    AnalyzeView::Host => "host"
    AnalyzeView::Pipeline => "pipeline"
    AnalyzeView::Dce => "dce"
    AnalyzeView::Keep => "keep"
    AnalyzeView::Retain => "retain"
  }
}

///|
fn is_analyze_subcommand(name : String) -> Bool {
  match name {
    "host"
    | "opt"
    | "deep"
    | "profile"
    | "top-functions"
    | "function-gap"
    | "block-sizes"
    | "callgraph"
    | "keep-reasons"
    | "retain-path"
    | "dce-report"
    | "runtime-profile"
    | "hot-size"
    | "component"
    | "component-top-functions"
    | "component-callgraph"
    | "component-dce-kpi"
    | "contract"
    | "root-policy" => true
    _ => false
  }
}

///|
fn make_shifted_args(args : Array[String], subcmd : String) -> Array[String] {
  // Shift args so that args[2] (subcommand) becomes transparent:
  // [wite, analyze, subcmd, file, ...] -> [wite, subcmd, file, ...]
  let shifted : Array[String] = [args[0], subcmd]
  for i in 3..<args.length() {
    shifted.push(args[i])
  }
  shifted
}

///|
async fn run_analyze_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_analyze_usage()
    @sys.exit(1)
  }
  let second = args[2]
  // Handle -h flag
  if second == "-h" || second == "--help" {
    print_analyze_usage()
    return
  }
  // Check if args[2] is a known subcommand
  if is_analyze_subcommand(second) {
    run_analyze_subcommand(args, second)
    return
  }
  // Otherwise, treat args[2] as a wasm file path and use --view= based analysis
  run_analyze_view_command(args)
}

///|
async fn run_analyze_subcommand(args : Array[String], subcmd : String) -> Unit {
  let shifted = make_shifted_args(args, subcmd)
  match subcmd {
    "host" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      run_analyze_host(shifted[2], limit)
    }
    "opt" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let mut config = @wite.OptimizeConfig::o1()
      let mut diff_limit = 20U
      if shifted.length() >= 4 {
        match @wite.optimize_config_from_opt_level(shifted[3]) {
          Some(v) => {
            config = v
            if shifted.length() >= 5 {
              diff_limit = parse_uint_or_exit(shifted[4], "diff-limit")
            }
          }
          None => diff_limit = parse_uint_or_exit(shifted[3], "diff-limit")
        }
      }
      run_analyze_opt(shifted[2], config, diff_limit)
    }
    "deep" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      run_deep_analyze(shifted[2], limit)
    }
    "profile" => run_profile_command(shifted)
    "top-functions" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      run_top_functions(shifted[2], limit)
    }
    "function-gap" => {
      if shifted.length() < 4 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 5 {
        parse_uint_or_exit(shifted[4], "limit")
      } else {
        20U
      }
      run_function_gap(shifted[2], shifted[3], limit)
    }
    "block-sizes" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      run_block_sizes(shifted[2], limit)
    }
    "callgraph" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      run_callgraph(shifted[2], limit)
    }
    "keep-reasons" => run_keep_reasons(shifted)
    "retain-path" => run_retain_path(shifted)
    "dce-report" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      run_dce_report(shifted[2], limit)
    }
    "runtime-profile" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let mut iterations = 50U
      let mut has_iterations = false
      for i in 3..<shifted.length() {
        let arg = shifted[i]
        if arg.has_prefix("--scenario=") {
          ()
        } else if arg.has_prefix("--") {
          println("unknown runtime-profile option: " + arg)
          @sys.exit(1)
        } else if not(has_iterations) {
          iterations = parse_uint_or_exit(arg, "iterations")
          has_iterations = true
        } else {
          println("unexpected runtime-profile argument: " + arg)
          @sys.exit(1)
        }
      }
      let scenarios = parse_runtime_profile_scenarios(shifted, 3)
      run_runtime_profile(shifted[2], iterations, scenarios)
    }
    "hot-size" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let mut iterations = 50U
      let mut limit = 20U
      let mut has_iterations = false
      let mut has_limit = false
      for i in 3..<shifted.length() {
        let arg = shifted[i]
        if arg.has_prefix("--scenario=") {
          ()
        } else if arg.has_prefix("--") {
          println("unknown hot-size option: " + arg)
          @sys.exit(1)
        } else if not(has_iterations) {
          iterations = parse_uint_or_exit(arg, "iterations")
          has_iterations = true
        } else if not(has_limit) {
          limit = parse_uint_or_exit(arg, "limit")
          has_limit = true
        } else {
          println("unexpected hot-size argument: " + arg)
          @sys.exit(1)
        }
      }
      let scenarios = parse_runtime_profile_scenarios(shifted, 3)
      run_hot_size(shifted[2], iterations, limit, scenarios)
    }
    "component" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      @wite_component.run_component_profile(shifted[2])
    }
    "component-top-functions" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      @wite_component.run_component_top_functions(shifted[2], limit)
    }
    "component-callgraph" => {
      if shifted.length() < 3 {
        print_analyze_usage()
        @sys.exit(1)
      }
      let limit = if shifted.length() >= 4 {
        parse_uint_or_exit(shifted[3], "limit")
      } else {
        20U
      }
      @wite_component.run_component_callgraph(shifted[2], limit)
    }
    "component-dce-kpi" => run_component_dce_kpi(shifted)
    "contract" => {
      if shifted.length() < 4 {
        print_analyze_usage()
        @sys.exit(1)
      }
      run_contract(shifted[2], shifted[3])
    }
    "root-policy" => run_root_policy(shifted)
    _ => {
      print_analyze_usage()
      @sys.exit(1)
    }
  }
}

///|
async fn run_analyze_view_command(args : Array[String]) -> Unit {
  let path = args[2]
  let raw_flags : Array[String] = []
  for i in 3..<args.length() {
    raw_flags.push(args[i])
  }
  let config_selection = @wite_config.parse_config_selection_flags(raw_flags)
  auto_sync_deps_from_config_if_needed(config_selection)
  let config_file = @wite_config.resolve_wite_config_or_default(
    config_selection,
  )
  let merged_flags = @wite_config.merge_command_flags(
    config_file.analyze_flags,
    config_selection.remaining_flags,
  )
  let mut view = AnalyzeView::Summary
  let mut kind = from_config_binary_kind(config_file.analyze_kind)
  let mut limit = 20U
  let mut diff_limit = 20U
  let mut config = @wite.OptimizeConfig::o1()
  let mut closed_world = false
  let mut safe_mode = false
  let closed_world_root_exports : Array[String] = []
  let positional : Array[String] = []
  let mut i = 0
  while i < merged_flags.length() {
    let arg = merged_flags[i]
    if arg == "--kind" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(merged_flags[i + 1], "analyze kind")
      i += 2
      continue
    }
    match arg.strip_prefix("--kind=") {
      Some(value) => {
        kind = parse_binary_kind_or_exit(value.to_string(), "analyze kind")
        i += 1
        continue
      }
      None => ()
    }
    match arg.strip_prefix("--view=") {
      Some(name) =>
        match parse_analyze_view(name.to_string()) {
          Some(v) => view = v
          None => {
            println("unknown analyze view: " + name.to_string())
            @sys.exit(1)
          }
        }
      None =>
        match arg.strip_prefix("--limit=") {
          Some(v) => limit = parse_uint_or_exit(v.to_string(), "limit")
          None =>
            match arg.strip_prefix("--diff-limit=") {
              Some(v) =>
                diff_limit = parse_uint_or_exit(v.to_string(), "diff-limit")
              None =>
                match arg.strip_prefix("--opt-level=") {
                  Some(v) => config = parse_opt_level_or_exit(v.to_string())
                  None =>
                    match arg.strip_prefix("--closed-world-root=") {
                      Some(root_name) =>
                        if not(root_name.is_empty()) {
                          closed_world_root_exports.push(root_name.to_string())
                        }
                      None =>
                        if arg == "--closed-world" {
                          closed_world = true
                        } else if arg == "--safe-mode" {
                          safe_mode = true
                        } else if arg.has_prefix("--") {
                          println("unknown analyze option: " + arg)
                          @sys.exit(1)
                        } else {
                          positional.push(arg)
                        }
                    }
                }
            }
        }
    }
    i += 1
  }
  if not(analyze_view_supports_kind(view, kind)) {
    println(
      "analyze view '" +
      analyze_view_name(view) +
      "' is not supported for kind=" +
      binary_kind_name(kind),
    )
    if kind is BinaryKind::Component {
      println("supported component analyze views: summary|functions|callgraph")
    }
    @sys.exit(1)
  }
  match view {
    AnalyzeView::Summary =>
      if positional.length() > 0 {
        println("unexpected analyze argument: " + positional[0])
        @sys.exit(1)
      }
    AnalyzeView::Deep
    | AnalyzeView::Functions
    | AnalyzeView::Blocks
    | AnalyzeView::Callgraph
    | AnalyzeView::Host
    | AnalyzeView::Dce => {
      if positional.length() > 1 {
        println("unexpected analyze argument: " + positional[1])
        @sys.exit(1)
      }
      if positional.length() == 1 {
        limit = parse_uint_or_exit(positional[0], "limit")
      }
    }
    AnalyzeView::Pipeline => {
      if positional.length() > 2 {
        println("unexpected analyze argument: " + positional[2])
        @sys.exit(1)
      }
      if positional.length() >= 1 {
        match
          @wite.optimize_config_from_opt_level(
            normalize_opt_level_token(positional[0]),
          ) {
          Some(v) => {
            config = v
            if positional.length() == 2 {
              diff_limit = parse_uint_or_exit(positional[1], "diff-limit")
            }
          }
          None => {
            diff_limit = parse_uint_or_exit(positional[0], "diff-limit")
            if positional.length() == 2 {
              println("unexpected analyze argument: " + positional[1])
              @sys.exit(1)
            }
          }
        }
      }
    }
    AnalyzeView::Keep =>
      if positional.length() > 0 {
        println("unexpected analyze argument: " + positional[0])
        @sys.exit(1)
      }
    AnalyzeView::Retain => {
      if positional.length() > 1 {
        println("unexpected analyze argument: " + positional[1])
        @sys.exit(1)
      }
      if positional.length() == 1 {
        limit = parse_uint_or_exit(positional[0], "limit")
      }
    }
  }
  match kind {
    BinaryKind::Component =>
      match view {
        AnalyzeView::Summary => @wite_component.run_component_profile(path)
        AnalyzeView::Functions =>
          @wite_component.run_component_top_functions(path, limit)
        AnalyzeView::Callgraph =>
          @wite_component.run_component_callgraph(path, limit)
        _ => {
          println(
            "analyze view '" +
            analyze_view_name(view) +
            "' is not supported for kind=component",
          )
          @sys.exit(1)
        }
      }
    BinaryKind::Auto | BinaryKind::Core =>
      match view {
        AnalyzeView::Summary => run_analyze(path)
        AnalyzeView::Deep => run_deep_analyze(path, limit)
        AnalyzeView::Functions => run_top_functions(path, limit)
        AnalyzeView::Blocks => run_block_sizes(path, limit)
        AnalyzeView::Callgraph => run_callgraph(path, limit)
        AnalyzeView::Host => run_analyze_host(path, limit)
        AnalyzeView::Pipeline => run_analyze_opt(path, config, diff_limit)
        AnalyzeView::Dce => run_dce_report(path, limit)
        AnalyzeView::Keep =>
          run_keep_reasons_with_options(
            path, closed_world, safe_mode, closed_world_root_exports,
          )
        AnalyzeView::Retain =>
          run_retain_path_with_options(
            path, limit, closed_world, safe_mode, closed_world_root_exports,
          )
      }
  }
}

///|

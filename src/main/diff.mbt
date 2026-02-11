///|
fn run_diff_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let left_path = args[2]
  let mut view = DiffView::Function
  let mut limit = 20U
  let mut baseline : DiffBaseline? = None
  let mut baseline_opt_level = "-Oz"
  let mut wasm_opt_bin_override : String? = None
  let wasm_opt_extra_args : Array[String] = []
  let positional : Array[String] = []
  for i in 3..<args.length() {
    let arg = args[i]
    match arg.strip_prefix("--view=") {
      Some(name) =>
        match parse_diff_view(name.to_string()) {
          Some(v) => view = v
          None => {
            println("unknown diff view: " + name.to_string())
            @sys.exit(1)
          }
        }
      None =>
        match arg.strip_prefix("--limit=") {
          Some(value) => limit = parse_uint_or_exit(value.to_string(), "limit")
          None =>
            match arg.strip_prefix("--baseline=") {
              Some(name) =>
                match parse_diff_baseline(name.to_string()) {
                  Some(v) => baseline = Some(v)
                  None => {
                    println("unknown diff baseline: " + name.to_string())
                    @sys.exit(1)
                  }
                }
              None =>
                match arg.strip_prefix("--wasm-opt-bin=") {
                  Some(path) => {
                    if path.is_empty() {
                      println("wasm-opt-bin must not be empty")
                      @sys.exit(1)
                    }
                    wasm_opt_bin_override = Some(path.to_string())
                  }
                  None =>
                    match arg.strip_prefix("--baseline-opt-level=") {
                      Some(level) =>
                        baseline_opt_level = parse_wasm_opt_level_or_exit(
                          level.to_string(),
                        )
                      None =>
                        match arg.strip_prefix("--baseline-arg=") {
                          Some(v) =>
                            if !v.is_empty() {
                              wasm_opt_extra_args.push(v.to_string())
                            }
                          None =>
                            if arg.has_prefix("--") {
                              println("unknown diff option: " + arg)
                              @sys.exit(1)
                            } else {
                              positional.push(arg)
                            }
                        }
                    }
                }
            }
        }
    }
  }
  if positional.length() > 1 {
    println("unexpected diff argument: " + positional[1])
    @sys.exit(1)
  }
  if positional.length() == 1 && baseline is Some(_) {
    println("cannot combine explicit right.wasm with --baseline")
    @sys.exit(1)
  }
  let mut generated_baseline_path : String? = None
  let right_path = if positional.length() == 1 {
    positional[0]
  } else {
    match baseline {
      Some(DiffBaseline::WasmOpt) => {
        let wasm_opt_bin = resolve_wasm_opt_bin(wasm_opt_bin_override)
        let output_path = js_make_temp_wasm_path("wite-diff-wasm-opt")
        run_wasm_opt_baseline_or_exit(
          left_path, output_path, wasm_opt_bin, baseline_opt_level, wasm_opt_extra_args,
        )
        generated_baseline_path = Some(output_path)
        output_path
      }
      None => {
        println("diff requires <right.wasm> or --baseline=wasm-opt")
        @sys.exit(1)
        ""
      }
    }
  }
  match view {
    DiffView::Function => run_function_gap(left_path, right_path, limit)
    DiffView::Section => run_section_gap(left_path, right_path, limit)
    DiffView::Block => run_block_gap(left_path, right_path, limit)
  }
  match generated_baseline_path {
    Some(path) => @fs.remove_file(path) catch { _ => () }
    None => ()
  }
}

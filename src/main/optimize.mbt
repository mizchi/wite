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


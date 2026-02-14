///|
fn print_usage() -> Unit {
  println("wite commands:")
  println("  init [--force]")
  println("  new [--moonbit|--rust] [--force]")
  println(
    "  install [--config=<path>|--config <path>] [--dir=<path>|--dir <path>] [--verify] [--fail-fast]",
  )
  println(
    "  add <dep-spec> [--protocol=wkg|warg|oci] [--registry=<host>] [--name=<id>] [--config=<path>] [--verify]",
  )
  println(
    "  build [entry.(wac|wasm)] [--interface=<wit-dir>|--interface <wit-dir>] [--world=<world>|--world <world>] [options]",
  )
  println("  diff <left.wasm> [right.wasm] [options]")
  println("  optimize <input.wasm> <output.wasm> [options]")
  println("  deps verify|sync [options]")
  println("  analyze [subcommand] <file.wasm> [options]")
  println("  componentize [--force]")
  println(
    "  componentize <core.wasm> [-o <path>] [--wit <dir>] [--world <name>]",
  )
  println("")
  println("Run 'wite <command> -h' for more information on a command.")
}

///|
fn print_analyze_usage() -> Unit {
  println("wite analyze subcommands:")
  println(
    "  wite analyze <file.wasm> [--view=summary|deep|functions|blocks|callgraph|host|pipeline|dce|keep|retain] [--limit=<n>] [--kind=auto|core|component] [options]",
  )
  println("  wite analyze host <file.wasm> [limit]")
  println("  wite analyze opt <file.wasm> [opt-level] [diff-limit]")
  println("  wite analyze deep <file.wasm> [limit]")
  println(
    "  wite analyze profile <file.wasm> [--config=<path>|--config <path>|--no-config] [--kind=auto|core|component]",
  )
  println("  wite analyze top-functions <file.wasm> [limit]")
  println("  wite analyze function-gap <left.wasm> <right.wasm> [limit]")
  println("  wite analyze block-sizes <file.wasm> [limit]")
  println("  wite analyze callgraph <file.wasm> [limit]")
  println(
    "  wite analyze keep-reasons <file.wasm> [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println(
    "  wite analyze retain-path <file.wasm> [limit] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println("  wite analyze dce-report <file.wasm> [limit]")
  println(
    "  wite analyze runtime-profile <file.wasm> [iterations] [--scenario=<export>[:arg1,arg2,...]]",
  )
  println(
    "  wite analyze hot-size <file.wasm> [iterations] [limit] [--scenario=<export>[:arg1,arg2,...]]",
  )
  println("  wite analyze component <file.wasm>")
  println("  wite analyze component-top-functions <file.wasm> [limit]")
  println("  wite analyze component-callgraph <file.wasm> [limit]")
  println(
    "  wite analyze component-dce-kpi <file.wasm> [wit-dir] [--exclude=<name>] [--closed-world-root=<export-name>] [--safe-mode] [--verbose]",
  )
  println("  wite analyze contract <file.wasm> <wit-dir>")
  println(
    "  wite analyze interface <file.wasm> [wit-dir] [--world=<world>] [--strict]",
  )
  println("  wite analyze root-policy <file.wasm> [wit-dir] [--exclude=<name>]")
}

///|
priv enum AnalyzeView {
  Summary
  Deep
  Functions
  Blocks
  Callgraph
  Host
  Pipeline
  Dce
  Keep
  Retain
}

///|
pub enum BinaryKind {
  Auto
  Core
  Component
}

///|
fn parse_binary_kind(name : String) -> BinaryKind? {
  match name.to_lower() {
    "auto" => Some(BinaryKind::Auto)
    "core" => Some(BinaryKind::Core)
    "component" => Some(BinaryKind::Component)
    _ => None
  }
}

///|
fn binary_kind_name(kind : BinaryKind) -> String {
  match kind {
    BinaryKind::Auto => "auto"
    BinaryKind::Core => "core"
    BinaryKind::Component => "component"
  }
}

///|
fn from_config_binary_kind(kind : @wite_config.BinaryKind) -> BinaryKind {
  match kind {
    @wite_config.BinaryKind::Auto => BinaryKind::Auto
    @wite_config.BinaryKind::Core => BinaryKind::Core
    @wite_config.BinaryKind::Component => BinaryKind::Component
  }
}

///|
fn parse_binary_kind_or_exit(value : String, label : String) -> BinaryKind {
  match parse_binary_kind(value) {
    Some(kind) => kind
    None => {
      println("invalid " + label + ": " + value)
      @sys.exit(1)
      BinaryKind::Auto
    }
  }
}

///|
priv struct BinaryKindFlagParseResult {
  kind : BinaryKind
  flags : Array[String]
}

///|
fn extract_binary_kind_flags(
  flags : Array[String],
  default_kind : BinaryKind,
  label : String,
) -> BinaryKindFlagParseResult {
  let out : Array[String] = []
  let mut kind = default_kind
  let mut i = 0
  while i < flags.length() {
    let flag = flags[i]
    if flag == "--kind" {
      if i + 1 >= flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(flags[i + 1], label)
      i += 2
      continue
    }
    if flag.strip_prefix("--kind=") is Some(value) {
      kind = parse_binary_kind_or_exit(value.to_string(), label)
      i += 1
      continue
    }
    out.push(flag)
    i += 1
  }
  { kind, flags: out }
}

///|
fn analyze_view_supports_kind(view : AnalyzeView, kind : BinaryKind) -> Bool {
  match kind {
    BinaryKind::Auto | BinaryKind::Core => true
    BinaryKind::Component =>
      view is AnalyzeView::Summary ||
      view is AnalyzeView::Functions ||
      view is AnalyzeView::Callgraph
  }
}

///|
priv enum DiffView {
  Function
  Section
  Block
}

///|
fn parse_diff_view(name : String) -> DiffView? {
  match name {
    "function" => Some(DiffView::Function)
    "section" => Some(DiffView::Section)
    "block" => Some(DiffView::Block)
    _ => None
  }
}

///|
priv enum DiffBaseline {
  WasmOpt
}

///|
fn parse_diff_baseline(name : String) -> DiffBaseline? {
  match name {
    "wasm-opt" => Some(DiffBaseline::WasmOpt)
    _ => None
  }
}

///|
fn parse_analyze_view(name : String) -> AnalyzeView? {
  match name {
    "summary" => Some(AnalyzeView::Summary)
    "deep" => Some(AnalyzeView::Deep)
    "functions" => Some(AnalyzeView::Functions)
    "top-functions" => Some(AnalyzeView::Functions)
    "blocks" => Some(AnalyzeView::Blocks)
    "block-sizes" => Some(AnalyzeView::Blocks)
    "callgraph" => Some(AnalyzeView::Callgraph)
    "host" => Some(AnalyzeView::Host)
    "pipeline" => Some(AnalyzeView::Pipeline)
    "dce" => Some(AnalyzeView::Dce)
    "keep" => Some(AnalyzeView::Keep)
    "retain" => Some(AnalyzeView::Retain)
    _ => None
  }
}

///|
fn normalize_opt_level_token(token : String) -> String {
  if token.has_prefix("-O") {
    token
  } else if token.has_prefix("O") {
    "-".to_string() + token
  } else {
    token
  }
}

///|
fn parse_opt_level_or_exit(token : String) -> @wite.OptimizeConfig {
  let normalized = normalize_opt_level_token(token)
  match @wite.optimize_config_from_opt_level(normalized) {
    Some(config) => config
    None => {
      println("invalid opt-level: " + token)
      @sys.exit(1)
      @wite.OptimizeConfig::o1()
    }
  }
}

///|

///|
fn run_doc_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println(doc_overview())
    return
  }
  let topic = args[2]
  let content = match topic {
    "config" => doc_config()
    "build" => doc_build()
    "analyze" => doc_analyze()
    "optimize" => doc_optimize()
    "diff" => doc_diff()
    "dev" => doc_dev()
    "deps" => doc_deps()
    "init" => doc_init()
    "new" => doc_new()
    "add" => doc_add()
    "install" => doc_install()
    _ => {
      println("unknown doc topic: " + topic)
      println("")
      println(doc_overview())
      return
    }
  }
  println(content)
}

///|
fn doc_overview() -> String {
  (
    #|# wite — WebAssembly component toolchain
    #|
    #|## Commands
    #|
    #|  init          Initialize wite project files (wite.config.ts, main.wac)
    #|  new           Create a new guest project from template (MoonBit or Rust)
    #|  build         Build and compose a WebAssembly component
    #|  optimize      Optimize a .wasm binary with wasm-opt passes
    #|  analyze       Analyze .wasm binary (size, functions, callgraph, DCE, etc.)
    #|  diff          Compare two .wasm binaries or diff against wasm-opt baseline
    #|  dev           Development server with live-reload
    #|  deps          Manage WIT/component dependencies (verify/sync)
    #|  add           Add a dependency to deps section
    #|  install       Install dependencies from config
    #|
    #|Run `wite doc <command>` for detailed documentation.
    #|
    #|Available topics: config, build, analyze, optimize, diff, dev, deps, add, install, init, new
  )
}

///|
fn doc_config() -> String {
  (
    #|# wite config
    #|
    #|wite reads configuration from `wite.config.jsonc` or `wite.config.ts` in the project root.
    #|TypeScript config is evaluated with `deno` or `npx tsx` and must `export default` an object.
    #|
    #|## Config Type
    #|
    #|  type WiteConfig = {
    #|    build?: {
    #|      kind?: "auto" | "core" | "component";
    #|      flags?: string[];
    #|    };
    #|    analyze?: {
    #|      kind?: "auto" | "core" | "component";
    #|      flags?: string[];
    #|    } | string[];
    #|    profile?: {
    #|      kind?: "auto" | "core" | "component";
    #|      flags?: string[];
    #|    } | string[];
    #|    input?: string | Record<string, string>;
    #|    output?: string | { dir?: string };
    #|    deps?: Record<string, string>;
    #|  };
    #|
    #|## Fields
    #|
    #|  build.kind       Binary kind for build command (default: "auto")
    #|  build.flags      Extra CLI flags passed to build
    #|  analyze.kind     Binary kind for analyze command (default: "auto")
    #|  analyze.flags    Extra CLI flags passed to analyze
    #|  profile.kind     Binary kind for profile command (default: "auto")
    #|  profile.flags    Extra CLI flags passed to analyze profile
    #|  input            Entry file path or named map of inputs
    #|                   - string: single entry (e.g. "main.wac")
    #|                   - Record<string, string>: named entries (e.g. { "app": "app.wac" })
    #|  output           Output config
    #|                   - string: output directory (e.g. "dist")
    #|                   - { dir: string }: output directory
    #|  deps             Dependency map: alias -> URL or version spec
    #|                   - e.g. { "wasi:http": "0.2.0" }
    #|                   - Supports local paths: "./path/to/wit"
    #|
    #|## Config Selection Flags (available on most commands)
    #|
    #|  --config=<path>    Use specific config file
    #|  --config <path>    (same, space-separated)
    #|  --no-config        Ignore config file
    #|
    #|## Example (wite.config.ts)
    #|
    #|  export default {
    #|    build: {
    #|      kind: "component",
    #|      flags: ["-Oz", "--converge"],
    #|    },
    #|    input: "main.wac",
    #|    output: "dist",
    #|    deps: {
    #|      "wasi:http": "0.2.0",
    #|    },
    #|  };
    #|
    #|## Example (wite.config.jsonc)
    #|
    #|  {
    #|    "build": {
    #|      "kind": "component",
    #|      "flags": ["-Oz", "--converge"]
    #|    },
    #|    "input": "main.wac",
    #|    "output": "dist"
    #|  }
  )
}

///|
fn doc_build() -> String {
  (
    #|# wite build
    #|
    #|Build and compose a WebAssembly component from .wac or .wasm entry.
    #|
    #|## Usage
    #|
    #|  wite build [entry.(wac|wasm)] [options]
    #|
    #|## Input Resolution
    #|
    #|  1. CLI argument (e.g. `wite build main.wac`)
    #|  2. Config `input` field
    #|  3. Filesystem default: main.wac or main.wasm in current dir
    #|
    #|## Flags
    #|
    #|  -o, --out <path>           Output file path
    #|      --out=<path>           (same, = form)
    #|      --kind <kind>          Binary kind: auto, core, component (default: auto)
    #|      --kind=<kind>          (same, = form)
    #|      --interface <wit-dir>  Path to WIT interface directory for verification
    #|      --interface=<wit-dir>  (same, = form)
    #|      --world <name>         WIT world name (requires --interface)
    #|      --world=<name>         (same, = form)
    #|      --best-effort          Continue with best-effort composition on errors
    #|      --no-compose-dce       Skip DCE during composition
    #|      --config <path>        Use specific config file
    #|      --no-config            Ignore config file
    #|
    #|## Optimization Flags (passed through to optimizer)
    #|
    #|  -O0, -O1, -O2, -O3, -O4   Optimization level presets
    #|  -Os                        Size optimization
    #|  -Oz                        Maximum size reduction
    #|  --converge, -c             Run 8 rounds for convergence
    #|  --strip                    Strip debug and name sections
    #|  --dce                      Dead code elimination
    #|
    #|  See `wite doc optimize` for full optimizer flag list.
    #|
    #|## Behavior
    #|
    #|  - .wac entry: auto-runs `wite deps sync` then wac compose
    #|  - .wasm entry: direct optimization pipeline
    #|  - Config flags are prepended to CLI flags
    #|  - Output defaults: derived from entry or config output.dir
  )
}

///|
fn doc_analyze() -> String {
  (
    #|# wite analyze
    #|
    #|Analyze a .wasm binary for size, structure, and optimization opportunities.
    #|
    #|## Usage
    #|
    #|  wite analyze <file.wasm> [--view=<view>] [--limit=<n>] [--kind=<kind>] [options]
    #|  wite analyze <subcommand> <file.wasm> [options]
    #|
    #|## View Modes (--view=)
    #|
    #|  summary      Section sizes and module overview (default)
    #|  deep         Detailed analysis with function sizes
    #|  functions    Top functions by size
    #|  blocks       Block sizes
    #|  callgraph    Call graph analysis
    #|  host         Host import analysis
    #|  pipeline     Optimization pipeline simulation
    #|  dce          Dead code elimination report
    #|  keep         Keep reasons for exports
    #|  retain       Retain path analysis
    #|
    #|## Subcommands
    #|
    #|  host <file.wasm> [limit]
    #|      List host imports
    #|
    #|  opt <file.wasm> [opt-level] [diff-limit]
    #|      Simulate optimization at given level
    #|
    #|  deep <file.wasm> [limit]
    #|      Deep size analysis
    #|
    #|  profile <file.wasm> [--config=<path>] [--no-config] [--kind=<kind>]
    #|      Full optimization profile using config flags
    #|
    #|  top-functions <file.wasm> [limit]
    #|      Top functions by code size
    #|
    #|  function-gap <left.wasm> <right.wasm> [limit]
    #|      Compare function sizes between two binaries
    #|
    #|  block-sizes <file.wasm> [limit]
    #|      Show block sizes
    #|
    #|  callgraph <file.wasm> [limit]
    #|      Display call graph
    #|
    #|  keep-reasons <file.wasm> [--closed-world] [--closed-world-root=<name>] [--safe-mode]
    #|      Show why each export is retained
    #|
    #|  retain-path <file.wasm> [limit] [--closed-world] [--closed-world-root=<name>] [--safe-mode]
    #|      Trace retain paths from roots
    #|
    #|  dce-report <file.wasm> [limit]
    #|      Dead code elimination report
    #|
    #|  runtime-profile <file.wasm> [iterations] [--scenario=<export>[:arg1,arg2,...]]
    #|      Runtime execution profile
    #|
    #|  hot-size <file.wasm> [iterations] [limit] [--scenario=<export>[:arg1,arg2,...]]
    #|      Hot function size analysis
    #|
    #|  component <file.wasm>
    #|      Component structure analysis
    #|
    #|  component-top-functions <file.wasm> [limit]
    #|      Top functions in component modules
    #|
    #|  component-callgraph <file.wasm> [limit]
    #|      Component-level call graph
    #|
    #|  component-dce-kpi <file.wasm> [wit-dir] [--exclude=<name>] [--closed-world-root=<name>] [--safe-mode] [--verbose]
    #|      Component DCE KPI analysis
    #|
    #|  contract <file.wasm> <wit-dir>
    #|      Contract verification
    #|
    #|  interface <file.wasm> [wit-dir] [--world=<world>] [--strict]
    #|      Interface validation
    #|
    #|  root-policy <file.wasm> [wit-dir] [--exclude=<name>]
    #|      Root policy analysis
    #|
    #|## View Mode Flags (for --view= form)
    #|
    #|  --kind=<auto|core|component>      Binary kind (default: auto)
    #|  --kind <kind>                     (same, space-separated)
    #|  --view=<view>                     View mode (default: summary)
    #|  --limit=<n>                       Limit output rows (default: 20)
    #|  --diff-limit=<n>                  Limit diff entries for pipeline view (default: 20)
    #|  --opt-level=<level>               Optimization level for pipeline view
    #|  --closed-world                    Enable closed-world analysis (keep/retain views)
    #|  --closed-world-root=<name>        Set closed-world roots (keep/retain views)
    #|  --safe-mode                       Preserve all exports (keep/retain views)
    #|  --config=<path>                   Config file path
    #|  --no-config                       Ignore config file
  )
}

///|
fn doc_optimize() -> String {
  (
    #|# wite optimize
    #|
    #|Optimize a .wasm binary using wasm-opt passes.
    #|
    #|## Usage
    #|
    #|  wite optimize <input.wasm> <output.wasm> [options]
    #|
    #|## Optimization Levels
    #|
    #|  -O0    No optimization
    #|  -O, -O1  Basic optimization
    #|  -O2    Standard optimization
    #|  -O3    Aggressive optimization
    #|  -O4    Maximum optimization (all passes)
    #|  -Os    Size optimization (optimize-level=2, shrink-level=1)
    #|  -Oz    Maximum size reduction (optimize-level=2, shrink-level=2)
    #|
    #|## Pass Control
    #|
    #|  --optimize-level <0-4>, -ol <0-4>   Set optimization level
    #|  --shrink-level <0-2>, -s <0-2>      Set shrink level
    #|  --rounds <n>                         Number of pass rounds (default: 1)
    #|  --converge, -c                       Run 8 rounds for convergence
    #|
    #|## Individual Passes
    #|
    #|  --dce, --dce-apply                         Dead code elimination
    #|  --duplicate-function-elimination, --dfe-apply  Function deduplication
    #|  --merge-similar-functions, --msf-apply     Merge similar functions
    #|  --remove-unused-module-elements, --rume-apply  Remove unused module items
    #|
    #|## Instruction-Level Optimization Toggles
    #|
    #|  --peephole / --no-peephole             Peephole optimizations (default: on)
    #|  --vacuum / --no-vacuum                 Vacuum pass (default: on)
    #|  --merge-blocks / --no-merge-blocks     Merge blocks (default: on)
    #|  --remove-unused-brs / --no-remove-unused-brs  Remove unused branches (default: on)
    #|
    #|## Strip/Debug Options
    #|
    #|  --strip                    Strip debug and name sections
    #|  --strip-all-custom         Remove all custom sections
    #|  --strip-producers          Strip producers section
    #|  --strip-debug              Strip debug info
    #|  --strip-dwarf              Strip DWARF debug sections
    #|  --strip-target-features    Strip target feature section
    #|  --debuginfo, -g            Keep debug info
    #|
    #|## Component (Closed-World) Options
    #|
    #|  --closed-world, -cw                   Enable closed-world analysis
    #|  --safe-mode                            Preserve all exports
    #|  --closed-world-root=<export-name>      Set closed-world roots
    #|  --exclude=<name>                       Exclude from DCE
    #|  --keep-custom=<name>                   Keep specific custom sections
    #|
    #|## Feature Flags
    #|
    #|  --all-features, -all       Enable all features
    #|  --mvp-features, -mvp       Use MVP features only
    #|  --detect-features          Auto-detect features
    #|  --enable-<name>            Enable specific feature
    #|  --disable-<name>           Disable specific feature
    #|
    #|## Other
    #|
    #|  --verbose                  Verbose output
  )
}

///|
fn doc_diff() -> String {
  (
    #|# wite diff
    #|
    #|Compare two .wasm binaries or diff against a wasm-opt baseline.
    #|
    #|## Usage
    #|
    #|  wite diff <left.wasm> [right.wasm] [options]
    #|  wite diff <file.wasm> --baseline=wasm-opt [options]
    #|
    #|## Flags
    #|
    #|  --view=<mode>                   Diff view: function (default), section, block
    #|  --limit=<n>                     Limit results (default: 20)
    #|  --baseline=wasm-opt             Generate right side via wasm-opt
    #|  --baseline-opt-level=<level>    Opt level for baseline: O0-O4, Os, Oz (default: Oz)
    #|  --baseline-arg=<arg>            Additional wasm-opt arg (repeatable)
    #|  --wasm-opt-bin=<path>           Path to wasm-opt (env: WASM_OPT_BIN)
    #|
    #|## Examples
    #|
    #|  # Compare two files
    #|  wite diff before.wasm after.wasm
    #|
    #|  # Compare against wasm-opt -Oz baseline
    #|  wite diff my.wasm --baseline=wasm-opt
    #|
    #|  # Section-level diff with custom baseline
    #|  wite diff my.wasm --baseline=wasm-opt --baseline-opt-level=Os --view=section
  )
}

///|
fn doc_dev() -> String {
  (
    #|# wite dev
    #|
    #|Development server with live-reload for WebAssembly projects.
    #|
    #|## Usage
    #|
    #|  wite dev [dir] [options]
    #|
    #|## Flags
    #|
    #|  [dir]                   Project directory (default: ".")
    #|  --port=<n>              Server port (default: 8080)
    #|  --port <n>              (same, space-separated)
    #|  --target=<target>       Build target: wasm-gc, wasm (default: wasm-gc)
    #|  --target <target>       (same, space-separated)
    #|  --build-cmd=<cmd>       Custom build command (run on file change)
    #|  --build-cmd <cmd>       (same, space-separated)
    #|  --watch=<path>          File path to watch (auto-detected if omitted)
    #|  --watch <path>          (same, space-separated)
    #|
    #|## Behavior
    #|
    #|  - Watches for WASM file changes and triggers live-reload via SSE
    #|  - Serves index.html from project dir or auto-generates one
    #|  - Injects livereload script into HTML responses
    #|  - Auto-detects WASM in target/<target>/debug/build/ or _build/<target>/debug/build/
    #|
    #|## Debug API Endpoints
    #|
    #|  /__wite/               Debug UI with module analysis
    #|  /__wite/api/status     JSON: { reload_version, wasm_hash, wasm_path }
    #|  /__wite/api/analyze    JSON: module profile and function sizes
    #|  /__wite_livereload     SSE stream for reload notifications
    #|
    #|## Example
    #|
    #|  # Start dev server with moon build on change
    #|  wite dev --build-cmd="moon build --target wasm-gc" --port=3000
  )
}

///|
fn doc_deps() -> String {
  (
    #|# wite deps
    #|
    #|Manage WIT/component dependencies.
    #|
    #|## Usage
    #|
    #|  wite deps verify [options]
    #|  wite deps sync [options]
    #|
    #|## Subcommands
    #|
    #|  verify    Verify that all dependencies are resolved and valid
    #|  sync      Materialize dependencies into deps/ directory
    #|
    #|## verify Flags
    #|
    #|  --config=<path>    Config file path
    #|  --config <path>    (same, space-separated)
    #|  --fail-fast        Stop on first error
    #|  --no-fail-fast     Disable fail-fast
    #|
    #|## sync Flags
    #|
    #|  --config=<path>    Config file path
    #|  --config <path>    (same, space-separated)
    #|  --dir=<path>       Output directory for deps (default: "deps")
    #|  --dir <path>       (same, space-separated)
    #|  --output-dir=<path>  Alias for --dir
    #|  --out-dir=<path>     Alias for --dir
    #|  --verify           Verify each dep before syncing
    #|  --no-verify        Disable verification
    #|  --fail-fast        Stop on first error
    #|  --no-fail-fast     Disable fail-fast
    #|
    #|## Dependency Resolution
    #|
    #|  Dependencies are defined in config `deps` field and materialized
    #|  into the `deps/` directory via `wkg` CLI.
    #|
    #|  Supported formats:
    #|    "wasi:http": "0.2.0"        Version spec
    #|    "my-wit": "./local/path"    Local path
    #|    "pkg": "https://..."        URL
  )
}

///|
fn doc_add() -> String {
  (
    #|# wite add
    #|
    #|Add a dependency to the config deps section.
    #|
    #|## Usage
    #|
    #|  wite add <dep-spec> [options]
    #|
    #|## Flags
    #|
    #|  --protocol=<wkg|warg|oci>   Protocol for resolution (default: wkg)
    #|  --protocol <proto>          (same, space-separated)
    #|  --registry=<host>           Registry host
    #|  --registry <host>           (same, space-separated)
    #|  --name=<id>                 Override dependency name
    #|  --name <id>                 (same, space-separated)
    #|  --config=<path>             Config file path
    #|  --config <path>             (same, space-separated)
    #|  --verify                    Verify after adding
    #|  --no-verify                 Skip verification (default)
    #|
    #|## Example
    #|
    #|  wite add wasi:http@0.2.0
    #|  wite add acme/logger@0.1.0 --protocol=oci
  )
}

///|
fn doc_install() -> String {
  (
    #|# wite install
    #|
    #|Install dependencies from config file. Alias for `wite deps sync`.
    #|
    #|## Usage
    #|
    #|  wite install [options]
    #|
    #|## Flags
    #|
    #|  --config=<path>      Config file path
    #|  --config <path>      (same, space-separated)
    #|  --dir=<path>         Output directory for deps (default: "deps")
    #|  --dir <path>         (same, space-separated)
    #|  --output-dir=<path>  Alias for --dir
    #|  --out-dir=<path>     Alias for --dir
    #|  --verify             Verify each dep before syncing
    #|  --no-verify          Disable verification (default)
    #|  --fail-fast          Stop on first error
    #|  --no-fail-fast       Disable fail-fast (default)
  )
}

///|
fn doc_init() -> String {
  (
    #|# wite init
    #|
    #|Initialize wite project files in the current directory.
    #|
    #|## Usage
    #|
    #|  wite init [--force]
    #|
    #|## Flags
    #|
    #|  --force    Overwrite existing files
    #|
    #|## Generated Files
    #|
    #|  wite.config.ts    TypeScript config template
    #|  main.wac          Starter WAC composition file
  )
}

///|
fn doc_new() -> String {
  (
    #|# wite new
    #|
    #|Create a new guest project from template.
    #|
    #|## Usage
    #|
    #|  wite new [--moonbit|--rust] [--force]
    #|
    #|## Flags
    #|
    #|  --moonbit    Create MoonBit guest template (default)
    #|  --rust       Create Rust/cargo-component guest template
    #|  --force      Overwrite existing files
    #|
    #|## Generated Structure
    #|
    #|  Common files:
    #|    .gitignore
    #|    wite.config.ts
    #|    main.wac
    #|
    #|  MoonBit template (guest/moonbit/):
    #|    moon.mod.json, moon.pkg, guest.mbt, README.md
    #|
    #|  Rust template (guest/rust/):
    #|    Cargo.toml, src/main.rs, README.md
  )
}

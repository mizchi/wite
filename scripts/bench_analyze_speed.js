#!/usr/bin/env node

const { spawnSync } = require("node:child_process")
const fs = require("node:fs")
const path = require("node:path")

function parse_args(argv) {
  const options = {
    iterations: 5,
    include_pglite: false,
    include_duckdb: false,
    output: "bench/kpi/analyze_speed.tsv",
    binary: "target/native/release/build/main/main.exe",
    build_if_missing: true,
  }
  for (const arg of argv) {
    if (arg.startsWith("--iterations=")) {
      const value = Number(arg.slice("--iterations=".length))
      if (!Number.isFinite(value) || value <= 0) {
        throw new Error("--iterations must be a positive number")
      }
      options.iterations = Math.floor(value)
      continue
    }
    if (arg === "--include-pglite") {
      options.include_pglite = true
      continue
    }
    if (arg === "--include-duckdb") {
      options.include_duckdb = true
      continue
    }
    if (arg.startsWith("--output=")) {
      options.output = arg.slice("--output=".length)
      continue
    }
    if (arg.startsWith("--binary=")) {
      options.binary = arg.slice("--binary=".length)
      continue
    }
    if (arg === "--no-build") {
      options.build_if_missing = false
      continue
    }
    throw new Error(`unknown argument: ${arg}`)
  }
  return options
}

function ensure_native_binary(root_dir, binary_path) {
  if (fs.existsSync(binary_path)) {
    return
  }
  const result = spawnSync(
    "moon",
    ["build", "src/main", "--target", "native"],
    {
      cwd: root_dir,
      stdio: "inherit",
      encoding: "utf8",
    },
  )
  if (result.status !== 0) {
    throw new Error("failed to build native binary")
  }
}

function build_cases(options) {
  const zlib = "bench/corpus/core/binaryen/zlib.wasm"
  const cases = [
    {
      name: "core_analyze_summary_zlib",
      args: ["analyze", zlib, "--view=summary", "--kind=core", "--no-config"],
    },
    {
      name: "core_analyze_functions_zlib",
      args: [
        "analyze",
        zlib,
        "--view=functions",
        "--limit=20",
        "--kind=core",
        "--no-config",
      ],
    },
    {
      name: "core_analyze_deep_zlib",
      args: ["analyze", zlib, "--view=deep", "--limit=20", "--kind=core", "--no-config"],
    },
    {
      name: "core_analyze_callgraph_zlib",
      args: [
        "analyze",
        zlib,
        "--view=callgraph",
        "--limit=20",
        "--kind=core",
        "--no-config",
      ],
    },
  ]

  if (options.include_pglite) {
    cases.push({
      name: "core_analyze_summary_pglite",
      args: [
        "analyze",
        "bench/corpus/core/pglite/pglite.wasm",
        "--view=summary",
        "--kind=core",
        "--no-config",
      ],
    })
  }

  if (options.include_duckdb) {
    cases.push({
      name: "core_analyze_summary_duckdb",
      args: [
        "analyze",
        "bench/corpus/core-analyze/duckdb/duckdb-mvp.wasm",
        "--view=summary",
        "--kind=core",
        "--no-config",
      ],
    })
    cases.push({
      name: "core_analyze_callgraph_duckdb",
      args: [
        "analyze",
        "bench/corpus/core-analyze/duckdb/duckdb-mvp.wasm",
        "--view=callgraph",
        "--limit=0",
        "--kind=core",
        "--no-config",
      ],
    })
  }

  return cases
}

function run_one_case(root_dir, binary_path, benchmark_case, iterations) {
  const times_ms = []
  for (let i = 0; i < iterations; i += 1) {
    const t0 = process.hrtime.bigint()
    const result = spawnSync(binary_path, benchmark_case.args, {
      cwd: root_dir,
      stdio: "ignore",
      encoding: "utf8",
    })
    const t1 = process.hrtime.bigint()
    if (result.status !== 0) {
      throw new Error(`benchmark case failed: ${benchmark_case.name}`)
    }
    times_ms.push(Number(t1 - t0) / 1_000_000)
  }
  const mean = times_ms.reduce((a, b) => a + b, 0) / times_ms.length
  const min = Math.min(...times_ms)
  const max = Math.max(...times_ms)
  const sorted = [...times_ms].sort((a, b) => a - b)
  const median =
    sorted.length % 2 === 1
      ? sorted[(sorted.length - 1) / 2]
      : (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2
  const variance =
    times_ms.reduce((a, b) => a + (b - mean) * (b - mean), 0) / times_ms.length
  const stdev = Math.sqrt(variance)
  return {
    name: benchmark_case.name,
    iterations,
    mean_ms: mean,
    min_ms: min,
    max_ms: max,
    median_ms: median,
    stdev_ms: stdev,
  }
}

function format_ms(value) {
  return value.toFixed(3)
}

function main() {
  const root_dir = path.resolve(__dirname, "..")
  const options = parse_args(process.argv.slice(2))
  const binary_path = path.isAbsolute(options.binary)
    ? options.binary
    : path.join(root_dir, options.binary)

  if (options.build_if_missing) {
    ensure_native_binary(root_dir, binary_path)
  } else if (!fs.existsSync(binary_path)) {
    throw new Error(`binary not found: ${binary_path}`)
  }

  const cases = build_cases(options)
  const results = []
  for (const benchmark_case of cases) {
    results.push(
      run_one_case(root_dir, binary_path, benchmark_case, options.iterations),
    )
  }

  const generated_at = new Date().toISOString()
  const output_lines = [
    `# generated_at_utc\t${generated_at}`,
    "benchmark\titerations\tmean_ms\tmedian_ms\tmin_ms\tmax_ms\tstdev_ms",
  ]
  for (const row of results) {
    output_lines.push(
      [
        row.name,
        row.iterations.toString(),
        format_ms(row.mean_ms),
        format_ms(row.median_ms),
        format_ms(row.min_ms),
        format_ms(row.max_ms),
        format_ms(row.stdev_ms),
      ].join("\t"),
    )
  }

  const output_path = path.join(root_dir, options.output)
  fs.mkdirSync(path.dirname(output_path), { recursive: true })
  fs.writeFileSync(output_path, output_lines.join("\n") + "\n", "utf8")

  console.log("benchmark\titerations\tmean_ms\tmedian_ms\tmin_ms\tmax_ms\tstdev_ms")
  for (const row of results) {
    console.log(
      [
        row.name,
        row.iterations.toString(),
        format_ms(row.mean_ms),
        format_ms(row.median_ms),
        format_ms(row.min_ms),
        format_ms(row.max_ms),
        format_ms(row.stdev_ms),
      ].join("\t"),
    )
  }
  console.log(`written:\t${path.relative(root_dir, output_path)}`)
}

main()

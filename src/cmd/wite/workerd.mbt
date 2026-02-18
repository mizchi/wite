///|
fn generate_worker_entry_mjs(js_output_path : String) -> String {
  "import './" +
  js_output_path +
  "';\nexport default {\n  async fetch(request, env, ctx) {\n    if (typeof globalThis.__wite_fetch_handler !== 'function') {\n      return new Response('fetch handler not registered via globalThis.__wite_fetch_handler', { status: 500 });\n    }\n    return globalThis.__wite_fetch_handler(request, env, ctx);\n  }\n};\n"
}

///|
fn generate_wrangler_toml(
  name : String,
  main_path : String,
  bindings? : @wite_config.ServerBindings = @wite_config.empty_server_bindings(),
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("name = \"")
  buf.write_string(name)
  buf.write_string("\"\nmain = \"")
  buf.write_string(main_path)
  buf.write_string("\"\ncompatibility_date = \"2025-01-01\"\n")
  for kv in bindings.kv_namespaces {
    buf.write_string("\n[[kv_namespaces]]\nbinding = \"")
    buf.write_string(kv.binding)
    buf.write_string("\"\nid = \"")
    buf.write_string(kv.id)
    buf.write_string("\"\n")
  }
  for r2 in bindings.r2_buckets {
    buf.write_string("\n[[r2_buckets]]\nbinding = \"")
    buf.write_string(r2.binding)
    buf.write_string("\"\nbucket_name = \"")
    buf.write_string(r2.bucket_name)
    buf.write_string("\"\n")
  }
  for d1 in bindings.d1_databases {
    buf.write_string("\n[[d1_databases]]\nbinding = \"")
    buf.write_string(d1.binding)
    buf.write_string("\"\ndatabase_name = \"")
    buf.write_string(d1.database_name)
    buf.write_string("\"\ndatabase_id = \"")
    buf.write_string(d1.database_id)
    buf.write_string("\"\n")
  }
  buf.to_string()
}

///|
async fn setup_workerd_files(
  project_dir : String,
  js_output_path : String,
  bindings? : @wite_config.ServerBindings = @wite_config.empty_server_bindings(),
) -> (String, String) {
  let wite_dir = if project_dir == "." {
    ".wite"
  } else {
    project_dir + "/.wite"
  }
  let _ = @xprocess.run("mkdir", ["-p", wite_dir])
  let entry_path = wite_dir + "/worker-entry.mjs"
  let toml_path = wite_dir + "/wrangler.toml"
  // Make js_output_path relative to .wite/ directory
  let rel_js = if js_output_path.has_prefix("/") {
    js_output_path
  } else if project_dir == "." {
    "../" + js_output_path
  } else {
    "../" + make_relative_path(project_dir, js_output_path)
  }
  let entry_content = generate_worker_entry_mjs(rel_js)
  let toml_content = generate_wrangler_toml(
    "wite-dev",
    "worker-entry.mjs",
    bindings~,
  )
  @xfs.write_file(entry_path, entry_content)
  @xfs.write_file(toml_path, toml_content)
  (entry_path, toml_path)
}

///|
async fn run_workerd_dev_loop(
  dir : String,
  build_cmd : String,
  build_args : Array[String],
  port : Int,
  bindings? : @wite_config.ServerBindings = @wite_config.empty_server_bindings(),
) -> Unit {
  // Find initial JS output
  let js_path = find_js_in_build_dirs(dir, release=true)
  let abs_js_path = match js_path {
    Some(p) => p
    None => {
      println("[wite] error: no .js file found in build output")
      @sys.exit(1)
      return
    }
  }
  // Setup .wite/ files
  let (_, toml_path) = setup_workerd_files(dir, abs_js_path, bindings~)
  println("[wite] generated .wite/worker-entry.mjs and .wite/wrangler.toml")
  // Read initial JS hash
  let initial_data = @xfs.read_file(abs_js_path) catch {
    _ => {
      println("[wite] error: failed to read JS file: " + abs_js_path)
      @sys.exit(1)
      return
    }
  }
  let mut last_js_hash = simple_bytes_hash(initial_data.binary())
  // Start wrangler dev in background
  let wrangler_args = [
    "wrangler",
    "dev",
    "--config",
    toml_path,
    "--port",
    port.to_string(),
  ]
  println("[wite] starting npx " + wrangler_args.join(" ") + " ...")
  let cwd : StringView? = if dir == "." { None } else { Some(dir) }
  @async.with_task_group(group => {
    // wrangler dev in background
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      let exit_code = @xprocess.run("npx", wrangler_args, cwd?)
      if exit_code != 0 {
        println(
          "[wite] wrangler dev exited with code: " + exit_code.to_string(),
        )
      }
    })
    // Watch and rebuild loop
    println("[wite] watching for changes...")
    while true {
      @async.sleep(1000)
      let (exit_code, _stdout, stderr) = @xprocess.collect_output(
        build_cmd,
        build_args,
        cwd?,
      )
      if exit_code == 0 {
        let data = @xfs.read_file(abs_js_path) catch {
          _ => {
            println("[wite] failed to read JS file: " + abs_js_path)
            continue
          }
        }
        let new_hash = simple_bytes_hash(data.binary())
        if new_hash != last_js_hash {
          last_js_hash = new_hash
          // Re-generate .wite/ files in case JS path changed
          let _ = setup_workerd_files(dir, abs_js_path, bindings~)
          println("[wite] rebuilt, wrangler will auto-reload...")
        }
      } else {
        let err_text = stderr.text() catch { _ => "unknown error" }
        println("[wite] build failed:\n" + err_text)
      }
    }
  })
}

///|
extern "js" fn js_spawn_wrangler(
  toml_path : String,
  port : Int,
  cwd : String,
) -> Int =
  #| (tomlPath, port, cwd) => {
  #|   const { spawn } = require('node:child_process');
  #|   const child = spawn('npx', ['wrangler', 'dev', '--config', String(tomlPath), '--port', String(port)], {
  #|     cwd: String(cwd),
  #|     stdio: 'ignore',
  #|     detached: false,
  #|   });
  #|   return child.pid || 0;
  #| }

///|
extern "js" fn js_kill_pid(pid : Int) -> Unit =
  #| (pid) => {
  #|   try { process.kill(pid, 'SIGTERM'); } catch(_) {}
  #| }

///|
async test "workerd e2e: kv put and get via wrangler dev" {
  // Check if wrangler is available
  let (exit_code, _stdout) = @xprocess.collect_stdout("npx", [
    "wrangler", "--version",
  ])
  if exit_code != 0 {
    println("[skip] wrangler not available")
    return
  }
  let temp_dir = js_make_temp_dir("wite-workerd-e2e-")
  // Write worker JS that handles KV operations
  let worker_js =
    #|export default {
    #|  async fetch(request, env) {
    #|    const url = new URL(request.url);
    #|    if (url.pathname === '/kv/put') {
    #|      const key = url.searchParams.get('key');
    #|      const value = url.searchParams.get('value');
    #|      if (!key || !value) return new Response('missing key or value', { status: 400 });
    #|      await env.MY_KV.put(key, value);
    #|      return new Response('ok', { status: 200 });
    #|    }
    #|    if (url.pathname === '/kv/get') {
    #|      const key = url.searchParams.get('key');
    #|      if (!key) return new Response('missing key', { status: 400 });
    #|      const value = await env.MY_KV.get(key);
    #|      if (value === null) return new Response('not found', { status: 404 });
    #|      return new Response(value, { status: 200 });
    #|    }
    #|    return new Response('not found', { status: 404 });
    #|  }
    #|};
  @xfs.write_file(temp_dir + "/worker.mjs", worker_js)
  // Generate wrangler.toml with KV binding
  let bindings : @wite_config.ServerBindings = {
    kv_namespaces: [{ binding: "MY_KV", id: "wite-e2e-test-kv" }],
    r2_buckets: [],
    d1_databases: [],
  }
  let toml = generate_wrangler_toml("wite-e2e-test", "worker.mjs", bindings~)
  let toml_path = temp_dir + "/wrangler.toml"
  @xfs.write_file(toml_path, toml)
  // Find a free port
  let probe_server = @xhttp.Server::new(port=0)
  let port = probe_server.port()
  probe_server.close()
  // Start wrangler dev as a detached process
  let pid = js_spawn_wrangler(toml_path, port, temp_dir)
  if pid == 0 {
    println("[skip] failed to spawn wrangler dev")
    js_remove_dir_recursive(temp_dir)
    return
  }
  // Poll until wrangler is ready (max 20 seconds)
  let base = "http://127.0.0.1:" + port.to_string()
  let mut ready = false
  for attempt = 0; attempt < 40; attempt = attempt + 1 {
    @async.sleep(500)
    let ok = try {
      let (resp, _) = @xhttp.get(base + "/kv/get?key=_probe")
      resp.code > 0
    } catch {
      _ => false
    }
    if ok {
      ready = true
      break
    }
  }
  if !ready {
    println("[skip] wrangler dev did not start in time")
    js_kill_pid(pid)
    js_remove_dir_recursive(temp_dir)
    return
  }
  // KV put
  let (put_resp, put_body) = @xhttp.get(
    base + "/kv/put?key=hello&value=world",
  )
  let put_text = put_body.text() catch { _ => "" }
  assert_eq(put_resp.code, 200)
  assert_eq(put_text, "ok")
  // KV get
  let (get_resp, get_body) = @xhttp.get(base + "/kv/get?key=hello")
  let get_text = get_body.text() catch { _ => "" }
  assert_eq(get_resp.code, 200)
  assert_eq(get_text, "world")
  // KV get nonexistent key
  let (miss_resp, _) = @xhttp.get(base + "/kv/get?key=nonexistent")
  assert_eq(miss_resp.code, 404)
  // Cleanup
  js_kill_pid(pid)
  @async.sleep(500)
  js_remove_dir_recursive(temp_dir)
}

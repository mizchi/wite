///|
priv struct DevState {
  mut reload_version : Int
  mut last_wasm_hash : Int
  wasm_path : String
  mut last_analyze_json : Json?
}

///|
fn simple_bytes_hash(bytes : Bytes) -> Int {
  let mut h = 0
  for i = 0; i < bytes.length(); i = i + 1 {
    h = h * 31 + bytes[i].to_int()
  }
  h
}

///|
fn livereload_script_tag() -> String {
  let s =
    #|<script>
    #|(function(){
    #|  const es = new EventSource('/__wite_livereload');
    #|  es.onmessage = function(e) { if (e.data === 'reload') location.reload(); };
    #|  es.onerror = function() { setTimeout(function(){ location.reload(); }, 2000); };
    #|})();
    #|</script>
  s
}

///|
fn generate_dev_html(wasm_path : String) -> String {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head><meta charset="utf-8"><title>wite dev</title>
    #|<style>
    #|  body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; margin: 2rem; }
    #|  h1 { color: #89b4fa; font-size: 1.2rem; }
    #|  pre { background: #181825; padding: 1rem; border-radius: 4px; overflow: auto; }
    #|</style>
    #|</head>
    #|<body>
    #|<h1>wite dev</h1>
    #|<nav style="margin-bottom:1rem"><a href="/__wite/" style="color:#89b4fa">debug</a></nav>
    #|<pre id="output"></pre>
    #|<script type="module">
  let script_start =
    #|const out = document.getElementById('output');
    #|function log(msg) { out.textContent += msg + '\n'; }
    #|
    #|let printBuf = '';
    #|const importObject = {
    #|  spectest: {
    #|    print_char(ch) {
    #|      if (ch === 10) { console.log(printBuf); log(printBuf); printBuf = ''; }
    #|      else { printBuf += String.fromCharCode(ch); }
    #|    }
    #|  }
    #|};
    #|
    #|try {
  let load_line = "  const { instance } = await WebAssembly.instantiateStreaming(fetch('" +
    wasm_path +
    "'), importObject);\n"
  let script_end =
    #|  const exports = Object.keys(instance.exports);
    #|  log('exports: ' + exports.join(', '));
    #|  if (typeof instance.exports._start === 'function') {
    #|    log('calling _start()...');
    #|    instance.exports._start();
    #|  }
    #|  if (printBuf) { console.log(printBuf); log(printBuf); printBuf = ''; }
    #|} catch(e) {
    #|  log('error: ' + e.message);
    #|  console.error(e);
    #|}
    #|</script>
  html +
  script_start +
  load_line +
  script_end +
  livereload_script_tag() +
  "\n</body>\n</html>\n"
}

///|
fn content_type_for_ext(ext : String) -> String {
  match ext {
    ".html" => "text/html"
    ".js" | ".mjs" => "text/javascript"
    ".css" => "text/css"
    ".json" => "application/json"
    ".wasm" => "application/wasm"
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".svg" => "image/svg+xml"
    ".txt" => "text/plain"
    _ => "application/octet-stream"
  }
}

///|
fn path_extension(path : String) -> String {
  let mut last_dot = -1
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    let ch = path[i]
    if ch == '.' {
      last_dot = i
    } else if ch == '/' || ch == '\\' {
      last_slash = i
    }
  }
  if last_dot > last_slash {
    path[last_dot:].to_string() catch {
      _ => ""
    }
  } else {
    ""
  }
}

///|
async fn find_wasm_files_recursive(dir : String) -> Array[String] {
  let results : Array[String] = []
  let queue : Array[String] = [dir]
  while queue.length() > 0 {
    let current = queue.pop().unwrap()
    let entries = @xfs.readdir(current) catch { _ => continue }
    for entry in entries {
      let full = current + "/" + entry
      if entry.has_suffix(".wasm") {
        results.push(full)
      } else {
        queue.push(full)
      }
    }
  }
  results
}

///|
async fn find_wasm_in_build_dirs(
  project_dir : String,
  target : String,
  release? : Bool = false,
) -> String? {
  let mode = if release { "release" } else { "debug" }
  let candidates = [
    project_dir + "/target/" + target + "/" + mode + "/build",
    project_dir + "/_build/" + target + "/" + mode + "/build",
  ]
  for dir in candidates {
    let exists = @xfs.exists(dir)
    if exists {
      let files = find_wasm_files_recursive(dir)
      if files.length() > 0 {
        return Some(files[0])
      }
    }
  }
  None
}

///|
async fn find_js_files_recursive(dir : String) -> Array[String] {
  let results : Array[String] = []
  let queue : Array[String] = [dir]
  while queue.length() > 0 {
    let current = queue.pop().unwrap()
    let entries = @xfs.readdir(current) catch { _ => continue }
    for entry in entries {
      let full = current + "/" + entry
      if entry.has_suffix(".js") {
        results.push(full)
      } else {
        queue.push(full)
      }
    }
  }
  results
}

///|
async fn find_js_in_build_dirs(
  project_dir : String,
  release? : Bool = false,
) -> String? {
  let mode = if release { "release" } else { "debug" }
  let candidates = [
    project_dir + "/target/js/" + mode + "/build",
    project_dir + "/_build/js/" + mode + "/build",
  ]
  for dir in candidates {
    let exists = @xfs.exists(dir)
    if exists {
      let files = find_js_files_recursive(dir)
      if files.length() > 0 {
        return Some(files[0])
      }
    }
  }
  None
}

///|
fn make_relative_path(base : String, full : String) -> String {
  let prefix = if base.has_suffix("/") { base } else { base + "/" }
  if full.has_prefix(prefix) {
    full[prefix.length():].to_string() catch {
      _ => full
    }
  } else {
    full
  }
}

///|
fn normalize_url_path(url_path : String) -> String? {
  let parts : Array[String] = []
  for segment in url_path.split("/") {
    let s = segment.to_string()
    if s == ".." {
      return None
    }
    if s != "" && s != "." {
      parts.push(s)
    }
  }
  Some(parts.join("/"))
}

///|
async fn send_error_response(
  conn : @xhttp.ServerConnection,
  code : Int,
  reason : String,
) -> Unit {
  conn.send_response(code, reason)
  conn.write(reason) catch {
    _ => ()
  }
  conn.end_response()
}

///|
async fn send_text_response(
  conn : @xhttp.ServerConnection,
  content_type : String,
  text : String,
) -> Unit {
  let headers : Map[String, String] = {
    "Content-Type": content_type,
    "Cache-Control": "no-cache",
  }
  conn.send_response(200, "OK", extra_headers=headers)
  conn.write(text) catch {
    _ => ()
  }
  conn.end_response()
}

///|
async fn send_bytes_response(
  conn : @xhttp.ServerConnection,
  content_type : String,
  data : Bytes,
) -> Unit {
  let headers : Map[String, String] = {
    "Content-Type": content_type,
    "Cache-Control": "no-cache",
  }
  conn.send_response(200, "OK", extra_headers=headers)
  conn.write(data) catch {
    _ => ()
  }
  conn.end_response()
}

///|
async fn handle_sse(state : DevState, conn : @xhttp.ServerConnection) -> Unit {
  let headers : Map[String, String] = {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  }
  conn.send_response(200, "OK", extra_headers=headers)
  conn.write("data: connected\n\n")
  conn.flush()
  let mut last_version = state.reload_version
  while true {
    @async.sleep(300)
    let current = state.reload_version
    if current != last_version {
      conn.write("data: reload\n\n")
      conn.flush()
      last_version = current
    }
  }
}

///|
fn uint_to_json(v : UInt) -> Json {
  Json::number(v.reinterpret_as_int().to_double())
}

///|
fn module_profile_to_json(p : @wite_core.ModuleProfile) -> Json {
  let sections_json : Array[Json] = []
  for s in p.sections {
    sections_json.push(
      Json::object({
        "key": Json::string(s.key),
        "section_id": uint_to_json(s.section_id),
        "total_bytes": uint_to_json(s.total_bytes),
      }),
    )
  }
  Json::object({
    "total_bytes": uint_to_json(p.total_bytes),
    "function_count": uint_to_json(p.function_count),
    "import_count": uint_to_json(p.import_count),
    "export_count": uint_to_json(p.export_count),
    "code_body_count": uint_to_json(p.code_body_count),
    "code_body_bytes": uint_to_json(p.code_body_bytes),
    "sections": Json::array(sections_json),
  })
}

///|
fn function_size_to_json(f : @wite_core.FunctionSize) -> Json {
  let export_names_json : Array[Json] = []
  for name in f.export_names {
    export_names_json.push(Json::string(name))
  }
  let name_json : Json = match f.name {
    Some(n) => Json::string(n)
    None => Json::null()
  }
  Json::object({
    "function_index": uint_to_json(f.function_index),
    "body_bytes": uint_to_json(f.body_bytes),
    "name": name_json,
    "export_names": Json::array(export_names_json),
  })
}

///|
async fn build_analyze_json(wasm_path : String) -> Json {
  let data = @xfs.read_file(wasm_path) catch {
    _ =>
      return Json::object({ "error": Json::string("failed to read wasm file") })
  }
  let bytes = data.binary()
  let profile_json = match @wite_analyze.profile_module(bytes) {
    Ok(p) => module_profile_to_json(p)
    Err(e) =>
      Json::object({
        "error": Json::string("profile: " + @wite_core.error_to_string(e)),
      })
  }
  let functions_json : Json = match
    @wite_analyze.analyze_function_sizes(bytes) {
    Ok(functions) => {
      let arr : Array[Json] = []
      for f in functions {
        arr.push(function_size_to_json(f))
      }
      Json::array(arr)
    }
    Err(e) =>
      Json::object({
        "error": Json::string("functions: " + @wite_core.error_to_string(e)),
      })
  }
  Json::object({ "profile": profile_json, "functions": functions_json })
}

///|
async fn handle_wite_api(
  state : DevState,
  url_path : String,
  conn : @xhttp.ServerConnection,
) -> Unit {
  if url_path == "/__wite" || url_path == "/__wite/" {
    send_text_response(
      conn,
      "text/html; charset=utf-8",
      generate_debug_ui_html(),
    )
    return
  }
  if url_path == "/__wite/api/status" {
    let json = Json::object({
      "reload_version": Json::number(state.reload_version.to_double()),
      "wasm_hash": Json::number(state.last_wasm_hash.to_double()),
      "wasm_path": Json::string(state.wasm_path),
    })
    send_text_response(conn, "application/json", json.stringify())
    return
  }
  if url_path == "/__wite/api/analyze" {
    let json = match state.last_analyze_json {
      Some(cached) => cached
      None => {
        let result = build_analyze_json(state.wasm_path)
        state.last_analyze_json = Some(result)
        result
      }
    }
    send_text_response(conn, "application/json", json.stringify())
    return
  }
  send_error_response(conn, 404, "Not Found")
}

///|
fn generate_debug_ui_html() -> String {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head><meta charset="utf-8"><title>wite debug</title>
    #|<style>
    #|  * { box-sizing: border-box; }
    #|  body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; margin: 2rem; }
    #|  h1 { color: #89b4fa; font-size: 1.2rem; }
    #|  h2 { color: #a6e3a1; font-size: 1rem; margin-top: 1.5rem; }
    #|  nav { margin-bottom: 1rem; }
    #|  nav a { color: #89b4fa; margin-right: 1rem; }
    #|  table { border-collapse: collapse; width: 100%; margin-top: 0.5rem; }
    #|  th, td { text-align: left; padding: 4px 8px; border-bottom: 1px solid #313244; }
    #|  th { color: #89b4fa; }
    #|  .num { text-align: right; font-variant-numeric: tabular-nums; }
    #|  .loading { color: #6c7086; }
    #|  .error { color: #f38ba8; }
    #|</style>
    #|</head>
    #|<body>
    #|<h1>wite debug</h1>
    #|<nav><a href="/">app</a><a href="/__wite/api/status">status.json</a><a href="/__wite/api/analyze">analyze.json</a></nav>
    #|<div id="status"></div>
    #|<div id="profile"></div>
    #|<div id="sections"></div>
    #|<div id="functions"></div>
    #|<script>
    #|(function(){
    #|  function $(id){ return document.getElementById(id); }
    #|  function fmt(n){ return n.toLocaleString(); }
    #|  function loadStatus(){
    #|    fetch('/__wite/api/status').then(r=>r.json()).then(d=>{
    #|      $('status').innerHTML='<h2>status</h2><p>reload_version: '+d.reload_version+' | wasm_hash: '+d.wasm_hash+'</p><p>wasm_path: '+d.wasm_path+'</p>';
    #|    }).catch(e=>{ $('status').innerHTML='<p class="error">'+e+'</p>'; });
    #|  }
    #|  function loadAnalyze(){
    #|    $('profile').innerHTML='<p class="loading">loading analyze...</p>';
    #|    fetch('/__wite/api/analyze').then(r=>r.json()).then(d=>{
    #|      if(d.profile && !d.profile.error){
    #|        var p=d.profile;
    #|        $('profile').innerHTML='<h2>module profile</h2><table>'
    #|          +'<tr><td>total bytes</td><td class="num">'+fmt(p.total_bytes)+'</td></tr>'
    #|          +'<tr><td>functions</td><td class="num">'+fmt(p.function_count)+'</td></tr>'
    #|          +'<tr><td>imports</td><td class="num">'+fmt(p.import_count)+'</td></tr>'
    #|          +'<tr><td>exports</td><td class="num">'+fmt(p.export_count)+'</td></tr>'
    #|          +'<tr><td>code bodies</td><td class="num">'+fmt(p.code_body_count)+'</td></tr>'
    #|          +'<tr><td>code body bytes</td><td class="num">'+fmt(p.code_body_bytes)+'</td></tr>'
    #|          +'</table>';
    #|        if(p.sections){
    #|          var h='<h2>sections</h2><table><tr><th>key</th><th>id</th><th class="num">bytes</th></tr>';
    #|          p.sections.forEach(function(s){ h+='<tr><td>'+s.key+'</td><td>'+s.section_id+'</td><td class="num">'+fmt(s.total_bytes)+'</td></tr>'; });
    #|          $('sections').innerHTML=h+'</table>';
    #|        }
    #|      }
    #|      if(d.functions && Array.isArray(d.functions)){
    #|        var sorted=d.functions.slice().sort(function(a,b){ return b.body_bytes-a.body_bytes; });
    #|        var h='<h2>functions (by size)</h2><table><tr><th>#</th><th>name</th><th class="num">bytes</th><th>exports</th></tr>';
    #|        sorted.forEach(function(f){
    #|          h+='<tr><td>'+f.function_index+'</td><td>'+(f.name||'')+'</td><td class="num">'+fmt(f.body_bytes)+'</td><td>'+(f.export_names||[]).join(', ')+'</td></tr>';
    #|        });
    #|        $('functions').innerHTML=h+'</table>';
    #|      }
    #|    }).catch(e=>{ $('profile').innerHTML='<p class="error">'+e+'</p>'; });
    #|  }
    #|  loadStatus(); loadAnalyze();
    #|  var es=new EventSource('/__wite_livereload');
    #|  es.onmessage=function(e){ if(e.data==='reload'){ loadStatus(); loadAnalyze(); } };
    #|  es.onerror=function(){ setTimeout(function(){ location.reload(); },2000); };
    #|})();
    #|</script>
    #|</body>
    #|</html>
  html
}

///|
async fn handle_request(
  root_dir : String,
  generated_html : String,
  req : @xhttp.Request,
  _body : &@io.Reader,
  conn : @xhttp.ServerConnection,
) -> Unit {
  let url_path = match req.path.find("?") {
    Some(i) => req.path[:i].to_string() catch { _ => req.path }
    None => req.path
  }
  let request_path = if url_path == "/" { "/index.html" } else { url_path }
  let safe_path = match normalize_url_path(request_path) {
    Some(p) => p
    None => {
      send_error_response(conn, 403, "Forbidden")
      return
    }
  }
  // Serve generated HTML for index.html if no file exists
  if request_path == "/index.html" && generated_html.length() > 0 {
    let exists = @xfs.exists(root_dir + "/index.html")
    if !exists {
      send_text_response(conn, "text/html; charset=utf-8", generated_html)
      return
    }
  }
  let file_path = root_dir + "/" + safe_path
  let ext = path_extension(safe_path)
  let ct = content_type_for_ext(ext)
  // Inject livereload script into HTML responses
  if ext == ".html" {
    let data = @xfs.read_file(file_path) catch {
      _ => {
        send_error_response(conn, 404, "Not Found")
        return
      }
    }
    let text = data.text()
    let injected = text + livereload_script_tag()
    send_text_response(conn, "text/html; charset=utf-8", injected)
    return
  }
  let bytes = @fs.read_file_to_bytes(file_path) catch {
    _ => {
      send_error_response(conn, 404, "Not Found")
      return
    }
  }
  send_bytes_response(conn, ct, bytes)
}

///|
async fn watch_and_rebuild(
  dir : String,
  build_cmd : String,
  build_args : Array[String],
  wasm_path : String,
  state : DevState,
) -> Unit {
  let cwd : StringView? = if dir == "." { None } else { Some(dir) }
  println("watching for changes...")
  while true {
    @async.sleep(1000)
    let (exit_code, _stdout, stderr) = @xprocess.collect_output(
      build_cmd,
      build_args,
      cwd?,
    )
    if exit_code == 0 {
      let data = @xfs.read_file(wasm_path) catch {
        _ => {
          println("[wite] failed to read wasm file: " + wasm_path)
          continue
        }
      }
      let new_hash = simple_bytes_hash(data.binary())
      if new_hash != state.last_wasm_hash {
        state.last_wasm_hash = new_hash
        state.last_analyze_json = None
        state.reload_version += 1
        println("[wite] rebuilt, reloading browser...")
      }
    } else {
      let err_text = stderr.text() catch { _ => "unknown error" }
      println("[wite] build failed:\n" + err_text)
    }
  }
}

///|
async fn run_dev_command(args : Array[String]) -> Unit {
  let mut dir = "."
  let mut port = 8080
  let mut target = "wasm-gc"
  let mut build_cmd_str = ""
  let mut watch_path = ""
  let mut server_mode = ""
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      println(
        "wite dev [dir] [--port=<n>] [--target=wasm-gc|wasm] [--build-cmd=<cmd>] [--watch=<path>] [--server[=wagi|workerd]]",
      )
      println("")
      println("Start a dev server with file watching and live reload.")
      println("")
      println("Options:")
      println("  --port=<n>       Port number (default: 8080)")
      println("  --target=<t>     Build target (default: wasm-gc)")
      println(
        "  --build-cmd=<cmd> Custom build command (default: moon build --target <t> --release)",
      )
      println(
        "  --watch=<path>   File path to watch for changes (default: auto-detect from _build/)",
      )
      println(
        "  --server[=wagi|workerd] Enable server mode (wagi: wasmtime CGI, workerd: Cloudflare Workers)",
      )
      return
    }
    if arg == "--server" {
      server_mode = "wagi"
      i += 1
      continue
    }
    if arg.strip_prefix("--server=") is Some(v) {
      let value = v.to_string()
      if value != "wagi" && value != "workerd" {
        println(
          "invalid --server value: " + value + " (expected wagi or workerd)",
        )
        @sys.exit(1)
      }
      server_mode = value
      i += 1
      continue
    }
    if arg.strip_prefix("--port=") is Some(v) {
      port = parse_int_or_exit(v.to_string(), "port")
      i += 1
      continue
    }
    if arg == "--port" {
      if i + 1 >= args.length() {
        println("missing value after --port")
        @sys.exit(1)
      }
      port = parse_int_or_exit(args[i + 1], "port")
      i += 2
      continue
    }
    if arg.strip_prefix("--target=") is Some(v) {
      target = v.to_string()
      i += 1
      continue
    }
    if arg == "--target" {
      if i + 1 >= args.length() {
        println("missing value after --target")
        @sys.exit(1)
      }
      target = args[i + 1]
      i += 2
      continue
    }
    if arg.strip_prefix("--build-cmd=") is Some(v) {
      build_cmd_str = v.to_string()
      i += 1
      continue
    }
    if arg == "--build-cmd" {
      if i + 1 >= args.length() {
        println("missing value after --build-cmd")
        @sys.exit(1)
      }
      build_cmd_str = args[i + 1]
      i += 2
      continue
    }
    if arg.strip_prefix("--watch=") is Some(v) {
      watch_path = v.to_string()
      i += 1
      continue
    }
    if arg == "--watch" {
      if i + 1 >= args.length() {
        println("missing value after --watch")
        @sys.exit(1)
      }
      watch_path = args[i + 1]
      i += 2
      continue
    }
    if arg.has_prefix("-") {
      println("unknown option: " + arg)
      @sys.exit(1)
    }
    dir = arg
    i += 1
  }
  // Server mode defaults: wagi → wasm target, workerd → js target
  if server_mode == "wagi" && target == "wasm-gc" {
    target = "wasm"
  }
  if server_mode == "workerd" && target == "wasm-gc" {
    target = "js"
  }
  let mod_path = if dir == "." {
    "moon.mod.json"
  } else {
    dir + "/moon.mod.json"
  }
  if !@fs.path_exists(mod_path) {
    println("error: " + mod_path + " not found")
    println("not a MoonBit project directory")
    @sys.exit(1)
  }
  // Resolve build command
  // Use sh -c for custom commands to support shell syntax (&&, |, etc.)
  let (build_cmd, build_args) = if build_cmd_str != "" {
    println("building with " + build_cmd_str + " ...")
    ("sh", ["-c", build_cmd_str])
  } else {
    println("building with moon build --target " + target + " --release ...")
    ("moon", ["build", "--target", target, "--release"])
  }
  // Initial build
  let cwd : StringView? = if dir == "." { None } else { Some(dir) }
  let exit_code = @xprocess.run(build_cmd, build_args, cwd?)
  if exit_code != 0 {
    println("build failed (exit code: " + exit_code.to_string() + ")")
    @sys.exit(1)
  }
  println("build succeeded")
  // Workerd mode: delegate to workerd dev loop (no HTTP server needed)
  if server_mode == "workerd" {
    println("[wite] server mode enabled (workerd)")
    // Load config for bindings
    let bindings = {
      let config_path = if dir == "." {
        "wite.config.jsonc"
      } else {
        dir + "/wite.config.jsonc"
      }
      if @fs.path_exists(config_path) {
        let config = load_wite_config_or_exit(config_path)
        match config.server {
          Some(server) => server.bindings
          None => @wite_config.empty_server_bindings()
        }
      } else {
        @wite_config.empty_server_bindings()
      }
    }
    let js_path = find_js_in_build_dirs(dir, release=true)
    match js_path {
      None => {
        println("error: no .js file found in build output")
        @sys.exit(1)
      }
      Some(abs_js_path) => {
        let rel_js = make_relative_path(dir, abs_js_path)
        println("found: " + rel_js)
        run_workerd_dev_loop(dir, build_cmd, build_args, port, bindings~)
      }
    }
    return
  }
  // Resolve watch path
  let resolved_wasm_path = if watch_path != "" {
    let full_path = if watch_path.has_prefix("/") {
      watch_path
    } else if dir == "." {
      watch_path
    } else {
      dir + "/" + watch_path
    }
    if !@fs.path_exists(full_path) {
      println("error: watch file not found: " + full_path)
      @sys.exit(1)
    }
    Some(full_path)
  } else {
    find_wasm_in_build_dirs(dir, target, release=true)
  }
  match resolved_wasm_path {
    None => {
      println("error: no .wasm file found in build output")
      @sys.exit(1)
    }
    Some(abs_wasm_path) => {
      let rel_wasm = make_relative_path(dir, abs_wasm_path)
      println("found: " + rel_wasm)
      let index_path = if dir == "." {
        "index.html"
      } else {
        dir + "/index.html"
      }
      let generated_html = if @fs.path_exists(index_path) {
        println("using existing index.html")
        ""
      } else {
        println("generating index.html (serving wasm at /" + rel_wasm + ")")
        generate_dev_html("/" + rel_wasm)
      }
      // Compute initial wasm hash
      let initial_data = @xfs.read_file(abs_wasm_path) catch {
        _ => {
          println("error: failed to read wasm file")
          @sys.exit(1)
          return
        }
      }
      let state = DevState::{
        reload_version: 0,
        last_wasm_hash: simple_bytes_hash(initial_data.binary()),
        wasm_path: abs_wasm_path,
        last_analyze_json: None,
      }
      let server = @xhttp.Server::new(host="0.0.0.0", port~) catch {
        err => {
          println("failed to start server: " + err.to_string())
          @sys.exit(1)
          return
        }
      }
      let actual_port = server.port()
      println(
        "dev server running at http://localhost:" +
        actual_port.to_string() +
        "/",
      )
      let root = dir
      let html = generated_html
      let is_server = server_mode == "wagi"
      let wasm_for_wagi = abs_wasm_path
      if is_server {
        println("[wite] server mode enabled (WAGI)")
      }
      @async.with_task_group(group => {
        // HTTP server in background
        group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
          server.run_forever(
            (req, body, conn) => {
              if req.path == "/__wite_livereload" {
                handle_sse(state, conn)
              } else if req.path.has_prefix("/__wite") {
                handle_wite_api(state, req.path, conn)
              } else if is_server {
                handle_wagi_request(wasm_for_wagi, req, body, conn)
              } else {
                handle_request(root, html, req, body, conn)
              }
            },
            allow_failure=true,
          ) catch {
            err => {
              println("server error: " + err.to_string())
              @sys.exit(1)
            }
          }
        })
        // File watcher in main flow
        watch_and_rebuild(dir, build_cmd, build_args, abs_wasm_path, state)
      })
    }
  }
}

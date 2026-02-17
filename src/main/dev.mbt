///|
priv struct DevState {
  mut reload_version : Int
  mut last_wasm_hash : Int
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
fn split_command(cmd_str : String) -> (String, Array[String]) {
  let parts : Array[String] = []
  for part in cmd_str.split(" ") {
    let s = part.to_string()
    if s != "" {
      parts.push(s)
    }
  }
  if parts.length() == 0 {
    ("", [])
  } else {
    let cmd = parts[0]
    let args : Array[String] = []
    for i = 1; i < parts.length(); i = i + 1 {
      args.push(parts[i])
    }
    (cmd, args)
  }
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
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      println(
        "wite dev [dir] [--port=<n>] [--target=wasm-gc|wasm] [--build-cmd=<cmd>] [--watch=<path>]",
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
      return
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
  let (build_cmd, build_args) = if build_cmd_str != "" {
    let (cmd, args) = split_command(build_cmd_str)
    println("building with " + build_cmd_str + " ...")
    (cmd, args)
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
      @async.with_task_group(group => {
        // HTTP server in background
        group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
          server.run_forever(
            (req, body, conn) => {
              if req.path == "/__wite_livereload" {
                handle_sse(state, conn)
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

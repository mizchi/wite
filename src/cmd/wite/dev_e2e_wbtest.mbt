///|
async test "dev server: generated html when no index.html exists" {
  let temp_dir = js_make_temp_dir("wite-dev-e2e-")
  let wasm_magic : Bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00"
  @xfs.write_file(temp_dir + "/test.wasm", wasm_magic)
  let state = DevState::{
    reload_version: 0,
    last_wasm_hash: 0,
    wasm_path: "",
    last_analyze_json: None,
  }
  let html = generate_dev_html("/test.wasm")
  let server = @xhttp.Server::new(port=0)
  let port = server.port()
  let root = temp_dir
  let html_copy = html
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      server.run_forever(
        (req, body, conn) => {
          if req.path == "/__wite_livereload" {
            handle_sse(state, conn)
          } else {
            handle_request(root, html_copy, req, body, conn)
          }
        },
        allow_failure=true,
      )
    })
    @async.sleep(100)
    let base = "http://127.0.0.1:" + port.to_string()
    // GET / should return generated HTML (no index.html exists)
    let (resp, body) = @xhttp.get(base + "/")
    assert_eq(resp.code, 200)
    let text = body.text() catch { _ => "" }
    assert_true(text.contains("<title>wite dev</title>"))
    assert_true(text.contains("WebAssembly.instantiateStreaming"))
    assert_true(text.contains("/test.wasm"))
    assert_true(text.contains("__wite_livereload"))
    assert_eq(
      resp.headers.get("content-type"),
      Some("text/html; charset=utf-8"),
    )
    // GET /test.wasm should return the wasm file
    let (wasm_resp, wasm_body) = @xhttp.get(base + "/test.wasm")
    assert_eq(wasm_resp.code, 200)
    assert_eq(wasm_resp.headers.get("content-type"), Some("application/wasm"))
    let wasm_bytes = wasm_body.binary()
    assert_eq(wasm_bytes.length(), 8)
    assert_eq(wasm_bytes[0], b'\x00')
    assert_eq(wasm_bytes[1], b'\x61')
    assert_eq(wasm_bytes[2], b'\x73')
    assert_eq(wasm_bytes[3], b'\x6d')
    // GET /nonexistent should return 404
    let (not_found_resp, _) = @xhttp.get(base + "/nonexistent.txt")
    assert_eq(not_found_resp.code, 404)
  })
  server.close()
  js_remove_dir_recursive(temp_dir)
}

///|
async test "dev server: existing index.html gets livereload injected" {
  let temp_dir = js_make_temp_dir("wite-dev-e2e-")
  let user_html = "<html><head><title>My App</title></head><body><h1>Hello</h1></body></html>"
  @xfs.write_file(temp_dir + "/index.html", user_html)
  let state = DevState::{
    reload_version: 0,
    last_wasm_hash: 0,
    wasm_path: "",
    last_analyze_json: None,
  }
  let server = @xhttp.Server::new(port=0)
  let port = server.port()
  let root = temp_dir
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      server.run_forever(
        (req, body, conn) => {
          if req.path == "/__wite_livereload" {
            handle_sse(state, conn)
          } else {
            // Pass empty generated_html so existing index.html is served
            handle_request(root, "", req, body, conn)
          }
        },
        allow_failure=true,
      )
    })
    @async.sleep(100)
    let base = "http://127.0.0.1:" + port.to_string()
    // GET / should return existing index.html with livereload injected
    let (resp, body) = @xhttp.get(base + "/")
    assert_eq(resp.code, 200)
    let text = body.text() catch { _ => "" }
    assert_true(text.contains("<title>My App</title>"))
    assert_true(text.contains("<h1>Hello</h1>"))
    // Livereload script should be injected
    assert_true(text.contains("__wite_livereload"))
    assert_true(text.contains("EventSource"))
  })
  server.close()
  js_remove_dir_recursive(temp_dir)
}

///|
async test "dev server: static files with correct content-type" {
  let temp_dir = js_make_temp_dir("wite-dev-e2e-")
  @xfs.write_file(temp_dir + "/app.js", "console.log('hello');")
  @xfs.write_file(temp_dir + "/style.css", "body { color: red; }")
  @xfs.write_file(temp_dir + "/data.json", "{\"key\": \"value\"}")
  let state = DevState::{
    reload_version: 0,
    last_wasm_hash: 0,
    wasm_path: "",
    last_analyze_json: None,
  }
  let server = @xhttp.Server::new(port=0)
  let port = server.port()
  let root = temp_dir
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      server.run_forever(
        (req, body, conn) => {
          if req.path == "/__wite_livereload" {
            handle_sse(state, conn)
          } else {
            handle_request(root, "", req, body, conn)
          }
        },
        allow_failure=true,
      )
    })
    @async.sleep(100)
    let base = "http://127.0.0.1:" + port.to_string()
    // JS file
    let (js_resp, js_body) = @xhttp.get(base + "/app.js")
    assert_eq(js_resp.code, 200)
    assert_eq(js_resp.headers.get("content-type"), Some("text/javascript"))
    let js_text = js_body.text() catch { _ => "" }
    assert_eq(js_text, "console.log('hello');")
    // CSS file
    let (css_resp, css_body) = @xhttp.get(base + "/style.css")
    assert_eq(css_resp.code, 200)
    assert_eq(css_resp.headers.get("content-type"), Some("text/css"))
    let css_text = css_body.text() catch { _ => "" }
    assert_eq(css_text, "body { color: red; }")
    // JSON file
    let (json_resp, json_body) = @xhttp.get(base + "/data.json")
    assert_eq(json_resp.code, 200)
    assert_eq(json_resp.headers.get("content-type"), Some("application/json"))
    let json_text = json_body.text() catch { _ => "" }
    assert_eq(json_text, "{\"key\": \"value\"}")
    // 404 for nonexistent files
    let (miss_resp, _) = @xhttp.get(base + "/missing.txt")
    assert_eq(miss_resp.code, 404)
  })
  server.close()
  js_remove_dir_recursive(temp_dir)
}

///|
async test "dev server: wite api status endpoint" {
  let temp_dir = js_make_temp_dir("wite-dev-e2e-")
  let wasm_magic : Bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00"
  let wasm_file = temp_dir + "/test.wasm"
  @xfs.write_file(wasm_file, wasm_magic)
  let state = DevState::{
    reload_version: 3,
    last_wasm_hash: 12345,
    wasm_path: wasm_file,
    last_analyze_json: None,
  }
  let html = generate_dev_html("/test.wasm")
  let server = @xhttp.Server::new(port=0)
  let port = server.port()
  let root = temp_dir
  let html_copy = html
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      server.run_forever(
        (req, body, conn) => {
          if req.path == "/__wite_livereload" {
            handle_sse(state, conn)
          } else if req.path.has_prefix("/__wite") {
            handle_wite_api(state, req.path, conn)
          } else {
            handle_request(root, html_copy, req, body, conn)
          }
        },
        allow_failure=true,
      )
    })
    @async.sleep(100)
    let base = "http://127.0.0.1:" + port.to_string()
    let (resp, body) = @xhttp.get(base + "/__wite/api/status")
    assert_eq(resp.code, 200)
    assert_eq(resp.headers.get("content-type"), Some("application/json"))
    let text = body.text() catch { _ => "" }
    assert_true(text.contains("\"reload_version\""))
    assert_true(text.contains("\"wasm_hash\""))
    assert_true(text.contains("\"wasm_path\""))
  })
  server.close()
  js_remove_dir_recursive(temp_dir)
}

///|
async test "dev server: wite debug ui page" {
  let temp_dir = js_make_temp_dir("wite-dev-e2e-")
  let wasm_magic : Bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00"
  let wasm_file = temp_dir + "/test.wasm"
  @xfs.write_file(wasm_file, wasm_magic)
  let state = DevState::{
    reload_version: 0,
    last_wasm_hash: 0,
    wasm_path: wasm_file,
    last_analyze_json: None,
  }
  let server = @xhttp.Server::new(port=0)
  let port = server.port()
  let root = temp_dir
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      server.run_forever(
        (req, body, conn) => {
          if req.path == "/__wite_livereload" {
            handle_sse(state, conn)
          } else if req.path.has_prefix("/__wite") {
            handle_wite_api(state, req.path, conn)
          } else {
            handle_request(root, "", req, body, conn)
          }
        },
        allow_failure=true,
      )
    })
    @async.sleep(100)
    let base = "http://127.0.0.1:" + port.to_string()
    let (resp, body) = @xhttp.get(base + "/__wite/")
    assert_eq(resp.code, 200)
    assert_eq(
      resp.headers.get("content-type"),
      Some("text/html; charset=utf-8"),
    )
    let text = body.text() catch { _ => "" }
    assert_true(text.contains("<title>wite debug</title>"))
    assert_true(text.contains("/__wite/api/analyze"))
    assert_true(text.contains("/__wite/api/status"))
  })
  server.close()
  js_remove_dir_recursive(temp_dir)
}

///|
async test "dev server: wite api analyze endpoint" {
  let temp_dir = js_make_temp_dir("wite-dev-e2e-")
  let wasm_file = temp_dir + "/test.wasm"
  @xfs.write_file(wasm_file, b"\x00\x61\x73\x6d\x01\x00\x00\x00")
  // Pre-populate analyze cache to avoid async file I/O in handler
  let cached_json = Json::object({
    "profile": Json::object({
      "total_bytes": Json::number(100.0),
      "function_count": Json::number(5.0),
      "import_count": Json::number(1.0),
      "export_count": Json::number(2.0),
      "code_body_count": Json::number(3.0),
      "code_body_bytes": Json::number(50.0),
      "sections": Json::array([]),
    }),
    "functions": Json::array([]),
  })
  let state = DevState::{
    reload_version: 0,
    last_wasm_hash: 0,
    wasm_path: wasm_file,
    last_analyze_json: Some(cached_json),
  }
  let server = @xhttp.Server::new(port=0)
  let port = server.port()
  let root = temp_dir
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, async fn() {
      server.run_forever(
        (req, body, conn) => {
          if req.path == "/__wite_livereload" {
            handle_sse(state, conn)
          } else if req.path.has_prefix("/__wite") {
            handle_wite_api(state, req.path, conn)
          } else {
            handle_request(root, "", req, body, conn)
          }
        },
        allow_failure=true,
      )
    })
    @async.sleep(100)
    let base = "http://127.0.0.1:" + port.to_string()
    let (resp, body) = @xhttp.get(base + "/__wite/api/analyze")
    assert_eq(resp.code, 200)
    assert_eq(resp.headers.get("content-type"), Some("application/json"))
    let text = body.text() catch { _ => "" }
    assert_true(text.contains("\"profile\""))
    assert_true(text.contains("\"functions\""))
    assert_true(text.contains("\"total_bytes\""))
    assert_true(text.contains("\"function_count\""))
  })
  server.close()
  js_remove_dir_recursive(temp_dir)
}

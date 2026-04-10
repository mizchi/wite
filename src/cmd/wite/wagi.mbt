///|
struct WagiResponse {
  status : Int
  headers : Map[String, String]
  body : String
}

///|
fn request_method_string(meth : @xhttp.RequestMethod) -> String {
  match meth {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
fn try_parse_int(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let mut value = 0
  let mut has_digit = false
  for ch in s {
    let code = ch.to_int()
    if code >= 48 && code <= 57 {
      value = value * 10 + (code - 48)
      has_digit = true
    } else {
      break
    }
  }
  if has_digit {
    Some(value)
  } else {
    None
  }
}

///|
fn parse_wagi_response(raw : String) -> WagiResponse {
  // Find the blank line separating headers from body
  let header_end = raw.find("\r\n\r\n")
  let (header_section, body) = match header_end {
    Some(i) => {
      let h = raw[:i].to_string()
      let b = raw[i + 4:].to_string()
      (h, b)
    }
    None =>
      match raw.find("\n\n") {
        Some(i) => {
          let h = raw[:i].to_string()
          let b = raw[i + 2:].to_string()
          (h, b)
        }
        None => (raw, "")
      }
  }
  let headers : Map[String, String] = {}
  let mut status = 200
  for line in header_section.split("\n") {
    let line_str = line.to_string().trim_end(chars="\r").to_string()
    if line_str == "" {
      continue
    }
    match line_str.find(":") {
      Some(colon_idx) => {
        let key = line_str[:colon_idx].to_string()
        let value = line_str[colon_idx + 1:]
          .to_string()
          .trim_start(chars=" ")
          .to_string()
        if key.to_lower() == "status" {
          for part in value.split(" ") {
            let part_str = part.to_string()
            if part_str != "" {
              match try_parse_int(part_str) {
                Some(code) => status = code
                None => ()
              }
              break
            }
          }
        } else {
          headers[key] = value
        }
      }
      None => ()
    }
  }
  if !headers.contains("Content-Type") {
    headers["Content-Type"] = "text/plain"
  }
  { status, headers, body }
}

///|
fn build_wagi_env_args(
  meth : String,
  path : String,
  headers : Map[String, String],
) -> Array[String] {
  let args : Array[String] = []
  args.push("--env")
  args.push("REQUEST_METHOD=" + meth)
  args.push("--env")
  args.push("PATH_INFO=" + path)
  args.push("--env")
  args.push("SERVER_PROTOCOL=HTTP/1.1")
  args.push("--env")
  args.push("GATEWAY_INTERFACE=CGI/1.1")
  for entry in headers {
    let key = entry.0
    let value = entry.1
    if key.to_lower() == "content-type" {
      args.push("--env")
      args.push("CONTENT_TYPE=" + value)
    } else {
      let env_key = "HTTP_" + key.to_upper().replace_all(old="-", new="_")
      args.push("--env")
      args.push(env_key + "=" + value)
    }
  }
  args
}

///|
async fn execute_wagi(
  wasm_path : String,
  meth : String,
  path : String,
  headers : Map[String, String],
) -> WagiResponse {
  let args : Array[String] = ["run"]
  let env_args = build_wagi_env_args(meth, path, headers)
  args.append(env_args[:])
  args.push(wasm_path)
  args.push("--")
  args.push(path)
  let (exit_code, stdout, stderr) = @xprocess.collect_output(
    "wasmtime",
    args[:],
  )
  if exit_code != 0 {
    let err_text = stderr.text() catch { _ => "unknown error" }
    return {
      status: 502,
      headers: { "Content-Type": "text/plain" },
      body: "WAGI execution failed (exit code: " +
      exit_code.to_string() +
      ")\n" +
      err_text,
    }
  }
  let raw = stdout.text() catch { _ => "" }
  parse_wagi_response(raw)
}

///|
async fn handle_wagi_request(
  wasm_path : String,
  req : @xhttp.Request,
  _body : &@io.Reader,
  conn : @xhttp.ServerConnection,
) -> Unit {
  let meth_str = request_method_string(req.meth)
  let response = execute_wagi(wasm_path, meth_str, req.path, req.headers)
  let extra_headers : Map[String, String] = {}
  for entry in response.headers {
    extra_headers[entry.0] = entry.1
  }
  conn.send_response(response.status, "OK", extra_headers~)
  conn.write(response.body) catch {
    _ => ()
  }
  conn.end_response()
}

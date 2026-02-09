///|
#borrow(cmd)
extern "C" fn c_system(cmd : Bytes) -> Int = "wite_system_ffi"

///|
fn to_c_string(s : String) -> Bytes {
  let buf : Array[Byte] = []
  let len = s.length()
  let mut i = 0
  while i < len {
    let mut c = s.code_unit_at(i).to_int()
    if c >= 0xD800 && c <= 0xDBFF && i + 1 < len {
      let lo = s.code_unit_at(i + 1).to_int() - 0xDC00
      c = ((c - 0xD800) << 10) + lo + 0x10000
      buf.push((0xF0 | (c >> 18)).to_byte())
      buf.push((0x80 | ((c >> 12) & 0x3F)).to_byte())
      buf.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      buf.push((0x80 | (c & 0x3F)).to_byte())
      i += 2
    } else if c < 0x80 {
      buf.push(c.to_byte())
      i += 1
    } else if c < 0x800 {
      buf.push((0xC0 | (c >> 6)).to_byte())
      buf.push((0x80 | (c & 0x3F)).to_byte())
      i += 1
    } else {
      buf.push((0xE0 | (c >> 12)).to_byte())
      buf.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      buf.push((0x80 | (c & 0x3F)).to_byte())
      i += 1
    }
  }
  buf.push(b'\x00')
  Bytes::from_array(buf)
}

///|
fn shell_quote(s : String) -> String {
  let buf : Array[Char] = ['\'']
  for ch in s {
    if ch == '\'' {
      buf.push('\'')
      buf.push('\\')
      buf.push('\'')
      buf.push('\'')
    } else {
      buf.push(ch)
    }
  }
  buf.push('\'')
  String::from_array(buf)
}

///|
fn run_shell_cmd(cmd : String) -> Int {
  let cmd_bytes = to_c_string(cmd)
  c_system(cmd_bytes)
}

///|
fn js_set_process_exit_code(_code : Int) -> Unit {
  // no-op: @sys.exit handles process exit in native
}

///|
fn js_force_process_exit(code : Int) -> Unit {
  @sys.exit(code)
}

///|
fn js_sanitize_dep_sync_name(raw : String) -> String {
  let text = raw.trim().to_string()
  if text.is_empty() {
    return "dep"
  }
  // Split on / and \, filter empty/./..
  let segments : Array[String] = []
  let current : Array[Char] = []
  for ch in text {
    if ch == '\\' || ch == '/' {
      let seg = String::from_array(current)
      if seg.length() > 0 && seg != "." && seg != ".." {
        segments.push(seg)
      }
      current.clear()
    } else {
      current.push(ch)
    }
  }
  if current.length() > 0 {
    let seg = String::from_array(current)
    if seg.length() > 0 && seg != "." && seg != ".." {
      segments.push(seg)
    }
  }
  if segments.is_empty() {
    return "dep"
  }
  // Join segments, replace non-safe chars, collapse underscores
  let buf : Array[Char] = []
  let mut prev_underscore = false
  for i, seg in segments {
    if i > 0 {
      if not(prev_underscore) {
        buf.push('_')
      }
      prev_underscore = true
    }
    for ch in seg {
      let safe = (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
        ch == '.' || ch == '_' || ch == '-'
      let c = if safe { ch } else { '_' }
      if c == '_' {
        if not(prev_underscore) {
          buf.push(c)
        }
        prev_underscore = true
      } else {
        buf.push(c)
        prev_underscore = false
      }
    }
  }
  // Trim leading/trailing underscores
  let mut start = 0
  while start < buf.length() && buf[start] == '_' {
    start += 1
  }
  let mut end_idx = buf.length()
  while end_idx > start && buf[end_idx - 1] == '_' {
    end_idx -= 1
  }
  if start >= end_idx {
    return "dep"
  }
  let result : Array[Char] = []
  for i in start..<end_idx {
    result.push(buf[i])
  }
  let s = String::from_array(result)
  if s.is_empty() {
    "dep"
  } else {
    s
  }
}

///|
fn js_verify_wkg_package_cli(
  package_spec : String,
  registry_host : String,
) -> String {
  let cmd = "d=$(mktemp -d) && wkg get " +
    shell_quote(package_spec) +
    " --registry " +
    shell_quote(registry_host) +
    " --output \"$d/pkg\" --overwrite 2>/dev/null; e=$?; rm -rf \"$d\"; exit $e"
  let exit_code = run_shell_cmd(cmd)
  if exit_code == -1 {
    return "error\tspawn\tsystem() failed"
  }
  if exit_code == 0 {
    "ok\t0\t"
  } else {
    "error\texit:" + exit_code.to_string() + "\twkg command failed"
  }
}

///|
fn js_sync_wkg_package_cli(
  package_spec : String,
  registry_host : String,
  output_dir : String,
) -> String {
  let out_dir = output_dir.trim().to_string()
  if out_dir.is_empty() {
    return "error\targs\toutput dir must not be empty"
  }
  let mkdir_cmd = "mkdir -p " + shell_quote(out_dir)
  let _ = run_shell_cmd(mkdir_cmd)
  let out_arg = if out_dir.has_suffix("/") || out_dir.has_suffix("\\") {
    out_dir
  } else {
    out_dir + "/"
  }
  let cmd = "wkg get " +
    shell_quote(package_spec) +
    " --registry " +
    shell_quote(registry_host) +
    " --output " +
    shell_quote(out_arg) +
    " --overwrite 2>/dev/null"
  let exit_code = run_shell_cmd(cmd)
  if exit_code == -1 {
    return "error\tspawn\tsystem() failed"
  }
  if exit_code == 0 {
    "ok\t" + out_dir + "\t"
  } else {
    "error\texit:" + exit_code.to_string() + "\twkg command failed"
  }
}

///|
fn js_sync_wkg_package_to_file_cli(
  package_spec : String,
  registry_host : String,
  output_path : String,
) -> String {
  let out_path = output_path.trim().to_string()
  if out_path.is_empty() {
    return "error\targs\toutput path must not be empty"
  }
  // Create parent directory
  let parent = path_dirname(out_path)
  if parent != "." {
    let mkdir_cmd = "mkdir -p " + shell_quote(parent)
    let _ = run_shell_cmd(mkdir_cmd)
  }
  let cmd = "wkg get " +
    shell_quote(package_spec) +
    " --registry " +
    shell_quote(registry_host) +
    " --format wasm --output " +
    shell_quote(out_path) +
    " --overwrite 2>/dev/null"
  let exit_code = run_shell_cmd(cmd)
  if exit_code == -1 {
    return "error\tspawn\tsystem() failed"
  }
  if exit_code == 0 {
    "ok\t" + out_path + "\t"
  } else {
    "error\texit:" + exit_code.to_string() + "\twkg command failed"
  }
}

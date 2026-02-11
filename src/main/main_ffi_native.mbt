// Native FFI functions for main.mbt

///|
#borrow(cmd)
extern "C" fn c_main_system(cmd : Bytes) -> Int = "wite_main_system_ffi"

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
      buf..push('\'')..push('\\')..push('\'')..push('\'')
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
  c_main_system(cmd_bytes)
}

///|
fn path_dirname_for_ffi(path : String) -> String {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let index = match (slash, backslash) {
    (Some(a), Some(b)) => if a >= b { Some(a) } else { Some(b) }
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  match index {
    Some(i) if i > 0 => path[:i].to_string() catch { _ => "." }
    Some(_) => "."
    None => "."
  }
}

///|
fn js_ensure_parent_dir_for_file(path : String) -> Unit {
  let parent = path_dirname_for_ffi(path)
  if parent != "." {
    let _ = run_shell_cmd("mkdir -p " + shell_quote(parent))
  }
}

///|
fn js_make_temp_wasm_path(prefix : String) -> String {
  let base = if prefix.is_empty() { "wite-diff" } else { prefix }
  // Build safe filename
  let safe_buf : Array[Char] = []
  for ch in base {
    let safe = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '_' ||
      ch == '-'
    safe_buf.push(if safe { ch } else { '-' })
  }
  let safe_base = String::from_array(safe_buf)
  // Use /tmp with a timestamp-based unique name
  let tmpdir = @sys.get_env_var("TMPDIR").unwrap_or("/tmp")
  let mut hash = 0
  for ch in safe_base {
    hash = hash * 31 + ch.to_int()
  }
  if hash < 0 {
    hash = -hash
  }
  tmpdir + "/" + safe_base + "-" + hash.to_string() + ".wasm"
}

///|
fn js_run_wasm_opt_cli(
  wasm_opt_bin : String,
  args_spec : String,
  input_path : String,
  output_path : String,
) -> String {
  let mut cmd = shell_quote(wasm_opt_bin)
  if args_spec.length() > 0 {
    // args_spec is tab-separated
    for part in args_spec.split("\t") {
      let arg = part.to_string()
      if arg.length() > 0 {
        cmd = cmd + " " + shell_quote(arg)
      }
    }
  }
  cmd = cmd + " " + shell_quote(input_path) + " -o " + shell_quote(output_path)
  let exit_code = run_shell_cmd(cmd)
  if exit_code == -1 {
    return "error\tspawn\tsystem() failed"
  }
  if exit_code == 0 {
    "ok\t0\t"
  } else {
    "error\texit:" + exit_code.to_string() + "\twasm-opt command failed"
  }
}

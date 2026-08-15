///|
fn sanitize_process_output(s : String) -> String {
  let buf : Array[Char] = []
  let mut count = 0
  for ch in s {
    if count >= 65536 {
      break
    }
    if ch == '\n' || ch == '\r' {
      buf.push(' ')
    } else if ch == '\t' {
      buf.push(' ')
    } else {
      buf.push(ch)
    }
    count += 1
  }
  String::from_array(buf)
}

///|
async fn evaluate_ts_config(config_path : String) -> String {
  // Build JS code that imports the TS config and writes JSON to stdout
  // Use top-level await with import() since --input-type=module disables require()
  let code = "const{default:p}=await import('node:path');const m=await import('file://'+p.resolve(" +
    json_quote(config_path) +
    "));process.stdout.write(JSON.stringify(m.default))"
  let args : Array[String] = ["--input-type=module", "-e", code]
  let (exit_code, stdout) = @xprocess.collect_stdout("node", args[:])
  let output = stdout.text() catch { _ => "" }
  if exit_code != 0 {
    let detail = sanitize_process_output(output)
    return "err\t" +
      (if detail.is_empty() {
        "node evaluation failed (exit=" + exit_code.to_string() + ")"
      } else {
        detail
      })
  }
  let trimmed = output.trim().to_owned()
  if trimmed.is_empty() {
    return "err\tempty output from ts config evaluation"
  }
  "ok\t" + trimmed
}

///|
fn json_quote(s : String) -> String {
  let buf : Array[Char] = ['"']
  for ch in s {
    if ch == '"' {
      buf..push('\\').push('"')
    } else if ch == '\\' {
      buf..push('\\').push('\\')
    } else {
      buf.push(ch)
    }
  }
  buf.push('"')
  String::from_array(buf)
}

///|
async fn load_ts_config_or_exit(path : String) -> @wite_config.WiteConfigFile {
  let raw = evaluate_ts_config(path)
  let tab_index = raw.find("\t")
  let (tag, payload) = match tab_index {
    Some(i) => (raw[:i].to_owned(), raw[i + 1:].to_owned())
    None => (raw, "")
  }
  if tag != "ok" {
    println("failed to evaluate ts config: " + path + " (" + payload + ")")
    @sys.exit(1)
    return @wite_config.empty_wite_config_file()
  }
  match @wite_config.parse_wite_config_text(payload) {
    Ok(config) => config
    Err(msg) => {
      println("failed to parse ts config: " + path + " (" + msg + ")")
      @sys.exit(1)
      @wite_config.empty_wite_config_file()
    }
  }
}

///|
async fn resolve_config_or_default(
  selection : @wite_config.ConfigSelectionFlags,
) -> @wite_config.WiteConfigFile {
  match resolve_config_file_path(selection) {
    None =>
      if selection.explicit_config_path {
        println("config file not found: " + selection.config_path)
        @sys.exit(1)
        @wite_config.empty_wite_config_file()
      } else {
        @wite_config.empty_wite_config_file()
      }
    Some(path) =>
      if @wite_config.is_ts_config(path) {
        load_ts_config_or_exit(path)
      } else {
        load_wite_config_or_exit(path)
      }
  }
}

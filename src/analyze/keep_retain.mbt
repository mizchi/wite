///|
pub fn run_keep_reasons_with_options(
  path : String,
  closed_world : Bool,
  safe_mode : Bool,
  closed_world_root_exports : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  let config = make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match analyze_keep_reasons(bytes, config~) {
    Ok(report) => {
      println("keep reasons:")
      println("  partial: " + report.partial.to_string())
      match report.entries {
        [] => println("  entries: (none)")
        [_, ..] => {
          println("  entries:")
          for entry in report.entries {
            let label = match entry.name {
              Some(v) => v
              None => "#\{entry.function_index.to_string()}"
            }
            let exports = match entry.export_names {
              [] => ""
              [_, ..] => " exports=" + entry.export_names.join(",")
            }
            println(
              "    " +
              label +
              " idx=" +
              entry.function_index.to_string() +
              exports +
              " reasons=" +
              entry.reasons.join(","),
            )
          }
        }
      }
    }
    Err(e) => {
      println("keep-reasons failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn print_retain_path_entries(
  entries : Array[@wite.RetainPathEntry],
  limit : UInt,
) -> Unit {
  match entries {
    [] => {
      println("  entries: (none)")
      return
    }
    [_, ..] => ()
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    let label = match entry.name {
      Some(v) => v
      None => "#\{entry.function_index.to_string()}"
    }
    let exports = match entry.export_names {
      [] => ""
      [_, ..] => " exports=" + entry.export_names.join(",")
    }
    let root_reasons = match entry.root_reasons {
      [] => "reachable"
      [_, ..] => entry.root_reasons.join(",")
    }
    let path = match entry.path {
      [] => "(none)"
      [_, ..] => entry.path.map(i => i.to_string()).join(" -> ")
    }
    println(
      "    " +
      label +
      " idx=" +
      entry.function_index.to_string() +
      " body=" +
      entry.body_bytes.to_string() +
      exports +
      " root=" +
      root_reasons +
      " path=" +
      path,
    )
    printed += 1U
  }
}

///|
pub fn run_retain_path_with_options(
  path : String,
  limit : UInt,
  closed_world : Bool,
  safe_mode : Bool,
  closed_world_root_exports : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  let config = make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match analyze_retain_paths(bytes, config~) {
    Ok(report) => {
      println("retain-path analysis:")
      println("  partial: " + report.partial.to_string())
      match report.roots {
        [] => println("  roots: (none)")
        [_, ..] =>
          println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      }
      print_retain_path_entries(report.entries, limit)
    }
    Err(e) => {
      println("retain-path failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

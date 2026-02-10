///|
async fn run_install_command(args : Array[String]) -> Unit {
  // Rewrite args as: [bin, "deps", "sync", ...rest]
  let synth : Array[String] = [args[0], "deps", "sync"]
  for i in 2..<args.length() {
    synth.push(args[i])
  }
  @wite_deps.run_deps_sync_command(synth, print_usage)
}


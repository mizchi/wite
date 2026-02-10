///|
async fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    @sys.exit(1)
  }
  match args[1] {
    "init" => run_init_command(args)
    "new" => run_new_command(args)
    "add" => @wite_deps.run_add_command(args, print_usage)
    "install" => run_install_command(args)
    "analyze" => run_analyze_command(args)
    "build" => run_build(args)
    "deps" => @wite_deps.run_deps_command(args, print_usage)
    "diff" => run_diff_command(args)
    "optimize" => run_optimize(args)
    _ => {
      print_usage()
      @sys.exit(1)
    }
  }
}

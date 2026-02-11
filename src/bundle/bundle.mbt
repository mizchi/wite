///|
pub fn build_wac_dep_target_path(
  base_dir : String,
  ns : String,
  name : String,
) -> String {
  base_dir + "/deps/" + ns + "/" + name + ".wasm"
}

///|
fn collect_wac_new_packages_from_expr(
  expr : @wac.WacExpr,
  packages : Array[String],
) -> Unit {
  match expr {
    @wac.WacExpr::New(new_expr) => packages.push(new_expr.pkg)
    @wac.WacExpr::Access(base, _) =>
      collect_wac_new_packages_from_expr(base, packages)
    @wac.WacExpr::Name(_) => ()
  }
}

///|
pub fn collect_wac_new_package_names(
  source : String,
) -> Result[Array[String], String] {
  let doc = match @wac.parse_wac(source) {
    Ok(v) => v
    Err(e) => return Err("failed to parse wac source: " + e.to_string())
  }
  let packages : Array[String] = []
  for stmt in doc.stmts {
    match stmt {
      @wac.WacStmt::Let(_, expr) =>
        collect_wac_new_packages_from_expr(expr, packages)
      @wac.WacStmt::Export(exp) =>
        collect_wac_new_packages_from_expr(exp.expr, packages)
      @wac.WacStmt::Import(_) => ()
    }
  }
  packages.sort()
  packages.dedup()
  Ok(packages)
}

///|
pub fn parse_wac_package_name(pkg_name : String) -> (String, String)? {
  let parsed = @oci_types.PackageName::parse(pkg_name)
  parsed.map(pkg => (pkg.ns, pkg.name))
}

///|
pub fn compose_wac_file(
  input_path : String,
  best_effort? : Bool = false,
  dce? : Bool = true,
) -> Result[Bytes, String] {
  @wac.compose_wac_file(input_path, best_effort~, dce~)
}

///|
pub fn compose_wac_source(
  source : String,
  base_dir : String,
  best_effort? : Bool = false,
  dce? : Bool = true,
) -> Result[Bytes, String] {
  @wac.compose_wac_source(source, base_dir, best_effort~, dce~)
}

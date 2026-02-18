///|
test "parse_wagi_response basic" {
  let raw = "Content-Type: text/html\n\n<h1>Hello</h1>"
  let resp = parse_wagi_response(raw)
  inspect(resp.status, content="200")
  inspect(resp.headers["Content-Type"], content="text/html")
  inspect(resp.body, content="<h1>Hello</h1>")
}

///|
test "parse_wagi_response with status header" {
  let raw = "Content-Type: application/json\nStatus: 404 Not Found\n\n{\"error\":\"not found\"}"
  let resp = parse_wagi_response(raw)
  inspect(resp.status, content="404")
  inspect(resp.headers["Content-Type"], content="application/json")
  inspect(resp.body, content="{\"error\":\"not found\"}")
}

///|
test "parse_wagi_response empty body" {
  let raw = "Content-Type: text/plain\nStatus: 204\n\n"
  let resp = parse_wagi_response(raw)
  inspect(resp.status, content="204")
  inspect(resp.body, content="")
}

///|
test "parse_wagi_response no headers" {
  let raw = "just body text"
  let resp = parse_wagi_response(raw)
  inspect(resp.status, content="200")
  inspect(resp.headers["Content-Type"], content="text/plain")
  inspect(resp.body, content="")
}

///|
test "parse_wagi_response multiple headers" {
  let raw = "Content-Type: text/html\nX-Custom: foo\nX-Other: bar\n\nbody"
  let resp = parse_wagi_response(raw)
  inspect(resp.headers["Content-Type"], content="text/html")
  inspect(resp.headers["X-Custom"], content="foo")
  inspect(resp.headers["X-Other"], content="bar")
  inspect(resp.body, content="body")
}

///|
test "parse_wagi_response crlf line endings" {
  let raw = "Content-Type: text/html\r\nStatus: 201\r\n\r\ncreated"
  let resp = parse_wagi_response(raw)
  inspect(resp.status, content="201")
  inspect(resp.headers["Content-Type"], content="text/html")
  inspect(resp.body, content="created")
}

///|
test "parse_wagi_response default content-type" {
  let raw = "Status: 200\n\nok"
  let resp = parse_wagi_response(raw)
  inspect(resp.headers["Content-Type"], content="text/plain")
}

///|
test "build_wagi_env_args basic" {
  let headers : Map[String, String] = {}
  let args = build_wagi_env_args("GET", "/hello", headers)
  inspect(
    args,
    content="[\"--env\", \"REQUEST_METHOD=GET\", \"--env\", \"PATH_INFO=/hello\", \"--env\", \"SERVER_PROTOCOL=HTTP/1.1\", \"--env\", \"GATEWAY_INTERFACE=CGI/1.1\"]",
  )
}

///|
test "build_wagi_env_args with content-type" {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  let args = build_wagi_env_args("POST", "/api", headers)
  assert_true(args.contains("CONTENT_TYPE=application/json"))
}

///|
test "build_wagi_env_args with custom headers" {
  let headers : Map[String, String] = { "Accept": "text/html" }
  let args = build_wagi_env_args("GET", "/", headers)
  assert_true(args.contains("HTTP_ACCEPT=text/html"))
}

///|
test "build_wagi_env_args header name conversion" {
  let headers : Map[String, String] = { "X-Custom-Header": "value" }
  let args = build_wagi_env_args("GET", "/", headers)
  assert_true(args.contains("HTTP_X_CUSTOM_HEADER=value"))
}

///|
test "try_parse_int valid" {
  inspect(try_parse_int("200"), content="Some(200)")
  inspect(try_parse_int("404"), content="Some(404)")
  inspect(try_parse_int("0"), content="Some(0)")
}

///|
test "try_parse_int invalid" {
  inspect(try_parse_int(""), content="None")
  inspect(try_parse_int("abc"), content="None")
}

///|
test "try_parse_int with trailing text" {
  inspect(try_parse_int("200 OK"), content="Some(200)")
}

///|
test "request_method_string" {
  inspect(request_method_string(@xhttp.RequestMethod::Get), content="GET")
  inspect(request_method_string(@xhttp.RequestMethod::Post), content="POST")
  inspect(request_method_string(@xhttp.RequestMethod::Put), content="PUT")
  inspect(request_method_string(@xhttp.RequestMethod::Delete), content="DELETE")
}

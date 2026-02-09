///|
fn wasi_fd_write(fd : Int, iovs : Int, iovs_len : Int, nwritten : Int) -> Int = "wasi_snapshot_preview1" "fd_write"

///|
extern "wasm" fn mem_store32(pos : Int, value : Int) =
  #|(func (param $pos i32) (param $value i32) (i32.store (local.get $pos) (local.get $value)))

///|
extern "wasm" fn mem_store8(pos : Int, value : Int) =
  #|(func (param $pos i32) (param $value i32) (i32.store8 (local.get $pos) (local.get $value)))

///|
fn write_stdout(s : String) -> Unit {
  let base = 32768
  let data_offset = base + 16
  let mut len = 0
  for i in 0..<s.length() {
    mem_store8(data_offset + len, s[i].to_int())
    len += 1
  }
  mem_store32(base, data_offset)
  mem_store32(base + 4, len)
  let _ = wasi_fd_write(1, base, 1, base + 8)
}

///|
fn main {
  write_stdout("hello from moonbit-wasi\n")
}

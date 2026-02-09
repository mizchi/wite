///|
pub fn add(a : Int, b : Int) -> Int {
  a + b
}

///|
pub fn fib(n : Int) -> Int {
  if n <= 1 {
    n
  } else {
    fib(n - 1) + fib(n - 2)
  }
}

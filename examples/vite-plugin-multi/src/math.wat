(component
  (core module $m
    (func $add (export "add") (param i32 i32) (result i32)
      local.get 0
      local.get 1
      i32.add)
    (func $mul (export "mul") (param i32 i32) (result i32)
      local.get 0
      local.get 1
      i32.mul))
  (core instance $i (instantiate $m))
  (func (export "add") (param "a" s32) (param "b" s32) (result s32)
    (canon lift (core func $i "add")))
  (func (export "mul") (param "a" s32) (param "b" s32) (result s32)
    (canon lift (core func $i "mul"))))

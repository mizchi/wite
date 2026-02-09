(component
  (core module $m
    (func $mul (param i32 i32) (result i32)
      local.get 0
      local.get 1
      i32.mul
    )
    (export "mul" (func $mul))
  )
  (core instance $i (instantiate $m))
  (func (export "mul") (param "a" s32) (param "b" s32) (result s32)
    (canon lift (core func $i "mul"))
  )
)

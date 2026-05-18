(module
  (type $ui_emit_t (func (param i64 i64) (result i64)))
  (type $main_t (func (result i64)))
  (import "edgerun.ui" "emit" (func $ui_emit (type $ui_emit_t)))
  (memory 1)

  ;; Purpose: prove authored WASM apps can emit bounded UI command lists.
  ;; Intention: keep UI authority in the host admission contract, not in the app.
  (func (export "main") (type $main_t) (result i64)
    (i32.const 1024)
    (i32.const 1)
    (i32.store16 offset=0)

    (i32.const 1024)
    (i32.const 3)
    (i32.store offset=4)

    (i32.const 1024)
    (i32.const 1)
    (i32.store offset=8)

    (i32.const 1024)
    (i32.const 1)
    (i32.store offset=12)

    (i32.const 1024)
    (i32.const 0)
    (i32.store offset=16)

    (i32.const 1024)
    (i32.const 0)
    (i32.store offset=20)

    (i32.const 1024)
    (i32.const 0)
    (i32.store offset=24)

    (i32.const 1024)
    (i32.const 0)
    (i32.store offset=28)

    (i32.const 1024)
    (i32.const 1)
    (i32.store offset=32)

    (i64.const 1024)
    (i64.const 36)
    (call $ui_emit))
)

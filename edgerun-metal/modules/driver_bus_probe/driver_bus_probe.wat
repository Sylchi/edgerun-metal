(module
  (type $bus_exec_t (func (param i64 i64) (result i64)))
  (type $main_t (func (result i64)))
  (import "edgerun.bus" "exec" (func $bus_exec (type $bus_exec_t)))
  (memory 1)

  ;; Purpose: prove driver modules can build bus packets in linear memory.
  ;; Intention: keep device logic in WASM while the executor only performs addressed bus transactions.
  (func (export "main") (type $main_t) (result i64)
    (i32.const 0)
    (i32.const 1)
    (i32.store16 offset=0)

    (i32.const 0)
    (i32.const 3)
    (i32.store16 offset=2)

    (i32.const 0)
    (i32.const 1)
    (i32.store offset=8)

    (i32.const 0)
    (i32.const 1)
    (i32.store16 offset=16)

    (i32.const 0)
    (i32.const 2)
    (i32.store16 offset=18)

    (i32.const 0)
    (i32.const 4)
    (i32.store offset=20)

    (i32.const 0)
    (i32.const 1)
    (i32.store offset=24)

    (i32.const 0)
    (i32.const 1)
    (i32.store16 offset=32)

    (i32.const 0)
    (i32.const 2)
    (i32.store16 offset=34)

    (i32.const 0)
    (i32.const 4)
    (i32.store offset=36)

    (i32.const 0)
    (i32.const 1)
    (i32.store offset=52)

    (i32.const 0)
    (i64.const 4096)
    (i64.store offset=64)

    (i32.const 0)
    (i64.const 4)
    (i64.store offset=72)

    (i64.const 0)
    (i64.const 128)
    (call $bus_exec)
    (drop)

    (i32.const 128)
    (i64.load offset=96 align=8))
)

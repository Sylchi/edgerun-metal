;; da_test.wat — Minimal WASM app that registers a surface with the DA
;; Compile: wat2wasm da_test.wat -o da_test.wasm
;;
;; The DA import wrappers handle DA route lookup and app identity.
;; The WASM app only needs to provide: layer, flags, rect pointer, rect count.

(module
  ;; Import DA surface register function from module "er"
  ;; signature: da_surface_register(params_ptr: i32) -> i32
  ;;   params struct (16 bytes at params_ptr):
  ;;     +0: layer (i32)     — DA_LAYER_* constant (0 = SCRIM)
  ;;     +4: flags (i32)     — DA_SURFACE_VISIBLE (1) etc.
  ;;     +8: rect_data (i32) — WASM offset of rect float array
  ;;    +12: rect_count (i32) — number of rects (max 3 per cell)
  (import "er" "da_surface_register" (func $register (param i32) (result i32)))

  ;; One page of linear memory (65536 bytes)
  (memory (export "memory") 1)

  ;; Store rect data at the start of memory
  ;; Each rect: [x, y, w, h, u, v, r, g, b, a, rx, ry, rz, rw, layer_id]
  ;; = 15 floats = 60 bytes
  ;; Blue-green rect at (100, 100), 200x150
  (data (i32.const 0) "\00\00\c8\42"  ;; x = 100.0
                       "\00\00\c8\42"  ;; y = 100.0
                       "\00\00\48\43"  ;; w = 200.0
                       "\00\00\16\43"  ;; h = 150.0
                       "\00\00\00\00"  ;; u = 0.0
                       "\00\00\00\00"  ;; v = 0.0
                       "\cd\cc\4c\3e"  ;; r = 0.2
                       "\00\00\00\3f"  ;; g = 0.5
                       "\cd\cc\4c\3f"  ;; b = 0.8
                       "\00\00\80\3f"  ;; a = 1.0
                       "\00\00\00\00"  ;; rx = 0.0
                       "\00\00\00\00"  ;; ry = 0.0
                       "\00\00\00\00"  ;; rz = 0.0
                       "\00\00\00\00"  ;; rw = 0.0
                       "\00\00\00\00") ;; layer_id = 0.0

  ;; Register params struct (16 bytes) right after rect data
  (data (i32.const 64) "\00\00\00\00"  ;; layer = 0 (SCRIM)
                        "\01\00\00\00"  ;; flags = 1 (VISIBLE)
                        "\00\00\00\00"  ;; rect_data = 0 (offset of rect data in mem)
                        "\01\00\00\00") ;; rect_count = 1

  ;; Exported function "f" — called by the interpreter
  (func (export "f") (result i32)
    i32.const 64        ;; params_ptr = offset of RegisterParams struct
    call $register      ;; da_surface_register(params_ptr)
  )
)

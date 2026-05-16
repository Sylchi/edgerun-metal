(module
  (import "edgerun.log" "u64" (func $log_u64 (param i64)))
  (import "edgerun.log" "hex" (func $log_hex (param i64)))
  (import "edgerun.pci" "read32" (func $pci_read32 (param i64 i64 i64 i64) (result i64)))

(func (export "main") (result i64)
    (local $bus i64)
    (local $dev i64)
    (local $func_idx i64)
    (local $id i64)
    (local $hdr i64)
    (local $multifunc i64)

    i64.const 0
    local.set $bus

    (block
      (loop
        (local.set $dev (i64.const 0))
        (block
          (loop
            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 0
            call $pci_read32
            local.tee $id

    i64.const 4294967295
            i64.ne
            i32.eqz
            br_if 1

            local.get $bus
            call $log_u64

            local.get $dev
            call $log_u64

            i64.const 0
            call $log_u64

            local.get $id
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 4
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 8
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 12
            call $pci_read32
            local.tee $hdr
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 16
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 20
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 24
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 28
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 32
            call $pci_read32
            call $log_hex

            local.get $bus
            local.get $dev
            i64.const 0
            i64.const 36
            call $pci_read32
            call $log_hex

            local.get $hdr
            i64.const 8388608
            i64.and
            local.set $multifunc

            (block
              local.get $multifunc
              i64.const 0
              i64.ne
              i32.eqz
              br_if 0

              i64.const 1
              local.set $func_idx

              (block
                (loop
                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 0
                  call $pci_read32
                  local.tee $id

    i64.const 4294967295
                  i64.ne
                  i32.eqz
                  br_if 1

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  call $log_u64

                  local.get $id
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 4
                  call $pci_read32
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 8
                  call $pci_read32
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 12
                  call $pci_read32
                  local.tee $hdr
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 16
                  call $pci_read32
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 20
                  call $pci_read32
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 24
                  call $pci_read32
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 28
                  call $pci_read32
                  call $log_hex

                  local.get $bus
                  local.get $dev
                  local.get $func_idx
                  i64.const 32
                  call $pci_read32
                  call $log_hex

                  local.get $func_idx
                  i64.const 1
                  i64.add
                  local.set $func_idx

                  local.get $func_idx
                  i64.const 8
                  i64.lt_u
                  br_if 0
                  br 1
                )
              )
            )

            local.get $dev
            i64.const 1
            i64.add
            local.set $dev

            local.get $dev
            i64.const 32
            i64.lt_u
            br_if 0
            br 1
          )
        )

        local.get $bus
        i64.const 1
        i64.add
        local.set $bus

        local.get $bus
        i64.const 256
        i64.lt_u
        br_if 0
      )
    )

    i64.const 123
  )
)

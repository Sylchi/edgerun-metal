# EdgeRun Wasm Driver ABI

Source of truth: `include/er_driver_abi.h`.

The first admitted driver contract is `contract=bus-driver`. It imports only:

```text
edgerun.bus/exec
```

`edgerun.bus/exec(request_ptr, response_ptr)` accepts an
`ER_DRIVER_ABI_BUS_PACKET_IO_BYTES` request and writes an
`ER_DRIVER_ABI_BUS_PACKET_IO_BYTES` response in driver linear memory. The ABI
defines:

- PCI discovery payload layout for bus, device, function, target, IDs, command,
  class, and BAR snapshots.
- PCI config, MMIO32, and I/O port address records.
- 8-, 16-, and 32-bit read/write access flags.
- 32-bit operation packets and generic width I/O packets.
- Explicit response status values.

Driver packages are not UI apps. They use the same package layout and identity
workflow as UI apps, but their manifest contract is distinct and `app-run`
rejects them.

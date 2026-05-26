# A Locked Device Becomes Trash Before The Hardware Dies

E-waste is not only a materials problem. It is a permission problem.

Sealed batteries, parts pairing, repair locks, short support windows, missing drivers, app support cutoffs, locked bootloaders, proprietary firmware, and disposable IoT all shorten device life.

> Mental model: hardware becomes waste early when authority expires before the machine does.

## Lifecycle failure

```text
hardware still works
  -> vendor stops updates
  -> bootloader stays locked
  -> apps stop supporting OS
  -> repair is blocked
  -> device becomes waste
```

The device did not become useless because physics failed. It became useless because authority expired.

## Where the life gets cut short

A device can die early when:

- the battery is glued and paired
- replacement parts require vendor approval
- the bootloader cannot be unlocked
- firmware tools are unavailable
- app stores stop accepting the OS
- cloud services refuse older clients
- drivers are never released
- activation servers disappear

Each lock looks small on its own. Together they turn working hardware into supervised waste.

## Better lifecycle shape

The owner needs an exit path before the vendor leaves:

- unlock when support ends
- publish repair information
- allow owner-controlled relocking
- separate security updates from feature control
- keep local functions local
- make cloud services replaceable
- preserve installable software paths

Security should not be an excuse to strand hardware. If a vendor no longer wants responsibility, it should not keep authority.

## Interactive model

[[demo:post_model]]

Lifecycle lock map: choose support length, repair access, bootloader policy, and parts availability. The demo shows how long hardware remains useful.

## Main lesson

If the vendor will not maintain the device, the vendor should not be allowed to prevent the owner from maintaining it.

## EdgeRun seed

User-owned runtimes and unlockable hardware extend device life by letting useful compute keep serving the owner after vendor interest ends.

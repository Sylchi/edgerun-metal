# EdgeRun OS And App Store Roadmap

Purpose: track the concrete path from the current Wasm runtime foundation to a
usable OS with user-authored apps, an app store, smooth UI, Wasm drivers, and
identity-routed encrypted storage.

## Milestone 1: Local User Apps

- [x] Own the Wasm compiler and interpreter path for the current subset.
- [x] Define canonical hostcalls in one contract table.
- [x] Runtime-test every declared hostcall.
- [x] Build `app/app.c` into `app/.build/app.wasm` through `er-build app-build`.
- [x] Validate app manifests against the owned app contract.
- [x] Generate package identity from app source, manifest, assets, and Wasm bytes.
- [ ] Expand the C subset with local variables, loads, stores, branches, and calls.
- [ ] Load a user-authored package from local storage into the shell.
- [x] Route keyboard/input events to the active Wasm UI app.

## Milestone 2: Polished Shell UI

- [ ] Build the app launcher as the first real shell surface.
- [ ] Add app install/remove/update states.
- [ ] Add retained UI state for shell navigation and app switching.
- [ ] Add frame timing instrumentation for 4K targets.
- [ ] Optimize redraws around dirty regions and stable GPU command batches.
- [ ] Verify 4K layout correctness before claiming 120 Hz smoothness.

## Milestone 3: Local App Store

- [x] Store packages by content identity, not labels.
- [x] Sign packages and verify signatures before install.
- [x] Build a local package index.
- [ ] Add package rollback and removal.
- [ ] Show package identity, permissions, and provenance in the shell.

## Milestone 4: Wasm Drivers

- [ ] Separate driver package admission from user app admission.
- [ ] Define the first driver ABI for PCI discovery, MMIO, and bus packets.
- [ ] Add event/interrupt delivery model for Wasm drivers.
- [ ] Move one simple device path from native C fixture to a Wasm driver package.
- [ ] Enforce driver memory and device access policy through admission.

## Milestone 5: Encrypted Identity Relay

- [ ] Define encrypted content object format.
- [ ] Wrap content keys to recipient identities.
- [ ] Chunk, verify, cache, and garbage-collect content-addressed objects.
- [ ] Relay sealed objects without exposing plaintext to storage nodes.
- [ ] Add route receipts and accounting records.
- [ ] Install packages fetched from another identity or device.

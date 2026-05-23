# Drivers and Firmware: The Hidden Software Under the Software

Not all software is visible.

Drivers let the operating system talk to hardware. Firmware is small software running inside devices and chips.

When people say "the app did it" or "the OS did it," they often skip the lower layers that made the action possible. The OS may request a Wi-Fi transmission, but firmware inside the radio may decide the details. The OS may ask storage to write data, but a controller inside the drive manages flash blocks. The OS may display a camera frame, but image processing may already have happened inside the camera pipeline.

## Where hidden software lives

Firmware can run inside:

- Wi-Fi chips
- Bluetooth chips
- cellular modems
- SSD controllers
- camera controllers
- GPUs
- secure elements
- TPMs

Drivers translate between the OS and those devices. Firmware often runs below the level ordinary users can inspect.

This matters because hidden software can hold real power. A radio firmware blob may parse complex input from the air. A storage controller may remap blocks and keep wear-leveling state. A secure element may refuse to release keys. A GPU firmware path may run privileged code that normal apps never see. Some of this is necessary. Some of it is vendor lock-in. Some of it is simply opaque.

## The driver boundary

A driver is supposed to translate a stable OS request into device-specific commands. That makes hardware usable, but it also creates a privileged bridge. Driver bugs can break isolation. Driver policy can hide device behavior. Vendor drivers can smuggle a control plane into what looked like a local machine.

Firmware is harder. It may be required before the device can operate at all. The user may not be able to rebuild it, inspect it, or replace it. That does not mean the system should pretend it is trusted. It means the system should isolate it and name the boundary honestly.

## Honest hardware trust

- measure what can be measured
- isolate what cannot be trusted
- keep opaque firmware away from secrets when possible
- avoid vendor control planes in the trusted path
- treat radio and boot firmware exceptions as narrow exceptions

The point is not fantasy purity. The point is refusing to confuse "required to operate this chip" with "allowed to own the system."

## Main lesson

Your device contains computers inside the computer, and you do not control all of them. A serious system names those boundaries instead of burying them under the word "hardware."

## Edgerun seed

A realistic user-owned system must admit hardware trust boundaries. Some parts can be made explicit and measured. Some parts remain opaque and must be isolated. Vendor firmware needed to operate a radio is not the same as vendor authority over apps, identity, storage, or policy.

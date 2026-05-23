# The Phone Is Powerful, But Permissioned

Modern phones are not general-purpose computers in your pocket. They are permissioned computers with a touchscreen.

They have fast CPUs, GPUs, NPUs, storage, sensors, cameras, radios, secure elements, and batteries. But many capabilities are controlled by locked bootloaders, secure boot, app signing, store policy, sandbox rules, sideloading limits, root restrictions, baseband firmware, NFC restrictions, camera and mic prompts, background task limits, file system controls, USB debugging controls, and repair locks.

## Purpose

Explain what users can and cannot do with hardware they bought.

## Visual idea

```text
hardware you bought
  -> bootloader
  -> operating system vendor
  -> app store
  -> app permissions
```

## Interactive demo

A permission ladder lets the reader choose a task: install an app, replace the OS, inspect files, use NFC, repair a camera, run a background worker, or connect USB debugging. The ladder shows which authority can allow or block the action.

## Main lesson

Some restrictions protect users. Some protect platforms. Some do both. The problem is that users rarely get to choose.

## EdgeRun seed

A user-owned runtime needs explicit capability grants and inspectable app authority, without pretending platform gatekeeping is the same thing as user control.

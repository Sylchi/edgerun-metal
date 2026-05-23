# The Phone Is Powerful, But Permissioned

Modern phones are not general-purpose computers in your pocket. They are permissioned computers with a touchscreen.

They have fast CPUs, GPUs, NPUs, storage, sensors, cameras, radios, secure elements, and batteries. But many capabilities are controlled by locked bootloaders, secure boot, app signing, store policy, sandbox rules, sideloading limits, root restrictions, baseband firmware, NFC restrictions, camera and mic prompts, background task limits, file system controls, USB debugging controls, and repair locks.

The phone is powerful enough to be a personal computer, but the authority model often treats the owner as a managed user.

## Permission ladder

[[demo:permission_ladder]]

```text
hardware you bought
  -> bootloader
  -> operating system vendor
  -> app store
  -> app permissions
  -> app runtime
```

Each rung can allow or block action. Replacing the OS depends on bootloader policy. Installing software depends on signing and store rules. Running background work depends on OS policy. Accessing NFC, files, camera, location, USB debugging, or repair diagnostics may depend on vendor decisions that the owner cannot override.

## Protection and control

Some restrictions are real protection. Sandboxing limits malware. Camera prompts protect privacy. Secure boot can prevent persistent compromise. But the same mechanisms can also block repair, alternative operating systems, independent software, long-term maintenance, and owner inspection.

The problem is not that every restriction is bad. The problem is that the owner rarely gets a clear override path.

## Main lesson

Some restrictions protect users. Some protect platforms. Some do both. The problem is that users rarely get to choose.

## EdgeRun seed

A user-owned runtime needs explicit capability grants and inspectable app authority, without pretending platform gatekeeping is the same thing as user control.

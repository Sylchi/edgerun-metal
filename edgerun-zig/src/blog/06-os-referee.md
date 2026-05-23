# The Operating System: The Referee You Forgot You Had

The operating system is the manager between apps and hardware.

It decides which app gets CPU time, which memory belongs to which process, which files an app can open, which devices an app can touch, and how network access works.

Without an operating system, every program would have to negotiate directly with every device and with every other program. That is chaos. The OS creates the basic rules: this process owns this memory, this file handle is open, this device request is allowed, this packet may leave, this app is suspended, this window receives the input event.

## What the OS manages

- CPU time
- RAM allocation
- files and storage
- network access
- devices
- permissions
- users
- processes
- drivers

These are not just technical chores. They are policy decisions. If the OS grants a program a camera stream, the program can see. If it grants a program a directory, the program can read or change those files. If it grants background execution, the program can keep working after the user thinks it is closed.

## Platform complication

The simple model is:

```text
User -> App -> Operating system -> Hardware
```

Modern platforms add more rulers:

```text
User -> App -> OS vendor rules -> app store rules -> manufacturer -> hardware and firmware
```

That second chain is closer to what users experience. The OS does not only protect the user from apps. It also protects platform policy, app store policy, carrier policy, vendor update policy, and sometimes government policy. The user may own the hardware but not the signing keys, update channel, app distribution rules, or recovery path.

## The referee has interests

A referee is useful only if you know whose game it is enforcing. A desktop OS, a phone OS, a browser, and a game console all enforce different assumptions. Some give the user broad local authority. Some treat the vendor as the final administrator. Some treat every app as a guest but also treat the user as a guest.

This is why a local-first system still has to respect the host OS while reducing dependence on hidden host policy. It cannot pretend the host boundary is gone. It has to build smaller, explicit boundaries inside it.

## Good OS boundaries

- separate process memory
- explicit file handles
- narrow device access
- inspectable network routes
- clear identity and key ownership
- predictable update authority
- revocation that actually removes access

## Main lesson

The operating system is the first government your app lives under, and the user needs to know whether that government answers to them.

## Edgerun seed

Edgerun needs to respect the OS boundary while creating a smaller, explicit authority boundary inside the app runtime. The host can provide execution, graphics, storage, and network access, but the Edgerun runtime should keep app authority narrow, inspectable, and user-owned.

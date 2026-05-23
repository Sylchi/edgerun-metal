# The Operating System: The Referee You Forgot You Had

The operating system is the manager between apps and hardware.

It decides which app gets CPU time, which memory belongs to which process, which files an app can open, which devices an app can touch, and how network access works.

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

## Platform complication

The simple model is:

```text
User -> App -> Operating system -> Hardware
```

Modern platforms add more rulers:

```text
User -> App -> OS vendor rules -> app store rules -> manufacturer -> hardware and firmware
```

## Main lesson

The operating system is the first government your app lives under.

## Edgerun seed

Edgerun needs to respect the OS boundary while creating a smaller, explicit authority boundary inside the app runtime.

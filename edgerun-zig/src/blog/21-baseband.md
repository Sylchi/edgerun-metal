# The Baseband: The Computer Inside Your Phone You Barely Control

A phone is not one computer. It is a city of tiny computers, and you are mayor of only some districts.

The application processor runs Android or iOS. The baseband talks to cellular networks. The secure enclave or TEE handles secrets and biometrics. Wi-Fi and Bluetooth chips run firmware. The GPU, DSP, and NPU run their own code. The SIM or eSIM has its own identity logic.

Even if the user controlled the visible operating system perfectly, the phone would still contain other execution domains.

> Mental model: phone ownership is partial unless the hidden computers and radio boundary are named honestly.

## Phone computer map

```text
phone
  -> main CPU: apps and OS
  -> baseband: cellular network
  -> secure enclave or TEE: keys and biometrics
  -> Wi-Fi and Bluetooth firmware
  -> GPU, DSP, and NPU
  -> SIM or eSIM identity
```

Each region has a different update path and trust boundary. Some firmware is signed by chip vendors. Some is delivered by phone vendors. Some behavior is constrained by carriers and radio law. Some components may observe sensitive data or control devices without being visible to normal app permissions.

## Why the baseband matters

The baseband is especially important because it speaks to hostile radio environments and carrier networks. It may run proprietary firmware. It may have memory, processors, and protocol stacks the user cannot inspect. It should be treated as an isolated neighbor, not as a trusted extension of the user's identity.

## Isolation beats pretending

The practical answer is not to pretend every chip can become transparent overnight. Radio hardware has regulation, certification, patents, carrier rules, and messy history. But a system can still be honest about the boundary.

Honest design keeps the baseband away from user identity, treats radio messages as untrusted input, logs which authority path woke the device, and avoids letting hidden firmware become the root of trust for personal data. The user may not control every radio detail, but the user should control what the rest of the system believes because of the radio.

## Interactive model

[[demo:post_model]]

## Main lesson

Hardware trust boundaries do not disappear because the screen shows one operating system.

## EdgeRun seed

A realistic user-owned system must admit hardware trust boundaries instead of pretending one OS owns everything.

# The Baseband: The Computer Inside Your Phone You Barely Control

A phone is not one computer. It is a city of tiny computers, and you are mayor of only some districts.

The application processor runs Android or iOS. The baseband talks to cellular networks. The secure enclave or TEE handles secrets and biometrics. Wi-Fi and Bluetooth chips run firmware. The GPU, DSP, and NPU run their own code. The SIM or eSIM has its own identity logic.

## Purpose

Show that even if a user controls Android, they may not control the whole phone.

## Visual idea

```text
phone
  -> main CPU: apps and OS
  -> baseband: cellular network
  -> secure enclave or TEE: keys and biometrics
  -> Wi-Fi and Bluetooth firmware
  -> GPU, DSP, and NPU
  -> SIM or eSIM identity
```

## Interactive demo

A phone computer map lets the reader click each processor or firmware domain. Each region shows who signs the code, who updates it, what data it can observe, and whether the user can replace it.

## Main lesson

Hardware trust boundaries do not disappear because the screen shows one operating system.

## EdgeRun seed

A realistic user-owned system must admit hardware trust boundaries instead of pretending one OS owns everything.

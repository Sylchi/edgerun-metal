# The Router: Your First Border Crossing

Your Wi-Fi password does not protect you from the internet. It mostly protects your local air.

Before a message reaches a server, the device usually talks to a router. Wi-Fi encryption protects local radio traffic, but the router still becomes a gatekeeper. It assigns addresses, decides what leaves the home, and can often see which devices connect where.

The router is the first network authority outside the device. It is close enough to feel like part of the home, but it is still a separate system with its own software, passwords, logs, update policy, DNS settings, firewall rules, and sometimes vendor cloud management.

## What Wi-Fi protects

Wi-Fi encryption protects the radio link between your device and the access point. That matters. Without it, nearby observers could more easily join the network or inspect local traffic.

But WPA is not a complete privacy model. After the access point receives traffic, the router still forwards it. The router can know which device is talking, when it is active, how much data it sends, which DNS resolver it asks, and which external addresses it contacts unless another layer hides those details.

## What the router does

- assigns local addresses
- forwards packets to the ISP
- performs NAT for many home networks
- applies firewall policy
- often provides DNS settings
- may isolate guest devices
- may expose admin or cloud management

This makes the router a real trust boundary. A compromised router can redirect names, observe traffic patterns, block updates, expose local devices, or create a bridge into a private network.

## Local does not mean safe

```text
phone -> Wi-Fi -> router -> ISP -> internet
```

Every arrow is a different boundary. Local apps can reduce what leaves the device. Guest networks can reduce what devices see each other. End-to-end encryption can reduce what the router sees. None of those solves all boundaries at once.

## Main lesson

Security is always local to a boundary. WPA protects one boundary. It does not solve identity, metadata, app tracking, server trust, or cloud ownership.

## EdgeRun seed

Local-first systems should keep private data inside your own trust boundary by default, and they should treat the router as transport, not as identity, storage, or policy authority.

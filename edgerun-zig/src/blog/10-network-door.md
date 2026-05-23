# Network: The Door Out of the Machine

The network begins after your device has already made decisions.

The app creates data. The operating system gives it to the network stack. Network hardware sends frames. A router forwards. An ISP forwards. DNS, TLS, VPNs, relays, and servers come later.

People often start the story at the server. That skips the part where the device decided what the message was, which app was allowed to create it, which key was allowed to sign it, and which route was allowed to carry it.

## Before the packet leaves

Your device already decided:

- what data exists
- which app created it
- which memory held it
- which key signed or encrypted it
- which OS policy allowed it
- which network interface sent it

Those decisions are local authority decisions. The network can carry them, hide parts of them, delay them, drop them, reorder them, or deliver them to another machine. It cannot retroactively make a bad local decision safe.

## The door is not the destination

A network interface is a door, not a guarantee. Once data leaves, many systems can observe or influence the path:

- router
- ISP
- VPN provider
- DNS resolver
- certificate authority
- relay
- server load balancer
- application server
- database

Encryption narrows what each layer can see, but it does not erase the path. Metadata still exists. Timing still exists. Destination choices still exist. Account policy still exists after decryption.

## What should leave

The strongest privacy boundary is not sending unnecessary data in the first place. A local-first system should ask whether the remote machine needs the raw data, a derived object, a signature, a sync delta, or nothing at all.

This is where object boundaries matter. If the local runtime can name, verify, and seal objects before the network sees them, the network becomes transport instead of authority.

## Tiny trace

```text
local object -> explicit intent -> route decision
route decision -> packet -> remote verifier
```

## Main lesson

The network begins after your device has already decided what to send. Fixing the network cannot fix a device that gave the wrong data the right permission.

## Bridge

Now we can talk about the internet. A message does not start in the cloud. It starts inside a machine full of boundaries, and the door out should be treated as one more explicit boundary.

# The VPN Company Is Just Your New ISP

A VPN does not remove trust. It moves it.

A VPN creates an encrypted tunnel from your device or router to someone else's network. That can be useful when your local network is hostile, censored, or untrusted. But the pipe ends somewhere, and at the end of that pipe is another network.

## The marketing problem

Separate useful private connectivity from consumer privacy theater. The reader should leave understanding that VPN means "tunnel to another middleman," not "privacy solved."

## The path

Before VPN:

```text
you -> router -> ISP -> website
```

After commercial VPN:

```text
you -> router -> ISP -> VPN provider -> website
```

Your ISP sees less of the final destination, but the VPN provider now sees a concentrated version of your traffic metadata. You did not eliminate the watcher. You changed the watcher.

## Two different things called VPN

- Private network VPN: WireGuard, Tailscale, or headscale between your own devices. This is private connectivity between things you control.
- Commercial consumer VPN: "hide your IP," "be anonymous," and "secure your internet." This sends your traffic through a stranger's exit server.

With a commercial VPN you may be trusting the VPN company, hosting provider, server admins, logging policy, payment processor, jurisdiction, app, browser extension, update mechanism, DNS resolver, and sometimes a root certificate.

## The network boundary problem

A VPN client becomes dangerous when it runs with high privileges, installs routes, changes DNS, captures all traffic, starts at boot, keeps long-lived credentials, allows inbound access, bridges networks, or runs on the router.

At that point the VPN is not just an app. It is part of your network boundary.

```text
all apps -> VPN tunnel -> remote network
```

If the VPN runs on the router, the privacy app may sit between your whole home network and the outside world.

## The accountability problem

Your local ISP is usually licensed, physically present in your country, connected to your billing relationship, and at least potentially accountable through courts or regulators.

A random VPN provider may be a shell company, renting servers from another provider, operating across jurisdictions, reselling infrastructure, using affiliates, hiding ownership, or changing operators without the user knowing.

So the sharper question is: why replace a regulated local network operator with an anonymous marketing company and call that privacy?

## What VPNs can help with

- hostile public Wi-Fi
- ISP-level blocking
- basic IP hiding from websites
- remote access to your own systems
- geographic routing
- company internal access
- connecting your own devices securely

## What VPNs do not solve

- tracking inside apps
- browser fingerprinting
- server-side logging
- account identity
- payment identity
- cookies
- malware
- phishing
- cloud data ownership
- metadata after the VPN exit
- trust in the service you are using

## Who sees what

[[demo:vpn_who_sees_what]]

A who-sees-what map compares no VPN, commercial VPN, self-hosted VPN, end-to-end sealed message, and EdgeRun relay model.

For commercial VPN, local Wi-Fi sees an encrypted tunnel, the ISP sees the VPN server, the VPN provider sees destinations, timing, and traffic shape, the website sees the VPN IP, the app company still sees account behavior, and advertisers may still identify the user.

For self-hosted VPN, the user controls the tunnel endpoint.

For sealed relay, middlemen can carry traffic while the recipient decrypts locally.

## Main lesson

A VPN is not a privacy shield. It is a pipe. The real question is not "Do I have a VPN?" The real question is "Who did I just move my trust to?"

## EdgeRun seed

The better design is not to keep adding bigger tunnels. The better design is to make the data useless to the tunnel.

Relays should not need to be trusted with content. Routing should not require identity leakage beyond what is necessary. Accounting should prove work without exposing private data. Users should control endpoints. The network should carry sealed objects, not naked user lives wrapped in temporary tunnels.

# The Router: Your First Border Crossing

Your Wi-Fi password does not protect you from the internet. It mostly protects your local air.

Before a message reaches a server, the device usually talks to a router. Wi-Fi encryption protects local radio traffic, but the router still becomes a gatekeeper. It assigns addresses, decides what leaves the home, and can often see which devices connect where.

## Purpose

Explain local networks, Wi-Fi, WPA, routers, NAT, and trust boundaries without pretending one security feature solves every boundary.

## Visual idea

Phone -> Wi-Fi -> router -> ISP connection -> internet

## Interactive demo

A home network map lets the reader toggle open Wi-Fi, WPA, guest network, VPN, and local-only app mode. Each toggle updates what the phone, router, ISP, and app service can see.

## Main lesson

Security is always local to a boundary. WPA protects one boundary. It does not solve identity, metadata, app tracking, server trust, or cloud ownership.

## EdgeRun seed

Local-first systems should keep private data inside your own trust boundary by default.

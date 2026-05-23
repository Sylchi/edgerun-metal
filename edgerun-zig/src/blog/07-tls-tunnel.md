# TLS: A Locked Tunnel To Someone Else's Building

TLS is important. It can stop many observers from reading the content of a connection. But a locked tunnel to a remote building still ends inside someone else's building.

The certificate tells the browser which endpoint it is talking to. It does not prove the endpoint acts for the user, avoids logs, ignores analytics, refuses subpoenas, or keeps plaintext out of internal systems after termination.

## Purpose

Show what TLS protects and what it cannot hide. Encryption protects content in transit, but metadata, endpoint control, server-side plaintext, and account policy are separate questions.

## Visual idea

Device -> encrypted tunnel -> TLS endpoint -> app server -> internal services

## Interactive demo

A tunnel observer lets the reader place observers at Wi-Fi, ISP, CDN, TLS endpoint, and app server positions. The demo marks which actors can see content, metadata, timing, IP addresses, and account identity.

## Main lesson

Connection security is not the same thing as user sovereignty.

## EdgeRun seed

Sealed objects should remain protected by user-held identity keys, not only by the connection that carried them.

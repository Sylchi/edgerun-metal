# DNS: The Internet's Phonebook That Someone Else Controls

You do not really connect to a name. You ask someone where the name points today.

When you type a domain, your device asks a resolver for an address. The resolver may ask root servers, a top-level domain, and an authoritative server before returning an IP address. This makes names useful, but it also creates trust in resolvers, registrars, caches, domain owners, and network policy.

## Purpose

Explain DNS and why names are fragile. Friendly names are not the same thing as cryptographic identity.

## Visual idea

friend.example -> resolver -> root -> TLD -> authoritative server -> IP address

## Interactive demo

A name resolution simulator accepts a domain and shows the lookup path. Failure toggles demonstrate resolver lies, domain expiry, registrar seizure, DNS blocking, and server address changes.

## Main lesson

Names are human-friendly, but ownership and routing are political and economic systems.

## EdgeRun seed

Identity should be cryptographic first. Names should be labels, not the root of trust.

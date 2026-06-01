# 11 Address Spec

## Special Hostnames in Tor

## Overview

Most of the time, Tor treats user-specified hostnames as opaque: When the user connects to <www.torproject.org>, Tor picks an exit node and uses that node to connect to “www.torproject.org”. Some hostnames, however, can be used to override Tor’s default behavior and circuit-building rules.

These hostnames can be passed to Tor as the address part of a SOCKS4a or SOCKS5 request. If the application is connected to Tor using an IP-only method (such as SOCKS4, TransPort, or NATDPort), these hostnames can be substituted for certain IP addresses using the MapAddress configuration option or the MAPADDRESS control command.

## .exit
[code]
      SYNTAX:  [hostname].[name-or-digest].exit
               [name-or-digest].exit

[/code]

Hostname is a valid hostname; [name-or-digest] is either the nickname of a Tor node or the hex-encoded SHA-1 digest of that node’s RSA identity key (`SHA1(DER(KP_relayid_rsa))`).

When Tor sees an address in this format, it uses the specified hostname as the exit node. If no “hostname” component is given, Tor defaults to the published IPv4 address of the exit node.

It is valid to try to resolve hostnames, and in fact upon success Tor will cache an internal mapaddress of the form “www.google.com.foo.exit=64.233.161.99.foo.exit” to speed subsequent lookups.

The .exit notation is disabled by default as of Tor 0.2.2.1-alpha, due to potential application-level attacks.
[code]
      EXAMPLES:
         www.example.com.exampletornode.exit

            Connect to www.example.com from the node called "exampletornode".

         exampletornode.exit

            Connect to the published IP address of "exampletornode" using
            "exampletornode" as the exit.

[/code]

## .onion
[code]
      SYNTAX:  [onion_address].onion
               [ignored].[onion_address].onion

[/code]

For version 3 onion service addresses, `onion_address` is defined as:
[code]
         onion_address = base32(PUBKEY | CHECKSUM | VERSION)
         CHECKSUM = SHA3_256(".onion checksum" | PUBKEY | VERSION)[:2]

         where:
           - PUBKEY is the 32-byte ed25519 master pubkey (KP_hs_id)
             of the onion service.
           - VERSION is a one-byte version field (default value '\x03')
           - ".onion checksum" is a constant string
           - CHECKSUM is truncated to two bytes before inserting it in onion_address

[/code]

When Tor sees an address in this format, it tries to look up and connect to the specified onion service. See rend-spec-v3.txt for full details.

The “ignored” portion of the address is intended for use in vhosting.

---

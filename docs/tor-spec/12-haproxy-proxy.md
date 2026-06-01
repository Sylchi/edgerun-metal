# 12 Haproxy Proxy

## Using the HAProxy PROXY protocol with onion services

# Tor’s support for the HAProxy “PROXY” protocol.

The `PROXY` protocol (sometimes called “HAProxy” due its generic name) is used to send information about a connection to a service.

Some Tor implementations support this protocol for outbound onion service connections, so that local services (such as an HTTP service) can tell which TCP streams are coming from the same onion service.

> Currently, this protocol is supported in C Tor only, when the `HiddenServiceExportCircuitID` option is set.

## With PROXY v1.

> This is known to be a kludge.

For reference, in v1 PROXY protocol (specified in section 2.1 of the PROXY protocol spec), the header is in the format “`PROXY` FAMILY SRCADDR DESTADDR SRCPORT DESTPORT`\r\n`).

When the C Tor is running as an onion service and is configured to use this protocol, it behaves as follows:

“FAMILY” is always `TCP6`.

The source address (SRCADDR) is an IPv6 address. The low 32 bits of “SRCADDR” encode a “unique” 32-bit circuit ID (UCircId), representing the circuit on which the stream arrived. The upper 96 bits of “SRCADDR” SHOULD always be ignored. Implementations SHOULD set them to an arbitrary value within a private address space (such as `fc00::/7`). Implementations MUST always use the same “SRCADDR” value for the same circuit.

> Naturally, a 32-bit value can’t actually be unique. Nonetheless, it should be selected so that collisions between simultaneous circuits are unlikely.

> We choose to use SRCADDR to encode the circuit ID so that a naive server implementation (one not aware of Tor) that wants to report the source of misbehavior, or block misbehaving IPs, is likelier to successfully block the circuits in question.

The destination address (DSTADDR) SHOULD be ignored. The implementation SHOULD set it to `::1`.

The source port (SRCPORT) SHOULD be ignored. The implementation SHOULD set it to an arbitrary value.

The destination port (DESTPORT) SHOULD be ignored. Implementations MUST set it to the virtual port within the onion service that the client connected to.

---

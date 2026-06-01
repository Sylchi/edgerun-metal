# 09 Socks Extensions

## Tor&amp;#x27;s extensions to the SOCKS protocol

# Tor’s extensions to the SOCKS protocol

## Overview

The SOCKS protocol provides a generic interface for TCP proxies. Client software connects to a SOCKS server via TCP, and requests a TCP connection to another address and port. The SOCKS server establishes the connection, and reports success or failure to the client. After the connection has been established, the client application uses the TCP stream as usual.

Except as noted below, Tor supports SOCKS4 as defined here, SOCKS4A as defined here, and SOCKS5 as defined in RFC 1928 and RFC 1929.

The stickiest issue for Tor in supporting clients, in practice, is forcing DNS lookups to occur at the OR side: if clients do their own DNS lookup, the DNS server can learn which addresses the client wants to reach. SOCKS4 supports addressing by IPv4 address; SOCKS4A is a kludge on top of SOCKS4 to allow addressing by hostname; SOCKS5 supports IPv4, IPv6, and hostnames.

### Extent of support

Tor supports the SOCKS4, SOCKS4A, and SOCKS5 standards, _except as follows_ :

**SOCKS4** , **SOCKS4A** :

  * The BIND command is not supported.

**SOCKS5** :

  * The SOCKS5 “UDP ASSOCIATE” command is not supported.
  * The SOCKS5 “BIND” command is not supported.
  * SOCKS5 GSSAPI authentication, and its subnegotiation protocol, are not supported, even though they are listed as “MUST support” by RFC 1928.
  * As an extension to support some broken clients, the C tor implementation allows clients to pass “USERNAME/PASSWORD” authentication message to us even if “NO AUTHENTICATION REQUIRED” was selected in the “METHOD selection message”. (In such cases, the provided “USERNAME/PASSWORD” authentication message is interpreted as if “USERNAME/PASSWORD” authentication had been selected in the “METHOD selection message.”) This technically violates RFC 1929, but ensures interoperability with somewhat broken SOCKS5 client implementations.

## Name lookup

As an extension to SOCKS4A and SOCKS5, Tor implements a new command value, “`RESOLVE`” (`[F0]`). When Tor receives a `RESOLVE` SOCKS command, it initiates a remote lookup of the hostname provided as the target address in the SOCKS request. The reply is either an error (if the address couldn’t be resolved) or a success response. In the case of success, the address is stored in the portion of the SOCKS response reserved for remote IP address.

(We support `RESOLVE` in SOCKS4 too, even though it is unnecessary.)

For SOCKS5 only, we support reverse resolution with a new command value, `RESOLVE_PTR` (`[F1]`). In response to a `RESOLVE_PTR` SOCKS5 command with an IPv4 address as its target, Tor attempts to find the canonical hostname for that IPv4 record, and returns it in the “server bound address” portion of the reply. (This command was not supported before Tor 0.1.2.2-alpha.)

## HTTP-resistance

Tor checks the first byte of each SOCKS request to see whether it looks more like an HTTP request (that is, it starts with a “G”, “H”, or “P”). If so, Tor returns a small webpage, telling the user that their browser is misconfigured. This is helpful for the many users who mistakenly try to use Tor as an HTTP proxy instead of a SOCKS proxy.

## Optimistic data

Tor allows SOCKS clients to send connection data before Tor has sent a SOCKS response. Tor will package such data and send it to the exit, without waiting to see whether the connection attempt succeeds. This behavior can save a single round-trip time when starting connections with a protocol where the client speaks first (like HTTP). Clients that do this must be ready to hear that their connection has succeeded or failed _after_ they have sent the data.

## Extended error codes

We define a set of additional extension error codes that can be returned by our SOCKS implementation in response to failed onion service connections.

(In the C Tor implementation, these error codes can be disabled via the ExtendedErrors flag. In Arti, these error codes are enabled whenever onion services are.)

  * `[F0]` Onion Service Descriptor Can Not be Found

The requested onion service descriptor can’t be found on the hashring and thus not reachable by the client.

  * `[F1]` Onion Service Descriptor Is Invalid

The requested onion service descriptor can’t be parsed or signature validation failed.

  * `[F2]` Onion Service Introduction Failed

Client failed to introduce to the service meaning the descriptor was found but the service is not anymore at the introduction points. The service has likely changed its descriptor or is not running.

  * `[F3]` Onion Service Rendezvous Failed

Client failed to rendezvous with the service which means that the client is unable to finalize the connection.

  * `[F4]` Onion Service Missing Client Authorization

Tor was able to download the requested onion service descriptor but is unable to decrypt its content because it is missing client authorization information for it.

  * `[F5]` Onion Service Wrong Client Authorization

Tor was able to download the requested onion service descriptor but is unable to decrypt its content using the client authorization information it has. This means the client access were revoked.

  * `[F6]` Onion Service Invalid Address

The given .onion address is invalid. In one of these cases this error is returned: address checksum doesn’t match, ed25519 public key is invalid or the encoding is invalid.

  * `[F7]` Onion Service Introduction Timed Out

Similar to `[F2]` code but in this case, all introduction attempts have failed due to a time out.

(Note that not all of the above error codes are currently returned by Arti as of August 2023.)

## Interpreting usernames and passwords

We support a series of extensions in SOCKS5 Username/Passwords. Currently, these extensions can encode a stream isolation parameter (used to indicate that streams may share a circuit) and an RPC object ID (used to associate the stream with an entity in an RPC session).

These extensions are in use whenever the SOCKS5 Username begins with the 8-byte “magic” sequence `[3c 74 6f 72 53 30 58 3e]`. (This is the ASCII encoding of `<torS0X>`).

If the SOCKS5 Username/Password fields are present but the Username does not begin with this byte sequence, it indicates _legacy isolation_. New client implementations SHOULD NOT use legacy isolation. A SocksPort may be configured to reject legacy isolation.

When these extensions are in use, the next byte of the username after the “magic” sequence indicate a format type. Any implementation receiving an unrecognized or missing format type MUST reject the socks request.

  * When the format type is `[30]` (the ascii encoding of `0`), we interpret the rest of the Username field and the Password field as follows:

The remainder of the Username field must be empty.

The Password field is stream isolation parameter. If it is empty, the stream isolation parameter is an empty string.

  * When the format type is `[31]` (the ascii encoding of `1`), we interpret the rest of the Username and field and the Password field as follows:

The remainder of the Username field encodes an RPC Object ID. It must not be empty.

The Password field is stream isolation parameter. If it is empty, the stream isolation parameter is an empty string.

All implementations SHOULD implement format type `[30]`.

> Tor began supporting format type `[30]` in 0.4.9.1-alpha. Arti began supporting format types `[30]` and `[31]` in 1.2.8.
>
> Note however that using format type `[30]` will have the intended effect with older versions of Tor and Arti, even though they will interpret it as legacy isolation.

> Examples:
>
>   * Username=`hello`; Password=`world`. These are legacy parameters, since `hello` does not begin with `<torS0X>`.
>
>   * Username=`<torS0X>0`; Password=`123`. There is no associated object ID. The isolation string is `123`.
>
>   * Username=`<torS0X>0`; Password is empty. There is no associated object ID. The isolation string is empty.
>
>   * Username=`<torS0X>1abc`; Password=`123`. The object ID is `abc`. The isolation string is `123`.
>
>   * Username=`<torS0X>1abc`; Password is empty. The object ID is `abc`. The isolation string is empty.
>
>   * Username=`<torS0X>0abc`; Password=`123`. Error: The format type is `0` but there is extra data in the username. Implementations must reject this.
>
>   * Username=`<torS0X>1`; Password=`123`. Error: The format type is `1` but the object ID is empty. Implementations must reject this.
>
>   * Username=`<torS0X>9`; Password=`123`. Error: The format type `9` is unspecified. Implementations must reject this.
>
>   * Username=`<torS0X>`; Password=`123`. Error: There is no format type. Implementations must reject this.
>
>

## Stream isolation

Two streams are considered to have the same SOCKS authentication values if and only if one of the following is true:

  * They are both SOCKS4 or SOCKS4a, with the same user “ID” string.
  * They are both SOCKS5, with no authentication.
  * They are both SOCKS5 with USERNAME/PASSWORD authentication, using legacy isolation parameters, and they have identical usernames and identical passwords.
  * They are both SOCKS5 using the extensions above, with the same stream isolation parameter.

Additionally, two streams with different format types (e.g. `[30]` and `[31]`) may not share a circuit.

> For more information on stream isolation, including other factors that can prevent streams from sharing circuits, see “Stream isolation and circuit sharing”.

## Inferring IP version preference

The Tor protocol’s `BEGIN` messages include flags to indicate preferences for IPv4 versus IPv6.

When opening streams based on SOCKS requests, the “IPv6 okay” flag is set, and the other flags are left cleared, except as follows:

If the address is an IPv4 address (received via SOCKS4, SOCKS5 address type 1, or a hostname string containing a literal IPv4 address) then the “IPv6 okay” flag is cleared.

If the address is an IPv6 address (via SOCKS5 address type 4, or a hostname string containing a literal IPv6 address) then the “IPv4 not okay” flag is set.

User-specified configuration options may override this behavior.

---

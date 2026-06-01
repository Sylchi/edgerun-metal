# 10 Http Connect

## Tor&amp;#x27;s support for HTTP CONNECT, and extensions

# Tor’s support for HTTP CONNECT, and extensions

The C Tor implementation supports the HTTP CONNECT protocol for providing a TCP tunnel over the Tor network.

HTTP is more readily extensible than SOCKS, and so it allows applications and Tor proxies to better communicate structured information about their needs.

Here we will outline the amount of HTTP support that Tor provides, and describe the extensions that it supports.

## HTTP CONNECT support

A Tor proxy supporting HTTP CONNECT _should_ implement the CONNECT method as specified in RFC 9110 s9.3.6. It SHOULD NOT support any other HTTP methods.

HTTP 1.0 support is mandatory; other HTTP versions are optional.

> HTTP 1.0 doesn’t actually specify the CONNECT method. But C Tor approximates an implementation of HTTP 1.0 only, so we do not currently require HTTP 1.1.

As with other proxy ports, Tor SHOULD NOT listen on publicly reachable addresses.

All CONNECT requests received at the HTTP CONNECT port should either be rejected, or handled by making a connection over the Tor network and forwarding their data. No request should be forwarded in any other way.

## OPTIONS method support

Implementations SHOULD implement the OPTIONS method. It SHOULD return an `Allow` header indicating the permitted methods, which SHOULD be CONNECT and OPTIONS.

> Clients can use this feature to inspect `Server` and `Tor-Capabilities` headers without actually making a connection.
>
> When supported by the proxy, clients SHOULD use HTTP/1.1 to make OPTIONS requests, and use the same TCP connection for any CONNECT request that relies on its output. Using separate TCP connections for OPTIONS and CONNECT can result in time-of-check/time-of-use issues.

(Supported by Arti, and by C Tor since 0.4.9.4-alpha.)

## Avoiding cross-site probing attacks

To prevent attackers from using DNS-rebinding to circumvent cross-site enforcement, the proxy MUST inspect the Host header on every request whose method is not CONNECT. If the target address is anything other than “localhost”, “127.0.0.1”, or “::1”, then the proxy MUST reject the request and close the stream **without replying, even with an error.**

> For defense in depth, Tor Browser already uses NoScript LAN protection to prevent connections to localhost altogether. This mechanism is still valuable, since it does help prevent a non-patched browser from being used to probe whether a Tor proxy is running at some known port.

(Arti and C Tor.)

## Error codes

Tor provides the following mapping from Tor END reasons to HTTP error codes:

> These aren’t necessarily sensible, and will likely change in the future.

END reason| HTTP status code
---|---
MISC| 500
RESOLVEFAILED| 503 1
NOROUTE| 503 1
CONNECTREFUSED| 403
EXITPOLICY| 503
DESTROY| 502
DONE2| 502
TIMEOUT| 504
HIBERNATING| 502
INTERNAL| 502
RESOURCELIMIT| 502
CONNRESET| 503
TORPROTOCOL| 502
NOTADIRECTORY3| 500
anything else| 500

Implementations SHOULD include information about the actual error code in the Reason-Phrase part of the Status-Line.

Note that once a connection has _succeeded_ , no subsequent status code for an END reason will be sent, since Tor already sent a “200 OK”.

> TODO: Specify specific return values, and/or messages, and/or headers, for onion-service-specific issues.

## Standard headers

> Except as noted here, and in “Extended headers” below, the C tor implementation doesn’t parse or send any HTTP headers.
>
> If this is non-conformant, we should change it.

### Proxy-Authorization: Backward compatible isolation

(Request only.)

The `Proxy-Authorization` header is sent by the application, and used as an input for stream isolation; see “Stream isolation” below.

Applications intending to use this behavior SHOULD use `basic` authentication, and set the username to `tor-iso`. Implementations SHOULD warn if the `Proxy-Authorization` header has a different value.

> C Tor does not impose an upper length limit on this header.

### `Via` / `Server`: Reporting proxy software version

(Response only.)

An indication of which software has answered the request.

“Via” is appropriate in response to CONNECT requests; “Server” is appropriate in response to OPTIONS requests.

The “via” header should include the name of the software, and its version, as the comment field. In “via”, the received-protocol and received-by fields should be set to “tor/1.0” and “tor-network” respectively, as in:
[code]
    Via: tor/1.0 tor-network (Tor 0.4.9.4-alpha)

[/code]

In “Server”, we use “tor/1.0” as the product, and place the software name and version in its comment field, as in:
[code]
    Server: tor/1.0 (Arti 1.7.0)

[/code]

Proxies MUST NOT include “tor/1.0” here unless they forward user traffic over anonymous Tor connections.

Clients MAY check for the presence or absence of this header.

Clients MUST NOT inspect the contents of this header to determine whether a given feature is supported or not; they should use `Tor-Capabilities` instead.

Clients MAY use this to determine whether some software has a particular bug, but the matching SHOULD NOT treat any future versions as buggy.

> That is, the ideal approach is to use
[code]
>     if (version in FIRST_BROKEN_VERSION .. LAST_BROKEN_VERSION) {
>        use workaround
>     }
>
[/code]
>
> but until the bug is fixed, developers will not know what `LAST_BROKEN_VERSION` is.
>
> What developers SHOULD NOT do is write `if (version >= FIRST_BROKEN_VERSION)`, since that will still apply the workaround when the bug is fixed.

(Supported by Arti, and by C Tor since 0.4.9.4-alpha.)

## Extensions

Here we describe Tor’s behaviors that are in addition to those of a standard HTTP CONNECT tunnel.

### Determining IP version preference

Tor applies the same rules to HTTP CONNECT requests as it does to SOCKS5 requests when determining which IP versions to request or allow.

### Extended headers

All new headers specified for use with Tor will begin with `Tor-`.

The “X-Tor-” prefix is reserved for historical extensions, and is deprecated for the reasons explained in RFC 6648.

### Tor-Stream-Isolation: Stream isolation

(Request only.)

The `X-Tor-Stream-Isolation` header is sent by the application, and used as an input for stream isolation; see “Stream isolation” below.

It can appear only once; subsequent occurrences are ignored.

> C Tor has accepted this header since 0.4.9.4-alpha.
>
> C Tor does not impose an upper length limit on this header.

### X-Tor-Stream-Isolation: Legacy stream isolation

(Request only.)

This is an old alternative to for `Tor-Stream-Isolation` for use with Tor 0.4.9.3-alpha and earlier.

All implementations SHOULD accept it, for backward compatibility.

> C Tor does not impose an upper length limit on this header.

### `Tor-RPC-Target`: Arti RPC Support

(Request only.)

Contains an Arti RPC Object ID, to be used as a target for an RPC request.

Implementations SHOULD reject such requests if the target RPC object does not exist.

An implementation that generally supports Tor extensions, but that doesn’t support Arti RPC, SHOULD reject requests containing this header.

> (Arti implements RPC behavior; C Tor implements “reject” behavior.)

### `Tor-Request-Failed`: Extended error codes

(Response only.)

A space-separated list of tokens, each of which indicates a reason why the requested connection could not be completed.

> The specific members of this list are not currently documented.
>
> We intend that they will eventually correspond to all the current END reasons, and all the onion-service-specific SOCKS failure codes.

(Arti only.)

### `Tor-Family-Preference`: IP version preferences

(Request only.)

Tor allows the client to transmit its preferences for IP versions as part of its BEGIN message.

We allow these to be encoded in an HTTP CONNECT header, `Tor-Family-Preference`.

Permitted values are:

  * `ipv4-preferred` (any family allowed; ipv4 preferred)
  * `ipv6-preferred` (any family allowed; ipv6 preferred)
  * `ipv4-only` (only ipv4 is allowed)
  * `ipv6-only` (only ipv6 is allowed)

The default is “ipv4-preferred”.

Any unrecognized value SHOULD be treated as “ipv4-preferred”.

(Arti only.)

### `Tor-Capabilities`: Determining specific extensions

(Response only.)

In responses, proxies SHOULD include a `Tor-Capabilities` header containing a space-separated list of capabilities. Clients MAY use this header to decide whether a required capability is present.

All new features that we add will have a corresponding capability. Clients SHOULD check for these capabilities whenever they are using a feature which, if absent, would be insecure.

Every request header has a capability of the same name, to indicate that the header will be recognized and processed if sent.

(Supported by Arti, and by C Tor since 0.4.9.4-alpha.)

### Stream isolation

The isolation value of an HTTP CONNECT stream is a tuple of its “Proxy-Authorization” header (if any), its “Tor-Stream-Isolation” header (if any), and its “X-Tor-Stream-Isolation” header (if any).

> When possible, applications should prefer `Tor-Stream-Isolation`, then `X-Tor-Stream-Isolation` `Proxy-Authorization` is supported in this role only to work with HTTP libraries that make it difficult to set arbitrary headers.

In contrast to the HTTP spec, implementations MAY ignore HTTP space-folding rules when comparing these headers for equality.

Two HTTP CONNECT streams are not allowed to share a circuit if they have different isolation values.

> For stream isolation purposes, C Tor considers a “Proxy-Authentication: X”, “X-Tor-Stream-Isolation: Y” tuple to be equivalent to SOCKS5 authentication with username=X and password=Y.
>
> We are unlikely to preserve this equivalence in Arti without further examination.

> For more information on stream isolation, including other factors that can prevent streams from sharing circuits, see “Stream isolation and circuit sharing”.

  1. In versions of Tor before 0.4.9.4-alpha, RESOLVEFAILED and NOROUTE produced status code 404. ↩ ↩2

  2. A regular DONE reason, if it arrives after a CONNECTED message, won’t trigger a status line, since the CONNECTED message already triggered a “200 OK” status line. ↩

  3. Applications should be unable to trigger a NOTADIRECTORY reason, since it should only happen in response to a BEGINDIR message. ↩

---

# 02 Tor Protocol

Note: This document aims to specify Tor as currently implemented, though it may take it a little time to become fully up to date. Future versions of Tor may implement improved protocols, and compatibility is not guaranteed. We may or may not remove compatibility notes for other obsolete versions of Tor as they become obsolete.

This specification is not a design document; most design criteria are not examined. For more information on why Tor acts as it does, see tor-design.pdf.

## Cells (messages on channels)

The basic unit of communication on a Tor channel is a “cell”.

Once a TLS connection is established, the two parties send cells to each other. Cells are sent serially, one after another.

Cells may be sent embedded in TLS records of any size, or divided across TLS records, but the framing of TLS records MUST NOT leak information about the type or contents of the cells.

Most cells are of fixed length, with the actual length depending on the negotiated link protocol on the channel. Below we designate the negotiated protocol as `v`.

As an exception, `VERSIONS` cells are always sent with `v = 0`, since no version has yet been negotiated.

A fixed-length cell has this format:

Field| Size in bytes| Notes
---|---|---
`CircID`| `CIRCID_LEN(v)`|
`Command`| 1|
`Body`| `CELL_BODY_LEN`| Padded to fit

The value of `CIRCID_LEN` depends on the negotiated link protocol.

Some cells have variable length; the length of these cells is encoded in their header.

A variable-length cell has this format:

Field| Size in bytes| Notes
---|---|---
`CircID`| `CIRCID_LEN(v)`|
`Command`| 1|
`Length`| 2| A big-endian integer
`Body`| `Length`|

Fixed-length and variable-length cells are distinguished based on the value of their Command field:

  * Command 7 (`VERSIONS`) is variable-length.
  * Every other command less than 128 denotes a fixed-length cell.
  * Every command greater than or equal to 128 denotes a variable-length cell.

> Historical note:
>
> On version 1 connections, all cells were fixed-length.
>
> On version 2 connections, only the `VERSIONS` command was variable-length, and all others were fixed-length.
>
> These link protocols are obsolete, and implementations SHOULD NOT support them.

## Interpreting the fields: CircID

The `CircID` field determines which circuit, if any, the cell is associated with. If the cell is not associated with any circuit, its `CircID` is set to 0.

>
> A single multi-hop circuit will have a different CircID on every channel that is used to transmit its data.

## Interpreting the fields: Command

The `Command` field of a fixed-length cell holds one of the following values:

Value| C| P| Identifier| Description
---|---|---|---|---
0| N| | `PADDING`| Link Padding
1| Y| | `CREATE`| Create circuit (deprecated)
2| Y| | `CREATED`| Acknowledge CREATE (deprecated)
3| Y| | `RELAY`| End-to-end data
4| Y| | `DESTROY`| Destroy circuit
5| Y| | `CREATE_FAST`| Create circuit, no public key
6| Y| | `CREATED_FAST`| Acknowledge CREATE_FAST
8| N| | `NETINFO`| Time and address info
9| Y| | `RELAY_EARLY`| End-to-end data; limited
10| Y| | `CREATE2`| Create circuit
11| Y| | `CREATED2`| Acknowledge CREATED2
12| Y| 5| `PADDING_NEGOTIATE`| Padding negotiation

The variable-length `Command` values are:

Value| C| P| Identifier| Description
---|---|---|---|---
7| N| | `VERSIONS`| Negotiate link protocol
128| N| | `VPADDING`| Variable-length padding
129| N| | `CERTS`| Certificates
130| N| | `AUTH_CHALLENGE`| Challenge value
131| N| | `AUTHENTICATE`| Authenticate initiator
132| N| n/a| `AUTHORIZE`| (Reserved)

In the tables above, **C** =Y indicates that a command must have a nonzero CircId, and **C** =N indicates that a command must have a zero CircId. Where given, **P** is the first link protocol version to support a command. Commands with no value given for **P** are supported at least in link protocols 3 and above.

No other command values are allowed. Implementations SHOULD NOT send undefined command values. Upon receiving an unrecognized command, an implementation MAY silently drop the cell and MAY terminate the channel with an error.

> Extensibility note:
>
> When we add new cell command types, we define a new link protocol version to indicate support for that command.
>
> Therefore, implementations can now safely assume that other correct implementations will never send them an unrecognized cell command.
>
> Historically, before the link protocol was not versioned, implementations would drop cells with unrecognized commands, under the assumption that the command was sent by a more up-to-date version of Tor.

## Interpreting the fields: Cell Body

The interpretation of a cell’s Body depends on the cell’s command. See the links in the command descriptions above for more information on each command.

## Padding fixed-length cell bodies

Often, the amount of information to be sent in a fixed-length cell is less than `CELL_BODY_LEN` bytes. When this happens, the sender MUST fill the unused part of the cell’s body with zero-valued bytes.

Recipients MUST ignore padding bytes.

> RELAY and RELAY_EARLY cells’ bodies contain encrypted data, and are always full from the point of the view of the channel layer.
>
> The _plaintext_ of these cells’ contents may be padded; this uses a different mechanism and does not interact with cell body padding.

Variable-length cells never have extra space, so there is no need to pad their bodies. Unless otherwise specified, variable-length cells have no padding.

## Channels

A channel is a direct encrypted connection between two Tor relays, or between a client and a relay.

Channels are implemented as TLS sessions over TCP.

Clients and relays may both open new channels; only a relay may be the recipient of a channel.

> Historical note: in some older documentation, channels were sometimes called “connections”. This proved to be confusing, and we are trying not to use the term.

As part of establishing a channel, the responding relay will always prove cryptographic ownership of one or more **relay identities**, using a handshake that combines TLS facilities and a series of Tor cells.

As part of this handshake, the initiator MAY also prove cryptographic ownership of its own relay identities, if it has any: public relays SHOULD prove their identities when they initiate a channel, whereas clients and bridges SHOULD NOT do so.

Parties should usually reuse an existing channel rather than opening new a channel to the same relay. There are exceptions here; we discuss them more below.

To open a channel, a client or relay must know the IP address and port of the target relay. (This is sometimes called the “OR address” or “OR port” for the relay.) In most cases, the participant will also know one or more expected identities for the target relay, and will reject the channel if the target relay cannot cryptographically prove ownership of those identities.

> (When initiating a connection, if a reasonably live consensus is available, then the expected identity key is taken from that consensus. But when initiating a connection otherwise, the expected identity key is the one given in the hard-coded authority or fallback list. Finally, when creating a connection because of an EXTEND/EXTEND2 message, the expected identity key is the one given in the message.)

Opening a channel is multi-step process:

  1. The initiator opens a new TLS session with certain properties, and the responding relay checks and enforces those properties.
  2. Both parties exchange cells over this TLS session in order to establish their identity or identities.
  3. Both parties verify that the identities that they received are the ones that they expected. (If any expected key is missing or not as expected, the party MUST close the connection.)

Once this is done, the channel is Open, and regular cells can be exchanged.

## Channel lifetime

Channels are not permanent. Either side MAY close a channel if there are no circuits running on it and an amount of time (KeepalivePeriod, defaults to 5 minutes) has passed since the last time any traffic was transmitted over it. Clients SHOULD also hold a TLS connection with no circuits open, if it is likely that a circuit will be built soon using that connection.

## Circuit management

This section describes how circuits are created, and how they operate once they are constructed.

## Closing streams

When an anonymized TCP connection is closed, or an edge node encounters error on any stream, it sends a ‘RELAY_END’ message along the circuit (if possible) and closes the TCP connection immediately. If an edge node receives a ‘RELAY_END’ message for any stream, it closes the TCP connection completely, and sends nothing more along the circuit for that stream.

The body of a RELAY_END message begins with a single ‘reason’ byte to describe why the stream is closing. For some reasons, it contains additional data (depending on the reason.) The values are:
[code]
           1 -- REASON_MISC           (catch-all for unlisted reasons)
           2 -- REASON_RESOLVEFAILED  (couldn't look up hostname)
           3 -- REASON_CONNECTREFUSED (remote host refused connection) [*]
           4 -- REASON_EXITPOLICY     (Relay refuses to connect to host or port)
           5 -- REASON_DESTROY        (Circuit is being destroyed)
           6 -- REASON_DONE           (Anonymized TCP connection was closed)
           7 -- REASON_TIMEOUT        (Connection timed out, or relay timed out
                                       while connecting)
           8 -- REASON_NOROUTE        (Routing error while attempting to
                                       contact destination)
           9 -- REASON_HIBERNATING    (Relay is temporarily hibernating)
          10 -- REASON_INTERNAL       (Internal error at the relay)
          11 -- REASON_RESOURCELIMIT  (Relay has no resources to fulfill request)
          12 -- REASON_CONNRESET      (Connection was unexpectedly reset)
          13 -- REASON_TORPROTOCOL    (Sent when closing connection because of
                                       Tor protocol violations.)
          14 -- REASON_NOTDIRECTORY   (Client sent RELAY_BEGIN_DIR to a
                                       non-directory relay.)

       [*] Older versions of Tor also send this reason when connections are
           reset.

[/code]

Clients and relays MUST accept reasons not on the above list, since future versions of Tor may provide more fine-grained reasons.

For most reasons, the format of RELAY_END is:

Reason [1 byte]

For REASON_EXITPOLICY, the format of RELAY_END is:
[code]
          Reason                      [1 byte]
          IPv4 or IPv6 address        [4 bytes or 16 bytes]
          TTL                         [4 bytes]

[/code]

(If the TTL is absent, it should be treated as if it were 0xffffffff. If the address is absent or is the wrong length, the RELAY_END message should be processed anyway.)

Tors SHOULD NOT send any reason except REASON_MISC for a stream that they have originated.

Implementations SHOULD accept empty RELAY_END messages, and treat them as if they specified REASON_MISC.

Upon receiving a RELAY_END message, the recipient may be sure that no further messages will arrive on that stream, and can treat such messages as a protocol violation.

Upon receiving a RELAY_END message, the recipient MAY respond with a RELAY_END message with the reason set to REASON_MISC.

> Note: as of 2025 current implementations do not automatically send RELAY_END after receiving RELAY_END.

After sending a RELAY_END message, the sender needs to give the recipient time to receive that message. In the meantime, the sender SHOULD remember how many messages of which types (CONNECTED, SENDME, DATA) it would have accepted on that stream, and SHOULD kill the circuit if it receives more than permitted.

— [The rest of this section describes unimplemented functionality.]

Because TCP connections can be half-open, we follow an equivalent to TCP’s FIN/FIN-ACK/ACK protocol to close streams.

An exit (or onion service) connection can have a TCP stream in one of three states: ‘OPEN’, ‘DONE_PACKAGING’, and ‘DONE_DELIVERING’. For the purposes of modeling transitions, we treat ‘CLOSED’ as a fourth state, although connections in this state are not, in fact, tracked by the onion router.

A stream begins in the ‘OPEN’ state. Upon receiving a ‘FIN’ from the corresponding TCP connection, the edge node sends a ‘RELAY_FIN’ message along the circuit and changes its state to ‘DONE_PACKAGING’. Upon receiving a ‘RELAY_FIN’ message, an edge node sends a ‘FIN’ to the corresponding TCP connection (e.g., by calling shutdown(SHUT_WR)) and changing its state to ‘DONE_DELIVERING’.

When a stream in already in ‘DONE_DELIVERING’ receives a ‘FIN’, it also sends a ‘RELAY_FIN’ along the circuit, and changes its state to ‘CLOSED’. When a stream already in ‘DONE_PACKAGING’ receives a ‘RELAY_FIN’ message, it sends a ‘FIN’ and changes its state to ‘CLOSED’.

If an edge node encounters an error on any stream, it sends a ‘RELAY_END’ message (if possible) and closes the stream immediately.

## Creating and extending circuits

Users set up circuits incrementally, one hop at a time. To create a new circuit, clients send a CREATE2 cell to the first node, with the first half of an authenticated handshake; that node responds with a CREATED2 cell with the second half of the handshake. To extend a circuit past the first hop, the client sends an EXTEND2 client relay message (see Extend and Extended messages which instructs the last node in the circuit to send a CREATE2 cell to extend the circuit.

In addition to CREATE2 and CREATED2 cells, there are also:

  * An obsolete “CREATE/CREATED format used in old versions of Tor.
  * A specialized “CREATE_FAST/CREATED_FAST” format for one hop circuits.

## Create and Created cells

A CREATE2 cell contains:

Field| Description| Size
---|---|---
`HTYPE`| Client Handshake Type| 2 bytes
`HLEN`| Client Handshake Data Len| 2 bytes
`HDATA`| Client Handshake Data| `HLEN` bytes

A CREATED2 cell contains:

Field| Description| Size
---|---|---
`HLEN`| Server Handshake Data Len| 2 bytes
`HDATA`| Server Handshake Data| `HLEN` bytes

Recognized HTYPEs (handshake types) are:

Value| Description
---|---
0x0000| TAP – the original (obsolete) Tor handshake; see The “TAP” handshake
0x0001| reserved
0x0002| ntor – the ntor+curve25519+sha256 handshake; see The “ntor” handshake
0x0003| ntor-v3 – ntor extended with extra data; see The “ntor-v3” handshake

Relays always respond to a successful CREATE2 with a CREATED2. On failure, the relay sends a DESTROY to shut down the circuit.

[CREATE2 is handled by Tor 0.2.4.7-alpha and later.]

## Choosing circuit IDs in create cells

The CircID for a CREATE2 cell is a nonzero integer, selected by the node (client or relay) that sends the CREATE2 cell. Depending on the link protocol version, there are certain rules for choosing the value of CircID which MUST be obeyed, as implementations MAY decide to refuse in case of a violation. In link protocol 3 or lower, CircIDs are 2 bytes long; in protocol 4 or higher, CircIDs are 4 bytes long.

In link protocol version 3 or lower, the nodes choose from only one half of the possible values based on the relays’ public identity keys, in order to avoid collisions. If the sending node has a lower key, it chooses a CircID with an MSB of 0; otherwise, it chooses a CircID with an MSB of 1. (Public keys are compared numerically by modulus.) A client with no public key MAY choose any CircID it wishes, since clients never need to process CREATE2 cells.

In link protocol version 4 or higher, whichever node initiated the connection MUST set its MSB to 1, and whichever node didn’t initiate the connection MUST set its MSB to 0.

The CircID value 0 is specifically reserved for cells that do not belong to any circuit: CircID 0 MUST not be used for circuits. No other CircID value, including 0x8000 or 0x80000000, is reserved.

Existing Tor implementations choose their CircID values at random from among the available unused values. To avoid distinguishability, new implementations should do the same. Implementations MAY give up and stop attempting to build new circuits on a channel, if a certain number of randomly chosen CircID values are all in use (today’s Tor stops after 64).

## Extend and Extended messagess

To extend an existing circuit, the client sends an EXTEND2 message, in a RELAY_EARLY cell, to the last node in the circuit.

The body of an EXTEND2 message contains:

Field| Description| Size
---|---|---
`NSPEC`| Number of link specifiers| 1 byte
`NSPEC` times:| |
\- `LSTYPE`| Link specifier type| 1 byte
\- `LSLEN`| Link specifier length| 1 byte
\- `LSPEC`| Link specifier| LSLEN bytes
`HTYPE`| Client Handshake Type| 2 bytes
`HLEN`| Client Handshake Data Len| 2 bytes
`HDATA`| Client Handshake Data| HLEN bytes

Link specifiers describe the next node in the circuit and how to connect to it. Recognized specifiers are:

Value| Description
---|---
[00]| TLS-over-TCP, IPv4 address. A four-byte IPv4 address plus two-byte ORPort.
[01]| TLS-over-TCP, IPv6 address. A sixteen-byte IPv6 address plus two-byte ORPort.
[02]| Legacy identity. A 20-byte SHA-1 identity fingerprint. At most one may be listed.
[03]| Ed25519 identity. A 32-byte Ed25519 identity. At most one may be listed.

Nodes MUST ignore unrecognized specifiers, and MUST accept multiple instances of specifiers other than ‘legacy identity’ and ‘Ed25519 identity’. (Nodes SHOULD reject link specifier lists that include multiple instances of either one of those specifiers.)

For purposes of indistinguishability, implementations SHOULD send these link specifiers, if using them, in this order: [00], [02], [03], [01].

The “Ed25519 identity” field is the Ed25519 identity key (`KP_relayid_ed`) of the target node. Including this key information allows the relay extending to verify that it is indeed connected to the correct target relay, and prevents certain man-in-the-middle attacks.

The “legacy identity” and “identity fingerprint” fields are computed as `SHA1(DER(KP_relayid_rsa))`.

The extending relay MUST check _all_ provided identity keys (if they recognize the format), and and MUST NOT extend the circuit if the target relay did not prove its ownership of any such identity key. If only one identity key is provided, but the extending relay knows the other (from directory information), then the relay SHOULD also enforce the key in the directory.

If the extending relay has a channel with a given Ed25519 ID and RSA identity, and receives a request for that Ed25519 ID and a different RSA identity, it SHOULD NOT attempt to make another connection: it should just fail and DESTROY the circuit.

The client MAY include multiple IPv4 or IPv6 link specifiers in an EXTEND2 message; current relay implementations only consider the first of each type.

After checking relay identities, extending relays generate a CREATE2 cell from the contents of the EXTEND2 message. See Creating circuits for details.

The body of an EXTENDED2 message is the same as the body of a CREATED2 cell.

[Support for EXTEND2/EXTENDED2 was added in Tor 0.2.4.8-alpha.]

When generating an EXTEND2 message, clients SHOULD include the target’s Ed25519 identity whenever the target has one, and whenever the target supports the subprotocol “LinkAuth=3” (`LINKAUTH_ED25519_SHA256_EXPORTER`). (See LinkAuth).

## The “ntor” handshake

This handshake uses a set of DH handshakes to compute a set of shared keys which the client knows are shared only with a particular server, and the server knows are shared with whomever sent the original handshake (or with nobody at all). Here we use the “curve25519” group and representation as specified in “Curve25519: new Diffie-Hellman speed records” by D. J. Bernstein.

Clients should only use the ntor handshake when they have no extensions to send. When a client _does_ have extensions, it MUST use ntor-v3.

> In practice, modern Tor clients _always_ have extensions to send, and all relays provide ntor-v3, so clients will always use ntor-v3.

[The ntor handshake was added in Tor 0.2.4.8-alpha.]

In this section, define:
[code]
    H(x,t) as HMAC_SHA256 with message x and key t.
    H_LENGTH  = 32.
    ID_LENGTH = 20.
    G_LENGTH  = 32
    PROTOID   = "ntor-curve25519-sha256-1"
    t_mac     = PROTOID | ":mac"
    t_key     = PROTOID | ":key_extract"
    t_verify  = PROTOID | ":verify"
    G         = The preferred base point for curve25519 ([9])
    KEYGEN()  = The curve25519 key generation algorithm, returning
                a private/public keypair.
    m_expand  = PROTOID | ":key_expand"
    KEYID(A)  = A
    EXP(a, b) = The ECDH algorithm for establishing a shared secret.

[/code]

To perform the handshake, the client needs to know `NODEID = SHA1(DER(KP_relayid_id))` for the server, and an ntor onion key (a curve25519 public key, `KP_onion_ntor`) for that server. Call the ntor onion key `B`. The client generates a temporary keypair:
[code]
    x,X = KEYGEN()

[/code]

and generates a client-side handshake with contents:

Field| Value| Size
---|---|---
`NODEID`| Server identity digest| `ID_LENGTH` bytes
`KEYID`| KEYID(B)| `H_LENGTH` bytes
`CLIENT_KP`| X| `G_LENGTH` bytes

The server generates a keypair of `y,Y = KEYGEN()`, and uses its ntor private key `b` to compute:
[code]
    secret_input = EXP(X,y) | EXP(X,b) | ID | B | X | Y | PROTOID
    KEY_SEED = H(secret_input, t_key)
    verify = H(secret_input, t_verify)
    auth_input = verify | ID | B | Y | X | PROTOID | "Server"

[/code]

The server’s handshake reply is:

Field| Value| Size
---|---|---
`SERVER_KP`| `Y`| `G_LENGTH` bytes
`AUTH`| `H(auth_input, t_mac)`| `H_LENGTH` bytes

The client then checks `Y` is in G* [see NOTE below], and computes
[code]
    secret_input = EXP(Y,x) | EXP(B,x) | ID | B | X | Y | PROTOID
    KEY_SEED = H(secret_input, t_key)
    verify = H(secret_input, t_verify)
    auth_input = verify | ID | B | Y | X | PROTOID | "Server"

[/code]

The client verifies that `AUTH == H(auth_input, t_mac)`.

Both parties check that none of the `EXP()` operations produced the point at infinity. [NOTE: This is an adequate replacement for checking `Y` for group membership, if the group is curve25519.]

Both parties now have a shared value for `KEY_SEED`. They expand this into the keys needed for the Tor relay protocol, using the KDF described in “KDF-RFC5869” and the tag `m_expand`.

### The “ntor-v3” handshake

This handshake extends the ntor handshake to include support for extra data transmitted as part of the handshake. Both the client and the server can transmit extra data; in both cases, the extra data is encrypted, but only server data receives forward secrecy.

To advertise support for this handshake, servers advertise the “Relay=4” subprotocol. To select it, clients use the ‘ntor-v3’ HTYPE value in their CREATE2 cells.

In this handshake, we define:
[code]
    PROTOID = "ntor3-curve25519-sha3_256-1"
    t_msgkdf = PROTOID | ":kdf_phase1"
    t_msgmac = PROTOID | ":msg_mac"
    t_key_seed = PROTOID | ":key_seed"
    t_verify = PROTOID | ":verify"
    t_final = PROTOID | ":kdf_final"
    t_auth = PROTOID | ":auth_final"

    `ENCAP(s)` -- an encapsulation function.  We define this
    as `htonll(len(s)) | s`.  (Note that `len(ENCAP(s)) = len(s) + 8`).

    `PARTITION(s, n1, n2, n3, ...)` -- a function that partitions a
    bytestring `s` into chunks of length `n1`, `n2`, `n3`, and so
    on. Extra data is put into a final chunk.  If `s` is not long
    enough, the function fails.

    H(s, t) = SHA3_256(ENCAP(t) | s)
    MAC(k, msg, t) = SHA3_256(ENCAP(t) | ENCAP(k) | s)
    KDF(s, t) = SHAKE_256(ENCAP(t) | s)
    ENC(k, m) = AES_256_CTR(k, m)

    EXP(pk,sk), KEYGEN: defined as in curve25519

    DIGEST_LEN = MAC_LEN = MAC_KEY_LEN = ENC_KEY_LEN = PUB_KEY_LEN = 32

    ID_LEN = 32  (representing an ed25519 identity key)

    For any tag "t_foo":
       H_foo(s) = H(s, t_foo)
       MAC_foo(k, msg) = MAC(k, msg, t_foo)
       KDF_foo(s) = KDF(s, t_foo)

[/code]

Other notation is as in the ntor description above.

The client begins by knowing:
[code]
    B, ID -- The curve25519 onion key (KP_onion_tap)
              and Ed25519 ID (KP_relayid_ed)
              of the server that it wants to use.
    CM -- A message it wants to send as part of its handshake.
    VER -- An optional shared verification string:

[/code]

The client computes:
[code]
    x,X = KEYGEN()
    Bx = EXP(B,x)
    secret_input_phase1 = Bx | ID | X | B | PROTOID | ENCAP(VER)
    phase1_keys = KDF_msgkdf(secret_input_phase1)
    (ENC_K1, MAC_K1) = PARTITION(phase1_keys, ENC_KEY_LEN, MAC_KEY_LEN)
    encrypted_msg = ENC(ENC_K1, CM)
    msg_mac = MAC_msgmac(MAC_K1, ID | B | X | encrypted_msg)

[/code]

The client then sends, as its Create handshake:

Field| Value| Size
---|---|---
`NODEID`| `ID`| `ID_LEN` bytes
`KEYID`| `B`| `PUB_KEY_LEN` bytes
`CLIENT_PK`| `X`| `PUB_KEY_LEN` bytes
`MSG`| `encrypted_msg`| `len(CM)` bytes
`MAC`| `msg_mac`| `MAC_LEN` bytes

The client remembers `x`, `X`, `B`, `ID`, `Bx`, and `msg_mac`.

When the server receives this handshake, it checks whether `NODEID` is as expected, and looks up the `(b,B)` keypair corresponding to `KEYID`. If the keypair is missing or the `NODEID` is wrong, the handshake fails.

Now the relay uses `X=CLIENT_PK` to compute:
[code]
    Xb = EXP(X,b)
    secret_input_phase1 = Xb | ID | X | B | PROTOID | ENCAP(VER)
    phase1_keys = KDF_msgkdf(secret_input_phase1)
    (ENC_K1, MAC_K1) = PARTITION(phase1_keys, ENC_KEY_LEN, MAC_KEY_LEN)

    expected_mac = MAC_msgmac(MAC_K1, ID | B | X | MSG)

[/code]

If `expected_mac` is not `MAC`, the handshake fails. Otherwise the relay computes `CM` as:
[code]
    CM = DEC(MSG, ENC_K1)

[/code]

The relay then checks whether `CM` is well-formed, and in response composes `SM`, the reply that it wants to send as part of the handshake. It then generates a new ephemeral keypair:
[code]
    y,Y = KEYGEN()

[/code]

and computes the rest of the handshake:
[code]
    Xy = EXP(X,y)
    secret_input = Xy | Xb | ID | B | X | Y | PROTOID | ENCAP(VER)
    ntor_key_seed = H_key_seed(secret_input)
    verify = H_verify(secret_input)

    RAW_KEYSTREAM = KDF_final(ntor_key_seed)
    (ENC_KEY, KEYSTREAM) = PARTITION(RAW_KEYSTREAM, ENC_KEY_LKEN, ...)

    encrypted_msg = ENC(ENC_KEY, SM)

    auth_input = verify | ID | B | Y | X | MAC | ENCAP(encrypted_msg) |
        PROTOID | "Server"
    AUTH = H_auth(auth_input)

[/code]

The relay then sends as its Created handshake:

Field| Value| Size
---|---|---
`Y`| `Y`| `PUB_KEY_LEN` bytes
`AUTH`| `AUTH`| `DIGEST_LEN` bytes
`MSG`| `encrypted_msg`| `len(SM)` bytes, up to end of the message

Upon receiving this handshake, the client computes:
[code]
    Yx = EXP(Y, x)
    secret_input = Yx | Bx | ID | B | X | Y | PROTOID | ENCAP(VER)
    ntor_key_seed = H_key_seed(secret_input)
    verify = H_verify(secret_input)

    auth_input = verify | ID | B | Y | X | MAC | ENCAP(MSG) |
        PROTOID | "Server"
    AUTH_expected = H_auth(auth_input)

[/code]

If `AUTH_expected` is equal to `AUTH`, then the handshake has succeeded. The client can then calculate:
[code]
    RAW_KEYSTREAM = KDF_final(ntor_key_seed)
    (ENC_KEY, KEYSTREAM) = PARTITION(RAW_KEYSTREAM, ENC_KEY_LKEN, ...)

    SM = DEC(ENC_KEY, MSG)

[/code]

SM is the message from the relay, and the client uses KEYSTREAM to generate the shared secrets for the newly created circuit.

Now both parties share the same KEYSTREAM, and can use it to generate their circuit keys.

## CREATE_FAST/CREATED_FAST cells

When creating a one-hop circuit, the client has already established the relay’s identity and negotiated a secret key using TLS. Because of this, it is not necessary for the client to perform the public key operations to create a circuit. In this case, the client MAY send a CREATE_FAST cell instead of a CREATE/CREATE2 cell. The relay responds with a CREATED_FAST cell, and the circuit is created.

> In particular, CREATE_FAST is useful when establishing a one-hop circuit in order to download directory information, when the client may not know any onion keys (e.g `KP_onion_ntor`) for the directory.

A CREATE_FAST cell contains:

Field| Size
---|---
Key material (`X`)| `SHA1_LEN` bytes

A CREATED_FAST cell contains:

Field| Size
---|---
Key material (`Y`)| `SHA1_LEN` bytes
Derivative key data| `SHA1_LEN` bytes (See KDF-TOR)

The values of `X` and `Y` must be generated randomly.

Once both parties have `X` and `Y`, they derive their shared circuit keys and ‘derivative key data’ value via the KDF-TOR function.

Parties SHOULD NOT use CREATE_FAST except for creating one-hop circuits.

## Sending extensions in the circuit extension handshake

Some handshakes (currently ntor-v3 defined above, and hs-ntor as used for onion services) allow the client or the relay to send additional data as part of the handshake. This additional data must have the following format:

Field| Size
---|---
`N_EXTENSIONS`| one byte
`N_EXTENSIONS` times:|
\- `EXT_FIELD_TYPE`| one byte
\- `EXT_FIELD_LEN`| one byte
\- `EXT_FIELD`| `EXT_FIELD_LEN` bytes

(`EXT_FIELD_LEN` may be zero, in which case `EXT_FIELD` is absent.)

All parties MUST reject messages that are not well-formed per the rules above.

Parties MUST ignore extensions with `EXT_FIELD_TYPE` bodies they do not recognize.

Unless otherwise specified in the documentation for an extension type:

  * Each extension type SHOULD be sent only once in a message.
  * Parties MUST ignore any occurrence of an extension with a given type after the first such occurrence.
  * Extensions SHOULD be sent in numerically ascending order by type.

> (The above extension sorting and multiplicity rules are only defaults; they may be overridden in the description of individual extensions.)

An extension may be supported in CREATE2/CREATED2 messages, in INTRODUCE messages, or both.

Currently supported extensions are as follows:

Type| Sent by| Name| Create?| Introduce?
---|---|---|---|---
1| Client| `CC_FIELD_REQUEST`| Y| Y
2| Service| `CC_FIELD_RESPONSE`| Y| N
2| Client| `POW`| N| Y
3| Client| `SUBPROTO`| Y| Y

  * 1 – `CC_FIELD_REQUEST` [Client to server]

Contains an empty body. Signifies that the client wants to use the extended congestion control described in proposal 324.

  * 2 – `CC_FIELD_RESPONSE` [Server to client] 1

Indicates that the relay will use the congestion control of proposal 324, as requested by the client. Not used with INTRODUCE. One byte in length:

`sendme_inc [1 byte]`

(Note that the use of “2” here is a historical accident; in the future, we should always use same number for a request and its response.)

  * 2 – `POW` [Client to server] 1

INTRODUCE only; used to provide proof of work for an onion service.

(Note that the overloading of `2` here is considered a historical accident.)

  * 3 – Subprotocol Request [Client to Server]

Tells the endpoint what subprotocol capabilities to use on the circuit.

### Extension handshake: Subprotocol request

This handshake extension is supported by any relay or onion service advertising support for the subprotocol capability `RELAY_NEGOTIATE_SUBPROTO` (“Relay=5”).

A client includes this extension to indicate one or more subprotocol capabilities which the relay or onion service must support and enable. If the responder does not support all of the listed capabilities, or if it does not enable them all, it MUST close the circuit.

The format of this extension is:

Field| Description| Len
---|---|---
Any number of times:| |
\- `protocol_id`| Identifier for the protocol| 1 byte
\- `cap_number`| Specific capability| 1 byte

Values for `protocol_id` are given in a table under subprotocol versioning. Specific capabilities are identified with a combination of a protocol and a capability number; for example, the `Relay=6` capability is represented as the two-byte sequence [02 06].

Within this extension, capabilities SHOULD be sorted in ascending order by `protocol_id`, then by `protocol_cap_number`. (For example, [01 01] comes before [01 02], which comes before [02 01].)

Not every subprotocol capability is supported with this extension: only a limited list is supported. That list of supported capabilities is:

Name| Value| Encoding
---|---|---
`RELAY_CRYPTO_CGO`| “Relay=6”| [02 06]

A client MUST NOT list any capability in this extension unless all of the following apply:

  * The capability is listed in the table above.
  * The target supports RELAY_NEGOTIATE_SUBPROTO (“Relay=5”).
  * The target supports the capability in question.

To determine whether a target relay supports a given capability, the client looks at the relay’s supported protocols. If the target relay is not listed in the consensus, the client SHOULD use the required-relay-protocols list from the latest consensus.

To determine whether an onion service supports a given capability, the client should look in the “proto” item in its descriptor.

> In the future, we plan to add other new subprotocol capabilities to the list above.
>
> It is appropriate to do so for capabilities where all of the following properties hold:
>
>   * The client needs to select whether the capability is enabled or not at circuit creation time.
>   * The server doesn’t need the ability to refuse to support the capability while still letting the circuit open.
>   * The client and server don’t need to negotitate any parameters related to the capability (this would require a separate extension).
>

> There is never an implicit automatic relationship between capabilities listed in this extension: If capability X requires capability Y, listing capability X does not “count as” listing capability Y unless documented otherwise.

  1. Note that the usage of “2” above is a historical accident. In the future, we should always use the same `EXT_FIELD_TYPE` number for a client’s response and the corresponding server reply (if any). ↩ ↩2

## Creating circuits

When creating a circuit through the network, the circuit creator (client) performs the following steps:

  1. Choose an onion router as an end node (R_N):

     * N MAY be 1 for non-anonymous directory mirror, introduction point, or service rendezvous connections.
     * N SHOULD be 3 or more for anonymous connections. Some end nodes accept streams (see “Opening streams”), others are introduction or rendezvous points (see the Rendezvous Spec).
  2. Choose a chain of (N-1) onion routers (R_1…R_N-1) to constitute the path, such that no router appears in the path twice.

  3. If not already connected to the first router in the chain, open a new connection to that router.

  4. Choose a circID not already in use on the connection with the first router in the chain; send a CREATE/CREATE2 cell along the connection, to be received by the first onion router.

  5. Wait until a CREATED/CREATED2 cell is received; finish the handshake and extract the forward key Kf_1 and the backward key Kb_1.

  6. For each subsequent onion router R (R_2 through R_N), extend the circuit to R.

To extend the circuit by a single onion router R_M, the client performs these steps:

  1. Create an onion skin, encrypted to R_M’s public onion key.

  2. Send the onion skin in a relay EXTEND/EXTEND2 message along the circuit (see “EXTEND and EXTENDED messages” and “Routing relay cells”).

  3. When a relay EXTENDED/EXTENDED2 message is received, verify the handshake, and calculate the shared keys. The circuit is now extended.

When an onion router receives an EXTEND relay message, it sends a CREATE cell to the next onion router, with the enclosed onion skin as its body.

When an onion router receives an EXTEND2 relay message, it sends a CREATE2 cell to the next onion router, with the enclosed HLEN, HTYPE, and HDATA as its body. The initiating onion router chooses some circID not yet used on the connection between the two onion routers. (But see section “Choosing circuit IDs in create cells”)

As special cases, if the EXTEND/EXTEND2 message includes a legacy identity, or identity fingerprint of all zeroes, or asks to extend back to the relay that sent the extend cell, the circuit will fail and be torn down.

Ed25519 identity keys are not required in EXTEND2 messages, so all zero keys SHOULD be accepted. If the extending relay knows the ed25519 key from the consensus, it SHOULD also check that key. (See EXTEND and EXTENDED message)

If an EXTEND2 message contains the ed25519 key of the relay that sent the EXTEND2 message, the circuit will fail and be torn down.

When an onion router receives a CREATE/CREATE2 cell, if it already has a circuit on the given connection with the given circID, it drops the cell. Otherwise, after receiving the CREATE/CREATE2 cell, it completes the specified handshake, and replies with a CREATED/CREATED2 cell.

Upon receiving a CREATED/CREATED2 cell, an onion router packs its body into an EXTENDED/EXTENDED2 relay message, and sends that message up the circuit. Upon receiving the EXTENDED/EXTENDED2 relay message, the client can retrieve the handshake material.

(As an optimization, relay implementations may delay processing onions until a break in traffic allows time to do so without harming network latency too greatly.)

## Canonical connections

It is possible for an attacker to launch a man-in-the-middle attack against a connection by telling relay Alice to extend to relay Bob at some address X controlled by the attacker. The attacker cannot read the encrypted traffic, but the attacker is now in a position to count all bytes sent between Alice and Bob (assuming Alice was not already connected to Bob.)

To prevent this, when a relay gets an extend request, it SHOULD use an existing relay connection if the ID matches, and ANY of the following conditions hold:

  * The IP matches the requested IP.
  * The relay knows that the IP of the connection it’s using is canonical because it was listed in the NETINFO cell.
  * The IP matches the relay address in the consensus.

## Flow control

## Link throttling

Each client or relay should do appropriate bandwidth throttling to keep its user happy.

Communicants rely on TCP’s default flow control to push back when they stop reading.

The mainline Tor implementation uses token buckets (one for reads, one for writes) for the rate limiting.

Since 0.2.0.x, Tor has let the user specify an additional pair of token buckets for “relayed” traffic, so people can deploy a Tor relay with strict rate limiting, but also use the same Tor as a client. To avoid partitioning concerns we combine both classes of traffic over a given relay connection, and keep track of the last time we read or wrote a high-priority (non-relayed) cell. If it’s been less than N seconds (currently N=30), we give the whole connection high priority, else we give the whole connection low priority. We also give low priority to reads and writes for connections that are serving directory information. See proposal 111 for details.

## Link padding

Link padding can be created by sending PADDING or VPADDING cells along the connection; relay messages of type “DROP” can be used for long-range padding. The bodies of PADDING cells, VPADDING cells, or DROP message are filled with padding bytes. See Cell Packet format.

If the link protocol is version 5 or higher, link level padding is enabled as per padding-spec.txt. On these connections, clients may negotiate the use of padding with a PADDING_NEGOTIATE command whose format is as follows:
[code]
             Version           [1 byte]
             Command           [1 byte]
             ito_low_ms        [2 bytes]
             ito_high_ms       [2 bytes]

[/code]

Currently, only version 0 of this cell is defined. In it, the command field is either 1 (stop padding) or 2 (start padding). For the start padding command, a pair of timeout values specifying a low and a high range bounds for randomized padding timeouts may be specified as unsigned integer values in milliseconds. The ito_low_ms field should not be lower than the current consensus parameter value for nf_ito_low (default: 1500). The ito_high_ms field should not be lower than ito_low_ms. (If any party receives an out-of-range value, they clamp it so that it is in-range.)

For the stop padding command, the timeout fields should be sent as zero (to avoid client distinguishability) and ignored by the recipient.

For more details on padding behavior, see padding-spec.txt.

## Circuit-level flow control

To control a circuit’s bandwidth usage, each relay keeps track of two ‘windows’, consisting of how many DATA-bearing relay cells it is allowed to originate or willing to consume.

(For the purposes of flow control, we call a relay cell “DATA-bearing” if it holds a DATA relay message. Note that this design does _not_ limit relay cells that don’t contain a DATA message; this limitation may be addressed in the future.)

These two windows are respectively named: the package window (packaged for transmission) and the deliver window (delivered for local streams).

Because of our leaky-pipe topology, every relay on the circuit has a pair of windows, and the client has a pair of windows for every relay on the circuit. These windows apply only to _originated_ and _consumed_ cells. They do not, however, apply to _relayed_ cells, and a relay that is never used for streams will never decrement its windows or cause the client to decrement a window.

Each ‘window’ value is initially set based on the consensus parameter ‘circwindow’ in the directory (see dir-spec.txt), or to 1000 DATA-bearing relay cells if no ‘circwindow’ value is given. In each direction, cells that are not RELAY_DATA cells do not affect the window.

A relay or client (depending on the stream direction) sends a RELAY_SENDME message to indicate that it is willing to receive more DATA-bearing cells when its deliver window goes down below a full increment (100). For example, if the window started at 1000, it should send a RELAY_SENDME when it reaches 900.

When a relay or client receives a RELAY_SENDME, it increments its package window by a value of 100 (circuit window increment) and proceeds to sending the remaining DATA-bearing cells.

If a package window reaches 0, the relay or client stops reading from TCP connections for all streams on the corresponding circuit, and sends no more DATA-bearing cells until receiving a RELAY_SENDME message.

If a deliver window goes below 0, the circuit should be torn down.

Starting with tor-0.4.1.1-alpha, authenticated SENDMEs are supported (version 1, see below). This means that both the relay and client need to remember the rolling digest of the relay cell that precedes (triggers) a RELAY_SENDME. This can be known if the package window gets to a multiple of the circuit window increment (100).

When the RELAY_SENDME version 1 arrives, it will contain a digest that MUST match the one remembered. This represents a proof that the end point of the circuit saw the sent relay cells. On failure to match, the circuit should be torn down.

To ensure unpredictability, random bytes should be added to at least one RELAY_DATA cell within one increment window. In other word, at every 100 data-bearing cells (increment), random bytes should be introduced in at least one cell.

### SENDME Message Format

A circuit-level RELAY_SENDME message always has its StreamID=0.

A relay or client must obey these two consensus parameters in order to know which version to emit and accept.
[code]
          'sendme_emit_min_version': Minimum version to emit.
          'sendme_accept_min_version': Minimum version to accept.

[/code]

If a RELAY_SENDME version is received that is below the minimum accepted version, the circuit should be closed.

The body of a RELAY_SENDME message contains the following:

Field| Size in bytes
---|---
`VERSION`| 1
`DATA_LEN`| 2
`DATA`| `DATA_LEN`

The VERSION tells us what is expected in the DATA section of length DATA_LEN and how to handle it. The recognized values are:

  * 0x00: The rest of the message should be ignored.

  * 0x01: Authenticated SENDME. The DATA section MUST contain:

DIGEST [20 bytes]

If the DATA_LEN value is less than 20 bytes, the message should be dropped and the circuit closed. If the value is more than 20 bytes, then the first 20 bytes should be read to get the DIGEST value.

The DIGEST is the rolling digest value from the DATA-bearing relay cell that immediately preceded (triggered) this RELAY_SENDME. This value is matched on the other side from the previous cell sent that the relay/client must remember.

(Note that if the digest in use has an output length greater than 20 bytes—as is the case for the hop of an onion service rendezvous circuit created by the hs_ntor handshake—we truncate the digest to 20 bytes here.)

If the VERSION is unrecognized or below the minimum accepted version (taken from the consensus), the circuit should be torn down. As an exception, relays accept version 0 SENDME cells on circuits that were made with CREATE_FAST, since such circuits have no way to negotiate parameters and also so obsolete Tors are able to fetch a consensus to discover that they are obsolete.

## Stream-level flow control

Edge nodes use RELAY_SENDME messages to implement end-to-end flow control for individual connections across circuits. Similarly to circuit-level flow control, edge nodes begin with a window of DATA-bearing cells (500) per stream, and increment the window by a fixed value (50) upon receiving a RELAY_SENDME message. Edge nodes initiate RELAY_SENDME messages when both a) the window is <= 450, and b) there are less than ten cells’ worth of data remaining to be flushed at that edge.

Stream-level RELAY_SENDME messages are distinguished by having nonzero StreamID. They are still empty; the body still SHOULD be ignored.

## Negotiating and initializing channels

Here we describe the primary TLS behavior used by Tor relays and clients to create a new channel. There are older versions of these handshakes, which we describe in another section.

In brief:

  * The initiator starts the handshake by opening a TLS connection.
  * Both parties send a VERSIONS to negotiate the link protocol version to use.
  * The responder sends a CERTS cell to give the initiator the certificates it needs to learn the responder’s identity, an AUTH_CHALLENGE cell that the initiator must include as part of its answer if it chooses to authenticate, and a NETINFO cell to establish clock skew and IP addresses.
  * The initiator checks whether the CERTS cell is correct, and decides whether to authenticate.
  * If the initiator is not authenticating itself, it sends a NETINFO cell.
  * If the initiator is authenticating itself, it sends a CERTS cell, an AUTHENTICATE cell, a NETINFO cell.

#### Padding

When this handshake is in use, the first cell must be a VERSIONS. After that, the link protocol version is known and then any number in any order of VPADDING cells are allowed but no other cell type is allowed to intervene.

### Negotiation Message Flow

As channel Initiator, public relays MUST prove their identities when they initiate a channel, whereas clients and bridges MUST NOT do so.

The `NETINFO` cell marks the end of the handshake. After sending it, an endpoint will not send any further handshake cells. Therefore, the responder can use it to determine whether the initiator intends to authenticate.

## The TLS handshake

The initiator must send a ciphersuite list containing at least one ciphersuite other than those listed in the obsolete v1 handshake.

> This is trivially achieved by using any modern TLS implementation, and most implementations will not need to worry about it.
>
> This requirement distinguishes the current protocol (sometimes called the “in-protocol” or “v3” handshake) from the obsolete v1 protocol.

### TLS security considerations

(Standard TLS security guarantees apply; this is not a comprehensive guide.)

Implementations SHOULD NOT allow TLS session resumption – it can exacerbate some attacks (e.g. the “Triple Handshake” attack from Feb 2013), and it plays havoc with forward secrecy guarantees.

Implementations SHOULD NOT allow TLS compression – although we don’t know a way to apply a CRIME-style attack to current Tor directly, it’s a waste of resources.

To ensure compatibility:

  * All implementations SHOULD support TLS 1.3.
  * Relay implementations SHOULD support TLS 1.2 and TLS 1.3.
  * With TLS 1.2, all implementations SHOULD support as many of the following ciphersuites and groups as possible:
    * `ECDHE_RSA_WITH_AES_128_GCM_SHA256`
    * `ECDHE_RSA_WITH_CHACHA20_POLY1305`
    * NIST group P-256
    * Curve25519
  * With TLS 1.3, all implementations SHOULD support as many of the following ciphers and handshakes as possible:
    * `AES_128_GCM_SHA256`
    * `CHACHA20_POLY1305_SHA256`
    * NIST group P-256
    * X25519

In general, relay implementations SHOULD support as many secure TLS ciphersuites, ciphers, and handshakes as possible.

Relay implementations SHOULD NOT support insecure or deprecated ciphersuites and options.

## Negotiating versions with VERSIONS cells

There are multiple instances of the Tor channel protocol.

Once the TLS handshake is complete, both parties send a variable-length VERSIONS cell to negotiate which one they will use.

The body in a VERSIONS cell is a series of big-endian two-byte integers. Both parties MUST select as the link protocol version the highest number contained both in the VERSIONS cell they sent and in the VERSIONS cell they received. If they have no such version in common, they cannot communicate and MUST close the connection. Either party MUST close the connection if the VERSIONS cell is not well-formed (for example, if the body contains an odd number of bytes).

Any VERSIONS cells sent after the first VERSIONS cell MUST be ignored. (To be interpreted correctly, later VERSIONS cells MUST have a CIRCID_LEN matching the version negotiated with the first VERSIONS cell.)

> (The obsolete v1 channel protocol does note VERSIONS cells. Implementations MUST NOT list version 1 in their VERSIONS cells. The obsolete v2 channel protocol can only be used after renegotiation; implementations MUST NOT list version 2 in their VERSIONS cells unless they have renegotiated the TLS session.)

The currently specified Link protocols are:

Version| Description
---|---
1| (Obsolete) The “certs up front” handshake.
2| (Obsolete) Uses the renegotiation-based handshake. Introduces variable-length cells.
3| (Obsolete) Begins use of the current (“in-protocol”) handshake.
4| Increases circuit ID width to 4 bytes.
5| Adds support for link padding and negotiation.

## CERTS cells

The CERTS cell describes the keys that a Tor instance is claiming to have, and provides certificates to authenticate that those keys belong, ultimately, to one or more identity keys.

CERTS is a variable-length cell. Its body format is:

Field| Size| Description
---|---|---
N| 1| Number of certificates in cell
N times:| |
\- CertType| 1| Type of certificate
\- CertLen| 2| Length of “Certificate” field
\- Certificate| CertLen| Encoded certificate

Any extra octets at the end of a CERTS cell MUST be ignored.

The CertType field determines the format of the certificate, and the roles of its keys within the Tor protocol. Recognized values are defined in “Certificate types (CERT_TYPE field)”.

A CERTS cell MUST have no more than one certificate of any CertType.

### Authenticating the responder from its CERTS

The responder’s CERTS cell is as follows:

  * The CERTS cell contains exactly one CertType 4 Ed25519 `IDENTITY_V_SIGNING_CERT`.
    * This cert must be self-signed; the signing key must be included in a “signed-with-ed25519-key” extension extension. This signing key is `KP_relayid_ed`. The subject key is `KP_relaysign_ed`.
  * The CERTS cell contains exactly one CertType 5 Ed25519 `SIGNING_V_TLS_CERT` certificate.
    * This cert must be signed with `KP_relaysign_ed`. Its subject must be the SHA-256 digest of the TLS certificate that was presented during the TLS handshake.
  * All of the certs above must be correctly signed, and not expired.

The initiator must check all of the above. If this is successful the initiator knows that the responder has the identity `KP_relayid_ed`.

> The responder’s CERTS cell is meant to prove that the responder posseses one or more relay identities. It does this by containing certificate chains from each relay identity key to the TLS certificate presented during the TLS handshake.

> The responder’s ownership of that TLS certificate was already proven during the TLS hadnshake itself.

### Validating an initiator’s CERTS

When required by other parts of this specification; to prove its identity, the initiator must provide a CERTS cell.

> Recall that not all initiators authenticate themselves; bridges and clients do not prove their identity.

The initiator’s CERTS cell must conform to the rules for the responder’s CERTS cell (see above, exchanging “initiator” and “responder”) except that:

**Instead** of containg a `SIGNING_V_TLS_CERT`,

  * The CERTS cell contains exactly one CertType 6 `SIGNING_V_LINK_AUTH` certificate.
    * This certificate must be signed with `KP_relaysign_ed`. (Its subject key is deemed to be `KP_link_ed`.)
  * All of the certs above must be correctly signed, and not expired.

The responder must check all of the CERTS cell’s properties (as stated here, and in the previous section). If this is successful **and** the initiator later sends a valid AUTHENTICATE cell, then the initiator has ownership of the presented `KP_relayid_ed`.

>
> Therefore, instead, the initiator’s CERTS cell proves a chain from the initiator’s relay identities to a “link authentication” key. This key is later used to sign an “authentication challenge”, and bind it to the channel.

### Authenticating an RSA identity (#auth-RSA)

After processing a CERTS cell to find the other party’s `KP_relayid_ed` Ed25519 identity key, a Tor instance MAY _additionally_ check the CERTS cell to find the other party’s `KP_relayid_rsa` legacy RSA identity key.

A party with a given `KP_relayid_ed` identity key also has a given `KP_relayid_rsa` legacy identity key when all of the following are true. (A party MUST NOT conclude that an RSA identity key is associated with a channel without checking these properties.)

  * The CERTS cell contains exactly one CertType 2 `RSA_ID_X509` certificate.
    * This must be a self-signed certificate containing a 1024-bit RSA key; that key’s exponent must be 65537. That key is `KP_relayid_rsa`.
  * The CERTS cell contains exactly one CertType 7 `RSA_ID_V_IDENTITY` certificate.
    * This certificate must be signed with `KP_relayid_rsa`.
    * This certificate’s subject key must be the same as an already-authenticated `KP_relayid_ed`.
  * All of the certs above must be correctly signed, not expired, and not before their `validAfter` dates.

If the above tests all pass, then any relay which can prove it has the the identity `KP_relayid_ed` also has the legacy identity `KP_relayid_rsa`.

## AUTH_CHALLENGE cells

An AUTH_CHALLENGE cell is a variable-length cell with the following fields:

Field| Size
---|---
Challenge| 32 octets
N_Methods| 2 octets
Methods| 2 * N_Methods octets

It is sent from the responder to the initiator. Initiators MUST ignore unexpected bytes at the end of the cell. Responders MUST generate every challenge independently.

The Challenge field is a randomly generated binary string that the initiator must sign (a hash of) as part of their AUTHENTICATE cell.

The Methods are a list of authentication methods that the responder will accept. These methods are defined:

Type| Method
---|---
`[00 01]`| RSA-SHA256-TLSSecret (Obsolete)
`[00 02]`| (Historical, never implemented)
`[00 03]`| Ed25519-SHA256-RFC5705

## AUTHENTICATE cells

To authenticate, an initiator MUST it respond to the AUTH_CHALLENGE cell with a CERTS cell and an AUTHENTICATE cell.

> Recall that initiators are not always required to authenticate.
>
> (As discussed above, the initiator’s CERTS cell differs slightly from what a responder would send.)

An AUTHENTICATE cell contains the following:

Field| Size
---|---
AuthType| 2
AuthLen| 2
Authentication| AuthLen

Responders MUST ignore extra bytes at the end of an AUTHENTICATE cell.

The `AuthType` value corresponds to one of the authentication methods. The initiator MUST NOT send an AUTHENTICATE cell whose AuthType was not contained in the responder’s AUTH_CHALLENGE.

An initiator MUST NOT send an AUTHENTICATE cell before it has verified the certificates presented in the responder’s CERTS cell, and authenticated the responder.

### Link authentication type 3: Ed25519-SHA256-RFC5705

If AuthType is `[00 03]`, meaning “Ed25519-SHA256-RFC5705”, the Authentication field of the AUTHENTICATE cell is as follows

Modified values and new fields below are marked with asterisks.

Field| Size| Summary
---|---|---
`TYPE`| 8| The nonterminated string `AUTH0003`
`CID`| 32| `SHA_256(DER(KP_relayid_rsa))` for initiator
`SID`| 32| `SHA_256(DER(KP_relayid_rsa))` for responder
`CID_ED`| 32| `KP_relayid_ed` for initiator
`SID_ED`| 32| `KP_relayid_ed` for responder
`SLOG`| 32| Responder log digest, SHA-256
`CLOG`| 32| Initiator log digest, SHA-256
`SCERT`| 32| SHA256 of responder’s TLS certificate
`TLSSECRETS`| 32| RFC5705 information
`RAND`| 24| Random bytes
`SIG`| 64| Ed25519 signature

  * The `TYPE` string distinguishes this authentication document from others. It must be the nonterminated 8-byte string `AUTH0003`.
  * For `CID` and `SID`, the SHA-256 digest of an RSA key is computed over the DER encoding of the key.
  * The `SLOG` field is computed as the SHA-256 digest of all bytes received within the TLS channel up to and including the AUTH_CHALLENGE cell.
    * This includes the VERSIONS cell, the CERTS cell, the AUTH_CHALLENGE cell, and any padding cells.
  * The `CLOG` field is computed as the SHA-256 digest of all bytes sent within the TLS channel up to but not including the AUTHENTICATE cell.
    * This includes the VERSIONS cell, the CERTS cell, and any padding cells.
  * The `SCERT` field holds the SHA-256 digest of the X.509 certificate presented by the responder as part of the TLS negotiation.
  * The `TLSSECRETS` field is computed as the output of a Keying Material Exporter function on the TLS section.
    * The parameters for this exporter are:
      * Label string: “EXPORTER FOR TOR TLS CLIENT BINDING AUTH0003”
      * Context value: The `CID` value above.1
      * Length: 32.
    * For keying material exporters on TLS 1.3, see RFC 8446 Section 7.5.
    * For keying material exporters on older TLS versions, see RFC5705.
  * The `RAND` field is a uniform squence of Random bytes.
  * The `SIG` field is an Ed25519 signature of all earlier members in the Authentication (from `TYPE` through `RAND`) using `KS_link_ed`.

To check an AUTHENTICATE cell, a responder checks that all fields from TYPE through TLSSECRETS contain their unique correct values as described above, and then verifies the signature. The responder MUST ignore any extra bytes in the signed data after the RAND field.

## NETINFO cells

To finish the handshake, each party sends the other a NETINFO cell.

A NETINFO cell’s body is:

Field| Description| Size
---|---|---
TIME| Timestamp| 4 bytes
OTHERADDR:| Other party’s address|
\- ATYPE| Address type| 1 byte
\- ALEN| Address length| 1 byte
\- AVAL| Address value| ALEN bytes
NMYADDR| Number of this party’s addresses| 1 byte
NMYADDR times:| |
\- ATYPE| Address type| 1 byte
\- ALEN| Address length| 1 byte
\- AVAL| Address value| ALEN bytes

Recognized address types (ATYPE) are:

ATYPE| Description
---|---
0x04| IPv4
0x06| IPv6

Implementations SHOULD ignore addresses with unrecognized types.

ALEN MUST be 4 when ATYPE is 0x04 (IPv4) and 16 when ATYPE is 0x06 (IPv6). If the ALEN value is wrong for the given ATYPE value, then the provided address should be ignored.

The `OTHERADDR` field SHOULD be set to the actual IP address observed for the other party.

> (This is typically the address passed to `connect()` when acting as the channel initiator, or the address received from `accept()` when acting as the channel responder.)

In the `ATYPE`/`ALEN`/`AVAL` fields, relays SHOULD send the addresses that they have advertised in their router descriptors. Bridges and clients SHOULD send none of their own addresses.

For the `TIME` field, relays send a (big-endian) integer holding the number of seconds since the Unix epoch. Clients SHOULD send `[00 00 00 00]` as their timestamp, to avoid fingerprinting.

> See proposal 338 for a proposal to extend the timestamp to 8 bytes.

Implementations MUST ignore unexpected bytes at the end of the NETINFO cell.

### Using information from NETINFO cells

Implementations MAY use the timestamp value to help decide if their clocks are skewed.

Initiators MAY use “other relay’s address” field to help learn which address their connections may be originating from, if they do not know it; and to learn whether the peer will treat the current connection as canonical. (See Canonical connections)

Implementations SHOULD NOT trust these values unconditionally, especially when they come from non-authorities, since the other party can lie about the time or the IP addresses it sees.

Initiators SHOULD use “this relay’s address” to make sure that they have connected to another relay at its canonical address.

  1. Note: we originally intended that the context value for the TLS exporter would be the initiator’s `KP_relayid_ed`. We implemented it incorrectly, however. Fortunately, we do not believe that the current behavior (using `CID` instead) affects the security of the protocol. ↩

## Obsolete channel negotiation handshakes

# Opening streams and transmitting data

## Opening a new stream: The begin/connected handshake

To open a new anonymized TCP connection, the client chooses an open circuit to an exit that may be able to connect to the destination address, selects an arbitrary StreamID not yet used on that circuit, and constructs a RELAY_BEGIN message with a body encoding the address and port of the destination host. The body format is:
[code]
             ADDRPORT [nul-terminated string]
             FLAGS    [4 bytes, optional]

       ADDRPORT is made of ADDRESS | ':' | PORT | [00]

[/code]

where ADDRESS can be a DNS hostname, or an IPv4 address in dotted-quad format, or an IPv6 address surrounded by square brackets; and where PORT is a decimal integer between 1 and 65535, inclusive.

The ADDRPORT string SHOULD be sent in lower case, to avoid fingerprinting. Implementations MUST accept strings in any case.

The FLAGS value has one or more of the following bits set, where “bit 1” is the LSB of the 32-bit value, and “bit 32” is the MSB. (Remember that all integers in Tor are big-endian, so the MSB of a 4-byte value is the MSB of the first byte, and the LSB of a 4-byte value is the LSB of its last byte.)

If FLAGS is absent, its value is 0. Whenever 0 would be sent for FLAGS, FLAGS is omitted from the message body.
[code]
         bit   meaning
          1 -- IPv6 okay.  We support learning about IPv6 addresses and
               connecting to IPv6 addresses.
          2 -- IPv4 not okay.  We don't want to learn about IPv4 addresses
               or connect to them.
          3 -- IPv6 preferred.  If there are both IPv4 and IPv6 addresses,
               we want to connect to the IPv6 one.  (By default, we connect
               to the IPv4 address.)
          4..32 -- Reserved. Current clients MUST NOT set these. Servers
               MUST ignore them.

[/code]

Upon receiving this message, the exit node first checks whether it happens to be the first node in the circuit (i.e. someone is trying to create a one-hop circuit). It does so by inspecting the accompanying channel to determine whether the channel initiator has authenticated itself, and whether its fingerprint is part of the current consensus. (See “Negotiating and initializing channels”)

Any attempts to create a one-hop circuit using a RELAY_BEGIN message SHOULD be declined by sending an appropriate DESTROY cell with a protocol violation as its reason.

Afterwards, the exit node resolves the address as necessary, and opens a new TCP connection to the target port. If the address cannot be resolved, or a connection can’t be established, the exit nodes replies with a RELAY_END message. (See “Closing streams”) Otherwise, the exit node replies with a RELAY_CONNECTED message, whose body is one of the following formats:
[code]
           The IPv4 address to which the connection was made [4 octets]
           A number of seconds (TTL) for which the address may be cached [4 octets]

        or

           Four zero-valued octets [4 octets]
           An address type (6)     [1 octet]
           The IPv6 address to which the connection was made [16 octets]
           A number of seconds (TTL) for which the address may be cached [4 octets]

[/code]

Implementations MUST accept either of these formats, and MUST also accept an empty RELAY_CONNECTED message body.

Implementations MAY ignore the address value, and MAY choose not to cache it. If an implementation chooses to cache the address, it SHOULD NOT reuse that address with any other circuit.

> The reason not to cache an address is that the exit might have lied about the actual address of the host, or might have given us a unique address to identify us in the future.

[Tor exit nodes before 0.1.2.0 set the TTL field to a fixed value. Later versions set the TTL to the last value seen from a DNS server, and expire their own cached entries after a fixed interval. This prevents certain attacks.]

## Transmitting data

Once a connection has been established, the client and exit node package stream data in RELAY_DATA message, and upon receiving such messages, echo their contents to the corresponding TCP stream.

The client MAY send RELAY_DATA messages immediately after sending the RELAY_BEGIN message (and before receiving either a RELAY_CONNECTED or RELAY_END message).

> In some contexts, messages sent before receiving a RELAY_CONNECTED message are called “optimistic data”.

When an exit receives RELAY_DATA messages it receives on streams which have seen RELAY_BEGIN but have not yet been replied to with a RELAY_CONNECTED or RELAY_END, those messages are queued. If the stream creation succeeds with a RELAY_CONNECTED, the queue is processed immediately afterwards; if the stream creation fails with a RELAY_END, the contents of the queue are deleted.

RELAY_DATA messages sent to closed streams are dropped.

RELAY_DATA messages sent to unrecognized streams are an error, and cause the circuit to close.

Relay RELAY_DROP messages are long-range dummies; upon receiving such a message, the relay or client must drop it.

## Opening a directory stream

If a Tor relay is a directory server, it should respond to a RELAY_BEGIN_DIR message as if it had received a BEGIN message requesting a connection to its directory port. RELAY_BEGIN_DIR messages ignore exit policy, since the stream is local to the Tor process.

Directory servers may be:

  * authoritative directories (RELAY_BEGIN_DIR, usually non-anonymous),
  * bridge authoritative directories (RELAY_BEGIN_DIR, anonymous),
  * directory mirrors (RELAY_BEGIN_DIR, usually non-anonymous),
  * onion service directories (RELAY_BEGIN_DIR, anonymous).

If the Tor relay is not running a directory service, it should respond with a REASON_NOTDIRECTORY RELAY_END message.

Clients MUST generate a empty body for RELAY_BEGIN_DIR message; relays MUST ignore the the body of a RELAY_BEGIN_DIR message.

In response to a RELAY_BEGIN_DIR message, relays respond either with a RELAY_CONNECTED message on success, or a RELAY_END message on failure. They MUST send a RELAY_CONNECTED message with an empty body; clients MUST ignore the body.

## Preliminaries

## Notation and encoding
[code]
       KP -- a public key for an asymmetric cipher.
       KS -- a private key for an asymmetric cipher.
       K  -- a key for a symmetric cipher.
       N  -- a "nonce", a random value, usually deterministically chosen
             from other inputs using hashing.

[/code]

## Security parameters

Tor uses a stream cipher, a public-key cipher, the Diffie-Hellman protocol, and a hash function.
[code]
       KEY_LEN -- the length of the stream cipher's key, in bytes.
       KP_ENC_LEN -- the length of a public-key encrypted message, in bytes.
       KP_PAD_LEN -- the number of bytes added in padding for public-key
         encryption, in bytes. (The largest number of bytes that can be encrypted
         in a single public-key operation is therefore KP_ENC_LEN-KP_PAD_LEN.)

       DH_LEN -- the number of bytes used to represent a member of the
         Diffie-Hellman group.
       DH_SEC_LEN -- the number of bytes used in a Diffie-Hellman private key (x).

[/code]

## Message lengths

Some message lengths are fixed in the Tor protocol. We give them here. Some of these message lengths depend on the version of the Tor link protocol in use: for these, the link protocol is denoted in this table with `v`.

Name| Length in bytes| Meaning
---|---|---
`CELL_BODY_LEN`| 509| The body length for a fixed-length cell.
`CIRCID_LEN(v)`, `v` < 4| 2| The length of a circuit ID
`CIRCID_LEN(v)`, `v` ≥ 4| 4|
`CELL_LEN(v)`, `v` < 4| 512| The length of a fixed-length cell.
`CELL_LEN(v)`, `v` ≥ 4| 514|

Note that for all `v`, `CELL_LEN(v) = 1 + CIRCID_LEN(v) + CELL_BODY_LEN`.

> Formerly `CELL_BODY_LEN` was called sometimes called `PAYLOAD_LEN`.

## Ciphers

These are the ciphers we use _unless otherwise specified_. Several of them are deprecated for new use.

For a stream cipher, unless otherwise specified, we use 128-bit AES in counter mode, with an IV of all 0 bytes. (We also require AES256.)

For a public-key cipher, unless otherwise specified, we use RSA with 1024-bit keys and a fixed exponent of 65537. We use OAEP-MGF1 padding, with SHA-1 as its digest function. We leave the optional “Label” parameter unset. (For OAEP padding, see ftp://ftp.rsasecurity.com/pub/pkcs/pkcs-1/pkcs-1v2-1.pdf)

We also use the Curve25519 group and the Ed25519 signature format in several places.

For Diffie-Hellman, unless otherwise specified, we use a generator (g) of 2. For the modulus (p), we use the 1024-bit safe prime from rfc2409 section 6.2 whose hex representation is:
[code]
         "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E08"
         "8A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B"
         "302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9"
         "A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE6"
         "49286651ECE65381FFFFFFFFFFFFFFFF"

[/code]

As an optimization, implementations SHOULD choose DH private keys (x) of 320 bits. Implementations that do this MUST never use any DH key more than once. [May other implementations reuse their DH keys?? -RD] [Probably not. Conceivably, you could get away with changing DH keys once per second, but there are too many oddball attacks for me to be comfortable that this is safe. -NM]

KEY_LEN=16. DH_LEN=128; DH_SEC_LEN=40. KP_ENC_LEN=128; KP_PAD_LEN=42.

All "random" values MUST be generated with a cryptographically strong pseudorandom number generator seeded from a strong entropy source, unless otherwise noted. All "random" values MUST selected uniformly at random from the universe of possible values, unless otherwise noted.

## Cryptographic hash functions

Tor uses the cryptographic hash functions SHA-1, SHA-256, and SHA3-256.

> SHA-1 is vulnerable to various collision attacks, and should not be used anywhere new. Its existing applications are redundant with other hash functions, deprecated, or both.

We denote applications of these hash functions to some message M as:

  * `SHA1(M)`
  * `SHA256(M)`
  * `SHA3_256(M)`.

We define constants to represent the lengths in bytes of the digests that these functions output:
[code]
    SHA1_LEN = 20
    SHA256_LEN = 32
    SHA3_256_LEN = 32

[/code]

Note that although the above terminology is preferred, many of our older specifications have not yet been converted to use it. In some places, we also use `H(M)` to mean “the digest of M”, and `DIGEST_LEN` or `HASH_LEN` to refer to the length of that digest. Unless otherwise specified, `H(M)` is computed using SHA-1.

### Computing the digest of an RSA key

When `key` is an RSA public key, we use the notation `DER(key)` to denote the ASN.1 DER encoding of the key’s representation as a PKCS#1 RSAPublicKey object.

Some older text does not use yet this notation. When we refer to “the digest of an RSA public key”, unless otherwise specified, we mean a digest of `DER(key)`. The hash function should be specified explicitly.

## Relay cells

Within a circuit, the client and the end node use the contents of relay cells to tunnel end-to-end commands and TCP connections (“Streams”) across circuits. End-to-end commands can be initiated by either edge; streams are initiated by the client.

End nodes that accept streams may be:

  * exit relays (RELAY_BEGIN, anonymous),
  * directory servers (RELAY_BEGIN_DIR, anonymous or non-anonymous),
  * onion services (RELAY_BEGIN, anonymous via a rendezvous point).

The body of each unencrypted relay cell consists of an enveloped relay message, encoded as follows:

Field| Size
---|---
Relay command| 1 byte
‘Recognized’| 2 bytes
StreamID| 2 bytes
Digest| 4 bytes
Length| 2 bytes
Data| Length bytes
Padding| CELL_BODY_LEN - 11 - Length bytes

> TODO: When we implement prop340, we should clarify which parts of the above are about the relay cell, and which are the enveloped message.

The relay commands are:

Command| Identifier| Type| Description
---|---|---|---
| Core protocol| | |
1| BEGIN| **F**|  Open a stream
2| DATA| **F** /**B**|  Transmit data
3| END| **F** /**B**|  Close a stream
4| CONNECTED| **B**|  Stream has successfully opened
5| SENDME| **F** /**B** , **C?**|  Acknowledge traffic
6| EXTEND| **F** , **C**|  Extend a circuit with TAP (obsolete)
7| EXTENDED| **B** , **C**|  Finish extending a circuit with TAP (obsolete)
8| TRUNCATE| **F** , **C**|  Remove nodes from a circuit (unused)
9| TRUNCATED| **B** , **C**|  Report circuit truncation (unused)
10| DROP| **F** /**B** , **C**|  Long-range padding
11| RESOLVE| **F**|  Hostname lookup
12| RESOLVED| **B**|  Hostname lookup reply
13| BEGIN_DIR| **F**|  Open stream to directory cache
14| EXTEND2| **F** , **C**|  Extend a circuit
15| EXTENDED2| **B** , **C**|  Finish extending a circuit
16..18| Reserved| | For UDP; see prop339.
| Conflux| | |
19| CONFLUX_LINK| **F** , **C**|  Link circuits into a bundle
20| CONFLUX_LINKED| **B** , **C**|  Acknowledge link request
21| CONFLUX_LINKED_ACK| **F** , **C**|  Acknowledge CONFLUX_LINKED message (for timing)
22| CONFLUX_SWITCH| **F** /**B** , **C**|  Switch between circuits in a bundle
| Onion services| | |
32| ESTABLISH_INTRO| **F** , **C**|  Create introduction point
33| ESTABLISH_RENDEZVOUS| **F** , **C**|  Create rendezvous point
34| INTRODUCE1| **F** , **C**|  Introduction request (to intro point)
35| INTRODUCE2| **B** , **C**|  Introduction request (to service)
36| RENDEZVOUS1| **F** , **C**|  Rendezvous request (to rendezvous point)
37| RENDEZVOUS2| **B** , **C**|  Rendezvous request (to client)
38| INTRO_ESTABLISHED| **B** , **C**|  Acknowledge ESTABLISH_INTRO
39| RENDEZVOUS_ESTABLISHED| **B** , **C**|  Acknowledge ESTABLISH_RENDEZVOUS
40| INTRODUCE_ACK| **B** , **C**|  Acknowledge INTRODUCE1
| Circuit padding| | |
41| PADDING_NEGOTIATE| **F** , **C**|  Negotiate circuit padding
42| PADDING_NEGOTIATED| **B** , **C**|  Negotiate circuit padding
| Flow control| | |
43| XOFF| **F** /**B**|  Stream-level flow control
44| XON| **F** /**B**|  Stream-level flow control

  * **F** (Forward): Must only be sent by the originator of the circuit.
  * **B** (Backward): Must only be sent by other nodes in the circuit back towards the originator.
  * **F** /**B** (Forward or backward): May be sent in either direction.
  * **C** : (Control) must have a zero-valued stream ID. (Other commands must have a nonzero stream ID.)

The ‘recognized’ field is used as a simple indication that the cell is still encrypted. It is an optimization to avoid calculating expensive digests for every cell. When sending cells, the unencrypted ‘recognized’ MUST be set to zero.

When receiving and decrypting cells the ‘recognized’ will always be zero if we’re the endpoint that the cell is destined for. For cells that we should relay, the ‘recognized’ field will usually be nonzero, but will accidentally be zero with P=2^-16.

When handling a relay cell, if the ‘recognized’ in field in a decrypted relay cell is zero, the ‘digest’ field is computed as the first four bytes of the running digest of all the bytes that have been destined for this hop of the circuit or originated from this hop of the circuit, seeded from Df or Db respectively (obtained in Setting circuit keys), and including this relay cell’s entire body (taken with the digest field set to zero). Note that these digests _do_ include the padding bytes at the end of the cell, not only those up to “Len”. If the digest is correct, the cell is considered “recognized” for the purposes of decryption (see Routing relay cells).

(The digest does not include any bytes from relay cells that do not start or end at this hop of the circuit. That is, it does not include forwarded data. Therefore if ‘recognized’ is zero but the digest does not match, the running digest at that node should not be updated, and the cell should be forwarded on.)

All relay messages pertaining to the same tunneled stream have the same stream ID. StreamIDs are chosen arbitrarily by the client. No stream may have a StreamID of zero. Rather, relay messages that affect the entire circuit rather than a particular stream use a StreamID of zero – they are marked in the table above as “**C** ” (control“) style cells. (Sendme cells are marked as “sometimes control” because they can include a StreamID or not depending on their purpose – see [Flow control.)

The ‘Length’ field of a relay cell contains the number of bytes in the relay cell’s body which contain the body of the message. The remainder of the unencrypted relay cell’s body is padded with padding bytes. Implementations handle padding bytes of unencrypted relay cells as they do padding bytes for other cell types; see Cell Packet format.

The ‘Padding’ field is used to make relay cell contents unpredictable, to avoid certain attacks (see proposal 289 for rationale). Implementations SHOULD fill this field with four zero-valued bytes, followed by as many random bytes as will fit. (If there are fewer than 4 bytes for padding, then they should all be filled with zero.

Implementations MUST NOT rely on the contents of the ‘Padding’ field.

If the relay cell is recognized but the relay command is not understood, the cell must be dropped and ignored. Its contents still count with respect to the digests and flow control windows, though.

## Calculating the ‘Digest’ field

The ‘Digest’ field itself serves the purpose to check if a cell has been fully decrypted, that is, all onion layers have been removed. Having a single field, namely ‘Recognized’ is not sufficient, as outlined above.

In this section, we assume an incrementally updated hash function, where `hash_calculate(state)` computes the current digest, and `hash_update(state,M)` adjusts the hash function’s state by adding `M` to its input. For ordinary circuits, the hash function used here is SHA-1. For onion service circuits, the hash function is SHA3-256.

When ENCRYPTING a relay cell, an implementation does the following:
[code]
    # Encode the cell in binary (recognized and digest set to zero)
    tmp = cmd + [0, 0] + stream_id + [0, 0, 0, 0] + length + data + padding

    # Update the hash state with the encoded data
    hash_state = hash_update(hash_state, tmp)
    digest = hash_calculate(hash_state)

    # The encoded data is the same as above with the digest field not being
    # zero anymore
    encoded = cmd + [0, 0] + stream_id + digest[0..4] + length + data +
              padding

    # Now we can encrypt the cell by adding the onion layers ...

[/code]

When DECRYPTING a relay cell, an implementation does the following:
[code]
    decrypted = decrypt(cell)

    # Replace the digest field in decrypted by zeros
    tmp = decrypted[0..5] + [0, 0, 0, 0] + decrypted[9..]

    # Update the digest field with the decrypted data and its digest field
    # set to zero
    hash_state = hash_update(hash_state, tmp)
    digest = hash_calculate(hash_state)

    if digest[0..4] == decrypted[5..9]
      # The cell has been fully decrypted ...

[/code]

The caveat itself is that only the binary data with the digest bytes set to zero are being taken into account when calculating the running digest. The final plain-text cells (with the digest field set to its actual value) are not taken into the running digest.

## Handling relay_early cells

A RELAY_EARLY cell is designed to limit the length any circuit can reach. When a relay receives a RELAY_EARLY cell, and the next node in the circuit is speaking v2 of the link protocol or later, the relay relays the cell as a RELAY_EARLY cell. Otherwise, older Tors will relay it as a RELAY cell.

If a node ever receives more than 8 RELAY_EARLY cells on a given outbound circuit, it SHOULD close the circuit. If it receives any inbound RELAY_EARLY cells, it MUST close the circuit immediately.

When speaking v2 of the link protocol or later, clients MUST only send EXTEND/EXTEND2 message inside RELAY_EARLY cells. Clients SHOULD send the first ~8 relay cells that are not targeted at the first hop of any circuit as RELAY_EARLY cells too, in order to partially conceal the circuit length.

[Starting with Tor 0.2.3.11-alpha, relays should reject any EXTEND/EXTEND2 cell not received in a RELAY_EARLY cell.]

## Relay keys and identities

Every Tor relay has multiple public/private keypairs, with different lifetimes and purposes. We explain them here.

Each key here has an English name (like “Ed25519 identity key”) and an unambiguous identifier (like `KP_relayid_ed`).

In an identifier, a `KP_` prefix denotes a public key, and a `KS_` prefix denotes the corresponding secret key.

> For historical reasons or reasons of space, you will sometimes encounter multiple English names for the same key, or shortened versions of that name. The identifier for a key, however, should always be unique and unambiguous.

For security reasons, **all keys MUST be distinct** : the same key or keypair should never be used for separate roles within the Tor protocol suite, unless specifically stated. For example, a relay’s identity key `KP_relayid_ed` MUST NOT also be used as its medium-term signing key `KP_relaysign_ed`.

## Identity keys

An **identity key** is a long-lived key that uniquely identifies a relay. Two relays with the same set of identity keys are considered to be the same; any relay that changes its identity key is considered to have become a different relay.

An identity keypair’s lifetime is the same as the lifetime of the relay.

Two identity keys are currently defined:

  * `KP_relayid_ed`, `KS_relayid_ed`: An “ed25519 identity key”, also sometimes called a “master identity key”.

This is an Ed25519 key. This key never expires. It is used for only one purpose: signing the `KP_relaysign_ed` key, which is used to sign other important keys and objects.

  * `KP_relayid_rsa`, `KS_relayid_rsa`: A _legacy_ “RSA identity key”.

This is an RSA key. It never expires. It is always 1024 bits long, and (as discussed above) its exponent must be 65537. It is used to sign directory documents and certificates.

Note that because the legacy RSA identity key is so short, it should not be assumed secure against an attacker. It exists for legacy purposes only. When authenticating a relay, a failure to prove an expected RSA identity is sufficient evidence of a _failure_ to authenticate, but a successful proof of an RSA identity is not sufficient to establish a relay’s identity. Parties SHOULD NOT use the RSA identity on its own.

We write `KP_relayid` to refer to a key which is either `KP_relayid_rsa` or `KP_relayid_ed`.

## Online signing keys

Since Tor’s design tries to support keeping the high-value Ed25519 relay identity key offline, we need a corresponding key that can be used for online signing:

  * `KP_relaysign_ed`, `KS_relaysign_ed`: A medium-term Ed25519 “signing” key. This key is signed by the identity key `KP_relayid_ed`, and must be kept online. A new one should be generated periodically. It signs nearly everything else, including directory objects, and certificates for other keys.

When this key is generated, it needs to be signed with the `KP_relayid_ed` key, producing a certificate of type `IDENTITY_V_SIGNING`. The `KP_relayid_ed` key is not used for anything else.

## Circuit extension keys

Each relay has one or more **circuit extension keys** (also called “onion keys”). When creating or extending a circuit, a client uses this key to perform a one-way authenticated key exchange with the target relay. If the recipient does not have the correct private key, the handshake will fail.

Circuit extension keys have moderate lifetimes, on the order of weeks. They are published as part of the directory protocol, and relays SHOULD accept handshakes for a while after publishing any new key. (The exact durations for these are set via a set of network parameters.)

There are two current kinds of circuit extension keys:

  * `KP_ntor`, `KS_ntor`: A curve25519 key used for the `ntor` and `ntorv3` circuit extension handshakes.

  * `KP_onion_tap`, `KS_onion_tap`: A 1024 bit RSA key used for the obsolete `TAP` circuit extension handshake.

## Family keys

When a group of relays are controlled by the same operator(s), we call them a “family”. A family has a keypair:

  * `KP_familyid_ed`, `KS_familyid_ed`: An ed25519 key used to prove membership in a family by signing a family certificate.

## Channel authentication

There are other keys that relays use to authenticate as part of their channel negotiation handshakes.

These keys are authenticated with other, longer lived keys. Relays MAY rotate them as often as they like, and SHOULD rotate them frequently—typically, at least once a day.

  * `KP_link_ed`, `KS_link_ed`. A short-term Ed25519 “link authentication” key, used to authenticate the link handshake: see “Negotiating and initializing channels”. This key is signed by the “signing” key, and should be regenerated frequently.

### Legacy channel authentication

These key types were used in older versions of the channel negotiation handshakes.

  * `KP_legacy_linkauth_rsa`, `KS_legacy_linkauth_rsa`: A 1024-bit RSA key, used to authenticate the link handshake. (No longer used in modern Tor.) It played a role similar to `KP_link_ed`.

As a convenience, to describe legacy versions of the link handshake, we give a name to the public key used for the TLS handshake itself:

  * `KP_legacy_conn_tls`, `KS_legacy_conn_tls`: A short term key used to for TLS connections. (No longer used in modern Tor.) This was another name for the server’s TLS key, which at the time was required to be an RSA key. It was used in some legacy handshake versions.

## Remote hostname lookup

To find the address associated with a hostname, the client sends a RELAY_RESOLVE message containing the hostname to be resolved with a NUL terminating byte.

For a reverse lookup, the client sends a RELAY_RESOLVE message containing an in-addr.arpa address.

The relay replies with a RELAY_RESOLVED message containing any number of answers. Each answer is of the form:
[code]
           Type   (1 octet)
           Length (1 octet)
           Value  (variable-width)
           TTL    (4 octets)
       "Length" is the length of the Value field.
       "Type" is one of:

          0x00 -- Hostname
          0x04 -- IPv4 address
          0x06 -- IPv6 address
          0xF0 -- Error, transient
          0xF1 -- Error, nontransient

[/code]

If any answer has a type of ‘Error’, then no other answer may be given.

The ‘Value’ field encodes the answer:

  * IP addresses are given in network order.

  * Hostnames are given in standard DNS order (“www.example.com”) and not NUL-terminated.

  * The content of Errors is currently ignored. Relays currently set it to the string “Error resolving hostname” with no terminating NUL. Implementations MUST ignore this value.

For backward compatibility, if there are any IPv4 answers, one of those must be given as the first answer.

The RELAY_RESOLVE messge must use a nonzero, distinct streamID; the corresponding RELAY_RESOLVED message must use the same streamID. No stream is actually created by the relay when resolving the name.

## Routing relay cells

## Circuit ID Checks

When a node wants to send a RELAY or RELAY_EARLY cell, it checks the cell’s circID and determines whether the corresponding circuit along that connection is still open. If not, the node drops the cell.

When a node receives a RELAY or RELAY_EARLY cell, it checks the cell’s circID and determines whether it has a corresponding circuit along that connection. If not, the node drops the cell.

> Here and elsewhere, we refer to RELAY and RELAY_EARLY cells collectively as “relay cells”.

## Forward Direction

The forward direction is the direction that CREATE/CREATE2 cells are sent.

### Routing from the Origin

When a relay cell is sent from a client, the client encrypts the cell’s body with the stream cipher as follows:
[code]
    Client sends relay cell:
       For I=N...1, where N is the destination node:
          Encrypt with Kf_I.
       Transmit the encrypted cell to node 1.

[/code]

### Relaying Forward at Onion Routers

When a forward relay cell is received by a relay, it decrypts the cell’s body with the stream cipher, as follows:
[code]
    'Forward' relay cell:
       Use Kf as key; decrypt.

[/code]

The relay then decides whether it recognizes the relay cell, by inspecting the cell as described in Relay cells. If the relay recognizes the cell, it processes the contents of the relay cell. Otherwise, it passes the decrypted relay cell along the circuit if the circuit continues. If the relay at the end of the circuit encounters an unrecognized relay cell, an error has occurred: the relay sends a DESTROY cell to tear down the circuit.

For more information, see Application connections and stream management.

## Backward Direction

The backward direction is the opposite direction from CREATE/CREATE2 cells.

### Relaying Backward at Onion Routers

When a backward relay cell is received by a relay, it encrypts the cell’s body with the stream cipher, as follows:
[code]
    'Backward' relay cell:
       Use Kb as key; encrypt.

[/code]

## Routing to the Origin

When a relay cell arrives at a client, the client decrypts the cell’s body with the stream cipher as follows:
[code]
    Client receives relay cell from node 1:
       For I=1...N, where N is the final node on the circuit:
           Decrypt with Kb_I.
           If the cell is recognized (see [1]), then:
               The sending node is I.
               Stop and process the cell.

[/code]

[1]: “Relay cells”

## Setting circuit keys

As a final step in creating or extending a circuit, both parties derive a shared set of circuit keys used to encrypt, decrypt, and authenticate relay cells sent over that circuit.

To do this, the parties first use a key expansion algorithm to derive a long (possibly unlimited) keystream from the output of the generator, and then partition the output of that keystream into the necessary circuit keys.

The exact key extension algorithm used, and the format of the partitioned keys, depends on which circuit extension handshake is in use.

## KDF-TOR

This key derivation function is used by the CREATE_FAST handshake, and by the obsolete TAP handshake. It shouldn’t be used for new functionality.

If the TAP handshake is used to extend a circuit, both parties base their key material on `K0=g^xy`, represented as a big-endian unsigned integer.

If CREATE_FAST is used, both parties base their key material on `K0=X|Y`.

From the base key material `K0`, they compute a stream of derivative key data as

`K = SHA1(K0 | \[00\]) | SHA1(K0 | \[01\]) | SHA1(K0 | \[02\]) | ...`

Note that because of the one-byte counter used in each SHA1 input, this KDF MUST NOT be used to generate more than `SHA1_LEN * 256 = 5120` bytes of output. We never approach this amount in practice.

When partitioning this keystream for the current relay cell encryption protocol, the first `SHA1_LEN` bytes of K form KH; the next `SHA1_LEN` form the forward digest Df; the next `SHA1_LEN` form the backward digest Db; the next `KEY_LEN` 61-76 form Kf, and the final `KEY_LEN` form Kb. Excess bytes from `K` are discarded.

KH is used in the handshake response to demonstrate knowledge of the computed shared key. Df is used to seed the integrity-checking hash for the stream of data going from the client to the relay, and Db seeds the integrity-checking hash for the data stream from the relay to the client. Kf is used to encrypt the stream of data going from the client to the relay, and Kb is used to encrypt the stream of data going from the relay to the client.

## KDF-RFC5869

For newer KDF needs, including `ntor` and `hs-ntor`. Tor uses the key derivation function HKDF from RFC5869, instantiated with SHA256. (This is due to a construction from Krawczyk.) The generated key material is:
[code]
    K = K_1 | K_2 | K_3 | ...

           Where H(x,t) is HMAC_SHA256 with value x and key t
             and K_1     = H(m_expand | INT8(1) , KEY_SEED )
             and K_(i+1) = H(K_i | m_expand | INT8(i+1) , KEY_SEED )
             and m_expand is an arbitrarily chosen value,
             and INT8(i) is a octet with the value "i".

[/code]

In RFC5869’s vocabulary, this is HKDF-SHA256 with `info == m_expand`, `salt == t_key` (a constant), and `IKM == secret_input` (the output of the ntor handshake). m_expand and t_key are constant parameters, whose values are stated whenever the use of KDF-RFC5869 is specified.

When partitioning this keystream for the current relay cell encryption protocol from the ntor handshake, the first `SHA1_LEN` bytes form the forward digest Df; the next `SHA1_LEN` form the backward digest Db; the next `KEY_LEN` form Kf, the next `KEY_LEN` form Kb, and the final `SHA1_LEN` bytes are taken as a nonce to use in the place of `KH` in the hidden service protocol. Excess bytes from `K` are discarded.

## Application connections and stream management

This section describes how clients use relay messages to communicate with exit nodes, and how use this communication channel to send and receive application data.

## Subprotocol versioning

# Subprotocol-based versioning

Tor implementations use “subprotocol versioning” to describe and negotiate which versions and features of the Tor protocol they support.

Individual protocol features (which we will call “subprotocol capabilities”) are grouped by the area of the protocol to which they apply, and denoted by individual numbers.

> For example, “Relay=3” is a subprotocol capability, as is “Link=5”.

Each subprotocol capability also has a symbolic name for use by programmers. These names are for human convenience only, and not used within the Tor protocols.

> For example, “Relay=3” is also known as `RELAY_EXTEND_IPV6`.

Relays advertise their supported subprotocol capabilities in the “proto” field in their descriptors. Authorities re-publish this information in the “pr” field of the relay’s microdescriptor.

Recognized protocols are as follows. When we need to indicate a protocol numerically in our protocol, we use the numeric Ids in this table.

Protocol| Numeric Id
---|---
Link| 0
LinkAuth| 1
Relay| 2
DirCache| 3
HSDir| 4
HSIntro| 5
HSRend| 6
Desc| 7
Microdesc| 8
Cons| 9
Padding| 10
FlowCtrl| 11
Conflux| 12

## Interpreting subprotocol capabilities

Each subprotocol capability should be interpreted as a single flag, independent of all others.

That is to say, from the fact that an instance supports “Relay=5”, it is incorrect to conclude that the relay supports “Relay=4”, even though 5 is greater than 4.

> Earlier versions of this document, and some other places in our spec and code, refer to “subprotocol versions”. We are avoiding this vocabulary in the future, to avoid this misunderstanding.

## Required and recommended subprotocols

The consensus document contains lists of subprotocol capabilities that are recommend or required for relays and clients.

They are:

  * “recommended-client-protocols”
  * “recommended-relay-protocols”
  * “required-relay-protocols”
  * “required-client-protocols”

Here are the rules a relay and client should follow when encountering a protocol list in the consensus:

  * When a relay lacks a capability listed in recommended-relay-protocols, it should warn its operator that the relay is obsolete.

  * When a relay lacks a capability listed in required-relay-protocols, it should warn its operator as above. If the consensus is newer than the date when the software was released or scheduled for release, it must not attempt to join the network.

  * When a client lacks a capability listed in recommended-client-protocols, it should warn the user that the client is obsolete.

  * When a client lacks a capability listed in required-client-protocols, it should warn the user as above. If the consensus is newer than the date when the software was released, it must not connect to the network. This implements a “safe forward shutdown” mechanism for zombie clients.

  * If a client or relay has a cached consensus telling it that a given capability is required, and it does not implement that capability, it SHOULD NOT try to fetch a newer consensus.

Software release dates SHOULD be automatically updated as part of the release process, to prevent forgetting to move them forward. Software release dates MAY be manually adjusted by maintainers if necessary.

Starting in version 0.2.9.4-alpha, the initial required subprotocol capabilities for clients that we will Recommend and Require was:
[code]
    Cons=1-2 Desc=1-2 DirCache=1 HSDir=1 HSIntro=3 HSRend=1 Link=4
    LinkAuth=1 Microdesc=1-2 Relay=2

[/code]

For relays we Required:
[code]
    Cons=1 Desc=1 DirCache=1 HSDir=1 HSIntro=3 HSRend=1 Link=3-4
    LinkAuth=1 Microdesc=1 Relay=1-2

[/code]

As of Feb 2026, the lists are:
[code]
    recommended-client-protocols Cons=2 Desc=2 DirCache=2 FlowCtrl=1-2 HSDir=2
       HSIntro=4 HSRend=2 Link=4-5 Microdesc=2 Relay=2-4

    recommended-relay-protocols Cons=2 Desc=2 DirCache=2 FlowCtrl=1-2 HSDir=2
       HSIntro=4-5 HSRend=2 Link=4-5 LinkAuth=3 Microdesc=2 Relay=2-4

    required-client-protocols Cons=2 Desc=2 FlowCtrl=1 Link=4 Microdesc=2 Relay=2

    required-relay-protocols Cons=2 Desc=2 DirCache=2 FlowCtrl=1-2 HSDir=2
       HSIntro=4-5 HSRend=2 Link=4-5 LinkAuth=3 Microdesc=2 Relay=2-4

[/code]

## “Link”

The “link” protocols are those used by clients and relays to initiate and receive relay connections and to handle cells on relay connections. The “link” subprotocols correspond 1:1 to those versions.

Two Tor instances can make a connection to each other only if they have at least one link protocol in common.

The current “link” capabilities are: “1” through “5”. See Negotiating versions with VERSIONS cells for more information.

## “LinkAuth”

LinkAuth protocols correspond to varieties of AUTHENTICATE cells used for the v3+ link protocols.

Current subprotocol capabilities are:

  * “1” (`LINKAUTH_RSA_SHA256_TLSSECRET`) – the RSA link authentication described in Link authentication type 1: RSA-SHA256-TLSSecret.

  * “2” is unused, and reserved by proposal 244.

  * “3” (`LINKAUTH_ED25519_SHA256_EXPORTER`) – the ed25519 link authentication described in Link authentication type 3: Ed25519-SHA256-RFC5705.

## “Relay”

The “relay” protocols are those used to handle CREATE/CREATE2 cells, and those that handle the various relay messages received after a CREATE/CREATE2 cell. (Except, relay cells used to manage introduction and rendezvous points are managed with the “HSIntro” and “HSRend” protocols respectively.)

Current subprotocol capabilities are as follows.

  * “1” (`RELAY_BASE`) – supports the TAP key exchange, with all features in Tor 0.2.3. Support for CREATE and CREATED.

  * “2” (`RELAY_NTOR`) – supports the ntor key exchange, and all features in Tor 0.2.4.19. Includes support for CREATE2 and CREATED2 and EXTEND2 and EXTENDED2.

Relay=2 has limited IPv6 support:

    * Clients might not include IPv6 ORPorts in EXTEND2 messages.
    * Relays (and bridges) might not initiate IPv6 connections in response to EXTEND2 messages containing IPv6 ORPorts, even if they are configured with an IPv6 ORPort.

However, relays support accepting inbound connections to their IPv6 ORPorts. And they might extend circuits via authenticated IPv6 connections to other relays.

  * “3” (`RELAY_EXTEND_IPv6`) – relays support extending over IPv6 connections in response to an EXTEND2 message containing an IPv6 ORPort.

Bridges might not extend over IPv6, because they try to imitate client behaviour.

A successful IPv6 extend requires:

    * Relay=3 subprotocol (or later) on the extending relay,
    * an IPv6 ORPort on the extending relay,
    * an IPv6 ORPort for the accepting relay in the EXTEND2 message, and
    * an IPv6 ORPort on the accepting relay. (Because different tor instances can have different views of the network, these checks should be done when the path is selected. Extending relays should only check local IPv6 information, before attempting the extend.)

When relays receive an EXTEND2 message containing both an IPv4 and an IPv6 ORPort, and there is no existing authenticated connection with the target relay, the extending relay may choose between IPv4 and IPv6 at random. The extending relay might not try the other address, if the first connection fails.

As is the case with other subprotocols, tor advertises, recommends, or requires support for this subprotocol, regardless of its current configuration.

In particular:

    * relays without an IPv6 ORPort, and
    * tor instances that are not relays, have the following behaviour, regardless of their configuration:
    * advertise support for “Relay=3” in their descriptor (if they are a relay, bridge, or directory authority), and
    * react to consensuses recommending or requiring support for “Relay=3”.

This subprotocol is described in proposal 311, and implemented in Tor 0.4.5.1-alpha.

  * “4” (`RELAY_NTORV3`) – support the ntorv3 (version 3) key exchange and all features in 0.4.7.3-alpha. This adds a new CREATE2 cell type. See proposal 332 and The “ntor-v3” handshake for more details.

  * “5” (`RELAY_NEGOTIATE_SUBPROTO`) – support the ntorv3 subprotocol request extension (proposal 346) allowing a client to request what features to be used on a circuit.

  * “6” (`RELAY_CRYPT_CGO`) – Support the Counter Galois Onion relay encryption algorithm (proposal 359).

## “HSIntro”

The “HSIntro” protocol handles introduction points.

  * “3” (`HSINTRO_V2`) – supports the RSA-based introduction point protocol of proposal 121 in Tor 0.2.1.6-alpha.

  * “4” (`HSINTRO_V3`) – support ed25519-based HS v3 introduction point protocol as defined by proposal 224 in Tor 0.3.0.4-alpha.

  * “5” (`HSINTRO_RATELIM`) – support ESTABLISH_INTRO message DoS parameters extension for onion service version 3 only in Tor 0.4.2.1-alpha.

## “HSRend”

The “HSRend” protocol handles rendezvous points.

  * “1” (`HSREND_V2`) – supports all features in Tor 0.0.6.

  * “2” (`HSREND_V3`) – supports RENDEZVOUS2 messages of arbitrary length as long as they have 20 bytes of cookie in Tor 0.2.9.1-alpha.

## “HSDir”

The “HSDir” protocols are the set of hidden service document types that can be uploaded to, understood by, and downloaded from a tor relay, and the set of URLs available to fetch them.

  * “1” (`HSDIR_V2`) – supports all features in Tor 0.2.0.10-alpha.

  * “2” (`HSDIR_V3`) – support ed25519 blinded keys request which is defined by the HS v3 protocol as part of proposal 224 in Tor 0.3.0.4-alpha.

## “DirCache”

The “DirCache” protocols are the set of documents available for download from a directory cache via BEGIN_DIR, and the set of URLs available to fetch them. (This excludes URLs for hidden service objects.)

  * “1” (`DIRCACHE_BASE`) – supports all features in Tor 0.2.4.19.

  * “2” (`DIRCACHE_CONSDIFF`) – adds support for consensus diffs in Tor 0.3.1.1-alpha.

## “Desc”

Describes features present or absent in descriptors.

Most features in descriptors don’t require a “Desc” update – only those that need to someday be required. For example, someday clients will need to understand ed25519 identities.

  * “1” (`DESC_BASE`) – supports all features in Tor 0.2.4.19.

  * “2” (`DESC_CROSSSIGN`) – cross-signing with onion-keys, signing with ed25519 identities.

  * “3” (`DESC_NO_TAP`) – parsing relay descriptors without onion-keys; generating them when the `publish-dummy-tap-key` option is `0`.

  * “4” (`DESC_FAMILY_IDS`) – Support for understanding family certs, family IDs, and building paths accordingly.

## “Microdesc”

Describes features present or absent in microdescriptors.

Most features in descriptors don’t require a “Microdesc” update – only those that need to someday be required. These correspond more or less with consensus methods.

  * “1” (`MICRODESC_BASE`) – consensus methods 9 through 20.

  * “2” (`MICRODESC_ED25519_KEY`) – consensus method 21 (adds ed25519 keys to microdescs).

  * “3” (`MICRODESC_NO_TAP`) – Accepts Microdescriptors without onion-key bodies. (Consensus method TBD; see proposal 350.)

## “Cons”

Describes features present or absent in consensus documents.

Most features in consensus documents don’t require a “Cons” update – only those that need to someday be required.

These correspond more or less with consensus methods.

  * “1” (`CONS_BASE`) – consensus methods 9 through 20.

  * “2” (`CONST_ED25519_MDS`) – consensus method 21 (adds ed25519 keys to microdescs).

## “Padding”

Describes the padding capabilities of the relay.

  * “1” [DEFUNCT] – Relay supports circuit-level padding. This subprotocol MUST NOT be used as it was also enabled in relays that don’t actually support circuit-level padding. Advertised by Tor versions from tor-0.4.0.1-alpha and only up to and including tor-0.4.1.4-rc.

  * “2” (`PADDING_MACHINES_CIRC_SETUP`) – Relay supports the HS circuit setup padding machines (proposal 302). Advertised by Tor versions from tor-0.4.1.5 and onwards.

## “FlowCtrl”

Describes the flow control protocol at the circuit and stream level. If there is no FlowCtrl advertised, tor supports the unauthenticated flow control features (version 0).

  * “1” (`FLOWCTRL_AUTH_SENDME`) – supports authenticated circuit level SENDMEs as of proposal 289 in Tor 0.4.1.1-alpha.

  * “2” (`FLOWCTRL_CC`) – supports congestion control by the Exits which implies a new SENDME format and algorithm. See proposal 324 for more details. Advertised in tor 0.4.7.3-alpha.

## “Conflux”

Describes the communications mechanisms used to bundle circuits together, in order to split traffic across multiple paths.

  * “1” (`CONFLUX_BASE`) – Supports the base coflux protocol from proposal 329.

## Tearing down circuits

Circuits are torn down when an unrecoverable error occurs along the circuit, or when all streams on a circuit are closed and the circuit’s intended lifetime is over.

Relays SHOULD also tear down circuits which attempt to create:

  * streams with RELAY_BEGIN, or
  * rendezvous points with ESTABLISH_RENDEZVOUS, ending at the first hop. Letting Tor be used as a single hop proxy makes exit and rendezvous nodes a more attractive target for compromise.

Relays MAY use multiple methods to check if they are the first hop:
[code]
       * If a relay sees a circuit created with CREATE_FAST, the relay is sure to be
         the first hop of a circuit.
       * If a relay is the responder, and the initiator:
         * did not authenticate the link, or
         * authenticated with a key that is not in the consensus,
         then the relay is probably the first hop of a circuit (or the second hop of
         a circuit via a bridge relay).

       Circuits may be torn down either completely or hop-by-hop.

[/code]

To tear down a circuit completely, a relay or client sends a DESTROY cell to the adjacent nodes on that circuit, using the appropriate direction’s circID.

Upon receiving an outgoing DESTROY cell, a relay frees resources associated with the corresponding circuit. If it’s not the end of the circuit, it sends a DESTROY cell for that circuit to the next relay in the circuit. If the node is the end of the circuit, then it tears down any associated edge connections (see Calculating the ‘Digest’ field).

After a DESTROY cell has been processed, a relay ignores all data or DESTROY cells for the corresponding circuit.

To tear down part of a circuit, the client may send a RELAY_TRUNCATE message signaling a given relay (Stream ID zero). That relay sends a DESTROY cell to the next node in the circuit, and replies to the client with a RELAY_TRUNCATED message.

As of 2026, current implementations do not support partial circuit tear down, so clients SHOULD NOT send RELAY_TRUNCATE messages.

[Note: If a relay receives a TRUNCATE message and it has any relay cells still queued on the circuit for the next node it will drop them without sending them. This is not considered conformant behavior, but it probably won’t get fixed until a later version of Tor. Thus, clients SHOULD NOT send a TRUNCATE message to a node running any current version of Tor if a) they have sent relay cells through that node, and b) they aren’t sure whether those cells have been sent on yet.]
[code]
       When an unrecoverable error occurs along one a circuit, the nodes
       must report it as follows:
         * If possible, send a DESTROY cell to relays _away_ from the client.
         * If possible, send *either* a DESTROY cell towards the client, or
           a RELAY_TRUNCATED cell towards the client.

[/code]

Current versions of Tor do not reuse truncated RELAY_TRUNCATED circuits: A client, upon receiving a RELAY_TRUNCATED, will send forward a DESTROY cell in order to entirely tear down the circuit. Because of this, we recommend that relays should send DESTROY towards the client, not RELAY_TRUNCATED.
[code]
       NOTE:
         In tor versions before 0.4.5.13, 0.4.6.11 and 0.4.7.9, relays would
         handle an inbound DESTROY by sending the client a RELAY_TRUNCATED
         message.  Beginning with those versions, relays now propagate
         DESTROY cells in either direction, in order to tell every
         intermediary relays to stop queuing data on the circuit.  The earlier
         behavior created queuing pressure on the intermediary relays.

[/code]

The body of a DESTROY cell or RELAY_TRUNCATED message contains a single octet, describing the reason that the circuit was closed. Implementations SHOULD always use the NONE reason to avoid side channels: sending the real DESTROY reason creates a side channel, particularly if the reason is sent in both directions, because it can enable colluding relays to determine that they are on the same circuit.
[code]
       NOTE:
       Older implementations include the actual reason
       from the list of error codes below
       in RELAY_TRUNCATED messages and DESTROY cells
       sent \_towards\_ the client.
       This is a remnant of the original relay behavior
       of converting a DESTROY into a RELAY_TRUNCATED
       in the inbound direction, which is no longer the case
       (see the NOTE above).

[/code]

Reasons from DESTROY cells SHOULD NOT be propagated downward or upward, due to potential side channel risk: A relay receiving a DESTROY command should use the NONE reason for its next cell.

The error codes are:
[code]
         0 -- NONE            (No reason given.)
         1 -- PROTOCOL        (Tor protocol violation.)
         2 -- INTERNAL        (Internal error.)
         3 -- REQUESTED       (A client sent a TRUNCATE command.)
         4 -- HIBERNATING     (Not currently operating; trying to save bandwidth.)
         5 -- RESOURCELIMIT   (Out of memory, sockets, or circuit IDs.)
         6 -- CONNECTFAILED   (Unable to reach relay.)
         7 -- OR_IDENTITY     (Connected to relay, but its OR identity was not
                               as expected.)
         8 -- CHANNEL_CLOSED  (The OR connection that was carrying this circuit
                               died.)
         9 -- FINISHED        (The circuit has expired for being dirty or old.)
        10 -- TIMEOUT         (Circuit construction took too long)
        11 -- DESTROYED       (The circuit was destroyed w/o client TRUNCATE)
        12 -- NOSUCHSERVICE   (Request for unknown hidden service)

[/code]

---

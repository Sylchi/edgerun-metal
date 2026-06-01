# 22 Ssh Protocols

## SSH protocol extensions

# Tor Project SSH protocol extensions

The SSH protocol provides various extension facilities.

The Tor Project has defined some extensions, using the domain-name-based extension facility. The Tor Project uses names ending `@spec.torproject.org`.

Id(s)| Namespace| Summary| Specification
link (retrieved at)
---|---|---|---
**`ed25519-expanded@`**| Public key algorithm (in SSH/OpenSSH key file)| Expanded ed25519 private key| Arti keystore types
**`x25519@`**| Public key algorithm (in SSH/OpenSSH key file)| X25519 keys| Arti keystore types

## Registration process

New entries may be added to this table after peer review by the Tor Project developers, via gitlab merge request.

The specification links may be to external documents, not managed as part of the Tor Specifications. Or, they may be links to specific sections of the Tor Specifications, or to Proposals. External links should be dated, for ease of future reference.

Ideally, before a protocol is deployed, its specification should be transferred to the Tor Specifications (and the link in the table adjusted).

## Interpretation

This section uses the notation and conventions from `PROTOCOL.key`) and SSH including RFC4251 s5), not those from the rest of the Tor Specifications.

### Interpreting the table

For example, the row for `x25519@` indicates that:

  * The Tor Project has assigned `x25519@spec.torproject.org`
  * In the namespace of public key algorithms - see RFC4250 table 4.11.3, but only when found within an SSH/OpenSSH format key file.
  * The meaning of this name is summarised as “X25519 private key”
  * The full details can be found at the linked text, which is part of the Arti keystore section, below.

The registered names resemble email addresses, but they are **not email addresses** and mail to them will not be delivered.

For further information, consult the linked specifications.

## SSH key types for the Arti keystore

The Arti keystore stores private keys in OpenSSH key format (and, sometimes, public keys, in SSH format). But it needs to store some key types that are not used in the SSH protocols. So the following key types are defined.

These are in the namespace of Public Key Algorithms (RFC4250 4.11.3) but they are only meaningful in OpenSSH format private key files (OpenSSH `PROTOCOL.key` document) and SSH public key files (RFC4716 3.4).

In each case we specify/reference

  * the name of the “public key algorithm” (RFC4250 4.11.3),
  * the underlying cryptographic algorithm(s),
  * the public key data (“key/certificate data” in RFC4253 6.6), see Encoding of the public key data
  * the private key data (see Encoding of the private key data)

### Encoding of the public key data

OpenSSH `PROTOCOL.key` does not clearly state the contents of the `publickey1`/`publickey2`/`publickeyN` fields in the outer (unencrypted) section (`PROTOCOL.key` s1), so we state it here.

Each `publickey` consists of the encoded public key as per RFC4253 6.6 (under “Certificates and public keys are encoded as follows”).

So the overall format of this part of the file is:
[code]
        uint32        number of keys, N
             string       publickey1, where the contained binary data is:
                  string      public key algorithm name (RFC4250 table 4.11.3)
                  byte[]      public key data (algorithm-specific)
             ... keys 2 to N-1 inclusive, each as for publickey1 ...
             string       publickeyN (as for publickey1)

[/code]

### Encoding of the private key data

OpenSSH `PROTOCOL.key` defines the representation of the private key data as, simply: “using the same rules as used for SSH agent”. However, no specific section is referred to; the SSH agent protocol is only available as an Internet Draft draft-miller-ssh-agent-04; and, the actual encoding used by OpenSSH is hard to relate to that document. So we document our understanding here.

The contents of each `privatekey1`/`privatekey2`/`privatekeyN` is:
[code]
        string      public key algorithm name (RFC4250 table 4.11.3)
        byte[]      public key data (algorithm-specific)
        byte[]      private key data (algorithm-specific)

[/code]

>
> Note also that the encrypted section does not separately state the number of keys or their total length. The reader must keep reading until it encounters either the end, or something that looks like padding (starting with a byte 0x01).

### `x25519@spec.torproject.org`

These refer to keys for X25519, ie, Diffie-Hellman on Curve25519, as per RFC7748 6.1. and s5.

The public key data is:
[code]
        string         wrapper for the following fixed-length data:
            byte[32]       the u-coordinate encoded as u[] from RFC7748 s5

[/code]

The private key data is:
[code]
        string         wrapper for the following fixed-length data:
            byte[32]       the scalar k encoded according to RFC7748 s5

[/code]

k MUST be stored as the true scalar value. So if the private key was generated from 32 random bytes according to the procedure described in RFC7748 s5 “in order to decode 32 random bytes as an integer scalar”. the value stored MUST be the “clamped” form: that is, the value _after_ the transformation. If a stored value is a byte string which doesn’t represent a valid scalar according to RFC7748 s5 (i.e. an “unclamped” value) it SHOULD be rejected; if it is not rejected, it MUST NOT be used unchanged, but MUST instead be clamped.

Keys whose `string` wrapper is not of the expected length MUST be rejected.

> The `string` wrapper is useless, but the same wrapper approach is used in official SSH for ed25519 public keys (RFC8709 s4). and for ed25519 private keys in the SSH agent protocol (draft-miller-ssh-agent-04 4.2.3). We do the same here for consistency (and implementation convenience).

> X25519 keys are interconvertible with ed25519 keys. So, it would be possible to store the ed25519 form instead, and convert on load/save. However, we use a different key type to avoid needing conversions during load/save, and to avoid key type punning and accidental key misuse: using the same key material for different algorithms is a poor idea.

### `ed25519-expanded@spec.torproject.org`

These refer to the expanded form of private keys for ed25519 (RFC8032).

This key type appears within OpenSSH private key files. When it does, the `ed25519-expanded@spec.torproject.org` algorithm name is used for the private key (`PROTOCOL.key` section 3, `privatekey1` etc.) but also for the public key (`PROTOCOL.key` section 1, `publickey1` etc.).

> In `PROTOCOL.key` we interpret the requirement that there be “matching” public and private keys to include the requirement that the public key algorithm name strings must be the same.

> In the Arti keystore a private key file whose filename ends with `.ed25519_private` may contain either a standard ed25519 keypair with SSH type `ed25519` or an `ed25519-expanded@spec.torproject.org` keypair.

`ed25519-expanded@spec.torproject.org` SHOULD NOT appear in RFC4716 _public_ key files. Software which is aware of this key type MUST NOT generate such public key files and SHOULD reject them on loading. (Software handling keys in a type-agnostic manner MAY, and probably will, process such files without complaint.)

> These rules are because public keys should always be advertised as `ed25519` even if the private key is only available as `ed25519-expanded@`: this avoids leaking information about the key generation process to relying parties, and simplifies certification and verification.

> Arti will provide a utility to convert anomalous RFC4716 public key files containing keys declared to be of type `ed25519-expanded@spec.torproject.org` to fully conforming files containg `ed25519` keys. In other circumstances Arti will reject such anomalous files.

The public key data is the same as for the official `ed25519` type:
[code]
        string         wrapper for the following fixed-length data:
            byte[32]       the actual public key, ENC(A) from RFC8032 3.2

[/code]

(Reference: RFC8032 3.2.)

The private key data is as follows:
[code]
        string         wrapper for the following fixed-length data:
            byte[32]       ENC(s) as per RFC8032 3.2, "expanded secret key"
            byte[32]       `h_b...h_(2b-1)` as per RFC8032 3.3, "separation nonce"

[/code]

(References: `ENC(s)` in RFC8032 3.2; `h_b || ... || h_(2b-1)` as per RFC8032 3.3.)

Keys whose `string` wrapper is not of the expected length MUST be rejected.

> As with `x25519`, the `string` wrapper is useless. We adopt it here for the same reasons.

This private key format does not provide a way to convey or establish a corresponding (unexpanded, standard) ed25519 private key `k`.

> The ed25519 standards define the private key for ed25519 as a 32-byte secret `k`. `k` is then hashed and processed into parameters used for signing, and the public key for verification. The `ed25519-expanded@spec.torproject.org` can represent private keys which can be used with the ed25519 signature algorithm, and for which a corresponding working public key is known, but for which there is no known value of `k` (the “real ed25519” private key). Allowing such keys can be convenient when one wishes to find private keys whose public keys have particular patterns, for example when trying to find a `.onion` domain for a Tor Hidden Service. This format is also used where blinded ed25519 keys need to be stored.

---

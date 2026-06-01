# 29 Cert Spec

## Binary certificate formats

This document describes two certificate formats that Tor uses for certifying Ed25519 keys, and discusses how those formats is labeled and encoded.

There are:

  * “Tor Ed25519 certificates”, which are signed by Ed25519 keys.
  * “Tor RSA→Ed25519 cross-certificates”, which are signed by RSA keys.

These are not the only certificate format that Tor uses. For the certificates that authorities use for their signing keys, see “Authority key certificates”.

Additionally, Tor uses TLS, which depends on X.509 certificates.

> The certificates in this document were first introduced in proposal 220, and were first supported by Tor in Tor version 0.2.7.2-alpha.

### Tor Ed25519 Certificates

A Tor Ed25519 Certificate certifies a key, or a digest of a key, or a digest of some other object, using an Ed25519 key to sign it.

Field| Size| Description
---|---|---
`VERSION`| 1| The version of this format
`CERT_TYPE`| 1| Purpose and meaning of the cert
`EXPIRATION_DATE`| 4| When the cert becomes invalid
`CERT_KEY_TYPE`| 1| Type of `CERTIFIED_KEY`
`CERTIFIED_KEY`| 32| Certified key, or its digest
`N_EXTENSIONS`| 1| Number of extensions
`N_EXTENSIONS` times:| |
\- `ExtLen`| 2| Length of encoded extension body
\- `ExtType`| 1| Type of extension
\- `ExtFlags`| 1| Control interpretation of extension
\- `ExtData`| `ExtLen`| Encoded extension body
`SIGNATURE`| 64| Signature of all previous fields

The `VERSION` field holds the value `[01]`.

The `CERT_TYPE` field holds a value depending on the type of certificate. (See “Certificate types”.)

The `CERTIFIED_KEY` field is a subject public key, or a digest of a subject public key. The representation depends on the value of `CERT_KEY_TYPE`. (See “List of certified key types”.)

The `EXPIRATION_DATE` is a date, given in **hours** since the epoch, after which this certificate isn’t valid.

> (A four-byte date here will work fine until 10136 A.D.)

The `ExtFlags` field holds flags. Only one flag is currently defined:

  * **1** : `AFFECTS_VALIDATION`. This flag tells an implementation how to handle an extension whose `ExtType` it does not recognize. If this flag is set on an extension, then the extension affects whether the certificate is valid; implementations MUST NOT accept the certificate as valid if the do not recognize the extension’s `ExtType`. If this flag is _not_ set on an extension, implementations MUST ignore that extension if they do not recognize the `ExtType`.

> Ignoring a _recognized_ extension is never valid.

The interpretation of `ExtBody` depends on the `ExtType` field. See “Recognized extensions” below.

It is an error for an `ExtLen` to extend beyond the end of a certificate.

Before acting based on any certificate, parties MUST know which key it is supposed to be signed by, and then check the signature.

> It _is_ okay to inspect the certificate’s fields before checking the signature, and reject the certificate if is ill-formed, expired, or so on.
>
> This does not count as “acting based on a certificate.”

The signature is created as an Ed25519 signature, over all the fields in the certificate up until but not including `SIGNATURE`.

### Defined Tor Ed25519 certificate extensions

#### Signed-with-ed25519-key extension [type 04]

In several places, it’s desirable to bundle the signing key along with the certificate. We do so with this extension.

With this extension:

  * `ExtLen` is 32.
  * `ExtData is a 32-byte Ed25519 public key.

When this extension is present, it MUST match the key used to sign the certificate.

### Tor RSA→Ed25519 cross-certificate

A Tor RSA→Ed25519 Cross-certificate signs an Ed25519 key using a legacy 1024-bit RSA key. Its format is:

Field| Size| Description
---|---|---
`ED25519_KEY`| 32| The subject key
`EXPIRATION_DATE`| 4| When the cert becomes invalid
`SIGLEN`| 1| Length of RSA signature.
`SIGNATURE`| `SIGLEN`| RSA Signature

Just as with the Ed25519 certificates above, the `EXPIRATION_DATE` field is a number of **hours** since the epoch.

As elsewhere, the RSA signature is generated using RSA-PKCSv1 padding, with hash algorithm OIDs omitted.

The signature is computed on the SHA-256 digest of `PREFIX | FIELDS`, where `PREFIX` is the string `"Tor TLS RSA/Ed25519 cross-certificate"` (without any terminating NUL), and `FIELDS` is all other fields in the certificate (other than the signature itself).

## Certificate types (CERT_TYPE field)

This table shows values that can appear in the `CertType` field used in a `CERTS` cell during channel negotiation.

Some of these values (those marked with “Ed”) are also used in the `CERT_TYPE` field in Tor Ed25519 certificates. (X.509 and RSA→Ed25519 cross-certificates don’t have a `CERT_TYPE` field.)

> You might need to scroll this table to view it all.
>
> We’ll try to fix this once we have a better grip on our mdbook CSS.

Type| Mnemonic| Format| Subject| Signing key| Reference| Notes
---|---|---|---|---|---|---
`[01]`| `TLS_LINK_X509`| X.509| `KP_legacy_conn_tls`| `KS_relayid_rsa`| Legacy channel negotiation| Obsolete
`[02]`| `RSA_ID_X509`| X.509| `KP_relayid_rsa`| `KS_relayid_rsa`| Legacy channel negotiation| Obsolete
`[03]`| `LINK_AUTH_X509`| X.509| `KP_legacy_linkauth_rsa`| `KS_relayid_rsa`| Legacy channel negotiation| Obsolete
`[04]`| `IDENTITY_V_SIGNING`| Ed| `KP_relaysign_ed`| `KS_relayid_ed`| Online signing keys|
`[05]`| `SIGNING_V_TLS_CERT`| Ed| A TLS certificate| `KS_relaysign_ed`| CERTS cells|
`[06]`| `SIGNING_V_LINK_AUTH`| Ed| `KP_link_ed`| `KS_relaysign_ed`| CERTS cells|
`[07]`| `RSA_ID_V_IDENTITY`| Rsa| `KP_relayid_ed`| `KS_relayid_rsa`| CERTS cells|
`[08]`| `BLINDED_ID_V_SIGNING`| Ed| `KP_hs_desc_sign`| `KS_hs_blind_id`| HsDesc (outer)|
`[09]`| `HS_IP_V_SIGNING`| Ed| `KP_hs_ipt_sid`| `KS_hs_desc_sign`| HsDesc (`auth-key`)| Backwards, see note 1
`[0A]`| `NTOR_CC_IDENTITY`| Ed| `KP_relayid_ed`| `EdCvt``(``KS_ntor``)`| ntor cross-cert|
`[0B]`| `HS_IP_CC_SIGNING`| Ed| `KP_hss_ntor`| `KS_hs_desc_sign`| HsDesc (`enc-key-cert`)| Backwards, see note 1
[`[0C]`| `FAMILY_V_IDENTITY`| Ed| `KP_relayid_ed`| `KS_familyid_ed`| family-cert|

Note 1: The certificate types [`[09] HS_IP_V_SIGNING`](./rend-spec/hsdesc-encrypt.html#auth-key) and [`[0B] HS_IP_CC_SIGNING`](./rend-spec/hsdesc-encrypt.html#enc-key-cert) were implemented incorrectly, and now cannot be changed. Their signing keys and subject keys, as implemented, are given in the table. They were originally meant to be the inverse of this order.

## List of extension types

  * `[04]` \- signed-with-ed25519-key

## List of certified key types (CERT_KEY_TYPE field)

  * `[01]`: ed25519 key
  * `[02]`: `SHA256(DER(key))` for an RSA key. (Not currently used.)
  * `[03]`: SHA-256 digest of an X.509 certificate. (Used with certificate type 5.)

> (NOTE: Up till 0.4.5.1-alpha, all versions of Tor have incorrectly used `[01]` for all types of certified key. Implementations SHOULD allow “01” in this position, and infer the actual key type from the `CERT_TYPE` field.

---

# 13 Onion Services

This document specifies how the hidden service version 3 protocol works. This text used to be proposal 224-rend-spec-ng.txt.

This document describes a proposed design and specification for hidden services in Tor version 0.2.5.x or later. It’s a replacement for the current rend-spec.txt, rewritten for clarity and for improved design.

## Deriving blinded keys and subcredentials [SUBCRED]

# Deriving blinded keys and subcredentials

In each time period (see [TIME-PERIODS] for a definition of time periods), a hidden service host uses a different blinded private key to sign its directory information, and clients use a different blinded public key as the index for fetching that information.

For a candidate for a key derivation method, see Appendix [KEYBLIND].

Additionally, clients and hosts derive a subcredential for each period. Knowledge of the subcredential is needed to decrypt hidden service descriptors for each period and to authenticate with the hidden service host in the introduction process. Unlike the credential, it changes each period. Knowing the subcredential does not enable the hidden service host to derive the main credential–therefore, it is safe to put the subcredential on the hidden service host while leaving the hidden service’s private key offline.

The subcredential for a period is derived as:
[code]
    N_hs_subcred = SHA3_256("subcredential" | N_hs_cred | blinded-public-key).

[/code]

In the above formula, credential corresponds to:
[code]
    N_hs_cred = SHA3_256("credential" | public-identity-key)

[/code]

where `public-identity-key` is the public identity master key of the hidden service.

# Locating, uploading, and downloading hidden service descriptors

To avoid attacks where a hidden service’s descriptor is easily targeted for censorship, we store them at different directories over time, and use shared random values to prevent those directories from being predictable far in advance.

Which Tor servers hosts a hidden service depends on:
[code]
             * the current time period,
             * the daily subcredential,
             * the hidden service directories' public keys,
             * a shared random value that changes in each time period,
               shared_random_value.
             * a set of network-wide networkstatus consensus parameters.
               (Consensus parameters are integer values voted on by authorities
               and published in the consensus documents, described in
               dir-spec.txt, section 3.3.)

       Below we explain in more detail.

[/code]

## Dividing time into periods

To prevent a single set of hidden service directory from becoming a target by adversaries looking to permanently censor a hidden service, hidden service descriptors are uploaded to different locations that change over time.

The length of a “time period” is controlled by the consensus parameter ‘hsdir-interval’, and is a number of minutes between 30 and 14400 (10 days). The default time period length is 1440 (one day).

Time periods start at the Unix epoch (Jan 1, 1970), and are computed by taking the number of minutes since the epoch and dividing by the time period. However, we want our time periods to start at a regular offset from the SRV voting schedule, so we subtract a “rotation time offset” of 12 voting periods from the number of minutes since the epoch, before dividing by the time period (effectively making “our” epoch start at Jan 1, 1970 12:00UTC when the voting period is 1 hour.)

Example: If the current time is 2016-04-13 11:15:01 UTC, making the seconds since the epoch 1460546101, and the number of minutes since the epoch 24342435\. We then subtract the “rotation time offset” of 12*60 minutes from the minutes since the epoch, to get 24341715. If the current time period length is 1440 minutes, by doing the division we see that we are currently in time period number 16903.

Specifically, time period #16903 began 16903*1440*60 + (12*60*60) seconds after the epoch, at 2016-04-12 12:00 UTC, and ended at 16904*1440*60 + (12*60*60) seconds after the epoch, at 2016-04-13 12:00 UTC.

## When to publish a hidden service descriptor

Hidden services periodically publish their descriptor to the responsible HSDirs. The set of responsible HSDirs is determined as specified in [WHERE-HSDESC].

Specifically, every time a hidden service publishes its descriptor, it also sets up a timer for a random time between 60 minutes and 120 minutes in the future. When the timer triggers, the hidden service needs to publish its descriptor again to the responsible HSDirs for that time period. [TODO: Control republish period using a consensus parameter?]

### Overlapping descriptors

Hidden services need to upload multiple descriptors so that they can be reachable to clients with older or newer consensuses than them. Services need to upload their descriptors to the HSDirs _before_ the beginning of each upcoming time period, so that they are readily available for clients to fetch them. Furthermore, services should keep uploading their old descriptor even after the end of a time period, so that they can be reachable by clients that still have consensuses from the previous time period.

Hence, services maintain two active descriptors at every point. Clients on the other hand, don’t have a notion of overlapping descriptors, and instead always download the descriptor for the current time period and shared random value. It’s the job of the service to ensure that descriptors will be available for all clients. See section [FETCHUPLOADDESC] for how this is achieved.

[TODO: What to do when we run multiple hidden services in a single host?]

## Where to publish a hidden service descriptor

This section specifies how the HSDir hash ring is formed at any given time. Whenever a time value is needed (e.g. to get the current time period number), we assume that clients and services use the valid-after time from their latest live consensus.

The following consensus parameters control where a hidden service descriptor is stored;
[code]
            hsdir_n_replicas = an integer in range [1,16] with default value 2.
            hsdir_spread_fetch = an integer in range [1,128] with default value 3.
            hsdir_spread_store = an integer in range [1,128] with default value 4.
               (Until 0.3.2.8-rc, the default was 3.)

[/code]

To determine where a given hidden service descriptor will be stored in a given period, after the blinded public key for that period is derived, the uploading or downloading party calculates:
[code]
            for replicanum in 1...hsdir_n_replicas:
                hs_service_index(replicanum) =
                                SHA3_256("store-at-idx" |
                                         blinded_public_key |
                                         INT_8(replicanum) |
                                         INT_8(period_length) |
                                         INT_8(period_num) )

[/code]

where blinded_public_key is specified in section [KEYBLIND], period_length is the length of the time period in minutes, and period_num is calculated using the current consensus “valid-after” as specified in section [TIME-PERIODS].

Then, for each node listed in the current consensus with the HSDir flag, we compute a directory index for that node as:
[code]
               hs_relay_index(node) =
                            SHA3_256("node-idx" | node_identity |
                                     shared_random_value |
                                     INT_8(period_num) |
                                     INT_8(period_length) )

[/code]

where shared_random_value is the shared value generated by the authorities in section [PUB-SHAREDRANDOM], and node_identity is the ed25519 identity key of the node.

Finally, for replicanum in 1…hsdir_n_replicas, the hidden service host uploads descriptors to the first hsdir_spread_store nodes whose indices immediately follow hs_service_index(replicanum). If any of those nodes have already been selected for a lower-numbered replica of the service, any nodes already chosen are disregarded (i.e. skipped over) when choosing a replica’s hsdir_spread_store nodes.

When choosing an HSDir to download from, clients choose randomly from among the first hsdir_spread_fetch nodes after the indices. (Note that, in order to make the system better tolerate disappearing HSDirs, hsdir_spread_fetch may be less than hsdir_spread_store.) Again, nodes from lower-numbered replicas are disregarded when choosing the spread for a replica.

## Using time periods and SRVs to fetch/upload HS descriptors

Hidden services and clients need to make correct use of time periods (TP) and shared random values (SRVs) to successfully fetch and upload descriptors. Furthermore, to avoid problems with skewed clocks, both clients and services use the ‘valid-after’ time of a live consensus as a way to take decisions with regards to uploading and fetching descriptors. By using the consensus times as the ground truth here, we minimize the desynchronization of clients and services due to system clock. Whenever time-based decisions are taken in this section, assume that they are consensus times and not system times.

As [PUB-SHAREDRANDOM] specifies, consensuses contain two shared random values (the current one and the previous one). Hidden services and clients are asked to match these shared random values with descriptor time periods and use the right SRV when fetching/uploading descriptors. This section attempts to precisely specify how this works.

Let’s start with an illustration of the system:
[code]
          +------------------------------------------------------------------+
          |                                                                  |
          | 00:00      12:00       00:00       12:00       00:00       12:00 |
          | SRV#1      TP#1        SRV#2       TP#2        SRV#3       TP#3  |
          |                                                                  |
          |  $==========|-----------$===========|-----------$===========|    |
          |                                                                  |
          |                                                                  |
          +------------------------------------------------------------------+

                                          Legend: [TP#1 = Time Period #1]
                                                  [SRV#1 = Shared Random Value #1]
                                                  ["$" = descriptor rotation moment]

[/code]

### Client behavior for fetching descriptors

And here is how clients use TPs and SRVs to fetch descriptors:

Clients always aim to synchronize their TP with SRV, so they always want to use TP#N with SRV#N: To achieve this wrt time periods, clients always use the current time period when fetching descriptors. Now wrt SRVs, if a client is in the time segment between a new time period and a new SRV (i.e. the segments drawn with “-”) it uses the current SRV, else if the client is in a time segment between a new SRV and a new time period (i.e. the segments drawn with “=”), it uses the previous SRV.

Example:
[code]
    +------------------------------------------------------------------+
    |                                                                  |
    | 00:00      12:00       00:00       12:00       00:00       12:00 |
    | SRV#1      TP#1        SRV#2       TP#2        SRV#3       TP#3  |
    |                                                                  |
    |  $==========|-----------$===========|-----------$===========|    |
    |              ^           ^                                       |
    |              C1          C2                                      |
    +------------------------------------------------------------------+

[/code]

If a client (C1) is at 13:00 right after TP#1, then it will use TP#1 and SRV#1 for fetching descriptors. Also, if a client (C2) is at 01:00 right after SRV#2, it will still use TP#1 and SRV#1.

### Service behavior for uploading descriptors

As discussed above, services maintain two active descriptors at any time. We call these the “first” and “second” service descriptors. Services rotate their descriptor every time they receive a consensus with a valid_after time past the next SRV calculation time. They rotate their descriptors by discarding their first descriptor, pushing the second descriptor to the first, and rebuilding their second descriptor with the latest data.

Services like clients also employ a different logic for picking SRV and TP values based on their position in the graph above. Here is the logic:

#### First descriptor upload logic

Here is the service logic for uploading its first descriptor:

When a service is in the time segment between a new time period a new SRV (i.e. the segments drawn with “-”), it uses the previous time period and previous SRV for uploading its first descriptor: that’s meant to cover for clients that have a consensus that is still in the previous time period.

Example: Consider in the above illustration that the service is at 13:00 right after TP#1. It will upload its first descriptor using TP#0 and SRV#0. So if a client still has a 11:00 consensus it will be able to access it based on the client logic above.

Now if a service is in the time segment between a new SRV and a new time period (i.e. the segments drawn with “=”) it uses the current time period and the previous SRV for its first descriptor: that’s meant to cover clients with an up-to-date consensus in the same time period as the service.

Example:
[code]
    +------------------------------------------------------------------+
    |                                                                  |
    | 00:00      12:00       00:00       12:00       00:00       12:00 |
    | SRV#1      TP#1        SRV#2       TP#2        SRV#3       TP#3  |
    |                                                                  |
    |  $==========|-----------$===========|-----------$===========|    |
    |                          ^                                       |
    |                          S                                       |
    +------------------------------------------------------------------+

[/code]

Consider that the service is at 01:00 right after SRV#2: it will upload its first descriptor using TP#1 and SRV#1.

#### Second descriptor upload logic

Here is the service logic for uploading its second descriptor:

When a service is in the time segment between a new time period a new SRV (i.e. the segments drawn with “-”), it uses the current time period and current SRV for uploading its second descriptor: that’s meant to cover for clients that have an up-to-date consensus on the same TP as the service.

Example: Consider in the above illustration that the service is at 13:00 right after TP#1: it will upload its second descriptor using TP#1 and SRV#1.

Now if a service is in the time segment between a new SRV and a new time period (i.e. the segments drawn with “=”) it uses the next time period and the current SRV for its second descriptor: that’s meant to cover clients with a newer consensus than the service (in the next time period).

Example:
[code]
    +------------------------------------------------------------------+
    |                                                                  |
    | 00:00      12:00       00:00       12:00       00:00       12:00 |
    | SRV#1      TP#1        SRV#2       TP#2        SRV#3       TP#3  |
    |                                                                  |
    |  $==========|-----------$===========|-----------$===========|    |
    |                          ^                                       |
    |                          S                                       |
    +------------------------------------------------------------------+

[/code]

Consider that the service is at 01:00 right after SRV#2: it will upload its second descriptor using TP#2 and SRV#2.

### Directory behavior for handling descriptor uploads [DIRUPLOAD]

Upon receiving a hidden service descriptor publish request, directories MUST check the following:
[code]
         * The outer wrapper of the descriptor can be parsed according to
           [DESC-OUTER]
         * The version-number of the descriptor is "3"
         * If the directory has already cached a descriptor for this hidden service,
           the revision-counter of the uploaded descriptor must be greater than the
           revision-counter of the cached one
         * The descriptor signature is valid

[/code]

If any of these basic validity checks fails, the directory MUST reject the descriptor upload.

NOTE: Even if the descriptor passes the checks above, its first and second layers could still be invalid: directories cannot validate the encrypted layers of the descriptor, as they do not have access to the public key of the service (required for decrypting the first layer of encryption), or the necessary client credentials (for decrypting the second layer).

## Expiring hidden service descriptors

Hidden services set their descriptor’s “descriptor-lifetime” field to 180 minutes (3 hours). Hidden services ensure that their descriptor will remain valid in the HSDir caches, by republishing their descriptors periodically as specified in [WHEN-HSDESC].

Hidden services MUST also keep their introduction circuits alive for as long as descriptors including those intro points are valid (even if that’s after the time period has changed).

Hidden services SHOULD continue to maintain every introduction point which was advertised in any non-expired previously uploaded descriptor, even if that descriptor has been replaced by a newer version.

> This is necessary because there is no way for a hidden service to guarantee that every client with a copy of the old descriptor, with old introduction points, knows that the descriptor is out of date.

Conversely, a client which experiences INTRODUCE_ACK with STATUS NOT_RECOGNIZED SHOULD consider attempting to download a fresh descriptor, if it hasn’t done so recently, even if it has an existing descriptor which is within its validity period. These attempts MUST be rate limited; as a guideline, clients should not query the same hidden service directory for the same descriptor ID more than once every 15 minutes.

> This is necessary to cope with hidden services which do not properly maintain all previously published introduction points, for example because they lack suitable persistent storage, or are C Tor.
>
> Trying to get a fresh descriptor could also help if many of the previous introduction points are at malfunctioning relays.

Clients MUST NOT replace their existing descriptor unless the newly downloaded one is more recent:

  * if both descriptors are associated with the same time period, the more recent descriptor is the one with the highest revision counter
  * otherwise, the more recent descriptor is the one associated with the more recent time period

## URLs for anonymous uploading and downloading

Hidden service descriptors conforming to this specification are uploaded with an HTTP POST request to the URL `/tor/hs/<version>/publish` relative to the hidden service directory’s root, and downloaded with an HTTP GET request for the URL `/tor/hs/<version>/<z>` where `<z>` is a base64 encoding of the hidden service’s blinded public key and `<version>` is the protocol version which is “3” in this case.

These requests must be made anonymously, on circuits not used for anything else.

The legacy “.z” suffix is **not** supported for these URLs.

To avoid fingerprinting, clients SHOULD NOT advertise any compression methods in their `Accept-Encoding` headers for these requests that are not listed as must-implement for clients in the directory specification.

## Client-side validation of onion addresses

When a Tor client receives a prop224 onion address from the user, it MUST first validate the onion address before attempting to connect or fetch its descriptor. If the validation fails, the client MUST refuse to connect.

As part of the address validation, Tor clients should check that the underlying ed25519 key does not have a torsion component. If Tor accepted ed25519 keys with torsion components, attackers could create multiple equivalent onion addresses for a single ed25519 key, which would map to the same service. We want to avoid that because it could lead to phishing attacks and surprising behaviors (e.g. imagine a browser plugin that blocks onion addresses, but could be bypassed using an equivalent onion address with a torsion component).

The right way for clients to detect such fraudulent addresses (which should only occur malevolently and never naturally) is to extract the ed25519 public key from the onion address and multiply it by the ed25519 group order and ensure that the result is the ed25519 identity element. For more details, please see [TORSION-REFS].

## Encoding onion addresses [ONIONADDRESS]

The onion address of a hidden service includes its identity public key, a version field and a basic checksum. All this information is then base32 encoded as shown below:
[code]
         onion_address = base32(PUBKEY | CHECKSUM | VERSION) + ".onion"
         CHECKSUM = SHA3_256(".onion checksum" | PUBKEY | VERSION)[:2]

         where:
           - PUBKEY is the 32 bytes ed25519 master pubkey (KP_hs_id) of the hidden service.
           - VERSION is a one byte version field (default value '\x03')
           - ".onion checksum" is a constant string
           - CHECKSUM is truncated to two bytes before inserting it in onion_address

      Here are a few example addresses:

           pg6mmjiyjmcrsslvykfwnntlaru7p5svn6y2ymmju6nubxndf4pscryd.onion
           sp3k262uwy4r2k3ycr5awluarykdpag6a7y33jxop4cs2lu5uz5sseqd.onion
           xa4r2iadxm55fbnqgwwi5mymqdcofiu3w6rpbtqn7b2dyn7mgwj64jyd.onion

[/code]

> For historical notes and rationales about this encoding, see this discussion thread.

## Encrypting data between client and host

A successfully completed handshake, as embedded in the INTRODUCE/RENDEZVOUS messages, gives the client and hidden service host a shared set of keys Kf, Kb, Df, Db, which they use for sending end-to-end traffic encryption and authentication as in the regular Tor relay encryption protocol, applying encryption with these keys before other encryption, and decrypting with these keys before other decryption. The client encrypts with Kf and decrypts with Kb; the service host does the opposite.

As mentioned previously, these keys are used the same as for regular relay cell encryption, except that instead of using AES-128 and SHA1, both parties use AES-256 and SHA3-256.

## Appendix F: Hidden service directory format [HIDSERVDIR-FORMAT]

This appendix section specifies the contents of the HiddenServiceDir directory:

  * “hostname” [FILE]

This file contains the onion address of the onion service.

  * “private_key_ed25519” [FILE]

This file contains the private master ed25519 key of the onion service. [TODO: Offline keys]
[code]
      - "./authorized_clients/"                  [DIRECTORY]
        "./authorized_clients/alice.auth"        [FILE]
        "./authorized_clients/bob.auth"          [FILE]
        "./authorized_clients/charlie.auth"      [FILE]

[/code]

> Note: “restricted discovery” is called “client authorization” in the C Tor implementation

If client authorization is enabled, this directory MUST contain a “.auth” file for each authorized client. Each such file contains the public key of the respective client. The files are transmitted to the service operator by the client.

See section [RESTRICTED-DISCOVERY-MGMT] for more details and the format of the client file.

(NOTE: client authorization is implemented as of 0.3.5.1-alpha.)

## Hidden service descriptors: encryption format [HS-DESC-ENC]

# Hidden service descriptors: encryption format

Hidden service descriptors are protected by two layers of encryption. Clients need to decrypt both layers to connect to the hidden service.

The first layer of encryption provides confidentiality against entities who don’t know the public key of the hidden service (e.g. HSDirs), while the second layer of encryption is only useful when restricted discovery is enabled and protects against entities that do not possess valid client credentials.

## First layer of encryption

The first layer of HS descriptor encryption is designed to protect descriptor confidentiality against entities who don’t know the public identity key of the hidden service.

### First layer encryption logic

The encryption keys and format for the first layer of encryption are generated as specified in [HS-DESC-ENCRYPTION-KEYS] with customization parameters:
[code]
         SECRET_DATA = blinded-public-key
         STRING_CONSTANT = "hsdir-superencrypted-data"

[/code]

The encryption scheme in [HS-DESC-ENCRYPTION-KEYS] uses the service credential which is derived from the public identity key (see [SUBCRED]) to ensure that only entities who know the public identity key can decrypt the first descriptor layer.

The ciphertext is placed on the “superencrypted” field of the descriptor.

Before encryption the plaintext is padded with NUL bytes to the nearest multiple of 10k bytes.

### First layer plaintext format

After clients decrypt the first layer of encryption, they need to parse the plaintext to get to the second layer ciphertext which is contained in the “encrypted” field.

If restricted discovery is enabled, the hidden service generates a fresh descriptor_cookie key (`N_hs_desc_enc`, 32 random bytes) and encrypts it using each authorized client’s identity x25519 key. Authorized clients can use the descriptor cookie (`N_hs_desc_enc`) to decrypt the second (inner) layer of encryption. Our encryption scheme requires the hidden service to also generate an ephemeral x25519 keypair for each new descriptor.

If restricted discovery is disabled, fake data is placed in each of the fields below to obfuscate whether restricted discovery is enabled.

Here are all the supported fields:

“desc-auth-type” SP type NL

[Exactly once]
[code]
          This field contains the type of authorization used to protect the
          descriptor. The only recognized type is "x25519" and specifies the
          encryption scheme described in this section.

          If restricted discovery is disabled, the value here should be "x25519".

         "desc-auth-ephemeral-key" SP KP_hs_desc_ephem NL

          [Exactly once]

          This field contains `KP_hss_desc_enc`, an ephemeral x25519 public
          key generated by the hidden service and encoded in base64. The key
          is used by the encryption scheme below.

          If restricted discovery is disabled, the value here should be a fresh
          x25519 pubkey that will remain unused.

         "auth-client" SP client-id SP iv SP encrypted-cookie

          [At least once]

          When restricted discovery is enabled, the hidden service inserts an
          "auth-client" line for each of its authorized clients. If client
          authorization is disabled, the fields here can be populated with random
          data of the right size (that's 8 bytes for 'client-id', 16 bytes for 'iv'
          and 16 bytes for 'encrypted-cookie' all encoded with base64).

          When restricted discovery is enabled, each "auth-client" line
          contains the descriptor cookie `N_hs_desc_enc` encrypted to each
          individual client. We assume that each authorized client possesses
          a pre-shared x25519 keypair (`KP_hsc_desc_enc`) which is used to
          decrypt the descriptor cookie.

          We now describe the descriptor cookie encryption scheme. Here is what
          the hidden service computes:

              SECRET_SEED = x25519(KS_hs_desc_ephem, KP_hsc_desc_enc)
              KEYS = SHAKE256_KDF(N_hs_subcred | SECRET_SEED, 40)
              CLIENT-ID = fist 8 bytes of KEYS
              COOKIE-KEY = last 32 bytes of KEYS

          Here is a description of the fields in the "auth-client" line:

          - The "client-id" field is CLIENT-ID from above encoded in base64.

          - The "iv" field is 16 random bytes encoded in base64.

          - The "encrypted-cookie" field contains the descriptor cookie ciphertext
            as follows and is encoded in base64:
               encrypted-cookie = STREAM(iv, COOKIE-KEY) XOR N_hs_desc_enc.

          See section [FIRST-LAYER-CLIENT-BEHAVIOR] for the client-side logic of
          how to decrypt the descriptor cookie.

        "encrypted" NL encrypted-string

         [Exactly once]

          An encrypted blob containing the second layer ciphertext, whose format is
          discussed in [HS-DESC-SECOND-LAYER] below. The blob is base64 encoded
          and enclosed in -----BEGIN MESSAGE---- and ----END MESSAGE---- wrappers.

        Compatibility note: The C Tor implementation does not include a final
        newline when generating this first-layer-plaintext section; other
        implementations MUST accept this section even if it is missing its final
        newline.  Other implementations MAY generate this section without a final
        newline themselves, to avoid being distinguishable from C tor.

[/code]

### Client behavior
[code]
        The goal of clients at this stage is to decrypt the "encrypted" field as
        described in [HS-DESC-SECOND-LAYER].

        If restricted discovery is enabled, authorized clients need to extract the
        descriptor cookie to proceed with decryption of the second layer as
        follows:

        An authorized client parsing the first layer of an encrypted descriptor,
        extracts the ephemeral key from "desc-auth-ephemeral-key" and calculates
        CLIENT-ID and COOKIE-KEY as described in the section above using their
        x25519 private key. The client then uses CLIENT-ID to find the right
        "auth-client" field which contains the ciphertext of the descriptor
        cookie. The client then uses COOKIE-KEY and the iv to decrypt the
        descriptor_cookie, which is used to decrypt the second layer of descriptor
        encryption as described in [HS-DESC-SECOND-LAYER].

[/code]

### Hiding restricted discovery data
[code]
        Hidden services should avoid leaking whether restricted discovery is
        enabled or how many authorized clients there are.

        Hence even when restricted discovery is disabled, the hidden service adds
        fake "desc-auth-type", "desc-auth-ephemeral-key" and "auth-client" lines to
        the descriptor, as described in [HS-DESC-FIRST-LAYER].

        The hidden service also avoids leaking the number of authorized clients by
        adding fake "auth-client" entries to its descriptor. Specifically,
        descriptors always contain a number of authorized clients that is a
        multiple of 16 by adding fake "auth-client" entries if needed.
        [XXX consider randomization of the value 16]

        Clients MUST accept descriptors with any number of "auth-client" lines as
        long as the total descriptor size is within the max limit of 50k (also
        controlled with a consensus parameter).

[/code]

## Second layer of encryption

The second layer of descriptor encryption is designed to protect descriptor confidentiality against unauthorized clients. If restricted discovery is enabled, it’s encrypted using the descriptor_cookie, and contains needed information for connecting to the hidden service, like the list of its introduction points.

If restricted discovery is disabled, then the second layer of HS encryption does not offer any additional security, but is still used.

### Second layer encryption keys

The encryption keys and format for the second layer of encryption are generated as specified in [HS-DESC-ENCRYPTION-KEYS] with customization parameters as follows:
[code]
         SECRET_DATA = blinded-public-key | descriptor_cookie
         STRING_CONSTANT = "hsdir-encrypted-data"

       If restricted discovery is disabled the 'descriptor_cookie' field is left blank.

       The ciphertext is placed on the "encrypted" field of the descriptor.

[/code]

### Second layer plaintext format

After decrypting the second layer ciphertext, clients can finally learn the list of intro points etc. The plaintext has the following format:

### `proto` — Declare supported subprotocol capabilities

  * **`proto`** _entry_ _entry_ ..
  * At most once
  * Syntax and semantics as for `proto` in a server descriptor.

This entry declares that the onion service supports one or more subprotocol capabilities.

Not all subprotocol capabilities should be listed here: only the ones whose presence the client may need to know in advance, as listed in the table below:

Name| Capability
---|---
RELAY_NEGOTIATE_SUBPROTO| “Relay=5”
RELAY_CRYPTO_CGO| “Relay=6”

### (unconverted items in older spec format)
[code]
    "create2-formats" SP formats NL

    \[Exactly once\]

          A space-separated list of integers denoting CREATE2 cell HTYPEs
          (handshake types) that the server recognizes. Must include at least
          ntor as described in tor-spec.txt. See tor-spec section 5.1 for a list
          of recognized handshake types.

[/code]
[code]
         "intro-auth-required" SP types NL

          [At most once]

          A space-separated list of introduction-layer authentication types; see
          section [INTRO-AUTH] for more info. A client that does not support at
          least one of these authentication types will not be able to contact the
          host. Recognized types are: 'ed25519'.

[/code]
[code]
         "single-onion-service"

          [At most once]

          If present, this line indicates that the service is a Single Onion
          Service (see prop260 for more details about that type of service). This
          field has been introduced in 0.3.0 meaning 0.2.9 service don't include
          this.

[/code]
[code]
         "pow-params" SP scheme SP seed-b64 SP suggested-effort
                      SP expiration-time NL

          [At most once per scheme]

          If present, this line provides parameters for an optional proof-of-work
          client puzzle. A client that supports an offered scheme can include a
          corresponding solution in its introduction request to improve priority
          in the service's processing queue.

          "pow-params" may appear multiple times; each occurrence must have
          a different "scheme" field. Only the scheme `v1` is currently defined.

          Unknown schemes found in a descriptor must be completely ignored:
          future schemes might have a different format (in the parts of the
          Item after the "scheme"; this could even include an Object); and
          future schemes might allow repetition, and might appear in any order.
          Implementations SHOULD ignore lines with unrecognized schemes.

          Introduced in tor-0.4.8.1-alpha.

            scheme: The PoW system used. We call the one specified here "v1".

            seed-b64: A random seed that should be used as the input to the PoW
                      hash function. Should be 32 random bytes encoded in base64
                      without trailing padding.

            suggested-effort: An unsigned integer specifying an effort value that
                      clients should aim for when contacting the service. Can be
                      zero to mean that PoW is available but not currently
                      suggested for a first connection attempt.

            expiration-time: A UTC timestamp in DateTime format ("YYYY-MM-DDTHH:MM:SS")
                      after which the above seed expires and
                      is no longer valid as the input for PoW.

                      If a client encounters an expired seed,
                      it should either fetch a new descriptor,
                      or (if the descriptor is very recent) make a connection
                      without PoW.

[/code]

Followed by zero or more introduction points as follows (see section [NUM_INTRO_POINT] below for accepted values):
[code]
            "introduction-point" SP link-specifiers NL

              [Exactly once per introduction point at start of introduction
                point section]

              The link-specifiers is a base64 encoding of a link specifier
              block in the format described in [BUILDING-BLOCKS] above.

              As of 0.4.1.1-alpha, services include both IPv4 and IPv6 link
              specifiers in descriptors. All available addresses SHOULD be
              included in the descriptor, regardless of the address that the
              onion service actually used to connect/extend to the intro
              point.

              The client SHOULD NOT reject any LSTYPE fields which it doesn't
              recognize; instead, it should use them verbatim in its EXTEND
              request to the introduction point.

              The client SHOULD perform the basic validity checks on the link
              specifiers in the descriptor, described in `tor-spec.txt`
              section 5.1.2. These checks SHOULD NOT leak
              detailed information about the client's version, configuration,
              or consensus. (See 3.3 for service link specifier handling.)

              When connecting to the introduction point, the client SHOULD send
              this list of link specifiers verbatim, in the same order as given
              here.

              The client MAY reject the list of link specifiers if it is
              inconsistent with relay information from the directory, but SHOULD
              NOT modify it.

[/code]
[code]
            "onion-key" SP "ntor" SP key NL

              [Exactly once per introduction point]

              The key is a base64 encoded curve25519 public key which is the onion
              key of the introduction point Tor node used for the ntor handshake
              when a client extends to it.

[/code]
[code]
            "onion-key" SP KeyType SP key.. NL

              [Any number of times]

              Implementations should accept other types of onion keys using this
              syntax (where "KeyType" is some string other than "ntor");
              unrecognized key types should be ignored.

[/code]
[code]
            "auth-key" NL certificate NL

              [Exactly once per introduction point]

              The certificate is a proposal 220 certificate wrapped in
              "-----BEGIN ED25519 CERT-----".  It contains the introduction
              point authentication key (`KP_hs_ipt_sid`), signed by
              the descriptor signing key (`KP_hs_desc_sign`).  The
              certificate type must be [09], and the signing key extension
              is mandatory.

              NOTE: This certificate was originally intended to be
              constructed the other way around: the signing and signed keys
              are meant to be reversed.  However, C tor implemented it
              backwards, and other implementations now need to do the same
              in order to conform.  (Since this section is inside the
              descriptor, which is _already_ signed by `KP_hs_desc_sign`,
              the verification aspect of this certificate serves no point in
              its current form.)

[/code]
[code]
            "enc-key" SP "ntor" SP key NL

              [Exactly once per introduction point]

              The key is a base64 encoded curve25519 public key used to encrypt
              the introduction request to service. (`KP_hss_ntor`)

[/code]
[code]
            "enc-key" SP KeyType SP key.. NL

              [Any number of times]

              Implementations should accept other types of onion keys using this
              syntax (where "KeyType" is some string other than "ntor");
              unrecognized key types should be ignored.

[/code]
[code]
            "enc-key-cert" NL certificate NL

              [Exactly once per introduction point]

              Cross-certification of the encryption key using the descriptor
              signing key.

              For "ntor" keys, certificate is a proposal 220 certificate
              wrapped in "-----BEGIN ED25519 CERT-----" armor.

              The subject
              key is the the ed25519 equivalent of a curve25519 public
              encryption key (`KP_hss_ntor`), with the ed25519 key
              derived using the process in proposal 228 appendix A,
              and its sign bit set to zero.

              The
              signing key is the descriptor signing key (`KP_hs_desc_sign`).
              The certificate type must be [0B], and the signing-key
              extension is mandatory.

              NOTE: As with "auth-key", this certificate was intended to be
              constructed the other way around.  However, for compatibility
              with C tor, implementations need to construct it this way.  It
              serves even less point than "auth-key", however, since the
              encryption key `KP_hss_ntor` is already available from
              the `enc-key` entry.

              ALSO NOTE: Setting the sign bit of the subject key
              to zero makes the subjected unusable for verification;
              this is also a mistake preserved for compatibility with
              C tor.

            "legacy-key" NL key NL

              [None or at most once per introduction point]
              [This field is obsolete and should never be generated; it
               is included for historical reasons only.]

              The key is an ASN.1 encoded RSA public key in PEM format used for a
              legacy introduction point as described in [LEGACY_EST_INTRO].

              This field is only present if the introduction point only supports
              legacy protocol (v2) that is <= 0.2.9 or the subprotocol value
              "HSIntro=3".

            "legacy-key-cert" NL certificate NL

              [None or at most once per introduction point]
              [This field is obsolete and should never be generated; it
               is included for historical reasons only.]

              MUST be present if "legacy-key" is present.

              The certificate is a proposal 220 RSA->Ed cross-certificate wrapped
              in "-----BEGIN CROSSCERT-----" armor, cross-certifying the RSA
              public key found in "legacy-key" using the descriptor signing key.

[/code]

To remain compatible with future revisions to the descriptor format, clients should ignore unrecognized lines in the descriptor. Other encryption and authentication key formats are allowed; clients should ignore ones they do not recognize.

Clients who manage to extract the introduction points of the hidden service can proceed with the introduction protocol as specified in [INTRO-PROTOCOL].

Compatibility note: At least some versions of OnionBalance do not include a final newline when generating this inner plaintext section; other implementations MUST accept this section even if it is missing its final newline.

## Deriving hidden service descriptor encryption keys

In this section we present the generic encryption format for hidden service descriptors. We use the same encryption format in both encryption layers, hence we introduce two customization parameters SECRET_DATA and STRING_CONSTANT which vary between the layers.

The SECRET_DATA parameter specifies the secret data that are used during encryption key generation, while STRING_CONSTANT is merely a string constant that is used as part of the KDF.

Here is the key generation logic:
[code]
           SALT = 16 bytes from SHA3_256(random), changes each time we rebuild the
                  descriptor even if the content of the descriptor hasn't changed.
                  (So that we don't leak whether the intro point list etc. changed)

           secret_input = SECRET_DATA | N_hs_subcred | INT_8(revision_counter)

           keys = SHAKE256_KDF(secret_input | salt | STRING_CONSTANT, S_KEY_LEN + S_IV_LEN + MAC_KEY_LEN)

           SECRET_KEY = first S_KEY_LEN bytes of keys
           SECRET_IV  = next S_IV_LEN bytes of keys
           MAC_KEY    = last MAC_KEY_LEN bytes of keys

       The encrypted data has the format:

           SALT       hashed random bytes from above  [16 bytes]
           ENCRYPTED  The ciphertext                  [variable]
           MAC        D_MAC of both above fields      [32 bytes]

       The final encryption format is ENCRYPTED = STREAM(SECRET_IV,SECRET_KEY) XOR Plaintext .

       Where D_MAC = SHA3_256(mac_key_len | MAC_KEY | salt_len | SALT | ENCRYPTED)
       and
        mac_key_len = htonll(len(MAC_KEY))
       and
        salt_len = htonll(len(SALT)).

[/code]

## Number of introduction points

This section defines how many introduction points an hidden service descriptor can have at minimum, by default and the maximum:

Minimum: 0 - Default: 3 - Maximum: 20

A value of 0 would means that the service is still alive but doesn’t want to be reached by any client at the moment. Note that the descriptor size increases considerably as more introduction points are added.

The reason for a maximum value of 20 is to give enough scalability to tools like OnionBalance to be able to load balance up to 120 servers (20 x 6 HSDirs) but also in order for the descriptor size to not overwhelmed hidden service directories with user defined values that could be gigantic.

## Hidden service descriptors: outer wrapper [DESC-OUTER]

The format for a hidden service descriptor is as follows, using the meta-format from dir-spec.txt.

“hs-descriptor” SP version-number NL

[At start, exactly once.]
[code]
           The version-number is a 32 bit unsigned integer indicating the version
           of the descriptor. Current version is "3".

         "descriptor-lifetime" SP LifetimeMinutes NL

           [Exactly once]

           The lifetime of a descriptor in minutes. An HSDir SHOULD expire the
           hidden service descriptor at least LifetimeMinutes after it was
           uploaded.

           The LifetimeMinutes field can take values between 30 and 720 (12
           hours).

[/code]
[code]
        "descriptor-signing-key-cert" NL certificate NL

           [Exactly once.]

           The 'certificate' field contains a certificate in the format from
           proposal 220, wrapped with "-----BEGIN ED25519 CERT-----".  The
           certificate cross-certifies the short-term descriptor signing key with
           the blinded public key.  The certificate type must be [08], and the
           blinded public key must be present as the signing-key extension.

[/code]
[code]
         "revision-counter" SP Integer NL

           [Exactly once.]

           The revision number of the descriptor. If an HSDir receives a
           second descriptor for a key that it already has a descriptor for,
           it should retain and serve the descriptor with the higher
           revision-counter.

           (Checking for monotonically increasing revision-counter values
           prevents an attacker from replacing a newer descriptor signed by
           a given key with a copy of an older version.)

           Implementations MUST be able to parse 64-bit values for these
           counters.

[/code]
[code]
         "superencrypted" NL encrypted-string

           [Exactly once.]

           An encrypted blob, whose format is discussed in [HS-DESC-ENC] below. The
           blob is base64 encoded and enclosed in -----BEGIN MESSAGE---- and
           ----END MESSAGE---- wrappers. (The resulting document does not end with
           a newline character.)

[/code]
[code]
         "signature" SP signature NL

           [exactly once, at end.]

           A signature of all previous fields, using the signing key in the
           descriptor-signing-key-cert line, prefixed by the string "Tor onion
           service descriptor sig v3". We use a separate key for signing, so that
           the hidden service host does not need to have its private blinded key
           online.

[/code]

HSDirs accept hidden service descriptors of up to 50k bytes (a consensus parameter should also be introduced to control this value).

## Generating and publishing hidden service descriptors [HSDIR]

Hidden service descriptors follow the same metaformat as other Tor directory objects. They are published anonymously to Tor servers with the HSDir flag, the HSDir=2 subprotocol, and tor version >= 0.3.0.8 (because a bug was fixed in this version).

## The introduction protocol [INTRO-PROTOCOL]

# The introduction protocol

The introduction protocol proceeds in three steps.

First, a hidden service host builds an anonymous circuit to a Tor node and registers that circuit as an introduction point.

Single Onion Services attempt to build a non-anonymous single-hop circuit, but use an anonymous 3-hop circuit if:
[code]
         * the intro point is on an address that is configured as unreachable via
           a direct connection, or
         * the initial attempt to connect to the intro point over a single-hop
           circuit fails, and they are retrying the intro point connection.

            [After 'First' and before 'Second', the hidden service publishes its
            introduction points and associated keys, and the client fetches
            them as described in section [HSDIR] above.]

[/code]

Second, a client builds an anonymous circuit to the introduction point, and sends an introduction request.

Third, the introduction point relays the introduction request along the introduction circuit to the hidden service host, and acknowledges the introduction request to the client.

## Registering an introduction point

### Extensible ESTABLISH_INTRO protocol

When a hidden service is establishing a new introduction point, it sends an ESTABLISH_INTRO message with the following contents:
[code]
         AUTH_KEY_TYPE    [1 byte]
         AUTH_KEY_LEN     [2 bytes]
         AUTH_KEY         [AUTH_KEY_LEN bytes]
         N_EXTENSIONS     [1 byte]
         N_EXTENSIONS times:
            EXT_FIELD_TYPE [1 byte]
            EXT_FIELD_LEN  [1 byte]
            EXT_FIELD      [EXT_FIELD_LEN bytes]
         HANDSHAKE_AUTH   [MAC_LEN bytes]
         SIG_LEN          [2 bytes]
         SIG              [SIG_LEN bytes]

[/code]

The AUTH_KEY_TYPE field indicates the type of the introduction point authentication key and the type of the MAC to use in HANDSHAKE_AUTH. Recognized types are:
[code]
           [00, 01] -- Reserved for legacy introduction messages; see
                       [LEGACY_EST_INTRO below]
           [02] -- Ed25519; SHA3-256.

[/code]

The AUTH_KEY_LEN field determines the length of the AUTH_KEY field. The AUTH_KEY field contains the public introduction point authentication key, KP_hs_ipt_sid.

The EXT_FIELD_TYPE, EXT_FIELD_LEN, EXT_FIELD entries are reserved for extensions to the introduction protocol. Extensions with unrecognized EXT_FIELD_TYPE values must be ignored. (`EXT_FIELD_LEN` may be zero, in which case EXT_FIELD is absent.)
[code]
       Unless otherwise specified in the documentation for an extension type:
          * Each extension type SHOULD be sent only once in a message.
          * Parties MUST ignore any occurrences all occurrences of an extension
            with a given type after the first such occurrence.
          * Extensions SHOULD be sent in numerically ascending order by type.
       (The above extension sorting and multiplicity rules are only defaults;
       they may be overridden in the descriptions of individual extensions.)

[/code]

The following extensions are currently defined:

`EXT_FIELD_TYPE`| Name
---|---
`[01]`| `DOS_PARAMS`

The HANDSHAKE_AUTH field contains the MAC of all earlier fields in the message using as its key the shared per-circuit material (“KH”) generated during the circuit extension protocol. It prevents replays of ESTABLISH_INTRO messages.

>

SIG_LEN is the length of the signature.

SIG is a signature, using AUTH_KEY, of all contents of the message, up to but not including SIG_LEN and SIG. These contents are prefixed with the string “Tor establish-intro cell v1”.

> (Note that this string is _sic_ ; it predates our efforts to distinguish cells from relay messages.)

Upon receiving an ESTABLISH_INTRO message, a Tor node first decodes the key and the signature, and checks the signature. The node must reject the ESTABLISH_INTRO message and destroy the circuit in these cases:
[code]
            * If the key type is unrecognized
            * If the key is ill-formatted
            * If the signature is incorrect
            * If the HANDSHAKE_AUTH value is incorrect

            * If the circuit is already a rendezvous circuit.
            * If the circuit is already an introduction circuit.
              [TODO: some scalability designs fail there.]
            * If the key is already in use by another circuit.

[/code]

Otherwise, the node must associate the key with the circuit, for use later in INTRODUCE1 messages.

#### Denial-of-Service defense extension (DOS_PARAMS)

The `DOS_PARAMS` extension in ESTABLISH_INTRO is used to send Denial-of-Service (DoS) parameters to the introduction point in order for it to apply them for the introduction circuit.

This is for the rate limiting DoS mitigation specifically.

The `EXT_FIELD_TYPE` value for the `DOS_PARAMS` extension is `[01]`.

The content is defined as follows:

Field| Size| Description
---|---|---
`N_PARAMS`| 1| Number of parameters
`N_PARAMS` times:| |
\- PARAM_TYPE| 1| Identifier for a parameter
\- PARAM_VALUE| 8| Integer value

Recognized values for `PARAM_TYPE` in this extension are:

`PARAM_TYPE`| Name| Min| Max
---|---|---|---
`[01]`| `DOS_INTRODUCE2_RATE_PER_SEC`| 0| 0x7fffffff
`[02]`| `DOS_INTRODUCE2_BURST_PER_SEC`| 0| 0x7fffffff

Together, these parameters configure a token bucket that determines how many INTRODUCE2 messages the introduction point may send to the service.

The `DOS_INTRODUCE2_RATE_PER_SEC` parameter defines the maximum average rate of messages;  The `DOS_INTRODUCE2_BURST_PER_SEC` parameter defines the largest allowable burst of messages (that is, the size of the token bucket).

> Technically speaking, the `BURST` parameter is misnamed in that it is not actually “per second”: only a _rate_ has an associated time.

If either of these parameters is set to 0, the defense is disabled, and the introduction point should ignore the other parameter.

If the burst is lower than the rate, the introduction point SHOULD ignore the extension.

> Using this extension extends the body of the ESTABLISH_INTRO message by 19 bytes bringing it from 134 bytes to 155 bytes.

When this extension is not _sent_ , introduction points use default settings taken from taken from the consensus parameters HiddenServiceEnableIntroDoSDefense, HiddenServiceEnableIntroDoSRatePerSec, and HiddenServiceEnableIntroDoSBurstPerSec.

This extension can only be used with relays supporting the subprotocol “HSIntro=5”.

Introduced in tor-0.4.2.1-alpha.

## Registering an introduction point on a legacy Tor node

> This section is obsolete and refers to a workaround for now-obsolete Tor relay versions. It is included for historical reasons.

Tor nodes should also support an older version of the ESTABLISH_INTRO message, first documented in rend-spec.txt. New hidden service hosts must use this format when establishing introduction points at older Tor nodes that do not support the format above in [EST_INTRO].

In this older protocol, an ESTABLISH_INTRO message contains:
[code]
            KEY_LEN        [2 bytes]
            KEY            [KEY_LEN bytes]
            HANDSHAKE_AUTH [20 bytes]
            SIG            [variable, up to end of relay message body]

       The KEY_LEN variable determines the length of the KEY field.

[/code]

The KEY field is the ASN1-encoded legacy RSA public key that was also included in the hidden service descriptor.

The HANDSHAKE_AUTH field contains the SHA1 digest of (KH | “INTRODUCE”).

The SIG field contains an RSA signature, using PKCS1 padding, of all earlier fields.

Older versions of Tor always use a 1024-bit RSA key for these introduction authentication keys.

### Acknowledging establishment of introduction point

After setting up an introduction circuit, the introduction point reports its status back to the hidden service host with an INTRO_ESTABLISHED message.

The INTRO_ESTABLISHED message has the following contents:
[code]
         N_EXTENSIONS [1 byte]
         N_EXTENSIONS times:
           EXT_FIELD_TYPE [1 byte]
           EXT_FIELD_LEN  [1 byte]
           EXT_FIELD      [EXT_FIELD_LEN bytes]

[/code]

Older versions of Tor send back an empty INTRO_ESTABLISHED message instead. Services must accept an empty INTRO_ESTABLISHED message from a legacy relay. [The above paragraph is obsolete and refers to a workaround for now-obsolete Tor relay versions. It is included for historical reasons.]

The same rules for multiplicity, ordering, and handling unknown types apply to the extension fields here as described [EST_INTRO] above.

## Sending an INTRODUCE1 message to the introduction point

In order to participate in the introduction protocol, a client must know the following:
[code]
         * An introduction point for a service.
         * The introduction authentication key for that introduction point.
         * The introduction encryption key for that introduction point.

[/code]

The client sends an INTRODUCE1 message to the introduction point, containing an identifier for the service, an identifier for the encryption key that the client intends to use, and an opaque blob to be relayed to the hidden service host.

In reply, the introduction point sends an INTRODUCE_ACK message back to the client, either informing it that its request has been delivered, or that its request will not succeed.

If the INTRODUCE_ACK message indicates success, the client SHOULD close the circuit to the introduction point, and not use it for anything else. If the INTRODUCE_ACK message indicates failure, the client MAY try a different introduction point. It MAY reach the different introduction point either by extending its introduction circuit an additional hop, or by building a new introduction circuit.
[code]
       [TODO: specify what tor should do when receiving a malformed message. Drop it?
              Kill circuit? This goes for all possible messages.]

[/code]

### Extensible INTRODUCE1 message format

When a client is connecting to an introduction point, INTRODUCE1 messages should be of the form:
[code]
         LEGACY_KEY_ID   [20 bytes]
         AUTH_KEY_TYPE   [1 byte]
         AUTH_KEY_LEN    [2 bytes]
         AUTH_KEY        [AUTH_KEY_LEN bytes]
         N_EXTENSIONS    [1 byte]
         N_EXTENSIONS times:
           EXT_FIELD_TYPE [1 byte]
           EXT_FIELD_LEN  [1 byte]
           EXT_FIELD      [EXT_FIELD_LEN bytes]
         ENCRYPTED        [Up to end of relay message body]

[/code]

The `ENCRYPTED` field is described in the [PROCESS_INTRO2] section.

AUTH_KEY_TYPE is defined as in [EST_INTRO]. Currently, the only value of AUTH_KEY_TYPE for this message is an Ed25519 public key [02].

The LEGACY_KEY_ID field is used to distinguish between legacy and new style INTRODUCE1 messages. In new style INTRODUCE1 messages, LEGACY_KEY_ID is 20 zero bytes. Upon receiving an INTRODUCE1 messages, the introduction point checks the LEGACY_KEY_ID field. If LEGACY_KEY_ID is non-zero, the INTRODUCE1 message should be handled as a legacy INTRODUCE1 message by the intro point.

Upon receiving a INTRODUCE1 message, the introduction point checks whether AUTH_KEY matches the introduction point authentication key for an active introduction circuit. It also checks whether the contents are at most 490 bytes (the size that will fit in a CGO-negotiated circuit). If so, the introduction point sends an INTRODUCE2 message with exactly the same contents to the service, and sends an INTRODUCE_ACK response to the client.

(Note that the introduction point does not “clean up” the INTRODUCE1 message that it retransmits. Specifically, it does not change the order or multiplicity of the extensions sent by the client.)

The same rules for multiplicity, ordering, and handling unknown types apply to the extension fields here as described [EST_INTRO] above.

### INTRODUCE_ACK message format.

An INTRODUCE_ACK message has the following fields:
[code]
         STATUS       [2 bytes]
         N_EXTENSIONS [1 bytes]
         N_EXTENSIONS times:
           EXT_FIELD_TYPE [1 byte]
           EXT_FIELD_LEN  [1 byte]
           EXT_FIELD      [EXT_FIELD_LEN bytes]

[/code]

Currently defined status values are:

STATUS| Name| Meaning
---|---|---
**`00 00`**|  SUCCESS| Success: message relayed to hidden service host.
**`00 01`**|  NOT_RECOGNIZED| Failure: service ID not recognized
**`00 02`**|  BAD_MESSAGE_FORMAT| Bad message format
**`00 03`**|  CANT_RELAY| Can’t relay message to service

The same rules for multiplicity, ordering, and handling unknown types apply to the extension fields here as described [EST_INTRO] above.

## Processing an INTRODUCE2 message at the hidden service.

Upon receiving an INTRODUCE2 message, the hidden service host checks whether the AUTH_KEY or LEGACY_KEY_ID field matches the keys for this introduction circuit.

The service host then checks whether it has received a message with these contents or rendezvous cookie before. If it has, it silently drops it as a replay. (It must maintain a replay cache for as long as it accepts messages with the same encryption key. Note that the encryption format below should be non-malleable. See also More notes on replay resistance below.)

If the message is not a replay, it decrypts the ENCRYPTED field, establishes a shared key with the client, and authenticates the whole contents of the message as having been unmodified since they left the client. There may be multiple ways of decrypting the ENCRYPTED field, depending on the chosen type of the encryption key. Requirements for an introduction handshake protocol are described in [INTRO-HANDSHAKE-REQS]. We specify one below in section [NTOR-WITH-EXTRA-DATA].

The decrypted plaintext must have the form:
[code]
          RENDEZVOUS_COOKIE                          [20 bytes]
          N_EXTENSIONS                               [1 byte]
          N_EXTENSIONS times:
              EXT_FIELD_TYPE                         [1 byte]
              EXT_FIELD_LEN                          [1 byte]
              EXT_FIELD                              [EXT_FIELD_LEN bytes]
          ONION_KEY_TYPE                             [1 bytes]
          ONION_KEY_LEN                              [2 bytes]
          ONION_KEY                                  [ONION_KEY_LEN bytes]
          NSPEC      (Number of link specifiers)     [1 byte]
          NSPEC times:
              LSTYPE (Link specifier type)           [1 byte]
              LSLEN  (Link specifier length)         [1 byte]
              LSPEC  (Link specifier)                [LSLEN bytes]
          PAD        (optional padding)              [up to end of plaintext]

[/code]

Upon processing this plaintext, the hidden service makes sure that any required authentication is present in the extension fields, and then extends a rendezvous circuit to the node described in the LSPEC fields, using the ONION_KEY to complete the extension. As mentioned in [BUILDING-BLOCKS], the “TLS-over-TCP, IPv4” and “Legacy node identity” specifiers must be present.

As of 0.4.1.1-alpha, clients include both IPv4 and IPv6 link specifiers in INTRODUCE1 messages. All available addresses SHOULD be included in the message, regardless of the address that the client actually used to extend to the rendezvous point.

The hidden service should handle invalid or unrecognised link specifiers the same way as clients do in section 2.5.2.2. In particular, services SHOULD perform basic validity checks on link specifiers, and SHOULD NOT reject unrecognised link specifiers, to avoid information leaks. The list of link specifiers received here SHOULD either be rejected, or sent verbatim when extending to the rendezvous point, in the same order received.

The service MAY reject the list of link specifiers if it is inconsistent with relay information from the directory, but SHOULD NOT modify it.

The ONION_KEY_TYPE field is:

[01] NTOR: ONION_KEY is 32 bytes long.

The ONION_KEY field describes the onion key that must be used when extending to the rendezvous point. It must be of a type listed as supported in the hidden service descriptor.

The PAD field should be filled with zeros; its size should be chosen so that the INTRODUCE2 message occupies a fixed maximum size, in order to hide the length of the encrypted data. (This maximum size is 490, since we assume that a future Tor implementations will implement proposal 340 and thus lower the number of bytes that can be contained in a single relay message.) Note also that current versions of Tor only pad the INTRODUCE2 message up to 246 bytes.

(See also the discussion in [FMT_INTRO1] about maximum message size: the INTRODUCE1 body SHOULD be padded up to 490 bytes, but MUST NOT be more than 490 bytes.)

Upon receiving a well-formed INTRODUCE2 message, the hidden service host will have:
[code]
         * The information needed to connect to the client's chosen
           rendezvous point.
         * The second half of a handshake to authenticate and establish a
           shared key with the hidden service client.
         * A set of shared keys to use for end-to-end encryption.

[/code]

The same rules for multiplicity, ordering, and handling unknown types apply to the extension fields here as described [EST_INTRO] above.

### More notes on replay resistance

Implementations SHOULD prevent INTRODUCE replays as well as reasonably practical. It is not, however, necessary to ensure that replays are completely impossible, so long as the opportunity for replay attacks remains limited. For example, it is not necessary to fsync() data to disk after each request.

> Rationale:
>
> The main reason we prevent INTRODUCE replays is to detect attempts by introduction points to mount replay attacks. Such attacks would cause the onion service to make a second circuit to the client’s chosen rendezvous point. If the attacker controls both the introduction point and the rendezvous point, they can use this to learn which original user circuit corresponded to the replayed request. This likely helps with traffic analysis somewhat, probably not _too_ much if it can only be done occasionally.
>
> A second reason for preventing replays is to avoid DoS attacks: a single accepted INTRODUCE message causes an onion service to perform significant work, but doesn’t cost the sender too much in CPU or bandwidth.
>
> These attacks are _relatively_ minor when only a limited number of messages can be successfully replayed, especially if the attacker can’t predict which replays will be detected. They become more problematic only when several messages can be replayed many times.

### INTRODUCE1/INTRODUCE2 Extensions

The following sections details the currently supported or reserved extensions of an `INTRODUCE1`/`INTRODUCE2` message.

Note that there are two sets of extensions in `INTRODUCE1`/`INTRODUCE2`: one in the top-level, unencrypted portion, and one within the plaintext of ENCRYPTED (ie, after RENDEZVOUS_COOKIE and before ONION_KEY_TYPE.

The sets of extensions allowed in each part of the message are disjoint: each extension is valid in only _one_ of the two places.

Nevertheless, for historical reasons, both kinds of extension are listed in this section, and they use nonoverlapping values of `EXT_FIELD_TYPE`.

Encrypted extensions are semantically equivalent to, and share a namespace with, the extensions used with circuit creation handshakes.

#### Congestion Control

This is used to request that the rendezvous circuit with the service be configured with congestion control.

EXT_FIELD_TYPE:
[code]
     \[01\] -- CC_FIELD_REQUEST.

[/code]

This extension has zero body length. Its presence signifies that the client wants to use congestion control. The client MUST NOT set this field if the service did not list “2” in the `FlowCtrl` line in the descriptor. The client SHOULD NOT provide this field if the consensus parameter ‘cc_alg’ is 0.

This extension is equivalent to the `CC_FIELD_REQUEST` extension used in circuit creation, except that no response is sent by the onion service.

This appears in the ENCRYPTED section of the INTRODUCE1/INTRODUCE2 message.

#### Proof-of-Work (PoW)

This extension can be used to optionally attach a proof of work to the introduction request. The proof must be calculated using unique parameters appropriate for this specific service. An acceptable proof will raise the priority of this introduction request according to the proof’s verified computational effort.

This is for the proof-of-work DoS mitigation, described in depth by the Proof of Work for onion service introduction specification.

This appears in the ENCRYPTED section of the INTRODUCE1/INTRODUCE2 message.

The content is defined as follows:

EXT_FIELD_TYPE:

[02] – `PROOF_OF_WORK`
[code]
    The EXT_FIELD content format is:

        POW_SCHEME     [1 byte]
        POW_NONCE      [16 bytes]
        POW_EFFORT     [4 bytes]
        POW_SEED       [4 bytes]
        POW_SOLUTION   [16 bytes]

    where:

    POW_SCHEME is 1 for the `v1` protocol specified here
    POW_NONCE is the nonce value chosen by the client's solver
    POW_EFFORT is the effort value chosen by the client,
               as a 32-bit integer in network byte order
    POW_SEED identifies which seed was in use, by its first 4 bytes
    POW_SOLUTION is a matching proof computed by the client's solver

[/code]

Only SCHEME 1, `v1`, is currently defined. Other schemes may have a different format, after the POW_SCHEME byte. A correctly functioning client only submits solutions with a scheme and seed which were advertised by the server (using a “pow-params” Item in the HS descriptor) and have not yet expired. An extension with an unknown scheme or expired seed is suspicious and SHOULD result in introduction failure.

Introduced in tor-0.4.8.1-alpha.

#### Subprotocol Request

[RESERVED]

EXT_FIELD_TYPE:
[code]
     \[03\] -- Subprotocol Request

[/code]

### Introduction handshake encryption requirements

When decoding the encrypted information in an INTRODUCE2 message, a hidden service host must be able to:
[code]
         * Decrypt additional information included in the INTRODUCE2 message,
           to include the rendezvous token and the information needed to
           extend to the rendezvous point.

         * Establish a set of shared keys for use with the client.

         * Authenticate that the message has not been modified since the client
           generated it.

[/code]

Note that the old TAP-derived protocol of the previous hidden service design achieved the first two requirements, but not the third.

### Encryption handshake: hs-ntor
[code]
    TODO: relocate this

[/code]

This is a variant of the ntor handshake (also see “Anonymity and one-way authentication in key-exchange protocols” by Goldberg, Stebila, and Ustaoglu).

It behaves the same as the ntor handshake, except that, in addition to negotiating forward secure keys, it also provides a means for encrypting non-forward-secure “additional data” to the server (in this case, to the hidden service host) as part of the handshake. This “additional data” is used to encode encrypted introduce1 extensions.

Notation here is as for the in section 5.1.4 of tor-spec.txt, which defines the ntor handshake.

The PROTOID for this variant is “tor-hs-ntor-curve25519-sha3-256-1”. We also use the following tweak values:
[code]
          t_hsenc    = PROTOID | ":hs_key_extract"
          t_hsverify = PROTOID | ":hs_verify"
          t_hsmac    = PROTOID | ":hs_mac"
          m_hsexpand = PROTOID | ":hs_key_expand"

[/code]

To make an INTRODUCE1 message, the client must know a public encryption key B for the hidden service on this introduction circuit. The client generates a single-use keypair:

x,X = KEYGEN()

and computes:
[code]
                 intro_secret_hs_input = EXP(B,x) | AUTH_KEY | X | B | PROTOID
                 info = m_hsexpand | N_hs_subcred
                 hs_keys = SHAKE256_KDF(intro_secret_hs_input | t_hsenc | info, S_KEY_LEN+MAC_LEN)
                 ENC_KEY = hs_keys[0:S_KEY_LEN]
                 MAC_KEY = hs_keys[S_KEY_LEN:S_KEY_LEN+MAC_KEY_LEN]

       and sends, as the ENCRYPTED part of the INTRODUCE1 message:

              CLIENT_PK                [PK_PUBKEY_LEN bytes]
              ENCRYPTED_DATA           [Padded to length of plaintext]
              MAC                      [MAC_LEN bytes]

[/code]

Substituting those fields into the INTRODUCE1 message body format described in [FMT_INTRO1] above, we have
[code]
                LEGACY_KEY_ID               [20 bytes]
                AUTH_KEY_TYPE               [1 byte]
                AUTH_KEY_LEN                [2 bytes]
                AUTH_KEY                    [AUTH_KEY_LEN bytes]
                N_EXTENSIONS                [1 bytes]
                N_EXTENSIONS times:
                   EXT_FIELD_TYPE           [1 byte]
                   EXT_FIELD_LEN            [1 byte]
                   EXT_FIELD                [EXT_FIELD_LEN bytes]
                ENCRYPTED:
                   CLIENT_PK                [PK_PUBKEY_LEN bytes]
                   ENCRYPTED_DATA           [Padded to length of plaintext]
                   MAC                      [MAC_LEN bytes]

[/code]

(This format is as documented in [FMT_INTRO1] above, except that here we describe how to build the ENCRYPTED portion.)

Here, the encryption key plays the role of B in the regular ntor handshake, and the AUTH_KEY field plays the role of the node ID. The CLIENT_PK field is the public key X. The ENCRYPTED_DATA field is the message plaintext, encrypted with the symmetric key ENC_KEY. The MAC field is a MAC of all of the message from the AUTH_KEY through the end of ENCRYPTED_DATA, using the MAC_KEY value as its key.

To process this format, the hidden service checks PK_VALID(CLIENT_PK) as necessary, and then computes ENC_KEY and MAC_KEY as the client did above, except using EXP(CLIENT_PK,b) in the calculation of intro_secret_hs_input. The service host then checks whether the MAC is correct. If it is invalid, it drops the message. Otherwise, it computes the plaintext by decrypting ENCRYPTED_DATA.

The hidden service host now completes the service side of the extended ntor handshake, as described in tor-spec.txt section 5.1.4, with the modified PROTOID as given above. To be explicit, the hidden service host generates a keypair of y,Y = KEYGEN(), and uses its introduction point encryption key ‘b’ to compute:
[code]
          intro_secret_hs_input = EXP(X,b) | AUTH_KEY | X | B | PROTOID
          info = m_hsexpand | N_hs_subcred
          hs_keys = SHAKE256_KDF(intro_secret_hs_input | t_hsenc | info, S_KEY_LEN+MAC_LEN)
          HS_DEC_KEY = hs_keys[0:S_KEY_LEN]
          HS_MAC_KEY = hs_keys[S_KEY_LEN:S_KEY_LEN+MAC_KEY_LEN]

          (The above are used to check the MAC and then decrypt the
          encrypted data.)

          rend_secret_hs_input = EXP(X,y) | EXP(X,b) | AUTH_KEY | B | X | Y | PROTOID
          NTOR_KEY_SEED = MAC(rend_secret_hs_input, t_hsenc)
          verify = MAC(rend_secret_hs_input, t_hsverify)
          auth_input = verify | AUTH_KEY | B | Y | X | PROTOID | "Server"
          AUTH_INPUT_MAC = MAC(auth_input, t_hsmac)

          (The above are used to finish the ntor handshake.)

       The server's handshake reply is:

           SERVER_PK   Y                         [PK_PUBKEY_LEN bytes]
           AUTH        AUTH_INPUT_MAC            [MAC_LEN bytes]

[/code]

These fields will be sent to the client in a RENDEZVOUS1 message using the HANDSHAKE_INFO element (see [JOIN_REND]).

The hidden service host now also knows the keys generated by the handshake, which it will use to encrypt and authenticate data end-to-end between the client and the server. These keys are as computed with the ntor handshake, except that instead of using AES-128 and SHA1 for this hop, we use AES-256 and SHA3-256.

## Authentication during the introduction phase.

Hidden services may restrict access only to authorized users. One mechanism to do so is the credential mechanism, where only users who know the credential for a hidden service may connect at all.

There is one defined authentication type: `ed25519`.

### Ed25519-based authentication `ed25519`

(NOTE: This section is not implemented by Tor. It is likely that we would want to change its design substantially before deploying any implementation. At the very least, we would want to bind these extensions to a single onion service, to prevent replays. We might also want to look for ways to limit the number of keys a user needs to have.)

To authenticate with an Ed25519 private key, the user must include an extension field in the encrypted part of the INTRODUCE1 message with an EXT_FIELD_TYPE type of [TBD] and the contents:
[code]
            Nonce     [16 bytes]
            Pubkey    [32 bytes]
            Signature [64 bytes]

[/code]

Nonce is a random value. Pubkey is the public key that will be used to authenticate. [TODO: should this be an identifier for the public key instead?] Signature is the signature, using Ed25519, of:
[code]
            "hidserv-userauth-ed25519"
            Nonce       (same as above)
            Pubkey      (same as above)
            AUTH_KEY    (As in the INTRODUCE1 message)

[/code]

The hidden service host checks this by seeing whether it recognizes and would accept a signature from the provided public key. If it would, then it checks whether the signature is correct. If it is, then the correct user has authenticated.

Replay prevention on the whole message is sufficient to prevent replays on the authentication.

Users SHOULD NOT use the same public key with multiple hidden services.

## Appendix A: Signature scheme with key blinding [KEYBLIND]

# Appendix A: Signature scheme with key blinding

## Key derivation overview

As described in [IMD:DIST] and [SUBCRED] above, we require a “key blinding” system that works (roughly) as follows:

There is a master keypair (sk, pk).
[code]
            Given the keypair and a nonce n, there is a derivation function
            that gives a new blinded keypair (sk_n, pk_n).  This keypair can
            be used for signing.

            Given only the public key and the nonce, there is a function
            that gives pk_n.

            Without knowing pk, it is not possible to derive pk_n; without
            knowing sk, it is not possible to derive sk_n.

            It's possible to check that a signature was made with sk_n while
            knowing only pk_n.

            Someone who sees a large number of blinded public keys and
            signatures made using those public keys can't tell which
            signatures and which blinded keys were derived from the same
            master keypair.

            You can't forge signatures.

            [TODO: Insert a more rigorous definition and better references.]

[/code]

## Tor’s key derivation scheme

We propose the following scheme for key blinding, based on Ed25519.

(This is an ECC group, so remember that scalar multiplication is the trapdoor function, and it’s defined in terms of iterated point addition. See the Ed25519 paper [Reference ED25519-REFS] for a fairly clear writeup.)

Let B be the ed25519 basepoint as found in section 5 of [ED25519-B-REF]:
[code]
          B = (15112221349535400772501151409588531511454012693041857206046113283949847762202,
               46316835694926478169428394003475163141307993866256225615783033603165251855960)

[/code]

Assume B has prime order l, so lB=0. Let a master keypair be written as (a,A), where a is the private key and A is the public key (A=aB).

To derive the key for a nonce N and an optional secret s, compute the blinding factor like this:
[code]
               h = SHA3_256(BLIND_STRING | A | s | B | N)
               BLIND_STRING = "Derive temporary signing key" | INT_1(0)
               N = "key-blind" | INT_8(period-number) | INT_8(period_length)
               B = "(1511[...]2202, 4631[...]5960)"

      then clamp the blinding factor 'h' according to the ed25519 spec:

               h[0] &= 248;
               h[31] &= 63;
               h[31] |= 64;

      and do the key derivation as follows:

          private key for the period:

               a' = h a mod l
               RH' = SHA-512(RH_BLIND_STRING | RH)[:32]
               RH_BLIND_STRING = "Derive temporary signing key hash input"

          public key for the period:

               A' = h A = (ha)B

[/code]

Generating a signature of M: given a deterministic random-looking r (see EdDSA paper), take R=rB, S=r+hash(R,A’,M)ah mod l. Send signature (R,S) and public key A’.

Verifying the signature: Check whether SB = R+hash(R,A’,M)A’.
[code]
      (If the signature is valid,
           SB = (r + hash(R,A',M)ah)B
              = rB + (hash(R,A',M)ah)B
              = R + hash(R,A',M)A' )

      This boils down to regular Ed25519 with key pair (a', A').

[/code]

See [KEYBLIND-REFS] for an extensive discussion on this scheme and possible alternatives. Also, see [KEYBLIND-PROOF] for a security proof of this scheme.

## Managing streams

## Sending BEGIN messages

In order to open a new stream to an onion service, the client sends a BEGIN message on an established rendezvous circuit.

When sending a BEGIN message to an onion service, a client should use an empty string as the target address, and not set any flags on the begin message.

> For example, to open a connection to `<some_addr>.onion` on port 443, a client would send a BEGIN message with the address:port string of `":443"`, and a `FLAGS` value of 0. The 0-values `FLAGS` would not be encoded, according to the instructions for encoding BEGIN messages.

## Receiving BEGIN messages

When a service receives a BEGIN message, it should check its port, _and ignore all other fields in the begin message_ , including its address and flags.

If a service chooses to reject a BEGIN message, it should typically destroy the circuit entirely to prevent port scanning, resource exhaustion, and other undesirable behaviors. But if it rejects the BEGIN without destroy the circuit, it should send back an `END` message with the `DONE` reason, to avoid leaking any further information.

If the service chooses to accept the BEGIN message, it should send back a CONNECTED message with an empty body.

# Protocol overview

In this section, we outline the hidden service protocol. This section omits some details in the name of simplicity; those are given more fully below, when we specify the protocol in more detail.

## View from 10,000 feet

A hidden service host prepares to offer a hidden service by choosing several Tor nodes to serve as its introduction points. It builds circuits to those nodes, and tells them to forward introduction requests to it using those circuits.

Once introduction points have been picked, the host builds a set of documents called “hidden service descriptors” (or just “descriptors” for short) and uploads them to a set of HSDir nodes. These documents list the hidden service’s current introduction points and describe how to make contact with the hidden service.

When a client wants to connect to a hidden service, it first chooses a Tor node at random to be its “rendezvous point” and builds a circuit to that rendezvous point. If the client does not have an up-to-date descriptor for the service, it contacts an appropriate HSDir and requests such a descriptor.

The client then builds an anonymous circuit to one of the hidden service’s introduction points listed in its descriptor, and gives the introduction point an introduction request to pass to the hidden service. This introduction request includes the target rendezvous point and the first part of a cryptographic handshake.

Upon receiving the introduction request, the hidden service host makes an anonymous circuit to the rendezvous point and completes the cryptographic handshake. The rendezvous point connects the two circuits, and the cryptographic handshake gives the two parties a shared key and proves to the client that it is indeed talking to the hidden service.

Once the two circuits are joined, the client can use Tor relay cells to deliver relay messages to the server: Whenever the rendezvous point receives as relay cell from one of the circuits, it transmits it to the other. (It accepts both RELAY and RELAY_EARLY cells, and retransmits them all as RELAY cells.)

The two parties use these relay messages to implement Tor’s usual application stream protocol: RELAY_BEGIN messages open streams to an external process or processes configured by the server; RELAY_DATA messages are used to communicate data on those streams, and so forth.

## In more detail: naming hidden services

A hidden service’s name is its long term master identity key. This is encoded as a hostname by encoding the entire key in Base 32, including a version byte and a checksum, and then appending the string “.onion” at the end. The result is a 56-character domain name.

(This is a change from older versions of the hidden service protocol, where we used an 80-bit truncated SHA1 hash of a 1024 bit RSA key.)

The names in this format are distinct from earlier names because of their length. An older name might look like:
[code]
            unlikelynamefora.onion
            yyhws9optuwiwsns.onion

       And a new name following this specification might look like:

            l5satjgud6gucryazcyvyvhuxhr74u6ygigiuyixe3a6ysis67ororad.onion

       Please see section [ONIONADDRESS] for the encoding specification.

[/code]

## In more detail: Access control

Access control for a hidden service is imposed at multiple points through the process above. Furthermore, there is also the option to impose additional restricted discovery access control using pre-shared secrets exchanged out-of-band between the hidden service and its clients.

> Note: “restricted discovery mode” was previously called “client authorization”

The first stage of access control happens when downloading HS descriptors. Specifically, in order to download a descriptor, clients must know which blinded signing key was used to sign it. (See the next section for more info on key blinding.)

To learn the introduction points, clients must decrypt the body of the hidden service descriptor. To do so, clients must know the _unblinded_ public key of the service, which makes the descriptor unusable by entities without that knowledge (e.g. HSDirs that don’t know the onion address).

Also, if optional restricted discovery mode is enabled, hidden service descriptors are superencrypted using each authorized user’s identity x25519 key, to further ensure that unauthorized entities cannot decrypt it.

In order to make the introduction point send a rendezvous request to the service, the client needs to use the per-introduction-point authentication key found in the hidden service descriptor.

The final level of access control happens at the server itself, which may decide to respond or not respond to the client’s request depending on the contents of the request. The protocol is extensible at this point: at a minimum, the server requires that the client demonstrate knowledge of the contents of the encrypted portion of the hidden service descriptor. If optional restricted discovery mode is enabled, the service may additionally require the client to prove knowledge of a pre-shared private key.

## In more detail: Distributing hidden service descriptors.

Periodically, hidden service descriptors become stored at different locations to prevent a single directory or small set of directories from becoming a good DoS target for removing a hidden service.

For each period, the Tor directory authorities agree upon a collaboratively generated random value. (See section 2.3 for a description of how to incorporate this value into the voting practice; generating the value is described in other proposals, including [SHAREDRANDOM-REFS].) That value, combined with hidden service directories’ public identity keys, determines each HSDir’s position in the hash ring for descriptors made in that period.

Each hidden service’s descriptors are placed into the ring in positions based on the key that was used to sign them. Note that hidden service descriptors are not signed with the services’ public keys directly. Instead, we use a key-blinding system [KEYBLIND] to create a new key-of-the-day for each hidden service. Any client that knows the hidden service’s public identity key can derive these blinded signing keys for a given period. It should be impossible to derive the blinded signing key lacking that knowledge.

This is achieved using two nonces:
[code]
        * A "credential", derived from the public identity key KP_hs_id.
          N_hs_cred.

        * A "subcredential", derived from the credential N_hs_cred
          and information which various with the current time period.
          N_hs_subcred.

[/code]

The body of each descriptor is also encrypted with a key derived from the public signing key.

To avoid a “thundering herd” problem where every service generates and uploads a new descriptor at the start of each period, each descriptor comes online at a time during the period that depends on its blinded signing key. The keys for the last period remain valid until the new keys come online.

## In more detail: Scaling to multiple hosts

This design is compatible with our current approaches for scaling hidden services. Specifically, hidden service operators can use onionbalance to achieve high availability between multiple nodes on the HSDir layer. Furthermore, operators can use proposal 255 to load balance their hidden services on the introduction layer. See [SCALING-REFS] for further discussions on this topic and alternative designs.
[code]
    1.6. In more detail: Backward compatibility with older hidden service
          protocols

[/code]

This design is incompatible with the clients, server, and hsdir node protocols from older versions of the hidden service protocol as described in rend-spec.txt. On the other hand, it is designed to enable the use of older Tor nodes as rendezvous points and introduction points.

## In more detail: Keeping crypto keys offline

In this design, a hidden service’s secret identity key may be stored offline. It’s used only to generate blinded signing keys, which are used to sign descriptor signing keys.

In order to operate a hidden service, the operator can generate in advance a number of blinded signing keys and descriptor signing keys (and their credentials; see [DESC-OUTER] and [HS-DESC-ENC] below), and their corresponding descriptor encryption keys, and export those to the hidden service hosts.

As a result, in the scenario where the Hidden Service gets compromised, the adversary can only impersonate it for a limited period of time (depending on how many signing keys were generated in advance).

It’s important to not send the private part of the blinded signing key to the Hidden Service since an attacker can derive from it the secret master identity key. The secret blinded signing key should only be used to create credentials for the descriptor signing keys.

(NOTE: although the protocol allows them, offline keys are not implemented as of 0.3.2.1-alpha.)

## In more detail: Encryption Keys And Replay Resistance

To avoid replays of an introduction request by an introduction point, a hidden service host must never accept the same request twice. Earlier versions of the hidden service design used an authenticated timestamp here, but including a view of the current time can create a problematic fingerprint. (See proposal 222 for more discussion.)

## In more detail: A menagerie of keys

[In the text below, an “encryption keypair” is roughly “a keypair you can do Diffie-Hellman with” and a “signing keypair” is roughly “a keypair you can do ECDSA with.”]

Public/private keypairs defined in this document:
[code]
          Master (hidden service) identity key -- A master signing keypair
            used as the identity for a hidden service.  This key is long
            term and not used on its own to sign anything; it is only used
            to generate blinded signing keys as described in [KEYBLIND]
            and [SUBCRED]. The public key is encoded in the ".onion"
            address according to [NAMING].
            KP_hs_id, KS_hs_id.

[/code]
[code]
          Blinded signing key -- A keypair derived from the identity key,
            used to sign descriptor signing keys. It changes periodically for
            each service. Clients who know a 'credential' consisting of the
            service's public identity key and an optional secret can derive
            the public blinded identity key for a service.  This key is used
            as an index in the DHT-like structure of the directory system
            (see [SUBCRED]).
            KP_hs_blind_id, KS_hs_blind_id.

[/code]
[code]
          Descriptor signing key -- A key used to sign hidden service
            descriptors.  This is signed by blinded signing keys. Unlike
            blinded signing keys and master identity keys, the secret part
            of this key must be stored online by hidden service hosts. The
            public part of this key is included in the unencrypted section
            of HS descriptors (see [DESC-OUTER]).
            KP_hs_desc_sign, KS_hs_desc_sign.

[/code]
[code]
          Introduction point authentication key -- A short-term signing
            keypair used to identify a hidden service's session at a given
            introduction point. The service makes a fresh keypair for each
            introduction point; these are used to sign the request that a
            hidden service host makes when establishing an introduction
            point, so that clients who know the public component of this key
            can get their introduction requests sent to the right
            service. No keypair is ever used with more than one introduction
            point. (previously called a "service key" in rend-spec.txt)
            KP_hs_ipt_sid, KS_hs_ipt_sid
            ("hidden service introduction point session id").

[/code]
[code]
          Introduction point encryption key -- A short-term encryption
            keypair used when establishing connections via an introduction
            point. Plays a role analogous to Tor nodes' onion keys. The service
            makes a fresh keypair for each introduction point.
            KP_hss_ntor, KS_hss_ntor.

[/code]
[code]
          Ephemeral descriptor encryption key -- A short-lived encryption
            keypair made by the service, and used to encrypt the inner layer
            of hidden service descriptors when restricted discovery is in
            use.
            KP_hss_desc_enc, KS_hss_desc_enc

[/code]
[code]
       Nonces defined in this document:

          N_hs_desc_enc -- a nonce used to derive keys to decrypt the inner
            encryption layer of hidden service descriptors.  This is
            sometimes also called a "descriptor cookie".

       Public/private keypairs defined elsewhere:

          Onion key -- Short-term encryption keypair (KS_ntor, KP_ntor).

          (Node) identity key (KP_relayid).

       Symmetric key-like things defined elsewhere:

          KH from circuit handshake -- An unpredictable value derived as
          part of the Tor circuit extension handshake, used to tie a request
          to a particular circuit.

[/code]

### In even more detail: Restricted discovery keys

When restricted discovery is enabled, each authorized client of a hidden service has two more asymmetric keypairs which are shared with the hidden service. An entity without those keys is not able to use the hidden service. Throughout this document, we assume that these pre-shared keys are exchanged between the hidden service and its clients in a secure out-of-band fashion.

Specifically, each authorized client possesses:

  * (NOTE: implemented as of 0.3.5.1-alpha.) An x25519 keypair used to compute decryption keys that allow the client to decrypt the hidden service descriptor. See HS-DESC-ENC. This is the client’s counterpart to `KP_hss_desc_enc`. `KP_hsc_desc_enc`, `KS_hsd_desc_enc`.

  * (NOTE: _not_ implemented) An ed25519 keypair which allows the client to compute signatures which prove to the hidden service that the client is authorized. These signatures are inserted into the INTRODUCE1 message, and without them the introduction to the hidden service cannot be completed. See INTRO-AUTH. `KP_hsc_intro_auth`, `KS_hsc_intro_auth`.

The right way to exchange these keys is to have the client generate keys and send the corresponding public keys to the hidden service out-of-band. An easier but less secure way of doing this exchange would be to have the hidden service generate the keypairs and pass the corresponding private keys to its clients. See section [RESTRICTED-DISCOVERY-MGMT] for more details on how these keys should be managed.

[TODO: Also specify stealth restricted discovery.]

# The rendezvous protocol

Before connecting to a hidden service, the client first builds a circuit to an arbitrarily chosen Tor node (known as the rendezvous point), and sends an ESTABLISH_RENDEZVOUS message. The hidden service later connects to the same node and sends a RENDEZVOUS message. Once this has occurred, the relay forwards the contents of the RENDEZVOUS message to the client, and joins the two circuits together.

Single Onion Services attempt to build a non-anonymous single-hop circuit, but use an anonymous 3-hop circuit if:
[code]
         * the rend point is on an address that is configured as unreachable via
           a direct connection, or
         * the initial attempt to connect to the rend point over a single-hop
           circuit fails, and they are retrying the rend point connection.

[/code]

## Establishing a rendezvous point

The client sends the rendezvous point a RELAY_COMMAND_ESTABLISH_RENDEZVOUS message containing a 20-byte value.

RENDEZVOUS_COOKIE [20 bytes]

Rendezvous points MUST ignore any extra bytes in an ESTABLISH_RENDEZVOUS message. (Older versions of Tor did not.)

The rendezvous cookie is an arbitrary 20-byte value, chosen randomly by the client. The client SHOULD choose a new rendezvous cookie for each new connection attempt. If the rendezvous cookie is already in use on an existing circuit, the rendezvous point should reject it and destroy the circuit.

Upon receiving an ESTABLISH_RENDEZVOUS message, the rendezvous point associates the cookie with the circuit on which it was sent. It replies to the client with an empty RENDEZVOUS_ESTABLISHED message to indicate success. Clients MUST ignore any extra bytes in a RENDEZVOUS_ESTABLISHED message.

The client MUST NOT use the circuit which sent the message for any purpose other than rendezvous with the given location-hidden service.

The client should establish a rendezvous point BEFORE trying to connect to a hidden service.

## Joining to a rendezvous point

To complete a rendezvous, the hidden service host builds a circuit to the rendezvous point and sends a RENDEZVOUS1 message containing:
[code]
           RENDEZVOUS_COOKIE          [20 bytes]
           HANDSHAKE_INFO             [variable; depends on handshake type
                                       used.]

[/code]

where RENDEZVOUS_COOKIE is the cookie suggested by the client during the introduction (see [PROCESS_INTRO2]) and HANDSHAKE_INFO is defined in [NTOR-WITH-EXTRA-DATA].

If the cookie matches the rendezvous cookie set on any not-yet-connected circuit on the rendezvous point, the rendezvous point connects the two circuits, and sends a RENDEZVOUS2 message to the client containing the HANDSHAKE_INFO field of the RENDEZVOUS1 message.

Upon receiving the RENDEZVOUS2 message, the client verifies that HANDSHAKE_INFO correctly completes a handshake. To do so, the client parses SERVER_PK from HANDSHAKE_INFO and reverses the final operations of section [NTOR-WITH-EXTRA-DATA] as shown here:
[code]
          rend_secret_hs_input = EXP(Y,x) | EXP(B,x) | AUTH_KEY | B | X | Y | PROTOID
          NTOR_KEY_SEED = MAC(rend_secret_hs_input, t_hsenc)
          verify = MAC(rend_secret_hs_input, t_hsverify)
          auth_input = verify | AUTH_KEY | B | Y | X | PROTOID | "Server"
          AUTH_INPUT_MAC = MAC(auth_input, t_hsmac)

[/code]

Finally the client verifies that the received AUTH field of HANDSHAKE_INFO is equal to the computed AUTH_INPUT_MAC.

Now both parties use the handshake output to derive shared keys for use on the circuit as specified in the section below:

### Key expansion

The hidden service and its client need to derive crypto keys from the `NTOR_KEY_SEED` part of the handshake output. To do so, they use the KDF construction as follows:
[code]
    K = KDF(NTOR_KEY_SEED | m_hsexpand,    SHA3_256_LEN *2 + S_KEY_LEN* 2)

[/code]

The first SHA3_256_LEN bytes of K form the forward digest Df; the next SHA3_256_LEN bytes form the backward digest Db; the next S_KEY_LEN bytes form Kf, and the final S_KEY_LEN bytes form Kb. Excess bytes from K are discarded.

Subsequently, the rendezvous point passes RELAY cells, unchanged, from each of the two circuits to the other. When Alice’s OP sends RELAY cells along the circuit, it authenticates with Df, and encrypts them with the Kf, then with all of the keys for the ORs in Alice’s side of the circuit; and when Alice’s OP receives RELAY cells from the circuit, it decrypts them with the keys for the ORs in Alice’s side of the circuit, then decrypts them with Kb, and checks integrity with Db. Bob’s OP does the same, with Kf and Kb interchanged.

[TODO: Should we encrypt HANDSHAKE_INFO as we did INTRODUCE2 contents? It’s not necessary, but it could be wise. Similarly, we should make it extensible.]

## Using legacy hosts as rendezvous points

[This section is obsolete and refers to a workaround for now-obsolete Tor relay versions. It is included for historical reasons.]

The behavior of ESTABLISH_RENDEZVOUS is unchanged from older versions of this protocol, except that relays should now ignore unexpected bytes at the end.

Old versions of Tor required that RENDEZVOUS message bodies be exactly 168 bytes long. All shorter rendezvous bodies should be padded to this length with random bytes, to make them difficult to distinguish from older protocols at the rendezvous point.

Relays older than 0.2.9.1 should not be used for rendezvous points by next generation onion services because they enforce too-strict length checks to RENDEZVOUS messages. Hence the “HSRend” protocol from proposal#264 should be used to select relays for rendezvous points.

## Appendix E: Reserved numbers

We reserve these certificate type values for Ed25519 certificates:
[code]
          [08] short-term descriptor signing key, signed with blinded
               public key. (Section 2.4)
          [09] intro point authentication key, cross-certifying the descriptor
               signing key. (Section 2.5)
          [0B] ed25519 key derived from the curve25519 intro point encryption key,
               cross-certifying the descriptor signing key. (Section 2.5)

          Note: The value "0A" is skipped because it's reserved for the onion key
                cross-certifying ntor identity key from proposal 228.

[/code]

## Appendix G: Managing restricted discovery data [RESTRICTED-DISCOVERY-MGMT]

# Appendix G: Managing authorized client data [RESTRICTED-DISCOVERY-MGMT]

Hidden services and clients can configure their authorized client data either using the torrc, or using the control port. This section presents a suggested scheme for configuring restricted discovery. Please see appendix [HIDSERVDIR-FORMAT] for more information about relevant hidden service files.

(NOTE: restricted discovery is implemented as of 0.3.5.1-alpha.)

G.1. Configuring restricted discovery using torrc

G.1.1. Hidden Service side configuration

> Note: “restricted discovery” is called “client authorization” in the C Tor implementation
[code]
         A hidden service that wants to enable client authorization, needs to
         populate the "authorized_clients/" directory of its HiddenServiceDir
         directory with the ".auth" files of its authorized clients.

         When Tor starts up with a configured onion service, Tor checks its
         <HiddenServiceDir>/authorized_clients/ directory for ".auth" files, and if
         any recognized and parseable such files are found, then client
         authorization becomes activated for that service.

      G.1.2. Service-side bookkeeping

         This section contains more details on how onion services should be keeping
         track of their client ".auth" files.

         For the "descriptor" authentication type, the ".auth" file MUST contain
         the x25519 public key of that client. Here is a suggested file format:

            <auth-type>:<key-type>:<base32-encoded-public-key>

         Here is an an example:

            descriptor:x25519:OM7TGIVRYMY6PFX6GAC6ATRTA5U6WW6U7A4ZNHQDI6OVL52XVV2Q

         Tor SHOULD ignore lines it does not recognize.
         Tor SHOULD ignore files that don't use the ".auth" suffix.

      G.1.3. Client side configuration

         A client who wants to register client authorization data for onion
         services needs to add the following line to their torrc to indicate the
         directory which hosts ".auth_private" files containing client-side
         credentials for onion services:

             ClientOnionAuthDir <DIR>

         The <DIR> contains a file with the suffix ".auth_private" for each onion
         service the client is authorized with. Tor should scan the directory for
         ".auth_private" files to find which onion services require client
         authorization from this client.

         For the "descriptor" auth-type, a ".auth_private" file contains the
         private x25519 key:

            <onion-address>:descriptor:x25519:<base32-encoded-privkey>

         The keypair used for client authorization is created by a third party tool
         for which the public key needs to be transferred to the service operator
         in a secure out-of-band way. The third party tool SHOULD add appropriate
         headers to the private key file to ensure that users won't accidentally
         give out their private key.

      G.2. Configuring client authorization using the control port

      G.2.1. Service side

         A hidden service also has the option to configure authorized clients
         using the control port. The idea is that hidden service operators can use
         controller utilities that manage their access control instead of using
         the filesystem to register client keys.

         Specifically, we require a new control port command ADD_ONION_CLIENT_AUTH
         which is able to register x25519/ed25519 public keys tied to a specific
         authorized client.
          [XXX figure out control port command format]

         Hidden services who use the control port interface for client auth need
         to perform their own key management.

      G.2.2. Client side

         There should also be a control port interface for clients to register
         authorization data for hidden services without having to use the
         torrc. It should allow both generation of client authorization private
         keys, and also to import client authorization data provided by a hidden
         service

         This way, Tor Browser can present "Generate client auth keys" and "Import
         client auth keys" dialogs to users when they try to visit a hidden service
         that is protected by client authorization.

         Specifically, we require two new control port commands:
                       IMPORT_ONION_CLIENT_AUTH_DATA
                       GENERATE_ONION_CLIENT_AUTH_DATA
         which import and generate client authorization data respectively.

         [XXX how does key management work here?]
         [XXX what happens when people use both the control port interface and the
              filesystem interface?]

[/code]

## Appendix F: Two methods for managing revision counters.

# Appendix F: Two methods for managing revision counters

Implementations MAY generate revision counters in any way they please, so long as they are monotonically increasing over the lifetime of each blinded public key. But to avoid fingerprinting, implementors SHOULD choose a strategy also used by other Tor implementations. Here we describe two, and additionally list some strategies that implementors should NOT use.

## F.1. Increment-on-generation

This is the simplest strategy, and the one used by Tor through at least version 0.3.4.0-alpha.

Whenever using a new blinded key, the service records the highest revision counter it has used with that key. When generating a descriptor, the service uses the smallest non-negative number higher than any number it has already used.

In other words, the revision counters under this system start fresh with each blinded key as 0, 1, 2, 3, and so on.

## F.2. Encrypted time in period

This scheme is what we recommend for situations when multiple service instances need to coordinate their revision counters, without an actual coordination mechanism.

Let T be the number of seconds that have elapsed since the start time of the SRV protocol run that corresponds to this descriptor, plus 1. (T must be at least 1.)

Let S be a per-time-period secret that all the service providers share. (C tor and arti use `S = KS_hs_blind_id`; when `KS_hs_blind_id` is not available, implementations may use `S = KS_hs_desc_sign`.)

Let K be an AES-256 key, generated as
[code]
    K = SHA3_256("rev-counter-generation" | S)

[/code]

Use `K`, and AES in counter mode with IV=0, to generate a stream of `T * 2` bytes. Consider these bytes as a sequence of T 16-bit little-endian words. Add these words.

Let the sum of these words, plus T, be the revision counter.

> (We include T in the sum so that every increment in T adds at least one to the output.)

Cryptowiki attributes roughly this scheme to G. Bebek in:

> G. Bebek. Anti-tamper database research: Inference control techniques. Technical Report EECS 433 Final Report, Case Western Reserve University, November 2002.

Although we believe it is suitable for use in this application, it is not a perfect order-preserving encryption algorithm (and all order-preserving encryption has weaknesses). Please think twice before using it for anything else.

(This scheme can be optimized pretty easily by caching the encryption of `X*1`, `X*2`, `X*3`, etc for some well chosen `X`.)

For a slow reference implementation that can generate test vectors, see `src/test/ope_ref.py` in the Tor source repository.

> ###### Note:
>
> Some onion service operators have historically relied upon the behavior of this OPE scheme to provide a kind of ersatz load-balancing: they run multiple onion services, each with the the same `KP_hs_id`. The onion services choose different introduction points, and race each other to publish their HSDescs.
>
> It’s probably better to use Onionbalance or a similar tool for this purpose. Nonetheless, onion services implemenentations MAY choose to implement this particular OPE scheme exactly in order to provide interoperability with C tor in this use case.

## F.X. Some revision-counter strategies to avoid

Though it might be tempting, implementations SHOULD NOT use the current time or the current time within the period directly as their revision counter – doing so leaks their view of the current time, which can be used to link the onion service to other services run on the same host.

Similarly, implementations SHOULD NOT let the revision counter increase forever without resetting it – doing so links the service across changes in the blinded public key.

## Appendix B: Selecting nodes [PICKNODES]

Picking introduction points Picking rendezvous points Building paths Reusing circuits

(TODO: This needs a writeup)

## Publishing shared random values [PUB-SHAREDRANDOM]

# Publishing shared random values

Our design for limiting the predictability of HSDir upload locations relies on a shared random value (SRV) that isn’t predictable in advance or too influenceable by an attacker. The authorities must run a protocol to generate such a value at least once per hsdir period. Here we describe how they publish these values; the procedure they use to generate them can change independently of the rest of this specification. For more information see [SHAREDRANDOM-REFS].

According to proposal 250, we add two new lines in consensuses:
[code]
         "shared-rand-previous-value" SP NUM_REVEALS SP VALUE NL
         "shared-rand-current-value" SP NUM_REVEALS SP VALUE NL

[/code]

## Client behavior in the absence of shared random values

If the previous or current shared random value cannot be found in a consensus, then Tor clients and services need to generate their own random value for use when choosing HSDirs.

To do so, Tor clients and services use:
[code]
    SRV = SHA3_256("shared-random-disaster" | INT_8(period_length) | INT_8(period_num))

[/code]

where period_length is the length of a time period in minutes, rounded down; period_num is calculated as specified in [TIME-PERIODS] for the wanted shared random value that could not be found originally.

## Hidden services and changing shared random values

It’s theoretically possible that the consensus shared random values will change or disappear in the middle of a time period because of directory authorities dropping offline or misbehaving.

To avoid client reachability issues in this rare event, hidden services should use the new shared random values to find the new responsible HSDirs and upload their descriptors there.

XXX How long should they upload descriptors there for?

## Appendix G: Test vectors

G.1. Test vectors for hs-ntor / NTOR-WITH-EXTRA-DATA
[code]
        Here is a set of test values for the hs-ntor handshake, called
        [NTOR-WITH-EXTRA-DATA] in this document.  They were generated by
        instrumenting Tor's code to dump the values for an INTRODUCE/RENDEZVOUS
        handshake, and then by running that code on a Chutney network.

        We assume an onion service with:

          KP_hs_ipd_sid = 34E171E4358E501BFF21ED907E96AC6B
                          FEF697C779D040BBAF49ACC30FC5D21F
          KP_hss_ntor   = 8E5127A40E83AABF6493E41F142B6EE3
                          604B85A3961CD7E38D247239AFF71979
          KS_hss_ntor   = A0ED5DBF94EEB2EDB3B514E4CF6ABFF6
                          022051CC5F103391F1970A3FCD15296A
          N_hs_subcred  = 0085D26A9DEBA252263BF0231AEAC59B
                          17CA11BAD8A218238AD6487CBAD68B57

        The client wants to make in INTRODUCE request.  It generates
        the following header (everything before the ENCRYPTED portion)
        of its INTRODUCE1 message:

          H = 000000000000000000000000000000000000000002002034E171E4358E501BFF
              21ED907E96AC6BFEF697C779D040BBAF49ACC30FC5D21F00

        It generates the following plaintext body to encrypt.  (This
        is the "decrypted plaintext body" from [PROCESS_INTRO2].

          P = 6BD364C12638DD5C3BE23D76ACA05B04E6CE932C0101000100200DE6130E4FCA
              C4EDDA24E21220CC3EADAE403EF6B7D11C8273AC71908DE565450300067F0000
              0113890214F823C4F8CC085C792E0AEE0283FE00AD7520B37D0320728D5DF39B
              7B7077A0118A900FF4456C382F0041300ACF9C58E51C392795EF870000000000
              0000000000000000000000000000000000000000000000000000000000000000
              000000000000000000000000000000000000000000000000000000000000

          (Note! This should in fact be padded to be longer; when these
          test vectors were generated, the target INTRODUCE1 length in C
          Tor was needlessly short.)

        The client now begins the hs-ntor handshake.  It generates
        a curve25519 keypair:

          x = 60B4D6BF5234DCF87A4E9D7487BDF3F4
              A69B6729835E825CA29089CFDDA1E341
          X = BF04348B46D09AED726F1D66C618FDEA
              1DE58E8CB8B89738D7356A0C59111D5D

        Then it calculates:

          ENC_KEY = 9B8917BA3D05F3130DACCE5300C3DC27
                    F6D012912F1C733036F822D0ED238706
          MAC_KEY = FC4058DA59D4DF61E7B40985D122F502
                    FD59336BC21C30CAF5E7F0D4A2C38FD5

        With these, it encrypts the plaintext body P with ENC_KEY, getting
        an encrypted value C.  It computes MAC(MAC_KEY, H | X | C),
        getting a MAC value M.  It then assembles the final INTRODUCE1
        body as H | X | C | M:

          000000000000000000000000000000000000000002002034E171E4358E501BFF
          21ED907E96AC6BFEF697C779D040BBAF49ACC30FC5D21F00BF04348B46D09AED
          726F1D66C618FDEA1DE58E8CB8B89738D7356A0C59111D5DADBECCCB38E37830
          4DCC179D3D9E437B452AF5702CED2CCFEC085BC02C4C175FA446525C1B9D5530
          563C362FDFFB802DAB8CD9EBC7A5EE17DA62E37DEEB0EB187FBB48C63298B0E8
          3F391B7566F42ADC97C46BA7588278273A44CE96BC68FFDAE31EF5F0913B9A9C
          7E0F173DBC0BDDCD4ACB4C4600980A7DDD9EAEC6E7F3FA3FC37CD95E5B8BFB3E
          35717012B78B4930569F895CB349A07538E42309C993223AEA77EF8AEA64F25D
          DEE97DA623F1AEC0A47F150002150455845C385E5606E41A9A199E7111D54EF2
          D1A51B7554D8B3692D85AC587FB9E69DF990EFB776D8

[/code]

Later the service receives that body in an INTRODUCE2 message. It processes it according to the hs-ntor handshake, and recovers the client’s plaintext P. To continue the hs-ntor handshake, the service chooses a curve25519 keypair:
[code]
          y = 68CB5188CA0CD7924250404FAB54EE13
              92D3D2B9C049A2E446513875952F8F55
          Y = 8FBE0DB4D4A9C7FF46701E3E0EE7FD05
              CD28BE4F302460ADDEEC9E93354EE700

       From this and the client's input, it computes:

          AUTH_INPUT_MAC = 4A92E8437B8424D5E5EC279245D5C72B
                           25A0327ACF6DAF902079FCB643D8B208
          NTOR_KEY_SEED  = 4D0C72FE8AFF35559D95ECC18EB5A368
                           83402B28CDFD48C8A530A5A3D7D578DB

[/code]

The service sends back Y | AUTH_INPUT_MAC in its RENDEZVOUS1 message body. From these, the client finishes the handshake, validates AUTH_INPUT_MAC, and computes the same NTOR_KEY_SEED.

Now that both parties have the same NTOR_KEY_SEED, they can derive the shared key material they will use for their circuit.

## Appendix C: Recommendations for searching for vanity .onions [VANITY]

EDITORIAL NOTE: The author thinks that it’s silly to brute-force the keyspace for a key that, when base-32 encoded, spells out the name of your website. It also feels a bit dangerous to me. If you train your users to connect to

llamanymityx4fi3l6x2gyzmtmgxjyqyorj9qsb5r543izcwymle.onion

I worry that you’re making it easier for somebody to trick them into connecting to

llamanymityb4sqi0ta0tsw6uovyhwlezkcrmczeuzdvfauuemle.onion

Nevertheless, people are probably going to try to do this, so here’s a decent algorithm to use.

To search for a public key with some criterion X:

Generate a random (sk,pk) pair.

While pk does not satisfy X:
[code]
                Add the number 8 to sk
                Add the point 8*B to pk

            Return sk, pk.

[/code]

We add 8 and 8*B, rather than 1 and B, so that sk is always a valid Curve25519 private key, with the lowest 3 bits equal to 0.

This algorithm is safe [source: djb, personal communication] [TODO: Make sure I understood correctly!] so long as only the final (sk,pk) pair is used, and all previous values are discarded.

To parallelize this algorithm, start with an independent (sk,pk) pair generated for each independent thread, and let each search proceed independently.

See [VANITY-REFS] for a reference implementation of this vanity .onion search scheme.

---

; EdgeRun Tor client constants — x86_64 assembly
; Tor protocol constants, cell layouts, state enums.

; ==================================================================
; Tor cell types (command values)
; ==================================================================
TOR_CELL_PADDING     equ 0
TOR_CELL_CREATE      equ 1
TOR_CELL_CREATED     equ 2
TOR_CELL_RELAY       equ 3
TOR_CELL_DESTROY     equ 4
TOR_CELL_CREATE_FAST equ 5
TOR_CELL_CREATED_FAST equ 6
TOR_CELL_VERSIONS    equ 7
TOR_CELL_NETINFO     equ 8
TOR_CELL_RELAY_EARLY equ 9
TOR_CELL_CREATE2     equ 10
TOR_CELL_CREATED2    equ 11
TOR_CELL_VPADDING    equ 128
TOR_CELL_CERTS       equ 129
TOR_CELL_AUTH_CHALLENGE equ 130
TOR_CELL_AUTHENTICATE   equ 131
TOR_CELL_RESOLVE     equ 132
TOR_CELL_RESOLVED    equ 133

; ==================================================================
; Cell sizes
; ==================================================================
TOR_CELL_LEN         equ 514   ; fixed-length cell for link protocol v4+: 4 + 1 + 509
TOR_CELL_HEADER_LEN  equ 5     ; circ_id(2) + cmd(1) + payload(1+...)
TOR_CELL_PAYLOAD_LEN equ 509   ; fixed cell payload
TOR_VERSIONS_HEADER  equ 5     ; initial VERSIONS uses v=0: circ_id(2)+cmd(1)+len(2)
TOR_CELL_VAR_HEADER  equ 7     ; var cell: circ_id(4) + cmd(1) + len(2)
TOR_CELL_VAR_MAX     equ 65535 ; max variable cell payload
TOR_VAR_HEADER       equ TOR_CELL_VAR_HEADER  ; alias for convenience

; For modern Tor (v4+): circuit IDs are 4 bytes
TOR_CIRC_ID_LEN_V3  equ 2
TOR_CIRC_ID_LEN_V4  equ 4

; ==================================================================
; Link protocol versions
; ==================================================================
TOR_LINK_V3  equ 3
TOR_LINK_V4  equ 4
TOR_LINK_V5  equ 5

; ==================================================================
; Cell field offsets (fixed-length cell, v4 style = 4-byte circ_id)
; ==================================================================
TOR_CELL_CIRC_ID    equ 0  ; 4 bytes
TOR_CELL_CMD        equ 4  ; 1 byte
TOR_CELL_PAYLOAD    equ 5  ; 509 bytes

; Variable-length cell
TOR_VAR_CIRC_ID     equ 0  ; 4 bytes
TOR_VAR_CMD         equ 4  ; 1 byte
TOR_VAR_LEN         equ 5  ; 2 bytes (big-endian)
TOR_VAR_PAYLOAD     equ 7

; ==================================================================
; Relay cell sub-commands (inside RELAY cell payload)
; ==================================================================
TOR_RELAY_BEGIN     equ 1
TOR_RELAY_DATA      equ 2
TOR_RELAY_END       equ 3
TOR_RELAY_CONNECTED equ 4
TOR_RELAY_SENDME    equ 5
TOR_RELAY_EXTEND    equ 6
TOR_RELAY_EXTENDED  equ 7
TOR_RELAY_TRUNCATE  equ 8
TOR_RELAY_TRUNCATED equ 9
TOR_RELAY_DROP      equ 10
TOR_RELAY_RESOLVE   equ 11
TOR_RELAY_RESOLVED  equ 12
TOR_RELAY_BEGIN_DIR equ 13
TOR_RELAY_EXTEND2   equ 14
TOR_RELAY_EXTENDED2 equ 15
TOR_RELAY_ESTABLISH_INTRO equ 32
TOR_RELAY_ESTABLISH_RENDEZVOUS equ 33
TOR_RELAY_INTRODUCE1 equ 34
TOR_RELAY_INTRODUCE2 equ 35
TOR_RELAY_RENDEZVOUS1 equ 36
TOR_RELAY_RENDEZVOUS2 equ 37
TOR_RELAY_INTRO_ESTABLISHED equ 38
TOR_RELAY_RENDEZVOUS_ESTABLISHED equ 39
TOR_RELAY_INTRODUCE_ACK equ 40

; Relay cell header inside payload (11 bytes)
TOR_RELAY_CMD         equ 0  ; 1 byte
TOR_RELAY_RECOGNIZED  equ 1  ; 2 bytes, zero when recognized
TOR_RELAY_STREAM_ID   equ 3  ; 2 bytes
TOR_RELAY_DIGEST      equ 5  ; 4 bytes (old SHA1, now truncated)
TOR_RELAY_LEN         equ 9  ; 2 bytes (big-endian)
TOR_RELAY_DATA_OFFSET equ 11 ; relay payload starts here

; Onion service message sizes
TOR_HS_RENDEZVOUS_COOKIE_LEN equ 20
TOR_HS_RELAY_DATA_MAX        equ TOR_CELL_PAYLOAD_LEN - 11
TOR_HS_AUTH_KEY_TYPE_ED25519 equ 2
TOR_HS_ONION_KEY_TYPE_NTOR   equ 1
TOR_HS_ONION_KEY_LEN_NTOR    equ 32
TOR_HS_CLIENT_PK_LEN         equ 32
TOR_HS_INTRODUCE1_MAC_LEN    equ 32
TOR_HS_SUBCRED_LEN           equ 32
TOR_HS_INTRODUCE1_PREFIX_LEN equ 56
TOR_HS_INTRODUCE1_PLAINTEXT_BASE_LEN equ 57
TOR_HS_INTRODUCE1_MAX_LEN    equ 490
TOR_HS_INTRODUCE1_ENCRYPTED_FIELD_MAX equ TOR_HS_INTRODUCE1_MAX_LEN - TOR_HS_INTRODUCE1_PREFIX_LEN
TOR_HS_INTRODUCE1_ENCRYPTED_DATA_MAX equ TOR_HS_INTRODUCE1_ENCRYPTED_FIELD_MAX - TOR_HS_CLIENT_PK_LEN - TOR_HS_INTRODUCE1_MAC_LEN
TOR_HS_NTOR_PROTOID_LEN      equ 33
TOR_HS_NTOR_T_HSENC_LEN      equ 48
TOR_HS_NTOR_T_HSMAC_LEN      equ 40
TOR_HS_NTOR_M_HSEXPAND_LEN   equ 47
TOR_HS_INTRO_SECRET_LEN      equ TOR_CURVE25519_KEY_LEN + TOR_HS_INTRO_AUTH_KEY_LEN + TOR_HS_CLIENT_PK_LEN + TOR_HS_ONION_KEY_LEN_NTOR + TOR_HS_NTOR_PROTOID_LEN
TOR_HS_INTRO_KDF_INPUT_LEN   equ TOR_HS_INTRO_SECRET_LEN + TOR_HS_NTOR_T_HSENC_LEN + TOR_HS_NTOR_M_HSEXPAND_LEN + TOR_HS_SUBCRED_LEN
TOR_HS_INTRO_KEY_MATERIAL_LEN equ 64
TOR_HS_INTRO_AUTH_KEY_LEN    equ 32
TOR_HS_INTRO_HANDSHAKE_AUTH_LEN equ 32
TOR_HS_ED25519_SIG_LEN       equ 64
TOR_HS_ESTABLISH_INTRO_BASE_LEN equ 70
TOR_HS_ENCAP_LEN             equ 8
TOR_HS_MAC_KEY_LEN           equ 32
TOR_HS_CRYPTO_BUF_MAX        equ 1024
TOR_HS_DESCRIPTOR_MAX_LEN    equ 50000
TOR_HS_DESCRIPTOR_SALT_LEN   equ 16
TOR_HS_DESCRIPTOR_KEY_LEN    equ 32
TOR_HS_DESCRIPTOR_IV_LEN     equ 16
TOR_HS_DESCRIPTOR_MAC_LEN    equ 32
TOR_HS_DESCRIPTOR_ENC_OVERHEAD equ TOR_HS_DESCRIPTOR_SALT_LEN + TOR_HS_DESCRIPTOR_MAC_LEN
TOR_HS_INTRO_ACK_OK          equ 0
TOR_HS_INTRO_ACK_NOT_RECOGNIZED equ 1
TOR_HS_INTRO_ACK_BAD_MESSAGE equ 2
TOR_HS_INTRO_ACK_CANT_RELAY  equ 3

; ==================================================================
; ntor protocol constants
; ==================================================================
; Curve25519 key sizes
TOR_CURVE25519_KEY_LEN equ 32

; ntor handshake data sizes
TOR_NTOR_ID_LEN      equ 20  ; SHA1 hash of TLS certificate / identity fingerprint
TOR_NTOR_T_LEN       equ 32  ; T_KEY = 32 bytes for MAC key
TOR_NTOR_MAC_LEN     equ 32  ; HMAC-SHA256 output length

; ntor protocol string constants (used in KDF)
TOR_NTOR_PROTOID     equ "ntor-curve25519-sha256-1"
TOR_NTOR_PROTOID_LEN equ 24
TOR_NTOR_M_EXPAND    equ "expand"
TOR_NTOR_M_EXPAND_LEN equ 6
TOR_NTOR_T_MAC       equ "t_mac"
TOR_NTOR_T_MAC_LEN   equ 5
TOR_NTOR_T_KEY       equ "t_key"
TOR_NTOR_T_KEY_LEN   equ 5
TOR_NTOR_M_KEY_VERIFY equ "key_verify"
TOR_NTOR_M_KEY_VERIFY_LEN equ 10

; ==================================================================
; Circuit state machine
; ==================================================================
TOR_CIRC_CLOSED          equ 0
TOR_CIRC_OPENING         equ 1  ; CREATE2 sent, waiting CREATED2
TOR_CIRC_OPEN            equ 2  ; circuit ready
TOR_CIRC_EXTENDING       equ 3  ; EXTEND2 sent, waiting EXTENDED2
TOR_CIRC_CLOSING         equ 4

; ==================================================================
; Stream state machine
; ==================================================================
TOR_STREAM_CLOSED        equ 0
TOR_STREAM_RESOLVING     equ 1
TOR_STREAM_CONNECTING    equ 2  ; RELAY_BEGIN sent, waiting RELAY_CONNECTED
TOR_STREAM_OPEN          equ 3
TOR_STREAM_CLOSING       equ 4

; ==================================================================
; Relayed stream end reasons
; ==================================================================
TOR_END_REASON_DONE         equ 1
TOR_END_REASON_CONNECTREFUSED equ 2
TOR_END_REASON_CONNRESET    equ 3
TOR_END_REASON_TIMEOUT      equ 4
TOR_END_REASON_EXITPOLICY   equ 5
TOR_END_REASON_DESTROY      equ 6
TOR_END_REASON_RESOLVEFAILED equ 7
TOR_END_REASON_MISC         equ 8

; ==================================================================
; CERTS cell cert types
; ==================================================================
TOR_CERTTYPE_RS1024     equ 1  ; obsolete
TOR_CERTTYPE_AUTH_1024  equ 2  ; RSA 1024
TOR_CERTTYPE_ID_1024    equ 3  ; RSA identity fingerprint
TOR_CERTTYPE_ED25519_ID equ 4  ; Ed25519 signing key
TOR_CERTTYPE_ED25519_AUTH equ 5  ; Ed25519 authentication key
TOR_CERTTYPE_RSA_ID_ED25519_AUTH equ 6  ; RSA identity cross-cert with Ed25519

; ==================================================================
; AUTHENTICATE cell types
; ==================================================================
TOR_AUTHTYPE_SAFE       equ 1  ; RSA-SHA256
TOR_AUTHTYPE_ED         equ 3  ; Ed25519-SHA256
TOR_AUTHTYPE_RSA_ED     equ 4  ; RSA + Ed25519
TOR_AUTHTYPE_ANON       equ 5  ; Anonymous (no auth)

; ==================================================================
; Error codes
; ==================================================================
ERROR_TOR_LINK_FAILED      equ 40
ERROR_TOR_AUTH_FAILED      equ 41
ERROR_TOR_CIRC_BUILD_FAIL  equ 42
ERROR_TOR_STREAM_FAIL      equ 43
ERROR_TOR_PROTOCOL_ERR     equ 44
ERROR_TOR_TIMEOUT          equ 45
ERROR_TOR_ROLE_INVALID     equ 46
ERROR_TOR_ROLE_UNSUPPORTED equ 47

; ==================================================================
; Fixed Tor network constants
; ==================================================================
TOR_DEFAULT_PORT         equ 9001  ; default OR port
TOR_DIR_PORT             equ 9030  ; directory port
TOR_RECV_BUF_SIZE        equ 65536
TOR_MAX_CIRCUITS         equ 4
TOR_MAX_STREAMS          equ 8
TOR_MAX_RELAYS           equ 8     ; max hops in a circuit
TOR_TCP_ESTABLISH_POLLS  equ 65536

; ==================================================================
; Circuit data structure (per-circuit)
; ==================================================================
; Size: one circuit entry
TOR_CIRC_STATE         equ 0   ; u32
TOR_CIRC_CONN_ID       equ 4   ; u32 (TCP connection id to guard)
TOR_CIRC_N_HOPS        equ 8   ; u32 (hops established)
TOR_CIRC_RX_BUF_LEN    equ 12  ; u32
TOR_CIRC_RX_BUF        equ 16  ; 65536 bytes receive buffer
TOR_CIRC_FORWARD_KEY   equ 65552 ; 16 bytes AES forward key (encrypt going out)
TOR_CIRC_FORWARD_IV    equ 65568 ; 16 bytes AES forward IV
TOR_CIRC_BACKWARD_KEY  equ 65584 ; 16 bytes AES backward key
TOR_CIRC_BACKWARD_IV   equ 65600 ; 16 bytes AES backward IV
TOR_CIRC_FORWARD_DIGEST equ 65616 ; 32 bytes running forward digest state
TOR_CIRC_BACKWARD_DIGEST equ 65648 ; 32 bytes running backward digest state
TOR_CIRC_NTOR_KEYS     equ 65680 ; ntor key material (repeated for each hop)
TOR_CIRC_SIZE          equ 66208 ; total per-circuit with four hop key slots
TOR_CIRC_MAX_HOPS      equ 4     ; fits in TOR_CIRC_NTOR_KEYS slack
TOR_CIRC_HOP_FWD_KEY   equ 0     ; 16 bytes
TOR_CIRC_HOP_BWD_KEY   equ 16    ; 16 bytes
TOR_CIRC_HOP_FWD_IV    equ 32    ; 16 bytes
TOR_CIRC_HOP_BWD_IV    equ 48    ; 16 bytes
TOR_CIRC_HOP_FWD_DIGEST equ 64   ; 32 bytes
TOR_CIRC_HOP_BWD_DIGEST equ 96   ; 32 bytes
TOR_CIRC_HOP_SIZE      equ 128

; ==================================================================
; Stream data structure (per-stream)
; ==================================================================
TOR_STREAM_STATE      equ 0   ; u32
TOR_STREAM_CIRC_ID    equ 4   ; u32 circuit id
TOR_STREAM_ID         equ 8   ; u16 stream ID (assigned by us)
TOR_STREAM_DST_IP     equ 10  ; u32 destination IP (network order)
TOR_STREAM_DST_PORT   equ 14  ; u16 destination port
TOR_STREAM_RX_LEN     equ 16  ; u32
TOR_STREAM_RX_BUF     equ 20  ; 4096 bytes
TOR_STREAM_SIZE       equ 4116

; ==================================================================
; Tor client state structure
; ==================================================================
TOR_STATE_LINK_ESTABLISHED equ 0  ; u32
TOR_STATE_LINK_VERSION     equ 4  ; u32
TOR_STATE_GUARD_IP         equ 8  ; u32 relay guard IP
TOR_STATE_GUARD_PORT       equ 12 ; u16
TOR_STATE_GUARD_FINGERPRINT equ 14 ; 20 bytes (identity digest)
TOR_STATE_N_CIRCUITS       equ 34 ; u32
TOR_STATE_ROLE             equ 38 ; u32
TOR_STATE_ROLE_CAPS        equ 42 ; u32 bitmask
TOR_STATE_SIZE             equ 46

; ==================================================================
; Tor role model
; ==================================================================
TOR_ROLE_CLIENT            equ 0
TOR_ROLE_GUARD             equ 1
TOR_ROLE_MIDDLE            equ 2
TOR_ROLE_EXIT              equ 3
TOR_ROLE_DIRECTORY         equ 4
TOR_ROLE_BRIDGE            equ 5
TOR_ROLE_HS_SERVICE        equ 6
TOR_ROLE_HS_INTRO          equ 7
TOR_ROLE_HS_RENDEZVOUS     equ 8
TOR_ROLE_HS_PEER           equ 9
TOR_ROLE_HS_FULL           equ 10

; Capabilities bitset for TOR_STATE_ROLE_CAPS
TOR_CAP_CLIENT             equ 0x0001
TOR_CAP_OR_RELAY           equ 0x0002
TOR_CAP_EXIT               equ 0x0004
TOR_CAP_DIRECTORY          equ 0x0008
TOR_CAP_BRIDGE             equ 0x0010
TOR_CAP_HS_SERVICE         equ 0x0020
TOR_CAP_HS_INTRO           equ 0x0040
TOR_CAP_HS_RENDEZVOUS      equ 0x0080
TOR_CAP_HS_PEER            equ TOR_CAP_CLIENT | TOR_CAP_HS_SERVICE
TOR_CAP_HS_FULL            equ TOR_CAP_CLIENT | TOR_CAP_OR_RELAY | TOR_CAP_HS_SERVICE | TOR_CAP_HS_INTRO | TOR_CAP_HS_RENDEZVOUS
TOR_CAP_KNOWN_MASK         equ TOR_CAP_CLIENT | TOR_CAP_OR_RELAY | TOR_CAP_EXIT | TOR_CAP_DIRECTORY | TOR_CAP_BRIDGE | TOR_CAP_HS_SERVICE | TOR_CAP_HS_INTRO | TOR_CAP_HS_RENDEZVOUS

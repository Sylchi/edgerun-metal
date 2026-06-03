; object_constants.inc — EdgeRun Object serialization format constants
; Ported from edgerun-zig/src/object.zig

; ==================================================================
; Sizes
; ==================================================================
OBJECT_ID_SIZE                  equ 32
OBJECT_HEADER_SIZE              equ 148
OBJECT_REQUIREMENTS_SIZE        equ 28
OBJECT_OWNER_SIZE               equ 36
OBJECT_ENVELOPE_SIZE            equ 76
OBJECT_CHILD_SIZE               equ 84
OBJECT_HEADER_RESERVED_START    equ 132
OBJECT_HEADER_RESERVED_SIZE     equ 16
OBJECT_MAX_OWNERS               equ 16
OBJECT_MAX_ENVELOPES            equ 16
OBJECT_MAX_CHILDREN             equ 65536
OBJECT_SIGNATURE_FIXED_SIZE     equ 112
OBJECT_SIGNATURE_MAX_SIZE       equ 128

; ObjectView decoded layout
OBJECT_VIEW_BODY_PTR            equ 0
OBJECT_VIEW_BODY_LEN            equ 8
OBJECT_VIEW_HEADER              equ 16
OBJECT_VIEW_SIZE                equ OBJECT_VIEW_HEADER + HEADER_STRUCT_SIZE

; ==================================================================
; Magic strings (as little-endian qwords for immediate comparison)
; =================================================================
OBJECT_MAGIC_QWORD              equ 0x3130304a424f5245  ; "EROBJ001"
OBJECT_SIGNATURE_MAGIC_QWORD    equ 0x3130304749535245  ; "ERSIG001"

; ==================================================================
; Error codes (returned in rdx)
; ==================================================================
OBJECT_ERR_OK                   equ 0
OBJECT_ERR_BAD_ARGUMENT         equ 1
OBJECT_ERR_NO_SPACE             equ 2
OBJECT_ERR_CORRUPT              equ 3
OBJECT_ERR_UNSUPPORTED          equ 4

; ==================================================================
; Kind enum (u16)
; ==================================================================
OBJECT_KIND_BYTES               equ 1
OBJECT_KIND_TREE                equ 2
OBJECT_KIND_RECEIPT             equ 4
OBJECT_KIND_CODE                equ 8
OBJECT_KIND_ISA                 equ 16

; ==================================================================
; Canonical instruction-set body records
; ==================================================================
ISA_BODY_MAGIC_QWORD            equ 0x3130304153495245  ; "ERISA001"
ISA_BODY_VERSION                equ 1
ISA_ID_X86_64                   equ 1
ISA_ID_X86_32                   equ 2
ISA_ID_AARCH64                  equ 3
ISA_ID_ARM32                    equ 4
ISA_ID_WASM                     equ 5

ISA_BODY_OF_MAGIC               equ 0   ; 8 bytes
ISA_BODY_OF_VERSION             equ 8   ; u16
ISA_BODY_OF_ISA                 equ 10  ; u16
ISA_BODY_OF_DEF_COUNT           equ 12  ; u32
ISA_BODY_HEADER_SIZE            equ 16

ISA_DEF_OF_INSTRUCTION_ID       equ 0   ; u32
ISA_DEF_OF_MNEMONIC_ID          equ 4   ; u16
ISA_DEF_OF_OPERAND_SHAPE        equ 6   ; u16
ISA_DEF_OF_ENCODING_SHAPE       equ 8   ; u16
ISA_DEF_OF_FLAGS                equ 10  ; u16
ISA_DEF_OF_INPUT_COUNT          equ 12  ; u8
ISA_DEF_OF_OUTPUT_COUNT         equ 13  ; u8
ISA_DEF_OF_IMPLICIT_COUNT       equ 14  ; u8
ISA_DEF_OF_RESERVED             equ 15  ; u8
ISA_DEF_SIZE                    equ 16

ISA_MNEMONIC_MOV                equ 1
ISA_MNEMONIC_RET                equ 2
ISA_MNEMONIC_NOP                equ 3
ISA_MNEMONIC_B                  equ 4
ISA_MNEMONIC_END                equ 5
ISA_OPERAND_SHAPE_NONE          equ 1
ISA_OPERAND_SHAPE_REG_IMM32     equ 2
ISA_ENCODING_X86_MOV_EAX_IMM32  equ 1
ISA_ENCODING_X86_RET_NEAR       equ 2
ISA_ENCODING_X86_NOP            equ 3
ISA_ENCODING_A64_RET            equ 101
ISA_ENCODING_A64_NOP            equ 102
ISA_ENCODING_ARM32_BX_LR        equ 201
ISA_ENCODING_ARM32_NOP          equ 202
ISA_ENCODING_WASM_END           equ 301
ISA_ENCODING_WASM_NOP           equ 302
ISA_INSTR_X86_MOV_EAX_IMM32     equ 1
ISA_INSTR_X86_RET               equ 2
ISA_INSTR_X86_NOP               equ 3
ISA_INSTR_A64_RET               equ 1
ISA_INSTR_A64_NOP               equ 2
ISA_INSTR_ARM32_BX_LR           equ 1
ISA_INSTR_ARM32_NOP             equ 2
ISA_INSTR_WASM_END              equ 1
ISA_INSTR_WASM_NOP              equ 2

; ==================================================================
; Canonical code body records
; ==================================================================
CODE_BODY_MAGIC_QWORD           equ 0x313045444f435245  ; "ERCODE01"
CODE_RECEIPT_MAGIC_QWORD        equ 0x313054414d435245  ; "ERCMAT01"
CODE_BODY_VERSION               equ 1
CODE_ISA_X86_64                 equ ISA_ID_X86_64

CODE_BODY_OF_MAGIC              equ 0   ; 8 bytes
CODE_BODY_OF_VERSION            equ 8   ; u16
CODE_BODY_OF_ISA                equ 10  ; u16
CODE_BODY_OF_RECORD_COUNT       equ 12  ; u32
CODE_BODY_HEADER_SIZE           equ 16

CODE_RECORD_OF_KIND             equ 0   ; u16
CODE_RECORD_OF_OPCODE           equ 2   ; u16
CODE_RECORD_OF_FLAGS            equ 4   ; u32
CODE_RECORD_OF_IMM64            equ 8   ; u64
CODE_RECORD_SIZE                equ 16

CODE_RECORD_KIND_INSTR          equ 1
CODE_RECORD_KIND_EXPORT         equ 2
CODE_RECORD_KIND_IMPORT         equ 3
CODE_OP_X86_MOV_EAX_IMM32       equ 1
CODE_OP_X86_RET                 equ 2

CODE_RECEIPT_OF_MAGIC           equ 0   ; 8 bytes
CODE_RECEIPT_OF_RECORD_COUNT    equ 8   ; u64
CODE_RECEIPT_OF_OUTPUT_LEN      equ 16  ; u64
CODE_RECEIPT_OF_ISA             equ 24  ; u64
CODE_RECEIPT_SIZE               equ 32

; ==================================================================
; Durability enum (u32)
; ==================================================================
OBJECT_DURABILITY_MEMORY        equ 1
OBJECT_DURABILITY_DURABLE       equ 2
OBJECT_DURABILITY_REPLICATED    equ 3

; ==================================================================
; Confidentiality enum (u32)
; ==================================================================
OBJECT_CONFIDENTIALITY_PUBLIC             equ 1
OBJECT_CONFIDENTIALITY_INTEGRITY_ONLY     equ 2
OBJECT_CONFIDENTIALITY_APP_PRIVATE        equ 3
OBJECT_CONFIDENTIALITY_USER_PRIVATE       equ 4
OBJECT_CONFIDENTIALITY_USER_APP_PRIVATE   equ 5
OBJECT_CONFIDENTIALITY_DEVICE_PRIVATE     equ 6
OBJECT_CONFIDENTIALITY_LAYERED            equ 7

; ==================================================================
; Portability enum (u32)
; ==================================================================
OBJECT_PORTABILITY_MACHINE_BOUND    equ 1
OBJECT_PORTABILITY_USER_PORTABLE    equ 2
OBJECT_PORTABILITY_APP_PORTABLE     equ 3
OBJECT_PORTABILITY_PUBLIC_PORTABLE  equ 4

; ==================================================================
; Integrity enum (u32)
; ==================================================================
OBJECT_INTEGRITY_HASH_ONLY  equ 1
OBJECT_INTEGRITY_SIGNED     equ 2
OBJECT_INTEGRITY_SEALED     equ 3

; ==================================================================
; Lifetime enum (u32)
; ==================================================================
OBJECT_LIFETIME_TRANSIENT   equ 1
OBJECT_LIFETIME_SESSION     equ 2
OBJECT_LIFETIME_CACHE       equ 3
OBJECT_LIFETIME_RETAINED    equ 4
OBJECT_LIFETIME_PINNED      equ 5

; ==================================================================
; Visibility enum (u32)
; ==================================================================
OBJECT_VISIBILITY_PRIVATE           equ 1
OBJECT_VISIBILITY_APP_NAMESPACE     equ 2
OBJECT_VISIBILITY_USER_NAMESPACE    equ 3
OBJECT_VISIBILITY_PUBLIC            equ 4

; ==================================================================
; Access enum (u32)
; ==================================================================
OBJECT_ACCESS_EXPLICIT_IO           equ 1
OBJECT_ACCESS_HOT_MEMORY_ALLOWED    equ 2

; ==================================================================
; OwnerKind enum (u32)
; ==================================================================
OBJECT_OWNER_KIND_DEVICE    equ 1
OBJECT_OWNER_KIND_STORAGE   equ 2
OBJECT_OWNER_KIND_APP       equ 3
OBJECT_OWNER_KIND_USER      equ 4

; ==================================================================
; EnvelopeKind enum (u32)
; ==================================================================
OBJECT_ENVELOPE_KIND_NONE       equ 0
OBJECT_ENVELOPE_KIND_DEVICE     equ 1
OBJECT_ENVELOPE_KIND_STORAGE    equ 2
OBJECT_ENVELOPE_KIND_APP        equ 3
OBJECT_ENVELOPE_KIND_USER       equ 4
OBJECT_ENVELOPE_KIND_SIGNATURE  equ 5

; ==================================================================
; Algorithm enum (u16)
; ==================================================================
OBJECT_ALGORITHM_NONE               equ 0
OBJECT_ALGORITHM_BLAKE3             equ 1
OBJECT_ALGORITHM_AES_GCM_256        equ 2
OBJECT_ALGORITHM_XCHACHA20_POLY1305 equ 3
OBJECT_ALGORITHM_ED25519            equ 4
OBJECT_ALGORITHM_ECDSA_P256_SHA256  equ 5

; ==================================================================
; Header binary layout offsets
; ==================================================================
HEADER_OF_MAGIC             equ 0   ; 8 bytes, "EROBJ001"
HEADER_OF_VERSION           equ 8   ; u16
HEADER_OF_KIND              equ 10  ; u16
HEADER_OF_FLAGS             equ 12  ; u32
HEADER_OF_LOGICAL_LEN       equ 16  ; u64
HEADER_OF_OWNER_COUNT       equ 24  ; u16
HEADER_OF_ENVELOPE_COUNT    equ 26  ; u16
HEADER_OF_CHILD_COUNT       equ 28  ; u32
HEADER_OF_BODY_LEN          equ 32  ; u64
HEADER_OF_EPOCH             equ 40  ; 64 bytes (clock.Stamp)
HEADER_OF_REQUIREMENTS      equ 104 ; 28 bytes (Requirements)
HEADER_OF_RESERVED          equ 132 ; 16 bytes (must be zero)

; Header decoded struct offsets
HEADER_STRUCT_KIND          equ 0   ; u16
HEADER_STRUCT_FLAGS         equ 4   ; u32
HEADER_STRUCT_LOGICAL_LEN   equ 8   ; u64
HEADER_STRUCT_OWNER_COUNT   equ 16  ; u16
HEADER_STRUCT_ENVELOPE_COUNT equ 18 ; u16
HEADER_STRUCT_CHILD_COUNT   equ 20  ; u32
HEADER_STRUCT_BODY_LEN      equ 24  ; u64
HEADER_STRUCT_EPOCH         equ 32  ; 64 bytes
HEADER_STRUCT_REQUIREMENTS  equ 96  ; 28 bytes (Requirements)
HEADER_STRUCT_SIZE          equ 124

; ==================================================================
; Requirements binary layout offsets (same as decoded struct)
; ==================================================================
REQ_OF_DURABILITY           equ 0   ; u32
REQ_OF_CONFIDENTIALITY      equ 4   ; u32
REQ_OF_PORTABILITY          equ 8   ; u32
REQ_OF_INTEGRITY            equ 12  ; u32
REQ_OF_LIFETIME             equ 16  ; u32
REQ_OF_VISIBILITY           equ 20  ; u32
REQ_OF_ACCESS               equ 24  ; u32
REQ_STRUCT_SIZE             equ 28

; ==================================================================
; Owner binary layout offsets
; ==================================================================
OWNER_OF_KIND               equ 0   ; u32
OWNER_OF_NODE_ID            equ 4   ; 32 bytes
OWNER_ENCODED_SIZE          equ 36

; Owner decoded struct offsets
OWNER_STRUCT_KIND           equ 0   ; u32
OWNER_STRUCT_NODE_ID        equ 4   ; 32 bytes
OWNER_STRUCT_SIZE           equ 36

; ==================================================================
; Envelope binary layout offsets
; ==================================================================
ENVELOPE_OF_KIND            equ 0   ; u32
ENVELOPE_OF_OWNER_INDEX     equ 4   ; u16
ENVELOPE_OF_ALGORITHM       equ 6   ; u16
ENVELOPE_OF_FLAGS           equ 8   ; u32
ENVELOPE_OF_KEY_ID          equ 12  ; 32 bytes
ENVELOPE_OF_METADATA_HASH   equ 44  ; 32 bytes
ENVELOPE_ENCODED_SIZE       equ 76

; Envelope decoded struct offsets
ENVELOPE_STRUCT_KIND        equ 0   ; u32
ENVELOPE_STRUCT_OWNER_INDEX equ 4   ; u16
ENVELOPE_STRUCT_ALGORITHM   equ 6   ; u16
ENVELOPE_STRUCT_FLAGS       equ 8   ; u32
ENVELOPE_STRUCT_KEY_ID      equ 12  ; 32 bytes
ENVELOPE_STRUCT_METADATA_HASH equ 44 ; 32 bytes
ENVELOPE_STRUCT_SIZE        equ 76

; ==================================================================
; Child binary layout offsets
; ==================================================================
CHILD_OF_OBJECT_ID          equ 0   ; 32 bytes
CHILD_OF_LOGICAL_OFFSET     equ 32  ; u64
CHILD_OF_LOGICAL_LEN        equ 40  ; u64
CHILD_OF_KIND               equ 48  ; u16
CHILD_OF_PAD                equ 50  ; u16 (must be zero)
CHILD_OF_REQUIREMENTS_HASH  equ 52  ; 32 bytes
CHILD_ENCODED_SIZE          equ 84

; Child decoded struct offsets
CHILD_STRUCT_OBJECT_ID         equ 0   ; 32 bytes
CHILD_STRUCT_LOGICAL_OFFSET    equ 32  ; u64
CHILD_STRUCT_LOGICAL_LEN       equ 40  ; u64
CHILD_STRUCT_KIND              equ 48  ; u16
CHILD_STRUCT_PAD               equ 50  ; u16
CHILD_STRUCT_REQUIREMENTS_HASH equ 52  ; 32 bytes
CHILD_STRUCT_SIZE              equ 84

; ==================================================================
; Signature body layout offsets
; ==================================================================
SIGBODY_OF_MAGIC            equ 0   ; 8 bytes "ERSIG001"
SIGBODY_OF_SIGNER_ID        equ 8   ; 32 bytes
SIGBODY_OF_CHALLENGE_ID     equ 40  ; 32 bytes
SIGBODY_OF_SUBJECT_ID       equ 72  ; 32 bytes
SIGBODY_OF_ALGORITHM        equ 104 ; u16
SIGBODY_OF_SIGNATURE_LEN    equ 106 ; u16
SIGBODY_OF_PAD              equ 108 ; u32 (must be zero)
SIGBODY_OF_SIGNATURE        equ 112 ; variable length

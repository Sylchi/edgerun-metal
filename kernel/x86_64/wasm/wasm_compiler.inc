; EdgeRun WASM Compiler — constants and data structures
; Ported from edgerun-zig/compiler/zig/src/edgerun_wasm_compiler.zig

; ABI
WASM_COMPILER_ABI_VERSION    equ 1
APP_ABI_VERSION              equ 1

; Alignment
COMPILER_MEMORY_ALIGNMENT    equ 16
COMPILER_MEMORY_ALIGN_MASK   equ 15

; Source limits
WASM_SOURCE_OFFSET           equ 1024
WASM_PAGE_BYTES              equ 65536
WASM_PAGE_SHIFT              equ 16
WASM_PAGE_MASK               equ 0xffff
MAX_SOURCE_BYTES             equ 96 * 1024 * 1024

; Object format constants
OBJECT_HEADER_BYTES          equ 148
OBJECT_OWNER_BYTES           equ 36
OBJECT_ENVELOPE_BYTES        equ 76
OBJECT_CHILD_BYTES           equ 84
OBJECT_KIND_BYTES            equ 1
VFS_LABEL_REF_BYTES          equ 236
VFS_LABEL_MAX                equ 160
WORKSPACE_MANIFEST_HEADER    equ 16

; FNV-1a hash
FNV_OFFSET_BASIS             equ 0x811c9dc5
FNV_PRIME                    equ 0x01000193

; Magic strings (as dwords for comparison)
OBJECT_MAGIC_DW0             equ 0x4f5245  ; "ERO"
OBJECT_MAGIC_DW1             equ 0x3031424a ; "JB01"  -- actually "EROBJ001"

; Default root label
DEFAULT_ROOT_LABEL           equ "src/main.er"

; Compiler sizing
MAX_PARSED_EXPORTS           equ 64
SUCCESSOR_BASE_FUNCTION_COUNT equ 27
MAX_LOWERED_EXPORTS          equ 64
MAX_LOWERED_CONSTS           equ 128
MAX_EDGERUN_TOP_LEVEL_NAMES  equ MAX_LOWERED_EXPORTS + MAX_LOWERED_CONSTS
MAX_EDGERUN_FUNCTION_LOCALS  equ 32
MAX_EDGERUN_EXPR_CODE_BYTES  equ 256
MAX_EDGERUN_PARAMS           equ 8       ; max function parameters
COMPILED_BODY_BUF_SIZE       equ 8192    ; compiled WASM opcode storage
MAX_WORKSPACE_IMPORT_EDGES   equ 16
MAX_LOWERED_DATA_BYTES       equ 512
MAX_EDGERUN_UI_NODES         equ 8

; ERUI constants
ERUI_MAGIC_DW0               equ 0x49555245  ; "ERUI"
ERUI_MAGIC_DW1               equ 0x30313030  ; "001\x00"
ERUI_HEADER_SIZE             equ 20
ERUI_RECORD_SIZE             equ 16
ERUI_RECORD_KIND_TEXT        equ 1
ERUI_RECORD_KIND_BUTTON      equ 2
ERUI_RECORD_KIND_INPUT       equ 3
ERUI_RECORD_KIND_BADGE       equ 6

; WASM type indices
TYPE_INDEX_NO_ARGS_I32       equ 0
TYPE_INDEX_NO_ARGS_VOID      equ 1
TYPE_INDEX_I32_ARG_I32       equ 2
TYPE_INDEX_I32_I32_ARG_I32   equ 3
TYPE_INDEX_I32_I32_I32_ARG_I32 equ 4

; WASM value types
WASM_BLOCK_TYPE_EMPTY        equ 0x40
WASM_BLOCK_TYPE_I32          equ 0x7f
WASM_FUNCREF_TYPE            equ 0x70

; WASM opcodes
WASM_OPCODE_UNREACHABLE      equ 0x00
WASM_OPCODE_BLOCK            equ 0x02
WASM_OPCODE_LOOP             equ 0x03
WASM_OPCODE_IF               equ 0x04
WASM_OPCODE_ELSE             equ 0x05
WASM_OPCODE_END              equ 0x0b
WASM_OPCODE_BR               equ 0x0c
WASM_OPCODE_BR_IF            equ 0x0d
WASM_OPCODE_RETURN           equ 0x0f
WASM_OPCODE_CALL             equ 0x10
WASM_OPCODE_LOCAL_GET        equ 0x20
WASM_OPCODE_LOCAL_SET        equ 0x21
WASM_OPCODE_I32_LOAD         equ 0x28
WASM_OPCODE_I32_LOAD8_U      equ 0x2d
WASM_OPCODE_I32_STORE        equ 0x36
WASM_OPCODE_I32_STORE8       equ 0x3a
WASM_OPCODE_I32_EQZ          equ 0x45
WASM_OPCODE_I32_EQ           equ 0x46
WASM_OPCODE_I32_NE           equ 0x47
WASM_OPCODE_I32_LT_S         equ 0x48
WASM_OPCODE_I32_GT_S         equ 0x4a
WASM_OPCODE_I32_LE_S         equ 0x4c
WASM_OPCODE_I32_GE_S         equ 0x4e
WASM_OPCODE_I32_ADD          equ 0x6a
WASM_OPCODE_I32_SUB          equ 0x6b
WASM_OPCODE_I32_MUL          equ 0x6c
WASM_OPCODE_I32_DIV_S        equ 0x6d
WASM_OPCODE_I32_REM_S        equ 0x6f

; Extended opcode prefix
WASM_EXTENDED_PREFIX         equ 0xfc
WASM_EXT_MEMORY_COPY         equ 10

; I32 constant opcode
WASM_I32_CONST               equ 0x41

; WASM magic + version
WASM_MAGIC_WORD              equ 0x6d736100
WASM_VERSION_WORD            equ 0x00010000  ; little-endian version 1

; State slot bytes
STATE_SLOT_BYTES             equ 4

; Linked compiler buffer sizes
LINKED_TYPE_SECTION_BUFFER   equ 64 * 1024
LINKED_FUNCTION_SECTION_BUFFER equ 64 * 1024
LINKED_EXPORT_SECTION_BUFFER equ 64 * 1024
COMPILE_WORKSPACE_BODY_BUFFER equ 2048

; Error codes
ERROR_CODE_OK                equ 0
ERROR_CODE_BAD_INPUT         equ 2
ERROR_CODE_COMPILE_SRC_EMPTY equ 20
ERROR_CODE_COMPILE_SRC_LARGE equ 21
ERROR_CODE_COMPILE_INIT_FAIL equ 22
ERROR_CODE_COMPILE_FAILED    equ 23
ERROR_CODE_COMPILE_OUT_SHORT equ 24
ERROR_CODE_COMPILE_OUT_LARGE equ 25
ERROR_CODE_COMPILE_BAD_MAGIC equ 26

; Compiler status codes
COMPILER_STATUS_OK           equ 0
COMPILER_STATUS_NOT_INIT     equ 1
COMPILER_STATUS_INVALID_MEM  equ 2
COMPILER_STATUS_UNSUPPORTED  equ 3
COMPILER_STATUS_SRC_TOO_LARGE equ 4
COMPILER_STATUS_OUT_TOO_LARGE equ 5
COMPILER_STATUS_CORRUPT_OBJ  equ 6
COMPILER_STATUS_MISSING_ROOT equ 7
COMPILER_STATUS_INVALID_SRC  equ 8
COMPILER_STATUS_MEM_TOO_SMALL equ 9

; Compile mode
COMPILE_MODE_FULL_SOURCE     equ 0
COMPILE_MODE_METADATA_ONLY   equ 1

; Source mode
SOURCE_MODE_EDGERUN          equ 0

; Linked compiler info indices (for parsing embedded wasm)
MAX_FUNCTION_COUNT           equ 1024
MAX_LINKED_TYPES             equ 128
LEB32_MAX_BYTES              equ 5
LEB64_MAX_BYTES              equ 10
LEB_PAYLOAD_MASK             equ 0x7f
LEB_CONTINUE_MASK            equ 0x80
LEB_SIGN_MASK                equ 0x40
LEB_BITS_PER_BYTE            equ 7

; Writer buffer sizes (for on-stack temp buffers)
WRITER_STACK_BUFFER_SIZE     equ 8192
EMIT_EXPORT_BUFFER_SIZE      equ 8192

; Edgerun string lookup constants for keyword matching
%define CONST_KEYWORD       "const "
%define VAR_KEYWORD         "var "
%define FN_KEYWORD          "fn "
%define EXPORT_FN_KEYWORD   "export fn "
%define PUB_EXPORT_FN       "pub export fn "
%define RETURN_KEYWORD      "return"
%define IF_KEYWORD          "if"
%define ELSE_KEYWORD        "else"
%define WHILE_KEYWORD       "while"
%define TRUE_KEYWORD        "true"
%define FALSE_KEYWORD       "false"

; Default function indices for successor base functions
; Index 0-4: sig ()->i32
; Index 5: sig ()->void (noop)
; Index 6-26: sig ()->i32

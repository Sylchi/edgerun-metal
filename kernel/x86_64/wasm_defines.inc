; EdgeRun freestanding WASM interpreter — x86_64 assembly
; Shared definitions (equates, %defines, error codes) — no BSS, no data, no macros.inc.
; Designed for inclusion by driver files that need error codes without the ~18MB WASM BSS.

; ==================================================================
; WASM limits (matching root.zig exactly)
; ==================================================================
%define MAX_FUNCTIONS        1024
%define MAX_IMPORTS          16
%define MAX_TYPES            128
%define MAX_TYPE_PARAMS      128
%define MAX_TYPE_RESULTS     4
%define MAX_LOCALS           1024
%define MAX_STACK            32
%define MAX_CALL_DEPTH       256
%define MAX_CONTROL_DEPTH    256
%define MAX_GLOBALS          16
%define MAX_TABLE_ENTRIES    32
%define MAX_DATA_SEGMENTS    8
%define MAX_DECODED_OPS      (512 * 1024)
%define BYTE_LOAD_BYTES      1
%define I32_LOAD_BYTES       4
%define WASM_PAGE_BYTES      65536
%define WASM_PAGE_SHIFT      16
%define LEB32_MAX_BYTES      5
%define LEB64_MAX_BYTES      10

; LEB128 bit masks
%define LEB_PAYLOAD_MASK     0x7f
%define LEB_CONTINUE_MASK    0x80
%define LEB_SIGN_MASK        0x40
%define LEB_BITS_PER_BYTE    7

; WASM type markers
%define WASM_EMPTY_BLOCK_TYPE 0x40
%define WASM_FUNCREF_TYPE     0x70
%define WASM_REF_FUNC_OPCODE  0xd2
%define WASM_EXTENDED_PREFIX  0xfc

; Limits flags
%define LIMITS_MIN_ONLY       0
%define LIMITS_MIN_MAX        1

; Extended opcodes
%define EXT_I32_TRUNC_SAT_F32_S  0
%define EXT_I32_TRUNC_SAT_F32_U  1
%define EXT_I32_TRUNC_SAT_F64_S  2
%define EXT_I32_TRUNC_SAT_F64_U  3
%define EXT_I64_TRUNC_SAT_F32_S  4
%define EXT_I64_TRUNC_SAT_F32_U  5
%define EXT_I64_TRUNC_SAT_F64_S  6
%define EXT_I64_TRUNC_SAT_F64_U  7
%define EXT_MEMORY_INIT          8
%define EXT_DATA_DROP            9
%define EXT_MEMORY_COPY          10
%define EXT_MEMORY_FILL          11
%define EXT_TABLE_INIT           12
%define EXT_ELEM_DROP            13
%define EXT_TABLE_COPY           14
%define EXT_TABLE_GROW           15
%define EXT_TABLE_SIZE           16
%define EXT_TABLE_FILL           17

; WASM sections
%define SECTION_TYPE        1
%define SECTION_IMPORT      2
%define SECTION_FUNCTION    3
%define SECTION_TABLE       4
%define SECTION_MEMORY      5
%define SECTION_GLOBAL      6
%define SECTION_EXPORT      7
%define SECTION_START       8
%define SECTION_ELEMENT     9
%define SECTION_CODE        10
%define SECTION_DATA        11
%define SECTION_DATA_COUNT  12

; External kinds
%define EXTERNAL_FUNCTION   0
%define EXTERNAL_TABLE      1
%define EXTERNAL_MEMORY     2
%define EXTERNAL_GLOBAL     3

; External references
extern er_memcpy
extern er_memset
extern er_memmove

; ==================================================================
; HostImport struct — host-provided import table entries
; Each entry: module name, function name, function pointer
; The caller passes an array of these via runtime.imports_ptr/len.
; ==================================================================
%define HOST_IMPORT_MODULE_PTR_OFF  0
%define HOST_IMPORT_MODULE_LEN_OFF  8
%define HOST_IMPORT_NAME_PTR_OFF   16
%define HOST_IMPORT_NAME_LEN_OFF   24
%define HOST_IMPORT_FN_PTR_OFF     32
%define HOST_IMPORT_SIZE           40

; ==================================================================
; RuntimeConfig struct offsets (passed as pointer in rdi to er_fn_run)
; ==================================================================
%define RUNTIME_MEMORY_PTR_OFF      0
%define RUNTIME_MEMORY_LEN_OFF      8
%define RUNTIME_TICKS_PTR_OFF      16
%define RUNTIME_MEM_GROW_FN_OFF    24
%define RUNTIME_MEM_GROW_CTX_OFF   32
%define RUNTIME_TABLE_GROW_FN_OFF  40
%define RUNTIME_TABLE_GROW_CTX_OFF 48
%define RUNTIME_INITIAL_PAGES_OFF  56
%define RUNTIME_HAS_PAGES_OFF      64
%define RUNTIME_IMPORTS_PTR_OFF    72
%define RUNTIME_IMPORTS_LEN_OFF    80
%define RUNTIME_SIZE               88

; WASM magic + version
wasm_magic: db 0x00, 0x61, 0x73, 0x6d
wasm_version: db 0x01, 0x00, 0x00, 0x00

; Error codes (returned in rdx on error; rdx=0 on success, per macros.inc convention)
%define ERROR_BAD_ARGUMENT     1
%define ERROR_CORRUPT          2
%define ERROR_UNSUPPORTED      3
%define ERROR_NO_MEMORY        4
%define ERROR_MEMORY_GROWTH    5
%define ERROR_TABLE_GROWTH     6
%define ERROR_NO_EXECUTION     7
%define ERROR_MISSING_EXPORT   8
%define ERROR_MISSING_IMPORT   9
%define ERROR_STACK_OVERFLOW   10
%define ERROR_STACK_UNDERFLOW  11
%define ERROR_TRAP             12
%define ERROR_ARITHMETIC_TRAP  13
%define ERROR_IMPORT_NOT_FOUND 14

; Driver error codes (shared across all hardware drivers)
%define ERROR_TIMEOUT          20
%define ERROR_IO               21
%define ERROR_NOT_PRESENT      22
%define ERROR_NO_DATA          23
%define ERROR_INVALID_PARAM    24
%define ERROR_BUSY             25
%define ERROR_AUTH             26
%define ERROR_NO_SPACE         27
%define ERROR_NOT_FOUND        28

%define ERROR_OK               0

; ==================================================================
; Value type tags (for Value.tag field)
; ==================================================================
%define VALUE_TAG_I32      0x7f
%define VALUE_TAG_I64      0x7e
%define VALUE_TAG_F32      0x7d
%define VALUE_TAG_F64      0x7c
%define VALUE_TAG_FUNCREF  0x70

; Control frame kinds
%define CONTROL_BLOCK      0
%define CONTROL_LOOP       1
%define CONTROL_IF_THEN    2
%define CONTROL_IF_ELSE    3

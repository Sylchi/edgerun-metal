; EdgeRun freestanding WASM interpreter — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, arg5=r8, arg6=r9, retval=rax
; Port of edgerun-zig/src/wasm/root.zig
; No libc, no external dependencies.

%include "x86_64/macros.inc"

default rel

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

; WASM magic + version
wasm_magic: db 0x00, 0x61, 0x73, 0x6d
wasm_version: db 0x01, 0x00, 0x00, 0x00

; Float constants for WASM spec semantics
F32_NEG_ZERO:    dd 0x80000000
F32_POS_INF:     dd 0x7f800000
F64_NEG_ZERO:    dq 0x8000000000000000
F64_POS_INF:     dq 0x7ff0000000000000

; Sign and magnitude masks
F32_SIGN_MASK:     dd 0x80000000
F32_MAGNITUDE_MASK: dd 0x7fffffff
F64_SIGN_MASK:     dq 0x8000000000000000
F64_MAGNITUDE_MASK: dq 0x7fffffffffffffff

; Error codes (returned in rax on error, or stored in error_code)
ERROR_BAD_ARGUMENT     equ 1
ERROR_CORRUPT          equ 2
ERROR_UNSUPPORTED      equ 3
ERROR_NO_MEMORY        equ 4
ERROR_MEMORY_GROWTH    equ 5
ERROR_TABLE_GROWTH     equ 6
ERROR_NO_EXECUTION     equ 7
ERROR_MISSING_EXPORT   equ 8
ERROR_MISSING_IMPORT   equ 9
ERROR_STACK_OVERFLOW   equ 10
ERROR_STACK_UNDERFLOW  equ 11
ERROR_TRAP             equ 12
ERROR_ARITHMETIC_TRAP  equ 13
ERROR_IMPORT_NOT_FOUND equ 14
ERROR_OK               equ 0

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

; ==================================================================
; BSS — all interpreter state
; ==================================================================
SECTION .bss

; -- Value is 16 bytes: 8 bytes data, 4 bytes type tag, 4 bytes padding
; VALUE_size equ 16

; -- FuncType: params[128] + results[4] + param_count + result_count
; Layout: 128 bytes params + 4 bytes results + 8 bytes param_count + 8 bytes result_count = 148
; Padded to 256 for power-of-2 addressing
FUNC_TYPE_SIZE equ 256
FUNC_TYPE_PARAM_COUNT_OFF equ 132  ; offset of param_count field
FUNC_TYPE_RESULT_COUNT_OFF equ 140 ; offset of result_count field

types_buf:      resb MAX_TYPES * FUNC_TYPE_SIZE       ; 128 * 148 = 18944
type_count:     resq 1

; -- ImportedFunction: module_name_offset(8) + module_name_len(8) + name_offset(8) + name_len(8) + type_index(8) = 40
; Padded to 64 for power-of-2 addressing
IMPORTED_FUNC_SIZE equ 64
imports_buf:    resb MAX_IMPORTS * IMPORTED_FUNC_SIZE
import_count:   resq 1

; -- ImportedMemory: module fields + min_pages(8) + max_pages(8) + present flag(1) = 33
imported_memory_present: resb 1
imported_memory_min:     resq 1
imported_memory_max:     resq 1

; -- ImportedTable: module fields + min_entries(8) + max_entries(8) + present flag(1)
imported_table_present:  resb 1
imported_table_min:      resq 1
imported_table_max:      resq 1

; -- ImportedGlobal: module fields + global_index(8)
IMPORTED_GLOBAL_SIZE equ 24
imported_globals_buf:   resb MAX_GLOBALS * IMPORTED_GLOBAL_SIZE
imported_global_count:  resq 1

; -- Function: type_index(8) + code_index(8) = 16
FUNCTION_SIZE equ 16
functions_buf:   resb MAX_FUNCTIONS * FUNCTION_SIZE
function_count:  resq 1

; -- Code: body_offset(8) + body_len(8) + local_count(8) + decoded_start(8) + decoded_count(8) = 40
; Padded to 64 for power-of-2 addressing
CODE_SIZE equ 64
code_buf:        resb MAX_FUNCTIONS * CODE_SIZE
code_count:      resq 1

; Local types for each function (stored contiguously)
; Each function has up to MAX_LOCALS types. Store as byte array.
; Index into this using: local_type_offset[func_idx] + local_idx
; We'll compute offsets on the fly from the Code struct
code_local_types: resb MAX_FUNCTIONS * MAX_LOCALS  ; 1024 * 1024 = 1MB (large!)

; -- Export: name_offset(8) + name_len(8) + kind(1) + padding(7) + index(8) = 32
EXPORT_SIZE equ 32
exports_buf:     resb MAX_FUNCTIONS * EXPORT_SIZE
export_count:    resq 1

; -- Global: value_type(1) + mutable(1) + padding(6) + value_data(8) + value_tag(4) + padding(4) = 24
; Padded to 32 for power-of-2 addressing
GLOBAL_SIZE equ 32
globals_buf:     resb MAX_GLOBALS * GLOBAL_SIZE
global_count:    resq 1

; -- Table entries (funcref array)
table_entries:    resq MAX_TABLE_ENTRIES  ; each is usize (8 bytes)
table_min:        resq 1
table_max:        resq 1
table_has:        resb 1

; -- Element segments: entries[32] * 8 + count(8) + passive(1) + dropped(1) = 266 per segment
; Padded to 512 for power-of-2 addressing
ELEMENT_SEGMENT_SIZE equ 512
element_segments: resb MAX_DATA_SEGMENTS * ELEMENT_SEGMENT_SIZE
element_segment_count: resq 1

; -- Data segments: offset(8) + byte_offset(8) + byte_len(8) + active(1) + dropped(1) = 26
;   bytes themselves stored in a workspace buffer
DATA_SEGMENT_SIZE equ 32
data_segments:    resb MAX_DATA_SEGMENTS * DATA_SEGMENT_SIZE
data_segment_count: resq 1
declared_data_count: resq 1  ; -1 = not declared

; -- Decoded op cache (global, reused across parses)
; DecodedOp: offset(4) + next_offset(4) + opcode_byte(1) + padding(3) + imm0(4) + imm1(4) = 20
; Padded to 32 for power-of-2 addressing
DECODED_OP_SIZE equ 32
decoded_ops:     resb MAX_DECODED_OPS * DECODED_OP_SIZE  ; ~10MB!
decoded_op_count: resq 1

; -- Runtime context (caller-provided)
runtime_memory_ptr:    resq 1
runtime_memory_len:    resq 1
runtime_ticks_ptr:     resq 1
runtime_imports_ptr:   resq 1
runtime_imports_len:   resq 1
runtime_memory_grow_fn:   resq 1
runtime_memory_grow_ctx:  resq 1
runtime_table_grow_fn:    resq 1
runtime_table_grow_ctx:   resq 1
runtime_initial_pages:    resq 1
runtime_has_initial_pages: resb 1

; -- Executor state (set up before execution)
executor_runtime_ptr:  resq 1
executor_module_ptr:   resq 1
executor_memory_pages: resq 1
executor_memory_limit: resq 1

; -- Names buffer (for import/export name strings)
; Simple bump allocator — caller writes names here before parsing
names_buf:       resb 16384
names_offset:    resq 1

; -- Workspace for string comparison, temp storage
scratch_buf:     resb 256

; -- Execution storage (cached module + executor for repeated calls)
; Module parse cache
exec_storage_module_valid: resb 1
exec_storage_start_ran:    resb 1

; -- String compare temporary buffer for import/export name matching
strcmp_buf:      resb 256

; -- Execution engine state
; Current frame locals (each is 8 bytes, up to MAX_LOCALS)
exec_local_count: resq 1
exec_locals:    resb MAX_LOCALS * 8

; Current frame value stack (each entry is 8 bytes)
exec_stack_len: resq 1
exec_stack:     resb MAX_STACK * 8

; Control frame stack
; Each ControlFrame: kind(8) + next_offset(8) = 16 bytes
CONTROL_FRAME_SIZE equ 16
exec_control_len: resq 1
exec_control:   resb MAX_CONTROL_DEPTH * CONTROL_FRAME_SIZE

; Decoded op tracking
exec_decoded_index: resq 1
exec_decoded_end:   resq 1

; Frame save area (for WASM function calls)
; Stores locals + stack + control frames as a flat stack
; Layout per saved frame:
;   [locals data (local_count * 8 bytes)]
;   [stack data (stack_len * 8 bytes)]
;   [control data (control_len * 16 bytes)]
;   [metadata: local_count, stack_len, control_len, dec_idx, dec_end = 40 bytes]
FRAME_SAVE_SIZE equ 1024 * 1024  ; 1MB save area (enough for deep recursion with moderate locals)
exec_frame_save:  resb FRAME_SAVE_SIZE
exec_frame_save_ptr: resq 1  ; offset into save area (grows upward)

; Current function info for dispatch
exec_function_type_ptr: resq 1  ; pointer to current FuncType
exec_type_index:       resq 1  ; type index of current function
exec_code_body_ptr:    resq 1  ; pointer to current code body
exec_code_body_len:    resq 1  ; remaining body length
exec_reader_offset:    resq 1  ; current reader offset within body

; Call depth for recursion limit
exec_call_depth: resq 1

; Return value from function execution (as i64, + count in exec_result_count)
exec_result_values: resb MAX_TYPE_RESULTS * 8  ; up to 4 result values
exec_result_count:  resq 1

; ==================================================================
; .data section — lookup tables
; ==================================================================
SECTION .data

; Opcode dispatch table: 256 entries, each 8 bytes (function pointer)
; Uses a two-level approach: hot opcodes handled inline, cold ones via table
; For now we use a simple jump table for the main dispatch
opcode_table:
; Uninitialized — will be populated by init code
times 256 dq 0  ; will be filled at runtime with dispatch addresses

; Section order table (for validation)
section_order:
db 0   ; 0 (custom)
db 1   ; 1 type
db 2   ; 2 import
db 3   ; 3 function
db 4   ; 4 table
db 5   ; 5 memory
db 6   ; 6 global
db 7   ; 7 export
db 8   ; 8 start
db 9   ; 9 element
db 10  ; 10 data_count
db 11  ; 11 code
db 12  ; 12 data

; ==================================================================
; SECTION .text
; ==================================================================
SECTION .text

; ==================================================================
; Helper: er_wasm_read_leb_u32
; Reads a LEB128 unsigned 32-bit value from [rsi], returns in rax.
; Updates rsi to point past the value.
; Returns error in rdx (0 = ok, nonzero = error).
; ==================================================================
er_wasm_read_leb_u32:
    xor     eax, eax
    xor     ecx, ecx            ; shift count (in bits)
    xor     r8d, r8d            ; byte counter
.leb_loop:
    cmp     r8d, LEB32_MAX_BYTES
    jge     .leb_error
    movzx   r9d, byte [rsi]
    inc     rsi
    mov     r10d, r9d
    and     r10d, LEB_PAYLOAD_MASK
    shl     r10d, cl
    or      eax, r10d
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9d, LEB_CONTINUE_MASK
    jnz     .leb_loop
    xor     edx, edx            ; no error
    ret
.leb_error:
    mov     edx, ERROR_CORRUPT
    ret

; ==================================================================
; Helper: er_wasm_read_leb_i32
; Reads a LEB128 signed 32-bit value from [rsi], returns in rax.
; Updates rsi to point past the value.
; Returns error in rdx.
; ==================================================================
er_wasm_read_leb_i32:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9b, 0              ; will store last byte
.leb_loop_s:
    cmp     r8d, LEB32_MAX_BYTES
    jge     .leb_error_s
    mov     r9b, byte [rsi]
    inc     rsi
    mov     r10d, r9d
    and     r10d, LEB_PAYLOAD_MASK
    shl     r10d, cl
    or      eax, r10d
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9b, LEB_CONTINUE_MASK
    jnz     .leb_loop_s
    ; sign extend if needed
    mov     ecx, r8d
    shl     ecx, 3              ; total bits read = bytes * 7
    cmp     ecx, 32
    jge     .done_s
    test    r9b, LEB_SIGN_MASK
    jz      .done_s
    mov     r10d, -1
    shl     r10d, cl            ; shift -1 left by bits_read
    or      eax, r10d
.done_s:
    xor     edx, edx
    ret
.leb_error_s:
    mov     edx, ERROR_CORRUPT
    ret

; ==================================================================
; Helper: er_wasm_read_leb_i64
; Reads a LEB128 signed 64-bit value from [rsi], returns in rax.
; Updates rsi to point past the value.
; Returns error in rdx.
; ==================================================================
er_wasm_read_leb_i64:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9b, 0
.leb_loop_l:
    cmp     r8d, LEB64_MAX_BYTES
    jge     .leb_error_l
    mov     r9b, byte [rsi]
    inc     rsi
    mov     r10, r9
    and     r10, LEB_PAYLOAD_MASK
    shl     r10, cl
    or      rax, r10
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9b, LEB_CONTINUE_MASK
    jnz     .leb_loop_l
    mov     ecx, r8d
    shl     ecx, 3
    cmp     ecx, 64
    jge     .done_l
    test    r9b, LEB_SIGN_MASK
    jz      .done_l
    mov     r10, -1
    shl     r10, cl
    or      rax, r10
.done_l:
    xor     edx, edx
    ret
.leb_error_l:
    mov     edx, ERROR_CORRUPT
    ret

; ==================================================================
; Helper: er_wasm_read_value_type
; Reads a ValueType byte from [rsi], returns in al.
; Updates rsi. Returns error in rdx.
; ==================================================================
er_wasm_read_value_type:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, VALUE_TAG_I32
    je      .valid
    cmp     al, VALUE_TAG_I64
    je      .valid
    cmp     al, VALUE_TAG_F32
    je      .valid
    cmp     al, VALUE_TAG_F64
    je      .valid
    cmp     al, VALUE_TAG_FUNCREF
    je      .valid
    mov     edx, ERROR_UNSUPPORTED
    ret
.valid:
    xor     edx, edx
    ret

; ==================================================================
; Helper: er_wasm_read_limits
; Reads limits from [rsi], stores in [rcx] (Limits struct: min=0, max=8).
; Updates rsi.
; ==================================================================
er_wasm_read_limits:
    push    rbx
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, LIMITS_MIN_ONLY
    je      .min_only
    cmp     al, LIMITS_MIN_MAX
    je      .min_max
    mov     edx, ERROR_UNSUPPORTED
    pop     rbx
    ret
.min_only:
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [rcx], rax          ; store min
    mov     qword [rcx + 8], 0  ; max = null (0)
    xor     edx, edx
    pop     rbx
    ret
.min_max:
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [rcx], rax          ; store min
    mov     rbx, rax
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     rax, rbx
    jb      .corrupt
    mov     [rcx + 8], rax      ; store max
    xor     edx, edx
    pop     rbx
    ret
.corrupt:
    mov     edx, ERROR_CORRUPT
.error:
    pop     rbx
    ret

; ==================================================================
; Helper: er_wasm_read_constant_i32
; Reads i32.const + value + end expression from [rsi].
; Returns value in rax. Updates rsi.
; ==================================================================
er_wasm_read_constant_i32:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x41            ; i32.const
    jne     .unsupported
    call    er_wasm_read_leb_i32
    test    edx, edx
    jnz     .error
    push    rax                 ; save value
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x0b            ; end
    jne     .unsupported
    pop     rax
    xor     edx, edx
    ret
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
.error:
    ret

; ==================================================================
; Helper: eql (string comparison)
; Compares two bytes at [rdi] (len in rsi) and [rdx] (len in rcx).
; Returns 1 in rax if equal, 0 otherwise.
; Clobbers: rdi, rsi, rcx, r8
; ==================================================================
er_wasm_eql:
    push    rbp
    mov     rbp, rsp
    ; rdi = ptr1, rsi = len1, rdx = ptr2, rcx = len2
    cmp     rsi, rcx
    jne     .not_equal
    test    rsi, rsi
    jz      .equal
    mov     r8, rsi
    mov     rsi, rdx
    mov     rcx, r8
    cld
    repe    cmpsb
    jne     .not_equal
.equal:
    mov     eax, 1
    pop     rbp
    ret
.not_equal:
    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Helper: find_host_import
; Searches runtime.imports for a matching import.
; rdi = import_ptr (ImportedFunction), rsi = import_size (for generic compare)
; rdx = expected kind (function/memory/table/global)
; Returns host import ptr in rax, or error in rdx
; ==================================================================
; TODO: implement

; ==================================================================
; Helper: checked_add
; Returns rdi + rsi in rax, CF set if overflow
; ==================================================================
er_wasm_checked_add:
    mov     rax, rdi
    add     rax, rsi
    ret

; ==================================================================
; Helper: pages_to_bytes
; rdi = pages, returns bytes in rax, rdx = 0 on success, error on overflow
; ==================================================================
er_wasm_pages_to_bytes:
    mov     rax, rdi
    shr     rax, 48             ; if pages > 2^48, overflow (since 2^48 >> 16 = 2^32)
    test    rax, rax
    jnz     .overflow
    mov     rax, rdi
    shl     rax, WASM_PAGE_SHIFT
    xor     edx, edx
    ret
.overflow:
    mov     edx, ERROR_UNSUPPORTED
    ret

; ==================================================================
; Module parser entry point
; er_wasm_parse_module(bytes_ptr=rdi, bytes_len=rsi)
; Returns: rax = 0 on success, error code otherwise
; Destroys current module state, re-parses into global structures
; =================================================================+
er_wasm_parse_module:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 64             ; local vars

    ; Reset module state
    mov     qword [type_count], 0
    mov     qword [import_count], 0
    mov     qword [function_count], 0
    mov     qword [code_count], 0
    mov     qword [export_count], 0
    mov     qword [global_count], 0
    mov     qword [imported_global_count], 0
    mov     qword [element_segment_count], 0
    mov     qword [data_segment_count], 0
    mov     qword [declared_data_count], 0
    mov     qword [table_min], 0
    mov     qword [table_max], 0
    mov     byte [table_has], 0
    mov     byte [imported_memory_present], 0
    mov     byte [imported_table_present], 0
    mov     qword [decoded_op_count], 0
    mov     qword [start_function_index], -1

    ; Check magic bytes
    cmp     rsi, 8
    jb      .corrupt
    ; Compare wasm magic
    mov     r8d, [rdi]
    cmp     r8d, 0x6d736100      ; little-endian "\x00asm"
    jne     .corrupt
    ; Compare wasm version (0x00000001 at offset 4)
    mov     r8d, [rdi + 4]
    cmp     r8d, 0x00000001
    jne     .corrupt

    ; Set up reader at offset 8
    lea     r12, [rdi + 8]      ; r12 = current read position
    lea     r13, [rdi + rsi]    ; r13 = end pointer
    xor     r14b, r14b          ; previous_section_order

.parse_loop:
    cmp     r12, r13
    jae     .parse_done

    ; Read section ID
    movzx   r15d, byte [r12]
    inc     r12

    ; Read section size (LEB128)
    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r11, rax            ; r11 = section_size

    ; Skip custom sections (id == 0)
    test    r15d, r15d
    jz      .skip_section

    ; Validate section order (section must have strictly increasing order)
    movzx   eax, byte [section_order + r15]
    cmp     al, r14b
    jbe     .corrupt
    mov     r14b, al

    ; Section payload bounds check
    mov     rax, r12
    add     rax, r11
    cmp     rax, r13
    ja      .corrupt

    ; Save rsi (payload start) and r11 (payload len), dispatch
    mov     [rsp], rsi          ; save payload start (past section-size LEB)
    mov     [rsp + 8], r11      ; save payload length
    mov     [rsp + 16], r13     ; save end pointer

    ; r12 = payload pointer for section parsing
    mov     r12, rsi
    mov     [debug_section_id], r15b  ; debug: mark section ID
    cmp     r15d, SECTION_TYPE
    je      .parse_type
    cmp     r15d, SECTION_IMPORT
    je      .parse_import
    cmp     r15d, SECTION_FUNCTION
    je     .parse_function
    cmp     r15d, SECTION_TABLE
    je      .parse_table
    cmp     r15d, SECTION_MEMORY
    je      .parse_memory
    cmp     r15d, SECTION_GLOBAL
    je      .parse_global
    cmp     r15d, SECTION_EXPORT
    je      .parse_export
    cmp     r15d, SECTION_START
    je      .parse_start
    cmp     r15d, SECTION_ELEMENT
    je      .parse_element
    cmp     r15d, SECTION_DATA_COUNT
    je      .parse_data_count
    cmp     r15d, SECTION_CODE
    je      .parse_code
    cmp     r15d, SECTION_DATA
    je      .parse_data
    jmp     .unsupported

.skip_section:
    add     r12, r11
    jmp     .parse_loop

.parse_type:
    call    er_wasm_parse_type_section
    test    edx, edx
    jnz     .error
    ; advance past section
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_import:
    call    er_wasm_parse_import_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_function:
    call    er_wasm_parse_function_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_table:
    call    er_wasm_parse_table_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_memory:
    call    er_wasm_parse_memory_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_global:
    call    er_wasm_parse_global_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_export:
    call    er_wasm_parse_export_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_start:
    call    er_wasm_parse_start_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_element:
    call    er_wasm_parse_element_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_data_count:
    call    er_wasm_parse_data_count_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_code:
    call    er_wasm_parse_code_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_data:
    call    er_wasm_parse_data_section
    test    edx, edx
    jnz     .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_done:
    ; Validate function_count == code_count
    mov     rax, [function_count]
    cmp     rax, [code_count]
    jne     .corrupt
    ; Validate declared_data_count matches data_segment_count if present
    mov     rax, [declared_data_count]
    test    rax, rax
    jz      .success
    cmp     rax, [data_segment_count]
    jne     .corrupt
.success:
    xor     eax, eax
    jmp     .done
.corrupt:
    mov     eax, ERROR_CORRUPT
    jmp     .done
.unsupported:
    mov     eax, ERROR_UNSUPPORTED
    jmp     .done
.error:
    mov     eax, edx
.done:
    lea     rsp, [rbp - 40]
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Type section parser
; Parses types from [r12] into types_buf
; =================================================================+
er_wasm_parse_type_section:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r14, rax            ; r14 = count
    cmp     r14, MAX_TYPES
    ja      .unsupported
    mov     [type_count], r14

    ; Parse each FuncType
    xor     r13d, r13d          ; index
.type_loop:
    cmp     r13, r14
    jae     .done

    ; Read form byte (must be 0x60)
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x60
    jne     .unsupported

    ; Read param count
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     rax, MAX_TYPE_PARAMS
    ja      .unsupported
    
    ; Compute offset into types_buf
    mov     rbx, r13
    imul    rbx, FUNC_TYPE_SIZE
    lea     rbx, [types_buf + rbx]

    ; Store param count
    mov     [rbx + FUNC_TYPE_PARAM_COUNT_OFF], rax
    mov     rcx, rax            ; rcx = param count

    ; Read params
    xor     r8d, r8d
.param_loop:
    cmp     r8, rcx
    jae     .params_done
    call    er_wasm_read_value_type
    test    edx, edx
    jnz     .error
    mov     [rbx + r8], al      ; store param type byte
    inc     r8
    jmp     .param_loop
.params_done:

    ; Read result count
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     rax, MAX_TYPE_RESULTS
    ja      .unsupported
    mov     [rbx + FUNC_TYPE_RESULT_COUNT_OFF], rax
    mov     rcx, rax            ; rcx = result count

    ; Read results
    xor     r8d, r8d
.result_loop:
    cmp     r8, rcx
    jae     .results_done
    call    er_wasm_read_value_type
    test    edx, edx
    jnz     .error
    mov     [rbx + MAX_TYPE_PARAMS + r8], al  ; store result type after params
    inc     r8
    jmp     .result_loop
.results_done:

    inc     r13
    jmp     .type_loop

.done:
    mov     r12, rsi            ; save updated reader position
    xor     edx, edx
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, ERROR_CORRUPT
.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Import section parser
; =================================================================+
er_wasm_parse_import_section:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r14, rax            ; r14 = count
    cmp     r14, MAX_IMPORTS
    ja      .unsupported

    xor     r13d, r13d          ; import index
.import_loop:
    cmp     r13, r14
    jae     .done

    ; Read module name
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r15, rsi
    add     rsi, rax            ; skip name bytes (we don't store them for matching — names are in the caller's wasm bytes)

    ; Read import name
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r15, rsi
    add     rsi, rax

    ; Read external kind
    movzx   r15d, byte [rsi]
    inc     rsi

    cmp     r15d, EXTERNAL_FUNCTION
    je      .import_function
    cmp     r15d, EXTERNAL_MEMORY
    je      .import_memory
    cmp     r15d, EXTERNAL_GLOBAL
    je      .import_global
    cmp     r15d, EXTERNAL_TABLE
    je      .import_table
    jmp     .unsupported

.import_function:
    ; Store ImportedFunction
    push    r10
        mov     r10, r13
        imul    r10, IMPORTED_FUNC_SIZE
    mov     qword [imports_buf + r10], r15   ; module offset (simplified — just store pointer to wasm bytes)
        pop     r10
    ; For now, we store the name pointer relative to original bytes
    ; TODO: store properly
    mov     rdi, qword [rsp]    ; get saved payload start
    ; type_index
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    ; Verify type_index < type_count
    mov     rbx, rax
    cmp     rbx, [type_count]
    jae     .corrupt
    push    r10
        mov     r10, r13
        imul    r10, IMPORTED_FUNC_SIZE
    mov     [imports_buf + r10 + 32], rbx  ; type_index @ offset 32
        pop     r10
    jmp     .import_next

.import_memory:
    ; Store ImportedMemory
    mov     byte [imported_memory_present], 1
    lea     rcx, [rsp - 16]      ; temp Limits struct
    push    rsi
    call    er_wasm_read_limits
    pop     rsi
    test    edx, edx
    jnz     .error
    mov     rax, [rsp - 16]      ; min
    mov     rbx, [rsp - 8]       ; max
    mov     [imported_memory_min], rax
    mov     [imported_memory_max], rbx
    ; Update module memory limits
    mov     [memory_min_pages], rax  ; TODO: define this global
    mov     [memory_max_pages], rbx
    jmp     .import_next

.import_global:
    call    er_wasm_read_value_type
    test    edx, edx
    jnz     .error
    movzx   r15d, byte [rsi - 1]  ; reread value type byte
    movzx   ebx, byte [rsi]
    inc     rsi
    cmp     bl, 1
    ja      .corrupt
    mov     rdi, [global_count]
    cmp     rdi, MAX_GLOBALS
    jae     .unsupported
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10], r15b  ; value_type
        pop     r10
    ; Store ImportedGlobal
    push    r10
    mov     r10, r13
    imul    r10, IMPORTED_GLOBAL_SIZE
    mov     [imported_globals_buf + r10 + 16], rdi  ; global_index
    pop     r10
    inc     qword [global_count]
    inc     qword [imported_global_count]
    jmp     .import_next

.import_table:
    mov     byte [imported_table_present], 1
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported
    lea     rcx, [rsp - 16]
    call    er_wasm_read_limits
    test    edx, edx
    jnz     .error
    mov     rax, [rsp - 16]      ; min
    mov     rbx, [rsp - 8]       ; max
    cmp     rax, MAX_TABLE_ENTRIES
    ja      .unsupported
    test    rbx, rbx
    jz      .table_ok
    cmp     rbx, MAX_TABLE_ENTRIES
    ja      .unsupported
.table_ok:
    mov     [imported_table_min], rax
    mov     [imported_table_max], rbx
    mov     byte [table_has], 1
    mov     [table_min], rax
    mov     [table_max], rbx
    jmp     .import_next

.import_next:
    inc     qword [import_count]
    inc     r13
    jmp     .import_loop

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Function section parser
; =================================================================+
er_wasm_parse_function_section:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     rbx, rax            ; rbx = count
    cmp     rbx, MAX_FUNCTIONS
    ja      .unsupported
    ; Check import_count + count <= MAX_FUNCTIONS
    mov     rax, [import_count]
    add     rax, rbx
    cmp     rax, MAX_FUNCTIONS
    ja      .unsupported
    mov     [function_count], rbx

    xor     r11d, r11d          ; index
.func_loop:
    cmp     r11, rbx
    jae     .done
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    ; Verify type_index < type_count
    cmp     rax, [type_count]
    jae     .corrupt
    ; Store Function { type_index, code_index = index }
    push    r10
    mov     r10, r11
    imul    r10, FUNCTION_SIZE
    mov     [functions_buf + r10], rax       ; type_index
    mov     [functions_buf + r10 + 8], r11   ; code_index
    pop     r10
    inc     r11
    jmp     .func_loop

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Table section parser
; =================================================================+
er_wasm_parse_table_section:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     rax, 1
    ja      .unsupported
    test    rax, rax
    jz      .done               ; count == 0, nothing to parse

    cmp     byte [imported_table_present], 1
    je      .corrupt

    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported

    lea     rcx, [rsp - 16]
    call    er_wasm_read_limits
    test    edx, edx
    jnz     .error
    mov     rax, [rsp - 16]     ; min
    mov     rbx, [rsp - 8]      ; max
    cmp     rax, MAX_TABLE_ENTRIES
    ja      .unsupported
    test    rbx, rbx
    jz      .table_ok
    cmp     rbx, MAX_TABLE_ENTRIES
    ja      .unsupported
.table_ok:
    mov     byte [table_has], 1
    mov     [table_min], rax
    mov     [table_max], rbx

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Memory section parser
; =================================================================+
er_wasm_parse_memory_section:
    push    rbp
    mov     rbp, rsp

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     rax, 1
    ja      .unsupported
    test    rax, rax
    jz      .done

    cmp     byte [imported_memory_present], 1
    je      .corrupt

    lea     rcx, [memory_min_pages]
    call    er_wasm_read_limits
    test    edx, edx
    jnz     .error

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     rbp
    ret

; ==================================================================
; Export section parser
; =================================================================+
er_wasm_parse_export_section:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     rbx, rax
    cmp     rbx, MAX_FUNCTIONS
    ja      .unsupported
    mov     [export_count], rbx

    xor     r14d, r14d
.export_loop:
    cmp     r14, rbx
    jae     .done

    ; Read name
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r13, rsi            ; save name start
    mov     r15, rax            ; save name length in r15
    add     rsi, rax            ; skip name

    ; Read kind
    movzx   r11d, byte [rsi]
    inc     rsi

    ; Read index
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    ; Store export
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10], r13      ; name ptr
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10 + 8], r15   ; name length
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10 + 16], r11b ; kind
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10 + 24], rax  ; index
        pop     r10

    inc     r14
    jmp     .export_loop

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Start section parser
; =================================================================+
er_wasm_parse_start_section:
    push    rbp
    mov     rbp, rsp

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [start_function_index], rax
    mov     r12, rsi
    xor     edx, edx
    pop     rbp
    ret
.error:
    mov     edx, edx
    pop     rbp
    ret

; ==================================================================
; Data count section parser
; =================================================================+
er_wasm_parse_data_count_section:
    push    rbp
    mov     rbp, rsp

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     rax, MAX_DATA_SEGMENTS
    ja      .unsupported
    mov     [declared_data_count], rax
    mov     r12, rsi
    xor     edx, edx
    pop     rbp
    ret
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    pop     rbp
    ret
.error:
    mov     edx, edx
    pop     rbp
    ret

; ==================================================================
; Code section parser (most complex — also decodes ops)
; =================================================================+
er_wasm_parse_code_section:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     rbx, rax            ; count
    cmp     rbx, [function_count]
    jne     .corrupt
    cmp     rbx, MAX_FUNCTIONS
    ja      .corrupt
    mov     [code_count], rbx

    xor     r14d, r14d          ; function index
.code_loop:
    cmp     r14, rbx
    jae     .done

    ; Read body size
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r15, rsi            ; r15 = body start
    add     r15, rax            ; r15 = body end (for bounds check)
    ; For now we use rsi as the reader into the body

    ; Read local group count
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r13, rax            ; local_group_count

    ; Store code entry: body_offset(8) + body_len(8) + local_count(8)
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10], rsi         ; body_offset (pointer into wasm bytes)
        pop     r10
    ; body_len = r15 - rsi (computed later after locals)
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 16], r13    ; local_group_count (reuse field — will convert to local_count after processing)
        pop     r10

    ; Parse local groups
    xor     r11d, r11d          ; total local count
.local_group_loop:
    test    r13, r13
    jz      .locals_done
    dec     r13

    ; Read repeat count
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r12, rax            ; repeat count

    ; Read value type
    call    er_wasm_read_value_type
    test    edx, edx
    jnz     .error
    mov     r9b, al             ; type byte

    ; Verify local_count + repeat <= MAX_LOCALS
    mov     rax, r11
    add     rax, r12
    cmp     rax, MAX_LOCALS
    ja      .unsupported

    ; Fill local_types
    mov     rdi, code_local_types
    imul    r10, r14, MAX_LOCALS
    add     rdi, r10
    xor     r10d, r10d
.repeat_loop:
    cmp     r10, r12
    jae     .repeat_done
    mov     [rdi + r11], r9b
    inc     r11
    inc     r10
    jmp     .repeat_loop
.repeat_done:
    jmp     .local_group_loop

.locals_done:
    ; Store local count
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 16], r11    ; local_count
        pop     r10
    ; Store body end pointer - start = body length
    mov     rax, r15
    sub     rax, rsi
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 8], rax     ; body_len
        pop     r10
    ; Store decoded_start = current decoded_op_count
    mov     rax, [decoded_op_count]
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 24], rax    ; decoded_start
        pop     r10
    ; Decode the body
    push    r14
    push    r15
    mov     r12, rsi            ; body start for decoder
    ; We need the body bytes — already at rsi, length = r15 - rsi
    mov     rax, r15
    sub     rax, rsi
    mov     rdi, rsi            ; body ptr
    mov     rsi, rax            ; body len
    call    er_wasm_decode_body
    pop     r15
    pop     r14
    test    edx, edx
    jnz     .error
    ; Store decoded_count = decoded_op_count - decoded_start
    mov     rax, [decoded_op_count]
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    sub     rax, [code_buf + r10 + 24]
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 32], rax  ; decoded_count
        pop     r10
    mov     rsi, r15
    inc     r14
    jmp     .code_loop

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Global section parser
; =================================================================+
er_wasm_parse_global_section:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     rbx, rax
    mov     rax, [global_count]
    add     rax, rbx
    cmp     rax, MAX_GLOBALS
    ja      .unsupported

    xor     r13d, r13d
.global_loop:
    cmp     r13, rbx
    jae     .done

    ; Read value type
    call    er_wasm_read_value_type
    test    edx, edx
    jnz     .error
    push    rax                 ; save value_type

    ; Read mutability
    movzx   r11d, byte [rsi]
    inc     rsi
    cmp     r11b, 1
    ja      .corrupt

    ; Read constant expression
    pop     rdi                 ; value_type for read_constant
    call    er_wasm_read_constant_value
    test    edx, edx
    jnz     .error

    ; Store global
    mov     rdi, [global_count]
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10], al      ; value_type (from read_value_type — need to save properly)
        pop     r10
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10 + 1], r11b ; mutable
        pop     r10
    ; value stored in rax
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10 + 8], rax  ; value_data
        pop     r10
    inc     qword [global_count]
    inc     r13
    jmp     .global_loop

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.corrupt:
    mov     edx, ERROR_CORRUPT
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Helper: er_wasm_read_constant_value
; Reads a constant value expression from [rsi] for the given value_type (in rdi).
; Returns value in rax.
; =================================================================+
er_wasm_read_constant_value:
    push    rbp
    mov     rbp, rsp
    push    rbx

    movzx   eax, byte [rsi]
    inc     rsi
    mov     rbx, rax            ; opcode

    cmp     dil, VALUE_TAG_I32
    je      .read_i32
    cmp     dil, VALUE_TAG_I64
    je      .read_i64
    cmp     dil, VALUE_TAG_F32
    je      .read_f32
    cmp     dil, VALUE_TAG_F64
    je      .read_f64
    cmp     dil, VALUE_TAG_FUNCREF
    je      .read_funcref
    jmp     .unsupported

.read_i32:
    cmp     bl, 0x41            ; i32.const
    jne     .unsupported
    call    er_wasm_read_leb_i32
    test    edx, edx
    jnz     .error
    push    rax
    jmp     .check_end
.read_i64:
    cmp     bl, 0x42            ; i64.const
    jne     .unsupported
    call    er_wasm_read_leb_i64
    test    edx, edx
    jnz     .error
    push    rax
    jmp     .check_end
.read_f32:
    cmp     bl, 0x43            ; f32.const
    jne     .unsupported
    mov     eax, [rsi]
    add     rsi, 4
    push    rax
    jmp     .check_end
.read_f64:
    cmp     bl, 0x44            ; f64.const
    jne     .unsupported
    mov     rax, [rsi]
    add     rsi, 8
    push    rax
    jmp     .check_end
.read_funcref:
    cmp     bl, 0xd0            ; ref.null
    je      .ref_null
    cmp     bl, 0xd2            ; ref.func
    je      .ref_func
    jmp     .unsupported
.ref_null:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported
    push    0                   ; null = 0
    jmp     .check_end
.ref_func:
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    push    rax
    jmp     .check_end

.check_end:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x0b            ; end
    jne     .unsupported
    pop     rax
    xor     edx, edx
    jmp     .done

.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    pop     rbx
    pop     rbp
    ret
.error:
    mov     edx, edx
.done:
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Element section parser (stub for now — full implementation)
; =================================================================+
er_wasm_parse_element_section:
    ; TODO: full element section parsing
    push    rbp
    mov     rbp, rsp
    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r12, rsi            ; skip for now
    xor     edx, edx
    pop     rbp
    ret
.error:
    mov     edx, edx
    pop     rbp
    ret

; ==================================================================
; Data section parser
; =================================================================+
er_wasm_parse_data_section:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     rsi, r12
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r12, rax
    cmp     r12, MAX_DATA_SEGMENTS
    ja      .unsupported
    mov     [data_segment_count], r12

    xor     r11d, r11d
.data_loop:
    cmp     r11, r12
    jae     .done

    ; Read mode
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    cmp     eax, 0
    je      .active_0
    cmp     eax, 1
    je      .passive
    cmp     eax, 2
    je      .active_2
    jmp     .unsupported

.active_0:
    ; mode 0: active, memory 0 implicit
    call    er_wasm_read_constant_i32
    test    edx, edx
    jnz     .error
    push    rax                 ; offset
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     rcx, rax            ; byte count
    pop     rdx                 ; offset
    ; Store DataSegment
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10], rdx     ; offset
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 8], rsi ; bytes ptr
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 16], rcx ; bytes len
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 24], 1  ; active
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 25], 0  ; not dropped
        pop     r10
    add     rsi, rcx
    jmp     .next

.passive:
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 8], rsi  ; bytes ptr
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 16], rax ; bytes len
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 24], 0  ; not active
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 25], 0
        pop     r10
    add     rsi, rax
    jmp     .next

.active_2:
    ; mode 2: active with explicit memory index
    call    er_wasm_read_leb_u32  ; read and ignore memory index (must be 0)
    test    edx, edx
    jnz     .error
    test    eax, eax
    jnz     .unsupported
    call    er_wasm_read_constant_i32
    test    edx, edx
    jnz     .error
    push    rax                 ; offset
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     rcx, rax
    pop     rdx
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10], rdx
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 8], rsi
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 16], rcx
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 24], 1
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 25], 0
        pop     r10
    add     rsi, rcx
    jmp     .next

.next:
    inc     r11
    jmp     .data_loop

.done:
    mov     r12, rsi
    xor     edx, edx
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Decoded op cache
; er_wasm_decode_body(bytes_ptr=rdi, bytes_len=rsi)
; Decodes opcodes from a function body, populates decoded_ops[]
; =================================================================+
er_wasm_decode_body:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; body start
    mov     r13, rdi
    add     r13, rsi            ; body end
    mov     rsi, rdi            ; rsi = bytecode reader (start at body ptr)
    mov     r14, [decoded_op_count]  ; start index

.decode_loop:
    cmp     rsi, r13
    jae     .done

    mov     r15d, [decoded_op_count]
    cmp     r15d, MAX_DECODED_OPS
    jae     .unsupported

    ; Calculate offset from body start
    mov     rax, rsi
    sub     rax, rdi
    mov     edx, eax            ; offset (low 32 bits)

    ; Read opcode byte
    movzx   r11d, byte [rsi]
    inc     rsi

    ; Store decoded op header
    mov     ebx, r15d
    imul    ebx, DECODED_OP_SIZE
    mov     [decoded_ops + rbx], edx      ; offset
    mov     [decoded_ops + rbx + 8], r11b ; opcode_byte

    ; Handle extended prefix
    cmp     r11b, WASM_EXTENDED_PREFIX
    je      .decode_extended

    ; Decode immediate fields based on opcode
    cmp     r11b, 0x02          ; block
    je      .decode_block_type
    cmp     r11b, 0x03          ; loop
    je      .decode_block_type
    cmp     r11b, 0x04          ; if
    je      .decode_block_type
    cmp     r11b, 0x0c          ; br
    je      .decode_leb
    cmp     r11b, 0x0d          ; br_if
    je      .decode_leb
    cmp     r11b, 0x10          ; call
    je      .decode_leb
    cmp     r11b, 0x20          ; local.get
    je      .decode_leb
    cmp     r11b, 0x21          ; local.set
    je      .decode_leb
    cmp     r11b, 0x22          ; local.tee
    je      .decode_leb
    cmp     r11b, 0x23          ; global.get
    je      .decode_leb
    cmp     r11b, 0x24          ; global.set
    je      .decode_leb
    cmp     r11b, 0x25          ; table.get
    je      .decode_table
    cmp     r11b, 0x26          ; table.set
    je      .decode_table
    cmp     r11b, 0x28          ; i32.load
    je      .decode_mem
    cmp     r11b, 0x29          ; i64.load
    je      .decode_mem
    cmp     r11b, 0x2a          ; f32.load
    je      .decode_mem
    cmp     r11b, 0x2b          ; f64.load
    je      .decode_mem
    cmp     r11b, 0x2c          ; i32.load8_s
    je      .decode_mem
    cmp     r11b, 0x2d          ; i32.load8_u
    je      .decode_mem
    cmp     r11b, 0x2e          ; i32.load16_s
    je      .decode_mem
    cmp     r11b, 0x2f          ; i32.load16_u
    je      .decode_mem
    cmp     r11b, 0x30          ; i64.load8_s
    je      .decode_mem
    cmp     r11b, 0x31          ; i64.load8_u
    je      .decode_mem
    cmp     r11b, 0x32          ; i64.load16_s
    je      .decode_mem
    cmp     r11b, 0x33          ; i64.load16_u
    je      .decode_mem
    cmp     r11b, 0x34          ; i64.load32_s
    je      .decode_mem
    cmp     r11b, 0x35          ; i64.load32_u
    je      .decode_mem
    cmp     r11b, 0x36          ; i32.store
    je      .decode_mem
    cmp     r11b, 0x37          ; i64.store
    je      .decode_mem
    cmp     r11b, 0x38          ; f32.store
    je      .decode_mem
    cmp     r11b, 0x39          ; f64.store
    je      .decode_mem
    cmp     r11b, 0x3a          ; i32.store8
    je      .decode_mem
    cmp     r11b, 0x3b          ; i32.store16
    je      .decode_mem
    cmp     r11b, 0x3c          ; i64.store8
    je      .decode_mem
    cmp     r11b, 0x3d          ; i64.store16
    je      .decode_mem
    cmp     r11b, 0x3e          ; i64.store32
    je      .decode_mem
    cmp     r11b, 0x3f          ; memory.size
    je      .decode_memidx
    cmp     r11b, 0x40          ; memory.grow
    je      .decode_memidx
    cmp     r11b, 0x41          ; i32.const
    je      .decode_i32_const
    cmp     r11b, 0x42          ; i64.const
    je      .decode_i64_const
    cmp     r11b, 0x43          ; f32.const
    je      .decode_f32_const
    cmp     r11b, 0x44          ; f64.const
    je      .decode_f64_const
    cmp     r11b, 0x11          ; call_indirect
    je      .decode_call_indirect
    cmp     r11b, 0x1c          ; select_typed
    je      .decode_select_typed
    cmp     r11b, 0xd0          ; ref.null
    je      .decode_ref_null
    cmp     r11b, 0xd2          ; ref.func
    je      .decode_leb
    cmp     r11b, 0x0e          ; br_table
    je      .decode_br_table

    ; Store next_offset for opcodes with no immediates
    mov     eax, esi
    sub     eax, edi            ; relative to body start
    mov     [decoded_ops + rbx + 4], eax  ; next_offset

    inc     dword [decoded_op_count]
    jmp     .decode_loop

    ; --- decode immediate handlers ---
.decode_leb:
    ; Read single LEB128 u32 into imm0
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax   ; next_offset
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_mem:
    ; Read alignment + offset (two LEB128 u32s)
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = alignment
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 16], eax  ; imm1 = offset
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax   ; next_offset
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_memidx:
    ; Read memory index (must be 0)
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    test    eax, eax
    jnz     .unsupported
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_i32_const:
    call    er_wasm_read_leb_i32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = value (as bit pattern)
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_i64_const:
    call    er_wasm_read_leb_i64
    test    edx, edx
    jnz     .error
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_f32_const:
    mov     eax, [rsi]
    add     rsi, 4
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = f32 bits
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_f64_const:
    mov     eax, esi
    add     rsi, 8
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_block_type:
    ; Read block type (1 byte or LEB128 type index)
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_EMPTY_BLOCK_TYPE
    je      .block_done
    ; Check if it's a value type
    cmp     al, VALUE_TAG_I32
    je      .block_done
    cmp     al, VALUE_TAG_I64
    je      .block_done
    cmp     al, VALUE_TAG_F32
    je      .block_done
    cmp     al, VALUE_TAG_F64
    je      .block_done
    cmp     al, VALUE_TAG_FUNCREF
    je      .block_done
    ; It's a type index (LEB128 starting with this byte)
    ; Continue reading as LEB128
    dec     rsi                 ; put back the byte
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
.block_done:
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_call_indirect:
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = type_index
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 16], eax  ; imm1 = table_index
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_select_typed:
    call    er_wasm_read_leb_u32  ; type count
    test    edx, edx
    jnz     .error
    cmp     eax, 1
    jne     .unsupported
    call    er_wasm_read_value_type
    test    edx, edx
    jnz     .error
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_table:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_ref_null:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_br_table:
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     r11d, eax           ; target count
    xor     r10d, r10d
.br_table_loop:
    cmp     r10, r11
    jae     .br_table_done
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    inc     r10
    jmp     .br_table_loop
.br_table_done:
    call    er_wasm_read_leb_u32  ; default target
    test    edx, edx
    jnz     .error
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_extended:
    ; Read extended opcode
    call    er_wasm_read_leb_u32
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = extended opcode
    ; Skip immediate fields based on extended opcode
    cmp     eax, EXT_MEMORY_INIT
    je      .ext_mem_init
    cmp     eax, EXT_DATA_DROP
    je      .ext_data_drop
    cmp     eax, EXT_MEMORY_COPY
    je      .ext_mem_copy
    cmp     eax, EXT_MEMORY_FILL
    je      .ext_mem_fill
    cmp     eax, EXT_TABLE_INIT
    je      .ext_table_init
    cmp     eax, EXT_ELEM_DROP
    je      .ext_elem_drop
    cmp     eax, EXT_TABLE_COPY
    je      .ext_table_copy
    cmp     eax, EXT_TABLE_GROW
    je      .ext_table_grow
    cmp     eax, EXT_TABLE_SIZE
    je      .ext_table_size
    cmp     eax, EXT_TABLE_FILL
    je      .ext_table_fill
    ; trunc_sat variants have no immediates
    jmp     .ext_done

.ext_mem_init:
    call    er_wasm_read_leb_u32  ; data segment index
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; memory index (must be 0)
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_data_drop:
    call    er_wasm_read_leb_u32  ; data segment index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_mem_copy:
    call    er_wasm_read_leb_u32  ; memory index (dst)
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; memory index (src)
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_mem_fill:
    call    er_wasm_read_leb_u32  ; memory index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_init:
    call    er_wasm_read_leb_u32  ; element segment index
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_elem_drop:
    call    er_wasm_read_leb_u32  ; element segment index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_copy:
    call    er_wasm_read_leb_u32  ; table index (dst)
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; table index (src)
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_grow:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_size:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_fill:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_done:
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.done:
    xor     edx, edx
    jmp     .out
.unsupported:
    mov     edx, ERROR_UNSUPPORTED
    mov     eax, edx
    jmp     .out
.error:
    mov     eax, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Missing BSS variables referenced by parsers
; =================================================================+
SECTION .bss
debug_section_id:  resb 1
debug_check:       resq 4
memory_min_pages:  resq 1
memory_max_pages:  resq 1
has_memory:        resb 1
start_function_index: resq 1

SECTION .text

; ==================================================================
; Apply data segments — copy data segment bytes into runtime memory
; er_wasm_apply_data_segments(memory_ptr=rdi, memory_pages=rsi)
; =================================================================+
er_wasm_apply_data_segments:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; memory_ptr
    ; Convert pages to bytes
    mov     rdi, rsi
    call    er_wasm_pages_to_bytes
    test    edx, edx
    jnz     .error
    mov     r13, rax            ; memory limit in bytes

    xor     r11d, r11d          ; segment index
.seg_loop:
    cmp     r11, [data_segment_count]
    jae     .done

    ; Check if active
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    cmp     byte [data_segments + r10 + 24], 0  ; active flag
        pop     r10
    je      .next

    ; offset + bytes_len <= limit?
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     rdx, [data_segments + r10]       ; offset
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     rcx, [data_segments + r10 + 16]  ; byte count
        pop     r10
    mov     rax, rdx
    add     rax, rcx
    jc      .nomemory
    cmp     rax, r13
    ja      .nomemory
    cmp     rax, [runtime_memory_len]
    ja      .nomemory

    ; Copy bytes: memcpy(memory + offset, segment_bytes, count)
    mov     rdi, r12
    add     rdi, rdx
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     rsi, [data_segments + r10 + 8]  ; bytes ptr
        pop     r10
    mov     rdx, rcx
    call    er_memcpy

.next:
    inc     r11
    jmp     .seg_loop

.done:
    xor     eax, eax
    jmp     .out
.nomemory:
    mov     eax, ERROR_NO_MEMORY
    jmp     .out
.error:
    mov     eax, edx
.out:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Find export by name
; er_wasm_find_export(name_ptr=rdi, name_len=rsi)
; Returns export index in rax, or error in rdx
; =================================================================+
er_wasm_find_export:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; name ptr
    mov     r13, rsi            ; name len

    xor     r11d, r11d
.search_loop:
    cmp     r11, [export_count]
    jae     .not_found

    push    r11
    ; Compare export name
    push    r10
        mov     r10, r11
        imul    r10, EXPORT_SIZE
    mov     rdi, [exports_buf + r10]  ; name ptr
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, EXPORT_SIZE
    mov     rsi, [exports_buf + r10 + 8]  ; name len (need to save this)
        pop     r10
    ; TODO: proper name length storage
    ; For now, compare using the name in the exports buf
    mov     rdx, r12
    mov     rcx, r13
    call    er_wasm_eql
    pop     r11
    test    rax, rax
    jnz     .found

    inc     r11
    jmp     .search_loop

.found:
    mov     rax, r11
    xor     edx, edx
    jmp     .done
.not_found:
    mov     edx, ERROR_MISSING_EXPORT
    xor     eax, eax
.done:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Type index for function
; er_wasm_type_index_for_function(function_index=rdi)
; Returns type_index in rax, error in rdx
; =================================================================+
er_wasm_type_index_for_function:
    push    rbp
    mov     rbp, rsp

    ; Check if imported function
    mov     rsi, [import_count]
    cmp     rdi, rsi
    jae     .defined

    ; Imported: return imports[function_index].type_index
    push    r10
        mov     r10, rdi
        imul    r10, IMPORTED_FUNC_SIZE
    mov     rax, [imports_buf + r10 + 32]  ; type_index
        pop     r10
    xor     edx, edx
    pop     rbp
    ret

.defined:
    ; Defined function
    sub     rdi, rsi            ; subtract import count
    cmp     rdi, [function_count]
    jae     .corrupt
    push    r10
    mov     r10, rdi
    imul    r10, FUNCTION_SIZE
    mov     rax, [functions_buf + r10]  ; type_index
    pop     r10
    xor     edx, edx
    pop     rbp
    ret

.corrupt:
    mov     edx, ERROR_CORRUPT
    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Code index for function  
; er_wasm_code_index_for_function(function_index=rdi)
; Returns code_index in rax, error in rdx
; =================================================================+
er_wasm_code_index_for_function:
    push    rbp
    mov     rbp, rsp

    mov     rsi, [import_count]
    cmp     rdi, rsi
    jb      .missing_import

    sub     rdi, rsi
    cmp     rdi, [function_count]
    jae     .corrupt

    push    r10
    mov     r10, rdi
    imul    r10, FUNCTION_SIZE
    mov     rax, [functions_buf + r10 + 8]  ; code_index
    pop     r10
    xor     edx, edx
    pop     rbp
    ret

.missing_import:
    mov     edx, ERROR_MISSING_IMPORT
    xor     eax, eax
    pop     rbp
    ret
.corrupt:
    mov     edx, ERROR_CORRUPT
    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Frame (per-function-call state) operations
; The Frame is stored in a dedicated BSS area since only one call
; is active at a time (we don't need the full call depth — we use
; a call stack area for that)
; =================================================================+

; -- Frame state (current invocation)
SECTION .bss
frame_locals:    resb MAX_LOCALS * 16  ; 1024 Values * 16 bytes each = 16KB
frame_stack:     resb MAX_STACK * 16   ; 32 Values * 16 bytes = 512 bytes
frame_stack_len: resq 1
SECTION .text

; ==================================================================
; Pop value from frame stack
; Returns value in rax
; =================================================================+
er_fn er_fn_pop
    push    rbp
    mov     rbp, rsp

    mov     rax, [frame_stack_len]
    test    rax, rax
    jz      .underflow

    dec     rax
    mov     [frame_stack_len], rax

    ; Load value data (16 bytes per entry)
    shl     rax, 4
    mov     rax, [frame_stack + rax]      ; value data
    pop     rbp
    ret

.underflow:
    mov     rax, -1
    pop     rbp
    ret

; ==================================================================
; Push value to frame stack
; rdi = value data
; =================================================================+
er_fn er_fn_push
    push    rbp
    mov     rbp, rsp

    mov     rax, [frame_stack_len]
    cmp     rax, MAX_STACK
    jae     .overflow

    shl     rax, 4
    mov     [frame_stack + rax], rdi      ; value data

    inc     qword [frame_stack_len]
    xor     eax, eax
    pop     rbp
    ret

.overflow:
    mov     rax, -1
    pop     rbp
    ret

; ==================================================================
; Executor entry point
; er_fn_run(runtime_ptr=rdi, wasm_bytes_ptr=rsi, wasm_bytes_len=rdx, export_name_ptr=rcx, export_name_len=r8)
; =================================================================+
; ==================================================================
; Frame save/restore helpers
; =================================================================+

; Save current frame state onto exec_frame_save area
; Clobbers: rax, rcx
; Returns: carry set if save area overflow
er_fn exec_save_frame_state
    push    rbp
    mov     rbp, rsp

    mov     rax, [exec_frame_save_ptr]
    mov     rcx, [exec_local_count]

    ; Check space: local_count*8 + stack_len*8 + control_len*16 + 40 <= FRAME_SAVE_SIZE - save_ptr
    push    rcx
    imul    rcx, 8
    add     rax, rcx
    pop     rcx
    mov     rcx, [exec_stack_len]
    shl     rcx, 3
    add     rax, rcx
    mov     rcx, [exec_control_len]
    imul    rcx, CONTROL_FRAME_SIZE
    add     rax, rcx
    add     rax, 40
    cmp     rax, FRAME_SAVE_SIZE
    ja      .overflow

    ; Push locals: exec_locals[0..local_count] onto save area
    mov     rcx, [exec_local_count]
    test    rcx, rcx
    jz      .save_stack
    mov     rax, exec_locals
    mov     rdx, [exec_frame_save_ptr]
.save_locals_loop:
    mov     r8, [rax]
    mov     [exec_frame_save + rdx], r8
    add     rax, 8
    add     rdx, 8
    dec     rcx
    jnz     .save_locals_loop
    mov     [exec_frame_save_ptr], rdx

.save_stack:
    ; Push stack entries
    mov     rcx, [exec_stack_len]
    test    rcx, rcx
    jz      .save_control
    mov     rax, exec_stack
    mov     rdx, [exec_frame_save_ptr]
.save_stack_loop:
    mov     r8, [rax]
    mov     [exec_frame_save + rdx], r8
    add     rax, 8
    add     rdx, 8
    dec     rcx
    jnz     .save_stack_loop
    mov     [exec_frame_save_ptr], rdx

.save_control:
    ; Push control frames
    mov     rcx, [exec_control_len]
    test    rcx, rcx
    jz      .save_meta
    mov     rax, exec_control
    mov     rdx, [exec_frame_save_ptr]
.save_control_loop:
    mov     r8, [rax]
    mov     r9, [rax + 8]
    mov     [exec_frame_save + rdx], r8
    mov     [exec_frame_save + rdx + 8], r9
    add     rax, CONTROL_FRAME_SIZE
    add     rdx, CONTROL_FRAME_SIZE
    dec     rcx
    jnz     .save_control_loop
    mov     [exec_frame_save_ptr], rdx

.save_meta:
    ; Push metadata: local_count, stack_len, control_len, dec_idx, dec_end
    mov     rdx, [exec_frame_save_ptr]
    mov     rax, [exec_local_count]
    mov     [exec_frame_save + rdx], rax
    mov     rax, [exec_stack_len]
    mov     [exec_frame_save + rdx + 8], rax
    mov     rax, [exec_control_len]
    mov     [exec_frame_save + rdx + 16], rax
    mov     rax, [exec_decoded_index]
    mov     [exec_frame_save + rdx + 24], rax
    mov     rax, [exec_decoded_end]
    mov     [exec_frame_save + rdx + 32], rax
    add     qword [exec_frame_save_ptr], 40
    clc
    pop     rbp
    ret

.overflow:
    mov     edx, ERROR_NO_MEMORY
    stc
    pop     rbp
    ret

; Restore frame state from exec_frame_save area
; Clobbers: rax, rcx
er_fn exec_restore_frame_state
    push    rbp
    mov     rbp, rsp

    ; First read metadata at the end
    mov     rax, [exec_frame_save_ptr]
    sub     rax, 40
    mov     rcx, [exec_frame_save + rax]
    mov     [exec_local_count], rcx
    mov     rcx, [exec_frame_save + rax + 8]
    mov     [exec_stack_len], rcx
    mov     rcx, [exec_frame_save + rax + 16]
    mov     [exec_control_len], rcx
    mov     rcx, [exec_frame_save + rax + 24]
    mov     [exec_decoded_index], rcx
    mov     rcx, [exec_frame_save + rax + 32]
    mov     [exec_decoded_end], rcx
    mov     [exec_frame_save_ptr], rax

    ; Pop control frames
    mov     rcx, [exec_control_len]
    test    rcx, rcx
    jz      .rest_stack
    mov     rdx, [exec_frame_save_ptr]
.rest_control_loop:
    sub     rdx, CONTROL_FRAME_SIZE
    mov     r8, [exec_frame_save + rdx]
    mov     r9, [exec_frame_save + rdx + 8]
    mov     rax, exec_control
    add     rax, rcx
    sub     rax, CONTROL_FRAME_SIZE
    mov     [rax], r8
    mov     [rax + 8], r9
    dec     rcx
    jnz     .rest_control_loop
    mov     [exec_frame_save_ptr], rdx

.rest_stack:
    ; Pop stack entries
    mov     rcx, [exec_stack_len]
    test    rcx, rcx
    jz      .rest_locals
    mov     rdx, [exec_frame_save_ptr]
.rest_stack_loop:
    sub     rdx, 8
    mov     r8, [exec_frame_save + rdx]
    mov     rax, exec_stack
    add     rax, rcx
    sub     rax, 8
    mov     [rax], r8
    dec     rcx
    jnz     .rest_stack_loop
    mov     [exec_frame_save_ptr], rdx

.rest_locals:
    ; Pop locals
    mov     rcx, [exec_local_count]
    test    rcx, rcx
    jz      .done_rest
    mov     rdx, [exec_frame_save_ptr]
.rest_locals_loop:
    sub     rdx, 8
    mov     r8, [exec_frame_save + rdx]
    mov     rax, exec_locals
    add     rax, rcx
    sub     rax, 8
    mov     [rax], r8
    dec     rcx
    jnz     .rest_locals_loop
    mov     [exec_frame_save_ptr], rdx

.done_rest:
    xor     edx, edx
    pop     rbp
    ret

; ==================================================================
; Stack operations
; =================================================================+

; Pop a value from exec_stack into rax
; Returns carry set on underflow
er_fn exec_stack_pop
    push    rbp
    mov     rbp, rsp
    mov     rax, [exec_stack_len]
    test    rax, rax
    jz      .underflow
    dec     rax
    mov     [exec_stack_len], rax
    mov     rax, [exec_stack + rax * 8]
    clc
    pop     rbp
    ret
.underflow:
    mov     eax, ERROR_STACK_UNDERFLOW
    mov     edx, ERROR_STACK_UNDERFLOW
    stc
    pop     rbp
    ret

; Push rax onto exec_stack
; Returns carry set on overflow
er_fn exec_stack_push
    push    rbp
    mov     rbp, rsp
    mov     rcx, [exec_stack_len]
    cmp     rcx, MAX_STACK
    jae     .overflow
    mov     [exec_stack + rcx * 8], rax
    inc     qword [exec_stack_len]
    clc
    pop     rbp
    ret
.overflow:
    mov     eax, ERROR_STACK_OVERFLOW
    mov     edx, ERROR_STACK_OVERFLOW
    stc
    pop     rbp
    ret

; Peek at stack top (no pop)
; Returns value in rax
er_fn exec_stack_peek
    mov     rax, [exec_stack_len]
    test    rax, rax
    jz      .underflow
    mov     rax, [exec_stack + rax * 8 - 8]
    clc
    ret
.underflow:
    stc
    ret

; Duplicate stack top
er_fn exec_stack_dup
    push    rbp
    mov     rbp, rsp
    call    exec_stack_peek
    jc      .done
    call    exec_stack_push
.done:
    pop     rbp
    ret

; ==================================================================
; Error handler
; Sets error code and returns from enclosing function
; Expects error code in rdx
; =================================================================+
er_fn exec_error
    pop     rbp         ; pop return address of the caller
    pop     rbp         ; restore parent frame
    ret

; ==================================================================
; Read current reader byte without advancing
; =================================================================+
er_fn reader_peek_byte
    mov     rax, [exec_reader_offset]
    cmp     rax, [exec_code_body_len]
    jae     .done
    mov     rsi, [exec_code_body_ptr]
    mov     al, [rsi + rax]
    xor     edx, edx
    clc
    ret
.done:
    stc
    ret

; Advance reader by amount in rdi
er_fn reader_advance
    mov     rax, [exec_reader_offset]
    add     rax, rdi
    mov     [exec_reader_offset], rax
    ret

; Read a byte from reader and advance
; Returns byte in al, carry set if past end
er_fn reader_read_byte
    push    rbp
    mov     rbp, rsp
    call    reader_peek_byte
    jc      .done
    inc     qword [exec_reader_offset]
    clc
.done:
    pop     rbp
    ret

; ==================================================================
; Set up frame for a function
; rdi = function_index
; rsi = args pointer (array of int64)
; rdx = args count
; =================================================================+
er_fn er_fn_exec
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; function_index
    mov     r13, rsi        ; args ptr
    mov     r14, rdx        ; args count

    ; Check call depth
    mov     rax, [exec_call_depth]
    cmp     rax, MAX_CALL_DEPTH
    jae     .depth_error

    ; Save current frame if we have locals
    cmp     qword [exec_local_count], 0
    je      .no_save
    call    exec_save_frame_state
    jc      .depth_error
.no_save:
    inc     qword [exec_call_depth]

    ; Check if imported function
    mov     rax, r12
    cmp     rax, [import_count]
    jb      .imported_func

    ; Defined function
    sub     r12, [import_count]    ; defined_index
    mov     rdi, r12
    call    er_wasm_code_index_for_function
    test    rdx, rdx
    jnz     .error

    mov     r15, rax               ; code_index

    ; Get code info
    ; Code struct: body_offset(8) + body_len(8) + local_count(8) + decoded_start(8) + decoded_count(8)
    push    r10
    mov     r10, r15
    imul    r10, CODE_SIZE
    mov     rax, [code_buf + r10]      ; body_offset (from code body start)
    mov     [exec_code_body_ptr], rax
    mov     rax, [code_buf + r10 + 8]  ; body_len
    mov     [exec_code_body_len], rax
    mov     rax, [code_buf + r10 + 16] ; local_count
    mov     rbx, rax                   ; local_count
    mov     rax, [code_buf + r10 + 24] ; decoded_start
    mov     [exec_decoded_index], rax
    mov     rax, [code_buf + r10 + 32] ; decoded_count
    mov     [exec_decoded_end], rax
    pop     r10

    ; Get function type
    mov     rdi, r12
    add     rdi, [import_count]
    call    er_wasm_type_index_for_function
    test    rdx, rdx
    jnz     .error
    ; Store type info for result handling
    mov     [exec_type_index], rax

    ; param_count + result_count from FuncType
    push    r10
    mov     r10, rax
    imul    r10, FUNC_TYPE_SIZE
    mov     rax, [types_buf + r10 + FUNC_TYPE_PARAM_COUNT_OFF]  ; param_count
    mov     rcx, rax
    mov     rax, [types_buf + r10 + FUNC_TYPE_RESULT_COUNT_OFF] ; result_count
    mov     [exec_result_count], rax
    pop     r10

    ; Local count = param_count + code local_count
    ; The code local_count is the number of zero-initialized locals after params
    ; rbx already has local_count from code struct
    mov     rax, rcx     ; param_count
    add     rax, rbx     ; + code local_count
    mov     [exec_local_count], rax
    cmp     rax, MAX_LOCALS
    ja      .unsupported_error

    ; Initialize locals from args
    xor     r15d, r15d
.init_locals_loop:
    cmp     r15, rcx     ; param_count
    jae     .init_zero
    ; Copy arg
    mov     rax, [r13 + r15 * 8]
    mov     [exec_locals + r15 * 8], rax
    inc     r15
    jmp     .init_locals_loop
.init_zero:
    ; Zero remaining locals
    cmp     r15, [exec_local_count]
    jae     .init_done
    mov     qword [exec_locals + r15 * 8], 0
    inc     r15
    jmp     .init_zero
.init_done:
    ; Clear value stack and control stack
    mov     qword [exec_stack_len], 0
    mov     qword [exec_control_len], 0
    mov     qword [exec_reader_offset], 0

    ; Enter dispatch loop
    call    exec_dispatch_loop

    ; Restore error state
    mov     r15, rax      ; save return value
    mov     r14, rdx      ; save error code

    ; Decrement call depth
    dec     qword [exec_call_depth]

    ; Restore previous frame
    call    exec_restore_frame_state

    mov     rax, r15
    mov     rdx, r14
    jmp     .done

.imported_func:
    ; Imported function - call through host import dispatch
    call    er_wasm_call_imported
    jmp     .done

.depth_error:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .done
.unsupported_error:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .done
.error:
    ; rdx already set
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Imported function dispatch
; rdi = function_index (absolute, < import_count)
; =================================================================+
er_wasm_call_imported:
    push    rbp
    mov     rbp, rsp
    ; For now, return Unsupported
    mov     edx, ERROR_UNSUPPORTED
    pop     rbp
    ret

; ==================================================================
; Main instruction dispatch loop
; =================================================================+
exec_dispatch_loop:
    push    rbp
    mov     rbp, rsp

.dispatch_next:
    ; Check reader done: reader_offset >= body_len
    mov     rax, [exec_reader_offset]
    cmp     rax, [exec_code_body_len]
    jae     .done

    ; Look up decoded op for current offset
    ; decoded_op_for_offset (rdi=body_ptr, rsi=body_len, rdx=offset)
    ; returns decoded op info or error
    
    ; For now, use a simplified approach: read opcode byte directly
    call    reader_read_byte
    jc      .corrupt_error

    movzx   ebx, al          ; opcode byte in bl
    mov     r12d, ebx        ; save opcode byte

    ; Check for extended prefix (0xfc)
    cmp     bl, WASM_EXTENDED_PREFIX
    je      .extended_opcode

    ; Check for hot opcodes that are handled inline
    cmp     bl, 0x20         ; local.get
    je      .op_local_get
    cmp     bl, 0x21         ; local.set
    je      .op_local_set
    cmp     bl, 0x22         ; local.tee
    je     .op_local_tee
    cmp     bl, 0x41         ; i32.const
    je     .op_i32_const
    cmp     bl, 0x42         ; i64.const
    je     .op_i64_const
    cmp     bl, 0x6a         ; i32.add
    je     .op_i32_add
    cmp     bl, 0x0b         ; end
    je     .op_end
    cmp     bl, 0x0f         ; return
    je     .op_return
    cmp     bl, 0x10         ; call
    je     .op_call
    cmp     bl, 0x0c         ; br
    je     .op_br
    cmp     bl, 0x0d         ; br_if
    je     .op_br_if
    cmp     bl, 0x02         ; block
    je     .op_block
    cmp     bl, 0x03         ; loop
    je     .op_loop
    cmp     bl, 0x04         ; if
    je     .op_if
    cmp     bl, 0x05         ; else
    je     .op_else
    cmp     bl, 0x23         ; global.get
    je     .op_global_get
    cmp     bl, 0x24         ; global.set
    je     .op_global_set
    cmp     bl, 0x1a         ; drop
    je     .op_drop
    cmp     bl, 0x1b         ; select
    je     .op_select
    cmp     bl, 0x46         ; i32.eq
    je     .op_i32_eq
    cmp     bl, 0x47         ; i32.ne
    je     .op_i32_ne
    cmp     bl, 0x48         ; i32.lt_s
    je     .op_i32_lt_s
    cmp     bl, 0x49         ; i32.lt_u
    je     .op_i32_lt_u
    cmp     bl, 0x4a         ; i32.gt_s
    je     .op_i32_gt_s
    cmp     bl, 0x4b         ; i32.gt_u
    je     .op_i32_gt_u
    cmp     bl, 0x4c         ; i32.le_s
    je     .op_i32_le_s
    cmp     bl, 0x4d         ; i32.le_u
    je     .op_i32_le_u
    cmp     bl, 0x4e         ; i32.ge_s
    je     .op_i32_ge_s
    cmp     bl, 0x4f         ; i32.ge_u
    je     .op_i32_ge_u
    cmp     bl, 0x45         ; i32.eqz
    je     .op_i32_eqz
    cmp     bl, 0x6b         ; i32.sub
    je     .op_i32_sub
    cmp     bl, 0x6c         ; i32.mul
    je     .op_i32_mul
    cmp     bl, 0x6d         ; i32.div_s
    je     .op_i32_div_s
    cmp     bl, 0x6e         ; i32.div_u
    je     .op_i32_div_u
    cmp     bl, 0x6f         ; i32.rem_s
    je     .op_i32_rem_s
    cmp     bl, 0x70         ; i32.rem_u
    je     .op_i32_rem_u
    cmp     bl, 0x71         ; i32.and
    je     .op_i32_and
    cmp     bl, 0x72         ; i32.or
    je     .op_i32_or
    cmp     bl, 0x73         ; i32.xor
    je     .op_i32_xor
    cmp     bl, 0x74         ; i32.shl
    je     .op_i32_shl
    cmp     bl, 0x75         ; i32.shr_s
    je     .op_i32_shr_s
    cmp     bl, 0x76         ; i32.shr_u
    je     .op_i32_shr_u
    cmp     bl, 0x77         ; i32.rotl
    je     .op_i32_rotl
    cmp     bl, 0x78         ; i32.rotr
    je     .op_i32_rotr
    cmp     bl, 0x67         ; i32.clz
    je     .op_i32_clz
    cmp     bl, 0x68         ; i32.ctz
    je     .op_i32_ctz
    cmp     bl, 0x69         ; i32.popcnt
    je     .op_i32_popcnt
    cmp     bl, 0x28         ; i32.load
    je     .op_i32_load
    cmp     bl, 0x2c         ; i32.load8_s
    je     .op_i32_load8_s
    cmp     bl, 0x2d         ; i32.load8_u
    je     .op_i32_load8_u
    cmp     bl, 0x2e         ; i32.load16_s
    je     .op_i32_load16_s
    cmp     bl, 0x2f         ; i32.load16_u
    je     .op_i32_load16_u
    cmp     bl, 0x36         ; i32.store
    je     .op_i32_store
    cmp     bl, 0x3a         ; i32.store8
    je     .op_i32_store8
    cmp     bl, 0x3b         ; i32.store16
    je     .op_i32_store16
    cmp     bl, 0x3f         ; memory.size
    je     .op_memory_size
    cmp     bl, 0x40         ; memory.grow
    je     .op_memory_grow
    cmp     bl, 0x11         ; call_indirect
    je     .op_call_indirect
    cmp     bl, 0x0e         ; br_table
    je     .op_br_table
    cmp     bl, 0x25         ; table.get
    je     .op_table_get
    cmp     bl, 0x26         ; table.set
    je     .op_table_set
    cmp     bl, 0x50         ; i64.eqz
    je     .op_i64_eqz
    cmp     bl, 0x51         ; i64.eq
    je     .op_i64_eq
    cmp     bl, 0x52         ; i64.ne
    je     .op_i64_ne
    cmp     bl, 0x53         ; i64.lt_s
    je     .op_i64_lt_s
    cmp     bl, 0x54         ; i64.lt_u
    je     .op_i64_lt_u
    cmp     bl, 0x55         ; i64.gt_s
    je     .op_i64_gt_s
    cmp     bl, 0x56         ; i64.gt_u
    je     .op_i64_gt_u
    cmp     bl, 0x57         ; i64.le_s
    je     .op_i64_le_s
    cmp     bl, 0x58         ; i64.le_u
    je     .op_i64_le_u
    cmp     bl, 0x59         ; i64.ge_s
    je     .op_i64_ge_s
    cmp     bl, 0x5a         ; i64.ge_u
    je     .op_i64_ge_u
    cmp     bl, 0x7c         ; i64.add
    je     .op_i64_add
    cmp     bl, 0x7d         ; i64.sub
    je     .op_i64_sub
    cmp     bl, 0x7e         ; i64.mul
    je     .op_i64_mul
    cmp     bl, 0x7f         ; i64.div_s
    je     .op_i64_div_s
    cmp     bl, 0x80         ; i64.div_u
    je     .op_i64_div_u
    cmp     bl, 0x81         ; i64.rem_s
    je     .op_i64_rem_s
    cmp     bl, 0x82         ; i64.rem_u
    je     .op_i64_rem_u
    cmp     bl, 0x83         ; i64.and
    je     .op_i64_and
    cmp     bl, 0x84         ; i64.or
    je     .op_i64_or
    cmp     bl, 0x85         ; i64.xor
    je     .op_i64_xor
    cmp     bl, 0x86         ; i64.shl
    je     .op_i64_shl
    cmp     bl, 0x87         ; i64.shr_s
    je     .op_i64_shr_s
    cmp     bl, 0x88         ; i64.shr_u
    je     .op_i64_shr_u
    cmp     bl, 0x89         ; i64.rotl
    je     .op_i64_rotl
    cmp     bl, 0x8a         ; i64.rotr
    je     .op_i64_rotr
    cmp     bl, 0x79         ; i64.clz
    je     .op_i64_clz
    cmp     bl, 0x7a         ; i64.ctz
    je     .op_i64_ctz
    cmp     bl, 0x7b         ; i64.popcnt
    je     .op_i64_popcnt
    cmp     bl, 0xa7         ; i32.wrap_i64
    je     .op_i32_wrap_i64
    cmp     bl, 0xac         ; i64.extend_i32_s
    je     .op_i64_extend_i32_s
    cmp     bl, 0xad         ; i64.extend_i32_u
    je     .op_i64_extend_i32_u
    cmp     bl, 0xc0         ; i32.extend8_s
    je     .op_i32_extend8_s
    cmp     bl, 0xc1         ; i32.extend16_s
    je     .op_i32_extend16_s
    cmp     bl, 0xc2         ; i64.extend8_s
    je     .op_i64_extend8_s
    cmp     bl, 0xc3         ; i64.extend16_s
    je     .op_i64_extend16_s
    cmp     bl, 0xc4         ; i64.extend32_s
    je     .op_i64_extend32_s
    cmp     bl, 0xbc         ; i32.reinterpret_f32
    je     .op_i32_reinterpret_f32
    cmp     bl, 0xbe         ; f32.reinterpret_i32
    je     .op_f32_reinterpret_i32
    cmp     bl, 0xbd         ; i64.reinterpret_f64
    je     .op_i64_reinterpret_f64
    cmp     bl, 0xbf         ; f64.reinterpret_i64
    je     .op_f64_reinterpret_i64
    cmp     bl, 0xd0         ; ref.null
    je     .op_ref_null
    cmp     bl, 0xd1         ; ref.is_null
    je     .op_ref_is_null
    cmp     bl, 0xd2         ; ref.func
    je     .op_ref_func
    cmp     bl, 0x00         ; unreachable
    je     .op_unreachable
    cmp     bl, 0x01         ; nop
    je     .op_nop
    cmp     bl, 0x1c         ; select_typed
    je     .op_select_typed
    cmp     bl, 0x29         ; i64.load
    je     .op_i64_load
    cmp     bl, 0x30         ; i64.load8_s
    je     .op_i64_load8_s
    cmp     bl, 0x31         ; i64.load8_u
    je     .op_i64_load8_u
    cmp     bl, 0x32         ; i64.load16_s
    je     .op_i64_load16_s
    cmp     bl, 0x33         ; i64.load16_u
    je     .op_i64_load16_u
    cmp     bl, 0x34         ; i64.load32_s
    je     .op_i64_load32_s
    cmp     bl, 0x35         ; i64.load32_u
    je     .op_i64_load32_u
    cmp     bl, 0x37         ; i64.store
    je     .op_i64_store
    cmp     bl, 0x3c         ; i64.store8
    je     .op_i64_store8
    cmp     bl, 0x3d         ; i64.store16
    je     .op_i64_store16
    cmp     bl, 0x3e         ; i64.store32
    je     .op_i64_store32
    cmp     bl, 0x2a         ; f32.load
    je     .op_f32_load
    cmp     bl, 0x2b         ; f64.load
    je     .op_f64_load
    cmp     bl, 0x38         ; f32.store
    je     .op_f32_store
    cmp     bl, 0x39         ; f64.store
    je     .op_f64_store
    cmp     bl, 0x43         ; f32.const
    je     .op_f32_const
    cmp     bl, 0x44         ; f64.const
    je     .op_f64_const
    cmp     bl, 0x5b         ; f32.eq
    je     .op_f32_eq
    cmp     bl, 0x5c         ; f32.ne
    je     .op_f32_ne
    cmp     bl, 0x5d         ; f32.lt
    je     .op_f32_lt
    cmp     bl, 0x5e         ; f32.gt
    je     .op_f32_gt
    cmp     bl, 0x5f         ; f32.le
    je     .op_f32_le
    cmp     bl, 0x60         ; f32.ge
    je     .op_f32_ge
    cmp     bl, 0x61         ; f64.eq
    je     .op_f64_eq
    cmp     bl, 0x62         ; f64.ne
    je     .op_f64_ne
    cmp     bl, 0x63         ; f64.lt
    je     .op_f64_lt
    cmp     bl, 0x64         ; f64.gt
    je     .op_f64_gt
    cmp     bl, 0x65         ; f64.le
    je     .op_f64_le
    cmp     bl, 0x66         ; f64.ge
    je     .op_f64_ge
    cmp     bl, 0x8b         ; f32.abs
    je     .op_f32_abs
    cmp     bl, 0x8c         ; f32.neg
    je     .op_f32_neg
    cmp     bl, 0x8d         ; f32.ceil
    je     .op_f32_ceil
    cmp     bl, 0x8e         ; f32.floor
    je     .op_f32_floor
    cmp     bl, 0x8f         ; f32.trunc
    je     .op_f32_trunc
    cmp     bl, 0x90         ; f32.nearest
    je     .op_f32_nearest
    cmp     bl, 0x91         ; f32.sqrt
    je     .op_f32_sqrt
    cmp     bl, 0x92         ; f32.add
    je     .op_f32_add
    cmp     bl, 0x93         ; f32.sub
    je     .op_f32_sub
    cmp     bl, 0x94         ; f32.mul
    je     .op_f32_mul
    cmp     bl, 0x95         ; f32.div
    je     .op_f32_div
    cmp     bl, 0x96         ; f32.min
    je     .op_f32_min
    cmp     bl, 0x97         ; f32.max
    je     .op_f32_max
    cmp     bl, 0x98         ; f32.copysign
    je     .op_f32_copysign
    cmp     bl, 0x99         ; f64.abs
    je     .op_f64_abs
    cmp     bl, 0x9a         ; f64.neg
    je     .op_f64_neg
    cmp     bl, 0x9b         ; f64.ceil
    je     .op_f64_ceil
    cmp     bl, 0x9c         ; f64.floor
    je     .op_f64_floor
    cmp     bl, 0x9d         ; f64.trunc
    je     .op_f64_trunc
    cmp     bl, 0x9e         ; f64.nearest
    je     .op_f64_nearest
    cmp     bl, 0x9f         ; f64.sqrt
    je     .op_f64_sqrt
    cmp     bl, 0xa0         ; f64.add
    je     .op_f64_add
    cmp     bl, 0xa1         ; f64.sub
    je     .op_f64_sub
    cmp     bl, 0xa2         ; f64.mul
    je     .op_f64_mul
    cmp     bl, 0xa3         ; f64.div
    je     .op_f64_div
    cmp     bl, 0xa4         ; f64.min
    je     .op_f64_min
    cmp     bl, 0xa5         ; f64.max
    je     .op_f64_max
    cmp     bl, 0xa6         ; f64.copysign
    je     .op_f64_copysign
    cmp     bl, 0xa8         ; i32.trunc_f32_s
    je     .op_i32_trunc_f32_s
    cmp     bl, 0xa9         ; i32.trunc_f32_u
    je     .op_i32_trunc_f32_u
    cmp     bl, 0xaa         ; i32.trunc_f64_s
    je     .op_i32_trunc_f64_s
    cmp     bl, 0xab         ; i32.trunc_f64_u
    je     .op_i32_trunc_f64_u
    cmp     bl, 0xae         ; i64.trunc_f32_s
    je     .op_i64_trunc_f32_s
    cmp     bl, 0xaf         ; i64.trunc_f32_u
    je     .op_i64_trunc_f32_u
    cmp     bl, 0xb0         ; i64.trunc_f64_s
    je     .op_i64_trunc_f64_s
    cmp     bl, 0xb1         ; i64.trunc_f64_u
    je     .op_i64_trunc_f64_u
    cmp     bl, 0xb2         ; f32.convert_i32_s
    je     .op_f32_convert_i32_s
    cmp     bl, 0xb3         ; f32.convert_i32_u
    je     .op_f32_convert_i32_u
    cmp     bl, 0xb4         ; f32.convert_i64_s
    je     .op_f32_convert_i64_s
    cmp     bl, 0xb5         ; f32.convert_i64_u
    je     .op_f32_convert_i64_u
    cmp     bl, 0xb6         ; f32.demote_f64
    je     .op_f32_demote_f64
    cmp     bl, 0xb7         ; f64.convert_i32_s
    je     .op_f64_convert_i32_s
    cmp     bl, 0xb8         ; f64.convert_i32_u
    je     .op_f64_convert_i32_u
    cmp     bl, 0xb9         ; f64.convert_i64_s
    je     .op_f64_convert_i64_s
    cmp     bl, 0xba         ; f64.convert_i64_u
    je     .op_f64_convert_i64_u
    cmp     bl, 0xbb         ; f64.promote_f32
    je     .op_f64_promote_f32

    ; Fallthrough - unsupported
    mov     edx, ERROR_UNSUPPORTED
    jmp     .error_return

; ==================================================================
; Hot opcode handlers
; =================================================================+

.op_i32_const:
    ; Read i32 const value via LEB128
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i32
    test    rdx, rdx
    jnz     .corrupt_error
    ; Update reader offset (LEB consumed bytes in rsi - body_ptr)
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_const:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i64
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_local_get:
    ; Read local index (LEB128)
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    ; Update reader
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Check bounds
    cmp     rax, [exec_local_count]
    jae     .corrupt_error
    ; Read local
    mov     rax, [exec_locals + rax * 8]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_local_set:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [exec_local_count]
    jae     .corrupt_error
    push    rax        ; save index
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [exec_locals + rcx * 8], rax
    jmp     .dispatch_next

.op_local_tee:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [exec_local_count]
    jae     .corrupt_error
    push    rax
    call    exec_stack_peek
    jc      .underflow_error
    pop     rcx
    mov     [exec_locals + rcx * 8], rax
    jmp     .dispatch_next

.op_global_get:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [global_count]
    jae     .corrupt_error
    push    r10
    mov     r10, rax
    imul    r10, GLOBAL_SIZE
    mov     rax, [globals_buf + r10 + 8]  ; value_data
    pop     r10
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_global_set:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [global_count]
    jae     .corrupt_error
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    push    r10
    mov     r10, rcx
    imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10 + 8], rax  ; value_data
    pop     r10
    jmp     .dispatch_next

.op_drop:
    call    exec_stack_pop
    jc      .underflow_error
    jmp     .dispatch_next

.op_select:
    call    exec_stack_pop  ; condition
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop  ; false_val
    jc      .underflow_error
    mov     rdx, rax
    call    exec_stack_pop  ; true_val
    jc      .underflow_error
    test    ecx, ecx
    cmovz   rax, rdx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_select_typed:
    ; Skip type immediates (read_byte for type count, then read_value_type)
    call    reader_read_byte   ; type_count (must be 1)
    jc      .corrupt_error
    cmp     al, 1
    jne     .unsupported_error
    call    reader_read_byte   ; value type byte
    jc      .corrupt_error
    ; Same as select
    call    exec_stack_pop  ; condition
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop  ; false_val
    jc      .underflow_error
    mov     rdx, rax
    call    exec_stack_pop  ; true_val
    jc      .underflow_error
    test    ecx, ecx
    cmovz   rax, rdx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_nop:
    jmp     .dispatch_next

.op_unreachable:
    mov     edx, ERROR_TRAP
    jmp     .error_return

.op_end:
    ; End of block/function
    mov     rax, [exec_control_len]
    test    rax, rax
    jz      .function_return
    ; Pop control frame
    dec     rax
    mov     [exec_control_len], rax
    jmp     .dispatch_next

.op_return:
    jmp     .function_return

.op_block:
    ; Read block type byte (skip it for now)
    call    reader_read_byte
    jc      .corrupt_error
    ; Push control frame: kind=BLOCK, start=reader_offset
    push    qword [exec_reader_offset]  ; start offset
    push    CONTROL_BLOCK
    call    exec_control_push
    jmp     .dispatch_next

.op_loop:
    call    reader_read_byte
    jc      .corrupt_error
    push    qword [exec_reader_offset]
    push    CONTROL_LOOP
    call    exec_control_push
    jmp     .dispatch_next

.op_if:
    call    reader_read_byte
    jc      .corrupt_error
    call    exec_stack_pop   ; condition
    jc      .underflow_error
    test    eax, eax
    jnz     .if_taken
    ; Skip to else or end
    ; Need to balance block/loop/if/else/end
    ; Simplified: scan forward counting nested blocks
    xor     r15d, r15d       ; depth
.skip_if_loop:
    call    reader_read_byte
    jc      .corrupt_error
    movzx   ebx, al
    cmp     bl, 0x02         ; block
    je      .skip_if_block
    cmp     bl, 0x03         ; loop
    je      .skip_if_block
    cmp     bl, 0x04         ; if
    je      .skip_if_block
    cmp     bl, 0x05         ; else
    je      .skip_if_else
    cmp     bl, 0x0b         ; end
    je      .skip_if_end
    ; Regular opcode - skip immediates
    call    .skip_opcode_immediates
    jmp     .skip_if_loop
.skip_if_block:
    inc     r15d
    call    reader_read_byte    ; skip block type
    jc      .corrupt_error
    jmp     .skip_if_loop
.skip_if_else:
    test    r15d, r15d
    jz      .if_else_found
    dec     r15d
    jmp     .skip_if_loop
.skip_if_end:
    test    r15d, r15d
    jz      .if_end_found
    dec     r15d
    jmp     .skip_if_loop
.if_else_found:
    push    qword [exec_reader_offset]
    push    CONTROL_IF_ELSE
    call    exec_control_push
    jmp     .dispatch_next
.if_end_found:
    ; No else branch - just continue (if body was empty)
    push    qword [exec_reader_offset]
    push    CONTROL_IF_THEN
    call    exec_control_push
    ; At end, so drop through to done
    jmp     .function_return
.if_taken:
    push    qword [exec_reader_offset]
    push    CONTROL_IF_THEN
    call    exec_control_push
    jmp     .dispatch_next

.op_else:
    ; Check control stack top is if_then
    mov     rax, [exec_control_len]
    test    rax, rax
    jz      .corrupt_error
    ; Pop control, push if_else (already at else body)
    dec     rax
    mov     [exec_control_len], rax
    push    qword [exec_reader_offset]
    push    CONTROL_IF_ELSE
    call    exec_control_push
    jmp     .dispatch_next

.op_br:
    ; Read branch depth
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Branch to control
    mov     rdi, rax        ; depth
    call    exec_branch_to_control
    test    rdx, rdx
    jnz     .corrupt_error
    jmp     .dispatch_next

.op_br_if:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    push    rax             ; save depth
    call    exec_stack_pop  ; condition
    jc      .underflow_error
    pop     rcx
    test    eax, eax
    jz      .dispatch_next
    mov     rdi, rcx
    call    exec_branch_to_control
    test    rdx, rdx
    jnz     .corrupt_error
    jmp     .dispatch_next

.op_call:
    ; Read function index
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Execute function
    mov     rdi, rax        ; function_index
    ; Pass current stack as args - simplified: pass args_ptr=0, args_count=0
    ; For proper argument passing, need to pop from stack
    xor     rsi, rsi        ; no explicit args for now
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error_return
    jmp     .dispatch_next

.op_call_indirect:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32    ; type_index
    test    rdx, rdx
    jnz     .corrupt_error
    push    rax
    call    reader_read_byte        ; table_index (LEB, but table index is small)
    jc      .corrupt_error
    pop     r15                     ; type_index -> r15
    ; Pop function index from stack
    call    exec_stack_pop
    jc      .underflow_error
    mov     rdi, rax                ; function_index
    xor     rsi, rsi
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error_return
    jmp     .dispatch_next

.op_br_table:
    ; Read target count
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    mov     r15d, eax       ; target_count
    call    exec_stack_pop
    jc      .underflow_error
    mov     r14d, eax       ; selector
    xor     r13d, r13d      ; target_index
.br_table_loop:
    cmp     r13d, r15d
    jae     .br_table_default
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     r13d, r14d
    je      .br_table_branch   ; found matching target
    inc     r13d
    jmp     .br_table_loop
.br_table_default:
    ; Read default target
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
.br_table_branch:
    mov     rdi, rax        ; branch depth
    call    exec_branch_to_control
    test    rdx, rdx
    jnz     .corrupt_error
    jmp     .dispatch_next

; ==================================================================
; Control frame push/pop/branch
; =================================================================+

; Push control frame: expects values on stack (kind=8 bytes, start=8 bytes)
; Used as: push kind; push start; call exec_control_push

; ==================================================================
; Integer i32 binary ops
; =================================================================+
.op_i32_add:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax        ; right
    call    exec_stack_pop
    jc      .underflow_error
    add     eax, ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_sub:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    sub     eax, ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_mul:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    imul    eax, ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_div_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    cmp     eax, 0x80000000
    jne     .div_s_ok
    cmp     ecx, -1
    jne     .div_s_ok
    ; Overflow: INT_MIN / -1
    mov     edx, ERROR_ARITHMETIC_TRAP
    jmp     .error_return
.div_s_ok:
    cdq
    idiv    ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_div_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    xor     edx, edx
    div     ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_rem_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    mov     r8d, eax        ; save dividend
    cdq
    idiv    ecx
    mov     eax, edx        ; remainder
    ; If dividend was INT_MIN and divisor was -1, remainder = 0
    cmp     r8d, 0x80000000
    jne     .rem_s_done
    cmp     ecx, -1
    jne     .rem_s_done
    xor     eax, eax
.rem_s_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_rem_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    xor     edx, edx
    div     ecx
    mov     eax, edx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_and:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    and     eax, ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_or:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    or      eax, ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_xor:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    xor     eax, ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_shl:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    shl     eax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_shr_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    sar     eax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_shr_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    shr     eax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_rotl:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    rol     eax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_rotr:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    ror     eax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_clz:
    call    exec_stack_pop
    jc      .underflow_error
    ; Count leading zeros (eax -> eax)
    bsr     ecx, eax
    jnz     .clz_found
    mov     eax, 32
    jmp     .clz_done
.clz_found:
    mov     eax, 31
    sub     eax, ecx
.clz_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_ctz:
    call    exec_stack_pop
    jc      .underflow_error
    bsf     ecx, eax
    jnz     .ctz_found
    mov     eax, 32
    jmp     .ctz_done
.ctz_found:
    mov     eax, ecx
.ctz_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_popcnt:
    call    exec_stack_pop
    jc      .underflow_error
    ; Popcount using x86 popcnt instruction
    popcnt  eax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Integer i32 comparison ops
; =================================================================+
.op_i32_eqz:
    call    exec_stack_pop
    jc      .underflow_error
    test    eax, eax
    setz    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_eq:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    sete    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_ne:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setne   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_lt_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setl    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_lt_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setb    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_gt_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setg    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_gt_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    seta    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_le_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setle   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_le_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setbe   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_ge_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setge   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_ge_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, ecx
    setae   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Integer i64 binary ops
; =================================================================+
.op_i64_add:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    add     rax, rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_sub:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    sub     rax, rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_mul:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    imul    rax, rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_div_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    mov     rdx, rax
    mov     rax, 0x8000000000000000
    cmp     rdx, rax
    jne     .div_s64_ok
    cmp     rcx, -1
    jne     .div_s64_ok
    ; Overflow: INT64_MIN / -1
    mov     edx, ERROR_ARITHMETIC_TRAP
    jmp     .error_return
.div_s64_ok:
    mov     rax, rdx
    cqo
    idiv    rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_div_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    xor     rdx, rdx
    div     rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_rem_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    mov     r8, rax
    cqo
    idiv    rcx
    mov     rax, rdx
    mov     rdx, 0x8000000000000000
    cmp     r8, rdx
    jne     .rem_s64_done
    cmp     rcx, -1
    jne     .rem_s64_done
    xor     eax, eax
.rem_s64_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_rem_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    xor     rdx, rdx
    div     rcx
    mov     rax, rdx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_and:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    and     rax, rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_or:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    or      rax, rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_xor:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    xor     rax, rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_shl:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    shl     rax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_shr_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    sar     rax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_shr_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    shr     rax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_rotl:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    rol     rax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_rotr:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    ror     rax, cl
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_clz:
    call    exec_stack_pop
    jc      .underflow_error
    bsr     rcx, rax
    jnz     .clz64_found
    mov     eax, 64
    jmp     .clz64_done
.clz64_found:
    mov     eax, 63
    sub     eax, ecx
.clz64_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_ctz:
    call    exec_stack_pop
    jc      .underflow_error
    bsf     rcx, rax
    jnz     .ctz64_found
    mov     eax, 64
    jmp     .ctz64_done
.ctz64_found:
    mov     eax, ecx
.ctz64_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_popcnt:
    call    exec_stack_pop
    jc      .underflow_error
    popcnt  rax, rax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Integer i64 comparison ops
; =================================================================+
.op_i64_eqz:
    call    exec_stack_pop
    jc      .underflow_error
    test    rax, rax
    setz    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_eq:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    sete    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_ne:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setne   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_lt_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setl    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_lt_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setb    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_gt_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setg    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_gt_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    seta    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_le_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setle   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_le_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setbe   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_ge_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setge   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_ge_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, rcx
    setae   al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Conversion ops
; =================================================================+
.op_i32_wrap_i64:
    call    exec_stack_pop
    jc      .underflow_error
    ; Just take low 32 bits (already in rax, truncate upper bits)
    mov     eax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend_i32_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsxd  rax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend_i32_u:
    call    exec_stack_pop
    jc      .underflow_error
    ; Zero extend (rax already has i32 in low bits, high bits 0 from 32-bit ops)
    mov     eax, eax    ; zero extend
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_extend8_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_extend16_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   eax, ax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend8_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   rax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend16_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   rax, ax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend32_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsxd  rax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Reinterpret ops
; =================================================================+
.op_i32_reinterpret_f32:
    ; f32 bits are already on stack as 64-bit value
    ; Just take low 32 bits
    call    exec_stack_peek
    ; Value is already in rax, just keep as is
    ; (but tagged as i32, which we don't track)
    jmp     .dispatch_next

.op_f32_reinterpret_i32:
    ; i32 bits are already on stack
    jmp     .dispatch_next

.op_i64_reinterpret_f64:
    jmp     .dispatch_next

.op_f64_reinterpret_i64:
    jmp     .dispatch_next

; ==================================================================
; Reference ops
; =================================================================+
.op_ref_null:
    mov     eax, -1
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_ref_is_null:
    ; Pop reference value
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, -1
    sete    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_ref_func:
    ; Read function index
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    mov     rdi, rax
    ; Verify function index < totalFunctionCount
    mov     rax, [import_count]
    add     rax, [function_count]
    cmp     rdi, rax
    jae     .corrupt_error
    ; Push function index as funcref
    mov     rax, rdi
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Memory ops
; =================================================================+


.op_i32_load:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4          ; size
    call    exec_memory_check_range
    jc      .error_return
    mov     eax, [rax]      ; load 32 bits
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load8_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movsx   eax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load8_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movzx   eax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load16_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movsx   eax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load16_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movzx   eax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_store:
    call    exec_stack_pop   ; value to store
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], ecx       ; store 32 bits
    jmp     .dispatch_next

.op_i32_store8:
    call    exec_stack_pop
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], cl
    jmp     .dispatch_next

.op_i32_store16:
    call    exec_stack_pop
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], cx
    jmp     .dispatch_next

.op_i64_load:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 8
    call    exec_memory_check_range
    jc      .error_return
    mov     rax, [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load8_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movsx   rax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load8_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movzx   rax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load16_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movsx   rax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load16_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movzx   rax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load32_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    movsxd  rax, dword [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load32_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    mov     eax, [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_store:
    call    exec_stack_pop
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 8
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], rcx
    jmp     .dispatch_next

.op_i64_store8:
    call    exec_stack_pop
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], cl
    jmp     .dispatch_next

.op_i64_store16:
    call    exec_stack_pop
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], cx
    jmp     .dispatch_next

.op_i64_store32:
    call    exec_stack_pop
    jc      .underflow_error
    push    rax
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    pop     rcx
    mov     [rax], ecx
    jmp     .dispatch_next

.op_memory_size:
    mov     rax, [executor_memory_pages]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_memory_grow:
    call    exec_stack_pop
    jc      .underflow_error
    mov     r15, rax         ; requested pages
    ; Current pages
    mov     rax, [executor_memory_pages]
    mov     r14, rax         ; previous pages
    ; Check if grow function exists
    mov     rdi, [runtime_memory_grow_fn]
    test    rdi, rdi
    jz      .memory_grow_no_authority
    mov     rsi, [runtime_memory_grow_ctx]
    ; Call memory grow function: fn(context, old_pages, new_pages)
    ; ABI: rdi=context, rsi=old_pages, rdx=new_pages
    mov     rdx, r15
    call    rdi
    test    rax, rax
    jz      .memory_grow_failed
    ; Update memory pages and limit
    mov     [executor_memory_pages], r15
    ; Current pages pushed as result
    mov     rax, r14
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next
.memory_grow_no_authority:
    mov     edx, ERROR_MEMORY_GROWTH
    jmp     .error_return
.memory_grow_failed:
    ; Push -1 on failure (WASM spec)
    mov     eax, -1
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Table ops
; =================================================================+
.op_table_get:
    call    reader_read_byte   ; table index (skip, only table 0 supported)
    jc      .corrupt_error
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, [table_min]
    jae     .corrupt_error
    mov     rax, [table_entries + rax * 8]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_table_set:
    call    reader_read_byte
    jc      .corrupt_error
    call    exec_stack_pop   ; value
    jc      .underflow_error
    push    rax
    call    exec_stack_pop   ; index
    jc      .underflow_error
    pop     rcx
    cmp     rax, [table_min]
    jae     .corrupt_error
    mov     [table_entries + rax * 8], rcx
    jmp     .dispatch_next

; ==================================================================
; Float ops (stubs for now - return Unsupported)
; =================================================================+
.op_f32_load:
.op_f64_load:
.op_f32_store:
.op_f64_store:
.op_f32_const:
.op_f64_const:
.op_f32_eq:
.op_f32_ne:
.op_f32_lt:
.op_f32_gt:
.op_f32_le:
.op_f32_ge:
.op_f64_eq:
.op_f64_ne:
.op_f64_lt:
.op_f64_gt:
.op_f64_le:
.op_f64_ge:
.op_f32_abs:
.op_f32_neg:
.op_f32_ceil:
.op_f32_floor:
.op_f32_trunc:
.op_f32_nearest:
.op_f32_sqrt:
.op_f32_add:
.op_f32_sub:
.op_f32_mul:
.op_f32_div:
.op_f32_min:
.op_f32_max:
.op_f32_copysign:
.op_f64_abs:
.op_f64_neg:
.op_f64_ceil:
.op_f64_floor:
.op_f64_trunc:
.op_f64_nearest:
.op_f64_sqrt:
.op_f64_add:
.op_f64_sub:
.op_f64_mul:
.op_f64_div:
.op_f64_min:
.op_f64_max:
.op_f64_copysign:
.op_i32_trunc_f32_s:
.op_i32_trunc_f32_u:
.op_i32_trunc_f64_s:
.op_i32_trunc_f64_u:
.op_i64_trunc_f32_s:
.op_i64_trunc_f32_u:
.op_i64_trunc_f64_s:
.op_i64_trunc_f64_u:
.op_f32_convert_i32_s:
.op_f32_convert_i32_u:
.op_f32_convert_i64_s:
.op_f32_convert_i64_u:
.op_f32_demote_f64:
.op_f64_convert_i32_s:
.op_f64_convert_i32_u:
.op_f64_convert_i64_s:
.op_f64_convert_i64_u:
.op_f64_promote_f32:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .error_return

; ==================================================================
; Extended opcodes (0xfc prefix)
; =================================================================+
.extended_opcode:
    ; Read extended opcode
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi

    cmp     eax, EXT_MEMORY_INIT
    je      .ext_memory_init
    cmp     eax, EXT_DATA_DROP
    je      .ext_data_drop
    cmp     eax, EXT_MEMORY_COPY
    je      .ext_memory_copy
    cmp     eax, EXT_MEMORY_FILL
    je      .ext_memory_fill

    ; All other extended opcodes (trunc_sat, table ops) - unsupported for now
    mov     edx, ERROR_UNSUPPORTED
    jmp     .error_return

.ext_memory_init:
    ; Read segment index, then memory index
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rax             ; segment index
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    reader_read_byte ; memory index (0)
    jc      .corrupt_error
    pop     r15             ; segment index
    ; Pop dest, src, count from stack
    call    exec_stack_pop  ; n
    jc      .underflow_error
    mov     r14, rax
    call    exec_stack_pop  ; s
    jc      .underflow_error
    mov     r13, rax
    call    exec_stack_pop  ; d
    jc      .underflow_error
    mov     r12, rax
    ; TODO: implement actual memory.init
    ; For now, just skip
    jmp     .dispatch_next

.ext_data_drop:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Mark data segment as dropped (set active=0)
    ; data_segment layout: offset(8) + byte_offset(8) + byte_len(8) + active(1) + dropped(1)
    ; For now, just skip
    jmp     .dispatch_next

.ext_memory_copy:
    ; Read dest memory index, then src memory index
    call    reader_read_byte
    jc      .corrupt_error
    call    reader_read_byte
    jc      .corrupt_error
    ; Pop n, s, d
    call    exec_stack_pop  ; n
    jc      .underflow_error
    mov     r14, rax
    call    exec_stack_pop  ; s
    jc      .underflow_error
    mov     r13, rax
    call    exec_stack_pop  ; d
    jc      .underflow_error
    mov     r12, rax
    ; TODO: implement actual memory.copy
    jmp     .dispatch_next

.ext_memory_fill:
    call    reader_read_byte
    jc      .corrupt_error
    ; Pop n, val, d
    call    exec_stack_pop  ; n
    jc      .underflow_error
    mov     r14, rax
    call    exec_stack_pop  ; val
    jc      .underflow_error
    mov     r13, rax
    call    exec_stack_pop  ; d
    jc      .underflow_error
    mov     r12, rax
    ; TODO: implement actual memory.fill
    jmp     .dispatch_next

; ==================================================================
; Opcode immediate skipping helper
; =================================================================+
.skip_opcode_immediates:
    ; ebx = opcode byte
    movzx   ebx, bl
    ; Most opcodes have no immediates
    ; Check opcodes that DO have immediates
    cmp     bl, 0x02         ; block
    je      .skip_block_type
    cmp     bl, 0x03         ; loop
    je      .skip_block_type
    cmp     bl, 0x04         ; if
    je      .skip_block_type
    cmp     bl, 0x0c         ; br
    je      .skip_leb
    cmp     bl, 0x0d         ; br_if
    je      .skip_leb
    cmp     bl, 0x10         ; call
    je      .skip_leb
    cmp     bl, 0x11         ; call_indirect
    je      .skip_call_indirect
    cmp     bl, 0x20         ; local.get
    je      .skip_leb
    cmp     bl, 0x21         ; local.set
    je      .skip_leb
    cmp     bl, 0x22         ; local.tee
    je      .skip_leb
    cmp     bl, 0x23         ; global.get
    je      .skip_leb
    cmp     bl, 0x24         ; global.set
    je      .skip_leb
    cmp     bl, 0x41         ; i32.const
    je      .skip_leb_i32
    cmp     bl, 0x42         ; i64.const
    je      .skip_leb_i64
    cmp     bl, 0x0e         ; br_table
    je      .skip_br_table
    cmp     bl, 0x28         ; i32.load etc.
    ret
    cmp     bl, 0x3f         ; below memory_size
    jb      .skip_load_store
    cmp     bl, 0x40         ; memory_grow
    je      .skip_leb
    cmp     bl, 0x1c         ; select_typed
    je      .skip_select_typed
    cmp     bl, 0xd0         ; ref.null
    je      .skip_byte
    cmp     bl, 0xd2         ; ref.func
    je      .skip_leb
    ; For most opcodes, no immediates to skip
    ret

.skip_leb:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_leb_i32:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_leb_i64:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i64
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_block_type:
    call    reader_read_byte
    jc      .skip_error
    ret

.skip_byte:
    call    reader_read_byte
    jc      .skip_error
    ret

.skip_call_indirect:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32    ; type_index
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    reader_read_byte        ; table_index
    ret

.skip_load_store:
    ; Two LEBs: alignment then offset
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_br_table:
    ; Read target count, then targets, then default
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    mov     r15d, eax      ; target count
.skip_br_table_loop:
    test    r15d, r15d
    jz      .skip_br_table_default
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    dec     r15d
    jmp     .skip_br_table_loop
.skip_br_table_default:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_select_typed:
    call    reader_read_byte  ; type count (should be 1)
    ret

.skip_error:
    ; On skip error, just return (will be caught later)
    ret

; ==================================================================
; Function return handling
; =================================================================+
.function_return:
    ; Collect results from stack based on result count
    mov     rcx, [exec_result_count]
    test    rcx, rcx
    jz      .return_done
    mov     r15, rcx
    ; Pop results in reverse order
.return_collect:
    cmp     r15, 0
    je      .return_done
    dec     r15
    call    exec_stack_pop
    jc      .underflow_error
    mov     [exec_result_values + r15 * 8], rax
    jmp     .return_collect
.return_done:
    ; If this is the outermost call (stack_len was 0 before call), exit loop
    ; Otherwise, the result will be pushed back by caller
    xor     edx, edx
    pop     rbp
    ret

; ==================================================================
; Error exit points
; =================================================================+
.corrupt_error:
    mov     edx, ERROR_CORRUPT
    jmp     .error_return
.underflow_error:
    mov     edx, ERROR_STACK_UNDERFLOW
    jmp     .error_return
.overflow_error:
    mov     edx, ERROR_STACK_OVERFLOW
    jmp     .error_return
.unsupported_error:
    mov     edx, ERROR_UNSUPPORTED
    jmp     .error_return
.arithmetic_trap:
    mov     edx, ERROR_ARITHMETIC_TRAP
    jmp     .error_return

; ==================================================================
; Outer dispatch loop exit (error)
; =================================================================+
.done:
    xor     edx, edx
    pop     rbp
    ret

.error_return:
    ; rdx set by caller
    mov     rax, -1
    pop     rbp
    ret
er_fn exec_control_push
    pop     rax     ; return address
    pop     rcx     ; start
    pop     rdx     ; kind
    push    rax     ; restore return address
    mov     rax, [exec_control_len]
    cmp     rax, MAX_CONTROL_DEPTH
    jae     .overflow
    push    r10
    mov     r10, rax
    imul    r10, CONTROL_FRAME_SIZE
    mov     [exec_control + r10], rdx      ; kind
    mov     [exec_control + r10 + 8], rcx  ; start
    pop     r10
    inc     qword [exec_control_len]
    ret
.overflow:
    mov     edx, ERROR_UNSUPPORTED
    ; Skip the pushed values
    ret

; Branch to control at given depth
; rdi = branch_depth from current position (0 = innermost)
er_fn exec_branch_to_control
    push    rbp
    mov     rbp, rsp
    ; target_index = control_len - 1 - branch_depth
    mov     rax, [exec_control_len]
    test    rax, rax
    jz      .error
    sub     rax, 1
    sub     rax, rdi
    jc      .error
    ; Get control frame at target_index
    push    r10
    mov     r10, rax
    imul    r10, CONTROL_FRAME_SIZE
    mov     rcx, [exec_control + r10]        ; kind
    mov     rdx, [exec_control + r10 + 8]   ; start
    pop     r10
    ; Set control length = target_index + 1 (for loop) or target_index (for block)
    mov     r8, rax         ; target_index
    cmp     rcx, CONTROL_LOOP
    je      .branch_loop
    ; block/if_then/if_else
.branch_block:
    mov     [exec_control_len], r8
    mov     [exec_reader_offset], rdx
    jmp     .branch_done
.branch_loop:
    add     r8, 1
    mov     [exec_control_len], r8
    mov     [exec_reader_offset], rdx
.branch_done:
    xor     edx, edx
    pop     rbp
    ret
.error:
    mov     edx, ERROR_CORRUPT
    pop     rbp
    ret
; Helper: read alignment and offset immediates, compute address
; Returns address in rax
er_fn exec_memory_prepare
    ; Read alignment (LEB, skip it)
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_mem
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Read offset (LEB)
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_mem
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    mov     r15d, eax      ; offset
    ; Pop base address from stack
    call    exec_stack_pop
    jc      .underflow_mem
    mov     ecx, eax        ; base (lower 32 bits)
    ; Compute final address = base + offset
    mov     eax, ecx
    add     eax, r15d       ; add offset
    jc      .no_memory      ; overflow
    clc
    ret
.corrupt_mem:
    mov     edx, ERROR_CORRUPT
    stc
    ret
.underflow_mem:
    mov     edx, ERROR_STACK_UNDERFLOW
    stc
    ret
.no_memory:
    mov     edx, ERROR_NO_MEMORY
    stc
    ret

; Check memory range: address in eax, size in ecx
; Returns pointer in rax, carry on error
er_fn exec_memory_check_range
    push    rbp
    mov     rbp, rsp
    ; Check address + size <= memory_len
    mov     rdx, [runtime_memory_len]
    mov     r8d, eax
    add     r8d, ecx
    jc      .out_of_range
    cmp     r8d, edx
    ja      .out_of_range
    ; Also check address + size <= memory_limit
    mov     rdx, [executor_memory_limit]
    cmp     r8d, edx
    ja      .out_of_range
    ; Valid: return pointer in rax
    add     rax, [runtime_memory_ptr]
    clc
    pop     rbp
    ret
.out_of_range:
    mov     edx, ERROR_NO_MEMORY
    stc
    pop     rbp
    ret

; ==================================================================
; er_fn_run: Top-level entry point
; rdi = runtime_ptr
; rsi = wasm_bytes_ptr
; rdx = wasm_bytes_len
; rcx = export_name_ptr
; r8  = export_name_len
; Returns: rax = result value, rdx = error code
; =================================================================+
er_fn er_fn_run
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    r8              ; save export_name_len

    mov     r12, rdi        ; runtime_ptr
    mov     r13, rsi        ; wasm_bytes
    mov     r14, rdx        ; wasm_len
    mov     r15, rcx        ; export_name

    ; Initialize runtime context
    mov     rdi, [r12]      ; runtime.memory_ptr (first field)
    mov     rsi, [r12 + 8]  ; runtime.memory_len (second field)
    mov     rdx, [r12 + 16] ; runtime.execution_ticks (third field)
    call    er_fn_init

    ; Also store the grow function pointers if present
    mov     rax, [r12 + 24] ; runtime_memory_grow_fn
    mov     [runtime_memory_grow_fn], rax
    mov     rax, [r12 + 32] ; runtime_memory_grow_ctx
    mov     [runtime_memory_grow_ctx], rax
    mov     rax, [r12 + 40] ; runtime_table_grow_fn
    mov     [runtime_table_grow_fn], rax
    mov     rax, [r12 + 48] ; runtime_table_grow_ctx
    mov     [runtime_table_grow_ctx], rax
    mov     rax, [r12 + 56] ; runtime_initial_pages
    mov     [runtime_initial_pages], rax
    movzx   eax, byte [r12 + 64] ; runtime_has_initial_pages
    mov     [runtime_has_initial_pages], al

    ; Reset parser state
    mov     byte [exec_storage_module_valid], 0
    mov     byte [exec_storage_start_ran], 0
    mov     qword [exec_frame_save_ptr], 0
    mov     qword [exec_call_depth], 0

    ; Parse module
    mov     rdi, r13
    mov     rsi, r14
    call    er_wasm_parse_module
    test    rax, rax
    jnz     .error

    mov     byte [exec_storage_module_valid], 1

    ; Determine initial memory pages
    cmp     byte [runtime_has_initial_pages], 0
    je      .use_module_memory_pages
    mov     rax, [runtime_initial_pages]
    jmp     .set_memory_pages
.use_module_memory_pages:
    mov     rax, [memory_min_pages]
.set_memory_pages:
    mov     [executor_memory_pages], rax
    ; Calculate memory limit: pages * 65536
    shl     rax, WASM_PAGE_SHIFT
    mov     [executor_memory_limit], rax

    ; Run start function if present
    cmp     byte [exec_storage_start_ran], 0
    jne     .skip_start

    cmp     qword [start_function_index], -1
    je      .no_start

    mov     rdi, [start_function_index]
    xor     rsi, rsi
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error
    ; Check that start function returned no results
    cmp     qword [exec_result_count], 0
    jne     .corrupt_error_label

.no_start:
    mov     byte [exec_storage_start_ran], 1

.skip_start:
    ; Find the export
    mov     rdi, r15
    mov     rsi, [rbp - 48]
    call    er_wasm_find_export
    test    rdx, rdx
    jnz     .error

    mov     r15, rax        ; function_index

    ; Apply data segments
    mov     rdi, [runtime_memory_ptr]
    mov     rsi, [executor_memory_pages]
    call    er_wasm_apply_data_segments

    ; Execute exported function
    mov     rdi, r15
    xor     rsi, rsi        ; no args for now
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error

    ; Return result
    mov     rax, [exec_result_values]
    mov     rdx, [exec_result_count]
    jmp     .done

.corrupt_error_label:
    mov     edx, ERROR_CORRUPT
.error:
    mov     rax, -1
.done:
    pop     r8              ; restore export_name_len
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Initialize the runtime context
; er_fn_init(memory_ptr=rdi, memory_len=rsi, ticks_ptr=rdx)
; =================================================================+
er_fn er_fn_init
    push    rbp
    mov     rbp, rsp

    mov     [runtime_memory_ptr], rdi
    mov     [runtime_memory_len], rsi
    mov     [runtime_ticks_ptr], rdx
    mov     qword [runtime_imports_ptr], 0
    mov     qword [runtime_imports_len], 0
    mov     byte [runtime_has_initial_pages], 0

    xor     eax, eax
    pop     rbp
    ret

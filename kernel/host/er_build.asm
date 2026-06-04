; EdgeRun owned build runner - x86_64 Linux userspace assembly.
;
; Current milestone:
;   er_build test-list
;   er_build test-registry
;   er_build help
;   er_build x86-sources
;   er_build pi-sources
;   er_build host-tools
;   er_build x86-objects
;   er_build validate-object OBJECT
;   er_build view OBJECT
;   er_build body-to-file OBJECT OUTPUT
;   er_build file-to-object INPUT OUTPUT.erobj
;   er_build replace-range OBJECT OFFSET DELETE_LEN INSERT_FILE OUTPUT.erobj
;
; The runner reads build graph data from EdgeRun EROBJ001 bytes objects instead
; of shell-owned text. It is intentionally small and fail-closed.

SYS_read       equ 0
SYS_write      equ 1
SYS_open       equ 2
SYS_close      equ 3
SYS_dup2       equ 33
SYS_mkdir      equ 83
SYS_fork       equ 57
SYS_execve     equ 59
SYS_wait4      equ 61
SYS_exit_group equ 231

STDOUT_FD equ 1
STDERR_FD equ 2
O_RDONLY  equ 0
O_WRONLY  equ 1
O_WRONLY_CREAT_TRUNC equ 577
DIR_MODE_0755 equ 0755o
FILE_MODE_0644 equ 0644o

OBJECT_HEADER_SIZE equ 148
OBJECT_BUF_SIZE    equ 1048576
OBJECT_KIND_BYTES  equ 1
OBJECT_KIND_TREE   equ 2
OBJECT_KIND_RECEIPT equ 4
OBJECT_KIND_CODE   equ 8
OBJECT_KIND_ISA    equ 16
OBJECT_VERSION     equ 1
EROBJ_SUFFIX_LEN   equ 6
ISA_BODY_MAGIC_QWORD         equ 0x3130304153495245
ISA_BODY_VERSION             equ 1
ISA_ID_X86_64                equ 1
ISA_ID_WASM                  equ 5
ISA_BODY_HEADER_SIZE         equ 16
ISA_DEF_SIZE                 equ 16
ISA_BODY_OF_MAGIC            equ 0
ISA_BODY_OF_VERSION          equ 8
ISA_BODY_OF_ISA              equ 10
ISA_BODY_OF_DEF_COUNT        equ 12
ISA_DEF_OF_INSTRUCTION_ID    equ 0
ISA_DEF_OF_MNEMONIC_ID       equ 4
ISA_DEF_OF_OPERAND_SHAPE     equ 6
ISA_DEF_OF_ENCODING_SHAPE    equ 8
ISA_DEF_OF_INPUT_COUNT       equ 12
ISA_DEF_OF_OUTPUT_COUNT      equ 13
ISA_DEF_OF_IMPLICIT_COUNT    equ 14
ISA_DEF_OF_RESERVED          equ 15
section .bss
object_buf: resb OBJECT_BUF_SIZE
source_list_buf: resb OBJECT_BUF_SIZE
edit_buf: resb OBJECT_BUF_SIZE
byte_buf: resb 1
wait_status: resd 1
source_path_buf: resb 512
source_object_path_buf: resb 512
source_kind_buf: resb 32
source_entry_buf: resb 512
source_logical_buf: resb 512
object_stem_buf: resb 128
object_path_buf: resb 512
binary_path_buf: resb 512
suppress_host_tools_output: resq 1
process_quiet: resq 1
stack_bottom: resb 65536
stack_top:

section .text
global _start

_start:
    mov     r12, [rsp]
    lea     r13, [rsp + 8]
    mov     rsp, stack_top

    cmp     r12, 7
    je      .argc7
    cmp     r12, 5
    je      .argc5
    cmp     r12, 4
    je      .argc4
    cmp     r12, 3
    je      .argc3
    cmp     r12, 2
    jne     .usage
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_test_list]
    call    streq
    test    eax, eax
    jnz     .test_list
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_test_registry]
    call    streq
    test    eax, eax
    jnz     .test_registry
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_test_status]
    call    streq
    test    eax, eax
    jnz     .test_status_all
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_help]
    call    streq
    test    eax, eax
    jnz     .help
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_x86_sources]
    call    streq
    test    eax, eax
    jnz     .x86_sources
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_pi_sources]
    call    streq
    test    eax, eax
    jnz     .pi_sources
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_host_tools]
    call    streq
    test    eax, eax
    jnz     .host_tools
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_er_asm]
    call    streq
    test    eax, eax
    jnz     .er_asm
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_x86_objects]
    call    streq
    test    eax, eax
    jnz     .x86_objects
    jmp     .usage

.argc7:
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_replace_range]
    call    streq
    test    eax, eax
    jnz     .replace_range
    jmp     .usage

.argc4:
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_test_status]
    call    streq
    test    eax, eax
    jnz     .test_status_2
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_body_to_file]
    call    streq
    test    eax, eax
    jnz     .body_to_file
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_file_to_object]
    call    streq
    test    eax, eax
    jnz     .file_to_object
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_file_to_isa_object]
    call    streq
    test    eax, eax
    jnz     .file_to_isa_object
    jmp     .usage

.argc5:
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_test_status]
    call    streq
    test    eax, eax
    jnz     .test_status_3
    jmp     .usage

.argc3:
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_test_status]
    call    streq
    test    eax, eax
    jnz     .test_status_1
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_view]
    call    streq
    test    eax, eax
    jnz     .view
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_validate_object]
    call    streq
    test    eax, eax
    jnz     .validate_object
    jmp     .usage

.view:
    mov     rdi, [r13 + 16]
    call    cmd_write_body
    xor     edi, edi
    jmp     exit_now

.test_list:
    call    cmd_test_list
    xor     edi, edi
    jmp     exit_now

.test_registry:
    call    cmd_test_registry
    xor     edi, edi
    jmp     exit_now

.test_status_all:
    xor     edi, edi
    xor     esi, esi
    call    cmd_test_status
    xor     edi, edi
    jmp     exit_now

.test_status_1:
    lea     rdi, [r13 + 16]
    mov     esi, 1
    call    cmd_test_status
    xor     edi, edi
    jmp     exit_now

.test_status_2:
    lea     rdi, [r13 + 16]
    mov     esi, 2
    call    cmd_test_status
    xor     edi, edi
    jmp     exit_now

.test_status_3:
    lea     rdi, [r13 + 16]
    mov     esi, 3
    call    cmd_test_status
    xor     edi, edi
    jmp     exit_now

.help:
    call    cmd_help
    xor     edi, edi
    jmp     exit_now

.x86_sources:
    lea     rdi, [rel x86_sources_path]
    call    cmd_write_body
    xor     edi, edi
    jmp     exit_now

.pi_sources:
    lea     rdi, [rel pi_sources_path]
    call    cmd_write_body
    xor     edi, edi
    jmp     exit_now

.host_tools:
    call    cmd_host_tools
    xor     edi, edi
    jmp     exit_now

.er_asm:
    call    cmd_host_tools
    xor     edi, edi
    jmp     exit_now

.x86_objects:
    call    cmd_x86_objects
    xor     edi, edi
    jmp     exit_now

.body_to_file:
    mov     rdi, [r13 + 16]
    mov     rsi, [r13 + 24]
    call    write_object_body_file
    xor     edi, edi
    jmp     exit_now

.file_to_object:
    mov     rdi, [r13 + 16]
    mov     rsi, [r13 + 24]
    call    write_file_object
    xor     edi, edi
    jmp     exit_now

.file_to_isa_object:
    mov     rdi, [r13 + 16]
    mov     rsi, [r13 + 24]
    call    write_file_isa_object
    xor     edi, edi
    jmp     exit_now

.replace_range:
    mov     rdi, [r13 + 16]
    mov     rsi, [r13 + 24]
    mov     rdx, [r13 + 32]
    mov     rcx, [r13 + 40]
    mov     r8,  [r13 + 48]
    call    cmd_replace_range
    xor     edi, edi
    jmp     exit_now

.validate_object:
    mov     rdi, [r13 + 16]
    call    cmd_validate_object_path
    xor     edi, edi
    jmp     exit_now

.usage:
    lea     rdi, [rel msg_usage]
    call    print_cstr_stderr
    mov     edi, 2
    jmp     exit_now

bad_object:
    lea     rdi, [rel msg_bad_object]
    call    print_cstr_stderr
    mov     edi, 1
    jmp     exit_now

build_fail:
    lea     rdi, [rel msg_build_fail]
    call    print_cstr_stderr
    mov     edi, 1
    jmp     exit_now

cmd_host_tools:
    lea     rdi, [rel build_dir]
    mov     esi, DIR_MODE_0755
    mov     eax, SYS_mkdir
    syscall
    lea     rdi, [rel host_build_dir]
    mov     esi, DIR_MODE_0755
    mov     eax, SYS_mkdir
    syscall

    lea     rdi, [rel host_tools_path]
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object
    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     bad_object
    lea     rdi, [rel source_list_buf]
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     rdx, rax
    call    copy_bytes
    mov     eax, [rel object_buf + 32]
    lea     r12, [rel source_list_buf]
    lea     r13, [r12 + rax]
.tool_loop:
    cmp     r12, r13
    jae     .tools_done
    lea     rdi, [rel source_kind_buf]
    mov     rsi, r12
    mov     rdx, r13
    call    copy_field
    mov     r12, rax
    call    validate_source_kind
    lea     rdi, [rel source_object_path_buf]
    mov     rsi, r12
    mov     rdx, r13
    call    copy_field
    mov     r12, rax
    lea     rdi, [rel object_path_buf]
    mov     rsi, r12
    mov     rdx, r13
    call    copy_field
    mov     r12, rax
    lea     rdi, [rel binary_path_buf]
    mov     rsi, r12
    mov     rdx, r13
    call    copy_field
    mov     r12, rax

    call    build_host_source_path
    call    materialize_source_object_if_needed
    lea     rdi, [rel yasm_path]
    lea     rsi, [rel argv_yasm_host_tool]
    call    run_process
    test    eax, eax
    jnz     build_fail
    lea     rdi, [rel ld_path]
    lea     rsi, [rel argv_ld_host_tool]
    call    run_process
    test    eax, eax
    jnz     build_fail
    jmp     .tool_loop
.tools_done:
    cmp     qword [rel suppress_host_tools_output], 0
    jne     .quiet_done
    lea     rdi, [rel msg_host_tools_ok]
    call    print_cstr_stdout
.quiet_done:
    ret

cmd_x86_objects:
    lea     rdi, [rel build_dir]
    mov     esi, DIR_MODE_0755
    mov     eax, SYS_mkdir
    syscall
    lea     rdi, [rel kernel_build_dir]
    mov     esi, DIR_MODE_0755
    mov     eax, SYS_mkdir
    syscall
    lea     rdi, [rel kernel_source_build_dir]
    mov     esi, DIR_MODE_0755
    mov     eax, SYS_mkdir
    syscall

    lea     rdi, [rel x86_sources_path]
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object

    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     bad_object
    lea     rdi, [rel source_list_buf]
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     rdx, rax
    call    copy_bytes
    mov     eax, [rel object_buf + 32]
    lea     r12, [rel source_list_buf]
    lea     r13, [r12 + rax]
.line_loop:
    cmp     r12, r13
    jae     .done
    mov     r14, r12
.scan_line:
    cmp     r12, r13
    jae     .line_ready
    cmp     byte [r12], 10
    je      .line_ready
    inc     r12
    jmp     .scan_line
.line_ready:
    mov     r15, r12
    sub     r15, r14
    cmp     r15, 0
    je      .advance
    lea     rdi, [rel source_kind_buf]
    mov     rsi, r14
    mov     rdx, r12
    call    copy_field
    mov     r14, rax
    call    validate_source_kind
    lea     rdi, [rel source_entry_buf]
    mov     rsi, r14
    mov     rdx, r12
    call    copy_field
    mov     r14, rax
    lea     rdi, [rel object_stem_buf]
    mov     rsi, r14
    mov     rdx, r12
    call    copy_field
    mov     r14, rax
    lea     rdi, [rel source_logical_buf]
    mov     rsi, r14
    mov     rdx, r12
    call    copy_field
    lea     rdi, [rel source_entry_buf]
    call    cstr_len
    mov     rsi, rax
    lea     rdi, [rel source_entry_buf]
    call    build_x86_paths
    call    materialize_source_object_if_needed
    lea     rdi, [rel yasm_path]
    lea     rsi, [rel argv_yasm_x86_object]
    call    run_process
    test    eax, eax
    jnz     build_fail
.advance:
    cmp     r12, r13
    jae     .line_loop
    inc     r12
    jmp     .line_loop
.done:
    lea     rdi, [rel msg_x86_objects_ok]
    call    print_cstr_stdout
    ret

; build_host_source_path()
build_host_source_path:
    push    r12
    push    r14
    push    r15
    call    source_kind_is_object
    test    eax, eax
    jnz     .object_source
    lea     rdi, [rel source_path_buf]
    lea     rsi, [rel source_object_path_buf]
    call    copy_cstr
    jmp     .done
.object_source:
    lea     r12, [rel source_object_path_buf]
    mov     r14, r12
.base_scan:
    mov     al, [r12]
    test    al, al
    jz      .base_found
    cmp     al, '/'
    jne     .base_next
    lea     r14, [r12 + 1]
.base_next:
    inc     r12
    jmp     .base_scan
.base_found:
    mov     r15, r12
    sub     r15, r14
    cmp     r15, EROBJ_SUFFIX_LEN
    jbe     build_fail
    sub     r15, EROBJ_SUFFIX_LEN
    lea     rdi, [rel source_path_buf]
    lea     rsi, [rel host_source_materialized_prefix]
    call    copy_cstr
    mov     rdi, rax
    mov     rsi, r14
    mov     rdx, r15
    call    copy_bytes
    mov     byte [rax], 0
.done:
    pop     r15
    pop     r14
    pop     r12
    ret

; build_x86_paths(line_ptr, line_len) -> eax=1 when source object was materialized
build_x86_paths:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13, rsi
    mov     r10, r12

    lea     rdi, [rel source_object_path_buf]
    lea     rsi, [rel x86_source_prefix]
    call    copy_cstr
    mov     rdi, rax
    mov     rsi, r10
    mov     rdx, r13
    call    copy_bytes
    mov     byte [rax], 0

    lea     rdi, [rel source_path_buf]
    lea     rsi, [rel x86_source_prefix]
    call    copy_cstr
    mov     rdi, rax
    mov     rsi, r10
    mov     rdx, r13
    call    copy_bytes
    mov     byte [rax], 0

    mov     r14, r12
    mov     rbx, r12
    add     rbx, r13
.base_scan:
    cmp     r12, rbx
    jae     .base_found
    cmp     byte [r12], '/'
    jne     .base_next
    lea     r14, [r12 + 1]
.base_next:
    inc     r12
    jmp     .base_scan
.base_found:
    mov     r15, rbx
    sub     r15, r14
    xor     r11d, r11d
    call    source_kind_is_object
    test    eax, eax
    jz      .plain_source
    mov     r11d, 1
    lea     rdi, [rel source_path_buf]
    lea     rsi, [rel x86_source_materialized_prefix]
    call    copy_cstr
    mov     rdi, rax
    lea     rsi, [rel source_logical_buf]
    call    copy_cstr
    jmp     .object_path
.plain_source:
    cmp     r15, 4
    jb      build_fail
    sub     r15, 4

.object_path:
    lea     rdi, [rel object_stem_buf]
    call    cstr_len
    test    rax, rax
    jz      build_fail
    lea     rdi, [rel object_path_buf]
    lea     rsi, [rel x86_object_prefix]
    call    copy_cstr
    mov     rdi, rax
    lea     rsi, [rel object_stem_buf]
    call    copy_cstr
    mov     rdi, rax
    lea     rsi, [rel object_suffix]
    call    copy_cstr

    mov     eax, r11d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; copy_cstr(dst, src) -> rax=end ptr after copied bytes, NUL written
copy_cstr:
.loop:
    mov     al, [rsi]
    mov     [rdi], al
    test    al, al
    jz      .done
    inc     rdi
    inc     rsi
    jmp     .loop
.done:
    mov     rax, rdi
    ret

; copy_bytes(dst, src, len) -> rax=end ptr
copy_bytes:
    test    rdx, rdx
    jz      .done
.loop:
    mov     al, [rsi]
    mov     [rdi], al
    inc     rdi
    inc     rsi
    dec     rdx
    jnz     .loop
.done:
    mov     rax, rdi
    ret

; copy_field(dst, ptr, end) -> rax=next ptr after '|' or newline
copy_field:
    push    r12
    mov     r12, rdx
.loop:
    cmp     rsi, r12
    jae     .finish
    mov     al, [rsi]
    inc     rsi
    cmp     al, '|'
    je      .finish
    cmp     al, 10
    je      .finish
    mov     [rdi], al
    inc     rdi
    jmp     .loop
.finish:
    mov     byte [rdi], 0
    mov     rax, rsi
    pop     r12
    ret

; materialize_source_object_if_needed() -> eax=1 when materialized, 0 otherwise
materialize_source_object_if_needed:
    call    source_kind_is_object
    test    eax, eax
    jz      .plain
    lea     rdi, [rel source_path_buf]
    call    ensure_parent_dir
    lea     rdi, [rel source_object_path_buf]
    lea     rsi, [rel source_path_buf]
    call    write_object_body_file
    mov     eax, 1
    ret
.plain:
    xor     eax, eax
    ret

source_kind_is_object:
    lea     rdi, [rel source_kind_buf]
    lea     rsi, [rel source_kind_object]
    call    streq
    ret

validate_source_kind:
    lea     rdi, [rel source_kind_buf]
    lea     rsi, [rel source_kind_source]
    call    streq
    test    eax, eax
    jnz     .ok
    lea     rdi, [rel source_kind_buf]
    lea     rsi, [rel source_kind_object]
    call    streq
    test    eax, eax
    jz      bad_object
.ok:
    ret

; ensure_parent_dir(path)
ensure_parent_dir:
    push    r12
    push    r13
    push    r14
    mov     r14, rdi
    mov     r12, rdi
    xor     r13d, r13d
.scan:
    mov     al, [r12]
    test    al, al
    jz      .ready
    cmp     al, '/'
    jne     .next
    mov     r13, r12
.next:
    inc     r12
    jmp     .scan
.ready:
    test    r13, r13
    jz      .done
    mov     byte [r13], 0
    mov     rdi, r14
    mov     esi, DIR_MODE_0755
    mov     eax, SYS_mkdir
    syscall
    mov     byte [r13], '/'
.done:
    pop     r14
    pop     r13
    pop     r12
    ret

; run_process(path, argv) -> eax=0 on clean exit, 1 otherwise
run_process_quiet:
    mov     qword [rel process_quiet], 1
    call    run_process
    mov     qword [rel process_quiet], 0
    ret

run_process:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    mov     eax, SYS_fork
    syscall
    test    rax, rax
    js      .fail
    jz      .child
    mov     rdi, rax
    lea     rsi, [rel wait_status]
    xor     edx, edx
    xor     r10d, r10d
    mov     eax, SYS_wait4
    syscall
    test    rax, rax
    js      .fail
    mov     eax, [rel wait_status]
    test    eax, eax
    jnz     .fail
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    ret
.child:
    cmp     qword [rel process_quiet], 0
    je      .exec
    lea     rdi, [rel dev_null_path]
    mov     esi, O_WRONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      .exec
    mov     rdi, rax
    mov     esi, STDOUT_FD
    mov     eax, SYS_dup2
    syscall
    mov     eax, SYS_close
    syscall
.exec:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel null_env]
    mov     eax, SYS_execve
    syscall
    mov     edi, 127
    jmp     exit_now
.fail:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbx
    ret

cmd_test_list:
    lea     rdi, [rel registry_path]
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object

    lea     rdi, [rel test_list_header]
    call    print_cstr_stdout
    call    write_registry_test_list
    ret

cmd_test_registry:
    lea     rdi, [rel registry_path]
    call    cmd_write_body
    ret

; cmd_test_status(argv_targets, count). count=0 runs the deterministic build subset.
cmd_test_status:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    lea     rdi, [rel test_status_header]
    call    print_cstr_stdout
    test    r13, r13
    jnz     .requested
    lea     rdi, [rel arg_test_registry]
    call    run_test_status_target
    lea     rdi, [rel arg_test_er_asm_parse]
    call    run_test_status_target
    lea     rdi, [rel arg_test_er_asm_cli]
    call    run_test_status_target
    jmp     .done
.requested:
    xor     ebx, ebx
.loop:
    cmp     rbx, r13
    jae     .done
    mov     rdi, [r12 + rbx * 8]
    call    run_test_status_target
    inc     rbx
    jmp     .loop
.done:
    pop     r13
    pop     r12
    pop     rbx
    ret

run_test_status_target:
    push    r12
    push    r13
    mov     r12, rdi
    lea     rsi, [rel arg_test_registry]
    call    streq
    test    eax, eax
    jnz     .registry
    mov     rdi, r12
    lea     rsi, [rel arg_test_er_asm_parse]
    call    streq
    test    eax, eax
    jnz     .er_asm_parse
    mov     rdi, r12
    lea     rsi, [rel arg_test_er_asm_cli]
    call    streq
    test    eax, eax
    jnz     .er_asm_cli
    mov     rdi, r12
    call    print_cstr_stdout
    lea     rdi, [rel test_status_unknown_tail]
    call    print_cstr_stdout
    jmp     .done
.registry:
    lea     rdi, [rel registry_path]
    call    read_object
    test    rax, rax
    js      .registry_fail
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      .registry_fail
    lea     rdi, [rel test_status_registry_pass]
    call    print_cstr_stdout
    jmp     .done
.registry_fail:
    lea     rdi, [rel test_status_registry_fail]
    call    print_cstr_stdout
    jmp     .done
.er_asm_parse:
    lea     rdi, [rel er_asm_path]
    lea     rsi, [rel argv_er_asm_parse_test]
    call    run_process_quiet
    test    eax, eax
    jnz     .parse_fail
    lea     rdi, [rel test_status_er_asm_parse_pass]
    call    print_cstr_stdout
    jmp     .done
.parse_fail:
    lea     rdi, [rel test_status_er_asm_parse_fail]
    call    print_cstr_stdout
    jmp     .done
.er_asm_cli:
    lea     rdi, [rel er_asm_path]
    lea     rsi, [rel argv_er_asm_cli_test]
    call    run_process_quiet
    test    eax, eax
    jnz     .cli_fail
    lea     rdi, [rel test_status_er_asm_cli_pass]
    call    print_cstr_stdout
    jmp     .done
.cli_fail:
    lea     rdi, [rel test_status_er_asm_cli_fail]
    call    print_cstr_stdout
.done:
    pop     r13
    pop     r12
    ret

cmd_validate_object_path:
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object
    ret

cmd_help:
    lea     rdi, [rel help_top_path]
    call    cmd_write_body
    call    cmd_test_help
    lea     rdi, [rel help_bottom_path]
    call    cmd_write_body
    ret

cmd_test_help:
    lea     rdi, [rel registry_path]
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object
    call    write_registry_help
    ret

cmd_write_body:
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object
    call    write_object_body
    ret

write_object_body:
    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     bad_object
    mov     rdx, rax
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     edi, STDOUT_FD
    mov     eax, SYS_write
    syscall
    ret

; write_object_body_file(object_path, output_path)
write_object_body_file:
    push    r12
    push    r13
    mov     r13, rsi
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object
    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     bad_object
    mov     r12, rax
    mov     rdi, r13
    mov     esi, O_WRONLY_CREAT_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      build_fail
    mov     r13, rax
    mov     rdi, r13
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     rdx, r12
    mov     eax, SYS_write
    syscall
    cmp     rax, r12
    jne     build_fail
    mov     rdi, r13
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      build_fail
    pop     r13
    pop     r12
    ret

write_raw_file:
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     rdi, r12
    call    ensure_parent_dir
    mov     rdi, r12
    mov     esi, O_WRONLY_CREAT_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      build_fail
    mov     r12, rax
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     eax, SYS_write
    syscall
    cmp     rax, r14
    jne     build_fail
    mov     rdi, r12
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      build_fail
    pop     r14
    pop     r13
    pop     r12
    ret

validate_isa_body:
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    test    r12, r12
    jz      .bad_arg
    cmp     r13, ISA_BODY_HEADER_SIZE
    jb      .bad_arg
    mov     rax, [r12 + ISA_BODY_OF_MAGIC]
    mov     rdx, ISA_BODY_MAGIC_QWORD
    cmp     rax, rdx
    jne     .bad_arg
    cmp     word [r12 + ISA_BODY_OF_VERSION], ISA_BODY_VERSION
    jne     .bad_arg
    movzx   eax, word [r12 + ISA_BODY_OF_ISA]
    cmp     eax, ISA_ID_X86_64
    jb      .unsupported
    cmp     eax, ISA_ID_WASM
    ja      .unsupported
    mov     r10d, [r12 + ISA_BODY_OF_DEF_COUNT]
    test    r10d, r10d
    jz      .bad_arg
    mov     rax, r10
    imul    rax, ISA_DEF_SIZE
    jo      .bad_arg
    add     rax, ISA_BODY_HEADER_SIZE
    jc      .bad_arg
    cmp     rax, r13
    jne     .bad_arg
    xor     ecx, ecx
    xor     r11d, r11d
.record_loop:
    cmp     ecx, r10d
    jae     .success
    mov     r9, rcx
    imul    r9, ISA_DEF_SIZE
    lea     r9, [r12 + ISA_BODY_HEADER_SIZE + r9]
    mov     eax, [r9 + ISA_DEF_OF_INSTRUCTION_ID]
    test    eax, eax
    jz      .bad_arg
    cmp     eax, r11d
    jbe     .bad_arg
    mov     r11d, eax
    cmp     word [r9 + ISA_DEF_OF_MNEMONIC_ID], 0
    je      .bad_arg
    cmp     word [r9 + ISA_DEF_OF_OPERAND_SHAPE], 0
    je      .bad_arg
    cmp     word [r9 + ISA_DEF_OF_ENCODING_SHAPE], 0
    je      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_INPUT_COUNT], 8
    ja      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_OUTPUT_COUNT], 8
    ja      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_IMPLICIT_COUNT], 16
    ja      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_RESERVED], 0
    jne     .bad_arg
    inc     ecx
    jmp     .record_loop
.success:
    mov     eax, r10d
    xor     edx, edx
    jmp     .done
.bad_arg:
    xor     eax, eax
    mov     edx, 1
    jmp     .done
.unsupported:
    xor     eax, eax
    mov     edx, 4
.done:
    pop     r13
    pop     r12
    ret

; write_file_object(input_path, output_path)
write_file_object:
    mov     edx, OBJECT_KIND_BYTES
    jmp     write_file_object_kind

write_file_isa_object:
    mov     edx, OBJECT_KIND_ISA

write_file_object_kind:
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rsi
    mov     r15d, edx

    mov     rsi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      build_fail
    mov     r14, rax

    mov     rdi, r14
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     edx, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    mov     eax, SYS_read
    syscall
    test    rax, rax
    js      build_fail
    cmp     rax, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    jae     build_fail
    mov     r13, rax

    mov     rdi, r14
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      build_fail

    cmp     r15d, OBJECT_KIND_ISA
    jne     .header
    lea     rdi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     rsi, r13
    call    validate_isa_body
    test    edx, edx
    jnz     build_fail

.header:
    mov     edi, r15d
    call    init_object_header_kind

    mov     rdi, r12
    call    ensure_parent_dir
    mov     rdi, r12
    mov     esi, O_WRONLY_CREAT_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      build_fail
    mov     r14, rax

    mov     rdi, r14
    lea     rsi, [rel object_buf]
    lea     rdx, [r13 + OBJECT_HEADER_SIZE]
    mov     eax, SYS_write
    syscall
    lea     rdx, [r13 + OBJECT_HEADER_SIZE]
    cmp     rax, rdx
    jne     build_fail

    mov     rdi, r14
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      build_fail
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret

; cmd_replace_range(object, offset_text, delete_len_text, insert_file, output_object)
cmd_replace_range:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi            ; object path
    mov     rbx, r8             ; output path
    mov     rbp, rcx            ; insert file path
    mov     rdi, rsi
    call    parse_u64_or_fail
    mov     r14, rax            ; offset
    mov     rdi, rdx
    call    parse_u64_or_fail
    mov     r15, rax            ; delete length

    mov     rdi, r12
    call    read_object
    test    rax, rax
    js      bad_object
    mov     rdi, rax
    call    validate_object
    test    eax, eax
    jz      bad_object
    mov     r12, [rel object_buf + 32] ; original body length
    cmp     r14, r12
    ja      build_fail
    mov     rax, r12
    sub     rax, r14
    cmp     r15, rax
    ja      build_fail

    mov     rdi, rbp
    call    read_insert_file
    mov     rbp, rax            ; insert length

    mov     r13, r12
    sub     r13, r15
    add     r13, rbp            ; new body length
    jc      build_fail
    cmp     r13, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    jae     build_fail

    lea     rdi, [rel source_list_buf]
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     rdx, r14
    call    copy_bytes
    mov     rdi, rax
    lea     rsi, [rel edit_buf]
    mov     rdx, rbp
    call    copy_bytes
    mov     rdi, rax
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    add     rsi, r14
    add     rsi, r15
    mov     rdx, r12
    sub     rdx, r14
    sub     rdx, r15
    call    copy_bytes

    call    init_object_header
    lea     rdi, [rel object_buf + OBJECT_HEADER_SIZE]
    lea     rsi, [rel source_list_buf]
    mov     rdx, r13
    call    copy_bytes
    mov     rdi, rbx
    call    write_current_object_file
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

read_insert_file:
    push    r12
    push    r13
    mov     rsi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      build_fail
    mov     r12, rax
    mov     rdi, r12
    lea     rsi, [rel edit_buf]
    mov     edx, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    mov     eax, SYS_read
    syscall
    test    rax, rax
    js      build_fail
    cmp     rax, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    jae     build_fail
    mov     r13, rax
    mov     rdi, r12
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      build_fail
    mov     rax, r13
    pop     r13
    pop     r12
    ret

write_current_object_file:
    push    r12
    mov     r12, rdi
    call    ensure_parent_dir
    mov     rdi, r12
    mov     esi, O_WRONLY_CREAT_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      build_fail
    mov     r12, rax
    mov     rdi, r12
    lea     rsi, [rel object_buf]
    lea     rdx, [r13 + OBJECT_HEADER_SIZE]
    mov     eax, SYS_write
    syscall
    lea     rdx, [r13 + OBJECT_HEADER_SIZE]
    cmp     rax, rdx
    jne     build_fail
    mov     rdi, r12
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      build_fail
    pop     r12
    ret

parse_u64_or_fail:
    xor     eax, eax
.loop:
    movzx   ecx, byte [rdi]
    test    ecx, ecx
    jz      .done
    cmp     ecx, '0'
    jb      build_fail
    cmp     ecx, '9'
    ja      build_fail
    imul    rax, rax, 10
    sub     ecx, '0'
    add     rax, rcx
    inc     rdi
    jmp     .loop
.done:
    ret

init_object_header:
    mov     edi, OBJECT_KIND_BYTES

init_object_header_kind:
    mov     r8d, edi
    lea     rdi, [rel object_buf]
    mov     ecx, OBJECT_HEADER_SIZE
.zero:
    mov     byte [rdi], 0
    inc     rdi
    loop    .zero
    mov     rax, 0x3130304a424f5245
    mov     [rel object_buf], rax
    mov     word [rel object_buf + 8], OBJECT_VERSION
    mov     word [rel object_buf + 10], r8w
    mov     qword [rel object_buf + 16], r13
    mov     qword [rel object_buf + 32], r13
    ret

init_object_header_receipt:
    mov     edi, OBJECT_KIND_RECEIPT
    jmp     init_object_header_kind

write_registry_test_list:
    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     bad_object
    lea     r12, [rel object_buf + OBJECT_HEADER_SIZE]
    lea     r13, [r12 + rax]
    mov     r14d, 1
.loop:
    cmp     r12, r13
    jae     .done
    movzx   edi, byte [r12]
    inc     r12
    cmp     dil, '|'
    je      .pipe
    cmp     dil, 10
    je      .newline
    cmp     r14d, 5
    je      .loop
    call    write_byte_stdout
    jmp     .loop
.pipe:
    cmp     r14d, 5
    je      .field_next
    cmp     r14d, 4
    ja      .field_next
    mov     edi, 9
    call    write_byte_stdout
.field_next:
    inc     r14d
    jmp     .loop
.newline:
    mov     edi, 10
    call    write_byte_stdout
    mov     r14d, 1
    jmp     .loop
.done:
    ret

write_registry_help:
    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     bad_object
    lea     r12, [rel object_buf + OBJECT_HEADER_SIZE]
    lea     r13, [r12 + rax]
    mov     r14d, 1
    xor     r15d, r15d
    lea     rdi, [rel help_line_prefix]
    call    print_cstr_stdout
.loop:
    cmp     r12, r13
    jae     .done
    movzx   edi, byte [r12]
    inc     r12
    cmp     dil, '|'
    je      .pipe
    cmp     dil, 10
    je      .newline
    cmp     r14d, 4
    je      .loop
    cmp     r14d, 5
    je      .loop
    call    write_byte_stdout
    cmp     r14d, 1
    jne     .loop
    inc     r15d
    jmp     .loop
.pipe:
    cmp     r14d, 1
    je      .target_done
    cmp     r14d, 2
    je      .category_done
    cmp     r14d, 3
    je      .subsystem_done
    inc     r14d
    jmp     .loop
.target_done:
    call    write_target_padding
    lea     rdi, [rel help_meta_open]
    call    print_cstr_stdout
    inc     r14d
    jmp     .loop
.category_done:
    mov     edi, '/'
    call    write_byte_stdout
    inc     r14d
    jmp     .loop
.subsystem_done:
    lea     rdi, [rel help_meta_close]
    call    print_cstr_stdout
    inc     r14d
    jmp     .loop
.newline:
    mov     edi, 10
    call    write_byte_stdout
    mov     r14d, 1
    xor     r15d, r15d
    cmp     r12, r13
    jae     .done
    lea     rdi, [rel help_line_prefix]
    call    print_cstr_stdout
    jmp     .loop
.done:
    ret

write_target_padding:
    cmp     r15d, 22
    jae     .done
.loop:
    mov     edi, ' '
    call    write_byte_stdout
    inc     r15d
    cmp     r15d, 22
    jb      .loop
.done:
    ret

%include "host/er_object_file.inc"

streq:
    xor     eax, eax
.loop:
    mov     dl, [rdi + rax]
    cmp     dl, [rsi + rax]
    jne     .no
    test    dl, dl
    jz      .yes
    inc     rax
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

print_cstr_stdout:
    push    rdi
    call    cstr_len
    mov     rdx, rax
    pop     rsi
    mov     edi, STDOUT_FD
    mov     eax, SYS_write
    syscall
    ret

write_byte_stdout:
    mov     [rel byte_buf], dil
    lea     rsi, [rel byte_buf]
    mov     edx, 1
    mov     edi, STDOUT_FD
    mov     eax, SYS_write
    syscall
    ret

print_cstr_stderr:
    push    rdi
    call    cstr_len
    mov     rdx, rax
    pop     rsi
    mov     edi, STDERR_FD
    mov     eax, SYS_write
    syscall
    ret

cstr_len:
    xor     eax, eax
.loop:
    cmp     byte [rdi + rax], 0
    je      .done
    inc     rax
    jmp     .loop
.done:
    ret

exit_now:
    mov     eax, SYS_exit_group
    syscall

section .rodata
arg_test_list: db "test-list", 0
arg_test_registry: db "test-registry", 0
arg_test_status: db "test-status", 0
arg_test_er_asm_parse: db "test-er-asm-parse", 0
arg_test_er_asm_cli: db "test-er-asm-cli", 0
arg_help: db "help", 0
arg_x86_sources: db "x86-sources", 0
arg_pi_sources: db "pi-sources", 0
arg_host_tools: db "host-tools", 0
arg_er_asm: db "er-asm", 0
arg_x86_objects: db "x86-objects", 0
arg_validate_object: db "validate-object", 0
arg_view: db "view", 0
arg_body_to_file: db "body-to-file", 0
arg_file_to_object: db "file-to-object", 0
arg_file_to_isa_object: db "file-to-isa-object", 0
arg_replace_range: db "replace-range", 0
registry_path: db "kernel/test/registry.erobj", 0
x86_sources_path: db "kernel/x86_64/kernel_sources.erobj", 0
pi_sources_path: db "kernel/arm/pi/kernel_sources.erobj", 0
help_top_path: db "docs/build-help-top.erobj", 0
help_bottom_path: db "docs/build-help-bottom.erobj", 0
host_tools_path: db "kernel/host/host_tools.erobj", 0
test_list_header: db "target", 9, "category", 9, "subsystem", 9, "default", 9, "description", 10, 0
help_line_prefix: db "  ", 0
help_meta_open: db " [", 0
help_meta_close: db "] ", 0
msg_usage: db "usage: er_build help|test-list|test-registry|test-status [TARGET...]|x86-sources|pi-sources|host-tools|er-asm|x86-objects|validate-object OBJECT|view OBJECT|body-to-file OBJECT OUTPUT|file-to-object INPUT OUTPUT.erobj|file-to-isa-object INPUT OUTPUT.erobj|replace-range OBJECT OFFSET DELETE_LEN INSERT_FILE OUTPUT.erobj", 10, 0
msg_bad_object: db "error: invalid build registry object", 10, 0
msg_build_fail: db "error: host tool build failed", 10, 0
msg_host_tools_ok: db "host-tools: .build/host/er_obj_body .build/host/er_obj_wrap .build/host/er_build.next .build/host/er_asm", 10, 0
msg_x86_objects_ok: db "x86-objects: .build/kernel/kernel_*.o", 10, 0
test_status_header: db "target", 9, "category", 9, "subsystem", 9, "status", 9, "log", 10, 0
test_status_registry_pass: db "test-registry", 9, "unit", 9, "build", 9, "pass", 9, "registry object validated", 10, 0
test_status_registry_fail: db "test-registry", 9, "unit", 9, "build", 9, "fail", 9, "registry object invalid", 10, 0
test_status_er_asm_parse_pass: db "test-er-asm-parse", 9, "unit", 9, "build", 9, "pass", 9, "er_asm interpreted committed source object", 10, 0
test_status_er_asm_parse_fail: db "test-er-asm-parse", 9, "unit", 9, "build", 9, "fail", 9, "er_asm parse probe failed", 10, 0
test_status_er_asm_cli_pass: db "test-er-asm-cli", 9, "unit", 9, "build", 9, "pass", 9, "er_asm assembled committed source object", 10, 0
test_status_er_asm_cli_fail: db "test-er-asm-cli", 9, "unit", 9, "build", 9, "fail", 9, "er_asm CLI probe failed", 10, 0
test_status_unknown_tail: db 9, "unknown", 9, "unknown", 9, "fail", 9, "unsupported test-status target", 10, 0
build_dir: db ".build", 0
host_build_dir: db ".build/host", 0
kernel_build_dir: db ".build/kernel", 0
yasm_path: db "/usr/bin/yasm", 0
ld_path: db "/usr/bin/ld", 0
arg_yasm: db "yasm", 0
arg_ld: db "ld", 0
arg_f: db "-f", 0
arg_elf64: db "elf64", 0
arg_include: db "-I", 0
arg_kernel: db "kernel", 0
arg_o: db "-o", 0
arg_flat: db "flat", 0
arg_parse_only: db "--parse-only", 0
arg_interpret: db "--interpret", 0
arg_elf32: db "elf32", 0
arg_nostdlib: db "-nostdlib", 0
arg_static: db "-static", 0
source_kind_source: db "source", 0
source_kind_object: db "object", 0
x86_source_prefix: db "kernel/x86_64/", 0
x86_source_materialized_prefix: db ".build/kernel/source/", 0
host_source_materialized_prefix: db ".build/host/", 0
x86_object_prefix: db ".build/kernel/kernel_", 0
object_suffix: db ".o", 0
kernel_source_build_dir: db ".build/kernel/source", 0
er_asm_path: db ".build/host/er_asm", 0
er_asm_source_object_path: db "kernel/host/er_asm.asm.erobj", 0
er_asm_cli_source_path: db "kernel/test/test_flat_runtime.asm.erobj", 0
er_asm_cli_probe_path: db ".build/host/er_asm_cli_probe.bin", 0
dev_null_path: db "/dev/null", 0
null_env: dq 0
argv_yasm_host_tool: dq arg_yasm, arg_f, arg_elf64, arg_include, arg_kernel, arg_o, object_path_buf, source_path_buf, 0
argv_ld_host_tool: dq arg_ld, arg_nostdlib, arg_static, arg_o, binary_path_buf, object_path_buf, 0
argv_yasm_x86_object: dq arg_yasm, arg_f, arg_elf32, arg_include, arg_kernel, arg_o, object_path_buf, source_path_buf, 0
argv_er_asm_parse_test: dq er_asm_path, arg_interpret, er_asm_source_object_path, 0
argv_er_asm_cli_test: dq er_asm_path, arg_f, arg_flat, arg_include, arg_kernel, arg_o, er_asm_cli_probe_path, er_asm_cli_source_path, 0

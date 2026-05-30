; ==================================================================
; wasm_jit_templates.asm — JIT opcode emission templates
;
; Each template emits x86_64 instructions into jit_state.code_ptr
; to implement one WASM opcode in native code.
;
; Register model (JIT'd code at runtime):
;   r15  = JitGlobals (set by trampoline)
;   rax  = scratch
;   rcx  = scratch
;   rdx  = scratch
;   rsp  = WASM value stack (push/pop for all values)
;
; Template calling convention (at compile time):
;   rdi = DecodedOp pointer (offset+4, next_offset+4, opcode+1, pad+3, imm0+4, imm1+4)
;   All emitter functions called by templates clobber rax, rcx, rdx.
;   No callee-save needed — orchestrator saves/restores around each template call.
; =================================================================+

; ------------------------------------------------------------------
; Template: unreachable (0x00)
; Emit: ud2
; -----------------------------------------------------------------+
er_fn jit_template_unreachable
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x0B         ; ud2
    call    jit_emit_byte
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: nop (0x01)
; -----------------------------------------------------------------+
er_fn jit_template_nop
    pop     rbp
    ret

; Control flow ops (0x02-0x0D, 0x0F-0x11) are handled directly by
; the orchestrator (wasm_jit.asm), not by templates.

; ------------------------------------------------------------------
; Template: drop (0x1A) — discard TOS
; Emit: add rsp, 8
; -----------------------------------------------------------------+
er_fn jit_template_drop
    mov     al, 0x48         ; REX.W
    call    jit_emit_byte
    mov     al, 0x83         ; add r/m64, imm8
    call    jit_emit_byte
    mov     al, 0xC4         ; ModRM: mod=11, reg=0(add), rm=4(rsp)
    call    jit_emit_modrm
    mov     al, 8            ; imm8 — add rsp, 8
    call    jit_emit_byte
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: local.get index (0x20)
; Emit: mov rdx, [r15 + JitGlobals.locals]
;       mov rax, [rdx + index*8]
;       push rax
; -----------------------------------------------------------------+
er_fn jit_template_local_get
    mov     cl, 2            ; rdx
    mov     eax, JitGlobals.locals
    call    jit_emit_load_global_to_reg
    mov     ecx, [rdi + 12]  ; local index
    shl     ecx, 3           ; *8
    ; mov rax, [rdx + rcx]
    mov     cl, 1            ; REX.W
    call    jit_emit_rex_nob
    mov     al, 0x8B         ; mov r64, r/m64
    call    jit_emit_byte
    mov     al, 0x04         ; ModRM: mod=00, reg=0(rax), rm=4(SIB)
    call    jit_emit_modrm
    mov     al, 0x0A         ; SIB: scale=0, index=1(rcx), base=2(rdx)
    call    jit_emit_sib
    ; push rax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: local.set index (0x21)
; Emit: pop rax; mov rdx, [r15 + JitGlobals.locals]; mov [rdx + index*8], rax
; -----------------------------------------------------------------+
er_fn jit_template_local_set
    ; pop rax
    xor     ecx, ecx         ; rax
    call    jit_emit_pop_reg
    ; load locals base into rdx
    push    rax              ; save value while we compute addr
    mov     cl, 2            ; rdx
    mov     eax, JitGlobals.locals
    call    jit_emit_load_global_to_reg
    mov     ecx, [rdi + 12]  ; local index
    shl     ecx, 3
    ; mov [rdx + rcx], rax
    pop     rax              ; restore value
    push    rax
    mov     cl, 1            ; REX.W
    call    jit_emit_rex_nob
    mov     al, 0x89         ; mov r/m64, r64
    call    jit_emit_byte
    mov     al, 0x04         ; ModRM: mod=00, reg=0(rax), rm=4(SIB)
    call    jit_emit_modrm
    mov     al, 0x0A         ; SIB: scale=0, index=1(rcx), base=2(rdx)
    call    jit_emit_sib
    pop     rax              ; consumed
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: local.tee index (0x22)
; Emit: same as local.set but keep value on stack
; -----------------------------------------------------------------+
er_fn jit_template_local_tee
    ; duplicate TOS: mov rax, [rsp]; push rax
    mov     cl, 1            ; REX.W
    call    jit_emit_rex_nob
    mov     al, 0x8B         ; mov rax, [rsp]
    call    jit_emit_byte
    mov     al, 0x04         ; ModRM SIB
    call    jit_emit_modrm
    mov     al, 0x24         ; SIB: [rsp]
    call    jit_emit_sib
    mov     al, 0x00         ; disp8 = 0
    call    jit_emit_byte
    xor     ecx, ecx         ; rax
    call    jit_emit_push_reg
    ; now do local.set
    mov     cl, 1            ; REX
    call    jit_emit_rex_nob
    mov     al, 0x89         ; mov r/m64, r64
    call    jit_emit_byte
    mov     al, 0x04         ; ModRM SIB
    call    jit_emit_modrm
    mov     al, 0x24         ; SIB: [rsp]
    call    jit_emit_sib
    mov     al, 0x00         ; disp8
    call    jit_emit_byte
    ; pop rax
    xor     ecx, ecx
    call    jit_emit_pop_reg
    ; load locals base into rdx
    push    rax
    mov     cl, 2
    mov     eax, JitGlobals.locals
    call    jit_emit_load_global_to_reg
    mov     ecx, [rdi + 12]
    shl     ecx, 3
    pop     rax
    push    rax
    mov     cl, 1
    call    jit_emit_rex_nob
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0x04
    call    jit_emit_modrm
    mov     al, 0x0A
    call    jit_emit_sib
    pop     rax
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: global.get index (0x23)
; Emit: mov rdx, [r15 + JitGlobals.globals_buf]; mov rax, [rdx + index*32]; push rax
; -----------------------------------------------------------------+
er_fn jit_template_global_get
    mov     cl, 2
    mov     eax, JitGlobals.globals_buf
    call    jit_emit_load_global_to_reg
    mov     ecx, [rdi + 12]
    imul    ecx, 32          ; GLOBAL_SIZE = 32
    ; mov rax, [rdx + rcx] — just load value_data at offset 8 within Global struct
    ; Global layout: value_type(1) + mutable(1) + pad(6) + value_data(8) + value_tag(4) + pad(4) = 24, padded to 32
    ; value_data is at offset 8
    add     ecx, 8
    mov     cl, 1
    call    jit_emit_rex_nob
    mov     al, 0x8B
    call    jit_emit_byte
    mov     al, 0x04
    call    jit_emit_modrm
    mov     al, 0x0A         ; SIB: [rdx + rcx]
    call    jit_emit_sib
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: global.set index (0x24)
; -----------------------------------------------------------------+
er_fn jit_template_global_set
    xor     ecx, ecx
    call    jit_emit_pop_reg
    push    rax
    mov     cl, 2
    mov     eax, JitGlobals.globals_buf
    call    jit_emit_load_global_to_reg
    mov     ecx, [rdi + 12]
    imul    ecx, 32
    add     ecx, 8           ; value_data offset
    pop     rax
    push    rax
    mov     cl, 1
    call    jit_emit_rex_nob
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0x04
    call    jit_emit_modrm
    mov     al, 0x0A
    call    jit_emit_sib
    pop     rax
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: i32.const imm (0x41)
; Emit: push imm32
; -----------------------------------------------------------------+
er_fn jit_template_i32_const
    mov     eax, [rdi + 12]  ; imm0
    call    jit_emit_push_imm32
    pop     rbp
    ret

; ------------------------------------------------------------------
; Template: i64.const imm (0x42)
; Emit: push imm64 — uses mov rax, imm64; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i64_const
    mov     eax, [rdi + 12]  ; imm0 (low)
    mov     edx, [rdi + 16]  ; imm1 (high)
    shl     rdx, 32
    or      rax, rdx
    ; mov rax, imm64
    mov     cl, 1            ; W=1
    mov     ch, 0
    xor     r8b, r8b
    xor     r9b, r9b
    call    jit_emit_rex
    mov     al, 0xB8         ; mov rax, imm64
    call    jit_emit_byte
    mov     eax, [rdi + 12]
    mov     edx, [rdi + 16]
    shl     rdx, 32
    or      rax, rdx
    call    jit_emit_qword
    ; push rax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; Emit: push imm32 (5-byte push)
; eax = value
; -----------------------------------------------------------------+
er_fn jit_emit_push_imm32
    push    rax
    mov     al, 0x68         ; push imm32
    call    jit_emit_byte
    pop     rax
    call    jit_emit_dword
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 eqz (0x45)
; Emit: pop rax; test eax, eax; sete al; movzx eax, al; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_eqz
    xor     ecx, ecx         ; pop rax
    call    jit_emit_pop_reg
    call    jit_emit_test32
    mov     cl, 0x94         ; sete
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx         ; push rax
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 eq (0x46)
; Emit: pop rcx; pop rax; cmp eax, ecx; sete al; movzx eax, al; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_eq
    mov     cl, 1            ; pop rcx
    call    jit_emit_pop_reg
    xor     ecx, ecx         ; pop rax
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x94         ; sete
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx         ; push rax
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 ne (0x47)
; -----------------------------------------------------------------+
er_fn jit_template_i32_ne
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x95         ; setne
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 lt_s (0x48)
; -----------------------------------------------------------------+
er_fn jit_template_i32_lt_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x9C         ; setl
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 lt_u (0x49)
; -----------------------------------------------------------------+
er_fn jit_template_i32_lt_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x92         ; setb
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 gt_s (0x4A)
; -----------------------------------------------------------------+
er_fn jit_template_i32_gt_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x9F         ; setg
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 gt_u (0x4B)
; -----------------------------------------------------------------+
er_fn jit_template_i32_gt_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x97         ; seta
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 le_s (0x4C)
; -----------------------------------------------------------------+
er_fn jit_template_i32_le_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x9E         ; setle
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 le_u (0x4D)
; -----------------------------------------------------------------+
er_fn jit_template_i32_le_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x96         ; setbe
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 ge_s (0x4E)
; -----------------------------------------------------------------+
er_fn jit_template_i32_ge_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x9D         ; setge
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 ge_u (0x4F)
; -----------------------------------------------------------------+
er_fn jit_template_i32_ge_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp32
    mov     cl, 0x93         ; setae
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 clz (0x67)
; Emit: pop rax; lzcnt eax, eax; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_clz
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_lzcnt32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 ctz (0x68)
; -----------------------------------------------------------------+
er_fn jit_template_i32_ctz
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_tzcnt32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 popcnt (0x69)
; -----------------------------------------------------------------+
er_fn jit_template_i32_popcnt
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_popcnt32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 add (0x6A)
; Emit: pop rcx; pop rax; add eax, ecx; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_add
    mov     cl, 1            ; pop rcx
    call    jit_emit_pop_reg
    xor     ecx, ecx         ; pop rax
    call    jit_emit_pop_reg
    call    jit_emit_add32
    xor     ecx, ecx         ; push rax
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 sub (0x6B)
; -----------------------------------------------------------------+
er_fn jit_template_i32_sub
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_sub32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 mul (0x6C)
; -----------------------------------------------------------------+
er_fn jit_template_i32_mul
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_imul32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 div_s (0x6D)
; Emit: pop rcx; pop rax; cdq; idiv ecx; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_div_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     al, 0x99         ; cdq
    call    jit_emit_byte
    call    jit_emit_idiv32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 div_u (0x6E)
; Emit: pop rcx; pop rax; xor edx, edx; div ecx; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_div_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_xor_eax_eax ; zero edx via xor edx, edx
    ; Actually jit_emit_xor_eax_eax does xor eax, eax. We need xor edx, edx.
    ; Emit: xor edx, edx
    mov     al, 0x31
    call    jit_emit_byte
    mov     al, 0xD2         ; xor edx, edx
    call    jit_emit_modrm
    call    jit_emit_div32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 rem_s (0x6F)
; Emit: pop rcx; pop rax; cdq; idiv ecx; mov eax, edx; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_rem_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     al, 0x99         ; cdq
    call    jit_emit_byte
    call    jit_emit_idiv32
    ; mov eax, edx
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0xD0         ; mov eax, edx
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 rem_u (0x70)
; Emit: pop rcx; pop rax; xor edx, edx; div ecx; mov eax, edx; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_rem_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     al, 0x31
    call    jit_emit_byte
    mov     al, 0xD2         ; xor edx, edx
    call    jit_emit_modrm
    call    jit_emit_div32
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0xD0         ; mov eax, edx
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 and (0x71)
; -----------------------------------------------------------------+
er_fn jit_template_i32_and
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_and32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 or (0x72)
; -----------------------------------------------------------------+
er_fn jit_template_i32_or
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_or32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 xor (0x73)
; -----------------------------------------------------------------+
er_fn jit_template_i32_xor
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_xor32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 shl (0x74)
; Emit: pop rcx; pop rax; shl eax, cl; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i32_shl
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_shl32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 shr_s (0x75)
; -----------------------------------------------------------------+
er_fn jit_template_i32_shr_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_sar32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 shr_u (0x76)
; -----------------------------------------------------------------+
er_fn jit_template_i32_shr_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_shr32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 rotl (0x77)
; -----------------------------------------------------------------+
er_fn jit_template_i32_rotl
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rol32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 rotr (0x78)
; -----------------------------------------------------------------+
er_fn jit_template_i32_rotr
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_ror32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32 wrap_i64 (0xA7)
; Emit: pop rax; push rax (64-to-32 is automatic on x86_64)
; Actually need to zero-extend: mov eax, eax does it
; -----------------------------------------------------------------+
er_fn jit_template_i32_wrap_i64
    xor     ecx, ecx
    call    jit_emit_pop_reg
    ; mov eax, eax (zero-extend)
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0xC0
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 extend_i32_s (0xAC)
; Emit: pop rax; movsxd rax, eax; push rax
; -----------------------------------------------------------------+
er_fn jit_template_i64_extend_i32_s
    xor     ecx, ecx
    call    jit_emit_pop_reg
    ; movsxd rax, eax — REX.W + 63 /r
    mov     al, 0x48         ; REX.W
    call    jit_emit_byte
    mov     al, 0x63         ; movsxd
    call    jit_emit_byte
    mov     al, 0xC0         ; ModRM: mod=11, reg=0(rax), rm=0(rax/eax)
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 extend_i32_u (0xAD)
; Emit: pop rax; mov eax, eax (zero-extend); push rax
; -----------------------------------------------------------------+
er_fn jit_template_i64_extend_i32_u
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0xC0         ; mov eax, eax
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ==================================================================
; Memory op templates (i32.load, i64.load, i32.store, i64.store)
; =================================================================+

; ------------------------------------------------------------------
; i32.load (0x28) — pop address, load 4 bytes, push
; -----------------------------------------------------------------+
er_fn jit_template_i32_load
    mov     cl, 1
    call    jit_emit_pop_reg      ; pop rcx (address)
    call    jit_emit_mem_load32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64.load (0x29) — pop address, load 8 bytes, push
; -----------------------------------------------------------------+
er_fn jit_template_i64_load
    mov     cl, 1
    call    jit_emit_pop_reg
    call    jit_emit_mem_load64
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i32.store (0x36) — pop address, pop value, store 4 bytes
; -----------------------------------------------------------------+
er_fn jit_template_i32_store
    mov     cl, 1
    call    jit_emit_pop_reg      ; pop rcx (address)
    xor     ecx, ecx
    call    jit_emit_pop_reg      ; pop rax (value)
    call    jit_emit_mem_store32
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64.store (0x37) — pop address, pop value, store 8 bytes
; -----------------------------------------------------------------+
er_fn jit_template_i64_store
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_mem_store64
    pop     rbp
    ret

; ==================================================================
; i64 comparison templates (REX.W + i32 compare pattern)
; =================================================================+

; ------------------------------------------------------------------
; i64 eqz (0x50)
; -----------------------------------------------------------------+
er_fn jit_template_i64_eqz
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_test64
    mov     cl, 0x94
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 eq (0x51)
; -----------------------------------------------------------------+
er_fn jit_template_i64_eq
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x94
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 ne (0x52)
; -----------------------------------------------------------------+
er_fn jit_template_i64_ne
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x95
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 lt_s (0x53)
; -----------------------------------------------------------------+
er_fn jit_template_i64_lt_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x9C
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 lt_u (0x54)
; -----------------------------------------------------------------+
er_fn jit_template_i64_lt_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x92
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 gt_s (0x55)
; -----------------------------------------------------------------+
er_fn jit_template_i64_gt_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x9F
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 gt_u (0x56)
; -----------------------------------------------------------------+
er_fn jit_template_i64_gt_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x97
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 le_s (0x57)
; -----------------------------------------------------------------+
er_fn jit_template_i64_le_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x9E
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 le_u (0x58)
; -----------------------------------------------------------------+
er_fn jit_template_i64_le_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x96
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 ge_s (0x59)
; -----------------------------------------------------------------+
er_fn jit_template_i64_ge_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x9D
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 ge_u (0x5A)
; -----------------------------------------------------------------+
er_fn jit_template_i64_ge_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cmp64
    mov     cl, 0x93
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ==================================================================
; i64 unary arithmetic (clz, ctz, popcnt)
; =================================================================+

; ------------------------------------------------------------------
; i64 clz (0x79)
; -----------------------------------------------------------------+
er_fn jit_template_i64_clz
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_lzcnt64
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 ctz (0x7A)
; -----------------------------------------------------------------+
er_fn jit_template_i64_ctz
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_tzcnt64
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 popcnt (0x7B)
; -----------------------------------------------------------------+
er_fn jit_template_i64_popcnt
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_popcnt64
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ==================================================================
; i64 binary arithmetic
; =================================================================+

; ------------------------------------------------------------------
; i64 add (0x7C)
; -----------------------------------------------------------------+
er_fn jit_template_i64_add
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_add32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 sub (0x7D)
; -----------------------------------------------------------------+
er_fn jit_template_i64_sub
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_sub32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 mul (0x7E)
; -----------------------------------------------------------------+
er_fn jit_template_i64_mul
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_imul32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 div_s (0x7F)
; -----------------------------------------------------------------+
er_fn jit_template_i64_div_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cqo
    call    jit_emit_rex_nob
    call    jit_emit_idiv32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 div_u (0x80)
; -----------------------------------------------------------------+
er_fn jit_template_i64_div_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_xor_edx_edx
    call    jit_emit_rex_nob
    call    jit_emit_div32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 rem_s (0x81)
; -----------------------------------------------------------------+
er_fn jit_template_i64_rem_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_cqo
    call    jit_emit_rex_nob
    call    jit_emit_idiv32
    mov     al, 0x48         ; REX.W for mov rdx, rax
    call    jit_emit_byte
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0xD0         ; mov rax, rdx
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 rem_u (0x82)
; -----------------------------------------------------------------+
er_fn jit_template_i64_rem_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_xor_edx_edx
    call    jit_emit_rex_nob
    call    jit_emit_div32
    mov     al, 0x48         ; REX.W for mov rax, rdx
    call    jit_emit_byte
    mov     al, 0x89
    call    jit_emit_byte
    mov     al, 0xD0         ; mov rax, rdx
    call    jit_emit_modrm
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 and (0x83)
; -----------------------------------------------------------------+
er_fn jit_template_i64_and
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_and32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 or (0x84)
; -----------------------------------------------------------------+
er_fn jit_template_i64_or
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_or32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 xor (0x85)
; -----------------------------------------------------------------+
er_fn jit_template_i64_xor
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_xor32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 shl (0x86)
; -----------------------------------------------------------------+
er_fn jit_template_i64_shl
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_shl32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 shr_s (0x87) — arithmetic shift right
; -----------------------------------------------------------------+
er_fn jit_template_i64_shr_s
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_sar32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 shr_u (0x88) — logical shift right
; -----------------------------------------------------------------+
er_fn jit_template_i64_shr_u
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_shr32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 rotl (0x89)
; -----------------------------------------------------------------+
er_fn jit_template_i64_rotl
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_rol32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; i64 rotr (0x8A)
; -----------------------------------------------------------------+
er_fn jit_template_i64_rotr
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_rex_nob
    call    jit_emit_ror32
    xor     ecx, ecx
    call    jit_emit_push_reg
    pop     rbp
    ret

; ------------------------------------------------------------------
; Fallback — emit nothing, just return (orchestrator handles fallback)
; -----------------------------------------------------------------+
er_fn jit_template_fallback
    pop     rbp
    ret

; ------------------------------------------------------------------
; Emit: test eax, eax  (for eqz)
; -----------------------------------------------------------------+
er_fn jit_emit_test32
    mov     al, 0x85
    call    jit_emit_byte
    mov     al, 0xC0         ; test eax, eax
    call    jit_emit_modrm
    pop     rbp
    ret

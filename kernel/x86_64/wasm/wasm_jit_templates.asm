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
    ret

; ------------------------------------------------------------------
; Template: nop (0x01)
; -----------------------------------------------------------------+
er_fn jit_template_nop
    ret

; Control flow ops (0x02-0x0D, 0x0F) are handled directly by
; the orchestrator (wasm_jit.asm). call (0x10) and
; call_indirect (0x11) use their own templates below.

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
    ret

; ------------------------------------------------------------------
; Template: i32.const imm (0x41)
; Emit: push imm32
; -----------------------------------------------------------------+
er_fn jit_template_i32_const
    mov     eax, [rdi + 12]  ; imm0
    call    jit_emit_push_imm32
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
    ret

; ------------------------------------------------------------------
; Template: call (0x10) — compile-time trampoline
;
; Emitted runtime code:
;   push r15          ; save JitGlobals
;   sub  rsp, n*8     ; allocate temp buffer
;   ; copy params from WASM stack to buffer (WASM order)
;   mov  rdi, func_idx
;   mov  rsi, rsp     ; buffer
;   mov  edx, n       ; param_count
;   mov  rax, er_fn_exec
;   call rax
;   add  rsp, n*8     ; free buffer
;   ; if result_count > 0: push rax
;   pop  r15          ; restore JitGlobals
; -----------------------------------------------------------------+
er_fn jit_template_call
    push    r12

    mov     r8d, [rdi + 12]         ; r8 = func_idx (imm0)
    mov     edi, r8d
    call    er_wasm_type_index_for_function
    test    rdx, rdx
    jnz     .call_type_error
    mov     r10, rax
    imul    r10, FUNC_TYPE_SIZE
    mov     r11, [rel types_buf + r10 + FUNC_TYPE_PARAM_COUNT_OFF]
    mov     r12, [rel types_buf + r10 + FUNC_TYPE_RESULT_COUNT_OFF]

    cmp     r11, 8
    ja      .call_too_many_params

    mov     cl, 15
    call    jit_emit_push_reg

    mov     eax, r11d
    shl     eax, 3
    call    jit_emit_sub_rsp_imm

    mov     r9d, r11d
    dec     r9d
.call_copy_loop:
    cmp     r9d, 0
    jl      .call_copy_done

    mov     eax, r11d
    shl     eax, 1
    dec     eax
    sub     eax, r9d
    shl     eax, 3
    call    jit_emit_load_rax_rsp_disp

    mov     eax, r9d
    shl     eax, 3
    call    jit_emit_store_rax_rsp_disp

    dec     r9d
    jmp     .call_copy_loop
.call_copy_done:

    mov     rax, r8
    call    jit_emit_mov_rdi_imm64
    call    jit_emit_mov_rsi_rsp
    mov     eax, r11d
    call    jit_emit_mov_edx_imm32
    mov     rax, er_fn_exec
    call    jit_emit_mov_rax_imm64
    call    jit_emit_call_rax

    mov     eax, r11d
    shl     eax, 3
    call    jit_emit_add_rsp_imm

    mov     cl, 15
    call    jit_emit_pop_reg        ; restore r15 BEFORE result push

    cmp     r12, 1
    jl      .call_no_result
    xor     ecx, ecx
    call    jit_emit_push_reg
.call_no_result:

    pop     r12
    er_ok
    ret

.call_type_error:
    pop     r12
    ; rdx already has error from er_wasm_type_index_for_function
    ret

.call_too_many_params:
    pop     r12
    er_err  ERROR_NOT_IMPLEMENTED
    ret

; ------------------------------------------------------------------
; Template: call_indirect (0x11) — runtime function index
;
; Emitted runtime code:
;   push r15          ; save JitGlobals
;   pop  rdi          ; func_idx from WASM stack
;   sub  rsp, n*8     ; allocate temp buffer
;   ; copy params from WASM stack to buffer (WASM order)
;   mov  rsi, rsp     ; buffer
;   mov  edx, n       ; param_count
;   mov  rax, er_fn_exec
;   call rax
;   add  rsp, n*8     ; free buffer
;   ; if result_count > 0: push rax
;   pop  r15          ; restore JitGlobals
; -----------------------------------------------------------------+
er_fn jit_template_call_indirect
    push    r12

    mov     r10d, [rdi + 12]        ; r10 = type_index (imm0)
    imul    r10d, FUNC_TYPE_SIZE
    mov     r11, [rel types_buf + r10 + FUNC_TYPE_PARAM_COUNT_OFF]
    mov     r12, [rel types_buf + r10 + FUNC_TYPE_RESULT_COUNT_OFF]

    cmp     r11, 8
    ja      .ci_too_many_params

    mov     cl, 15
    call    jit_emit_push_reg

    mov     cl, 7
    call    jit_emit_pop_reg

    mov     eax, r11d
    shl     eax, 3
    call    jit_emit_sub_rsp_imm

    mov     r8d, r11d
    dec     r8d
.ci_copy_loop:
    cmp     r8d, 0
    jl      .ci_copy_done

    mov     eax, r11d
    shl     eax, 1
    dec     eax
    sub     eax, r8d
    shl     eax, 3
    call    jit_emit_load_rax_rsp_disp

    mov     eax, r8d
    shl     eax, 3
    call    jit_emit_store_rax_rsp_disp

    dec     r8d
    jmp     .ci_copy_loop
.ci_copy_done:

    call    jit_emit_mov_rsi_rsp
    mov     eax, r11d
    call    jit_emit_mov_edx_imm32
    mov     rax, er_fn_exec
    call    jit_emit_mov_rax_imm64
    call    jit_emit_call_rax

    mov     eax, r11d
    shl     eax, 3
    call    jit_emit_add_rsp_imm

    mov     cl, 15
    call    jit_emit_pop_reg

    cmp     r12, 1
    jl      .ci_no_result
    xor     ecx, ecx
    call    jit_emit_push_reg
.ci_no_result:

    pop     r12
    er_ok
    ret

.ci_too_many_params:
    pop     r12
    er_err  ERROR_NOT_IMPLEMENTED
    ret

; ==================================================================
; Float comparison helpers — shared by f32 and f64 comparison templates
; =================================================================+
; After ucomiss/ucomisd:
;   ZF=1,PF=0,CF=0 → equal
;   ZF=0,PF=0,CF=0 → greater than
;   ZF=0,PF=0,CF=1 → less than
;   ZF=1,PF=1,CF=1 → unordered (NaN)
;
; NaN fixup:
;   eq: setnp al; mov ah, al; sete al; and al, ah  (false on NaN)
;   ne: setne al; setnp ah; ... wait, need OR with PF
;   ne: setp al; ... no
;
;   Actually:
;   eq: sete & ~PF   → setnp; save; sete; and
;   ne: setne | PF   → sete? no
;   ne: the opposite of eq: setne al (1 if !equal); but NaN → ZF=1 → setne=0, we want 1
;   Better: setp al (1 if NaN); setne ah (1 if not equal); or al, ah
;   Or simplest: sete al; setnp ah; xor al, 1; and al, ah; xor al, 1
;     (flip eq result for NaN-safe eq → ne)
;   lt: setb & ~PF   → setnp; save; setb; and
;   gt: seta alone (NaN: CF=1 → seta=0 ✓)
;   le: setbe & ~PF  → setnp; save; setbe; and
;   ge: setae alone (NaN: CF=1 → setae=0 ✓)
;
; For ne: use setp al; mov ah, al; sete al; xor al, 1; and al, ah; xor al, 1
;   NaN: setp al=1 → ah=1; sete al=1; xor 1=0; and 0,1=0; xor 1=1 ✓
;   equal: setp al=0 → ah=0; sete al=1; xor 1=0; and 0,0=0; xor 1=1 ... WRONG!
;   Not equal: setp al=0 → ah=0; sete al=0; xor 1=1; and 1,0=0; xor 1=1 ✓
;
; Hmm, equal case is wrong. Let me try:
; ne = (a != b) || isNaN(a,b) = NOT(eq & ordered)
;   = NOT(sete & ~PF) = (NOT sete) | PF
;   = setne | PF
; So: setp al (PF→al); setne ah; or al, ah

; -----------------------------------------------------------------+
; Emit f32 comparison prologue: pop xmm1(right), pop xmm0(left), ucomiss
; -----------------------------------------------------------------+
er_fn jit_emit_f32_cmp_prologue
    mov     cl, 1
    call    jit_emit_pop_reg          ; pop rcx
    xor     ecx, ecx
    call    jit_emit_pop_reg          ; pop rax
    call    jit_emit_movd_xmm1_ecx
    call    jit_emit_movd_xmm0_eax
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x2E
    call    jit_emit_byte
    mov     al, 0xC1
    jmp     jit_emit_modrm

; -----------------------------------------------------------------+
; Emit f64 comparison prologue: pop xmm1(right), pop xmm0(left), ucomisd
; -----------------------------------------------------------------+
er_fn jit_emit_f64_cmp_prologue
    mov     cl, 1
    call    jit_emit_pop_reg          ; pop rcx
    xor     ecx, ecx
    call    jit_emit_pop_reg          ; pop rax
    call    jit_emit_movq_xmm1_rcx
    call    jit_emit_movq_xmm0_rax
    mov     al, 0x66
    call    jit_emit_byte
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x2E
    call    jit_emit_byte
    mov     al, 0xC1
    jmp     jit_emit_modrm

; ==================================================================
; F32 comparison templates (0x5B-0x60)
; Each: cmp_prologue → setcc → NaN fixup → movzx → push
; =================================================================+

; f32.eq (0x5B)
er_fn jit_template_f32_eq
    call    jit_emit_f32_cmp_prologue
    call    jit_emit_setnp_save_ah
    mov     cl, 0x94
    call    jit_emit_setcc         ; sete al
    call    jit_emit_and_al_ah     ; and al, ah → al = eq && ordered
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.ne (0x5C)
er_fn jit_template_f32_ne
    call    jit_emit_f32_cmp_prologue
    call    jit_emit_setp_save_ah
    mov     cl, 0x95
    call    jit_emit_setcc         ; setne al
    call    jit_emit_or_al_ah      ; or al, ah → al = setne | PF
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg
; ACTUALLY: setp al; mov ah, al; setne al; or al, ah

; f32.lt (0x5D)
er_fn jit_template_f32_lt
    call    jit_emit_f32_cmp_prologue
    call    jit_emit_setnp_save_ah
    mov     cl, 0x92               ; setb (CF=1, below)
    call    jit_emit_setcc
    call    jit_emit_and_al_ah
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.gt (0x5E)
er_fn jit_template_f32_gt
    call    jit_emit_f32_cmp_prologue
    mov     cl, 0x97               ; seta (CF=0,ZF=0)
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.le (0x5F)
er_fn jit_template_f32_le
    call    jit_emit_f32_cmp_prologue
    call    jit_emit_setnp_save_ah
    mov     cl, 0x96               ; setbe (CF=1 or ZF=1)
    call    jit_emit_setcc
    call    jit_emit_and_al_ah
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.ge (0x60)
er_fn jit_template_f32_ge
    call    jit_emit_f32_cmp_prologue
    mov     cl, 0x93               ; setae (CF=0)
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; ==================================================================
; F64 comparison templates (0x61-0x66)
; =================================================================+

; f64.eq (0x61)
er_fn jit_template_f64_eq
    call    jit_emit_f64_cmp_prologue
    call    jit_emit_setnp_save_ah
    mov     cl, 0x94
    call    jit_emit_setcc
    call    jit_emit_and_al_ah
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.ne (0x62)
er_fn jit_template_f64_ne
    call    jit_emit_f64_cmp_prologue
    call    jit_emit_setp_save_ah
    mov     cl, 0x95
    call    jit_emit_setcc
    call    jit_emit_or_al_ah
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.lt (0x63)
er_fn jit_template_f64_lt
    call    jit_emit_f64_cmp_prologue
    call    jit_emit_setnp_save_ah
    mov     cl, 0x92
    call    jit_emit_setcc
    call    jit_emit_and_al_ah
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.gt (0x64)
er_fn jit_template_f64_gt
    call    jit_emit_f64_cmp_prologue
    mov     cl, 0x97
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.le (0x65)
er_fn jit_template_f64_le
    call    jit_emit_f64_cmp_prologue
    call    jit_emit_setnp_save_ah
    mov     cl, 0x96
    call    jit_emit_setcc
    call    jit_emit_and_al_ah
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.ge (0x66)
er_fn jit_template_f64_ge
    call    jit_emit_f64_cmp_prologue
    mov     cl, 0x93
    call    jit_emit_setcc
    call    jit_emit_movzx_al_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; ==================================================================
; F32 constant and unary templates
; =================================================================+

; -----------------------------------------------------------------+
; f32.const (0x43) — push imm32 float bits
; -----------------------------------------------------------------+
er_fn jit_template_f32_const
    mov     eax, [rdi + 12]
    call    jit_emit_push_imm32
    ret

; -----------------------------------------------------------------+
; f64.const (0x44) — push imm64 float bits
; -----------------------------------------------------------------+
er_fn jit_template_f64_const
    mov     eax, [rdi + 12]
    mov     edx, [rdi + 16]
    shl     rdx, 32
    or      rax, rdx
    mov     cl, 1
    mov     ch, 0
    xor     r8b, r8b
    xor     r9b, r9b
    call    jit_emit_rex
    mov     al, 0xB8
    call    jit_emit_byte
    mov     eax, [rdi + 12]
    mov     edx, [rdi + 16]
    shl     rdx, 32
    or      rax, rdx
    call    jit_emit_qword
    xor     ecx, ecx
    call    jit_emit_push_reg
    ret

; -----------------------------------------------------------------+
; f32.abs (0x8B) — pop; clear sign bit 31; push
; -----------------------------------------------------------------+
er_fn jit_template_f32_abs
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     cl, 31
    call    jit_emit_btr_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; -----------------------------------------------------------------+
; f32.neg (0x8C) — pop; toggle sign bit 31; push
; -----------------------------------------------------------------+
er_fn jit_template_f32_neg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     cl, 31
    call    jit_emit_btc_eax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; -----------------------------------------------------------------+
; f64.abs (0x99) — pop; clear sign bit 63; push
; -----------------------------------------------------------------+
er_fn jit_template_f64_abs
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     cl, 63
    call    jit_emit_btr_rax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; -----------------------------------------------------------------+
; f64.neg (0x9A) — pop; toggle sign bit 63; push
; -----------------------------------------------------------------+
er_fn jit_template_f64_neg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    mov     cl, 63
    call    jit_emit_btc_rax
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; -----------------------------------------------------------------+
; f32.sqrt (0x91) — pop, sqrtss, push
; -----------------------------------------------------------------+
er_fn jit_template_f32_sqrt
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm0_eax
    mov     al, 0xF3
    mov     ch, 0x51
    mov     cl, 0xC0
    call    jit_emit_sse_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; -----------------------------------------------------------------+
; f64.sqrt (0x9F) — pop, sqrtsd, push
; -----------------------------------------------------------------+
er_fn jit_template_f64_sqrt
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm0_rax
    mov     al, 0xF2
    mov     ch, 0x51
    mov     cl, 0xC0
    call    jit_emit_sse_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; ==================================================================
; F32 SSE binary arithmetic templates (0x92-0x95)
; Each: pop rcx, pop rax, movd xmm1, movd xmm0, opss, movd, push
; =================================================================+

; f32.add (0x92)
er_fn jit_template_f32_add
    mov     cl, 1
    call    jit_emit_pop_reg           ; pop rcx
    xor     ecx, ecx
    call    jit_emit_pop_reg           ; pop rax
    call    jit_emit_movd_xmm1_ecx
    call    jit_emit_movd_xmm0_eax
    mov     al, 0xF3
    mov     ch, 0x58                   ; addss opcode
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.sub (0x93)
er_fn jit_template_f32_sub
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm1_ecx
    call    jit_emit_movd_xmm0_eax
    mov     al, 0xF3
    mov     ch, 0x5C                   ; subss
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.mul (0x94)
er_fn jit_template_f32_mul
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm1_ecx
    call    jit_emit_movd_xmm0_eax
    mov     al, 0xF3
    mov     ch, 0x59                   ; mulss
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.div (0x95)
er_fn jit_template_f32_div
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm1_ecx
    call    jit_emit_movd_xmm0_eax
    mov     al, 0xF3
    mov     ch, 0x5E                   ; divss
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; ==================================================================
; F64 SSE binary arithmetic templates (0xA0-0xA3)
; Each: pop rcx, pop rax, movq xmm1, movq xmm0, opsd, movq, push
; =================================================================+

; f64.add (0xA0)
er_fn jit_template_f64_add
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm1_rcx
    call    jit_emit_movq_xmm0_rax
    mov     al, 0xF2
    mov     ch, 0x58                   ; addsd
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.sub (0xA1)
er_fn jit_template_f64_sub
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm1_rcx
    call    jit_emit_movq_xmm0_rax
    mov     al, 0xF2
    mov     ch, 0x5C                   ; subsd
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.mul (0xA2)
er_fn jit_template_f64_mul
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm1_rcx
    call    jit_emit_movq_xmm0_rax
    mov     al, 0xF2
    mov     ch, 0x59                   ; mulsd
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.div (0xA3)
er_fn jit_template_f64_div
    mov     cl, 1
    call    jit_emit_pop_reg
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm1_rcx
    call    jit_emit_movq_xmm0_rax
    mov     al, 0xF2
    mov     ch, 0x5E                   ; divsd
    mov     cl, 0xC1
    call    jit_emit_sse_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; ==================================================================
; SSE4.1 rounding templates
; roundss/roundsd: 66 0F 3A 0A/0B <modrm> <imm8>
; imm8 = 0x08 | mode where mode: 0=nearest,1=floor,2=ceil,3=trunc
; Imm[3]=1 suppresses precision exception
; =================================================================+

; f32.ceil (0x8D)
er_fn jit_template_f32_ceil
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm0_eax
    mov     al, 0x0A
    mov     cl, 0xC0
    mov     ch, 0x0A                   ; ceil (2) | 0x08 = 0x0A
    call    jit_emit_sse3a_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.floor (0x8E)
er_fn jit_template_f32_floor
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm0_eax
    mov     al, 0x0A
    mov     cl, 0xC0
    mov     ch, 0x09                   ; floor (1) | 0x08 = 0x09
    call    jit_emit_sse3a_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.trunc (0x8F)
er_fn jit_template_f32_trunc
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm0_eax
    mov     al, 0x0A
    mov     cl, 0xC0
    mov     ch, 0x0B                   ; trunc (3) | 0x08 = 0x0B
    call    jit_emit_sse3a_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f32.nearest (0x90)
er_fn jit_template_f32_nearest
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movd_xmm0_eax
    mov     al, 0x0A
    mov     cl, 0xC0
    mov     ch, 0x08                   ; nearest (0) | 0x08 = 0x08
    call    jit_emit_sse3a_op
    call    jit_emit_movd_eax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.ceil (0x9B)
er_fn jit_template_f64_ceil
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm0_rax
    mov     al, 0x0B
    mov     cl, 0xC0
    mov     ch, 0x0A
    call    jit_emit_sse3a_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.floor (0x9C)
er_fn jit_template_f64_floor
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm0_rax
    mov     al, 0x0B
    mov     cl, 0xC0
    mov     ch, 0x09
    call    jit_emit_sse3a_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.trunc (0x9D)
er_fn jit_template_f64_trunc
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm0_rax
    mov     al, 0x0B
    mov     cl, 0xC0
    mov     ch, 0x0B
    call    jit_emit_sse3a_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; f64.nearest (0x9E)
er_fn jit_template_f64_nearest
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_movq_xmm0_rax
    mov     al, 0x0B
    mov     cl, 0xC0
    mov     ch, 0x08
    call    jit_emit_sse3a_op
    call    jit_emit_movq_rax_xmm0
    xor     ecx, ecx
    jmp     jit_emit_push_reg

; ==================================================================
; Reinterpret ops — no-op on x86_64 (WASM stack holds raw bits)
; =================================================================+

; i32.reinterpret_f32 (0xBC)
er_fn jit_template_i32_reinterpret_f32
    ret

; i64.reinterpret_f64 (0xBD)
er_fn jit_template_i64_reinterpret_f64
    ret

; f32.reinterpret_i32 (0xBE)
er_fn jit_template_f32_reinterpret_i32
    ret

; f64.reinterpret_i64 (0xBF)
er_fn jit_template_f64_reinterpret_i64
    ret

; ==================================================================
; Float load/store — reuse integer load/store templates
; (f32.load = i32.load, f64.load = i64.load, etc.)
; =================================================================+
; These are registered by alias in the init table.

; -----------------------------------------------------------------+
; Fallback — emit nothing, just return (orchestrator handles fallback)
; -----------------------------------------------------------------+
er_fn jit_template_fallback
    ret

; ------------------------------------------------------------------
; Emit: test eax, eax  (for eqz)
; -----------------------------------------------------------------+
er_fn jit_emit_test32
    mov     al, 0x85
    call    jit_emit_byte
    mov     al, 0xC0         ; test eax, eax
    call    jit_emit_modrm
    ret

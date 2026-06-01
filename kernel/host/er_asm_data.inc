SECTION .data
arg_parse_only: db "--parse-only", 0
arg_o: db "-o", 0
arg_f: db "-f", 0
arg_i: db "-I", 0
msg_usage: db "usage: er_asm --parse-only <source.asm> | -f <fmt> [-I path] [-d name] [-D name] -o <out> <source.asm>", 10, 0
msg_fail: db "er_asm: assembly failed", 10, 0
msg_unsupported: db "er_asm: unsupported source shape", 10, 0
key_magic: db "er_asm_parse", 9, "1", 10, 0
key_lines: db "lines", 0
key_preproc: db "preproc", 0
key_directives: db "directives", 0
key_labels: db "labels", 0
key_instructions: db "instructions", 0
key_text_len: db "text_len", 0
key_exit_step: db "exit_step", 0
key_exit_bad: db "exit_bad", 0
key_generic_mode: db "generic_mode", 0
key_generic_bad: db "generic_bad", 0
key_globals: db "globals", 0
key_pending_globals: db "pending_globals", 0
key_pending_branches: db "pending_branches", 0
key_pending_calls: db "pending_calls", 0
key_equ_seen: db "equ_seen", 0
tab_str: db 9, 0
nl_str: db 10, 0

tok_section: db "section"
tok_section_len equ $ - tok_section
tok_global: db "global"
tok_global_len equ $ - tok_global
tok_extern: db "extern"
tok_extern_len equ $ - tok_extern
tok_default: db "default"
tok_default_len equ $ - tok_default
tok_bits: db "[bits"
tok_bits_len equ $ - tok_bits
tok_db: db "db"
tok_db_len equ $ - tok_db
tok_dw: db "dw"
tok_dw_len equ $ - tok_dw
tok_dd: db "dd"
tok_dd_len equ $ - tok_dd
tok_dq: db "dq"
tok_dq_len equ $ - tok_dq
tok_resb: db "resb"
tok_resb_len equ $ - tok_resb
tok_resw: db "resw"
tok_resw_len equ $ - tok_resw
tok_resd: db "resd"
tok_resd_len equ $ - tok_resd
tok_resq: db "resq"
tok_resq_len equ $ - tok_resq
tok_times: db "times"
tok_times_len equ $ - tok_times
tok_align: db "align"
tok_align_len equ $ - tok_align
tok_incbin: db "incbin"
tok_incbin_len equ $ - tok_incbin
tok_equ: db "equ"
tok_equ_len equ $ - tok_equ
tok_percent_define: db "%define"
tok_percent_define_len equ $ - tok_percent_define
tok_percent_include: db "%include"
tok_percent_include_len equ $ - tok_percent_include
tok_percent_macro: db "%macro"
tok_percent_macro_len equ $ - tok_percent_macro
tok_percent_endmacro: db "%endmacro"
tok_percent_endmacro_len equ $ - tok_percent_endmacro
tok_percent_ifdef: db "%ifdef"
tok_percent_ifdef_len equ $ - tok_percent_ifdef
tok_percent_ifndef: db "%ifndef"
tok_percent_ifndef_len equ $ - tok_percent_ifndef
tok_percent_else: db "%else"
tok_percent_else_len equ $ - tok_percent_else
tok_percent_endif: db "%endif"
tok_percent_endif_len equ $ - tok_percent_endif
tok_x86_macros_inc: db "x86_64/macros.inc"
tok_x86_macros_inc_len equ $ - tok_x86_macros_inc
tok_test_macros_inc: db "test/test_macros.inc"
tok_test_macros_inc_len equ $ - tok_test_macros_inc
tok_er_fn: db "er_fn"
tok_er_fn_len equ $ - tok_er_fn
tok_er_ret: db "er_ret"
tok_er_ret_len equ $ - tok_er_ret
tok_er_ok: db "er_ok"
tok_er_ok_len equ $ - tok_er_ok
tok_er_err: db "er_err"
tok_er_err_len equ $ - tok_er_err
tok_er_call: db "er_call"
tok_er_call_len equ $ - tok_er_call
tok_er_check_zero: db "er_check_zero"
tok_er_check_zero_len equ $ - tok_er_check_zero
tok_er_check_nonzero: db "er_check_nonzero"
tok_er_check_nonzero_len equ $ - tok_er_check_nonzero
tok_er_cmp_below: db "er_cmp_below"
tok_er_cmp_below_len equ $ - tok_er_cmp_below
tok_cmos_out_index: db "_cmos_out_index"
tok_cmos_out_index_len equ $ - tok_cmos_out_index
tok_cmos_in_data: db "_cmos_in_data"
tok_cmos_in_data_len equ $ - tok_cmos_in_data
tok_cmos_out_data: db "_cmos_out_data"
tok_cmos_out_data_len equ $ - tok_cmos_out_data
tok_er_frame_push: db "er_frame_push"
tok_er_frame_push_len equ $ - tok_er_frame_push
tok_er_frame_pop: db "er_frame_pop"
tok_er_frame_pop_len equ $ - tok_er_frame_pop
tok_er_push: db "er_push"
tok_er_push_len equ $ - tok_er_push
tok_er_pop: db "er_pop"
tok_er_pop_len equ $ - tok_er_pop
tok_test_bss_passed_failed: db "TEST_BSS_PASSED_FAILED"
tok_test_bss_passed_failed_len equ $ - tok_test_bss_passed_failed
tok_test_data_passed_failed: db "TEST_DATA_PASSED_FAILED"
tok_test_data_passed_failed_len equ $ - tok_test_data_passed_failed
tok_test_bss_total_passed: db "TEST_BSS_TOTAL_PASSED"
tok_test_bss_total_passed_len equ $ - tok_test_bss_total_passed
tok_test_bss_total_passed_failed: db "TEST_BSS_TOTAL_PASSED_FAILED"
tok_test_bss_total_passed_failed_len equ $ - tok_test_bss_total_passed_failed
tok_test_data_total_passed_failed: db "TEST_DATA_TOTAL_PASSED_FAILED"
tok_test_data_total_passed_failed_len equ $ - tok_test_data_total_passed_failed
tok_test_exit: db "TEST_EXIT"
tok_test_exit_len equ $ - tok_test_exit
tok_test_call_eax: db "TEST_CALL_EAX"
tok_test_call_eax_len equ $ - tok_test_call_eax
tok_test_exit_passed_total: db "TEST_EXIT_PASSED_TOTAL"
tok_test_exit_passed_total_len equ $ - tok_test_exit_passed_total
tok_total_sym: db "total"
tok_total_sym_len equ $ - tok_total_sym
tok_passed_sym: db "passed"
tok_passed_sym_len equ $ - tok_passed_sym
tok_failed_sym: db "failed"
tok_failed_sym_len equ $ - tok_failed_sym
tok_mov: db "mov"
tok_mov_len equ $ - tok_mov
tok_lea: db "lea"
tok_lea_len equ $ - tok_lea
tok_xor: db "xor"
tok_xor_len equ $ - tok_xor
tok_and: db "and"
tok_and_len equ $ - tok_and
tok_or: db "or"
tok_or_len equ $ - tok_or
tok_not: db "not"
tok_not_len equ $ - tok_not
tok_neg: db "neg"
tok_neg_len equ $ - tok_neg
tok_cmp: db "cmp"
tok_cmp_len equ $ - tok_cmp
tok_add: db "add"
tok_add_len equ $ - tok_add
tok_sub: db "sub"
tok_sub_len equ $ - tok_sub
tok_shl: db "shl"
tok_shl_len equ $ - tok_shl
tok_shr: db "shr"
tok_shr_len equ $ - tok_shr
tok_test: db "test"
tok_test_len equ $ - tok_test
tok_inc: db "inc"
tok_inc_len equ $ - tok_inc
tok_dec: db "dec"
tok_dec_len equ $ - tok_dec
tok_lodsb: db "lodsb"
tok_lodsb_len equ $ - tok_lodsb
tok_cld: db "cld"
tok_cld_len equ $ - tok_cld
tok_std: db "std"
tok_std_len equ $ - tok_std
tok_clc: db "clc"
tok_clc_len equ $ - tok_clc
tok_stc: db "stc"
tok_stc_len equ $ - tok_stc
tok_rep: db "rep"
tok_rep_len equ $ - tok_rep
tok_repne: db "repne"
tok_repne_len equ $ - tok_repne
tok_stosq: db "stosq"
tok_stosq_len equ $ - tok_stosq
tok_stosb: db "stosb"
tok_stosb_len equ $ - tok_stosb
tok_stosd: db "stosd"
tok_stosd_len equ $ - tok_stosd
tok_movsq: db "movsq"
tok_movsq_len equ $ - tok_movsq
tok_movsb: db "movsb"
tok_movsb_len equ $ - tok_movsb
tok_scasb: db "scasb"
tok_scasb_len equ $ - tok_scasb
tok_in: db "in"
tok_in_len equ $ - tok_in
tok_out: db "out"
tok_out_len equ $ - tok_out
tok_crc32: db "crc32"
tok_crc32_len equ $ - tok_crc32
tok_cdq: db "cdq"
tok_cdq_len equ $ - tok_cdq
tok_cqo: db "cqo"
tok_cqo_len equ $ - tok_cqo
tok_bsr: db "bsr"
tok_bsr_len equ $ - tok_bsr
tok_bsf: db "bsf"
tok_bsf_len equ $ - tok_bsf
tok_idiv: db "idiv"
tok_idiv_len equ $ - tok_idiv
tok_movzx: db "movzx"
tok_movzx_len equ $ - tok_movzx
tok_mul: db "mul"
tok_mul_len equ $ - tok_mul
tok_div: db "div"
tok_div_len equ $ - tok_div
tok_imul: db "imul"
tok_imul_len equ $ - tok_imul
tok_setz: db "setz"
tok_setz_len equ $ - tok_setz
tok_call: db "call"
tok_call_len equ $ - tok_call
tok_push: db "push"
tok_push_len equ $ - tok_push
tok_pop: db "pop"
tok_pop_len equ $ - tok_pop
tok_jb: db "jb"
tok_jb_len equ $ - tok_jb
tok_jc: db "jc"
tok_jc_len equ $ - tok_jc
tok_ja: db "ja"
tok_ja_len equ $ - tok_ja
tok_jz: db "jz"
tok_jz_len equ $ - tok_jz
tok_je: db "je"
tok_je_len equ $ - tok_je
tok_jne: db "jne"
tok_jne_len equ $ - tok_jne
tok_jnz: db "jnz"
tok_jnz_len equ $ - tok_jnz
tok_jae: db "jae"
tok_jae_len equ $ - tok_jae
tok_jbe: db "jbe"
tok_jbe_len equ $ - tok_jbe
tok_jle: db "jle"
tok_jle_len equ $ - tok_jle
tok_jl: db "jl"
tok_jl_len equ $ - tok_jl
tok_jg: db "jg"
tok_jg_len equ $ - tok_jg
tok_jmp: db "jmp"
tok_jmp_len equ $ - tok_jmp
tok_syscall: db "syscall"
tok_syscall_len equ $ - tok_syscall
tok_pause: db "pause"
tok_pause_len equ $ - tok_pause
tok_ret: db "ret"
tok_ret_len equ $ - tok_ret
tok_eax: db "eax"
tok_eax_len equ $ - tok_eax
tok_ebx: db "ebx"
tok_ebx_len equ $ - tok_ebx
tok_bl: db "bl"
tok_bl_len equ $ - tok_bl
tok_ecx: db "ecx"
tok_ecx_len equ $ - tok_ecx
tok_edx: db "edx"
tok_edx_len equ $ - tok_edx
tok_esi: db "esi"
tok_esi_len equ $ - tok_esi
tok_edi: db "edi"
tok_edi_len equ $ - tok_edi
tok_rax: db "rax"
tok_rax_len equ $ - tok_rax
tok_rdi: db "rdi"
tok_rdi_len equ $ - tok_rdi
tok_rsi: db "rsi"
tok_rsi_len equ $ - tok_rsi
tok_rcx: db "rcx"
tok_rcx_len equ $ - tok_rcx
tok_rdx: db "rdx"
tok_rdx_len equ $ - tok_rdx
tok_rbx: db "rbx"
tok_rbx_len equ $ - tok_rbx
tok_rbp: db "rbp"
tok_rbp_len equ $ - tok_rbp
tok_rsp: db "rsp"
tok_rsp_len equ $ - tok_rsp
tok_r8: db "r8"
tok_r8_len equ $ - tok_r8
tok_r8w: db "r8w"
tok_r8w_len equ $ - tok_r8w
tok_r8d: db "r8d"
tok_r8d_len equ $ - tok_r8d
tok_r8b: db "r8b"
tok_r8b_len equ $ - tok_r8b
tok_r9: db "r9"
tok_r9_len equ $ - tok_r9
tok_r9d: db "r9d"
tok_r9d_len equ $ - tok_r9d
tok_r9b: db "r9b"
tok_r9b_len equ $ - tok_r9b
tok_r10: db "r10"
tok_r10_len equ $ - tok_r10
tok_r10d: db "r10d"
tok_r10d_len equ $ - tok_r10d
tok_r10b: db "r10b"
tok_r10b_len equ $ - tok_r10b
tok_r11: db "r11"
tok_r11_len equ $ - tok_r11
tok_r11d: db "r11d"
tok_r11d_len equ $ - tok_r11d
tok_r12: db "r12"
tok_r12_len equ $ - tok_r12
tok_r12d: db "r12d"
tok_r12d_len equ $ - tok_r12d
tok_r13: db "r13"
tok_r13_len equ $ - tok_r13
tok_r13d: db "r13d"
tok_r13d_len equ $ - tok_r13d
tok_r14: db "r14"
tok_r14_len equ $ - tok_r14
tok_r14d: db "r14d"
tok_r14d_len equ $ - tok_r14d
tok_r15: db "r15"
tok_r15_len equ $ - tok_r15
tok_ax: db "ax"
tok_ax_len equ $ - tok_ax
tok_bx: db "bx"
tok_bx_len equ $ - tok_bx
tok_dil: db "dil"
tok_dil_len equ $ - tok_dil
tok_al: db "al"
tok_al_len equ $ - tok_al
tok_ah: db "ah"
tok_ah_len equ $ - tok_ah
tok_cl: db "cl"
tok_cl_len equ $ - tok_cl
tok_dl: db "dl"
tok_dl_len equ $ - tok_dl
tok_sil: db "sil"
tok_sil_len equ $ - tok_sil
tok_dx: db "dx"
tok_dx_len equ $ - tok_dx
tok_di: db "di"
tok_di_len equ $ - tok_di
tok_qword: db "qword"
tok_qword_len equ $ - tok_qword
tok_dword: db "dword"
tok_dword_len equ $ - tok_dword
tok_byte: db "byte"
tok_byte_len equ $ - tok_byte
tok_word: db "word"
tok_word_len equ $ - tok_word
tok_mem_rdi: db "[rdi]"
tok_mem_rdi_len equ $ - tok_mem_rdi
tok_mem_edi: db "[edi]"
tok_mem_edi_len equ $ - tok_mem_edi
tok_mem_edi_open: db "[edi"
tok_mem_edi_open_len equ $ - tok_mem_edi_open
tok_mem_rsi: db "[rsi]"
tok_mem_rsi_len equ $ - tok_mem_rsi
tok_mem_rcx: db "[rcx]"
tok_mem_rcx_len equ $ - tok_mem_rcx
tok_mem_rdx: db "[rdx]"
tok_mem_rdx_len equ $ - tok_mem_rdx
tok_mem_r8: db "[r8]"
tok_mem_r8_len equ $ - tok_mem_r8
tok_mem_r9: db "[r9]"
tok_mem_r9_len equ $ - tok_mem_r9
tok_mem_r12: db "[r12]"
tok_mem_r12_len equ $ - tok_mem_r12
tok_mem_r13: db "[r13]"
tok_mem_r13_len equ $ - tok_mem_r13
tok_mem_r14: db "[r14]"
tok_mem_r14_len equ $ - tok_mem_r14
tok_mem_r15: db "[r15]"
tok_mem_r15_len equ $ - tok_mem_r15
tok_mem_rbx: db "[rbx]"
tok_mem_rbx_len equ $ - tok_mem_rbx
tok_mem_ebda_seg_ptr: db "[EBDA_SEG_PTR]"
tok_mem_ebda_seg_ptr_len equ $ - tok_mem_ebda_seg_ptr
tok_mem_r12_open: db "[r12"
tok_mem_r12_open_len equ $ - tok_mem_r12_open
tok_mem_rdi_rcx: db "[rdi"
tok_mem_rdi_rcx_len equ $ - tok_mem_rdi_rcx
tok_mem_rsi_open: db "[rsi"
tok_mem_rsi_open_len equ $ - tok_mem_rsi_open
tok_mem_rsp_open: db "[rsp"
tok_mem_rsp_open_len equ $ - tok_mem_rsp_open
tok_mem_rdi_open: db "[rdi"
tok_mem_rdi_open_len equ $ - tok_mem_rdi_open
tok_mem_rdx_open: db "[rdx"
tok_mem_rdx_open_len equ $ - tok_mem_rdx_open
tok_plus: db "+"
tok_plus_len equ $ - tok_plus
tok_minus: db "-"
tok_minus_len equ $ - tok_minus
tok_rcx_close: db "rcx]"
tok_rcx_close_len equ $ - tok_rcx_close
tok_rdx_close: db "rdx]"
tok_rdx_close_len equ $ - tok_rdx_close
tok_r8_close: db "r8]"
tok_r8_close_len equ $ - tok_r8_close
tok_r8_times_2: db "r8*2"
tok_r8_times_2_len equ $ - tok_r8_times_2
tok_r8_times_2_close: db "r8*2]"
tok_r8_times_2_close_len equ $ - tok_r8_times_2_close
tok_r9_close: db "r9]"
tok_r9_close_len equ $ - tok_r9_close
tok_r10_close: db "r10]"
tok_r10_close_len equ $ - tok_r10_close
tok_one_close: db "1]"
tok_one_close_len equ $ - tok_one_close
tok_ten_close: db "10]"
tok_ten_close_len equ $ - tok_ten_close
tok_four_close: db "4]"
tok_four_close_len equ $ - tok_four_close
tok_rsdp_revision_close: db "RSDP_REVISION]"
tok_rsdp_revision_close_len equ $ - tok_rsdp_revision_close
tok_rsdp_rsdt_addr_close: db "RSDP_RSDT_ADDR]"
tok_rsdp_rsdt_addr_close_len equ $ - tok_rsdp_rsdt_addr_close
tok_rsdp_xsdt_addr_close: db "RSDP_XSDT_ADDR]"
tok_rsdp_xsdt_addr_close_len equ $ - tok_rsdp_xsdt_addr_close
tok_rsdp_length_close: db "RSDP_LENGTH]"
tok_rsdp_length_close_len equ $ - tok_rsdp_length_close
tok_madt_lapic_addr_close: db "MADT_LAPIC_ADDR]"
tok_madt_lapic_addr_close_len equ $ - tok_madt_lapic_addr_close
tok_madt_entries: db "MADT_ENTRIES"
tok_madt_entries_len equ $ - tok_madt_entries
tok_uart_dll: db "UART_DLL"
tok_uart_dll_len equ $ - tok_uart_dll
tok_uart_dlm: db "UART_DLM"
tok_uart_dlm_len equ $ - tok_uart_dlm
tok_uart_ier: db "UART_IER"
tok_uart_ier_len equ $ - tok_uart_ier
tok_uart_fcr: db "UART_FCR"
tok_uart_fcr_len equ $ - tok_uart_fcr
tok_uart_lcr: db "UART_LCR"
tok_uart_lcr_len equ $ - tok_uart_lcr
tok_uart_mcr: db "UART_MCR"
tok_uart_mcr_len equ $ - tok_uart_mcr
tok_uart_lsr: db "UART_LSR"
tok_uart_lsr_len equ $ - tok_uart_lsr
tok_lcr_dlab: db "LCR_DLAB"
tok_lcr_dlab_len equ $ - tok_lcr_dlab
tok_lcr_8n1: db "LCR_8N1"
tok_lcr_8n1_len equ $ - tok_lcr_8n1
tok_lsr_thr_empty: db "LSR_THR_EMPTY"
tok_lsr_thr_empty_len equ $ - tok_lsr_thr_empty
tok_lsr_data_ready: db "LSR_DATA_READY"
tok_lsr_data_ready_len equ $ - tok_lsr_data_ready
tok_error_no_data: db "ERROR_NO_DATA"
tok_error_no_data_len equ $ - tok_error_no_data
tok_error_timeout: db "ERROR_TIMEOUT"
tok_error_timeout_len equ $ - tok_error_timeout
tok_er_in_al_dx_sym: db "er_in_al_dx"
tok_er_in_al_dx_sym_len equ $ - tok_er_in_al_dx_sym
tok_er_out_dx_al_sym: db "er_out_dx_al"
tok_er_out_dx_al_sym_len equ $ - tok_er_out_dx_al_sym
tok_i8042_in_status: db "_i8042_in_status"
tok_i8042_in_status_len equ $ - tok_i8042_in_status
tok_i8042_in_data: db "_i8042_in_data"
tok_i8042_in_data_len equ $ - tok_i8042_in_data
tok_i8042_out_cmd: db "_i8042_out_cmd"
tok_i8042_out_cmd_len equ $ - tok_i8042_out_cmd
tok_i8042_out_data: db "_i8042_out_data"
tok_i8042_out_data_len equ $ - tok_i8042_out_data
tok_madt_ioapic_addr_close: db "MADT_IOAPIC_ADDR]"
tok_madt_ioapic_addr_close_len equ $ - tok_madt_ioapic_addr_close
tok_madt_ioapic_gsi_base_close: db "MADT_IOAPIC_GSI_BASE]"
tok_madt_ioapic_gsi_base_close_len equ $ - tok_madt_ioapic_gsi_base_close
tok_mcfg_allocations: db "MCFG_ALLOCATIONS"
tok_mcfg_allocations_len equ $ - tok_mcfg_allocations
tok_mcfg_alloc_entry: db "MCFG_ALLOC_ENTRY"
tok_mcfg_alloc_entry_len equ $ - tok_mcfg_alloc_entry
tok_mcfg_alloc_base_close: db "MCFG_ALLOC_BASE]"
tok_mcfg_alloc_base_close_len equ $ - tok_mcfg_alloc_base_close
tok_mcfg_alloc_start_close: db "MCFG_ALLOC_START]"
tok_mcfg_alloc_start_close_len equ $ - tok_mcfg_alloc_start_close
tok_mcfg_alloc_end_close: db "MCFG_ALLOC_END]"
tok_mcfg_alloc_end_close_len equ $ - tok_mcfg_alloc_end_close
tok_sdt_length_close: db "SDT_LENGTH]"
tok_sdt_length_close_len equ $ - tok_sdt_length_close
tok_sdt_header_len: db "SDT_HEADER_LEN"
tok_sdt_header_len_len equ $ - tok_sdt_header_len
tok_two_close: db "2]"
tok_two_close_len equ $ - tok_two_close
tok_three_close: db "3]"
tok_three_close_len equ $ - tok_three_close
tok_rel_open: db "[rel"
tok_rel_open_len equ $ - tok_rel_open

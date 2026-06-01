; Stubs for tor_ntor.o external references not used by field arithmetic tests.
; These are called by ntor handshake functions, never by _fe_mul/_fe_invert,
; but the linker needs them to resolve all symbols in tor_ntor.o.

UNEXPECTED_NTOR_STUB_EXIT equ 88

SECTION .text

global er_tor_hmac_sha256
global er_tpm_get_random
global er_tpm_crb_transfer
global er_tpm_parse_get_random
global er_tor_sha256

er_tor_hmac_sha256:
er_tpm_get_random:
er_tpm_crb_transfer:
er_tpm_parse_get_random:
er_tor_sha256:
    mov     eax, -1
    mov     edx, UNEXPECTED_NTOR_STUB_EXIT
    ret

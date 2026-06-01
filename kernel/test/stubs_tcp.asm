; Stubs for TCP checksum test dependencies outside the checksum path.

SECTION .text

global er_ip_send
er_ip_send:
    xor     eax, eax
    ret

global er_net_get_ip
er_net_get_ip:
    xor     eax, eax
    ret

global er_memcpy
er_memcpy:
    ret

global er_memset
er_memset:
    ret

global er_tpm_get_random
er_tpm_get_random:
    xor     eax, eax
    ret

global er_tpm_crb_transfer
er_tpm_crb_transfer:
    xor     eax, eax
    ret

global er_tpm_parse_get_random
er_tpm_parse_get_random:
    xor     eax, eax
    ret

global er_serial_putchar
er_serial_putchar:
    ret

global er_serial_puthex32
er_serial_puthex32:
    ret

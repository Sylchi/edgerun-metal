; EdgeRun TPM2 shared protocol constants
; Included by both tpm.asm and consumers (e.g. kernel_main.asm)
; to avoid duplicate definitions.

; Tags
%define TPM_ST_NO_SESSIONS      0x8001

; Response codes
%define TPM_RC_SUCCESS          0x00000000

; Common command codes
%define TPM_CC_STARTUP          0x00000144
%define TPM_CC_GET_RANDOM       0x0000017b
%define TPM_CC_GET_CAPABILITY   0x0000017a

; Startup types
%define TPM_SU_CLEAR            0x0000

; Capability types
%define TPM_CAP_ALGS            0x00000000
%define TPM_CAP_COMMANDS        0x00000002

; Common algorithm IDs
%define TPM_ALG_SHA256          0x000b
%define TPM_ALG_ECC             0x0023

; Protocol sizes
%define TPM_HEADER_LEN          10

; Command size constants
%define TPM_CMD_STARTUP_LEN     12
%define TPM_CMD_GET_RANDOM_LEN  12
%define TPM_CMD_GET_CAP_LEN     22

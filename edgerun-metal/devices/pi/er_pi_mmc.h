#ifndef ER_PI_MMC_H
#define ER_PI_MMC_H

/*
 * Purpose: expose Raspberry Pi EMMC/MMC/SDIO register-level helpers.
 * Intention: share storage and SDIO command sequencing across Pi boards without
 * binding raw kernels to the UEFI MMIO handle table.
 */

#include "er_mmio.h"

#define ER_PI_CLOCK_ID_EMMC 1u
#define ER_PI_CLOCK_ID_UART 2u

#define ER_PI_MMC_CMD_GO_IDLE_STATE 0u
#define ER_PI_MMC_CMD_ALL_SEND_CID 2u
#define ER_PI_MMC_CMD_SEND_RELATIVE_ADDR 3u
#define ER_PI_MMC_CMD_IO_SEND_OP_COND 5u
#define ER_PI_MMC_CMD_SELECT_CARD 7u
#define ER_PI_MMC_CMD_SEND_IF_COND 8u
#define ER_PI_MMC_CMD_READ_SINGLE_BLOCK 17u
#define ER_PI_MMC_CMD_WRITE_BLOCK 24u
#define ER_PI_MMC_ACMD_SD_SEND_OP_COND 41u
#define ER_PI_MMC_CMD_IO_RW_DIRECT 52u
#define ER_PI_MMC_CMD_IO_RW_EXTENDED 53u
#define ER_PI_MMC_CMD_APP_CMD 55u

#define ER_PI_MMC_RESPONSE_NONE 0u
#define ER_PI_MMC_RESPONSE_R1 1u
#define ER_PI_MMC_RESPONSE_R2 2u
#define ER_PI_MMC_RESPONSE_R3 3u
#define ER_PI_MMC_RESPONSE_R4 4u
#define ER_PI_MMC_RESPONSE_R5 5u
#define ER_PI_MMC_RESPONSE_R6 6u
#define ER_PI_MMC_RESPONSE_R7 7u

#define ER_PI_MMC_RCA_MASK 0x0000ffffu

#define ER_PI_SDIO_FUNCTION_BACKPLANE 1u
#define ER_PI_SDIO_FUNCTION_WLAN 2u

#define ER_PI_SDIO_READ 0u
#define ER_PI_SDIO_WRITE 1u
#define ER_PI_SDIO_CMD52_READ ER_PI_SDIO_READ
#define ER_PI_SDIO_CMD52_WRITE ER_PI_SDIO_WRITE
#define ER_PI_SDIO_CMD52_NO_RAW 0u
#define ER_PI_SDIO_CMD52_RAW 1u

#define ER_PI_SDIO_CMD53_FIXED_ADDRESS 0u
#define ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS 1u
#define ER_PI_SDIO_CMD53_BYTE_MODE 0u
#define ER_PI_SDIO_CMD53_BLOCK_MODE 1u

#define ER_PI_EMMC_BLOCK_BYTES 512u

#define ER_PI_EMMC_REG_BLKSIZECNT 0x00000004u
#define ER_PI_EMMC_REG_ARG1 0x00000008u
#define ER_PI_EMMC_REG_CMDTM 0x0000000cu
#define ER_PI_EMMC_REG_RESP0 0x00000010u
#define ER_PI_EMMC_REG_RESP1 0x00000014u
#define ER_PI_EMMC_REG_RESP2 0x00000018u
#define ER_PI_EMMC_REG_RESP3 0x0000001cu
#define ER_PI_EMMC_REG_DATA 0x00000020u
#define ER_PI_EMMC_REG_STATUS 0x00000024u
#define ER_PI_EMMC_REG_INTERRUPT 0x00000030u
#define ER_PI_EMMC_REG_IRPT_MASK 0x00000034u
#define ER_PI_EMMC_REG_IRPT_EN 0x00000038u
#define ER_PI_EMMC_REG_CONTROL2 0x0000003cu

#define ER_PI_EMMC_INTERRUPT_CMD_DONE 0x00000001u
#define ER_PI_EMMC_INTERRUPT_DATA_DONE 0x00000002u
#define ER_PI_EMMC_INTERRUPT_WRITE_RDY 0x00000010u
#define ER_PI_EMMC_INTERRUPT_READ_RDY 0x00000020u
#define ER_PI_EMMC_INTERRUPT_ERROR_MASK 0xffff0000u

typedef struct {
  UINT32 command_index;
  UINT32 argument;
  UINT32 response_kind;
} ErPiMmcCommand;

typedef struct {
  UINT32 interrupt_offset;
  UINT32 interrupt_clear_value;
  UINT32 argument_offset;
  UINT32 argument_value;
  UINT32 command_offset;
  UINT32 command_value;
  UINT32 response_offset;
  UINT32 response_kind;
} ErPiEmmcCommandIo;

typedef struct {
  ErPiEmmcCommandIo io;
  UINT32 interrupt_value;
  UINT32 response0;
  UINT32 response1;
  UINT32 response2;
  UINT32 response3;
  UINT8 completed;
  UINT8 error;
} ErPiEmmcCommandResult;

typedef struct {
  UINT32 block_size_count_offset;
  UINT32 block_size_count_value;
  UINT32 data_offset;
  ErPiEmmcCommandIo command_io;
  UINT8 read;
} ErPiEmmcBlockIo;

typedef struct {
  ErPiEmmcBlockIo io;
  UINT32 interrupt_value;
  UINT32 response0;
  UINT8 completed;
  UINT8 error;
} ErPiEmmcBlockResult;

typedef struct {
  UINT32 block_size_count_offset;
  UINT32 block_size_count_value;
  UINT32 data_offset;
  UINT32 data_len;
  ErPiEmmcCommandIo command_io;
  UINT8 read;
} ErPiEmmcSdioTransferIo;

typedef struct {
  ErPiEmmcSdioTransferIo io;
  UINT32 interrupt_value;
  UINT32 response0;
  UINT8 completed;
  UINT8 error;
} ErPiEmmcSdioTransferResult;

typedef UINT8 (*ErPiEmmcRead32Fn)(void* ctx,
                                  UINT32 offset,
                                  UINT32* out_value);
typedef UINT8 (*ErPiEmmcWrite32Fn)(void* ctx, UINT32 offset, UINT32 value);
typedef UINT8 (*ErPiEmmcRead8Fn)(void* ctx, UINT32 offset, UINT8* out_value);
typedef UINT8 (*ErPiEmmcWrite8Fn)(void* ctx, UINT32 offset, UINT8 value);

typedef struct {
  void* ctx;
  ErPiEmmcRead32Fn read32;
  ErPiEmmcWrite32Fn write32;
  ErPiEmmcRead8Fn read8;
  ErPiEmmcWrite8Fn write8;
} ErPiEmmcMmioOps;

UINT32 er_pi_sdio_cmd52_argument(UINT8 write,
                                 UINT8 function,
                                 UINT8 raw,
                                 UINT32 address,
                                 UINT8 data);
UINT32 er_pi_sdio_cmd53_argument(UINT8 write,
                                 UINT8 function,
                                 UINT8 block_mode,
                                 UINT8 incrementing_address,
                                 UINT32 address,
                                 UINT32 count);
UINT32 er_pi_mmc_relative_card_argument(UINT32 relative_card_address);
UINT32 er_pi_mmc_relative_card_from_r6(UINT32 response);
UINT8 er_pi_mmc_command_prepare(UINT32 command_index,
                                UINT32 argument,
                                UINT32 response_kind,
                                ErPiMmcCommand* out_command);
UINT8 er_pi_emmc_command_io_prepare(const ErPiMmcCommand* command,
                                    ErPiEmmcCommandIo* out_io);
UINT8 er_pi_emmc_command_begin(INT64 emmc_handle,
                               const ErPiMmcCommand* command,
                               ErPiEmmcCommandIo* out_io);
UINT8 er_pi_emmc_command_poll(INT64 emmc_handle,
                              const ErPiEmmcCommandIo* io,
                              UINT32 poll_budget,
                              ErPiEmmcCommandResult* out_result);
UINT8 er_pi_emmc_command_execute(INT64 emmc_handle,
                                 const ErPiMmcCommand* command,
                                 UINT32 poll_budget,
                                 ErPiEmmcCommandResult* out_result);
UINT8 er_pi_emmc_block_io_prepare(UINT32 command_index,
                                  UINT32 block_address,
                                  ErPiEmmcBlockIo* out_io);
UINT8 er_pi_emmc_read_block_with_ops(const ErPiEmmcMmioOps* ops,
                                     UINT32 block_address,
                                     UINT8* out_block,
                                     UINT32 poll_budget,
                                     ErPiEmmcBlockResult* out_result);
UINT8 er_pi_emmc_write_block_with_ops(const ErPiEmmcMmioOps* ops,
                                      UINT32 block_address,
                                      const UINT8* block,
                                      UINT32 poll_budget,
                                      ErPiEmmcBlockResult* out_result);
UINT8 er_pi_emmc_read_block(INT64 emmc_handle,
                            UINT32 block_address,
                            UINT8* out_block,
                            UINT32 poll_budget,
                            ErPiEmmcBlockResult* out_result);
UINT8 er_pi_emmc_write_block(INT64 emmc_handle,
                             UINT32 block_address,
                             const UINT8* block,
                             UINT32 poll_budget,
                             ErPiEmmcBlockResult* out_result);
UINT8 er_pi_emmc_sdio_transfer_io_prepare(UINT8 write,
                                           UINT8 function,
                                           UINT8 incrementing_address,
                                           UINT32 address,
                                           UINT32 data_len,
                                           ErPiEmmcSdioTransferIo* out_io);
UINT8 er_pi_emmc_sdio_read_bytes(INT64 emmc_handle,
                                 UINT8 function,
                                 UINT8 incrementing_address,
                                 UINT32 address,
                                 UINT8* out_bytes,
                                 UINT32 bytes_len,
                                 UINT32 poll_budget,
                                 ErPiEmmcSdioTransferResult* out_result);
UINT8 er_pi_emmc_sdio_write_bytes(INT64 emmc_handle,
                                  UINT8 function,
                                  UINT8 incrementing_address,
                                  UINT32 address,
                                  const UINT8* bytes,
                                  UINT32 bytes_len,
                                  UINT32 poll_budget,
                                  ErPiEmmcSdioTransferResult* out_result);

#endif

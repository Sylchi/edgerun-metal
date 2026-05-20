enum {
  TEST_PI_EMMC_OPS_READY_INTERRUPT_READ = 1u,
  TEST_PI_EMMC_OPS_DATA_DONE_INTERRUPT_READ = 2u,
  TEST_PI_EMMC_OPS_RESPONSE0 = 0x1a2b3c4du
};

typedef struct {
  UINT32 interrupt_read_count;
  UINT32 ready_interrupt;
  UINT32 data_read_count;
  UINT32 data_write_count;
  UINT32 first_data_read_word;
  UINT32 last_data_read_word;
  UINT32 first_data_word;
  UINT32 last_data_word;
} TestPiEmmcOpsCtx;

static UINT8 test_pi_emmc_ops_read32(void* ctx,
                                     UINT32 offset,
                                     UINT32* out_value) {
  TestPiEmmcOpsCtx* ops_ctx = (TestPiEmmcOpsCtx*)ctx;

  if (ops_ctx == 0 || out_value == 0) {
    return 0u;
  }
  switch (offset) {
    case ER_PI_EMMC_REG_INTERRUPT:
      ops_ctx->interrupt_read_count += 1u;
      switch (ops_ctx->interrupt_read_count) {
        case TEST_PI_EMMC_OPS_READY_INTERRUPT_READ:
          *out_value = ops_ctx->ready_interrupt;
          return 1u;
        case TEST_PI_EMMC_OPS_DATA_DONE_INTERRUPT_READ:
          *out_value = ER_PI_EMMC_INTERRUPT_DATA_DONE;
          return 1u;
        default:
          *out_value = 0u;
          return 1u;
      }
    case ER_PI_EMMC_REG_RESP0:
      *out_value = TEST_PI_EMMC_OPS_RESPONSE0;
      return 1u;
    case ER_PI_EMMC_REG_DATA:
      *out_value =
          ops_ctx->first_data_read_word + ops_ctx->data_read_count;
      ops_ctx->last_data_read_word = *out_value;
      ops_ctx->data_read_count += 1u;
      return 1u;
    default:
      *out_value = 0u;
      return 1u;
  }
}

static UINT8 test_pi_emmc_ops_write32(void* ctx,
                                      UINT32 offset,
                                      UINT32 value) {
  TestPiEmmcOpsCtx* ops_ctx = (TestPiEmmcOpsCtx*)ctx;

  if (ops_ctx == 0) {
    return 0u;
  }
  switch (offset) {
    case ER_PI_EMMC_REG_DATA:
      if (ops_ctx->data_write_count == 0u) {
        ops_ctx->first_data_word = value;
      }
      ops_ctx->last_data_word = value;
      ops_ctx->data_write_count += 1u;
      return 1u;
    case ER_PI_EMMC_REG_INTERRUPT:
    case ER_PI_EMMC_REG_BLKSIZECNT:
    case ER_PI_EMMC_REG_ARG1:
    case ER_PI_EMMC_REG_CMDTM:
      return 1u;
    default:
      return 0u;
  }
}

static void test_pi_zero2w_bringup_boundary(void) {
  enum {
    PI_TEST_SDIO_CMD52_PACKED = 0xa82468abu,
    PI_TEST_SDIO_CMD53_PACKED = 0x2c008020u,
    PI_TEST_SDIO_ADDRESS = 0x00001234u,
    PI_TEST_SDIO_DATA = 0xabu,
    PI_TEST_SDIO_BLOCK_ADDRESS = 0x00000040u,
    PI_TEST_SDIO_BLOCK_COUNT = 0x00000020u,
    PI_TEST_SDIO_BYTE_COUNT = 0x00000010u,
    PI_TEST_SDIO_CMD53_READ_BYTES_PACKED = 0x24008010u,
    PI_TEST_SDIO_CMD53_WRITE_BYTES_PACKED = 0xa4008010u,
    PI_TEST_SDIO_RCA = 0x00001234u,
    PI_TEST_SDIO_RCA_ARGUMENT = 0x12340000u,
    PI_TEST_SDIO_OCR_3V3 = 0x00300000u,
    PI_TEST_SD_MEMORY_IF_COND = 0x000001aau,
    PI_TEST_SD_MEMORY_OCR_HCS = 0x40300000u,
    PI_TEST_SD_MEMORY_IDENTITY_PLAN_COUNT = 6u,
    PI_TEST_SD_MEMORY_CLAIM_PLAN_COUNT = 1u,
    PI_TEST_SD_MEMORY_CMD8_INDEX = 1u,
    PI_TEST_SD_MEMORY_CMD55_INDEX = 2u,
    PI_TEST_SD_MEMORY_ACMD41_INDEX = 3u,
    PI_TEST_SD_MEMORY_CMD2_INDEX = 4u,
    PI_TEST_SD_MEMORY_CMD3_INDEX = 5u,
    PI_TEST_SDIO_IDENTITY_PLAN_COUNT = 3u,
    PI_TEST_SDIO_CLAIM_PLAN_COUNT = 2u,
    PI_TEST_SDIO_CLAIM_CMD52_INDEX = 1u,
    PI_TEST_SDIO_IDENTITY_CMD5_INDEX = 1u,
    PI_TEST_SDIO_IDENTITY_CMD3_INDEX = 2u,
    PI_TEST_EMMC_CMD0_VALUE = 0x00000000u,
    PI_TEST_EMMC_CMD5_VALUE = 0x05020000u,
    PI_TEST_EMMC_CMD3_VALUE = 0x031a0000u,
    PI_TEST_EMMC_CMD8_VALUE = 0x081a0000u,
    PI_TEST_EMMC_CMD55_VALUE = 0x371a0000u,
    PI_TEST_EMMC_ACMD41_VALUE = 0x29020000u,
    PI_TEST_EMMC_CMD2_VALUE = 0x02090000u,
    PI_TEST_EMMC_CMD52_VALUE = 0x341a0000u,
    PI_TEST_EMMC_BLOCK_ADDRESS = 0x00000007u,
    PI_TEST_EMMC_BLOCK_SIZE_COUNT_VALUE = 0x00010200u,
    PI_TEST_EMMC_SDIO_BYTE_SIZE_COUNT_VALUE = 0x00010010u,
    PI_TEST_EMMC_CMD17_VALUE = 0x113a0012u,
    PI_TEST_EMMC_CMD24_VALUE = 0x183a0002u,
    PI_TEST_EMMC_CMD53_READ_BYTES_VALUE = 0x353a0012u,
    PI_TEST_EMMC_CMD53_WRITE_BYTES_VALUE = 0x353a0002u,
    PI_TEST_EMMC_WORD_BYTES = 4u,
    PI_TEST_EMMC_FIRST_WRITE_WORD = 0x03020100u,
    PI_TEST_EMMC_LAST_WRITE_WORD = 0xfffefdfcu,
    PI_TEST_EMMC_FIRST_READ_WORD = 0x11121314u,
    PI_TEST_EMMC_LAST_READ_WORD = 0x11121393u,
    PI_TEST_EMMC_FIRST_READ_BYTE = 0x14u,
    PI_TEST_EMMC_LAST_READ_BYTE = 0x11u
  };

  ErPiZero2wMmio mmio;
  ErMmioInfo info;
  ErPiMailboxTwoValueMessage message;
  ErPiMmcCommand command;
  ErPiEmmcCommandIo command_io;
  ErPiEmmcBlockIo block_io;
  ErPiEmmcSdioTransferIo sdio_transfer_io;
  ErPiEmmcCommandResult command_result;
  ErPiEmmcBlockResult block_result;
  ErPiEmmcSdioTransferResult sdio_transfer_result;
  ErPiEmmcMmioOps emmc_ops;
  TestPiEmmcOpsCtx emmc_ops_ctx;
  ErPiZero2wSdioBringupPlan sdio_plan;
  ErPiZero2wSdioBringupState sdio_state;
  ErPiZero2wSdMemoryBringupPlan sd_memory_plan;
  ErPiZero2wSdMemoryBringupState sd_memory_state;
  ErBootServicesReport report;
  UINT8 block[ER_PI_EMMC_BLOCK_BYTES];
  UINT32 i;

  for (i = 0u; i < ER_PI_EMMC_BLOCK_BYTES; ++i) {
    block[i] = (UINT8)i;
  }

  er_mmio_reset();
  check_uint64("pi zero peripheral mailbox phys",
               er_pi_zero2w_peripheral_phys(ER_PI_ZERO2W_MAILBOX_OFFSET),
               ER_PI_ZERO2W_PERIPHERAL_BASE + ER_PI_ZERO2W_MAILBOX_OFFSET);
  check_int64("pi zero mmio map", er_pi_zero2w_mmio_map(&mmio), 1);
  check_uint64("pi zero mmio mapped", mmio.mapped, 1u);
  check_int64("pi zero mailbox info",
              er_mmio_get_info(mmio.mailbox_handle, &info), 1);
  check_uint64("pi zero mailbox phys", info.phys,
               ER_PI_ZERO2W_PERIPHERAL_BASE + ER_PI_ZERO2W_MAILBOX_OFFSET);
  check_uint64("pi zero mailbox len", info.len, ER_PI_ZERO2W_MAILBOX_BYTES);
  check_int64("pi zero gpio info", er_mmio_get_info(mmio.gpio_handle, &info), 1);
  check_uint64("pi zero gpio phys", info.phys,
               ER_PI_ZERO2W_PERIPHERAL_BASE + ER_PI_ZERO2W_GPIO_OFFSET);
  check_int64("pi mailbox reject end tag",
              er_pi_mailbox_two_value_request(ER_PI_MAILBOX_TAG_LAST,
                                              0u,
                                              0u,
                                              &message),
              0);
  check_int64("pi mailbox get clock",
              er_pi_mailbox_two_value_request(ER_PI_MAILBOX_TAG_GET_CLOCK_RATE,
                                              ER_PI_CLOCK_ID_EMMC,
                                              0u,
                                              &message),
              1);
  check_uint64("pi mailbox message bytes", message.size_bytes,
               8u * sizeof(UINT32));
  check_uint64("pi mailbox request", message.request_code,
               ER_PI_MAILBOX_REQUEST_CODE);
  check_uint64("pi mailbox tag", message.tag_id,
               ER_PI_MAILBOX_TAG_GET_CLOCK_RATE);
  check_uint64("pi mailbox value bytes", message.value_buffer_bytes, 8u);
  check_uint64("pi mailbox value0", message.value0, ER_PI_CLOCK_ID_EMMC);
  check_uint64("pi mailbox end", message.end_tag, ER_PI_MAILBOX_TAG_LAST);

  check_uint64("pi sdio cmd52 argument",
               er_pi_sdio_cmd52_argument(ER_PI_SDIO_CMD52_WRITE,
                                         ER_PI_SDIO_FUNCTION_WLAN,
                                         ER_PI_SDIO_CMD52_RAW,
                                         PI_TEST_SDIO_ADDRESS,
                                         PI_TEST_SDIO_DATA),
               PI_TEST_SDIO_CMD52_PACKED);
  check_uint64("pi sdio cmd53 argument",
               er_pi_sdio_cmd53_argument(
                   ER_PI_SDIO_READ,
                   ER_PI_SDIO_FUNCTION_WLAN,
                   ER_PI_SDIO_CMD53_BLOCK_MODE,
                   ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                   PI_TEST_SDIO_BLOCK_ADDRESS,
                   PI_TEST_SDIO_BLOCK_COUNT),
               PI_TEST_SDIO_CMD53_PACKED);
  check_uint64("pi sdio cmd53 read bytes argument",
               er_pi_sdio_cmd53_argument(
                   ER_PI_SDIO_READ,
                   ER_PI_SDIO_FUNCTION_WLAN,
                   ER_PI_SDIO_CMD53_BYTE_MODE,
                   ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                   PI_TEST_SDIO_BLOCK_ADDRESS,
                   PI_TEST_SDIO_BYTE_COUNT),
               PI_TEST_SDIO_CMD53_READ_BYTES_PACKED);
  check_uint64("pi sdio cmd53 write bytes argument",
               er_pi_sdio_cmd53_argument(
                   ER_PI_SDIO_WRITE,
                   ER_PI_SDIO_FUNCTION_WLAN,
                   ER_PI_SDIO_CMD53_BYTE_MODE,
                   ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                   PI_TEST_SDIO_BLOCK_ADDRESS,
                   PI_TEST_SDIO_BYTE_COUNT),
               PI_TEST_SDIO_CMD53_WRITE_BYTES_PACKED);
  check_int64("pi mmc rejects wrong response",
              er_pi_mmc_command_prepare(ER_PI_MMC_CMD_IO_RW_DIRECT,
                                        PI_TEST_SDIO_CMD52_PACKED,
                                        ER_PI_MMC_RESPONSE_R4,
                                        &command),
              0);
  check_int64("pi mmc accepts cmd52 response",
              er_pi_mmc_command_prepare(ER_PI_MMC_CMD_IO_RW_DIRECT,
                                        PI_TEST_SDIO_CMD52_PACKED,
                                        ER_PI_MMC_RESPONSE_R5,
                                        &command),
              1);
  check_uint64("pi mmc command index",
               command.command_index,
               ER_PI_MMC_CMD_IO_RW_DIRECT);
  check_uint64("pi mmc command argument",
               command.argument,
               PI_TEST_SDIO_CMD52_PACKED);
  check_uint64("pi mmc command response",
               command.response_kind,
               ER_PI_MMC_RESPONSE_R5);
  check_uint64("pi mmc rca argument",
               er_pi_mmc_relative_card_argument(PI_TEST_SDIO_RCA),
               PI_TEST_SDIO_RCA_ARGUMENT);
  check_uint64("pi mmc rca from r6",
               er_pi_mmc_relative_card_from_r6(PI_TEST_SDIO_RCA_ARGUMENT),
               PI_TEST_SDIO_RCA);
  check_int64("pi sd memory identity plan",
              er_pi_zero2w_sd_memory_identity_plan(&sd_memory_plan),
              1);
  check_uint64("pi sd memory identity plan count",
               sd_memory_plan.command_count,
               PI_TEST_SD_MEMORY_IDENTITY_PLAN_COUNT);
  check_uint64("pi sd memory identity cmd0",
               sd_memory_plan.commands[0].command_index,
               ER_PI_MMC_CMD_GO_IDLE_STATE);
  check_uint64("pi sd memory identity cmd8",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD8_INDEX].command_index,
               ER_PI_MMC_CMD_SEND_IF_COND);
  check_uint64("pi sd memory identity cmd8 argument",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD8_INDEX].argument,
               PI_TEST_SD_MEMORY_IF_COND);
  check_uint64("pi sd memory identity cmd55",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD55_INDEX].command_index,
               ER_PI_MMC_CMD_APP_CMD);
  check_uint64("pi sd memory identity acmd41",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_ACMD41_INDEX].command_index,
               ER_PI_MMC_ACMD_SD_SEND_OP_COND);
  check_uint64("pi sd memory identity acmd41 argument",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_ACMD41_INDEX].argument,
               PI_TEST_SD_MEMORY_OCR_HCS);
  check_uint64("pi sd memory identity cmd2",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD2_INDEX].command_index,
               ER_PI_MMC_CMD_ALL_SEND_CID);
  check_uint64("pi sd memory identity cmd3",
               sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD3_INDEX].command_index,
               ER_PI_MMC_CMD_SEND_RELATIVE_ADDR);
  check_int64("pi emmc cmd8 io",
              er_pi_emmc_command_io_prepare(
                  &sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD8_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc cmd8 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD8_VALUE);
  check_int64("pi emmc cmd55 io",
              er_pi_emmc_command_io_prepare(
                  &sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD55_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc cmd55 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD55_VALUE);
  check_int64("pi emmc acmd41 io",
              er_pi_emmc_command_io_prepare(
                  &sd_memory_plan.commands[PI_TEST_SD_MEMORY_ACMD41_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc acmd41 command value",
               command_io.command_value,
               PI_TEST_EMMC_ACMD41_VALUE);
  check_int64("pi emmc cmd2 io",
              er_pi_emmc_command_io_prepare(
                  &sd_memory_plan.commands[PI_TEST_SD_MEMORY_CMD2_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc cmd2 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD2_VALUE);
  check_int64("pi sd memory claim rejects missing rca",
              er_pi_zero2w_sd_memory_claim_plan(0u, &sd_memory_plan),
              0);
  check_int64("pi sd memory claim plan",
              er_pi_zero2w_sd_memory_claim_plan(PI_TEST_SDIO_RCA,
                                                &sd_memory_plan),
              1);
  check_uint64("pi sd memory claim plan count",
               sd_memory_plan.command_count,
               PI_TEST_SD_MEMORY_CLAIM_PLAN_COUNT);
  check_uint64("pi sd memory claim cmd7",
               sd_memory_plan.commands[0].command_index,
               ER_PI_MMC_CMD_SELECT_CARD);
  check_int64("pi sdio identity plan",
              er_pi_zero2w_sdio_identity_plan(&sdio_plan),
              1);
  check_uint64("pi sdio identity plan count",
               sdio_plan.command_count,
               PI_TEST_SDIO_IDENTITY_PLAN_COUNT);
  check_uint64("pi sdio identity cmd0",
               sdio_plan.commands[0].command_index,
               ER_PI_MMC_CMD_GO_IDLE_STATE);
  check_uint64("pi sdio identity cmd0 response",
               sdio_plan.commands[0].response_kind,
               ER_PI_MMC_RESPONSE_NONE);
  check_int64("pi emmc cmd0 io",
              er_pi_emmc_command_io_prepare(&sdio_plan.commands[0],
                                            &command_io),
              1);
  check_uint64("pi emmc cmd0 interrupt register",
               command_io.interrupt_offset,
               ER_PI_EMMC_REG_INTERRUPT);
  check_uint64("pi emmc cmd0 argument register",
               command_io.argument_offset,
               ER_PI_EMMC_REG_ARG1);
  check_uint64("pi emmc cmd0 command register",
               command_io.command_offset,
               ER_PI_EMMC_REG_CMDTM);
  check_uint64("pi emmc cmd0 response register",
               command_io.response_offset,
               ER_PI_EMMC_REG_RESP0);
  check_uint64("pi emmc cmd0 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD0_VALUE);
  check_uint64("pi sdio identity cmd5",
               sdio_plan.commands[PI_TEST_SDIO_IDENTITY_CMD5_INDEX].command_index,
               ER_PI_MMC_CMD_IO_SEND_OP_COND);
  check_uint64("pi sdio identity cmd5 response",
               sdio_plan.commands[PI_TEST_SDIO_IDENTITY_CMD5_INDEX].response_kind,
               ER_PI_MMC_RESPONSE_R4);
  check_int64("pi emmc cmd5 io",
              er_pi_emmc_command_io_prepare(
                  &sdio_plan.commands[PI_TEST_SDIO_IDENTITY_CMD5_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc cmd5 argument",
               command_io.argument_value,
               PI_TEST_SDIO_OCR_3V3);
  check_uint64("pi emmc cmd5 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD5_VALUE);
  check_uint64("pi sdio identity cmd3",
               sdio_plan.commands[PI_TEST_SDIO_IDENTITY_CMD3_INDEX].command_index,
               ER_PI_MMC_CMD_SEND_RELATIVE_ADDR);
  check_uint64("pi sdio identity cmd3 response",
               sdio_plan.commands[PI_TEST_SDIO_IDENTITY_CMD3_INDEX].response_kind,
               ER_PI_MMC_RESPONSE_R6);
  check_int64("pi emmc cmd3 io",
              er_pi_emmc_command_io_prepare(
                  &sdio_plan.commands[PI_TEST_SDIO_IDENTITY_CMD3_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc cmd3 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD3_VALUE);
  check_int64("pi sdio claim rejects missing rca",
              er_pi_zero2w_sdio_claim_plan(0u, &sdio_plan),
              0);
  check_int64("pi sdio claim plan",
              er_pi_zero2w_sdio_claim_plan(PI_TEST_SDIO_RCA, &sdio_plan),
              1);
  check_uint64("pi sdio claim plan count",
               sdio_plan.command_count,
               PI_TEST_SDIO_CLAIM_PLAN_COUNT);
  check_uint64("pi sdio claim cmd7",
               sdio_plan.commands[0].command_index,
               ER_PI_MMC_CMD_SELECT_CARD);
  check_uint64("pi sdio claim cmd7 argument",
               sdio_plan.commands[0].argument,
               PI_TEST_SDIO_RCA_ARGUMENT);
  check_uint64("pi sdio claim cmd7 response",
               sdio_plan.commands[0].response_kind,
               ER_PI_MMC_RESPONSE_R1);
  check_uint64("pi sdio claim cmd52",
               sdio_plan.commands[PI_TEST_SDIO_CLAIM_CMD52_INDEX].command_index,
               ER_PI_MMC_CMD_IO_RW_DIRECT);
  check_uint64("pi sdio claim cmd52 response",
               sdio_plan.commands[PI_TEST_SDIO_CLAIM_CMD52_INDEX].response_kind,
               ER_PI_MMC_RESPONSE_R5);
  check_int64("pi emmc cmd52 io",
              er_pi_emmc_command_io_prepare(
                  &sdio_plan.commands[PI_TEST_SDIO_CLAIM_CMD52_INDEX],
                  &command_io),
              1);
  check_uint64("pi emmc cmd52 command value",
               command_io.command_value,
               PI_TEST_EMMC_CMD52_VALUE);
  check_int64("pi mmc accepts cmd17 response",
              er_pi_mmc_command_prepare(ER_PI_MMC_CMD_READ_SINGLE_BLOCK,
                                        PI_TEST_EMMC_BLOCK_ADDRESS,
                                        ER_PI_MMC_RESPONSE_R1,
                                        &command),
              1);
  check_int64("pi mmc rejects cmd17 wrong response",
              er_pi_mmc_command_prepare(ER_PI_MMC_CMD_READ_SINGLE_BLOCK,
                                        PI_TEST_EMMC_BLOCK_ADDRESS,
                                        ER_PI_MMC_RESPONSE_R5,
                                        &command),
              0);
  check_int64("pi emmc read block io",
              er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_READ_SINGLE_BLOCK,
                                          PI_TEST_EMMC_BLOCK_ADDRESS,
                                          &block_io),
              1);
  check_uint64("pi emmc read block size count offset",
               block_io.block_size_count_offset,
               ER_PI_EMMC_REG_BLKSIZECNT);
  check_uint64("pi emmc read block size count value",
               block_io.block_size_count_value,
               PI_TEST_EMMC_BLOCK_SIZE_COUNT_VALUE);
  check_uint64("pi emmc read block data offset",
               block_io.data_offset,
               ER_PI_EMMC_REG_DATA);
  check_uint64("pi emmc read block argument",
               block_io.command_io.argument_value,
               PI_TEST_EMMC_BLOCK_ADDRESS);
  check_uint64("pi emmc read block command value",
               block_io.command_io.command_value,
               PI_TEST_EMMC_CMD17_VALUE);
  check_uint64("pi emmc read block marks read",
               block_io.read,
               1u);
  check_int64("pi emmc write block io",
              er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_WRITE_BLOCK,
                                          PI_TEST_EMMC_BLOCK_ADDRESS,
                                          &block_io),
              1);
  check_uint64("pi emmc write block command value",
               block_io.command_io.command_value,
               PI_TEST_EMMC_CMD24_VALUE);
  check_uint64("pi emmc write block marks write",
               block_io.read,
               0u);
  check_int64("pi emmc block rejects cmd52",
              er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_IO_RW_DIRECT,
                                          PI_TEST_EMMC_BLOCK_ADDRESS,
                                          &block_io),
              0);
  check_int64("pi emmc sdio read transfer io",
              er_pi_emmc_sdio_transfer_io_prepare(
                  ER_PI_SDIO_READ,
                  ER_PI_SDIO_FUNCTION_WLAN,
                  ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                  PI_TEST_SDIO_BLOCK_ADDRESS,
                  PI_TEST_SDIO_BYTE_COUNT,
                  &sdio_transfer_io),
              1);
  check_uint64("pi emmc sdio read transfer size count",
               sdio_transfer_io.block_size_count_value,
               PI_TEST_EMMC_SDIO_BYTE_SIZE_COUNT_VALUE);
  check_uint64("pi emmc sdio read transfer argument",
               sdio_transfer_io.command_io.argument_value,
               PI_TEST_SDIO_CMD53_READ_BYTES_PACKED);
  check_uint64("pi emmc sdio read transfer command value",
               sdio_transfer_io.command_io.command_value,
               PI_TEST_EMMC_CMD53_READ_BYTES_VALUE);
  check_uint64("pi emmc sdio read transfer marks read",
               sdio_transfer_io.read,
               1u);
  check_int64("pi emmc sdio write transfer io",
              er_pi_emmc_sdio_transfer_io_prepare(
                  ER_PI_SDIO_WRITE,
                  ER_PI_SDIO_FUNCTION_WLAN,
                  ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                  PI_TEST_SDIO_BLOCK_ADDRESS,
                  PI_TEST_SDIO_BYTE_COUNT,
                  &sdio_transfer_io),
              1);
  check_uint64("pi emmc sdio write transfer argument",
               sdio_transfer_io.command_io.argument_value,
               PI_TEST_SDIO_CMD53_WRITE_BYTES_PACKED);
  check_uint64("pi emmc sdio write transfer command value",
               sdio_transfer_io.command_io.command_value,
               PI_TEST_EMMC_CMD53_WRITE_BYTES_VALUE);
  check_uint64("pi emmc sdio write transfer marks write",
               sdio_transfer_io.read,
               0u);
  check_int64("pi emmc sdio transfer rejects cccr function",
              er_pi_emmc_sdio_transfer_io_prepare(
                  ER_PI_SDIO_READ,
                  ER_CYW43438_SDIO_FUNCTION_CCCR,
                  ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                  PI_TEST_SDIO_BLOCK_ADDRESS,
                  PI_TEST_SDIO_BYTE_COUNT,
                  &sdio_transfer_io),
              0);
  check_int64("pi emmc command begin rejects block command",
              er_pi_emmc_command_begin(ER_MMIO_INVALID_HANDLE,
                                       &command,
                                       &command_io),
              0);
  check_int64("pi emmc command begin rejects invalid handle",
              er_pi_emmc_command_begin(ER_MMIO_INVALID_HANDLE,
                                       &sdio_plan.commands[0],
                                       &command_io),
              0);
  check_int64("pi emmc command execute rejects invalid handle",
              er_pi_emmc_command_execute(ER_MMIO_INVALID_HANDLE,
                                         &sdio_plan.commands[0],
                                         1u,
                                         &command_result),
              0);
  check_int64("pi emmc read block rejects invalid handle",
              er_pi_emmc_read_block(ER_MMIO_INVALID_HANDLE,
                                    PI_TEST_EMMC_BLOCK_ADDRESS,
                                    block,
                                    1u,
                                    &block_result),
              0);
  check_uint64("pi emmc read block marks error",
               block_result.error,
               1u);
  check_int64("pi emmc write block rejects invalid handle",
              er_pi_emmc_write_block(ER_MMIO_INVALID_HANDLE,
                                     PI_TEST_EMMC_BLOCK_ADDRESS,
                                     block,
                                     1u,
                                     &block_result),
              0);
  check_uint64("pi emmc write block marks error",
               block_result.error,
               1u);
  emmc_ops_ctx.interrupt_read_count = 0u;
  emmc_ops_ctx.ready_interrupt = ER_PI_EMMC_INTERRUPT_WRITE_RDY;
  emmc_ops_ctx.data_read_count = 0u;
  emmc_ops_ctx.data_write_count = 0u;
  emmc_ops_ctx.first_data_read_word = 0u;
  emmc_ops_ctx.last_data_read_word = 0u;
  emmc_ops_ctx.first_data_word = 0u;
  emmc_ops_ctx.last_data_word = 0u;
  emmc_ops.ctx = &emmc_ops_ctx;
  emmc_ops.read32 = test_pi_emmc_ops_read32;
  emmc_ops.write32 = test_pi_emmc_ops_write32;
  emmc_ops.read8 = 0;
  emmc_ops.write8 = 0;
  check_int64("pi emmc write block ops",
              er_pi_emmc_write_block_with_ops(&emmc_ops,
                                              PI_TEST_EMMC_BLOCK_ADDRESS,
                                              block,
                                              2u,
                                              &block_result),
              1);
  check_uint64("pi emmc write block ops completed",
               block_result.completed,
               1u);
  check_uint64("pi emmc write block ops data words",
               emmc_ops_ctx.data_write_count,
               ER_PI_EMMC_BLOCK_BYTES / PI_TEST_EMMC_WORD_BYTES);
  check_uint64("pi emmc write block ops first word",
               emmc_ops_ctx.first_data_word,
               PI_TEST_EMMC_FIRST_WRITE_WORD);
  check_uint64("pi emmc write block ops last word",
               emmc_ops_ctx.last_data_word,
               PI_TEST_EMMC_LAST_WRITE_WORD);
  check_int64("pi emmc write block rejects null ops",
              er_pi_emmc_write_block_with_ops(0,
                                              PI_TEST_EMMC_BLOCK_ADDRESS,
                                              block,
                                              1u,
                                              &block_result),
              0);
  emmc_ops_ctx.interrupt_read_count = 0u;
  emmc_ops_ctx.ready_interrupt = ER_PI_EMMC_INTERRUPT_READ_RDY;
  emmc_ops_ctx.data_read_count = 0u;
  emmc_ops_ctx.data_write_count = 0u;
  emmc_ops_ctx.first_data_read_word = PI_TEST_EMMC_FIRST_READ_WORD;
  emmc_ops_ctx.last_data_read_word = 0u;
  emmc_ops_ctx.first_data_word = 0u;
  emmc_ops_ctx.last_data_word = 0u;
  check_int64("pi emmc read block ops",
              er_pi_emmc_read_block_with_ops(&emmc_ops,
                                             PI_TEST_EMMC_BLOCK_ADDRESS,
                                             block,
                                             2u,
                                             &block_result),
              1);
  check_uint64("pi emmc read block ops completed",
               block_result.completed,
               1u);
  check_uint64("pi emmc read block ops data words",
               emmc_ops_ctx.data_read_count,
               ER_PI_EMMC_BLOCK_BYTES / PI_TEST_EMMC_WORD_BYTES);
  check_uint64("pi emmc read block ops first byte",
               block[0],
               PI_TEST_EMMC_FIRST_READ_BYTE);
  check_uint64("pi emmc read block ops last first-word byte",
               block[3],
               PI_TEST_EMMC_LAST_READ_BYTE);
  check_uint64("pi emmc read block ops last word",
               emmc_ops_ctx.last_data_read_word,
               PI_TEST_EMMC_LAST_READ_WORD);
  check_int64("pi emmc sdio read rejects invalid handle",
              er_pi_emmc_sdio_read_bytes(ER_MMIO_INVALID_HANDLE,
                                         ER_PI_SDIO_FUNCTION_WLAN,
                                         ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                                         PI_TEST_SDIO_BLOCK_ADDRESS,
                                         block,
                                         PI_TEST_SDIO_BYTE_COUNT,
                                         1u,
                                         &sdio_transfer_result),
              0);
  check_uint64("pi emmc sdio read marks error",
               sdio_transfer_result.error,
               1u);
  check_int64("pi emmc sdio write rejects invalid handle",
              er_pi_emmc_sdio_write_bytes(ER_MMIO_INVALID_HANDLE,
                                          ER_PI_SDIO_FUNCTION_WLAN,
                                          ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                                          PI_TEST_SDIO_BLOCK_ADDRESS,
                                          block,
                                          PI_TEST_SDIO_BYTE_COUNT,
                                          1u,
                                          &sdio_transfer_result),
              0);
  check_uint64("pi emmc sdio write marks error",
               sdio_transfer_result.error,
               1u);
  check_int64("pi emmc command poll rejects zero budget",
              er_pi_emmc_command_poll(ER_MMIO_INVALID_HANDLE,
                                      &command_io,
                                      0u,
                                      &command_result),
              0);
  check_uint64("pi emmc command poll zero budget not completed",
               command_result.completed,
               0u);
  check_int64("pi sdio execute rejects invalid handle",
              er_pi_zero2w_sdio_execute_plan(ER_MMIO_INVALID_HANDLE,
                                             &sdio_plan,
                                             1u,
                                             &sdio_state),
              0);
  check_int64("pi sd memory execute rejects invalid handle",
              er_pi_zero2w_sd_memory_execute_plan(ER_MMIO_INVALID_HANDLE,
                                                  &sd_memory_plan,
                                                  1u,
                                                  &sd_memory_state),
              0);
  check_uint64("pi sd memory execute keeps command count",
               sd_memory_state.command_count,
               PI_TEST_SD_MEMORY_CLAIM_PLAN_COUNT);
  check_uint64("pi sd memory execute marks error",
               sd_memory_state.error,
               1u);
  check_uint64("pi sdio execute keeps command count",
               sdio_state.command_count,
               PI_TEST_SDIO_CLAIM_PLAN_COUNT);
  check_uint64("pi sdio execute reports no completed commands",
               sdio_state.completed_count,
               0u);
  check_uint64("pi sdio execute marks error",
               sdio_state.error,
               1u);

  er_boot_services_report_init(&report);
  er_mmio_reset();
  check_int64("pi zero boot report",
              er_pi_zero2w_apply_boot_report(&report), 1);
  check_uint64("pi zero report wifi kind",
               report.runtime_capabilities.wifi_kind,
               ER_BOOT_WIFI_KIND_CYW43439_SDIO);
  check_uint64("pi zero report wifi not ready",
               report.runtime_capabilities.wifi_ready, 0u);
  check_uint64("pi zero report bluetooth kind",
               report.runtime_capabilities.bluetooth_kind,
               ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART);
  check_uint64("pi zero report bluetooth not ready",
               report.runtime_capabilities.bluetooth_ready, 0u);
  check_uint64("pi zero report storage kind",
               report.runtime_capabilities.local_storage_kind,
               ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD);
  check_uint64("pi zero report update blocked",
               report.runtime_capabilities.update_blocked_reason,
               ER_BOOT_UPDATE_BLOCKED_NO_WIFI);

}

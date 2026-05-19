static void test_pi_zero2w_bringup_boundary(void) {
  enum {
    PI_TEST_SDIO_CMD52_PACKED = 0xa82468abu,
    PI_TEST_SDIO_CMD53_PACKED = 0x2c008020u,
    PI_TEST_SDIO_ADDRESS = 0x00001234u,
    PI_TEST_SDIO_DATA = 0xabu,
    PI_TEST_SDIO_BLOCK_ADDRESS = 0x00000040u,
    PI_TEST_SDIO_BLOCK_COUNT = 0x00000020u,
    PI_TEST_SDIO_RCA = 0x00001234u,
    PI_TEST_SDIO_RCA_ARGUMENT = 0x12340000u,
    PI_TEST_SDIO_OCR_3V3 = 0x00300000u,
    PI_TEST_SDIO_IDENTITY_PLAN_COUNT = 3u,
    PI_TEST_SDIO_CLAIM_PLAN_COUNT = 2u,
    PI_TEST_SDIO_CLAIM_CMD52_INDEX = 1u,
    PI_TEST_SDIO_IDENTITY_CMD5_INDEX = 1u,
    PI_TEST_SDIO_IDENTITY_CMD3_INDEX = 2u,
    PI_TEST_EMMC_CMD0_VALUE = 0x00000000u,
    PI_TEST_EMMC_CMD5_VALUE = 0x05020000u,
    PI_TEST_EMMC_CMD3_VALUE = 0x031a0000u,
    PI_TEST_EMMC_CMD52_VALUE = 0x341a0000u
  };

  ErPiZero2wMmio mmio;
  ErMmioInfo info;
  ErPiMailboxTwoValueMessage message;
  ErPiMmcCommand command;
  ErPiEmmcCommandIo command_io;
  ErPiZero2wSdioBringupPlan sdio_plan;
  ErBootServicesReport report;

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
  check_int64("pi emmc command begin rejects invalid handle",
              er_pi_emmc_command_begin(ER_MMIO_INVALID_HANDLE,
                                       &sdio_plan.commands[0],
                                       &command_io),
              0);

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

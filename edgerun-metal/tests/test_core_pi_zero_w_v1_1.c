#include "../devices/pi_zero_w_v1_1/er_pi_zero_w_v1_1_uart.h"

static void test_pi_zero_w_v1_1_bringup_boundary(void) {
  enum {
    PI_TEST_ZERO_W_UART_ALT5_FSEL1 = 0x00012000u,
    PI_TEST_SERIAL_HEX_DIGIT_A = 10u,
    PI_TEST_SERIAL_HEX_DIGIT_F = 15u
  };

  ErPiZero2wMmio mmio;
  ErMmioInfo info;
  ErBootServicesReport report;
  const ErPiBoardProfile* profile;

  profile = er_pi_zero_w_v1_1_profile();
  check_uint64("pi zero w peripheral phys",
               er_pi_board_peripheral_phys(profile,
                                           ER_PI_ZERO2W_MAILBOX_OFFSET),
               ER_PI_ZERO_W_V1_1_PERIPHERAL_BASE +
                   ER_PI_ZERO2W_MAILBOX_OFFSET);
  er_mmio_reset();
  check_int64("pi zero w mmio map",
              er_pi_board_mmio_map(profile, &mmio),
              1);
  check_int64("pi zero w mailbox info",
              er_mmio_get_info(mmio.mailbox_handle, &info),
              1);
  check_uint64("pi zero w mailbox phys",
               info.phys,
               ER_PI_ZERO_W_V1_1_PERIPHERAL_BASE +
                   ER_PI_ZERO2W_MAILBOX_OFFSET);
  check_uint64("pi zero w profile wifi",
               profile->wifi_kind,
               ER_BOOT_WIFI_KIND_CYW43438_SDIO);
  check_uint64("pi zero w uart peripheral base",
               ER_PI_ZERO_W_V1_1_UART_PERIPHERAL_BASE,
               ER_PI_ZERO_W_V1_1_PERIPHERAL_BASE);

  er_boot_services_report_init(&report);
  er_mmio_reset();
  check_int64("pi zero w boot report",
              er_pi_zero_w_v1_1_apply_boot_report(&report),
              1);
  check_uint64("pi zero w report wifi kind",
               report.runtime_capabilities.wifi_kind,
               ER_BOOT_WIFI_KIND_CYW43438_SDIO);
  check_uint64("pi zero w report bluetooth kind",
               report.runtime_capabilities.bluetooth_kind,
               ER_BOOT_BLUETOOTH_KIND_CYW43438_HCI_UART);
  check_uint64("pi zero w report storage kind",
               report.runtime_capabilities.local_storage_kind,
               ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD);
  check_uint64("pi zero w uart tx shift",
               er_pi_zero_w_v1_1_gpio_fsel_shift(
                   ER_PI_ZERO_W_V1_1_GPIO_PIN_UART_TX),
               12u);
  check_uint64("pi zero w uart rx shift",
               er_pi_zero_w_v1_1_gpio_fsel_shift(
                   ER_PI_ZERO_W_V1_1_GPIO_PIN_UART_RX),
               15u);
  check_uint64("pi zero w uart alt5 fsel",
               er_pi_zero_w_v1_1_gpio_fsel_alt(
                   er_pi_zero_w_v1_1_gpio_fsel_alt(
                       0u,
                       ER_PI_ZERO_W_V1_1_GPIO_PIN_UART_TX,
                       ER_PI_ZERO_W_V1_1_GPIO_ALT5),
                   ER_PI_ZERO_W_V1_1_GPIO_PIN_UART_RX,
                   ER_PI_ZERO_W_V1_1_GPIO_ALT5),
               PI_TEST_ZERO_W_UART_ALT5_FSEL1);
  check_uint64("pi zero w serial hex digit zero",
               (UINT8)er_pi_zero_w_v1_1_serial_hex_digit(0u),
               (UINT8)'0');
  check_uint64("pi zero w serial hex digit nine",
               (UINT8)er_pi_zero_w_v1_1_serial_hex_digit(9u),
               (UINT8)'9');
  check_uint64("pi zero w serial hex digit a",
               (UINT8)er_pi_zero_w_v1_1_serial_hex_digit(
                   PI_TEST_SERIAL_HEX_DIGIT_A),
               (UINT8)'a');
  check_uint64("pi zero w serial hex digit f",
               (UINT8)er_pi_zero_w_v1_1_serial_hex_digit(
                   PI_TEST_SERIAL_HEX_DIGIT_F),
               (UINT8)'f');
}

#include "er_pi_zero_w_v1_1_lcd_hat.h"

#include "er_pi_zero_w_v1_1_uart.h"
#include "er_st7789.h"

#define ER_PI_ZERO_W_V1_1_LCD_READY 1u
#define ER_PI_ZERO_W_V1_1_LCD_RESET_DELAY_TICKS 20000u
#define ER_PI_ZERO_W_V1_1_LCD_GPIO_DELAY_TICKS 150u
#define ER_PI_ZERO_W_V1_1_LCD_SPI_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_LCD_LINE_SCALE 2u
#define ER_PI_ZERO_W_V1_1_LCD_TITLE_SCALE 3u
#define ER_PI_ZERO_W_V1_1_LCD_LINE_HEIGHT 18u
#define ER_PI_ZERO_W_V1_1_LCD_LEFT 8u
#define ER_PI_ZERO_W_V1_1_LCD_TOP 8u
#define ER_PI_ZERO_W_V1_1_LCD_TITLE_Y 8u
#define ER_PI_ZERO_W_V1_1_LCD_STATUS_Y 40u
#define ER_PI_ZERO_W_V1_1_LCD_SDIO_Y 62u
#define ER_PI_ZERO_W_V1_1_LCD_STORE_Y 84u
#define ER_PI_ZERO_W_V1_1_LCD_L2_Y 106u
#define ER_PI_ZERO_W_V1_1_LCD_OTA_Y 128u
#define ER_PI_ZERO_W_V1_1_LCD_HEARTBEAT_Y 150u
#define ER_PI_ZERO_W_V1_1_LCD_HEX_DIGITS 8u
#define ER_PI_ZERO_W_V1_1_LCD_HEX_PREFIX_BYTES 2u
#define ER_PI_ZERO_W_V1_1_LCD_LABEL_STATUS "BOOT"
#define ER_PI_ZERO_W_V1_1_LCD_LABEL_SDIO "SDIO"
#define ER_PI_ZERO_W_V1_1_LCD_LABEL_STORE "STORE"
#define ER_PI_ZERO_W_V1_1_LCD_LABEL_L2 "L2"
#define ER_PI_ZERO_W_V1_1_LCD_LABEL_OTA "OTA"
#define ER_PI_ZERO_W_V1_1_LCD_LABEL_HB "HB"
#define ER_PI_ZERO_W_V1_1_LCD_TEXT_ON "ON"
#define ER_PI_ZERO_W_V1_1_LCD_TEXT_OFF "OFF"
#define ER_PI_ZERO_W_V1_1_LCD_TEXT_EDGERUN "EDGERUN"
#define ER_PI_ZERO_W_V1_1_LCD_TEXT_PI_ZERO_W "PI ZERO W"
#define ER_PI_ZERO_W_V1_1_LCD_HEX_SHIFT_28 28u
#define ER_PI_ZERO_W_V1_1_LCD_HEX_NIBBLE_BITS 4u
#define ER_PI_ZERO_W_V1_1_LCD_HEX_NIBBLE_MASK 0x0fu
#define ER_PI_ZERO_W_V1_1_LCD_DIGIT_9 9u
#define ER_PI_ZERO_W_V1_1_LCD_DIGIT_A_OFFSET 10u

static UINT8 g_er_pi_zero_w_v1_1_lcd_ready = 0u;

static volatile UINT32* er_pi_zero_w_v1_1_lcd_reg(UINT32 base,
                                                  UINT32 offset) {
  return (volatile UINT32*)(UINTN)(base + offset);
}

static UINT32 er_pi_zero_w_v1_1_lcd_read(UINT32 base, UINT32 offset) {
  return *er_pi_zero_w_v1_1_lcd_reg(base, offset);
}

static void er_pi_zero_w_v1_1_lcd_write(UINT32 base,
                                        UINT32 offset,
                                        UINT32 value) {
  *er_pi_zero_w_v1_1_lcd_reg(base, offset) = value;
}

static void er_pi_zero_w_v1_1_lcd_delay(UINT32 ticks) {
  volatile UINT32 i;

  for (i = 0u; i < ticks; ++i) {
    __asm__ volatile("nop" ::: "memory");
  }
}

static void er_pi_zero_w_v1_1_lcd_gpio_set(UINT32 mask) {
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPSET0,
                              mask);
}

static void er_pi_zero_w_v1_1_lcd_gpio_clear(UINT32 mask) {
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPCLR0,
                              mask);
}

static UINT8 er_pi_zero_w_v1_1_lcd_spi_wait(UINT32 mask) {
  UINT32 i;

  for (i = 0u; i < ER_PI_ZERO_W_V1_1_LCD_SPI_POLL_BUDGET; ++i) {
    if ((er_pi_zero_w_v1_1_lcd_read(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                                    ER_PI_ZERO_W_V1_1_SPI0_CS) & mask) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_pi_zero_w_v1_1_lcd_spi_write_byte(UINT8 value) {
  if (er_pi_zero_w_v1_1_lcd_spi_wait(ER_PI_ZERO_W_V1_1_SPI0_CS_TXD) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                              ER_PI_ZERO_W_V1_1_SPI0_FIFO,
                              value);
  while ((er_pi_zero_w_v1_1_lcd_read(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                                     ER_PI_ZERO_W_V1_1_SPI0_CS) &
          ER_PI_ZERO_W_V1_1_SPI0_CS_RXD) != 0u) {
    (void)er_pi_zero_w_v1_1_lcd_read(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                                     ER_PI_ZERO_W_V1_1_SPI0_FIFO);
  }
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_lcd_spi_transfer(const UINT8* bytes,
                                                UINT32 len) {
  UINT32 i;
  UINT32 control;

  if (bytes == 0 && len != 0u) {
    return 0u;
  }
  control = ER_PI_ZERO_W_V1_1_SPI0_CS_CHIP_SELECT_0 |
            ER_PI_ZERO_W_V1_1_SPI0_CS_CLEAR_TX_RX |
            ER_PI_ZERO_W_V1_1_SPI0_CS_TA;
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                              ER_PI_ZERO_W_V1_1_SPI0_CS,
                              control);
  for (i = 0u; i < len; ++i) {
    if (er_pi_zero_w_v1_1_lcd_spi_write_byte(bytes[i]) == 0u) {
      er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                                  ER_PI_ZERO_W_V1_1_SPI0_CS,
                                  ER_PI_ZERO_W_V1_1_SPI0_CS_CHIP_SELECT_0);
      return 0u;
    }
  }
  if (er_pi_zero_w_v1_1_lcd_spi_wait(ER_PI_ZERO_W_V1_1_SPI0_CS_DONE) == 0u) {
    er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                                ER_PI_ZERO_W_V1_1_SPI0_CS,
                                ER_PI_ZERO_W_V1_1_SPI0_CS_CHIP_SELECT_0);
    return 0u;
  }
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                              ER_PI_ZERO_W_V1_1_SPI0_CS,
                              ER_PI_ZERO_W_V1_1_SPI0_CS_CHIP_SELECT_0);
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_lcd_command(void* ctx, UINT8 command) {
  (void)ctx;
  er_pi_zero_w_v1_1_lcd_gpio_clear(ER_PI_ZERO_W_V1_1_GPIO_SET_LCD_DC);
  return er_pi_zero_w_v1_1_lcd_spi_transfer(&command, 1u);
}

static UINT8 er_pi_zero_w_v1_1_lcd_data(void* ctx,
                                        const UINT8* bytes,
                                        UINT32 len) {
  (void)ctx;
  er_pi_zero_w_v1_1_lcd_gpio_set(ER_PI_ZERO_W_V1_1_GPIO_SET_LCD_DC);
  return er_pi_zero_w_v1_1_lcd_spi_transfer(bytes, len);
}

static void er_pi_zero_w_v1_1_lcd_bus_delay(void* ctx, UINT32 ticks) {
  (void)ctx;
  er_pi_zero_w_v1_1_lcd_delay(ticks);
}

static ErSt7789Bus er_pi_zero_w_v1_1_lcd_bus(void) {
  ErSt7789Bus bus;

  bus.ctx = 0;
  bus.write_command = er_pi_zero_w_v1_1_lcd_command;
  bus.write_data = er_pi_zero_w_v1_1_lcd_data;
  bus.delay = er_pi_zero_w_v1_1_lcd_bus_delay;
  return bus;
}

static void er_pi_zero_w_v1_1_lcd_gpio_init(void) {
  UINT32 fsel0;
  UINT32 fsel1;
  UINT32 fsel2;

  fsel0 = er_pi_zero_w_v1_1_lcd_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                     ER_PI_ZERO_W_V1_1_GPIO_GPFSEL0);
  fsel0 = er_pi_zero_w_v1_1_gpio_fsel_alt(
      fsel0,
      ER_PI_ZERO_W_V1_1_GPIO_PIN_LCD_CS,
      ER_PI_ZERO_W_V1_1_GPIO_ALT0);
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPFSEL0,
                              fsel0);

  fsel1 = er_pi_zero_w_v1_1_lcd_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                     ER_PI_ZERO_W_V1_1_GPIO_GPFSEL1);
  fsel1 = er_pi_zero_w_v1_1_gpio_fsel_alt(
      fsel1,
      ER_PI_ZERO_W_V1_1_GPIO_PIN_LCD_MOSI,
      ER_PI_ZERO_W_V1_1_GPIO_ALT0);
  fsel1 = er_pi_zero_w_v1_1_gpio_fsel_alt(
      fsel1,
      ER_PI_ZERO_W_V1_1_GPIO_PIN_LCD_SCLK,
      ER_PI_ZERO_W_V1_1_GPIO_ALT0);
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPFSEL1,
                              fsel1);

  fsel2 = er_pi_zero_w_v1_1_lcd_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                     ER_PI_ZERO_W_V1_1_GPIO_GPFSEL2);
  fsel2 = er_pi_zero_w_v1_1_gpio_fsel_alt(
      fsel2,
      ER_PI_ZERO_W_V1_1_GPIO_PIN_LCD_BL,
      ER_PI_ZERO_W_V1_1_GPIO_OUTPUT);
  fsel2 = er_pi_zero_w_v1_1_gpio_fsel_alt(
      fsel2,
      ER_PI_ZERO_W_V1_1_GPIO_PIN_LCD_DC,
      ER_PI_ZERO_W_V1_1_GPIO_OUTPUT);
  fsel2 = er_pi_zero_w_v1_1_gpio_fsel_alt(
      fsel2,
      ER_PI_ZERO_W_V1_1_GPIO_PIN_LCD_RST,
      ER_PI_ZERO_W_V1_1_GPIO_OUTPUT);
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPFSEL2,
                              fsel2);

  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPPUD,
                              ER_PI_ZERO_W_V1_1_GPIO_PULL_DISABLE);
  er_pi_zero_w_v1_1_lcd_delay(ER_PI_ZERO_W_V1_1_LCD_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPPUDCLK0,
                              ER_PI_ZERO_W_V1_1_GPIO_PULL_CLOCK_LCD);
  er_pi_zero_w_v1_1_lcd_delay(ER_PI_ZERO_W_V1_1_LCD_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                              ER_PI_ZERO_W_V1_1_GPIO_GPPUDCLK0,
                              ER_PI_ZERO_W_V1_1_GPIO_PULL_DISABLE);
}

static void er_pi_zero_w_v1_1_lcd_hex(char* out, UINT32 value) {
  UINT32 i;
  UINT8 nibble;

  out[0] = '0';
  out[1] = 'X';
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_LCD_HEX_DIGITS; ++i) {
    nibble = (UINT8)((value >> (ER_PI_ZERO_W_V1_1_LCD_HEX_SHIFT_28 -
                                (i * ER_PI_ZERO_W_V1_1_LCD_HEX_NIBBLE_BITS))) &
                     ER_PI_ZERO_W_V1_1_LCD_HEX_NIBBLE_MASK);
    out[i + ER_PI_ZERO_W_V1_1_LCD_HEX_PREFIX_BYTES] =
        (char)(nibble <= ER_PI_ZERO_W_V1_1_LCD_DIGIT_9 ?
                   ('0' + nibble) :
                   ('A' + (nibble - ER_PI_ZERO_W_V1_1_LCD_DIGIT_A_OFFSET)));
  }
  out[ER_PI_ZERO_W_V1_1_LCD_HEX_PREFIX_BYTES +
      ER_PI_ZERO_W_V1_1_LCD_HEX_DIGITS] = '\0';
}

static UINT8 er_pi_zero_w_v1_1_lcd_draw_pair(const ErSt7789Bus* bus,
                                             UINT16 y,
                                             const char* label,
                                             UINT32 value,
                                             UINT16 value_color) {
  char text[ER_PI_ZERO_W_V1_1_LCD_HEX_PREFIX_BYTES +
            ER_PI_ZERO_W_V1_1_LCD_HEX_DIGITS + 1u];

  er_pi_zero_w_v1_1_lcd_hex(text, value);
  return er_st7789_draw_text(bus,
                             ER_PI_ZERO_W_V1_1_LCD_LEFT,
                             y,
                             label,
                             ER_PI_ZERO_W_V1_1_LCD_LINE_SCALE,
                             ER_ST7789_COLOR_CYAN,
                             ER_ST7789_COLOR_BLACK) != 0u &&
         er_st7789_draw_text(bus,
                             ER_PI_ZERO_W_V1_1_LCD_LEFT,
                             (UINT16)(y + ER_PI_ZERO_W_V1_1_LCD_LINE_HEIGHT),
                             text,
                             ER_PI_ZERO_W_V1_1_LCD_LINE_SCALE,
                             value_color,
                             ER_ST7789_COLOR_BLACK) != 0u;
}

void er_pi_zero_w_v1_1_lcd_hat_init(void) {
  ErSt7789Bus bus;

  g_er_pi_zero_w_v1_1_lcd_ready = 0u;
  er_pi_zero_w_v1_1_lcd_gpio_init();
  er_pi_zero_w_v1_1_lcd_write(ER_PI_ZERO_W_V1_1_SPI0_BASE,
                              ER_PI_ZERO_W_V1_1_SPI0_CLK,
                              ER_PI_ZERO_W_V1_1_SPI0_CLOCK_DIVISOR);
  er_pi_zero_w_v1_1_lcd_gpio_set(ER_PI_ZERO_W_V1_1_GPIO_SET_LCD_BL |
                                 ER_PI_ZERO_W_V1_1_GPIO_SET_LCD_RST);
  er_pi_zero_w_v1_1_lcd_delay(ER_PI_ZERO_W_V1_1_LCD_RESET_DELAY_TICKS);
  er_pi_zero_w_v1_1_lcd_gpio_clear(ER_PI_ZERO_W_V1_1_GPIO_SET_LCD_RST);
  er_pi_zero_w_v1_1_lcd_delay(ER_PI_ZERO_W_V1_1_LCD_RESET_DELAY_TICKS);
  er_pi_zero_w_v1_1_lcd_gpio_set(ER_PI_ZERO_W_V1_1_GPIO_SET_LCD_RST);
  er_pi_zero_w_v1_1_lcd_delay(ER_PI_ZERO_W_V1_1_LCD_RESET_DELAY_TICKS);
  bus = er_pi_zero_w_v1_1_lcd_bus();
  if (er_st7789_init(&bus) == 0u ||
      er_st7789_fill_rect(&bus,
                          0u,
                          0u,
                          ER_ST7789_WIDTH,
                          ER_ST7789_HEIGHT,
                          ER_ST7789_COLOR_BLACK) == 0u ||
      er_st7789_draw_text(&bus,
                          ER_PI_ZERO_W_V1_1_LCD_LEFT,
                          ER_PI_ZERO_W_V1_1_LCD_TITLE_Y,
                          ER_PI_ZERO_W_V1_1_LCD_TEXT_EDGERUN,
                          ER_PI_ZERO_W_V1_1_LCD_TITLE_SCALE,
                          ER_ST7789_COLOR_GREEN,
                          ER_ST7789_COLOR_BLACK) == 0u ||
      er_st7789_draw_text(&bus,
                          ER_PI_ZERO_W_V1_1_LCD_LEFT,
                          ER_PI_ZERO_W_V1_1_LCD_STATUS_Y,
                          ER_PI_ZERO_W_V1_1_LCD_TEXT_PI_ZERO_W,
                          ER_PI_ZERO_W_V1_1_LCD_LINE_SCALE,
                          ER_ST7789_COLOR_WHITE,
                          ER_ST7789_COLOR_BLACK) == 0u) {
    return;
  }
  g_er_pi_zero_w_v1_1_lcd_ready = ER_PI_ZERO_W_V1_1_LCD_READY;
}

void er_pi_zero_w_v1_1_lcd_hat_status(const ErPiZeroWV11DebugStatus* status) {
  ErSt7789Bus bus;

  if (g_er_pi_zero_w_v1_1_lcd_ready != ER_PI_ZERO_W_V1_1_LCD_READY ||
      status == 0) {
    return;
  }
  bus = er_pi_zero_w_v1_1_lcd_bus();
  if (er_st7789_fill_rect(&bus,
                          0u,
                          ER_PI_ZERO_W_V1_1_LCD_SDIO_Y,
                          ER_ST7789_WIDTH,
                          (UINT16)(ER_ST7789_HEIGHT -
                                   ER_PI_ZERO_W_V1_1_LCD_SDIO_Y),
                          ER_ST7789_COLOR_BLACK) == 0u) {
    g_er_pi_zero_w_v1_1_lcd_ready = 0u;
    return;
  }
  if (er_pi_zero_w_v1_1_lcd_draw_pair(&bus,
                                      ER_PI_ZERO_W_V1_1_LCD_SDIO_Y,
                                      ER_PI_ZERO_W_V1_1_LCD_LABEL_SDIO,
                                      status->sdio_state,
                                      ER_ST7789_COLOR_YELLOW) == 0u ||
      er_pi_zero_w_v1_1_lcd_draw_pair(&bus,
                                      ER_PI_ZERO_W_V1_1_LCD_STORE_Y,
                                      ER_PI_ZERO_W_V1_1_LCD_LABEL_STORE,
                                      status->storage_state,
                                      ER_ST7789_COLOR_WHITE) == 0u ||
      er_st7789_draw_text(&bus,
                          ER_PI_ZERO_W_V1_1_LCD_LEFT,
                          ER_PI_ZERO_W_V1_1_LCD_L2_Y,
                          ER_PI_ZERO_W_V1_1_LCD_LABEL_L2,
                          ER_PI_ZERO_W_V1_1_LCD_LINE_SCALE,
                          ER_ST7789_COLOR_CYAN,
                          ER_ST7789_COLOR_BLACK) == 0u ||
      er_st7789_draw_text(&bus,
                          ER_PI_ZERO_W_V1_1_LCD_LEFT,
                          (UINT16)(ER_PI_ZERO_W_V1_1_LCD_L2_Y +
                                   ER_PI_ZERO_W_V1_1_LCD_LINE_HEIGHT),
                          status->l2_ready != 0u ?
                              ER_PI_ZERO_W_V1_1_LCD_TEXT_ON :
                              ER_PI_ZERO_W_V1_1_LCD_TEXT_OFF,
                          ER_PI_ZERO_W_V1_1_LCD_LINE_SCALE,
                          status->l2_ready != 0u ?
                              ER_ST7789_COLOR_GREEN :
                              ER_ST7789_COLOR_RED,
                          ER_ST7789_COLOR_BLACK) == 0u ||
      er_pi_zero_w_v1_1_lcd_draw_pair(&bus,
                                      ER_PI_ZERO_W_V1_1_LCD_OTA_Y,
                                      ER_PI_ZERO_W_V1_1_LCD_LABEL_OTA,
                                      status->ota_status ^ status->ota_offset,
                                      ER_ST7789_COLOR_WHITE) == 0u ||
      er_pi_zero_w_v1_1_lcd_draw_pair(&bus,
                                      ER_PI_ZERO_W_V1_1_LCD_HEARTBEAT_Y,
                                      ER_PI_ZERO_W_V1_1_LCD_LABEL_HB,
                                      status->heartbeat,
                                      ER_ST7789_COLOR_GREEN) == 0u) {
    g_er_pi_zero_w_v1_1_lcd_ready = 0u;
  }
}

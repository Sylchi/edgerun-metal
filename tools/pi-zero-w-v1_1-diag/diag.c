typedef unsigned int u32;

#define GPIO_BASE 0x20200000u
#define AUX_BASE 0x20215000u
#define SPI0_BASE 0x20204000u

#define GPIO_FSEL0 0x00u
#define GPIO_SET0 0x1cu
#define GPIO_SET1 0x20u
#define GPIO_CLR0 0x28u
#define GPIO_CLR1 0x2cu
#define GPIO_PUD 0x94u
#define GPIO_PUDCLK0 0x98u
#define GPIO_PUDCLK1 0x9cu

#define AUX_ENABLES 0x04u
#define AUX_MU_IO 0x40u
#define AUX_MU_IER 0x44u
#define AUX_MU_IIR 0x48u
#define AUX_MU_LCR 0x4cu
#define AUX_MU_MCR 0x50u
#define AUX_MU_LSR 0x54u
#define AUX_MU_CNTL 0x60u
#define AUX_MU_BAUD 0x68u

#define SPI_CS 0x00u
#define SPI_FIFO 0x04u
#define SPI_CLK 0x08u
#define SPI_CS_CLEAR 0x30u
#define SPI_CS_TA 0x80u
#define SPI_CS_DONE 0x10000u
#define SPI_CS_RXD 0x20000u
#define SPI_CS_TXD 0x40000u

#define EMMC_BASE 0x20300000u
#define EMMC_ARG1 0x08u
#define EMMC_CMDTM 0x0cu
#define EMMC_RESP0 0x10u
#define EMMC_DATA 0x20u
#define EMMC_STATUS 0x24u
#define EMMC_CONTROL1 0x2cu
#define EMMC_INTERRUPT 0x30u
#define EMMC_IRPT_MASK 0x34u
#define EMMC_IRPT_EN 0x38u
#define EMMC_BLKSIZECNT 0x04u
#define EMMC_CMD_DONE 0x00000001u
#define EMMC_DATA_DONE 0x00000002u
#define EMMC_WRITE_RDY 0x00000010u
#define EMMC_READ_RDY 0x00000020u
#define EMMC_INTERRUPT_ALL 0xffffffffu
#define EMMC_ERROR_MASK 0xffff0000u
#define EMMC_STATUS_CMD_INHIBIT 0x00000001u
#define EMMC_STATUS_DATA_INHIBIT 0x00000002u
#define EMMC_CONTROL1_CLK_INTLEN 0x00000001u
#define EMMC_CONTROL1_CLK_STABLE 0x00000002u
#define EMMC_CONTROL1_CLK_EN 0x00000004u
#define EMMC_CONTROL1_CLK_GENSEL 0x00000020u
#define EMMC_CONTROL1_DATA_TOUNIT_MAX 0x0000000eu
#define EMMC_CONTROL1_DATA_TOUNIT_SHIFT 16u
#define EMMC_CONTROL1_SRST_HC 0x01000000u
#define EMMC_IDENT_CLOCK_DIVISOR 626u

#define MMC_CMD_GO_IDLE_STATE 0u
#define MMC_CMD_ALL_SEND_CID 2u
#define MMC_CMD_SEND_RELATIVE_ADDR 3u
#define MMC_CMD_SELECT_CARD 7u
#define MMC_CMD_SEND_IF_COND 8u
#define MMC_CMD_WRITE_BLOCK 24u
#define MMC_CMD_APP_CMD 55u
#define MMC_ACMD_SD_SEND_OP_COND 41u
#define MMC_RESPONSE_NONE 0u
#define MMC_RESPONSE_R1 1u
#define MMC_RESPONSE_R2 2u
#define MMC_RESPONSE_R3 3u
#define MMC_RESPONSE_R6 6u
#define MMC_RESPONSE_R7 7u

#define SD_IF_COND_3V3_CHECK 0x000001aau
#define SD_OCR_3V3_HCS 0x40300000u
#define SD_OCR_READY 0x80000000u
#define SD_POLL_BUDGET 1000000u
#define SD_OCR_POLL_BUDGET 1000u
#define SD_LOG_CHECKPOINT_BLOCK 131072u
#define SD_LOG_EVENT_BLOCK 131073u

#define GPIO_ALT0 4u
#define GPIO_ALT5 2u
#define GPIO_OUT 1u

#define PIN_LCD_CS 8u
#define PIN_LCD_MOSI 10u
#define PIN_LCD_SCLK 11u
#define PIN_UART_TX 14u
#define PIN_UART_RX 15u
#define PIN_LCD_BL 24u
#define PIN_LCD_DC 25u
#define PIN_LCD_RST 27u
#define PIN_ACT 47u

static volatile u32 g_sd_stage = 0;
static volatile u32 g_sd_interrupt = 0;
static volatile u32 g_sd_response = 0;
static volatile u32 g_sd_rca = 0;
static volatile u32 g_sd_write_result = 0;

static inline volatile u32 *reg(u32 base, u32 off) {
    return (volatile u32 *)(base + off);
}

static inline u32 rd(u32 base, u32 off) {
    return *reg(base, off);
}

static inline void wr(u32 base, u32 off, u32 v) {
    *reg(base, off) = v;
}

static void delay(u32 n) {
    for (volatile u32 i = 0; i < n; ++i) {
        __asm__ volatile("nop");
    }
}

static void gpio_func(u32 pin, u32 func) {
    const u32 off = GPIO_FSEL0 + (pin / 10u) * 4u;
    const u32 shift = (pin % 10u) * 3u;
    u32 v = rd(GPIO_BASE, off);
    v &= ~(7u << shift);
    v |= (func & 7u) << shift;
    wr(GPIO_BASE, off, v);
}

static void gpio_set(u32 pin) {
    if (pin < 32u) {
        wr(GPIO_BASE, GPIO_SET0, 1u << pin);
    } else {
        wr(GPIO_BASE, GPIO_SET1, 1u << (pin - 32u));
    }
}

static void gpio_clr(u32 pin) {
    if (pin < 32u) {
        wr(GPIO_BASE, GPIO_CLR0, 1u << pin);
    } else {
        wr(GPIO_BASE, GPIO_CLR1, 1u << (pin - 32u));
    }
}

static void gpio_disable_pulls(u32 mask0, u32 mask1) {
    wr(GPIO_BASE, GPIO_PUD, 0u);
    delay(150u);
    wr(GPIO_BASE, GPIO_PUDCLK0, mask0);
    wr(GPIO_BASE, GPIO_PUDCLK1, mask1);
    delay(150u);
    wr(GPIO_BASE, GPIO_PUDCLK0, 0u);
    wr(GPIO_BASE, GPIO_PUDCLK1, 0u);
}

static void act_on(void) {
    gpio_clr(PIN_ACT);
}

static void act_off(void) {
    gpio_set(PIN_ACT);
}

static void uart_init(void) {
    gpio_func(PIN_UART_TX, GPIO_ALT5);
    gpio_func(PIN_UART_RX, GPIO_ALT5);
    gpio_disable_pulls((1u << PIN_UART_TX) | (1u << PIN_UART_RX), 0u);

    wr(AUX_BASE, AUX_ENABLES, 1u);
    wr(AUX_BASE, AUX_MU_CNTL, 0u);
    wr(AUX_BASE, AUX_MU_IER, 0u);
    wr(AUX_BASE, AUX_MU_IIR, 0xc6u);
    wr(AUX_BASE, AUX_MU_LCR, 3u);
    wr(AUX_BASE, AUX_MU_MCR, 0u);
    wr(AUX_BASE, AUX_MU_BAUD, 270u);
    wr(AUX_BASE, AUX_MU_CNTL, 3u);
}

static void uart_putc(char c) {
    while ((rd(AUX_BASE, AUX_MU_LSR) & 0x20u) == 0u) {
    }
    wr(AUX_BASE, AUX_MU_IO, (u32)c);
}

static void uart_puts(const char *s) {
    while (*s != '\0') {
        uart_putc(*s++);
    }
}

static void put_hex_nibble(u32 n) {
    uart_putc((char)((n < 10u) ? ('0' + n) : ('a' + (n - 10u))));
}

static void uart_hex32(u32 v) {
    uart_puts("0x");
    for (u32 shift = 28u;; shift -= 4u) {
        put_hex_nibble((v >> shift) & 0x0fu);
        if (shift == 0u) break;
    }
}

static u32 emmc_response_bits(u32 response_kind) {
    if (response_kind == MMC_RESPONSE_NONE) return 0u;
    if (response_kind == MMC_RESPONSE_R2) return 1u;
    return 2u;
}

static u32 emmc_response_requires_crc(u32 response_kind) {
    return response_kind == MMC_RESPONSE_R1 ||
           response_kind == MMC_RESPONSE_R2 ||
           response_kind == MMC_RESPONSE_R6 ||
           response_kind == MMC_RESPONSE_R7;
}

static u32 emmc_response_requires_index(u32 response_kind) {
    return response_kind == MMC_RESPONSE_R1 ||
           response_kind == MMC_RESPONSE_R6 ||
           response_kind == MMC_RESPONSE_R7;
}

static u32 emmc_command_value(u32 command_index, u32 response_kind, u32 is_data) {
    u32 value = command_index << 24u;
    value |= emmc_response_bits(response_kind) << 16u;
    if (emmc_response_requires_crc(response_kind) != 0u) value |= 1u << 19u;
    if (emmc_response_requires_index(response_kind) != 0u) value |= 1u << 20u;
    if (is_data != 0u) {
        value |= 1u << 1u;
        value |= 1u << 21u;
    }
    return value;
}

static u32 emmc_wait_clear(u32 offset, u32 mask, u32 poll_budget) {
    for (u32 poll = 0; poll < poll_budget; ++poll) {
        if ((rd(EMMC_BASE, offset) & mask) == 0u) return 1u;
    }
    return 0u;
}

static u32 emmc_wait_set(u32 offset, u32 mask, u32 poll_budget) {
    for (u32 poll = 0; poll < poll_budget; ++poll) {
        if ((rd(EMMC_BASE, offset) & mask) == mask) return 1u;
    }
    return 0u;
}

static u32 emmc_wait_interrupt(u32 wanted, u32 *out_interrupt) {
    *out_interrupt = 0u;
    for (u32 poll = 0; poll < SD_POLL_BUDGET; ++poll) {
        const u32 interrupt = rd(EMMC_BASE, EMMC_INTERRUPT);
        if ((interrupt & EMMC_ERROR_MASK) != 0u) {
            *out_interrupt = interrupt;
            return 0u;
        }
        if ((interrupt & wanted) != 0u) {
            *out_interrupt = interrupt;
            return 1u;
        }
    }
    return 0u;
}

static u32 emmc_init(void) {
    const u32 divisor = EMMC_IDENT_CLOCK_DIVISOR;
    u32 control1 = EMMC_CONTROL1_CLK_INTLEN |
                   EMMC_CONTROL1_CLK_GENSEL |
                   (EMMC_CONTROL1_DATA_TOUNIT_MAX << EMMC_CONTROL1_DATA_TOUNIT_SHIFT);
    control1 |= (divisor & 0xffu) << 8u;
    control1 |= (divisor & 0x300u) >> 6u;

    wr(EMMC_BASE, EMMC_CONTROL1, EMMC_CONTROL1_SRST_HC);
    if (emmc_wait_clear(EMMC_CONTROL1, EMMC_CONTROL1_SRST_HC, 100000u) == 0u) return 0u;
    wr(EMMC_BASE, EMMC_IRPT_EN, 0u);
    wr(EMMC_BASE, EMMC_IRPT_MASK, 0u);
    wr(EMMC_BASE, EMMC_INTERRUPT, EMMC_INTERRUPT_ALL);
    wr(EMMC_BASE, EMMC_CONTROL1, control1);
    if (emmc_wait_set(EMMC_CONTROL1, EMMC_CONTROL1_CLK_STABLE, 100000u) == 0u) return 0u;
    wr(EMMC_BASE, EMMC_CONTROL1, control1 | EMMC_CONTROL1_CLK_EN);
    return 1u;
}

static u32 emmc_command(u32 command_index, u32 argument, u32 response_kind, u32 *out_response) {
    u32 interrupt = 0;
    *out_response = 0u;
    if (emmc_wait_clear(EMMC_STATUS, EMMC_STATUS_CMD_INHIBIT | EMMC_STATUS_DATA_INHIBIT, 100000u) == 0u) return 0u;
    wr(EMMC_BASE, EMMC_INTERRUPT, EMMC_INTERRUPT_ALL);
    wr(EMMC_BASE, EMMC_ARG1, argument);
    wr(EMMC_BASE, EMMC_CMDTM, emmc_command_value(command_index, response_kind, 0u));
    if (emmc_wait_interrupt(EMMC_CMD_DONE, &interrupt) == 0u) {
        g_sd_interrupt = interrupt;
        return 0u;
    }
    g_sd_interrupt = interrupt;
    if (response_kind != MMC_RESPONSE_NONE) {
        *out_response = rd(EMMC_BASE, EMMC_RESP0);
        g_sd_response = *out_response;
    }
    wr(EMMC_BASE, EMMC_INTERRUPT, interrupt);
    return 1u;
}

static u32 sd_app_command(u32 rca, u32 command_index, u32 argument, u32 response_kind, u32 *out_response) {
    u32 app_response = 0;
    if (emmc_command(MMC_CMD_APP_CMD, (rca & 0xffffu) << 16u, MMC_RESPONSE_R1, &app_response) == 0u) return 0u;
    return emmc_command(command_index, argument, response_kind, out_response);
}

static u32 sd_memory_init(void) {
    u32 response = 0;
    g_sd_stage = 0u;
    g_sd_response = 0u;
    g_sd_interrupt = 0u;
    g_sd_rca = 0u;
    if (emmc_init() == 0u) {
        g_sd_stage = 0x80000001u;
        return 0u;
    }
    if (emmc_command(MMC_CMD_GO_IDLE_STATE, 0u, MMC_RESPONSE_NONE, &response) == 0u) {
        g_sd_stage = 0x80000002u;
        return 0u;
    }
    if (emmc_command(MMC_CMD_SEND_IF_COND, SD_IF_COND_3V3_CHECK, MMC_RESPONSE_R7, &response) == 0u) {
        g_sd_stage = 0x80000003u;
        return 0u;
    }
    g_sd_stage = 1u;
    for (u32 poll = 0; poll < SD_OCR_POLL_BUDGET; ++poll) {
        if (sd_app_command(0u, MMC_ACMD_SD_SEND_OP_COND, SD_OCR_3V3_HCS, MMC_RESPONSE_R3, &response) == 0u) {
            g_sd_stage = 0x80000004u;
            return 0u;
        }
        if ((response & SD_OCR_READY) != 0u) break;
    }
    if ((response & SD_OCR_READY) == 0u) {
        g_sd_stage = 0x80000005u;
        return 0u;
    }
    g_sd_stage = 2u;
    if (emmc_command(MMC_CMD_ALL_SEND_CID, 0u, MMC_RESPONSE_R2, &response) == 0u) {
        g_sd_stage = 0x80000006u;
        return 0u;
    }
    g_sd_stage = 3u;
    if (emmc_command(MMC_CMD_SEND_RELATIVE_ADDR, 0u, MMC_RESPONSE_R6, &response) == 0u) {
        g_sd_stage = 0x80000007u;
        return 0u;
    }
    g_sd_rca = (response >> 16u) & 0xffffu;
    if (g_sd_rca == 0u) {
        g_sd_stage = 0x80000008u;
        return 0u;
    }
    g_sd_stage = 4u;
    if (emmc_command(MMC_CMD_SELECT_CARD, g_sd_rca << 16u, MMC_RESPONSE_R1, &response) == 0u) {
        g_sd_stage = 0x80000009u;
        return 0u;
    }
    g_sd_stage = 5u;
    return 1u;
}

static void put_le32(unsigned char *block, u32 offset, u32 value) {
    block[offset] = (unsigned char)value;
    block[offset + 1u] = (unsigned char)(value >> 8u);
    block[offset + 2u] = (unsigned char)(value >> 16u);
    block[offset + 3u] = (unsigned char)(value >> 24u);
}

static void fill_log_block(unsigned char *block, u32 event) {
    for (u32 i = 0; i < 512u; ++i) block[i] = 0u;
    put_le32(block, 0u, 0x4c444745u);
    put_le32(block, 4u, 1u);
    put_le32(block, 8u, 0x20260522u);
    put_le32(block, 12u, 3u);
    put_le32(block, 16u, event);
    put_le32(block, 20u, (u32)g_sd_stage);
    put_le32(block, 24u, (u32)g_sd_interrupt);
    put_le32(block, 28u, (u32)g_sd_response);
    put_le32(block, 32u, (u32)g_sd_rca);
    put_le32(block, 36u, (u32)g_sd_write_result);
    block[64] = 'E';
    block[65] = 'R';
    block[66] = ' ';
    block[67] = 'P';
    block[68] = 'I';
    block[69] = ' ';
    block[70] = 'S';
    block[71] = 'D';
    block[72] = ' ';
    block[73] = 'D';
    block[74] = 'I';
    block[75] = 'A';
    block[76] = 'G';
}

static u32 sd_write_block(u32 block_address, const unsigned char *block) {
    u32 interrupt = 0;
    u32 response = 0;
    if (emmc_wait_clear(EMMC_STATUS, EMMC_STATUS_CMD_INHIBIT | EMMC_STATUS_DATA_INHIBIT, 100000u) == 0u) {
        g_sd_write_result = 0x80000010u;
        return 0u;
    }
    wr(EMMC_BASE, EMMC_INTERRUPT, EMMC_INTERRUPT_ALL);
    wr(EMMC_BASE, EMMC_BLKSIZECNT, (1u << 16u) | 512u);
    wr(EMMC_BASE, EMMC_ARG1, block_address);
    wr(EMMC_BASE, EMMC_CMDTM, emmc_command_value(MMC_CMD_WRITE_BLOCK, MMC_RESPONSE_R1, 1u));
    if (emmc_wait_interrupt(EMMC_WRITE_RDY, &interrupt) == 0u) {
        g_sd_interrupt = interrupt;
        g_sd_write_result = 0x80000011u;
        return 0u;
    }
    for (u32 word_index = 0; word_index < 128u; ++word_index) {
        const u32 byte_index = word_index * 4u;
        const u32 word = (u32)block[byte_index] |
                         ((u32)block[byte_index + 1u] << 8u) |
                         ((u32)block[byte_index + 2u] << 16u) |
                         ((u32)block[byte_index + 3u] << 24u);
        wr(EMMC_BASE, EMMC_DATA, word);
    }
    if (emmc_wait_interrupt(EMMC_DATA_DONE, &interrupt) == 0u) {
        g_sd_interrupt = interrupt;
        g_sd_write_result = 0x80000012u;
        return 0u;
    }
    response = rd(EMMC_BASE, EMMC_RESP0);
    wr(EMMC_BASE, EMMC_INTERRUPT, interrupt);
    g_sd_interrupt = interrupt;
    g_sd_response = response;
    g_sd_write_result = 1u;
    return 1u;
}

static void sd_log(void) {
    unsigned char block[512];
    if (sd_memory_init() == 0u) {
        uart_puts("sd=init-fail stage=");
        uart_hex32((u32)g_sd_stage);
        uart_puts(" intr=");
        uart_hex32((u32)g_sd_interrupt);
        uart_puts(" resp=");
        uart_hex32((u32)g_sd_response);
        uart_puts("\r\n");
        return;
    }
    fill_log_block(block, 0x10u);
    (void)sd_write_block(SD_LOG_CHECKPOINT_BLOCK, block);
    fill_log_block(block, 0x11u);
    (void)sd_write_block(SD_LOG_EVENT_BLOCK, block);
    uart_puts("sd=logged stage=");
    uart_hex32((u32)g_sd_stage);
    uart_puts(" rca=");
    uart_hex32((u32)g_sd_rca);
    uart_puts(" write=");
    uart_hex32((u32)g_sd_write_result);
    uart_puts("\r\n");
}

static void spi_init(void) {
    gpio_func(PIN_LCD_CS, GPIO_ALT0);
    gpio_func(PIN_LCD_MOSI, GPIO_ALT0);
    gpio_func(PIN_LCD_SCLK, GPIO_ALT0);
    gpio_disable_pulls((1u << PIN_LCD_CS) | (1u << PIN_LCD_MOSI) | (1u << PIN_LCD_SCLK), 0u);

    wr(SPI0_BASE, SPI_CS, 0u);
    wr(SPI0_BASE, SPI_CLK, 32u);
    wr(SPI0_BASE, SPI_CS, SPI_CS_CLEAR);
}

static void spi_begin(void) {
    wr(SPI0_BASE, SPI_CS, SPI_CS_CLEAR | SPI_CS_TA);
}

static void spi_byte(u32 b) {
    while ((rd(SPI0_BASE, SPI_CS) & SPI_CS_TXD) == 0u) {
    }
    wr(SPI0_BASE, SPI_FIFO, b & 0xffu);
    while ((rd(SPI0_BASE, SPI_CS) & SPI_CS_RXD) != 0u) {
        (void)rd(SPI0_BASE, SPI_FIFO);
    }
}

static void spi_end(void) {
    while ((rd(SPI0_BASE, SPI_CS) & SPI_CS_DONE) == 0u) {
    }
    while ((rd(SPI0_BASE, SPI_CS) & SPI_CS_RXD) != 0u) {
        (void)rd(SPI0_BASE, SPI_FIFO);
    }
    wr(SPI0_BASE, SPI_CS, SPI_CS_CLEAR);
}

static void lcd_cmd(u32 c) {
    gpio_clr(PIN_LCD_DC);
    spi_begin();
    spi_byte(c);
    spi_end();
}

static void lcd_data(u32 d) {
    gpio_set(PIN_LCD_DC);
    spi_begin();
    spi_byte(d);
    spi_end();
}

static void lcd_window(void) {
    lcd_cmd(0x2au);
    lcd_data(0u);
    lcd_data(0u);
    lcd_data(0u);
    lcd_data(239u);

    lcd_cmd(0x2bu);
    lcd_data(0u);
    lcd_data(0u);
    lcd_data(0u);
    lcd_data(239u);

    lcd_cmd(0x2cu);
}

static void lcd_fill(u32 hi, u32 lo) {
    gpio_set(PIN_LCD_DC);
    spi_begin();
    for (u32 i = 0; i < 240u * 240u; ++i) {
        spi_byte(hi);
        spi_byte(lo);
    }
    spi_end();
}

static void lcd_init(void) {
    gpio_func(PIN_LCD_BL, GPIO_OUT);
    gpio_func(PIN_LCD_DC, GPIO_OUT);
    gpio_func(PIN_LCD_RST, GPIO_OUT);
    gpio_disable_pulls((1u << PIN_LCD_BL) | (1u << PIN_LCD_DC) | (1u << PIN_LCD_RST), 0u);

    gpio_set(PIN_LCD_BL);
    gpio_set(PIN_LCD_RST);
    delay(50000u);
    gpio_clr(PIN_LCD_RST);
    delay(50000u);
    gpio_set(PIN_LCD_RST);
    delay(120000u);

    spi_init();
    lcd_cmd(0x01u);
    delay(120000u);
    lcd_cmd(0x11u);
    delay(120000u);
    lcd_cmd(0x3au);
    lcd_data(0x55u);
    lcd_cmd(0x36u);
    lcd_data(0x00u);
    lcd_cmd(0x21u);
    lcd_cmd(0x29u);
    delay(120000u);
    lcd_window();
    lcd_fill(0xf8u, 0x00u);
}

static void diag_main(void) __attribute__((used));
static void diag_main(void) {
    gpio_func(PIN_ACT, GPIO_OUT);
    act_off();
    uart_init();
    uart_puts("\r\nER PI ZERO W V1.1 DIAG BOOT\r\n");
    uart_puts("uart=ok sd=init-log lcd=init led=blink\r\n");

    sd_log();

    lcd_init();
    uart_puts("lcd=red-fill\r\n");

    for (;;) {
        act_on();
        uart_puts("ER DIAG ALIVE red\r\n");
        lcd_window();
        lcd_fill(0xf8u, 0x00u);
        delay(800000u);

        act_off();
        uart_puts("ER DIAG ALIVE green\r\n");
        lcd_window();
        lcd_fill(0x07u, 0xe0u);
        delay(800000u);
    }
}

void _start(void) __attribute__((naked, section(".text.start")));
void _start(void) {
    __asm__ volatile(
        "mov sp, #0x8000\n"
        "bl diag_main\n"
        "1: b 1b\n");
}

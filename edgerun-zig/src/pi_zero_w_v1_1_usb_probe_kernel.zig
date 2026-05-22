const gpio_base: u32 = 0x2020_0000;
const aux_base: u32 = 0x2021_5000;

const gpio_fsel1: u32 = 0x04;
const gpio_fsel4: u32 = 0x10;
const gpio_set1: u32 = 0x20;
const gpio_clr1: u32 = 0x2c;
const gpio_pud: u32 = 0x94;
const gpio_pudclk0: u32 = 0x98;

const aux_enables: u32 = 0x04;
const aux_mu_io: u32 = 0x40;
const aux_mu_ier: u32 = 0x44;
const aux_mu_iir: u32 = 0x48;
const aux_mu_lcr: u32 = 0x4c;
const aux_mu_mcr: u32 = 0x50;
const aux_mu_lsr: u32 = 0x54;
const aux_mu_cntl: u32 = 0x60;
const aux_mu_baud: u32 = 0x68;

const pin_uart_tx: u32 = 14;
const pin_uart_rx: u32 = 15;
const pin_act_led: u32 = 47;
const gpio_output: u32 = 1;
const gpio_alt5: u32 = 2;

fn reg32(base: u32, offset: u32) *volatile u32 {
    return @ptrFromInt(base + offset);
}

fn read32(base: u32, offset: u32) u32 {
    return reg32(base, offset).*;
}

fn write32(base: u32, offset: u32, value: u32) void {
    reg32(base, offset).* = value;
}

fn delay(ticks: u32) void {
    var i: u32 = 0;
    while (i < ticks) : (i += 1) {
        asm volatile ("nop");
    }
}

fn gpioFselAlt(current: u32, pin: u32, alt_function: u32) u32 {
    const shift: u5 = @intCast((pin % 10) * 3);
    const mask: u32 = @as(u32, 0b111) << shift;
    return (current & ~mask) | ((alt_function & 0b111) << shift);
}

fn uartInit() void {
    var fsel1 = read32(gpio_base, gpio_fsel1);
    fsel1 = gpioFselAlt(fsel1, pin_uart_tx, gpio_alt5);
    fsel1 = gpioFselAlt(fsel1, pin_uart_rx, gpio_alt5);
    write32(gpio_base, gpio_fsel1, fsel1);
    write32(gpio_base, gpio_pud, 0);
    delay(150);
    write32(gpio_base, gpio_pudclk0, (1 << pin_uart_tx) | (1 << pin_uart_rx));
    delay(150);
    write32(gpio_base, gpio_pudclk0, 0);

    write32(aux_base, aux_enables, 1);
    write32(aux_base, aux_mu_cntl, 0);
    write32(aux_base, aux_mu_ier, 0);
    write32(aux_base, aux_mu_iir, 0xc6);
    write32(aux_base, aux_mu_lcr, 3);
    write32(aux_base, aux_mu_mcr, 0);
    write32(aux_base, aux_mu_baud, 270);
    write32(aux_base, aux_mu_cntl, 3);
}

fn putByte(byte: u8) void {
    while ((read32(aux_base, aux_mu_lsr) & 0x20) == 0) {}
    write32(aux_base, aux_mu_io, byte);
}

fn putString(text: []const u8) void {
    for (text) |byte| putByte(byte);
}

fn actLedInit() void {
    var fsel4 = read32(gpio_base, gpio_fsel4);
    fsel4 = gpioFselAlt(fsel4, pin_act_led, gpio_output);
    write32(gpio_base, gpio_fsel4, fsel4);
}

fn actLedOn() void {
    write32(gpio_base, gpio_clr1, 1 << (pin_act_led - 32));
}

fn actLedOff() void {
    write32(gpio_base, gpio_set1, 1 << (pin_act_led - 32));
}

export fn kernelMain() callconv(.c) noreturn {
    actLedInit();
    actLedOff();
    uartInit();
    putString("\r\nER ZIG USB PROBE BOOT\r\n");
    while (true) {
        actLedOn();
        putString("ER USB PROBE ALIVE\r\n");
        delay(800_000);
        actLedOff();
        delay(800_000);
    }
}

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\mov sp, #0x8000
        \\bl kernelMain
        \\1: b 1b
    );
}

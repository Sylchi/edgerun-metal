#include "er_pi_zero_w_v1_1_uart.h"
#include "er_types.h"

/*
 * Purpose: provide the first owned ARMv6 payload for Raspberry Pi Zero W v1.1.
 * Intention: emit relay node-control state as erwire bytes over the bootstrap
 * UART carrier until the CYW43438 L2 relay carrier is ready.
 */

#define ER_PI_ZERO_W_V1_1_BOOT_MAGIC 0x45525a57u
#define ER_PI_ZERO_W_V1_1_STACK_TOP_ASM "0x8000"
#define ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC 0x31575245u
#define ER_PI_ZERO_W_V1_1_ERWIRE_VERSION 1u
#define ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE 32u
#define ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_FIRST 0x0001u
#define ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_LAST 0x0002u
#define ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_AVAILABLE 37u
#define ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_HEARTBEAT 38u
#define ER_PI_ZERO_W_V1_1_ERWIRE_STREAM_ID 0x45525a57u
#define ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION 1u
#define ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY 1u
#define ER_PI_ZERO_W_V1_1_CHANNEL_KIND_WIFI_OPEN_L2 14u
#define ER_PI_ZERO_W_V1_1_HEARTBEAT_SECS 10u
#define ER_PI_ZERO_W_V1_1_NODE_BYTES 32u
#define ER_PI_ZERO_W_V1_1_HASH_BYTES 32u
#define ER_PI_ZERO_W_V1_1_SSID_BYTES 19u
#define ER_PI_ZERO_W_V1_1_WIFI_ADDR_BYTES 29u
#define ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES 189u
#define ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES 116u
#define ER_PI_ZERO_W_V1_1_CRC32_INITIAL 0xffffffffu
#define ER_PI_ZERO_W_V1_1_CRC32_POLY 0xedb88320u
#define ER_PI_ZERO_W_V1_1_CRC32_BITS_PER_BYTE 8u
#define ER_PI_ZERO_W_V1_1_ETH_TYPE_EDGERUN 0x88b5u
#define ER_PI_ZERO_W_V1_1_WIFI_CHANNEL 6u
#define ER_PI_ZERO_W_V1_1_BYTE_MASK 0xffu
#define ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT 8u
#define ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT 16u
#define ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT 24u
#define ER_PI_ZERO_W_V1_1_U64_BYTE4_SHIFT 32u
#define ER_PI_ZERO_W_V1_1_U64_BYTE5_SHIFT 40u
#define ER_PI_ZERO_W_V1_1_U64_BYTE6_SHIFT 48u
#define ER_PI_ZERO_W_V1_1_U64_BYTE7_SHIFT 56u
#define ER_PI_ZERO_W_V1_1_HEX_HIGH_NIBBLE_SHIFT 4u
#define ER_PI_ZERO_W_V1_1_HEX_NIBBLE_MASK 0x0fu
#define ER_PI_ZERO_W_V1_1_BOOT_MS 0u

volatile UINT32 g_er_pi_zero_w_v1_1_boot_magic =
    ER_PI_ZERO_W_V1_1_BOOT_MAGIC;

static const UINT8 g_er_pi_zero_w_v1_1_node_id[ER_PI_ZERO_W_V1_1_NODE_BYTES] = {
  0x45u, 0x52u, 0x5au, 0x57u, 0x50u, 0x49u, 0x30u, 0x31u,
  0x52u, 0x45u, 0x4cu, 0x41u, 0x59u, 0x30u, 0x30u, 0x31u,
  0x43u, 0x59u, 0x57u, 0x34u, 0x33u, 0x34u, 0x33u, 0x38u,
  0x41u, 0x52u, 0x4du, 0x56u, 0x36u, 0x4cu, 0x32u, 0x01u
};

static const UINT8 g_er_pi_zero_w_v1_1_channel_id[ER_PI_ZERO_W_V1_1_HASH_BYTES] = {
  0x45u, 0x52u, 0x57u, 0x49u, 0x46u, 0x49u, 0x4cu, 0x32u,
  0x50u, 0x49u, 0x5au, 0x45u, 0x52u, 0x4fu, 0x57u, 0x31u,
  0x43u, 0x48u, 0x41u, 0x4eu, 0x4eu, 0x45u, 0x4cu, 0x30u,
  0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x31u
};

static volatile UINT32* er_pi_zero_w_v1_1_reg(UINT32 base, UINT32 offset) {
  return (volatile UINT32*)(UINTN)(base + offset);
}

static UINT32 er_pi_zero_w_v1_1_read(UINT32 base, UINT32 offset) {
  return *er_pi_zero_w_v1_1_reg(base, offset);
}

static void er_pi_zero_w_v1_1_write(UINT32 base, UINT32 offset, UINT32 value) {
  *er_pi_zero_w_v1_1_reg(base, offset) = value;
}

static void er_pi_zero_w_v1_1_barrier(void) {
  __asm__ volatile("" ::: "memory");
}

static void er_pi_zero_w_v1_1_delay(UINT32 ticks) {
  volatile UINT32 i;

  for (i = 0u; i < ticks; ++i) {
    __asm__ volatile("nop" ::: "memory");
  }
}

static void er_pi_zero_w_v1_1_uart_gpio_init(void) {
  UINT32 fsel1;

  fsel1 = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                 ER_PI_GPIO_GPFSEL1);
  fsel1 = er_pi_gpio_fsel_alt(fsel1,
                              ER_PI_GPIO_PIN_UART_TX,
                              ER_PI_GPIO_ALT5);
  fsel1 = er_pi_gpio_fsel_alt(fsel1,
                              ER_PI_GPIO_PIN_UART_RX,
                              ER_PI_GPIO_ALT5);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPFSEL1,
                          fsel1);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPPUD,
                          ER_PI_GPIO_PULL_DISABLE);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPPUDCLK0,
                          ER_PI_GPIO_PULL_CLOCK_UART);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPPUDCLK0,
                          ER_PI_GPIO_PULL_DISABLE);
}

static void er_pi_zero_w_v1_1_uart_init(void) {
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_ENABLES,
                          ER_PI_AUX_ENABLE_MINI_UART);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_CNTL,
                          ER_PI_AUX_MU_DISABLE);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_IER,
                          ER_PI_AUX_MU_DISABLE_INTERRUPTS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_LCR,
                          ER_PI_AUX_MU_EIGHT_BIT_MODE);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_MCR,
                          ER_PI_AUX_MU_RTS_HIGH);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_IIR,
                          ER_PI_AUX_MU_CLEAR_FIFOS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_BAUD,
                          ER_PI_AUX_MU_BAUD_115200_CORE_250MHZ);
  er_pi_zero_w_v1_1_uart_gpio_init();
  er_pi_zero_w_v1_1_barrier();
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_CNTL,
                          ER_PI_AUX_MU_ENABLE_TX_RX);
}

static void er_pi_zero_w_v1_1_uart_put_byte(UINT8 byte) {
  while ((er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_AUX_BASE,
                                 ER_PI_AUX_MU_LSR) &
          ER_PI_AUX_MU_LSR_TX_EMPTY) == 0u) {
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_IO,
                          (UINT32)byte);
}

static void er_pi_zero_w_v1_1_put_u16(UINT8** cursor, UINT16 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 2u;
}

static void er_pi_zero_w_v1_1_put_u32(UINT8** cursor, UINT32 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[2] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[3] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 4u;
}

static void er_pi_zero_w_v1_1_put_u64(UINT8** cursor, UINT64 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[2] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[3] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[4] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE4_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[5] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE5_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[6] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE6_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[7] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE7_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 8u;
}

static void er_pi_zero_w_v1_1_put_bytes(UINT8** cursor,
                                        const UINT8* bytes,
                                        UINT32 len) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    (*cursor)[i] = bytes[i];
  }
  *cursor += len;
}

static UINT8 er_pi_zero_w_v1_1_hex(UINT8 value) {
  UINT8 digit = (UINT8)(value & ER_PI_ZERO_W_V1_1_HEX_NIBBLE_MASK);

  if (digit < 10u) {
    return (UINT8)('0' + digit);
  }
  return (UINT8)('a' + (digit - 10u));
}

static void er_pi_zero_w_v1_1_fill_zero(UINT8* bytes, UINT32 len) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = 0u;
  }
}

static void er_pi_zero_w_v1_1_wifi_address(UINT8 out_address[ER_PI_ZERO_W_V1_1_WIFI_ADDR_BYTES]) {
  UINT32 i;

  out_address[0] = 0x02u;
  out_address[1] = (UINT8)(g_er_pi_zero_w_v1_1_node_id[0] ^
                           g_er_pi_zero_w_v1_1_node_id[7]);
  out_address[2] = (UINT8)(g_er_pi_zero_w_v1_1_node_id[1] ^
                           g_er_pi_zero_w_v1_1_node_id[8]);
  out_address[3] = (UINT8)(g_er_pi_zero_w_v1_1_node_id[2] ^
                           g_er_pi_zero_w_v1_1_node_id[9]);
  out_address[4] = (UINT8)(g_er_pi_zero_w_v1_1_node_id[3] ^
                           g_er_pi_zero_w_v1_1_node_id[10]);
  out_address[5] = (UINT8)(g_er_pi_zero_w_v1_1_node_id[4] ^
                           g_er_pi_zero_w_v1_1_node_id[11]);
  out_address[6] = (UINT8)((ER_PI_ZERO_W_V1_1_ETH_TYPE_EDGERUN >>
                            ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                           ER_PI_ZERO_W_V1_1_BYTE_MASK);
  out_address[7] = (UINT8)(ER_PI_ZERO_W_V1_1_ETH_TYPE_EDGERUN &
                           ER_PI_ZERO_W_V1_1_BYTE_MASK);
  out_address[8] = ER_PI_ZERO_W_V1_1_WIFI_CHANNEL;
  out_address[9] = ER_PI_ZERO_W_V1_1_SSID_BYTES;
  out_address[10] = (UINT8)'e';
  out_address[11] = (UINT8)'r';
  out_address[12] = (UINT8)'-';
  for (i = 0u; i < 8u; ++i) {
    out_address[13u + (i * 2u)] =
        er_pi_zero_w_v1_1_hex((UINT8)(g_er_pi_zero_w_v1_1_node_id[i] >>
                                      ER_PI_ZERO_W_V1_1_HEX_HIGH_NIBBLE_SHIFT));
    out_address[14u + (i * 2u)] =
        er_pi_zero_w_v1_1_hex(g_er_pi_zero_w_v1_1_node_id[i]);
  }
}

static UINT32 er_pi_zero_w_v1_1_crc32(const UINT8* bytes, UINT32 len) {
  UINT32 crc = ER_PI_ZERO_W_V1_1_CRC32_INITIAL;
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    UINT32 bit;
    crc ^= (UINT32)bytes[i];
    for (bit = 0u; bit < ER_PI_ZERO_W_V1_1_CRC32_BITS_PER_BYTE; ++bit) {
      UINT32 mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (ER_PI_ZERO_W_V1_1_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static void er_pi_zero_w_v1_1_send_erwire(UINT16 kind,
                                          UINT32 seq,
                                          const UINT8* payload,
                                          UINT32 payload_len) {
  UINT8 header[ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE];
  UINT8* cursor = header;
  UINT32 i;

  er_pi_zero_w_v1_1_put_u32(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_VERSION);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE);
  er_pi_zero_w_v1_1_put_u32(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_STREAM_ID);
  er_pi_zero_w_v1_1_put_u32(&cursor, seq);
  er_pi_zero_w_v1_1_put_u16(&cursor, kind);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_FIRST |
                                     ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_LAST);
  er_pi_zero_w_v1_1_put_u32(&cursor, payload_len);
  er_pi_zero_w_v1_1_put_u32(&cursor,
                            er_pi_zero_w_v1_1_crc32(payload, payload_len));
  er_pi_zero_w_v1_1_put_u32(&cursor, 0u);
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE; ++i) {
    er_pi_zero_w_v1_1_uart_put_byte(header[i]);
  }
  for (i = 0u; i < payload_len; ++i) {
    er_pi_zero_w_v1_1_uart_put_byte(payload[i]);
  }
}

static void er_pi_zero_w_v1_1_send_node_available(void) {
  UINT8 payload[ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES];
  UINT8 wifi_address[ER_PI_ZERO_W_V1_1_WIFI_ADDR_BYTES];
  UINT8 log_head[ER_PI_ZERO_W_V1_1_HASH_BYTES];
  UINT8* cursor = payload;

  er_pi_zero_w_v1_1_wifi_address(wifi_address);
  er_pi_zero_w_v1_1_fill_zero(log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_node_id,
                              ER_PI_ZERO_W_V1_1_NODE_BYTES);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_node_id,
                              ER_PI_ZERO_W_V1_1_NODE_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor,
                            ER_PI_ZERO_W_V1_1_CHANNEL_KIND_WIFI_OPEN_L2);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_channel_id,
                              ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_WIFI_ADDR_BYTES);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              wifi_address,
                              ER_PI_ZERO_W_V1_1_WIFI_ADDR_BYTES);
  er_pi_zero_w_v1_1_put_u64(&cursor, 1u);
  er_pi_zero_w_v1_1_put_u64(&cursor, ER_PI_ZERO_W_V1_1_BOOT_MS);
  er_pi_zero_w_v1_1_put_u64(&cursor, ER_PI_ZERO_W_V1_1_HEARTBEAT_SECS);
  er_pi_zero_w_v1_1_put_bytes(&cursor, log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_send_erwire(ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_AVAILABLE,
                                0u,
                                payload,
                                ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES);
}

static void er_pi_zero_w_v1_1_send_node_heartbeat(UINT32 heartbeat) {
  UINT8 payload[ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES];
  UINT8 connection_hash[ER_PI_ZERO_W_V1_1_HASH_BYTES];
  UINT8 log_head[ER_PI_ZERO_W_V1_1_HASH_BYTES];
  UINT8* cursor = payload;
  UINT32 i;

  for (i = 0u; i < ER_PI_ZERO_W_V1_1_HASH_BYTES; ++i) {
    connection_hash[i] =
        (UINT8)(g_er_pi_zero_w_v1_1_channel_id[i] ^ (UINT8)heartbeat);
  }
  er_pi_zero_w_v1_1_fill_zero(log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_node_id,
                              ER_PI_ZERO_W_V1_1_NODE_BYTES);
  er_pi_zero_w_v1_1_put_u64(&cursor, (UINT64)heartbeat + 2u);
  er_pi_zero_w_v1_1_put_u64(&cursor, (UINT64)heartbeat);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              connection_hash,
                              ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_bytes(&cursor, log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_send_erwire(ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_HEARTBEAT,
                                heartbeat + 1u,
                                payload,
                                ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES);
}

void er_pi_zero_w_v1_1_main(void) {
  UINT32 heartbeat = 0u;

  er_pi_zero_w_v1_1_uart_init();
  er_pi_zero_w_v1_1_send_node_available();

  for (;;) {
    g_er_pi_zero_w_v1_1_boot_magic = ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
    er_pi_zero_w_v1_1_send_node_heartbeat(heartbeat);
    heartbeat += 1u;
    er_pi_zero_w_v1_1_delay(
        ER_PI_ZERO_W_V1_1_UART_HEARTBEAT_DELAY_TICKS);
  }
}

void _start(void) __attribute__((naked));
void _start(void) {
  __asm__ volatile(
      "ldr sp, =" ER_PI_ZERO_W_V1_1_STACK_TOP_ASM "\n"
      "bl er_pi_zero_w_v1_1_main\n"
      "1: b 1b\n"
      ::: "memory");
}

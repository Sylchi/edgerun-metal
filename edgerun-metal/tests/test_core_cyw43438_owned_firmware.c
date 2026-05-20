#include "test_core_internal.h"

static UINT32 test_owned_firmware_le32(UINT32 offset) {
  return ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset]) |
         ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset + 1u] << 8u) |
         ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset + 2u] << 16u) |
         ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset + 3u] << 24u);
}

static void test_owned_firmware_byte(const char* label,
                                     UINT32 offset,
                                     UINT8 expected) {
  check_uint64(label, (UINT64)ER_CYW43438_OWNED_FIRMWARE[offset], expected);
}

static void test_cyw43438_owned_firmware_payload(void) {
  check_uint64("cyw43438 owned firmware size",
               (UINT64)sizeof(ER_CYW43438_OWNED_FIRMWARE),
               ER_CYW43438_OWNED_FIRMWARE_SIZE);
  check_uint64("cyw43438 owned reset vector",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR);
  check_uint64("cyw43438 owned shared base literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_SHARED_BASE_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_SHARED_BASE);
  check_uint64("cyw43438 owned mailbox magic literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC);
  check_uint64("cyw43438 owned ack mask literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK);
  check_uint64("cyw43438 owned tx frame address literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR);
  check_uint64("cyw43438 owned mailbox address",
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_SHARED_BASE);
  check_uint64("cyw43438 owned heartbeat address",
               ER_CYW43438_OWNED_FIRMWARE_HEARTBEAT_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned command address",
               ER_CYW43438_OWNED_FIRMWARE_COMMAND_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_HEARTBEAT_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned response address",
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_COMMAND_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned tx len address",
               ER_CYW43438_OWNED_FIRMWARE_TX_LEN_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned tx status address",
               ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_TX_LEN_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned tx frame capacity",
               ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_CAPACITY,
               ER_IEEE80211_AP_FRAME_MAX);
  check_uint64("cyw43438 owned tx status fc mask",
               ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_FRAME_CONTROL_MASK,
               0xffu);
  check_uint64("cyw43438 owned tx status len shift",
               ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_LEN_SHIFT,
               8u);
  check_uint64("cyw43438 owned no command",
               ER_CYW43438_OWNED_FIRMWARE_COMMAND_NONE,
               0u);
  check_uint64("cyw43438 owned ping command",
               ER_CYW43438_OWNED_FIRMWARE_COMMAND_PING,
               1u);
  check_uint64("cyw43438 owned tx beacon command",
               ER_CYW43438_OWNED_FIRMWARE_COMMAND_TX_BEACON,
               2u);
  check_uint64("cyw43438 owned ping ack",
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_PING_ACK,
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK |
                   ER_CYW43438_OWNED_FIRMWARE_COMMAND_PING);
  check_uint64("cyw43438 owned tx beacon ack",
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_TX_BEACON_ACK,
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK |
                   ER_CYW43438_OWNED_FIRMWARE_COMMAND_TX_BEACON);
  test_owned_firmware_byte("cyw43438 owned ldr r0",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET,
                           0x09u);
  test_owned_firmware_byte("cyw43438 owned ldr r0 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 1u,
                           0x48u);
  test_owned_firmware_byte("cyw43438 owned ldr r1",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 2u,
                           0x0au);
  test_owned_firmware_byte("cyw43438 owned ldr r1 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 3u,
                           0x49u);
  test_owned_firmware_byte("cyw43438 owned ldr r4",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 4u,
                           0x0au);
  test_owned_firmware_byte("cyw43438 owned ldr r4 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 5u,
                           0x4cu);
  test_owned_firmware_byte("cyw43438 owned ldr r6",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 6u,
                           0x0bu);
  test_owned_firmware_byte("cyw43438 owned ldr r6 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 7u,
                           0x4eu);
  test_owned_firmware_byte("cyw43438 owned store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 8u,
                           0x01u);
  test_owned_firmware_byte("cyw43438 owned store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 9u,
                           0x60u);
  test_owned_firmware_byte("cyw43438 owned movs r2",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 10u,
                           0x00u);
  test_owned_firmware_byte("cyw43438 owned movs r2 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 11u,
                           0x22u);
  test_owned_firmware_byte("cyw43438 owned adds r2",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 12u,
                           0x01u);
  test_owned_firmware_byte("cyw43438 owned adds r2 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 13u,
                           0x32u);
  test_owned_firmware_byte("cyw43438 owned heartbeat store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 14u,
                           0x42u);
  test_owned_firmware_byte("cyw43438 owned heartbeat store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 15u,
                           0x60u);
  test_owned_firmware_byte("cyw43438 owned command load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 16u,
                           0x83u);
  test_owned_firmware_byte("cyw43438 owned command load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 17u,
                           0x68u);
  test_owned_firmware_byte("cyw43438 owned command compare",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 18u,
                           0x00u);
  test_owned_firmware_byte("cyw43438 owned command compare high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 19u,
                           0x2bu);
  test_owned_firmware_byte("cyw43438 owned idle branch",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 20u,
                           0xfau);
  test_owned_firmware_byte("cyw43438 owned idle branch high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 21u,
                           0xd0u);
  test_owned_firmware_byte("cyw43438 owned tx len load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 22u,
                           0x05u);
  test_owned_firmware_byte("cyw43438 owned tx len load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 23u,
                           0x69u);
  test_owned_firmware_byte("cyw43438 owned frame control load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 24u,
                           0x37u);
  test_owned_firmware_byte("cyw43438 owned frame control load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 25u,
                           0x78u);
  test_owned_firmware_byte("cyw43438 owned tx len shift",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 26u,
                           0x2du);
  test_owned_firmware_byte("cyw43438 owned tx len shift high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 27u,
                           0x02u);
  test_owned_firmware_byte("cyw43438 owned tx status orr",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 28u,
                           0x3du);
  test_owned_firmware_byte("cyw43438 owned tx status orr high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 29u,
                           0x43u);
  test_owned_firmware_byte("cyw43438 owned tx status store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 30u,
                           0x45u);
  test_owned_firmware_byte("cyw43438 owned tx status store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 31u,
                           0x61u);
  test_owned_firmware_byte("cyw43438 owned ack orr",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 32u,
                           0x23u);
  test_owned_firmware_byte("cyw43438 owned ack orr high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 33u,
                           0x43u);
  test_owned_firmware_byte("cyw43438 owned response store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 34u,
                           0xc3u);
  test_owned_firmware_byte("cyw43438 owned response store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 35u,
                           0x60u);
  test_owned_firmware_byte("cyw43438 owned loop",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 36u,
                           0xf2u);
  test_owned_firmware_byte("cyw43438 owned loop high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 37u,
                           0xe7u);
}

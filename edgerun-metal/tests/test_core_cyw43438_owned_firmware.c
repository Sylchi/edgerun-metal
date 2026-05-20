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
  check_uint64("cyw43438 owned rx frame address literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR);
  check_uint64("cyw43438 owned rx len address",
               ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned rx status address",
               ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned d11 tx frame address",
               ER_CYW43438_OWNED_FIRMWARE_D11_TX_FRAME_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned d11 tx len address",
               ER_CYW43438_OWNED_FIRMWARE_D11_TX_LEN_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_D11_TX_FRAME_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned d11 tx status address",
               ER_CYW43438_OWNED_FIRMWARE_D11_TX_STATUS_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_D11_TX_LEN_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned tx frame capacity",
               ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_CAPACITY,
               ER_IEEE80211_AP_FRAME_MAX);
  check_uint64("cyw43438 owned rx frame capacity",
               ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_CAPACITY,
               ER_CYW43438_OWNED_FIRMWARE_RX_ERWIRE_HEADER_CAPACITY +
                   ER_CYW43438_OWNED_FIRMWARE_RX_VFS_PACKET_CAPACITY);
  check_uint64("cyw43438 owned rx frame follows tx frame",
               ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR +
                   ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_CAPACITY);
  check_uint64("cyw43438 owned tx status len shift",
               ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_LEN_SHIFT,
               8u);
  check_uint64("cyw43438 owned rx status len shift",
               ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_LEN_SHIFT,
               8u);
  check_uint64("cyw43438 owned tx status fc mask",
               ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_FRAME_CONTROL_MASK,
               0xffu);
  check_uint64("cyw43438 owned rx status fc mask",
               ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_FRAME_CONTROL_MASK,
               0xffu);
  check_uint64("cyw43438 owned rx probe command",
               ER_CYW43438_OWNED_FIRMWARE_COMMAND_RX_PROBE,
               3u);
  check_uint64("cyw43438 owned rx probe ack",
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_RX_PROBE_ACK,
               ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK |
                   ER_CYW43438_OWNED_FIRMWARE_COMMAND_RX_PROBE);
  check_uint64("cyw43438 owned over air rx unsupported",
               ER_CYW43438_OWNED_FIRMWARE_OVER_AIR_RX_SUPPORTED,
               0u);
  check_uint64("cyw43438 owned rx source host scratch",
               ER_CYW43438_OWNED_FIRMWARE_RX_SOURCE_HOST_SCRATCH,
               1u);
  test_owned_firmware_byte("cyw43438 owned ldr r0",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET,
                           0x0du);
  test_owned_firmware_byte("cyw43438 owned ldr r0 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 1u,
                           0x48u);
  test_owned_firmware_byte("cyw43438 owned ldr r1",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 2u,
                           0x0eu);
  test_owned_firmware_byte("cyw43438 owned ldr r1 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 3u,
                           0x49u);
  test_owned_firmware_byte("cyw43438 owned ldr r4",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 4u,
                           0x0eu);
  test_owned_firmware_byte("cyw43438 owned ldr r4 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 5u,
                           0x4cu);
  test_owned_firmware_byte("cyw43438 owned tx frame literal load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 20u,
                           0x0bu);
  test_owned_firmware_byte("cyw43438 owned tx frame literal load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 21u,
                           0x4eu);
  test_owned_firmware_byte("cyw43438 owned d11 tx frame store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 22u,
                           0x06u);
  test_owned_firmware_byte("cyw43438 owned d11 tx frame store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 23u,
                           0x62u);
  test_owned_firmware_byte("cyw43438 owned tx len load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 24u,
                           0x05u);
  test_owned_firmware_byte("cyw43438 owned tx len load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 25u,
                           0x69u);
  test_owned_firmware_byte("cyw43438 owned d11 tx len store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 26u,
                           0x45u);
  test_owned_firmware_byte("cyw43438 owned d11 tx len store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 27u,
                           0x62u);
  test_owned_firmware_byte("cyw43438 owned tx fc load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 28u,
                           0x37u);
  test_owned_firmware_byte("cyw43438 owned tx len shift",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 30u,
                           0x2du);
  test_owned_firmware_byte("cyw43438 owned tx status orr",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 32u,
                           0x3du);
  test_owned_firmware_byte("cyw43438 owned tx status store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 34u,
                           0x45u);
  test_owned_firmware_byte("cyw43438 owned d11 tx status store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 36u,
                           0x85u);
  test_owned_firmware_byte("cyw43438 owned rx frame literal load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 38u,
                           0x08u);
  test_owned_firmware_byte("cyw43438 owned rx frame literal load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 39u,
                           0x4eu);
  test_owned_firmware_byte("cyw43438 owned rx len load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 40u,
                           0x85u);
  test_owned_firmware_byte("cyw43438 owned rx status store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 48u,
                           0xc5u);
  test_owned_firmware_byte("cyw43438 owned ack orr",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 50u,
                           0x23u);
  test_owned_firmware_byte("cyw43438 owned response store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 52u,
                           0xc3u);
  test_owned_firmware_byte("cyw43438 owned loop",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 54u,
                           0xe9u);
  test_owned_firmware_byte("cyw43438 owned loop high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 55u,
                           0xe7u);
}

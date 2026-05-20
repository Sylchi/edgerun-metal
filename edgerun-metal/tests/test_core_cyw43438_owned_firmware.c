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
  check_uint64("cyw43438 owned mailbox magic literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC);
  test_owned_firmware_byte("cyw43438 owned ldr r0",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET,
                           0x05u);
  test_owned_firmware_byte("cyw43438 owned ldr r0 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 1u,
                           0x48u);
  test_owned_firmware_byte("cyw43438 owned ldr r1",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 2u,
                           0x06u);
  test_owned_firmware_byte("cyw43438 owned ldr r1 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 3u,
                           0x49u);
  test_owned_firmware_byte("cyw43438 owned store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 4u,
                           0x01u);
  test_owned_firmware_byte("cyw43438 owned store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 5u,
                           0x60u);
  test_owned_firmware_byte("cyw43438 owned movs r2",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 6u,
                           0x00u);
  test_owned_firmware_byte("cyw43438 owned movs r2 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 7u,
                           0x22u);
  test_owned_firmware_byte("cyw43438 owned adds r2",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 8u,
                           0x01u);
  test_owned_firmware_byte("cyw43438 owned adds r2 high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 9u,
                           0x32u);
  test_owned_firmware_byte("cyw43438 owned heartbeat store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 10u,
                           0x42u);
  test_owned_firmware_byte("cyw43438 owned heartbeat store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 11u,
                           0x60u);
  test_owned_firmware_byte("cyw43438 owned command load",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 12u,
                           0x83u);
  test_owned_firmware_byte("cyw43438 owned command load high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 13u,
                           0x68u);
  test_owned_firmware_byte("cyw43438 owned response store",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 14u,
                           0xc3u);
  test_owned_firmware_byte("cyw43438 owned response store high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 15u,
                           0x60u);
  test_owned_firmware_byte("cyw43438 owned loop",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 16u,
                           0xfau);
  test_owned_firmware_byte("cyw43438 owned loop high",
                           ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 17u,
                           0xe7u);
}

#include "test_core_internal.h"

static UINT32 test_owned_firmware_le32(UINT32 offset) {
  return ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset]) |
         ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset + 1u] << 8u) |
         ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset + 2u] << 16u) |
         ((UINT32)ER_CYW43438_OWNED_FIRMWARE[offset + 3u] << 24u);
}

static void test_cyw43438_owned_firmware_payload(void) {
  check_uint64("cyw43438 owned firmware size",
               (UINT64)sizeof(ER_CYW43438_OWNED_FIRMWARE),
               ER_CYW43438_OWNED_FIRMWARE_SIZE);
  check_uint64("cyw43438 owned reset vector",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR);
  check_uint64("cyw43438 owned mailbox address literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR);
  check_uint64("cyw43438 owned heartbeat address",
               ER_CYW43438_OWNED_FIRMWARE_HEARTBEAT_ADDR,
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR +
                   (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 owned mailbox magic literal",
               test_owned_firmware_le32(
                   ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC_OFFSET),
               ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC);
  check_uint64("cyw43438 owned ldr r0",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET],
               0x03u);
  check_uint64("cyw43438 owned ldr r0 high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 1u],
               0x48u);
  check_uint64("cyw43438 owned ldr r1",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 2u],
               0x04u);
  check_uint64("cyw43438 owned ldr r1 high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 3u],
               0x49u);
  check_uint64("cyw43438 owned store",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 4u],
               0x01u);
  check_uint64("cyw43438 owned store high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 5u],
               0x60u);
  check_uint64("cyw43438 owned movs r2",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 6u],
               0x00u);
  check_uint64("cyw43438 owned movs r2 high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 7u],
               0x22u);
  check_uint64("cyw43438 owned adds r2",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 8u],
               0x01u);
  check_uint64("cyw43438 owned adds r2 high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 9u],
               0x32u);
  check_uint64("cyw43438 owned heartbeat store",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 10u],
               0x42u);
  check_uint64("cyw43438 owned heartbeat store high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 11u],
               0x60u);
  check_uint64("cyw43438 owned loop",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 12u],
               0xfcu);
  check_uint64("cyw43438 owned loop high",
               (UINT64)ER_CYW43438_OWNED_FIRMWARE[
                   ER_CYW43438_OWNED_FIRMWARE_HANDLER_OFFSET + 13u],
               0xe7u);
}

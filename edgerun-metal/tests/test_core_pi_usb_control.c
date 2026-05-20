#include "test_core_internal.h"

static void test_pi_usb_control_requests(void) {
  ErPiUsbControlRequest request;
  ErPiUsbControlResponse response;

  check_uint64("pi usb control packet bytes",
               ER_PI_USB_CONTROL_PACKET_BYTES,
               64u);
  check_uint64("pi usb control block bytes",
               ER_PI_USB_CONTROL_BLOCK_BYTES,
               512u);
  check_uint64("pi usb control storage class",
               er_pi_usb_control_command_class(
                   ER_PI_USB_CONTROL_COMMAND_STORAGE_READ),
               ER_PI_USB_CONTROL_CLASS_STORAGE);
  check_uint64("pi usb control gpio class",
               er_pi_usb_control_command_class(
                   ER_PI_USB_CONTROL_COMMAND_GPIO_WRITE),
               ER_PI_USB_CONTROL_CLASS_GPIO);
  check_uint64("pi usb control wifi class",
               er_pi_usb_control_command_class(
                   ER_PI_USB_CONTROL_COMMAND_WIFI_STATUS),
               ER_PI_USB_CONTROL_CLASS_WIFI);
  check_uint64("pi usb control gpu class",
               er_pi_usb_control_command_class(
                   ER_PI_USB_CONTROL_COMMAND_GPU_FLUSH),
               ER_PI_USB_CONTROL_CLASS_GPU);
  check_uint64("pi usb control memory class",
               er_pi_usb_control_command_class(
                   ER_PI_USB_CONTROL_COMMAND_MEMORY_WRITE),
               ER_PI_USB_CONTROL_CLASS_MEMORY);
  check_uint64("pi usb control storage read supported",
               er_pi_usb_control_command_supported(
                   ER_PI_USB_CONTROL_COMMAND_STORAGE_READ),
               1u);
  check_uint64("pi usb control unsupported rejected",
               er_pi_usb_control_command_supported(0xffffffffu),
               0u);

  check_uint64("pi usb storage read request",
               er_pi_usb_control_make_request(
                   1u,
                   ER_PI_USB_CONTROL_COMMAND_STORAGE_READ,
                   ER_PI_USB_CONTROL_FLAG_READ |
                       ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED,
                   8u,
                   ER_PI_USB_CONTROL_BLOCK_BYTES,
                   0u,
                   &request),
               1u);
  check_uint64("pi usb storage request valid",
               er_pi_usb_control_request_valid(&request),
               1u);
  check_uint64("pi usb storage request magic",
               request.magic,
               ER_PI_USB_CONTROL_MAGIC);
  check_uint64("pi usb storage request address",
               request.address,
               8u);
  check_uint64("pi usb storage response",
               er_pi_usb_control_make_response(&request,
                                               ER_PI_USB_CONTROL_STATUS_OK,
                                               request.length,
                                               0u,
                                               &response),
               1u);
  check_uint64("pi usb storage response valid",
               er_pi_usb_control_response_valid(&response, &request),
               1u);

  check_uint64("pi usb rejects unaligned storage length",
               er_pi_usb_control_make_request(
                   2u,
                   ER_PI_USB_CONTROL_COMMAND_STORAGE_WRITE,
                   ER_PI_USB_CONTROL_FLAG_WRITE |
                       ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED,
                   0u,
                   ER_PI_USB_CONTROL_BLOCK_BYTES - 1u,
                   0u,
                   &request),
               0u);
  check_uint64("pi usb rejects zero sequence",
               er_pi_usb_control_make_request(
                   0u,
                   ER_PI_USB_CONTROL_COMMAND_GPIO_READ,
                   ER_PI_USB_CONTROL_FLAG_READ |
                       ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED,
                   47u,
                   (UINT32)sizeof(UINT32),
                   0u,
                   &request),
               0u);
  check_uint64("pi usb gpio write request",
               er_pi_usb_control_make_request(
                   3u,
                   ER_PI_USB_CONTROL_COMMAND_GPIO_WRITE,
                   ER_PI_USB_CONTROL_FLAG_WRITE |
                       ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED,
                   47u,
                   0u,
                   1u,
                   &request),
               1u);
  check_uint64("pi usb rejects read flag for write command",
               er_pi_usb_control_make_request(
                   4u,
                   ER_PI_USB_CONTROL_COMMAND_MEMORY_WRITE,
                   ER_PI_USB_CONTROL_FLAG_READ |
                       ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED,
                   0x8000u,
                   16u,
                   0u,
                   &request),
               0u);
}

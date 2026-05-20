#include "er_pi_usb_control.h"
#include "er_mem.h"

#define ER_PI_USB_CONTROL_CLASS_SHIFT 16u
#define ER_PI_USB_CONTROL_CLASS_MASK 0xffff0000u
#define ER_PI_USB_CONTROL_OP_MASK 0x0000ffffu

UINT32 er_pi_usb_control_command_class(UINT32 command) {
  return (command & ER_PI_USB_CONTROL_CLASS_MASK) >>
         ER_PI_USB_CONTROL_CLASS_SHIFT;
}

UINT8 er_pi_usb_control_command_supported(UINT32 command) {
  switch (command) {
    case ER_PI_USB_CONTROL_COMMAND_STORAGE_READ:
    case ER_PI_USB_CONTROL_COMMAND_STORAGE_WRITE:
    case ER_PI_USB_CONTROL_COMMAND_GPIO_READ:
    case ER_PI_USB_CONTROL_COMMAND_GPIO_WRITE:
    case ER_PI_USB_CONTROL_COMMAND_WIFI_STATUS:
    case ER_PI_USB_CONTROL_COMMAND_WIFI_TX_FRAME:
    case ER_PI_USB_CONTROL_COMMAND_GPU_FLUSH:
    case ER_PI_USB_CONTROL_COMMAND_MEMORY_READ:
    case ER_PI_USB_CONTROL_COMMAND_MEMORY_WRITE:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_pi_usb_control_flags_valid(UINT32 command, UINT32 flags) {
  switch (command) {
    case ER_PI_USB_CONTROL_COMMAND_STORAGE_READ:
    case ER_PI_USB_CONTROL_COMMAND_GPIO_READ:
    case ER_PI_USB_CONTROL_COMMAND_WIFI_STATUS:
    case ER_PI_USB_CONTROL_COMMAND_MEMORY_READ:
      return (UINT8)(flags == (ER_PI_USB_CONTROL_FLAG_READ |
                               ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED));
    case ER_PI_USB_CONTROL_COMMAND_STORAGE_WRITE:
    case ER_PI_USB_CONTROL_COMMAND_GPIO_WRITE:
    case ER_PI_USB_CONTROL_COMMAND_WIFI_TX_FRAME:
    case ER_PI_USB_CONTROL_COMMAND_GPU_FLUSH:
    case ER_PI_USB_CONTROL_COMMAND_MEMORY_WRITE:
      return (UINT8)(flags == (ER_PI_USB_CONTROL_FLAG_WRITE |
                               ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED));
    default:
      return 0u;
  }
}

static UINT8 er_pi_usb_control_length_valid(UINT32 command, UINT32 length) {
  switch (command) {
    case ER_PI_USB_CONTROL_COMMAND_STORAGE_READ:
    case ER_PI_USB_CONTROL_COMMAND_STORAGE_WRITE:
      return (UINT8)(length != 0u &&
                     length <= ER_PI_USB_CONTROL_MAX_TRANSFER_BYTES &&
                     (length % ER_PI_USB_CONTROL_BLOCK_BYTES) == 0u);
    case ER_PI_USB_CONTROL_COMMAND_GPIO_READ:
    case ER_PI_USB_CONTROL_COMMAND_WIFI_STATUS:
      return (UINT8)(length == (UINT32)sizeof(UINT32));
    case ER_PI_USB_CONTROL_COMMAND_GPIO_WRITE:
    case ER_PI_USB_CONTROL_COMMAND_GPU_FLUSH:
      return (UINT8)(length == 0u);
    case ER_PI_USB_CONTROL_COMMAND_WIFI_TX_FRAME:
    case ER_PI_USB_CONTROL_COMMAND_MEMORY_READ:
    case ER_PI_USB_CONTROL_COMMAND_MEMORY_WRITE:
      return (UINT8)(length != 0u &&
                     length <= ER_PI_USB_CONTROL_MAX_TRANSFER_BYTES);
    default:
      return 0u;
  }
}

UINT8 er_pi_usb_control_request_valid(const ErPiUsbControlRequest* request) {
  if (request == 0 ||
      request->magic != ER_PI_USB_CONTROL_MAGIC ||
      request->abi_version != ER_PI_USB_CONTROL_ABI_VERSION ||
      request->header_bytes != (UINT16)sizeof(*request) ||
      request->sequence == 0u ||
      er_pi_usb_control_command_supported(request->command) == 0u ||
      er_pi_usb_control_flags_valid(request->command, request->flags) == 0u ||
      er_pi_usb_control_length_valid(request->command, request->length) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_pi_usb_control_response_valid(const ErPiUsbControlResponse* response,
                                       const ErPiUsbControlRequest* request) {
  if (response == 0 ||
      request == 0 ||
      response->magic != ER_PI_USB_CONTROL_MAGIC ||
      response->abi_version != ER_PI_USB_CONTROL_ABI_VERSION ||
      response->header_bytes != (UINT16)sizeof(*response) ||
      response->sequence != request->sequence ||
      response->command != request->command) {
    return 0u;
  }
  switch (response->status) {
    case ER_PI_USB_CONTROL_STATUS_OK:
    case ER_PI_USB_CONTROL_STATUS_BAD_REQUEST:
    case ER_PI_USB_CONTROL_STATUS_UNSUPPORTED:
    case ER_PI_USB_CONTROL_STATUS_IO_ERROR:
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_pi_usb_control_make_request(UINT32 sequence,
                                     UINT32 command,
                                     UINT32 flags,
                                     UINT64 address,
                                     UINT32 length,
                                     UINT32 value,
                                     ErPiUsbControlRequest* out_request) {
  if (out_request != 0) {
    er_mem_zero((UINT8*)out_request, (UINTN)sizeof(*out_request));
  }
  if (out_request == 0) {
    return 0u;
  }
  out_request->magic = ER_PI_USB_CONTROL_MAGIC;
  out_request->abi_version = ER_PI_USB_CONTROL_ABI_VERSION;
  out_request->header_bytes = (UINT16)sizeof(*out_request);
  out_request->sequence = sequence;
  out_request->command = command;
  out_request->flags = flags;
  out_request->address = address;
  out_request->length = length;
  out_request->value = value;
  if (er_pi_usb_control_request_valid(out_request) == 0u) {
    er_mem_zero((UINT8*)out_request, (UINTN)sizeof(*out_request));
    return 0u;
  }
  return 1u;
}

UINT8 er_pi_usb_control_make_response(const ErPiUsbControlRequest* request,
                                      UINT32 status,
                                      UINT32 length,
                                      UINT32 value,
                                      ErPiUsbControlResponse* out_response) {
  if (out_response != 0) {
    er_mem_zero((UINT8*)out_response, (UINTN)sizeof(*out_response));
  }
  if (out_response == 0 || er_pi_usb_control_request_valid(request) == 0u) {
    return 0u;
  }
  out_response->magic = ER_PI_USB_CONTROL_MAGIC;
  out_response->abi_version = ER_PI_USB_CONTROL_ABI_VERSION;
  out_response->header_bytes = (UINT16)sizeof(*out_response);
  out_response->sequence = request->sequence;
  out_response->command = request->command;
  out_response->status = status;
  out_response->length = length;
  out_response->value = value;
  if (er_pi_usb_control_response_valid(out_response, request) == 0u) {
    er_mem_zero((UINT8*)out_response, (UINTN)sizeof(*out_response));
    return 0u;
  }
  return 1u;
}

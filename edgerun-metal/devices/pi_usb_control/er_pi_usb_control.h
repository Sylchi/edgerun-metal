#ifndef ER_PI_USB_CONTROL_H
#define ER_PI_USB_CONTROL_H

/*
 * Purpose: define the post-boot Raspberry Pi USB control plane.
 * Intention: expose storage, GPIO, Wi-Fi, GPU, and memory control through one
 * deterministic vendor protocol instead of separate ad hoc USB paths.
 */

#include "er_types.h"

#define ER_PI_USB_CONTROL_ABI_VERSION 1u
#define ER_PI_USB_CONTROL_MAGIC 0x55524345u
#define ER_PI_USB_CONTROL_VENDOR_ID 0x4552u
#define ER_PI_USB_CONTROL_PRODUCT_ID 0x5049u
#define ER_PI_USB_CONTROL_INTERFACE_CLASS_VENDOR 0xffu
#define ER_PI_USB_CONTROL_INTERFACE_SUBCLASS 0x45u
#define ER_PI_USB_CONTROL_INTERFACE_PROTOCOL 0x52u
#define ER_PI_USB_CONTROL_OUT_ENDPOINT 0x01u
#define ER_PI_USB_CONTROL_IN_ENDPOINT 0x81u
#define ER_PI_USB_CONTROL_INTERRUPT_ENDPOINT 0x82u
#define ER_PI_USB_CONTROL_BULK_ATTRIBUTES 0x02u
#define ER_PI_USB_CONTROL_INTERRUPT_ATTRIBUTES 0x03u
#define ER_PI_USB_CONTROL_PACKET_BYTES 64u
#define ER_PI_USB_CONTROL_BLOCK_BYTES 512u
#define ER_PI_USB_CONTROL_MAX_TRANSFER_BYTES 16384u

#define ER_PI_USB_CONTROL_FLAG_WRITE 0x00000001u
#define ER_PI_USB_CONTROL_FLAG_READ 0x00000002u
#define ER_PI_USB_CONTROL_FLAG_RESPONSE_REQUIRED 0x00000004u

#define ER_PI_USB_CONTROL_STATUS_OK 0u
#define ER_PI_USB_CONTROL_STATUS_BAD_REQUEST 1u
#define ER_PI_USB_CONTROL_STATUS_UNSUPPORTED 2u
#define ER_PI_USB_CONTROL_STATUS_IO_ERROR 3u

typedef enum {
  ER_PI_USB_CONTROL_COMMAND_STORAGE_READ = 0x00010001u,
  ER_PI_USB_CONTROL_COMMAND_STORAGE_WRITE = 0x00010002u,
  ER_PI_USB_CONTROL_COMMAND_GPIO_READ = 0x00020001u,
  ER_PI_USB_CONTROL_COMMAND_GPIO_WRITE = 0x00020002u,
  ER_PI_USB_CONTROL_COMMAND_WIFI_STATUS = 0x00030001u,
  ER_PI_USB_CONTROL_COMMAND_WIFI_TX_FRAME = 0x00030002u,
  ER_PI_USB_CONTROL_COMMAND_GPU_FLUSH = 0x00040001u,
  ER_PI_USB_CONTROL_COMMAND_MEMORY_READ = 0x00050001u,
  ER_PI_USB_CONTROL_COMMAND_MEMORY_WRITE = 0x00050002u
} ErPiUsbControlCommand;

typedef enum {
  ER_PI_USB_CONTROL_CLASS_STORAGE = 1u,
  ER_PI_USB_CONTROL_CLASS_GPIO = 2u,
  ER_PI_USB_CONTROL_CLASS_WIFI = 3u,
  ER_PI_USB_CONTROL_CLASS_GPU = 4u,
  ER_PI_USB_CONTROL_CLASS_MEMORY = 5u
} ErPiUsbControlClass;

typedef struct {
  UINT32 magic;
  UINT16 abi_version;
  UINT16 header_bytes;
  UINT32 sequence;
  UINT32 command;
  UINT32 flags;
  UINT64 address;
  UINT32 length;
  UINT32 value;
} ErPiUsbControlRequest;

typedef struct {
  UINT32 magic;
  UINT16 abi_version;
  UINT16 header_bytes;
  UINT32 sequence;
  UINT32 command;
  UINT32 status;
  UINT32 length;
  UINT32 value;
} ErPiUsbControlResponse;

UINT8 er_pi_usb_control_command_supported(UINT32 command);
UINT32 er_pi_usb_control_command_class(UINT32 command);
UINT8 er_pi_usb_control_request_valid(const ErPiUsbControlRequest* request);
UINT8 er_pi_usb_control_response_valid(const ErPiUsbControlResponse* response,
                                       const ErPiUsbControlRequest* request);
UINT8 er_pi_usb_control_make_request(UINT32 sequence,
                                     UINT32 command,
                                     UINT32 flags,
                                     UINT64 address,
                                     UINT32 length,
                                     UINT32 value,
                                     ErPiUsbControlRequest* out_request);
UINT8 er_pi_usb_control_make_response(const ErPiUsbControlRequest* request,
                                      UINT32 status,
                                      UINT32 length,
                                      UINT32 value,
                                      ErPiUsbControlResponse* out_response);

#endif

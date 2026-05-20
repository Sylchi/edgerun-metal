#ifndef ER_BCM2708_USB_BOOT_H
#define ER_BCM2708_USB_BOOT_H

/*
 * Purpose: model the Raspberry Pi BCM2708 USB boot ROM transport.
 * Intention: keep boot-device discovery and bulk-transfer planning freestanding,
 * so Linux USB helpers remain disposable bring-up aids rather than architecture.
 */

#include "er_types.h"

#define ER_BCM2708_USB_BOOT_ABI_VERSION 1u
#define ER_BCM2708_USB_BOOT_VENDOR_ID 0x0a5cu
#define ER_BCM2708_USB_BOOT_PRODUCT_ID 0x2763u
#define ER_BCM2708_USB_BOOT_INTERFACE_CLASS_VENDOR 0xffu
#define ER_BCM2708_USB_BOOT_INTERFACE_SUBCLASS 0u
#define ER_BCM2708_USB_BOOT_INTERFACE_PROTOCOL 0u
#define ER_BCM2708_USB_BOOT_OUT_ENDPOINT 0x01u
#define ER_BCM2708_USB_BOOT_IN_ENDPOINT 0x82u
#define ER_BCM2708_USB_BOOT_BULK_ATTRIBUTES 0x02u
#define ER_BCM2708_USB_BOOT_PACKET_BYTES 64u

typedef struct {
  UINT16 abi_version;
  UINT16 vendor_id;
  UINT16 product_id;
  UINT8 interface_number;
  UINT8 out_endpoint;
  UINT8 in_endpoint;
  UINT8 packet_bytes;
} ErBcm2708UsbBootTransport;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  UINT32 payload_bytes;
  UINT32 packet_count;
  UINT32 full_packet_count;
  UINT8 final_packet_bytes;
  UINT8 packet_bytes;
  UINT8 reserved1[2];
} ErBcm2708UsbBootPayloadPlan;

UINT8 er_bcm2708_usb_boot_device_id_supported(UINT16 vendor_id,
                                              UINT16 product_id);
UINT8 er_bcm2708_usb_boot_parse_configuration(
    const UINT8* descriptor,
    UINT32 descriptor_len,
    ErBcm2708UsbBootTransport* out_transport);
UINT8 er_bcm2708_usb_boot_payload_plan(UINT32 payload_bytes,
                                       ErBcm2708UsbBootPayloadPlan* out_plan);

#endif

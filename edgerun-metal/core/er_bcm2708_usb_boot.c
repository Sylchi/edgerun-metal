#include "er_bcm2708_usb_boot.h"
#include "er_mem.h"

enum {
  ER_USB_DESCRIPTOR_LEN_OFFSET = 0u,
  ER_USB_DESCRIPTOR_TYPE_OFFSET = 1u,
  ER_USB_DESCRIPTOR_HEADER_BYTES = 2u,
  ER_USB_DESCRIPTOR_TYPE_INTERFACE = 4u,
  ER_USB_DESCRIPTOR_TYPE_ENDPOINT = 5u,
  ER_USB_INTERFACE_NUMBER_OFFSET = 2u,
  ER_USB_INTERFACE_CLASS_OFFSET = 5u,
  ER_USB_INTERFACE_SUBCLASS_OFFSET = 6u,
  ER_USB_INTERFACE_PROTOCOL_OFFSET = 7u,
  ER_USB_ENDPOINT_ADDRESS_OFFSET = 2u,
  ER_USB_ENDPOINT_ATTRIBUTES_OFFSET = 3u,
  ER_USB_ENDPOINT_PACKET_LOW_OFFSET = 4u,
  ER_USB_ENDPOINT_PACKET_HIGH_OFFSET = 5u,
  ER_USB_INTERFACE_DESCRIPTOR_BYTES = 9u,
  ER_USB_ENDPOINT_DESCRIPTOR_BYTES = 7u,
  ER_USB_ENDPOINT_DIRECTION_IN = 0x80u,
  ER_USB_ENDPOINT_NUMBER_MASK = 0x0fu,
  ER_USB_ENDPOINT_PACKET_SHIFT = 8u,
  ER_USB_UINT8_MAX = 0xffu
};

typedef struct {
  UINT8 found;
  UINT8 complete;
  UINT8 interface_number;
  UINT8 out_endpoint;
  UINT8 in_endpoint;
  UINT8 out_packet_bytes;
  UINT8 in_packet_bytes;
} ErBcm2708UsbBootParseState;

UINT8 er_bcm2708_usb_boot_device_id_supported(UINT16 vendor_id,
                                              UINT16 product_id) {
  return (UINT8)(vendor_id == ER_BCM2708_USB_BOOT_VENDOR_ID &&
                 product_id == ER_BCM2708_USB_BOOT_PRODUCT_ID);
}

static UINT8 er_bcm2708_usb_boot_endpoint_packet_bytes(
    const UINT8* descriptor) {
  UINT16 packet_bytes;

  packet_bytes =
      (UINT16)((UINT16)descriptor[ER_USB_ENDPOINT_PACKET_LOW_OFFSET] |
               ((UINT16)descriptor[ER_USB_ENDPOINT_PACKET_HIGH_OFFSET] <<
                ER_USB_ENDPOINT_PACKET_SHIFT));
  if (packet_bytes > ER_USB_UINT8_MAX) {
    return 0u;
  }
  return (UINT8)packet_bytes;
}

static UINT8 er_bcm2708_usb_boot_endpoint_matches(UINT8 actual,
                                                  UINT8 expected) {
  return (UINT8)(actual == expected &&
                 (actual & ER_USB_ENDPOINT_NUMBER_MASK) != 0u);
}

static void er_bcm2708_usb_boot_scan_interface(
    const UINT8* descriptor,
    ErBcm2708UsbBootParseState* state) {
  if (descriptor[ER_USB_DESCRIPTOR_LEN_OFFSET] < ER_USB_INTERFACE_DESCRIPTOR_BYTES) {
    if (state->complete == 0u) {
      state->found = 0u;
    }
    return;
  }
  if (state->complete != 0u) {
    return;
  }
  if (descriptor[ER_USB_INTERFACE_CLASS_OFFSET] ==
          ER_BCM2708_USB_BOOT_INTERFACE_CLASS_VENDOR &&
      descriptor[ER_USB_INTERFACE_SUBCLASS_OFFSET] ==
          ER_BCM2708_USB_BOOT_INTERFACE_SUBCLASS &&
      descriptor[ER_USB_INTERFACE_PROTOCOL_OFFSET] ==
          ER_BCM2708_USB_BOOT_INTERFACE_PROTOCOL) {
    er_mem_zero((UINT8*)state, (UINTN)sizeof(*state));
    state->found = 1u;
    state->interface_number = descriptor[ER_USB_INTERFACE_NUMBER_OFFSET];
    return;
  }
  if (state->out_endpoint == 0u && state->in_endpoint == 0u) {
    state->found = 0u;
  }
}

static void er_bcm2708_usb_boot_scan_endpoint(
    const UINT8* descriptor,
    ErBcm2708UsbBootParseState* state) {
  UINT8 endpoint_address;
  UINT8 packet_bytes;

  if (state->found == 0u ||
      descriptor[ER_USB_DESCRIPTOR_LEN_OFFSET] < ER_USB_ENDPOINT_DESCRIPTOR_BYTES ||
      descriptor[ER_USB_ENDPOINT_ATTRIBUTES_OFFSET] !=
          ER_BCM2708_USB_BOOT_BULK_ATTRIBUTES) {
    return;
  }
  endpoint_address = descriptor[ER_USB_ENDPOINT_ADDRESS_OFFSET];
  packet_bytes = er_bcm2708_usb_boot_endpoint_packet_bytes(descriptor);
  if (packet_bytes != ER_BCM2708_USB_BOOT_PACKET_BYTES) {
    return;
  }
  if (er_bcm2708_usb_boot_endpoint_matches(
          endpoint_address,
          ER_BCM2708_USB_BOOT_OUT_ENDPOINT) != 0u &&
      (endpoint_address & ER_USB_ENDPOINT_DIRECTION_IN) == 0u) {
    state->out_endpoint = endpoint_address;
    state->out_packet_bytes = packet_bytes;
    if (state->in_endpoint == ER_BCM2708_USB_BOOT_IN_ENDPOINT) {
      state->complete = 1u;
    }
    return;
  }
  if (er_bcm2708_usb_boot_endpoint_matches(
          endpoint_address,
          ER_BCM2708_USB_BOOT_IN_ENDPOINT) != 0u &&
      (endpoint_address & ER_USB_ENDPOINT_DIRECTION_IN) != 0u) {
    state->in_endpoint = endpoint_address;
    state->in_packet_bytes = packet_bytes;
    if (state->out_endpoint == ER_BCM2708_USB_BOOT_OUT_ENDPOINT) {
      state->complete = 1u;
    }
  }
}

UINT8 er_bcm2708_usb_boot_parse_configuration(
    const UINT8* descriptor,
    UINT32 descriptor_len,
    ErBcm2708UsbBootTransport* out_transport) {
  ErBcm2708UsbBootParseState state;
  UINT32 offset = 0u;
  UINT8 descriptor_bytes;
  UINT8 descriptor_type;

  if (out_transport != 0) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
  }
  if (descriptor == 0 || descriptor_len == 0u || out_transport == 0) {
    return 0u;
  }

  er_mem_zero((UINT8*)&state, (UINTN)sizeof(state));
  while (offset + ER_USB_DESCRIPTOR_HEADER_BYTES <= descriptor_len) {
    descriptor_bytes = descriptor[offset + ER_USB_DESCRIPTOR_LEN_OFFSET];
    descriptor_type = descriptor[offset + ER_USB_DESCRIPTOR_TYPE_OFFSET];
    if (descriptor_bytes == 0u ||
        offset + descriptor_bytes > descriptor_len) {
      return 0u;
    }
    switch (descriptor_type) {
      case ER_USB_DESCRIPTOR_TYPE_INTERFACE:
        er_bcm2708_usb_boot_scan_interface(descriptor + offset, &state);
        break;
      case ER_USB_DESCRIPTOR_TYPE_ENDPOINT:
        er_bcm2708_usb_boot_scan_endpoint(descriptor + offset, &state);
        break;
      default:
        break;
    }
    offset += descriptor_bytes;
  }

  if (state.found == 0u ||
      state.out_endpoint != ER_BCM2708_USB_BOOT_OUT_ENDPOINT ||
      state.in_endpoint != ER_BCM2708_USB_BOOT_IN_ENDPOINT ||
      state.out_packet_bytes != ER_BCM2708_USB_BOOT_PACKET_BYTES ||
      state.in_packet_bytes != ER_BCM2708_USB_BOOT_PACKET_BYTES) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
    return 0u;
  }
  out_transport->abi_version = ER_BCM2708_USB_BOOT_ABI_VERSION;
  out_transport->vendor_id = ER_BCM2708_USB_BOOT_VENDOR_ID;
  out_transport->product_id = ER_BCM2708_USB_BOOT_PRODUCT_ID;
  out_transport->interface_number = state.interface_number;
  out_transport->out_endpoint = state.out_endpoint;
  out_transport->in_endpoint = state.in_endpoint;
  out_transport->packet_bytes = ER_BCM2708_USB_BOOT_PACKET_BYTES;
  return 1u;
}

UINT8 er_bcm2708_usb_boot_payload_plan(UINT32 payload_bytes,
                                       ErBcm2708UsbBootPayloadPlan* out_plan) {
  UINT32 full_packet_count;
  UINT32 final_packet_bytes;
  UINT32 packet_count;

  if (out_plan != 0) {
    er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
  }
  if (payload_bytes == 0u || out_plan == 0) {
    return 0u;
  }
  full_packet_count = payload_bytes / ER_BCM2708_USB_BOOT_PACKET_BYTES;
  final_packet_bytes = payload_bytes -
                       (full_packet_count * ER_BCM2708_USB_BOOT_PACKET_BYTES);
  packet_count = full_packet_count;
  if (final_packet_bytes != 0u) {
    packet_count += 1u;
  }

  out_plan->abi_version = ER_BCM2708_USB_BOOT_ABI_VERSION;
  out_plan->payload_bytes = payload_bytes;
  out_plan->packet_count = packet_count;
  out_plan->full_packet_count = full_packet_count;
  out_plan->final_packet_bytes = (UINT8)final_packet_bytes;
  out_plan->packet_bytes = ER_BCM2708_USB_BOOT_PACKET_BYTES;
  return 1u;
}

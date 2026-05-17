#ifndef ER_HW_RELAY_H
#define ER_HW_RELAY_H

/*
 * Purpose: bind relay records to hardware-backed channel endpoints.
 * Intention: keep the bare metal executor concrete: move packets between addresses.
 */

#include "er_work.h"

#define ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN 6u
#define ER_HW_RELAY_FIRMWARE_UDP_PORT 9000u

UINT8 er_hw_relay_prepare_firmware_udp_endpoint(UINT8 a, UINT8 b, UINT8 c, UINT8 d, UINT16 port,
                                                const char* label, UINTN label_len,
                                                ErChannelEndpoint* out_endpoint);
UINT8 er_hw_relay_default_firmware_udp_endpoint(ErChannelEndpoint* out_endpoint);
UINT8 er_hw_relay_endpoint_is_firmware_udp(const ErChannelEndpoint* endpoint);
UINT8 er_hw_relay_forward_to_firmware_udp(const ErRelayForwardIntent* intent, const UINT8* packet, UINTN packet_len);

#endif

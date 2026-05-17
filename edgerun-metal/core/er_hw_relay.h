#ifndef ER_HW_RELAY_H
#define ER_HW_RELAY_H

/*
 * Purpose: bind relay records to hardware-backed channel endpoints.
 * Intention: keep the bare metal executor concrete: move packets between addresses.
 */

#include "er_work.h"
#include "er_native_eth.h"

#define ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN 6u
#define ER_HW_RELAY_FIRMWARE_UDP_PORT 9000u
#define ER_HW_RELAY_NATIVE_ETH_ADDR_LEN ER_NET_MAC_LEN
#define ER_HW_RELAY_VIRTIO_ADDR_LEN 8u

typedef struct {
  ErChannelEndpoint storage;
  ErChannelEndpoint display;
  UINT8 storage_ready;
  UINT8 display_ready;
} ErHwRelayVirtioRoutes;

UINT8 er_hw_relay_prepare_firmware_udp_endpoint(UINT8 a, UINT8 b, UINT8 c, UINT8 d, UINT16 port,
                                                const char* label, UINTN label_len,
                                                ErChannelEndpoint* out_endpoint);
UINT8 er_hw_relay_default_firmware_udp_endpoint(ErChannelEndpoint* out_endpoint);
UINT8 er_hw_relay_endpoint_is_firmware_udp(const ErChannelEndpoint* endpoint);
UINT8 er_hw_relay_forward_to_firmware_udp(const ErRelayForwardIntent* intent, const UINT8* packet, UINTN packet_len);
UINT8 er_hw_relay_prepare_native_eth_endpoint(const UINT8* mac,
                                              const char* label, UINTN label_len,
                                              ErChannelEndpoint* out_endpoint);
UINT8 er_hw_relay_endpoint_is_native_eth(const ErChannelEndpoint* endpoint);
UINT8 er_hw_relay_forward_to_native_eth(ErNativeEth* native_eth,
                                        const ErRelayForwardIntent* intent,
                                        const UINT8* packet, UINTN packet_len);
UINT8 er_hw_relay_prepare_virtio_endpoint(UINT32 device_type, UINT16 queue,
                                          const char* label, UINTN label_len,
                                          ErChannelEndpoint* out_endpoint);
UINT8 er_hw_relay_endpoint_is_virtio(const ErChannelEndpoint* endpoint);
UINT8 er_hw_relay_prepare_default_virtio_routes(ErHwRelayVirtioRoutes* out_routes);
UINT8 er_hw_relay_route_erwire_to_virtio(const ErChannelEndpoint* ingress,
                                         UINT16 erwire_kind,
                                         const UINT8* payload, UINT32 payload_len,
                                         const ErHwRelayVirtioRoutes* routes,
                                         ErRelayForwardIntent* out_intent);

#endif

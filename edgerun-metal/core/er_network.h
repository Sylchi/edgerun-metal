#ifndef ER_NETWORK_H
#define ER_NETWORK_H

/*
 * Purpose: define EdgeRun's public local-network coordinator API.
 * Intention: keep carrier selection separate from work authority and reuse erwire.
 */

#include "er_hw_relay.h"
#include "er_wifi_burst.h"
#include "erwire.h"

#define ER_NETWORK_ABI_VERSION 1u
#define ER_NETWORK_MAX_LOCATORS 4u
#define ER_NETWORK_LOCATOR_NATIVE_ETH_LEN ER_HW_RELAY_NATIVE_ETH_ADDR_LEN
#define ER_NETWORK_LOCATOR_FIRMWARE_UDP_LEN ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN
#define ER_NETWORK_LOCATOR_WIFI_OPEN_HEADER_LEN 6u
#define ER_NETWORK_LOCATOR_WIFI_OPEN_SSID_MAX 32u

typedef enum {
  ER_NETWORK_LOCATOR_KIND_NONE = 0,
  ER_NETWORK_LOCATOR_KIND_NATIVE_ETH = 1,
  ER_NETWORK_LOCATOR_KIND_WIFI_OPEN = 2,
  ER_NETWORK_LOCATOR_KIND_FIRMWARE_UDP = 3,
  ER_NETWORK_LOCATOR_KIND_MEMORY = 4
} ErNetworkLocatorKind;

typedef enum {
  ER_NETWORK_DIRECTNESS_NONE = 0,
  ER_NETWORK_DIRECTNESS_DIRECT = 1,
  ER_NETWORK_DIRECTNESS_RELAYED = 2,
  ER_NETWORK_DIRECTNESS_BRIDGE_REQUIRED = 3,
  ER_NETWORK_DIRECTNESS_STORE_FORWARD = 4
} ErNetworkDirectness;

typedef struct {
  UINT16 abi_version;
  UINT8 kind;
  UINT8 directness;
  UINT16 priority;
  UINT64 valid_until_ms;
  UINT32 cost_per_packet;
  UINT32 cost_per_byte;
  UINT8 address_len;
  UINT8 address[ER_CHANNEL_ADDRESS_MAX];
} ErNetworkLocator;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNodeId node_id;
  UINT8 locator_count;
  ErNetworkLocator locators[ER_NETWORK_MAX_LOCATORS];
} ErNetworkPeer;

typedef struct {
  UINT16 abi_version;
  UINT8 peer_index;
  UINT8 locator_index;
  ErNodeId target_node_id;
  ErNodeId next_hop_node_id;
  ErNetworkLocator selected_locator;
} ErNetworkRoute;

typedef UINT8 (*ErNetworkWifiOpenSendFn)(void* ctx,
                                         const ErNetworkLocator* locator,
                                         const UINT8* packet,
                                         UINT32 packet_len);
typedef UINT8 (*ErNetworkWifiOpenRecvFn)(void* ctx,
                                         ErNetworkLocator* out_locator,
                                         UINT8* out_packet,
                                         UINT32 out_capacity,
                                         UINT32* out_packet_len);

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  void* ctx;
  ErNetworkWifiOpenSendFn send;
  ErNetworkWifiOpenRecvFn recv;
} ErNetworkWifiOpenCarrier;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNativeEth* native_eth;
  ErChannelEndpoint* firmware_udp;
  ErNetworkWifiOpenCarrier* wifi_open;
} ErNetworkIo;

UINT8 er_network_locator_prepare_native_eth(const UINT8 mac[ER_NET_MAC_LEN],
                                            UINT16 priority,
                                            UINT64 valid_until_ms,
                                            ErNetworkLocator* out_locator);
UINT8 er_network_locator_prepare_wifi_open(UINT32 group_id,
                                           UINT8 channel,
                                           const UINT8* ssid,
                                           UINT8 ssid_len,
                                           UINT16 priority,
                                           UINT64 valid_until_ms,
                                           ErNetworkLocator* out_locator);
UINT8 er_network_locator_prepare_firmware_udp(UINT8 a,
                                              UINT8 b,
                                              UINT8 c,
                                              UINT8 d,
                                              UINT16 port,
                                              UINT16 priority,
                                              UINT64 valid_until_ms,
                                              ErNetworkLocator* out_locator);
UINT8 er_network_locator_prepare_memory(UINT16 priority,
                                        UINT64 valid_until_ms,
                                        ErNetworkLocator* out_locator);
UINT8 er_network_locator_from_wifi_burst(const ErWifiBurstPlan* plan,
                                         UINT16 priority,
                                         UINT64 valid_until_ms,
                                         ErNetworkLocator* out_locator);
UINT8 er_network_locator_valid(const ErNetworkLocator* locator,
                               UINT64 now_ms);
UINT8 er_network_peer_prepare(const ErNodeId* node_id,
                              const ErNetworkLocator* locators,
                              UINT8 locator_count,
                              ErNetworkPeer* out_peer);
UINT8 er_network_peer_add_locator(ErNetworkPeer* peer,
                                  const ErNetworkLocator* locator);
UINT8 er_network_route_select(const ErNetworkPeer* peers,
                              UINT8 peer_count,
                              const ErNodeId* target_node_id,
                              UINT64 now_ms,
                              ErNetworkRoute* out_route);
UINT8 er_network_erwire_kind_requires_admission(UINT16 kind);
UINT8 er_network_send_erwire(ErNetworkIo* io,
                             const ErNetworkRoute* route,
                             const ErAdmittedRoute* admitted_route,
                             UINT16 kind,
                             UINT16 flags,
                             const UINT8* payload,
                             UINT32 payload_len);
UINT8 er_network_poll_erwire(ErNetworkIo* io,
                             const ErNetworkPeer* peers,
                             UINT8 peer_count,
                             UINT64 now_ms,
                             ErNetworkRoute* out_route,
                             ErwirePacketHeader* out_header,
                             UINT8* out_payload,
                             UINT32 out_capacity,
                             UINT32* out_payload_len);

#endif

#include "test_core_internal.h"

static void test_network_coordinator(void) {
  enum {
    NET_TEST_MMIO_DWORDS = 128u,
    NET_TEST_VIRTIO_HDR_LEN = 12u,
    NET_TEST_TX_DESC = 0u,
    NET_TEST_RX_DESC = 3u,
    NET_TEST_NOW_MS = 1000u,
    NET_TEST_VALID_MS = 2000u,
    NET_TEST_LATE_VALID_MS = 3000u,
    NET_TEST_PRIORITY_LOW = 1u,
    NET_TEST_PRIORITY_HIGH = 9u,
    NET_TEST_GROUP_ID = 0x11223344u,
    NET_TEST_WIFI_CHANNEL = 6u,
    NET_TEST_PAYLOAD_LEN = 2u,
    NET_TEST_PAYLOAD_OFFSET = NET_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN,
    NET_TEST_PACKET_LEN = ERWIRE_HEADER_SIZE + NET_TEST_PAYLOAD_LEN,
    NET_TEST_NODE_SSID_INDEX0 = 0u,
    NET_TEST_NODE_SSID_INDEX1 = 1u,
    NET_TEST_NODE_SSID_INDEX2 = 2u,
    NET_TEST_NODE_SSID_INDEX3 = 3u,
    NET_TEST_NODE_SSID_INDEX4 = 4u,
    NET_TEST_NODE_SSID_INDEX18 = 18u
  };
  UINT32 regs[NET_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErNetworkIo io;
  ErNetworkLocator native_locator;
  ErNetworkLocator weaker_native_locator;
  ErNetworkLocator wifi_locator;
  ErNetworkLocator burst_locator;
  ErNetworkLocator udp_locator;
  ErNetworkLocator memory_locator;
  ErNetworkPeer peer;
  ErNetworkPeer full_peer;
  ErNetworkPeer other_peer;
  ErNetworkPeer peers[2];
  ErNetworkRoute route;
  ErNetworkRoute wifi_route;
  ErwirePacketHeader header;
  ErVirtioQueueAvail* tx_avail;
  ErVirtioQueueUsed* rx_used;
  UINT8* tx_frame;
  UINT8* rx_buffer;
  UINT8 payload[NET_TEST_PAYLOAD_LEN] = {'n', 'w'};
  UINT8 out_payload[ERWIRE_MAX_PAYLOAD] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x51u, 0x52u, 0x53u, 0x54u, 0x55u};
  UINT8 other_mac[ER_NET_MAC_LEN] = {0x02u, 0x61u, 0x62u, 0x63u, 0x64u, 0x65u};
  UINT8 ssid[ER_WIFI_BURST_SSID_BYTES] = {'E', 'R', 'W', 'I', 'F', 'I'};
  ErNodeId target_node;
  ErNodeId other_node;
  ErWifiBurstPlan burst;
  ErWifiL2ApPlan wifi_l2_plan;
  ErWifiL2ApPlan rejected_wifi_l2_plan;
  ErAdmittedRoute admitted_route;
  ErChannelEndpoint firmware_endpoint;
  UINT32 frame_len = 0u;
  UINT32 out_payload_len = 0u;

  test_fill_bytes(target_node.bytes, ER_NODE_ID_LEN, 0x31u);
  test_fill_bytes(other_node.bytes, ER_NODE_ID_LEN, 0x41u);
  check_int64("network wifi l2 ap plan",
              er_wifi_l2_ap_plan_prepare(&target_node,
                                         NET_TEST_WIFI_CHANNEL,
                                         &wifi_l2_plan),
              1);
  check_int64("network wifi l2 ap plan valid",
              er_wifi_l2_ap_plan_valid(&wifi_l2_plan),
              1);
  check_uint64("network wifi l2 eth type",
               wifi_l2_plan.eth_type,
               ER_NET_ETH_TYPE_EDGERUN);
  check_uint64("network wifi l2 ssid len",
               wifi_l2_plan.ssid_len,
               ER_WIFI_L2_NODE_SSID_LEN);
  check_uint64("network wifi l2 ssid e",
               wifi_l2_plan.ssid[NET_TEST_NODE_SSID_INDEX0],
               'e');
  check_uint64("network wifi l2 ssid r",
               wifi_l2_plan.ssid[NET_TEST_NODE_SSID_INDEX1],
               'r');
  check_uint64("network wifi l2 ssid dash",
               wifi_l2_plan.ssid[NET_TEST_NODE_SSID_INDEX2],
               '-');
  check_uint64("network wifi l2 ssid first high",
               wifi_l2_plan.ssid[NET_TEST_NODE_SSID_INDEX3],
               '3');
  check_uint64("network wifi l2 ssid first low",
               wifi_l2_plan.ssid[NET_TEST_NODE_SSID_INDEX4],
               '1');
  check_uint64("network wifi l2 ssid last",
               wifi_l2_plan.ssid[NET_TEST_NODE_SSID_INDEX18],
               '8');
  check_uint64("network wifi l2 mac local",
               wifi_l2_plan.mac[0] & 0x02u,
               0x02u);
  check_uint64("network wifi l2 mac unicast",
               wifi_l2_plan.mac[0] & 0x01u,
               0u);
  check_int64("network wifi l2 reject missing node",
              er_wifi_l2_ap_plan_prepare(0,
                                         NET_TEST_WIFI_CHANNEL,
                                         &rejected_wifi_l2_plan),
              0);
  check_int64("network native locator",
              er_network_locator_prepare_native_eth(peer_mac, NET_TEST_PRIORITY_HIGH,
                                                    NET_TEST_VALID_MS, &native_locator),
              1);
  check_uint64("network native kind", native_locator.kind, ER_NETWORK_LOCATOR_KIND_NATIVE_ETH);
  check_uint64("network native len", native_locator.address_len, ER_NET_MAC_LEN);
  check_uint64("network native mac0", native_locator.address[0], peer_mac[0]);
  check_int64("network native valid",
              er_network_locator_valid(&native_locator, NET_TEST_NOW_MS), 1);
  check_int64("network native expired",
              er_network_locator_valid(&native_locator, NET_TEST_VALID_MS), 0);
  native_locator.abi_version = 0u;
  check_int64("network native bad abi",
              er_network_locator_valid(&native_locator, NET_TEST_NOW_MS), 0);
  native_locator.abi_version = ER_NETWORK_ABI_VERSION;

  check_int64("network wifi locator",
              er_network_locator_prepare_wifi_open(NET_TEST_GROUP_ID,
                                                   NET_TEST_WIFI_CHANNEL,
                                                   wifi_l2_plan.ssid,
                                                   wifi_l2_plan.ssid_len,
                                                   NET_TEST_PRIORITY_LOW,
                                                   NET_TEST_VALID_MS,
                                                   &wifi_locator),
              1);
  check_uint64("network wifi len", wifi_locator.address_len,
               ER_NETWORK_LOCATOR_WIFI_OPEN_HEADER_LEN +
                   ER_WIFI_L2_NODE_SSID_LEN);
  check_uint64("network wifi group byte0", wifi_locator.address[0], 0x44u);
  check_uint64("network wifi channel", wifi_locator.address[4], NET_TEST_WIFI_CHANNEL);
  check_int64("network wifi reject bad group",
              er_network_locator_prepare_wifi_open(ER_BLE_WIFI_GROUP_ID_INVALID,
                                                   NET_TEST_WIFI_CHANNEL,
                                                   ssid, 6u,
                                                   NET_TEST_PRIORITY_HIGH,
                                                   NET_TEST_VALID_MS,
                                                   &wifi_locator),
              0);

  burst.open = 1u;
  burst.wifi_channel = NET_TEST_WIFI_CHANNEL;
  burst.group_id = NET_TEST_GROUP_ID;
  burst.session_id = 7u;
  burst.local_role = ER_BLE_WIFI_ROLE_AP;
  burst.ssid_len = 6u;
  er_mem_copy(burst.ssid, ssid, 6u);
  check_int64("network burst locator",
              er_network_locator_from_wifi_burst(&burst, NET_TEST_PRIORITY_HIGH,
                                                 NET_TEST_VALID_MS, &burst_locator),
              1);
  burst.open = 0u;
  check_int64("network burst closed rejected",
              er_network_locator_from_wifi_burst(&burst, NET_TEST_PRIORITY_HIGH,
                                                 NET_TEST_VALID_MS, &burst_locator),
              0);

  check_int64("network udp locator",
              er_network_locator_prepare_firmware_udp(10u, 42u, 0u, 1u,
                                                      ER_HW_RELAY_FIRMWARE_UDP_PORT,
                                                      NET_TEST_PRIORITY_LOW,
                                                      NET_TEST_VALID_MS,
                                                      &udp_locator),
              1);
  check_uint64("network udp port hi", udp_locator.address[4], 0x23u);
  check_uint64("network udp port lo", udp_locator.address[5], 0x28u);
  check_int64("network memory locator",
              er_network_locator_prepare_memory(NET_TEST_PRIORITY_LOW,
                                                NET_TEST_VALID_MS, &memory_locator),
              1);
  check_uint64("network memory len", memory_locator.address_len, 0u);

  check_int64("network peer prepare",
              er_network_peer_prepare(&target_node, &native_locator, 1u, &peer), 1);
  check_uint64("network peer locator count", peer.locator_count, 1u);
  check_int64("network peer add wifi", er_network_peer_add_locator(&peer, &wifi_locator), 1);
  check_uint64("network peer locator count add", peer.locator_count, 2u);
  check_int64("network full peer prepare",
              er_network_peer_prepare(&target_node, &native_locator, 1u, &full_peer), 1);
  check_int64("network peer full add wifi", er_network_peer_add_locator(&full_peer, &wifi_locator), 1);
  check_int64("network peer full add udp", er_network_peer_add_locator(&full_peer, &udp_locator), 1);
  check_int64("network peer full add memory", er_network_peer_add_locator(&full_peer, &memory_locator), 1);
  check_int64("network peer reject full add", er_network_peer_add_locator(&full_peer, &native_locator), 0);

  check_int64("network other native locator",
              er_network_locator_prepare_native_eth(other_mac, NET_TEST_PRIORITY_HIGH,
                                                    NET_TEST_LATE_VALID_MS,
                                                    &weaker_native_locator),
              1);
  weaker_native_locator.cost_per_packet = 2u;
  check_int64("network other peer prepare",
              er_network_peer_prepare(&other_node, &weaker_native_locator, 1u, &other_peer),
              1);
  peers[0] = other_peer;
  peers[1] = peer;
  check_int64("network route select target",
              er_network_route_select(peers, 2u, &target_node, NET_TEST_NOW_MS, &route),
              1);
  check_uint64("network route peer index", route.peer_index, 1u);
  check_uint64("network route locator index", route.locator_index, 0u);
  check_node_id_equal("network route target", &route.target_node_id, &target_node);
  check_uint64("network route selected kind",
               route.selected_locator.kind, ER_NETWORK_LOCATOR_KIND_NATIVE_ETH);
  peers[1].locators[0].valid_until_ms = NET_TEST_NOW_MS;
  check_int64("network route select wifi after expiry",
              er_network_route_select(peers, 2u, &target_node, NET_TEST_NOW_MS, &wifi_route),
              1);
  check_uint64("network route selected wifi",
               wifi_route.selected_locator.kind, ER_NETWORK_LOCATOR_KIND_WIFI_OPEN);
  check_int64("network route reject unknown target",
              er_network_route_select(peers, 2u, &other_node, NET_TEST_LATE_VALID_MS, &route),
              0);

  check_int64("network admission log",
              er_network_erwire_kind_requires_admission(ERWIRE_KIND_LOG_TEXT), 0);
  check_int64("network admission channel",
              er_network_erwire_kind_requires_admission(ERWIRE_KIND_CHANNEL_ENVELOPE), 1);

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;
  check_int64("network virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("network native eth init", er_native_eth_init(&native_eth, &net, peer_mac), 1);
  io.abi_version = ER_NETWORK_ABI_VERSION;
  io.reserved = 0u;
  io.native_eth = &native_eth;
  io.firmware_udp = 0;
  peers[1] = peer;
  check_int64("network route select native for send",
              er_network_route_select(peers, 2u, &target_node, NET_TEST_NOW_MS, &route),
              1);
  erwire_init(17u);
  check_int64("network send native",
              er_network_send_erwire(&io, &route, 0, ERWIRE_KIND_LOG_TEXT,
                                     ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                     payload, NET_TEST_PAYLOAD_LEN),
              1);
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(NET_TEST_TX_DESC);
  check_uint64("network tx desc", tx_avail->ring[0], NET_TEST_TX_DESC);
  check_uint64("network tx dst mac0", tx_frame[NET_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("network tx erwire magic0", tx_frame[NET_TEST_PAYLOAD_OFFSET], 'E');
  check_uint64("network tx erwire magic3", tx_frame[NET_TEST_PAYLOAD_OFFSET + 3u], '1');
  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(NET_TEST_RX_DESC);
  check_int64("network build rx frame",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_EDGERUN,
                                     tx_frame + NET_TEST_PAYLOAD_OFFSET,
                                     NET_TEST_PACKET_LEN,
                                     rx_buffer + NET_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = NET_TEST_RX_DESC;
  rx_used->ring[0].len = NET_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;
  check_int64("network poll native",
              er_network_poll_erwire(&io, peers, 2u, NET_TEST_NOW_MS, &route,
                                     &header, out_payload, (UINT32)sizeof(out_payload),
                                     &out_payload_len),
              1);
  check_uint64("network poll kind", header.Kind, ERWIRE_KIND_LOG_TEXT);
  check_uint64("network poll payload len", out_payload_len, NET_TEST_PAYLOAD_LEN);
  check_uint64("network poll route peer", route.peer_index, 1u);
  check_uint64("network poll payload0", out_payload[0], payload[0]);

  check_int64("network send requires admission",
              er_network_send_erwire(&io, &route, 0, ERWIRE_KIND_CHANNEL_ENVELOPE,
                                     ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                     payload, NET_TEST_PAYLOAD_LEN),
              0);
  er_mem_zero((UINT8*)&admitted_route, (UINTN)sizeof(admitted_route));
  admitted_route.abi_version = ER_WORK_ABI_VERSION;
  admitted_route.admitted_budget = 1u;
  admitted_route.target_node_id = other_node;
  check_int64("network send rejects wrong admitted target",
              er_network_send_erwire(&io, &route, &admitted_route,
                                     ERWIRE_KIND_CHANNEL_ENVELOPE,
                                     ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                     payload, NET_TEST_PAYLOAD_LEN),
              0);
  admitted_route.target_node_id = target_node;
  check_int64("network send with admission",
              er_network_send_erwire(&io, &route, &admitted_route,
                                     ERWIRE_KIND_CHANNEL_ENVELOPE,
                                     ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                     payload, NET_TEST_PAYLOAD_LEN),
              1);
  check_int64("network reject wifi send",
              er_network_send_erwire(&io, &wifi_route, 0, ERWIRE_KIND_LOG_TEXT,
                                     ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                     payload, NET_TEST_PAYLOAD_LEN),
              0);

  check_int64("network firmware endpoint",
              er_hw_relay_default_firmware_udp_endpoint(&firmware_endpoint), 1);
  io.firmware_udp = &firmware_endpoint;
  check_int64("network firmware route select",
              er_network_peer_prepare(&target_node, &udp_locator, 1u, &peer), 1);
  peers[1] = peer;
  check_int64("network firmware route",
              er_network_route_select(peers, 2u, &target_node, NET_TEST_NOW_MS, &route),
              1);
  erwire_init(23u);
  check_int64("network firmware send",
              er_network_send_erwire(&io, &route, 0, ERWIRE_KIND_LOG_TEXT,
                                     ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                     payload, NET_TEST_PAYLOAD_LEN),
              1);
}

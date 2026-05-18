#include "test_core_internal.h"

static void test_boot_profiles(void) {
  check_int64("boot profile os valid", er_boot_profile_valid(ER_BOOT_PROFILE_OS), 1);
  check_int64("boot profile retired smoke rejected", er_boot_profile_valid(0u), 0);
  check_int64("boot profile retired pci rejected", er_boot_profile_valid(1u), 0);
  check_int64("boot profile retired quiet rejected", er_boot_profile_valid(2u), 0);
  check_int64("boot profile retired mmio rejected", er_boot_profile_valid(3u), 0);
  check_int64("boot profile retired native rejected", er_boot_profile_valid(5u), 0);
  check_int64("boot profile retired tpm rejected", er_boot_profile_valid(6u), 0);
  check_int64("boot profile retired gpu rejected", er_boot_profile_valid(7u), 0);
  check_int64("boot profile invalid rejected", er_boot_profile_valid(255u), 0);
  check_cstr("boot profile os label", er_boot_profile_label(ER_BOOT_PROFILE_OS), "os");
  check_cstr("boot profile retired label", er_boot_profile_label(0u), "invalid");
  check_cstr("boot profile invalid label", er_boot_profile_label(255u), "invalid");
}

static void test_hw_relay_endpoints(void) {
  enum {
    RELAY_ETH_TEST_MMIO_DWORDS = 128u,
    RELAY_ETH_TEST_VIRTIO_HDR_LEN = 12u,
    RELAY_ETH_TEST_TX_DESC = 0u,
    RELAY_VIRTIO_TEST_DEVICE_TYPE_OFFSET = 0u,
    RELAY_VIRTIO_TEST_QUEUE_OFFSET = 4u,
    RELAY_VIRTIO_TEST_TRANSPORT_OFFSET = 6u
  };
  UINT32 regs[RELAY_ETH_TEST_MMIO_DWORDS] = {0};
  ErChannelEndpoint endpoint;
  ErChannelEndpoint eth_endpoint;
  ErChannelEndpoint virtio_endpoint;
  ErRelayForwardIntent intent;
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErVirtioQueueAvail* tx_avail;
  UINT8* tx_frame;
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x10u, 0x20u, 0x30u, 0x40u, 0x50u};
  UINT8 other_mac[ER_NET_MAC_LEN] = {0x02u, 0xaau, 0xbbu, 0xccu, 0xddu, 0xeeu};
  UINT8 packet[4] = {1u, 2u, 3u, 4u};

  check_int64("relay udp endpoint",
              er_hw_relay_prepare_firmware_udp_endpoint(10u, 42u, 0u, 1u, 9000u,
                                                        "uefi-udp4", 9u, &endpoint),
              1);
  check_int64("relay udp abi", endpoint.abi_version, ER_WORK_ABI_VERSION);
  check_int64("relay udp kind", endpoint.kind, ER_CHANNEL_KIND_FIRMWARE_UDP);
  check_int64("relay udp address len", endpoint.address_len, ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN);
  check_int64("relay udp ip0", endpoint.address[0], 10);
  check_int64("relay udp ip1", endpoint.address[1], 42);
  check_int64("relay udp port hi", endpoint.address[4], 0x23);
  check_int64("relay udp port lo", endpoint.address[5], 0x28);
  check_int64("relay udp recognized", er_hw_relay_endpoint_is_firmware_udp(&endpoint), 1);

  check_int64("relay default udp", er_hw_relay_default_firmware_udp_endpoint(&endpoint), 1);
  check_int64("relay default label", endpoint.label_len, 9);

  intent.abi_version = ER_WORK_ABI_VERSION;
  intent.reserved = 0;
  intent.to = endpoint;
  check_int64("relay forward unavailable",
              er_hw_relay_forward_to_firmware_udp(&intent, packet, (UINTN)sizeof(packet)),
              0);

  endpoint.kind = ER_CHANNEL_KIND_MEMORY;
  check_int64("relay udp reject kind", er_hw_relay_endpoint_is_firmware_udp(&endpoint), 0);

  check_int64("relay native eth endpoint",
              er_hw_relay_prepare_native_eth_endpoint(peer_mac, "native-eth", 10u,
                                                      &eth_endpoint),
              1);
  check_int64("relay native eth abi", eth_endpoint.abi_version, ER_WORK_ABI_VERSION);
  check_int64("relay native eth kind", eth_endpoint.kind, ER_CHANNEL_KIND_NATIVE_ETH);
  check_int64("relay native eth address len", eth_endpoint.address_len,
              ER_HW_RELAY_NATIVE_ETH_ADDR_LEN);
  check_uint64("relay native eth mac0", eth_endpoint.address[0], peer_mac[0]);
  check_uint64("relay native eth mac5", eth_endpoint.address[5], peer_mac[5]);
  check_int64("relay native eth recognized",
              er_hw_relay_endpoint_is_native_eth(&eth_endpoint), 1);
  check_int64("relay native eth not virtio",
              er_hw_relay_endpoint_is_virtio(&eth_endpoint), 0);

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;
  check_int64("relay native eth virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("relay native eth init",
              er_native_eth_init(&native_eth, &net, peer_mac), 1);
  intent.to = eth_endpoint;
  check_int64("relay forward native eth",
              er_hw_relay_forward_to_native_eth(&native_eth, &intent, packet,
                                                (UINTN)sizeof(packet)),
              1);
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(RELAY_ETH_TEST_TX_DESC);
  check_uint64("relay native eth tx desc", tx_avail->ring[0], RELAY_ETH_TEST_TX_DESC);
  check_uint64("relay native eth tx mac0",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("relay native eth tx type hi",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN + 12u], 0x88u);
  check_uint64("relay native eth tx type lo",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN + 13u], 0xb5u);
  check_uint64("relay native eth payload3",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN + 3u],
               packet[3]);

  check_int64("relay native eth other endpoint",
              er_hw_relay_prepare_native_eth_endpoint(other_mac, "native-eth", 10u,
                                                      &eth_endpoint),
              1);
  intent.to = eth_endpoint;
  check_int64("relay native eth reject mac mismatch",
              er_hw_relay_forward_to_native_eth(&native_eth, &intent, packet,
                                                (UINTN)sizeof(packet)),
              0);

  check_int64("relay virtio endpoint",
              er_hw_relay_prepare_virtio_endpoint(ER_VIRTIO_DEVICE_TYPE_BLK, 0u,
                                                  "virtio-blk", 10u,
                                                  &virtio_endpoint),
              1);
  check_int64("relay virtio abi", virtio_endpoint.abi_version, ER_WORK_ABI_VERSION);
  check_int64("relay virtio kind", virtio_endpoint.kind, ER_CHANNEL_KIND_VIRTIO_QUEUE);
  check_int64("relay virtio address len", virtio_endpoint.address_len,
              ER_HW_RELAY_VIRTIO_ADDR_LEN);
  check_uint64("relay virtio device type byte0",
               virtio_endpoint.address[RELAY_VIRTIO_TEST_DEVICE_TYPE_OFFSET],
               ER_VIRTIO_DEVICE_TYPE_BLK);
  check_uint64("relay virtio queue byte0",
               virtio_endpoint.address[RELAY_VIRTIO_TEST_QUEUE_OFFSET], 0u);
  check_uint64("relay virtio transport any",
               virtio_endpoint.address[RELAY_VIRTIO_TEST_TRANSPORT_OFFSET],
               ER_VIRTIO_TRANSPORT_KIND_NONE);
  check_int64("relay virtio recognized",
              er_hw_relay_endpoint_is_virtio(&virtio_endpoint), 1);
  check_int64("relay virtio not native eth",
              er_hw_relay_endpoint_is_native_eth(&virtio_endpoint), 0);
}

static void test_erwire_native_eth_sink(void) {
  enum {
    ERWIRE_ETH_TEST_MMIO_DWORDS = 128u,
    ERWIRE_ETH_TEST_VIRTIO_HDR_LEN = 12u,
    ERWIRE_ETH_TEST_TX_DESC = 0u,
    ERWIRE_ETH_TEST_STREAM_ID = 7u,
    ERWIRE_ETH_TEST_ETH_TYPE_OFFSET = ERWIRE_ETH_TEST_VIRTIO_HDR_LEN + (ER_NET_MAC_LEN * 2u),
    ERWIRE_ETH_TEST_ETH_TYPE_HI = (ER_NET_ETH_TYPE_EDGERUN >> 8u) & 0xffu,
    ERWIRE_ETH_TEST_ETH_TYPE_LO = ER_NET_ETH_TYPE_EDGERUN & 0xffu,
    ERWIRE_ETH_TEST_PAYLOAD_OFFSET = ERWIRE_ETH_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN,
    ERWIRE_ETH_TEST_KIND_OFFSET =
        ERWIRE_ETH_TEST_PAYLOAD_OFFSET + sizeof(UINT32) + (sizeof(UINT16) * 2u) + (sizeof(UINT32) * 2u),
    ERWIRE_ETH_TEST_LEN_OFFSET = ERWIRE_ETH_TEST_KIND_OFFSET + (sizeof(UINT16) * 2u),
    ERWIRE_ETH_TEST_TEXT_OFFSET = ERWIRE_ETH_TEST_PAYLOAD_OFFSET + ERWIRE_HEADER_SIZE
  };
  UINT32 regs[ERWIRE_ETH_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErVirtioQueueAvail* tx_avail;
  UINT8* tx_frame;
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x21u, 0x22u, 0x23u, 0x24u, 0x25u};

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("erwire eth virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("erwire eth native init", er_native_eth_init(&native_eth, &net, peer_mac), 1);
  erwire_init(ERWIRE_ETH_TEST_STREAM_ID);
  check_int64("erwire eth set sink", erwire_set_native_eth_sink(&native_eth), 1);
  erwire_send_text("ok");
  erwire_clear_native_eth_sink();

  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(ERWIRE_ETH_TEST_TX_DESC);
  check_uint64("erwire eth tx desc", tx_avail->ring[0], ERWIRE_ETH_TEST_TX_DESC);
  check_uint64("erwire eth dst mac0", tx_frame[ERWIRE_ETH_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("erwire eth type hi", tx_frame[ERWIRE_ETH_TEST_ETH_TYPE_OFFSET], ERWIRE_ETH_TEST_ETH_TYPE_HI);
  check_uint64("erwire eth type lo", tx_frame[ERWIRE_ETH_TEST_ETH_TYPE_OFFSET + 1u], ERWIRE_ETH_TEST_ETH_TYPE_LO);
  check_uint64("erwire eth magic0", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET], 'E');
  check_uint64("erwire eth magic1", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET + 1u], 'R');
  check_uint64("erwire eth magic2", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET + 2u], 'W');
  check_uint64("erwire eth magic3", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET + 3u], '1');
  check_uint64("erwire eth kind", tx_frame[ERWIRE_ETH_TEST_KIND_OFFSET], ERWIRE_KIND_LOG_TEXT);
  check_uint64("erwire eth payload len", tx_frame[ERWIRE_ETH_TEST_LEN_OFFSET], 2u);
  check_uint64("erwire eth text0", tx_frame[ERWIRE_ETH_TEST_TEXT_OFFSET], 'o');
  check_uint64("erwire eth text1", tx_frame[ERWIRE_ETH_TEST_TEXT_OFFSET + 1u], 'k');
}

static void test_erwire_parse_and_native_poll(void) {
  enum {
    ERWIRE_RX_TEST_MMIO_DWORDS = 128u,
    ERWIRE_RX_TEST_VIRTIO_HDR_LEN = 12u,
    ERWIRE_RX_TEST_TX_DESC = 0u,
    ERWIRE_RX_TEST_RX_DESC = 3u,
    ERWIRE_RX_TEST_STREAM_ID = 11u,
    ERWIRE_RX_TEST_PAYLOAD_LEN = 2u,
    ERWIRE_RX_TEST_PAYLOAD_OFFSET = ERWIRE_RX_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN,
    ERWIRE_RX_TEST_PACKET_LEN = ERWIRE_HEADER_SIZE + ERWIRE_RX_TEST_PAYLOAD_LEN
  };
  UINT32 regs[ERWIRE_RX_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErwirePacketHeader header;
  ErVirtioQueueUsed* rx_used;
  UINT8* rx_buffer;
  UINT8* tx_frame;
  UINT8 payload[ERWIRE_MAX_PAYLOAD] = {0};
  UINT8 short_payload[1] = {0};
  UINT8 bad_packet[ERWIRE_RX_TEST_PACKET_LEN] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x31u, 0x32u, 0x33u, 0x34u, 0x35u};
  UINT32 frame_len = 0u;
  UINT32 payload_len = 0u;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("erwire rx virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("erwire rx native init", er_native_eth_init(&native_eth, &net, peer_mac), 1);
  erwire_init(ERWIRE_RX_TEST_STREAM_ID);
  check_int64("erwire rx set sink", erwire_set_native_eth_sink(&native_eth), 1);
  erwire_send_text("rx");

  tx_frame = er_virtio_net_test_tx_buffer(ERWIRE_RX_TEST_TX_DESC);
  check_int64("erwire parse packet",
              erwire_parse_packet(tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
                                  ERWIRE_RX_TEST_PACKET_LEN, &header,
                                  payload, (UINT32)sizeof(payload),
                                  &payload_len),
              1);
  check_uint64("erwire parse stream", header.StreamId, ERWIRE_RX_TEST_STREAM_ID);
  check_uint64("erwire parse seq", header.Seq, 0u);
  check_uint64("erwire parse kind", header.Kind, ERWIRE_KIND_LOG_TEXT);
  check_uint64("erwire parse flags", header.Flags, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST);
  check_uint64("erwire parse len", payload_len, ERWIRE_RX_TEST_PAYLOAD_LEN);
  check_uint64("erwire parse payload0", payload[0], 'r');
  check_uint64("erwire parse payload1", payload[1], 'x');
  check_int64("erwire parse reject capacity",
              erwire_parse_packet(tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
                                  ERWIRE_RX_TEST_PACKET_LEN, &header,
                                  short_payload, (UINT32)sizeof(short_payload),
                                  &payload_len),
              0);
  er_mem_copy(bad_packet, tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
              ERWIRE_RX_TEST_PACKET_LEN);
  bad_packet[0] = 0u;
  check_int64("erwire parse reject magic",
              erwire_parse_packet(bad_packet, ERWIRE_RX_TEST_PACKET_LEN,
                                  &header, payload, (UINT32)sizeof(payload),
                                  &payload_len),
              0);

  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(ERWIRE_RX_TEST_RX_DESC);
  check_int64("erwire rx build frame",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_EDGERUN,
                                     tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
                                     ERWIRE_RX_TEST_PACKET_LEN,
                                     rx_buffer + ERWIRE_RX_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = ERWIRE_RX_TEST_RX_DESC;
  rx_used->ring[0].len = ERWIRE_RX_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;
  check_int64("erwire poll native eth",
              erwire_poll_native_eth(&header, payload, (UINT32)sizeof(payload),
                                     &payload_len),
              1);
  check_uint64("erwire poll stream", header.StreamId, ERWIRE_RX_TEST_STREAM_ID);
  check_uint64("erwire poll payload len", payload_len, ERWIRE_RX_TEST_PAYLOAD_LEN);
  check_uint64("erwire poll payload0", payload[0], 'r');
  check_uint64("erwire poll payload1", payload[1], 'x');
  erwire_clear_native_eth_sink();
}

static void test_native_boot_erwire_eth_sink(void) {
  enum {
    NATIVE_BOOT_TEST_MMIO_DWORDS = 128u,
    NATIVE_BOOT_TEST_VIRTIO_HDR_LEN = 12u,
    NATIVE_BOOT_TEST_TX_DESC = 0u,
    NATIVE_BOOT_TEST_RX_DESC = 3u,
    NATIVE_BOOT_TEST_BAD_RX_DESC = 4u,
    NATIVE_BOOT_TEST_STREAM_ID = 9u,
    NATIVE_BOOT_TEST_PAYLOAD_LEN = 4u,
    NATIVE_BOOT_TEST_PAYLOAD_OFFSET = NATIVE_BOOT_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN
  };
  UINT32 regs[NATIVE_BOOT_TEST_MMIO_DWORDS] = {0};
  ErNativeBootState state;
  ErNativeRelayIngress ingress;
  ErCryptoProvider crypto;
  ErVirtioQueueAvail* tx_avail;
  ErVirtioQueueUsed* rx_used;
  UINT8* tx_frame;
  UINT8* rx_buffer;
  UINT8 payload[NATIVE_BOOT_TEST_PAYLOAD_LEN] = {1u, 2u, 3u, 4u};
  UINT8 bad_packet[ERWIRE_HEADER_SIZE] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x21u, 0x22u, 0x23u, 0x24u, 0x25u};
  UINT32 frame_len = 0u;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("native boot sink configured",
              er_native_boot_configure_erwire_eth_sink((UINT64)(UINTN)regs,
                                                       (UINT64)sizeof(regs),
                                                       peer_mac,
                                                       &state),
              1);
  check_int64("native boot initialized", state.initialized, 1);
  check_int64("native boot erwire ready", state.erwire_sink_ready, 1);
  check_int64("native boot net", state.net != 0, 1);
  check_int64("native boot eth", state.eth != 0, 1);

  erwire_init(NATIVE_BOOT_TEST_STREAM_ID);
  erwire_send(ERWIRE_KIND_VFS_OBJECT_PACKET, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
              payload, (UINT32)sizeof(payload));
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(NATIVE_BOOT_TEST_TX_DESC);
  check_uint64("native boot tx desc", tx_avail->ring[0], NATIVE_BOOT_TEST_TX_DESC);
  check_uint64("native boot dst mac0", tx_frame[NATIVE_BOOT_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("native boot erwire magic0", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET], 'E');
  check_uint64("native boot erwire magic1", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET + 1u], 'R');
  check_uint64("native boot erwire magic2", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET + 2u], 'W');
  check_uint64("native boot erwire magic3", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET + 3u], '1');

  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_BOOT_TEST_RX_DESC);
  check_int64("native boot relay build frame",
              er_net_build_eth_frame(peer_mac, state.net->mac,
                                     ER_NET_ETH_TYPE_EDGERUN,
                                     tx_frame + NATIVE_BOOT_TEST_PAYLOAD_OFFSET,
                                     ERWIRE_HEADER_SIZE + NATIVE_BOOT_TEST_PAYLOAD_LEN,
                                     rx_buffer + NATIVE_BOOT_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = NATIVE_BOOT_TEST_RX_DESC;
  rx_used->ring[0].len = NATIVE_BOOT_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;

  er_crypto_blake3_provider(&crypto);
  check_int64("native boot poll relay ingress",
              er_native_boot_poll_relay_ingress(&state, &crypto, &ingress), 1);
  check_int64("native boot relay accepted", ingress.status, ER_NATIVE_RELAY_INGRESS_ACCEPTED);
  check_uint64("native boot relay kind", ingress.header.Kind, ERWIRE_KIND_VFS_OBJECT_PACKET);
  check_uint64("native boot relay seq", ingress.header.Seq, 0u);
  check_uint64("native boot relay payload len", ingress.payload_len, NATIVE_BOOT_TEST_PAYLOAD_LEN);
  check_uint64("native boot relay payload0", ingress.payload[0], payload[0]);
  check_uint64("native boot relay payload3", ingress.payload[3], payload[3]);
  check_uint64("native boot relay ingress mac", ingress.ingress.address[0], peer_mac[0]);

  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_BOOT_TEST_BAD_RX_DESC);
  check_int64("native boot bad relay frame",
              er_net_build_eth_frame(peer_mac, state.net->mac,
                                     ER_NET_ETH_TYPE_EDGERUN,
                                     bad_packet, (UINT32)sizeof(bad_packet),
                                     rx_buffer + NATIVE_BOOT_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[1].id = NATIVE_BOOT_TEST_BAD_RX_DESC;
  rx_used->ring[1].len = NATIVE_BOOT_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 2u;
  check_int64("native boot poll malformed relay ingress",
              er_native_boot_poll_relay_ingress(&state, &crypto, &ingress), 1);
  check_int64("native boot relay malformed", ingress.status, ER_NATIVE_RELAY_INGRESS_MALFORMED);
  check_int64("native boot poll no relay ingress",
              er_native_boot_poll_relay_ingress(&state, &crypto, &ingress), 1);
  check_int64("native boot relay none", ingress.status, ER_NATIVE_RELAY_INGRESS_NONE);
  erwire_clear_native_eth_sink();
}

static void test_native_boot_endpoint_intent(void) {
  enum {
    NATIVE_INTENT_PACKET_SEQUENCE = 12u,
    NATIVE_INTENT_COST_PER_BYTE = 1u,
    NATIVE_INTENT_MAX_TOTAL_COST = sizeof(ErCapabilityEnvelopeHeader) +
                                   ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                                   ER_WASM_UI_RECT_RECORD_LEN +
                                   ER_WASM_UI_HIT_RECORD_LEN +
                                   ER_WASM_UI_QUAD_RECORD_LEN
  };
  ErAdmittedRoute route;
  ErAdmittedRoute bad_route;
  ErNativeRelayIngress ingress;
  ErNativeEndpointIntent intent;
  ErCapabilityEnvelopeHeader capability;
  ErCryptoProvider crypto;
  ErHash session_id;
  ErHash invocation_id;
  ErHash capability_id;
  ErHash token_id;
  ErHash scene_hash;
  UINT8 scene_payload[ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                      ER_WASM_UI_RECT_RECORD_LEN +
                      ER_WASM_UI_HIT_RECORD_LEN +
                      ER_WASM_UI_QUAD_RECORD_LEN];
  UINT8 relay_payload[sizeof(ErCapabilityEnvelopeHeader) +
                      sizeof(scene_payload)];
  UINT32 packet_len = 0u;

  er_crypto_blake3_provider(&crypto);
  test_write_wasm_ui_scene_packet(scene_payload, (UINT32)sizeof(scene_payload));
  er_mem_zero((UINT8*)&route, (UINTN)sizeof(route));
  er_mem_zero((UINT8*)&ingress, (UINTN)sizeof(ingress));
  route.abi_version = ER_WORK_ABI_VERSION;
  route.role = ER_NODE_ROLE_CAPABILITY;
  route.department = ER_DEPARTMENT_CAPABILITY;
  route.work_type = ER_WORK_TYPE_CAPABILITY_INVOKE;
  test_fill_bytes(route.source_node_id.bytes, ER_NODE_ID_LEN, 0x21u);
  test_fill_bytes(route.target_node_id.bytes, ER_NODE_ID_LEN, 0x41u);
  test_fill_bytes(route.admission_hash.bytes, ER_HASH_LEN, 0x61u);
  test_fill_bytes(route.target_route_commitment.bytes, ER_HASH_LEN, 0x81u);
  test_fill_bytes(token_id.bytes, ER_HASH_LEN, 0xa1u);
  test_fill_bytes(session_id.bytes, ER_HASH_LEN, 0xc1u);
  test_fill_bytes(invocation_id.bytes, ER_HASH_LEN, 0xd1u);
  test_fill_bytes(capability_id.bytes, ER_HASH_LEN, 0xe1u);
  check_int64("native endpoint scene payload hash",
              er_render_endpoint_scene_payload_hash(&crypto, scene_payload,
                                                    (UINT32)sizeof(scene_payload),
                                                    &scene_hash),
              1);

  check_int64("native endpoint capability prepare",
              er_work_prepare_capability_envelope_header(ER_CAPABILITY_PACKET_INVOKE,
                                                         ER_WORK_TYPE_CAPABILITY_INVOKE,
                                                         ER_CAPABILITY_CONTENT_RENDER,
                                                         ER_CAPABILITY_RISK_NONE,
                                                         &session_id,
                                                         &invocation_id,
                                                         &capability_id,
                                                         &route.source_node_id,
                                                         &route.target_node_id,
                                                         NATIVE_INTENT_PACKET_SEQUENCE,
                                                         1000u,
                                                         &scene_hash,
                                                         (UINT32)sizeof(scene_payload),
                                                         &capability),
              1);
  er_mem_copy(relay_payload, (const UINT8*)&capability,
              (UINTN)sizeof(capability));
  er_mem_copy(relay_payload + sizeof(capability), scene_payload,
              (UINTN)sizeof(scene_payload));
  check_int64("native endpoint relay packet prepare",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_INTENT_PACKET_SEQUENCE,
                                      NATIVE_INTENT_COST_PER_BYTE,
                                      NATIVE_INTENT_MAX_TOTAL_COST,
                                      &scene_hash,
                                      relay_payload,
                                      (UINT32)sizeof(relay_payload),
                                      &packet_len),
              1);
  ingress.status = ER_NATIVE_RELAY_INGRESS_ACCEPTED;
  ingress.payload_len = packet_len;
  check_int64("native endpoint decode render intent",
              er_native_boot_decode_endpoint_intent(&ingress, &route, &intent), 1);
  check_int64("native endpoint render intent kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_RENDER_CAPABILITY);
  check_node_id_equal("native endpoint render intent source",
                      &intent.packet.source_node_id, &route.source_node_id);
  check_node_id_equal("native endpoint render intent target",
                      &intent.capability.target_node_id, &route.target_node_id);
  check_hash_equal("native endpoint render intent admission",
                   &intent.packet.admission_id, &route.admission_hash);
  check_hash_equal("native endpoint render intent route",
                   &intent.packet.route_hash, &route.target_route_commitment);
  check_uint64("native endpoint render intent packet sequence",
               intent.packet.sequence, NATIVE_INTENT_PACKET_SEQUENCE);
  check_uint64("native endpoint render intent content",
               intent.capability.content_type, ER_CAPABILITY_CONTENT_RENDER);
  check_uint64("native endpoint render scene len",
               intent.scene_payload_len, (UINT64)sizeof(scene_payload));
  check_uint64("native endpoint render scene byte0",
               intent.scene_payload[0], scene_payload[0]);

  check_int64("native endpoint relay packet prepare missing scene",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_INTENT_PACKET_SEQUENCE,
                                      NATIVE_INTENT_COST_PER_BYTE,
                                      NATIVE_INTENT_MAX_TOTAL_COST,
                                      &scene_hash,
                                      (const UINT8*)&capability,
                                      (UINT32)sizeof(capability),
                                      &packet_len),
              1);
  ingress.payload_len = packet_len;
  check_int64("native endpoint decode missing scene",
              er_native_boot_decode_endpoint_intent(&ingress, &route, &intent), 1);
  check_int64("native endpoint missing scene kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_MALFORMED);
  check_int64("native endpoint relay packet restore scene",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_INTENT_PACKET_SEQUENCE,
                                      NATIVE_INTENT_COST_PER_BYTE,
                                      NATIVE_INTENT_MAX_TOTAL_COST,
                                      &scene_hash,
                                      relay_payload,
                                      (UINT32)sizeof(relay_payload),
                                      &packet_len),
              1);
  ingress.payload_len = packet_len;

  bad_route = route;
  bad_route.department = ER_DEPARTMENT_STORAGE;
  check_int64("native endpoint decode unsupported route",
              er_native_boot_decode_endpoint_intent(&ingress, &bad_route, &intent), 1);
  check_int64("native endpoint unsupported route kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_UNSUPPORTED);

  bad_route = route;
  bad_route.admission_hash.bytes[0] ^= 1u;
  check_int64("native endpoint decode malformed route",
              er_native_boot_decode_endpoint_intent(&ingress, &bad_route, &intent), 1);
  check_int64("native endpoint malformed route kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_MALFORMED);

  capability.sequence = NATIVE_INTENT_PACKET_SEQUENCE + 1u;
  er_mem_copy(relay_payload, (const UINT8*)&capability,
              (UINTN)sizeof(capability));
  er_mem_copy(relay_payload + sizeof(capability), scene_payload,
              (UINTN)sizeof(scene_payload));
  check_int64("native endpoint relay packet prepare bad sequence",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_INTENT_PACKET_SEQUENCE,
                                      NATIVE_INTENT_COST_PER_BYTE,
                                      NATIVE_INTENT_MAX_TOTAL_COST,
                                      &scene_hash,
                                      relay_payload,
                                      (UINT32)sizeof(relay_payload),
                                      &packet_len),
              1);
  ingress.payload_len = packet_len;
  check_int64("native endpoint decode sequence mismatch",
              er_native_boot_decode_endpoint_intent(&ingress, &route, &intent), 1);
  check_int64("native endpoint sequence mismatch kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_MALFORMED);
  capability.sequence = NATIVE_INTENT_PACKET_SEQUENCE;
  er_mem_copy(relay_payload, (const UINT8*)&capability,
              (UINTN)sizeof(capability));
  er_mem_copy(relay_payload + sizeof(capability), scene_payload,
              (UINTN)sizeof(scene_payload));
  check_int64("native endpoint relay packet prepare restored",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_INTENT_PACKET_SEQUENCE,
                                      NATIVE_INTENT_COST_PER_BYTE,
                                      NATIVE_INTENT_MAX_TOTAL_COST,
                                      &scene_hash,
                                      relay_payload,
                                      (UINT32)sizeof(relay_payload),
                                      &packet_len),
              1);
  ingress.payload_len = packet_len;

  ingress.payload[0] = 0xffu;
  check_int64("native endpoint decode malformed packet",
              er_native_boot_decode_endpoint_intent(&ingress, &route, &intent), 1);
  check_int64("native endpoint malformed packet kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_MALFORMED);
  ingress.payload[0] = (UINT8)ER_RELAY_PACKET_ABI_VERSION;

  ingress.status = ER_NATIVE_RELAY_INGRESS_NONE;
  ingress.payload_len = 0u;
  check_int64("native endpoint decode none",
              er_native_boot_decode_endpoint_intent(&ingress, &route, &intent), 1);
  check_int64("native endpoint none kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_NONE);
  check_int64("native endpoint reject null intent",
              er_native_boot_decode_endpoint_intent(&ingress, &route, 0), 0);
}

static void test_native_boot_storage_endpoint_intent(void) {
  enum {
    NATIVE_STORAGE_PACKET_SEQUENCE = 13u,
    NATIVE_STORAGE_COST_PER_BYTE = 1u,
    NATIVE_STORAGE_PAYLOAD_BYTES = sizeof(ErVfsObjectPacketHeader) + 5u,
    NATIVE_STORAGE_MAX_TOTAL_COST = NATIVE_STORAGE_PAYLOAD_BYTES,
    NATIVE_STORAGE_APP_INDEX = 0u
  };
  ErAdmittedRoute route;
  ErAdmittedRoute bad_route;
  ErNativeRelayIngress ingress;
  ErNativeEndpointIntent intent;
  ErVfsObjectPacket object_packet;
  ErVfsObjectPacket bad_object_packet;
  ErCryptoProvider crypto;
  ErHash token_id;
  UINT8 object_bytes[5] = {'o', 'b', 'j', '0', '1'};
  UINT8 storage_payload[NATIVE_STORAGE_PAYLOAD_BYTES];
  UINT32 packet_len = 0u;

  er_crypto_blake3_provider(&crypto);
  er_mem_zero((UINT8*)&ingress, (UINTN)sizeof(ingress));
  check_int64("native storage route prepare",
              er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                        NATIVE_STORAGE_APP_INDEX,
                                                        &route),
              1);
  test_fill_bytes(token_id.bytes, ER_HASH_LEN, 0xb1u);
  check_int64("native storage object packet prepare",
              er_vfs_prepare_object_packet(&crypto, object_bytes,
                                           (UINTN)sizeof(object_bytes),
                                           0u, 0u, 1u, &object_packet),
              1);
  er_mem_copy(storage_payload, (const UINT8*)&object_packet.header,
              (UINTN)sizeof(object_packet.header));
  er_mem_copy(storage_payload + sizeof(object_packet.header),
              object_packet.bytes, (UINTN)sizeof(object_bytes));
  check_int64("native storage relay packet prepare",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_STORAGE_PACKET_SEQUENCE,
                                      NATIVE_STORAGE_COST_PER_BYTE,
                                      NATIVE_STORAGE_MAX_TOTAL_COST,
                                      &object_packet.header.packet_id,
                                      storage_payload,
                                      (UINT32)sizeof(storage_payload),
                                      &packet_len),
              1);
  ingress.status = ER_NATIVE_RELAY_INGRESS_ACCEPTED;
  ingress.payload_len = packet_len;
  check_int64("native storage decode intent",
              er_native_boot_decode_endpoint_intent(&ingress, &route,
                                                    &intent),
              1);
  check_int64("native storage intent kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_STORAGE_OBJECT_PACKET);
  check_hash_equal("native storage intent packet id",
                   &intent.object_packet.header.packet_id,
                   &object_packet.header.packet_id);
  check_hash_equal("native storage intent object id",
                   &intent.object_packet.header.object_id,
                   &object_packet.header.object_id);
  check_uint64("native storage intent bytes",
               intent.object_packet.header.bytes_len,
               sizeof(object_bytes));

  bad_object_packet = object_packet;
  bad_object_packet.header.packet_id.bytes[0] ^= 1u;
  er_mem_copy(storage_payload, (const UINT8*)&bad_object_packet.header,
              (UINTN)sizeof(bad_object_packet.header));
  er_mem_copy(storage_payload + sizeof(bad_object_packet.header),
              bad_object_packet.bytes, (UINTN)sizeof(object_bytes));
  check_int64("native storage bad packet relay prepare",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      NATIVE_STORAGE_PACKET_SEQUENCE,
                                      NATIVE_STORAGE_COST_PER_BYTE,
                                      NATIVE_STORAGE_MAX_TOTAL_COST,
                                      &object_packet.header.packet_id,
                                      storage_payload,
                                      (UINT32)sizeof(storage_payload),
                                      &packet_len),
              1);
  ingress.payload_len = packet_len;
  check_int64("native storage reject packet id mismatch",
              er_native_boot_decode_endpoint_intent(&ingress, &route,
                                                    &intent),
              1);
  check_int64("native storage packet id mismatch kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_MALFORMED);

  bad_route = route;
  bad_route.target_route_commitment.bytes[0] ^= 1u;
  check_int64("native storage route mismatch decode",
              er_native_boot_decode_endpoint_intent(&ingress, &bad_route,
                                                    &intent),
              1);
  check_int64("native storage route mismatch kind",
              intent.kind, ER_NATIVE_ENDPOINT_INTENT_MALFORMED);
}

static void test_os_native_relay_dispatch(void) {
  enum {
    OS_RELAY_PACKET_SEQUENCE = 1u,
    OS_RELAY_COST_PER_BYTE = 1u,
    OS_RELAY_MAX_TOTAL_COST = sizeof(ErCapabilityEnvelopeHeader) +
                              ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                              ER_WASM_UI_RECT_RECORD_LEN +
                              ER_WASM_UI_HIT_RECORD_LEN +
                              ER_WASM_UI_QUAD_RECORD_LEN,
    OS_RELAY_TOKEN_SEED = 0xa1u,
    OS_RELAY_PACKET_HASH_SEED = 0xc1u,
    OS_RELAY_STORAGE_PACKET_HASH_SEED = 0xd1u,
    OS_RELAY_TIMESTAMP_MS = 1000u,
    OS_RELAY_SCENE_BG_R = 0u,
    OS_RELAY_SCENE_BG_G = 0u,
    OS_RELAY_SCENE_BG_B = 0u,
    OS_RELAY_ACTIVE_APP_INDEX = 0u,
    OS_RELAY_STORAGE_PAYLOAD_BYTES = sizeof(ErVfsObjectPacketHeader) + 6u
  };
  ErAppUiPresentation presentation;
  ErUiBootAppContext app;
  ErUiBootRenderContext render;
  er_ui_scene_t scene;
  ErNativeRelayIngress ingress;
  ErAdmittedRoute route;
  ErAdmittedRoute storage_route;
  ErAdmittedRoute wrong_storage_route;
  ErCapabilityEnvelopeHeader capability;
  ErVfsObjectPacket object_packet;
  ErCryptoProvider crypto;
  ErHash token_id;
  ErHash scene_hash;
  ErAppLoadedPackage loaded_package;
  UINT8 module_memory[ER_UI_BOOT_APP_MODULE_BYTES];
  UINT8 manifest_memory[ER_UI_BOOT_APP_MANIFEST_BYTES];
  UINT8 object_bytes[6] = {'s', 't', 'o', 'r', 'e', '1'};
  UINT8 storage_payload[OS_RELAY_STORAGE_PAYLOAD_BYTES];
  UINT8 scene_payload[ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                      ER_WASM_UI_RECT_RECORD_LEN +
                      ER_WASM_UI_HIT_RECORD_LEN +
                      ER_WASM_UI_QUAD_RECORD_LEN];
  UINT8 relay_payload[sizeof(ErCapabilityEnvelopeHeader) +
                      sizeof(scene_payload)];
  UINT32 packet_len = 0u;
  UINT8 redraw = 1u;

  er_crypto_blake3_provider(&crypto);
  test_write_wasm_ui_scene_packet(scene_payload, (UINT32)sizeof(scene_payload));
  check_int64("os relay dispatch scene init",
              er_ui_scene_init_with_allocator(&scene,
                                              er_ui_color_rgb_u8(OS_RELAY_SCENE_BG_R,
                                                                 OS_RELAY_SCENE_BG_G,
                                                                 OS_RELAY_SCENE_BG_B),
                                              test_ui_allocator()),
              ER_UI_OK);
  test_prepare_wasm_ui_presentation(&presentation);
  er_mem_zero((UINT8*)&app, (UINTN)sizeof(app));
  app.ready = 1u;
  app.runtime.presentation = &presentation;
  er_mem_zero((UINT8*)&render, (UINTN)sizeof(render));
  render.apps = &app;
  render.app_count = 1u;
  render.active_app = 0u;
  render.scene = &scene;
  er_mem_zero((UINT8*)&ingress, (UINTN)sizeof(ingress));

  ingress.status = ER_NATIVE_RELAY_INGRESS_NONE;
  check_int64("os relay dispatch none",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress,
                                                       &redraw), 1);
  check_uint64("os relay dispatch none count",
               render.native_relay_stats.none, 1u);
  check_uint64("os relay dispatch none redraw", redraw, 0u);

  ingress.status = ER_NATIVE_RELAY_INGRESS_MALFORMED;
  check_int64("os relay dispatch malformed",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress,
                                                       &redraw), 1);
  check_uint64("os relay dispatch malformed count",
               render.native_relay_stats.malformed, 1u);

  check_int64("os relay dispatch prepare route",
              er_ui_wasm_app_prepare_render_route(&presentation, &route), 1);
  test_fill_bytes(token_id.bytes, ER_HASH_LEN, OS_RELAY_TOKEN_SEED);
  check_int64("os relay dispatch scene payload hash",
              er_render_endpoint_scene_payload_hash(&crypto, scene_payload,
                                                    (UINT32)sizeof(scene_payload),
                                                    &scene_hash),
              1);
  test_fill_bytes(ingress.packet_hash.bytes, ER_HASH_LEN,
                  OS_RELAY_PACKET_HASH_SEED);
  ingress.ingress.abi_version = ER_WORK_ABI_VERSION;
  ingress.ingress.kind = ER_CHANNEL_KIND_NATIVE_ETH;
  ingress.ingress.channel_id = route.channel_id;
  ingress.ingress.address_len = ER_HW_RELAY_NATIVE_ETH_ADDR_LEN;
  check_int64("os relay dispatch capability prepare",
              er_work_prepare_capability_envelope_header(ER_CAPABILITY_PACKET_INVOKE,
                                                         ER_WORK_TYPE_CAPABILITY_INVOKE,
                                                         ER_CAPABILITY_CONTENT_RENDER,
                                                         ER_CAPABILITY_RISK_NONE,
                                                         &presentation.jurisdiction_id,
                                                         &presentation.presentation_id,
                                                         &presentation.admission_id,
                                                         &route.source_node_id,
                                                         &route.target_node_id,
                                                         OS_RELAY_PACKET_SEQUENCE,
                                                         OS_RELAY_TIMESTAMP_MS,
                                                         &scene_hash,
                                                         (UINT32)sizeof(scene_payload),
                                                         &capability),
              1);
  er_mem_copy(relay_payload, (const UINT8*)&capability,
              (UINTN)sizeof(capability));
  er_mem_copy(relay_payload + sizeof(capability), scene_payload,
              (UINTN)sizeof(scene_payload));
  check_int64("os relay dispatch packet prepare",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &route.source_node_id,
                                      &route.target_node_id,
                                      &route.admission_hash,
                                      &token_id,
                                      &route.target_route_commitment,
                                      OS_RELAY_PACKET_SEQUENCE,
                                      OS_RELAY_COST_PER_BYTE,
                                      OS_RELAY_MAX_TOTAL_COST,
                                      &scene_hash,
                                      relay_payload,
                                      (UINT32)sizeof(relay_payload),
                                      &packet_len),
              1);
  ingress.status = ER_NATIVE_RELAY_INGRESS_ACCEPTED;
  ingress.payload_len = packet_len;
  check_int64("os relay dispatch render intent",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress,
                                                       &redraw), 1);
  check_uint64("os relay dispatch render count",
               render.native_relay_stats.render_capability, 1u);
  check_uint64("os relay dispatch render scene count",
               render.native_relay_stats.render_scenes, 1u);
  check_hash_equal("os relay dispatch render capture scene",
                   &render.native_relay_last_render_capture.scene_hash,
                   &scene_hash);
  check_hash_equal("os relay dispatch render endpoint scene",
                   &render.native_relay_last_render_scene.scene_hash,
                   &scene_hash);
  check_uint64("os relay dispatch decoded rect count",
               scene.rect_count, 1u);
  check_uint64("os relay dispatch decoded hit count",
               scene.hit_count, 1u);
  check_uint64("os relay dispatch transit count",
               render.native_relay_stats.transit_hops, 1u);
  check_uint64("os relay dispatch transit not emitted without native sink",
               render.native_relay_stats.transit_emitted, 0u);
  check_node_id_equal("os relay dispatch transit relay",
                      &render.native_relay_last_transit.relay_node_id,
                      &route.relay_node_id);
  check_hash_equal("os relay dispatch transit channel",
                   &render.native_relay_last_transit.channel_id,
                   &route.channel_id);
  check_hash_equal("os relay dispatch transit packet",
                   &render.native_relay_last_transit.packet_hash,
                   &ingress.packet_hash);
  check_uint64("os relay dispatch transit sequence",
               render.native_relay_last_transit.sequence,
               OS_RELAY_PACKET_SEQUENCE);
  check_int64("os relay dispatch transit hash nonzero",
              er_hash_nonzero(&render.native_relay_last_transit.transit_hash),
              1);
  check_uint64("os relay dispatch render redraw", redraw, 1u);

  check_int64("os relay dispatch seed app storage",
              er_ui_boot_load_wasm_counter_package(module_memory,
                                                   (UINT32)sizeof(module_memory),
                                                   manifest_memory,
                                                   (UINT32)sizeof(manifest_memory),
                                                   &app.storage,
                                                   OS_RELAY_ACTIVE_APP_INDEX,
                                                   &loaded_package),
              1);
  check_uint64("os relay dispatch seeded app store complete",
               app.storage.app_store.complete, 1u);

  check_int64("os relay dispatch storage route prepare",
              er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                        OS_RELAY_ACTIVE_APP_INDEX,
                                                        &storage_route),
              1);
  check_int64("os relay dispatch storage packet prepare",
              er_vfs_prepare_object_packet(&crypto, object_bytes,
                                           (UINTN)sizeof(object_bytes),
                                           0u, 0u, 1u, &object_packet),
              1);
  er_mem_copy(storage_payload, (const UINT8*)&object_packet.header,
              (UINTN)sizeof(object_packet.header));
  er_mem_copy(storage_payload + sizeof(object_packet.header),
              object_packet.bytes, (UINTN)sizeof(object_bytes));
  test_fill_bytes(ingress.packet_hash.bytes, ER_HASH_LEN,
                  OS_RELAY_STORAGE_PACKET_HASH_SEED);
  ingress.ingress.channel_id = storage_route.channel_id;
  check_int64("os relay dispatch storage relay prepare",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &storage_route.source_node_id,
                                      &storage_route.target_node_id,
                                      &storage_route.admission_hash,
                                      &token_id,
                                      &storage_route.target_route_commitment,
                                      OS_RELAY_PACKET_SEQUENCE,
                                      OS_RELAY_COST_PER_BYTE,
                                      (UINT32)sizeof(storage_payload),
                                      &object_packet.header.packet_id,
                                      storage_payload,
                                      (UINT32)sizeof(storage_payload),
                                      &packet_len),
              1);
  ingress.status = ER_NATIVE_RELAY_INGRESS_ACCEPTED;
  ingress.payload_len = packet_len;
  check_int64("os relay dispatch storage intent",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress,
                                                       &redraw), 1);
  check_uint64("os relay dispatch storage count",
               render.native_relay_stats.storage_object_packets, 1u);
  check_hash_equal("os relay dispatch storage route",
                   &render.native_relay_last_storage_capture.route_id,
                   &storage_route.route_id);
  check_hash_equal("os relay dispatch storage object",
                   &render.native_relay_last_storage_capture.object_id,
                   &object_packet.header.object_id);
  check_hash_equal("os relay dispatch storage packet",
                   &render.native_relay_last_storage_capture.packet_id,
                   &object_packet.header.packet_id);
  check_int64("os relay dispatch storage capture nonzero",
              er_hash_nonzero(&render.native_relay_last_storage_capture.capture_hash),
              1);
  check_uint64("os relay dispatch storage store complete",
               app.storage.app_store.complete, 1u);
  check_hash_equal("os relay dispatch storage store route",
                   &app.storage.app_store.route_id,
                   &storage_route.route_id);
  check_hash_equal("os relay dispatch storage store object",
                   &app.storage.app_store.object_id,
                   &object_packet.header.object_id);
  check_uint64("os relay dispatch storage transit count",
               render.native_relay_stats.transit_hops, 2u);
  check_hash_equal("os relay dispatch storage transit packet",
                   &render.native_relay_last_transit.packet_hash,
                   &ingress.packet_hash);
  check_uint64("os relay dispatch storage redraw", redraw, 0u);

  check_int64("os relay dispatch wrong storage route prepare",
              er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                        1u, &wrong_storage_route),
              1);
  ingress.ingress.channel_id = wrong_storage_route.channel_id;
  check_int64("os relay dispatch wrong storage relay prepare",
              er_relay_packet_prepare(ingress.payload,
                                      (UINT32)sizeof(ingress.payload),
                                      &wrong_storage_route.source_node_id,
                                      &wrong_storage_route.target_node_id,
                                      &wrong_storage_route.admission_hash,
                                      &token_id,
                                      &wrong_storage_route.target_route_commitment,
                                      OS_RELAY_PACKET_SEQUENCE,
                                      OS_RELAY_COST_PER_BYTE,
                                      (UINT32)sizeof(storage_payload),
                                      &object_packet.header.packet_id,
                                      storage_payload,
                                      (UINT32)sizeof(storage_payload),
                                      &packet_len),
              1);
  ingress.payload_len = packet_len;
  check_int64("os relay dispatch wrong storage route",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress,
                                                       &redraw), 1);
  check_uint64("os relay dispatch wrong storage malformed",
               render.native_relay_stats.malformed, 2u);

  ingress.payload[0] = 0xffu;
  check_int64("os relay dispatch malformed accepted",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress,
                                                       &redraw), 1);
  check_uint64("os relay dispatch malformed accepted count",
               render.native_relay_stats.malformed, 3u);

  check_int64("os relay dispatch reject null render",
              er_ui_boot_dispatch_native_relay_ingress(0, &ingress, &redraw),
              0);
  check_int64("os relay dispatch reject null ingress",
              er_ui_boot_dispatch_native_relay_ingress(&render, 0, &redraw),
              0);
  check_int64("os relay dispatch reject null redraw",
              er_ui_boot_dispatch_native_relay_ingress(&render, &ingress, 0),
              0);
  er_ui_scene_destroy(&scene);
}

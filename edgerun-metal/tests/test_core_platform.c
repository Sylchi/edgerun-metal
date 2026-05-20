#include "test_core_internal.h"

static void test_net_frame_builders(void) {
  enum {
    NET_TEST_UDP_PAYLOAD_LEN = 3u,
    NET_TEST_SRC_PORT = 1234u,
    NET_TEST_DST_PORT = 9000u
  };
  UINT8 src_mac[ER_NET_MAC_LEN] = {0x02u, 0x00u, 0x00u, 0x00u, 0x00u, 0x02u};
  UINT8 dst_mac[ER_NET_MAC_LEN] = {0x02u, 0x00u, 0x00u, 0x00u, 0x00u, 0x01u};
  UINT8 src_ip[ER_NET_IPV4_LEN] = {10u, 42u, 0u, 2u};
  UINT8 dst_ip[ER_NET_IPV4_LEN] = {10u, 42u, 0u, 1u};
  UINT8 payload[NET_TEST_UDP_PAYLOAD_LEN] = {'E', 'R', 'W'};
  UINT8 frame[ER_NET_FRAME_MAX] = {0};
  UINT8 eth_payload[NET_TEST_UDP_PAYLOAD_LEN] = {'L', '2', '!'};
  UINT8 parsed_payload[NET_TEST_UDP_PAYLOAD_LEN] = {0};
  UINT8 parsed_src_mac[ER_NET_MAC_LEN] = {0};
  UINT32 frame_len = 0;
  UINT32 parsed_payload_len = 0;
  UINT8 arp[ER_NET_ARP_FRAME_LEN] = {0};
  UINT8 parsed_mac[ER_NET_MAC_LEN] = {0};
  UINT32 arp_len = 0;

  check_int64("net frame udp build",
              er_net_build_ipv4_udp_frame(src_mac, dst_mac, src_ip, dst_ip,
                                          NET_TEST_SRC_PORT, NET_TEST_DST_PORT,
                                          payload, NET_TEST_UDP_PAYLOAD_LEN,
                                          frame, (UINT32)sizeof(frame), &frame_len),
              1);
  check_uint64("net frame udp len", frame_len,
               ER_NET_IPV4_UDP_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame dst mac0", frame[0], dst_mac[0]);
  check_uint64("net frame src mac5", frame[11], src_mac[5]);
  check_uint64("net frame eth ipv4 hi", frame[12], 0x08u);
  check_uint64("net frame eth ipv4 lo", frame[13], 0x00u);
  check_uint64("net frame ipv4 version", frame[14], 0x45u);
  check_uint64("net frame ipv4 total hi", frame[16], 0x00u);
  check_uint64("net frame ipv4 total lo", frame[17],
               ER_NET_IPV4_HEADER_LEN + ER_NET_UDP_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame ipv4 ttl", frame[22], 64u);
  check_uint64("net frame ipv4 proto udp", frame[23], ER_NET_IP_PROTO_UDP);
  check_uint64("net frame ipv4 checksum valid",
               er_net_checksum16(&frame[ER_NET_ETH_HEADER_LEN], ER_NET_IPV4_HEADER_LEN), 0u);
  check_uint64("net frame udp src hi", frame[34], 0x04u);
  check_uint64("net frame udp src lo", frame[35], 0xd2u);
  check_uint64("net frame udp dst hi", frame[36], 0x23u);
  check_uint64("net frame udp dst lo", frame[37], 0x28u);
  check_uint64("net frame udp len lo", frame[39], ER_NET_UDP_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame udp checksum zero", frame[40] | frame[41], 0u);
  check_uint64("net frame payload0", frame[ER_NET_IPV4_UDP_HEADER_LEN], payload[0]);
  check_uint64("net frame payload2", frame[ER_NET_IPV4_UDP_HEADER_LEN + 2u], payload[2]);

  check_int64("net frame eth build",
              er_net_build_eth_frame(src_mac, dst_mac, ER_NET_ETH_TYPE_EDGERUN,
                                     eth_payload, NET_TEST_UDP_PAYLOAD_LEN,
                                     frame, (UINT32)sizeof(frame), &frame_len),
              1);
  check_uint64("net frame eth len", frame_len,
               ER_NET_ETH_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame edgerun type hi", frame[12], 0x88u);
  check_uint64("net frame edgerun type lo", frame[13], 0xb5u);
  check_int64("net frame eth parse",
              er_net_parse_eth_frame(frame, frame_len, dst_mac,
                                     ER_NET_ETH_TYPE_EDGERUN, parsed_src_mac,
                                     parsed_payload, (UINT32)sizeof(parsed_payload),
                                     &parsed_payload_len),
              1);
  check_uint64("net frame eth parse len", parsed_payload_len, NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame eth parse src5", parsed_src_mac[5], src_mac[5]);
  check_uint64("net frame eth parse payload2", parsed_payload[2], eth_payload[2]);

  check_int64("net frame arp request",
              er_net_build_arp_request(src_mac, src_ip, dst_ip, arp, (UINT32)sizeof(arp), &arp_len),
              1);
  check_uint64("net frame arp len", arp_len, ER_NET_ARP_FRAME_LEN);
  check_uint64("net frame arp broadcast", arp[0], 0xffu);
  check_uint64("net frame arp eth type hi", arp[12], 0x08u);
  check_uint64("net frame arp eth type lo", arp[13], 0x06u);
  check_uint64("net frame arp op request", arp[21], 0x01u);
  check_uint64("net frame arp source mac5", arp[ER_NET_ETH_HEADER_LEN + 13u], src_mac[5]);
  check_uint64("net frame arp target ip0", arp[ER_NET_ETH_HEADER_LEN + 24u], dst_ip[0]);

  er_mem_copy(arp, dst_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + 6u, src_mac, ER_NET_MAC_LEN);
  arp[21] = 0x02u;
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 8u, dst_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 14u, dst_ip, ER_NET_IPV4_LEN);
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 18u, src_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 24u, src_ip, ER_NET_IPV4_LEN);
  check_int64("net frame arp parse",
              er_net_parse_arp_ipv4_reply(arp, arp_len, dst_ip, src_ip, parsed_mac),
              1);
  check_uint64("net frame arp parsed mac0", parsed_mac[0], dst_mac[0]);
  check_uint64("net frame arp parsed mac5", parsed_mac[5], dst_mac[5]);
}

static void test_native_eth_endpoint(void) {
  enum {
    NATIVE_ETH_TEST_MMIO_DWORDS = 128u,
    NATIVE_ETH_TEST_PAYLOAD_LEN = 4u,
    NATIVE_ETH_TEST_VIRTIO_HDR_LEN = 12u,
    NATIVE_ETH_TEST_TX_DESC = 0u,
    NATIVE_ETH_TEST_RX_DESC = 2u,
    NATIVE_ETH_TEST_RX_REJECT_DESC = 3u
  };
  UINT32 regs[NATIVE_ETH_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth endpoint;
  ErNativeEthStats stats;
  ErVirtioQueueUsed* rx_used;
  UINT8* rx_buffer;
  ErVirtioQueueAvail* tx_avail;
  UINT8* tx_frame;
  UINT8 payload[NATIVE_ETH_TEST_PAYLOAD_LEN] = {'w', 'o', 'r', 'k'};
  UINT8 received[NATIVE_ETH_TEST_PAYLOAD_LEN] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x00u, 0x00u, 0x00u, 0x00u, 0x01u};
  UINT8 reply_payload[NATIVE_ETH_TEST_PAYLOAD_LEN] = {'o', 'k', 'a', 'y'};
  UINT32 received_len = 0u;
  UINT32 frame_len = 0u;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("native eth virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("native eth init",
              er_native_eth_init(&endpoint, &net, peer_mac),
              1);
  check_int64("native eth reject empty send",
              er_native_eth_send(&endpoint, payload, 0u), 0);
  check_int64("native eth send",
              er_native_eth_send(&endpoint, payload, NATIVE_ETH_TEST_PAYLOAD_LEN), 1);
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(NATIVE_ETH_TEST_TX_DESC);
  check_uint64("native eth tx avail", tx_avail->ring[0], NATIVE_ETH_TEST_TX_DESC);
  check_uint64("native eth tx dst mac0",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("native eth tx src mac5",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + 11u], net.mac[ER_NET_MAC_LEN - 1u]);
  check_uint64("native eth tx type hi",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + 12u], 0x88u);
  check_uint64("native eth tx type lo",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + 13u], 0xb5u);
  check_uint64("native eth tx payload0",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN], payload[0]);
  stats = er_native_eth_stats(&endpoint);
  check_uint64("native eth tx stats", stats.tx_frames_sent, 1u);

  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_ETH_TEST_RX_DESC);
  check_int64("native eth build reply",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_EDGERUN,
                                     reply_payload, NATIVE_ETH_TEST_PAYLOAD_LEN,
                                     rx_buffer + NATIVE_ETH_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = NATIVE_ETH_TEST_RX_DESC;
  rx_used->ring[0].len = NATIVE_ETH_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;
  check_int64("native eth recv",
              er_native_eth_recv(&endpoint, received, (UINT32)sizeof(received),
                                 &received_len),
              1);
  check_uint64("native eth recv len", received_len, NATIVE_ETH_TEST_PAYLOAD_LEN);
  check_uint64("native eth recv payload0", received[0], reply_payload[0]);
  check_uint64("native eth recv payload3", received[3], reply_payload[3]);
  stats = er_native_eth_stats(&endpoint);
  check_uint64("native eth rx polled stats", stats.rx_frames_polled, 1u);
  check_uint64("native eth rx accepted stats", stats.rx_frames_accepted, 1u);
  check_uint64("native eth rx rejected stats", stats.rx_frames_rejected, 0u);

  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_ETH_TEST_RX_REJECT_DESC);
  check_int64("native eth build rejected frame",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_IPV4,
                                     reply_payload, NATIVE_ETH_TEST_PAYLOAD_LEN,
                                     rx_buffer + NATIVE_ETH_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[1].id = NATIVE_ETH_TEST_RX_REJECT_DESC;
  rx_used->ring[1].len = NATIVE_ETH_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 2u;
  check_int64("native eth reject non edgerun",
              er_native_eth_recv(&endpoint, received, (UINT32)sizeof(received),
                                 &received_len),
              0);
  stats = er_native_eth_stats(&endpoint);
  check_uint64("native eth rejected stats", stats.rx_frames_rejected, 1u);
}

static void test_acpi_tables(void) {
  enum {
    PCI_TEST_ECAM_DWORDS = 1024u,
    PCI_TEST_DEVICE_ID = 0x56781234u,
    PCI_TEST_INVALID_ID = 0xffffffffu,
    PCI_TEST_COMMAND_VALUE = ER_PCI_COMMAND_MEMORY_SPACE | ER_PCI_COMMAND_BUS_MASTER
  };
  static UINT8 rsdp[36];
  static UINT8 xsdt[68];
  static UINT8 fadt[132];
  static UINT8 madt[74];
  static UINT8 mcfg[60];
  static UINT8 hpet[56];
  static UINT32 pci_ecam[PCI_TEST_ECAM_DWORDS];
  EFI_CONFIGURATION_TABLE config[1];
  EFI_SYSTEM_TABLE st;
  ErAcpiRsdpInfo rsdp_info;
  ErAcpiTableList table_list;
  ErAcpiTableInfo found_table;
  ErAcpiFadtInfo fadt_info;
  ErAcpiMadtInfo madt_info;
  ErAcpiMcfgInfo mcfg_info;
  ErAcpiHpetInfo hpet_info;
  UINT64 ecam_address = 0;
  EFI_GUID acpi20 = {
    0x8868e871u, 0xe4f1u, 0x11d3u, {0xbcu, 0x22u, 0x00u, 0x80u, 0xc7u, 0x3cu, 0x88u, 0x81u}
  };

  test_put_le64(&rsdp[0], 0x2052545020445352ull);
  rsdp[9] = 'E';
  rsdp[10] = 'D';
  rsdp[11] = 'G';
  rsdp[12] = 'E';
  rsdp[13] = 'R';
  rsdp[14] = 'N';
  rsdp[15] = 2;
  test_put_le32(&rsdp[16], 0u);
  test_put_le32(&rsdp[20], (UINT32)sizeof(rsdp));
  test_put_le64(&rsdp[24], (UINT64)(UINTN)xsdt);
  test_acpi_set_checksum(rsdp, 20u, 8u);
  test_acpi_set_checksum(rsdp, (UINTN)sizeof(rsdp), 32u);

  test_put_le32(&xsdt[0], er_acpi_signature("XSDT"));
  test_put_le32(&xsdt[4], (UINT32)sizeof(xsdt));
  xsdt[8] = 1;
  test_put_le64(&xsdt[36], (UINT64)(UINTN)fadt);
  test_put_le64(&xsdt[44], (UINT64)(UINTN)madt);
  test_put_le64(&xsdt[52], (UINT64)(UINTN)mcfg);
  test_put_le64(&xsdt[60], (UINT64)(UINTN)hpet);
  test_acpi_set_checksum(xsdt, (UINTN)sizeof(xsdt), 9u);

  test_put_le32(&fadt[0], er_acpi_signature("FACP"));
  test_put_le32(&fadt[4], (UINT32)sizeof(fadt));
  fadt[8] = 6;
  fadt[46] = 9;
  fadt[47] = 0;
  test_put_le32(&fadt[48], 0x000000b2u);
  fadt[52] = 0xa0u;
  fadt[53] = 0xa1u;
  test_put_le32(&fadt[56], 0x00000400u);
  test_put_le32(&fadt[60], 0x00000500u);
  test_put_le32(&fadt[64], 0x00000404u);
  test_put_le32(&fadt[68], 0x00000504u);
  test_put_le32(&fadt[76], 0x00000408u);
  fadt[88] = 4;
  fadt[89] = 2;
  fadt[91] = 4;
  fadt[109] = 0x03u;
  fadt[110] = 0x00u;
  test_put_le32(&fadt[112], 0x00000001u);
  fadt[116] = 1;
  fadt[117] = 8;
  fadt[118] = 0;
  fadt[119] = 1;
  test_put_le64(&fadt[120], 0x0000000000000cf9ull);
  fadt[128] = 0x06u;
  test_acpi_set_checksum(fadt, (UINTN)sizeof(fadt), 9u);

  test_put_le32(&madt[0], er_acpi_signature("APIC"));
  test_put_le32(&madt[4], (UINT32)sizeof(madt));
  madt[8] = 5;
  test_put_le32(&madt[36], 0xfee00000u);
  test_put_le32(&madt[40], 1u);
  madt[44] = ER_ACPI_MADT_ENTRY_LAPIC;
  madt[45] = 8;
  madt[46] = 2;
  madt[47] = 3;
  test_put_le32(&madt[48], ER_ACPI_MADT_LAPIC_ENABLED);
  madt[52] = ER_ACPI_MADT_ENTRY_IOAPIC;
  madt[53] = 12;
  madt[54] = 4;
  test_put_le32(&madt[56], 0xfec00000u);
  test_put_le32(&madt[60], 0u);
  madt[64] = ER_ACPI_MADT_ENTRY_INTERRUPT_SOURCE_OVERRIDE;
  madt[65] = 10;
  madt[66] = 0;
  madt[67] = 1;
  test_put_le32(&madt[68], 9u);
  madt[72] = 0x0du;
  madt[73] = 0;
  test_acpi_set_checksum(madt, (UINTN)sizeof(madt), 9u);

  test_put_le32(&mcfg[0], er_acpi_signature("MCFG"));
  test_put_le32(&mcfg[4], (UINT32)sizeof(mcfg));
  mcfg[8] = 1;
  test_put_le64(&mcfg[44], 0xe0000000ull);
  mcfg[52] = 0;
  mcfg[53] = 0;
  mcfg[54] = 0;
  mcfg[55] = 63;
  test_acpi_set_checksum(mcfg, (UINTN)sizeof(mcfg), 9u);

  test_put_le32(&hpet[0], er_acpi_signature("HPET"));
  test_put_le32(&hpet[4], (UINT32)sizeof(hpet));
  hpet[8] = 1;
  test_put_le32(&hpet[36], 0x8086u << 16 | 1u << 13 | 2u << 8 | 0x01u);
  hpet[40] = 0;
  hpet[41] = 64;
  hpet[42] = 0;
  hpet[43] = 3;
  test_put_le64(&hpet[44], 0xfed00000ull);
  hpet[52] = 0;
  hpet[53] = 0x80u;
  hpet[54] = 0x00u;
  hpet[55] = 0;
  test_acpi_set_checksum(hpet, (UINTN)sizeof(hpet), 9u);

  config[0].VendorGuid = acpi20;
  config[0].VendorTable = rsdp;
  st.NumberOfTableEntries = 1;
  st.ConfigurationTable = config;

  check_uint64("acpi sig", er_acpi_signature("XSDT"), 0x54445358u);
  check_int64("acpi checksum ok", er_acpi_checksum_valid(xsdt, (UINTN)sizeof(xsdt)), 1);
  check_int64("acpi find rsdp", er_acpi_find_rsdp(&st, &rsdp_info), 1);
  check_int64("acpi rsdp found", rsdp_info.found, 1);
  check_int64("acpi rsdp revision", rsdp_info.revision, 2);
  check_int64("acpi rsdp checksum", rsdp_info.checksum_valid, 1);
  check_int64("acpi xsdt checksum", rsdp_info.xsdt_checksum_valid, 1);
  check_uint64("acpi xsdt address", rsdp_info.xsdt_address, (UINT64)(UINTN)xsdt);

  check_int64("acpi enumerate", er_acpi_enumerate_tables(&rsdp_info, &table_list), 1);
  check_int64("acpi table list found", table_list.found, 1);
  check_int64("acpi table kind xsdt", table_list.table_kind, ER_ACPI_TABLE_KIND_XSDT);
  check_uint64("acpi table count", table_list.table_count, 4u);
  check_uint64("acpi table sig", table_list.tables[0].signature, er_acpi_signature("FACP"));
  check_uint64("acpi table address", table_list.tables[0].address, (UINT64)(UINTN)fadt);
  check_int64("acpi table checksum", table_list.tables[0].checksum_valid, 1);
  check_int64("acpi find fadt", er_acpi_find_table(&table_list, er_acpi_signature("FACP"), &found_table), 1);
  check_int64("acpi parse fadt", er_acpi_parse_fadt(found_table.address, &fadt_info), 1);
  check_int64("acpi fadt found", fadt_info.found, 1);
  check_int64("acpi fadt checksum", fadt_info.checksum_valid, 1);
  check_uint64("acpi fadt sci", fadt_info.sci_interrupt, 9u);
  check_uint64("acpi fadt smi", fadt_info.smi_command_port, 0xb2u);
  check_uint64("acpi fadt pm timer", fadt_info.pm_timer_block, 0x408u);
  check_uint64("acpi fadt boot arch", fadt_info.boot_architecture_flags, 3u);
  check_uint64("acpi fadt flags", fadt_info.flags, 1u);
  check_uint64("acpi fadt reset space", fadt_info.reset_register.address_space_id, 1u);
  check_uint64("acpi fadt reset addr", fadt_info.reset_register.address, 0xcf9u);
  check_uint64("acpi fadt reset value", fadt_info.reset_value, 0x06u);
  check_int64("acpi find madt", er_acpi_find_table(&table_list, er_acpi_signature("APIC"), &found_table), 1);
  check_uint64("acpi madt address", found_table.address, (UINT64)(UINTN)madt);
  check_int64("acpi parse madt", er_acpi_parse_madt(found_table.address, &madt_info), 1);
  check_int64("acpi madt found", madt_info.found, 1);
  check_int64("acpi madt checksum", madt_info.checksum_valid, 1);
  check_uint64("acpi madt lapic addr", madt_info.lapic_address, 0xfee00000u);
  check_uint64("acpi madt flags", madt_info.flags, 1u);
  check_uint64("acpi madt lapic count", madt_info.lapic_count, 1u);
  check_uint64("acpi madt lapic apic id", madt_info.lapics[0].apic_id, 3u);
  check_uint64("acpi madt ioapic count", madt_info.ioapic_count, 1u);
  check_uint64("acpi madt ioapic addr", madt_info.ioapics[0].address, 0xfec00000u);
  check_uint64("acpi madt iso count", madt_info.interrupt_source_override_count, 1u);
  check_uint64("acpi madt iso gsi", madt_info.interrupt_source_overrides[0].global_system_interrupt, 9u);
  check_uint64("acpi madt iso flags", madt_info.interrupt_source_overrides[0].flags, 0x0du);
  check_int64("acpi find mcfg", er_acpi_find_table(&table_list, er_acpi_signature("MCFG"), &found_table), 1);
  check_uint64("acpi mcfg address", found_table.address, (UINT64)(UINTN)mcfg);
  check_int64("acpi parse mcfg", er_acpi_parse_mcfg(found_table.address, &mcfg_info), 1);
  check_int64("acpi mcfg found", mcfg_info.found, 1);
  check_int64("acpi mcfg checksum", mcfg_info.checksum_valid, 1);
  check_uint64("acpi mcfg count", mcfg_info.allocation_count, 1u);
  check_uint64("acpi mcfg base", mcfg_info.allocations[0].base_address, 0xe0000000ull);
  check_uint64("acpi mcfg end bus", mcfg_info.allocations[0].end_bus, 63u);
  check_int64("acpi mcfg ecam",
              er_acpi_mcfg_config_address(&mcfg_info, 0u, 2u, 3u, 4u, 0x10u, &ecam_address),
              1);
  check_uint64("acpi mcfg ecam address", ecam_address,
               0xe0000000ull + (2ull * 0x100000ull) + (3ull * 0x8000ull) + (4ull * 0x1000ull) + 0x10ull);
  check_int64("acpi mcfg reject bus",
              er_acpi_mcfg_config_address(&mcfg_info, 0u, 64u, 0u, 0u, 0u, &ecam_address),
              0);
  er_mem_zero((UINT8*)pci_ecam, (UINTN)sizeof(pci_ecam));
  mcfg_info.allocations[0].base_address = (UINT64)(UINTN)pci_ecam;
  mcfg_info.allocations[0].end_bus = 0u;
  pci_ecam[ER_PCI_ID_OFFSET / sizeof(UINT32)] = PCI_TEST_DEVICE_ID;
  check_int64("pci configure mcfg", er_pci_configure_mcfg(&mcfg_info), 1);
  check_uint64("pci ecam read id", er_pci_cfg_read32(0u, 0u, 0u, ER_PCI_ID_OFFSET),
               PCI_TEST_DEVICE_ID);
  er_pci_write32(0u, 0u, 0u, ER_PCI_COMMAND_STATUS_OFFSET, PCI_TEST_COMMAND_VALUE);
  check_uint64("pci ecam write command",
               pci_ecam[ER_PCI_COMMAND_STATUS_OFFSET / sizeof(UINT32)],
               PCI_TEST_COMMAND_VALUE);
  check_uint64("pci ecam reject bus", er_pci_cfg_read32(1u, 0u, 0u, ER_PCI_ID_OFFSET),
               PCI_TEST_INVALID_ID);
  check_int64("pci clear mcfg", er_pci_configure_mcfg(0), 0);
  check_int64("acpi find hpet", er_acpi_find_table(&table_list, er_acpi_signature("HPET"), &found_table), 1);
  check_uint64("acpi hpet address", found_table.address, (UINT64)(UINTN)hpet);
  check_int64("acpi parse hpet", er_acpi_parse_hpet(found_table.address, &hpet_info), 1);
  check_int64("acpi hpet found", hpet_info.found, 1);
  check_int64("acpi hpet checksum", hpet_info.checksum_valid, 1);
  check_uint64("acpi hpet rev", hpet_info.hardware_rev_id, 1u);
  check_uint64("acpi hpet timers", hpet_info.comparator_count, 3u);
  check_uint64("acpi hpet bits64", hpet_info.counter_size_64, 1u);
  check_uint64("acpi hpet vendor", hpet_info.pci_vendor_id, 0x8086u);
  check_uint64("acpi hpet mmio", hpet_info.address, 0xfed00000ull);
  check_uint64("acpi hpet min tick", hpet_info.minimum_tick, 0x80u);
  check_int64("acpi find missing", er_acpi_find_table(&table_list, er_acpi_signature("SSDT"), &found_table), 0);

  rsdp_info.checksum_valid = 0;
  check_int64("acpi reject bad rsdp", er_acpi_enumerate_tables(&rsdp_info, &table_list), 0);
}

static void test_tpm_crb_direct_transport(void) {
  static UINT8 tpm2[52];
  static UINT8 crb[4096];
  static UINT8 command_buffer[256];
  static UINT8 response_buffer[256];
  ErTpm2Info info;
  ErTpmCrbTransport transport;
  ErTpmP256Primary primary;
  ErTpmAlgorithmProfile algorithms;
  ErTpmCommandProfile commands;
  ErTpmNvLimits limits;
  UINT8 command[128];
  UINT8 response[256];
  UINT8 random[32];
  UINT8 digest[32];
  UINT8 signature[64];
  UINT32 cipher_len = 0u;
  UINT32 iv_len = 0u;
  UINT32 command_len = 0u;
  UINT32 response_len = 0u;
  UINT32 random_len = 0u;
  UINT32 response_body_len;
  UINT32 offset;
  UINT16 selected_mode = 0u;

  er_mem_zero(tpm2, (UINTN)sizeof(tpm2));
  er_mem_zero(crb, (UINTN)sizeof(crb));
  er_mem_zero(command_buffer, (UINTN)sizeof(command_buffer));
  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  test_fill_bytes(digest, (UINTN)sizeof(digest), 0x31u);

  test_put_le32(&tpm2[0], er_acpi_signature("TPM2"));
  test_put_le32(&tpm2[4], (UINT32)sizeof(tpm2));
  tpm2[8] = 4u;
  test_put_le64(&tpm2[40], (UINT64)(UINTN)crb);
  test_put_le32(&tpm2[48], 6u);
  test_acpi_set_checksum(tpm2, (UINTN)sizeof(tpm2), 9u);

  check_int64("tpm parse tpm2",
              er_tpm_parse_tpm2_table((UINT64)(UINTN)tpm2, &info), 1);
  check_int64("tpm info found", info.found, 1);
  check_int64("tpm info crb", er_tpm2_info_is_crb(&info), 1);
  check_uint64("tpm control area", info.control_area, (UINT64)(UINTN)crb);

  test_put_le32(&crb[0x58], (UINT32)sizeof(command_buffer));
  test_put_le64(&crb[0x5c], (UINT64)(UINTN)command_buffer);
  test_put_le32(&crb[0x64], (UINT32)sizeof(response_buffer));
  test_put_le64(&crb[0x68], (UINT64)(UINTN)response_buffer);
  check_int64("tpm crb from base",
              er_tpm_crb_from_register_base((UINT64)(UINTN)crb, &transport), 1);
  transport.timeout_polls = 0u;
  check_uint64("tpm crb command buffer", transport.command_buffer,
               (UINT64)(UINTN)command_buffer);
  check_uint64("tpm crb response buffer", transport.response_buffer,
               (UINT64)(UINTN)response_buffer);

  check_int64("tpm startup command",
              er_tpm_build_startup_command(ER_TPM_SU_CLEAR, command,
                                           (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm startup command len", command_len, 12u);
  check_uint64("tpm startup tag", command[0], 0x80u);
  check_uint64("tpm startup cc lo", command[9], 0x44u);

  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  response_buffer[2] = 0u;
  response_buffer[3] = 0u;
  response_buffer[4] = 0u;
  response_buffer[5] = 10u;
  response_buffer[6] = 0u;
  response_buffer[7] = 0u;
  response_buffer[8] = 0u;
  response_buffer[9] = 0u;
  check_int64("tpm crb transact",
              er_tpm_crb_transact(&transport, command, command_len,
                                  response, (UINT32)sizeof(response),
                                  &response_len),
              1);
  check_uint64("tpm crb response len", response_len, 10u);
  check_uint64("tpm crb copied command cc", command_buffer[9], 0x44u);
  check_uint64("tpm response code", er_tpm_response_code(response, response_len),
               ER_TPM_RC_SUCCESS);

  check_int64("tpm get random command",
              er_tpm_build_get_random_command(4u, command,
                                              (UINT32)sizeof(command),
                                              &command_len),
              1);
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  response_buffer[2] = 0u;
  response_buffer[3] = 0u;
  response_buffer[4] = 0u;
  response_buffer[5] = 16u;
  response_buffer[6] = 0u;
  response_buffer[7] = 0u;
  response_buffer[8] = 0u;
  response_buffer[9] = 0u;
  response_buffer[10] = 0u;
  response_buffer[11] = 4u;
  response_buffer[12] = 0xaau;
  response_buffer[13] = 0xbbu;
  response_buffer[14] = 0xccu;
  response_buffer[15] = 0xddu;
  check_int64("tpm random transact",
              er_tpm_crb_transact(&transport, command, command_len,
                                  response, (UINT32)sizeof(response),
                                  &response_len),
              1);
  check_int64("tpm parse random",
              er_tpm_parse_get_random_response(response, response_len, random,
                                               (UINT32)sizeof(random), &random_len),
              1);
  check_uint64("tpm random len", random_len, 4u);
  check_uint64("tpm random byte0", random[0], 0xaau);
  check_uint64("tpm random byte3", random[3], 0xddu);

  check_int64("tpm hash command",
              er_tpm_build_hash_sha256_command(random, 4u, ER_TPM_RH_NULL,
                                               command, (UINT32)sizeof(command),
                                               &command_len),
              1);
  check_uint64("tpm hash command len", command_len, 22u);
  check_uint64("tpm hash command code", command[9], 0x7du);
  check_uint64("tpm hash data len", command[11], 4u);
  check_uint64("tpm hash data byte0", command[12], random[0]);
  check_uint64("tpm hash algorithm", command[17], ER_TPM_ALG_SHA256);
  check_uint64("tpm hash hierarchy lo", command[21], 0x07u);
  check_int64("tpm hash rejects oversized command",
              er_tpm_build_hash_sha256_command(random, 0xffffu, ER_TPM_RH_NULL,
                                               command, (UINT32)sizeof(command),
                                               &command_len),
              0);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 44u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be16(response_buffer + 10u, ER_TPM_SHA256_DIGEST_LEN);
  test_fill_bytes(response_buffer + 12u, ER_TPM_SHA256_DIGEST_LEN, 0x22u);
  check_int64("tpm parse hash digest",
              er_tpm_parse_sha256_digest_response(response_buffer, 44u, digest),
              1);
  check_uint64("tpm hash digest byte0", digest[0], 0x22u);
  check_uint64("tpm hash digest byte31", digest[31], 0x41u);

  check_int64("tpm get alg capability command",
              er_tpm_build_get_capability_command(ER_TPM_CAP_ALGS,
                                                  ER_TPM_ALG_SHA256, 11u,
                                                  command, (UINT32)sizeof(command),
                                                  &command_len),
              1);
  check_uint64("tpm get alg capability len", command_len, 22u);
  check_uint64("tpm get alg capability code", command[9], 0x7au);
  check_uint64("tpm get alg capability cap", command[13], ER_TPM_CAP_ALGS);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 85u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  response_buffer[10] = 0u;
  test_put_be32(response_buffer + 11u, ER_TPM_CAP_ALGS);
  test_put_be32(response_buffer + 15u, 11u);
  offset = 19u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_SHA256);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_HMAC);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_KEYEDHASH);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECC);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECDH);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECDSA);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_AES);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_SYMCIPHER);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_CTR);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_CBC);
  offset += 6u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_CFB);
  check_int64("tpm parse algorithm profile",
              er_tpm_parse_algorithm_profile_response(response_buffer, 85u,
                                                      &algorithms),
              1);
  check_uint64("tpm profile sha256", algorithms.has_sha256, 1u);
  check_uint64("tpm profile hmac", algorithms.has_hmac, 1u);
  check_uint64("tpm profile keyedhash", algorithms.has_keyedhash, 1u);
  check_uint64("tpm profile ecdh", algorithms.has_ecdh, 1u);
  check_uint64("tpm profile symcipher", algorithms.has_symcipher, 1u);
  check_uint64("tpm profile ctr", algorithms.has_ctr, 1u);
  check_uint64("tpm profile cbc", algorithms.has_cbc, 1u);
  check_uint64("tpm profile cfb", algorithms.has_cfb, 1u);
  check_int64("tpm select record mode",
              er_tpm_select_record_cipher_mode(&algorithms, &selected_mode), 1);
  check_uint64("tpm selected record mode", selected_mode, ER_TPM_ALG_CTR);

  check_int64("tpm get command capability command",
              er_tpm_build_get_capability_command(ER_TPM_CAP_COMMANDS,
                                                  ER_TPM_CC_CREATE_PRIMARY, 9u,
                                                  command, (UINT32)sizeof(command),
                                                  &command_len),
              1);
  check_uint64("tpm get command capability len", command_len, 22u);
  check_uint64("tpm get command capability cap", command[13], ER_TPM_CAP_COMMANDS);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 67u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  response_buffer[10] = 0u;
  test_put_be32(response_buffer + 11u, ER_TPM_CAP_COMMANDS);
  test_put_be32(response_buffer + 15u, 12u);
  offset = 19u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_CREATE_PRIMARY);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_ECDH_ZGEN);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_ENCRYPT_DECRYPT2);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_GET_RANDOM);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_HASH);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_HASH_SEQUENCE_START);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_HMAC);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_LOAD_EXTERNAL);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_SEQUENCE_COMPLETE);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_SEQUENCE_UPDATE);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_SIGN);
  offset += 4u;
  test_put_be32(response_buffer + offset, ER_TPM_CC_VERIFY_SIGNATURE);
  check_int64("tpm parse command profile",
              er_tpm_parse_command_profile_response(response_buffer, 67u,
                                                    &commands),
              1);
  check_uint64("tpm command profile create primary", commands.has_create_primary, 1u);
  check_uint64("tpm command profile encrypt decrypt2", commands.has_encrypt_decrypt2, 1u);
  check_uint64("tpm command profile sequence start", commands.has_hash_sequence_start, 1u);
  check_uint64("tpm command profile sequence complete", commands.has_sequence_complete, 1u);
  check_uint64("tpm command profile sequence update", commands.has_sequence_update, 1u);
  check_uint64("tpm command profile verify", commands.has_verify_signature, 1u);

  check_int64("tpm tls profile supported",
              er_tpm_tls_compat_profile_supported(&info, &algorithms, &commands), 1);
  algorithms.has_ctr = 0u;
  algorithms.has_cbc = 0u;
  algorithms.has_cfb = 0u;
  selected_mode = ER_TPM_ALG_CTR;
  check_int64("tpm select record mode rejects none",
              er_tpm_select_record_cipher_mode(&algorithms, &selected_mode), 0);
  check_uint64("tpm rejected record mode cleared", selected_mode, ER_TPM_ALG_NULL);
  check_int64("tpm tls profile rejects missing record mode",
              er_tpm_tls_compat_profile_supported(&info, &algorithms, &commands), 0);
  algorithms.has_ctr = 1u;
  algorithms.has_symcipher = 0u;
  check_int64("tpm tls profile rejects missing symcipher",
              er_tpm_tls_compat_profile_supported(&info, &algorithms, &commands), 0);
  algorithms.has_symcipher = 1u;
  algorithms.has_keyedhash = 0u;
  check_int64("tpm tls profile rejects missing keyedhash",
              er_tpm_tls_compat_profile_supported(&info, &algorithms, &commands), 0);
  algorithms.has_keyedhash = 1u;
  commands.has_encrypt_decrypt2 = 0u;
  check_int64("tpm tls profile rejects missing record command",
              er_tpm_tls_compat_profile_supported(&info, &algorithms, &commands), 0);

  check_int64("tpm get capability command",
              er_tpm_build_get_capability_command(ER_TPM_CAP_TPM_PROPERTIES,
                                                  ER_TPM_PT_NV_INDEX_MAX, 2u,
                                                  command, (UINT32)sizeof(command),
                                                  &command_len),
              1);
  check_uint64("tpm get capability len", command_len, 22u);
  check_uint64("tpm get capability code", command[9], 0x7au);
  check_uint64("tpm get capability property", command[17], 0x17u);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 35u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  response_buffer[10] = 0u;
  test_put_be32(response_buffer + 11u, ER_TPM_CAP_TPM_PROPERTIES);
  test_put_be32(response_buffer + 15u, 2u);
  test_put_be32(response_buffer + 19u, ER_TPM_PT_NV_INDEX_MAX);
  test_put_be32(response_buffer + 23u, 1600u);
  test_put_be32(response_buffer + 27u, ER_TPM_PT_NV_BUFFER_MAX);
  test_put_be32(response_buffer + 31u, 1024u);
  check_int64("tpm parse nv limits",
              er_tpm_parse_nv_storage_limits_response(response_buffer, 35u,
                                                      &limits),
              1);
  check_uint64("tpm nv index max present", limits.has_nv_index_max, 1u);
  check_uint64("tpm nv index max", limits.nv_index_max, 1600u);
  check_uint64("tpm nv buffer max present", limits.has_nv_buffer_max, 1u);
  check_uint64("tpm nv buffer max", limits.nv_buffer_max, 1024u);

  check_int64("tpm create primary command",
              er_tpm_build_create_primary_p256_signing_command(
                  command, (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm create primary len", command_len, 65u);
  check_uint64("tpm create primary command code", command[9], 0x31u);
  check_uint64("tpm create primary owner", command[13], 0x01u);
  check_uint64("tpm create primary auth bytes", command[17], 9u);
  check_uint64("tpm create primary ecc type", command[35], 0x00u);
  check_uint64("tpm create primary ecc type lo", command[36], 0x23u);

  check_int64("tpm create primary ecdh command",
              er_tpm_build_create_primary_p256_ecdh_command(
                  command, (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm create primary ecdh len", command_len, 65u);
  check_uint64("tpm create primary ecdh decrypt attr", command[40], 0x02u);
  check_uint64("tpm create primary ecdh scheme", command[48], ER_TPM_ALG_ECDH);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x02u;
  test_put_be32(response_buffer + 2u, 126u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, 0x80000000u);
  test_put_be32(response_buffer + 14u, 90u);
  offset = 18u;
  test_put_be16(response_buffer + offset, 88u);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECC);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_SHA256);
  offset += 2u;
  test_put_be32(response_buffer + offset, 0x00040472u);
  offset += 4u;
  test_put_be16(response_buffer + offset, 0u);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_NULL);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECDSA);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_SHA256);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ECC_NIST_P256);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_NULL);
  offset += 2u;
  test_put_be16(response_buffer + offset, 32u);
  offset += 2u;
  test_fill_bytes(response_buffer + offset, 32u, 0x71u);
  offset += 32u;
  test_put_be16(response_buffer + offset, 32u);
  offset += 2u;
  test_fill_bytes(response_buffer + offset, 32u, 0x91u);
  check_int64("tpm parse create primary",
              er_tpm_parse_create_primary_p256_response(response_buffer, 126u,
                                                        &primary),
              1);
  check_uint64("tpm primary handle", primary.handle, 0x80000000u);
  check_uint64("tpm primary public x0", primary.public_key[0], 0x71u);
  check_uint64("tpm primary public y0", primary.public_key[32], 0x91u);

  check_int64("tpm load external p256 verify command",
              er_tpm_build_load_external_p256_verify_key_command(
                  primary.public_key, command, (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm load external p256 len", command_len, 106u);
  check_uint64("tpm load external command code", command[9], 0x67u);
  check_uint64("tpm load external public size", command[13], 88u);
  check_uint64("tpm load external ecc type", command[15], ER_TPM_ALG_ECC);
  check_uint64("tpm load external scheme", command[27], ER_TPM_ALG_ECDSA);
  check_uint64("tpm load external x size", command[35], 32u);
  check_uint64("tpm load external x byte0", command[36], primary.public_key[0]);
  check_uint64("tpm load external y byte0", command[70], primary.public_key[32]);
  check_uint64("tpm load external hierarchy lo", command[105], 0x07u);

  test_fill_bytes(digest, ER_TPM_SHA256_DIGEST_LEN, 0xc0u);
  check_int64("tpm load external hmac key command",
              er_tpm_build_load_external_hmac_sha256_key_command(
                  digest, ER_TPM_SHA256_DIGEST_LEN,
                  command, (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm load external hmac len", command_len, 74u);
  check_uint64("tpm load external hmac command code", command[9], 0x67u);
  check_uint64("tpm load external hmac sensitive size", command[11], 40u);
  check_uint64("tpm load external hmac sensitive type", command[13],
               ER_TPM_ALG_KEYEDHASH);
  check_uint64("tpm load external hmac key size", command[19],
               ER_TPM_SHA256_DIGEST_LEN);
  check_uint64("tpm load external hmac key byte0", command[20], digest[0]);
  check_uint64("tpm load external hmac public size", command[53], 16u);
  check_uint64("tpm load external hmac public type", command[55],
               ER_TPM_ALG_KEYEDHASH);
  check_uint64("tpm load external hmac public attrs", command[61], 0x40u);
  check_uint64("tpm load external hmac scheme", command[65], ER_TPM_ALG_HMAC);
  check_uint64("tpm load external hmac hash", command[67], ER_TPM_ALG_SHA256);
  check_uint64("tpm load external hmac hierarchy lo", command[73], 0x07u);
  check_int64("tpm load external hmac rejects oversized key",
              er_tpm_build_load_external_hmac_sha256_key_command(
                  digest, 0xfff8u, command, (UINT32)sizeof(command), &command_len),
              0);

  test_fill_bytes(signature, ER_TPM_AES_128_KEY_LEN, 0xd0u);
  check_int64("tpm load external aes key command",
              er_tpm_build_load_external_aes_key_command(
                  signature, ER_TPM_AES_128_KEY_LEN,
                  ER_TPM_AES_128_KEY_BITS, ER_TPM_ALG_CTR,
                  command, (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm load external aes len", command_len, 60u);
  check_uint64("tpm load external aes sensitive size", command[11], 24u);
  check_uint64("tpm load external aes sensitive type", command[13],
               ER_TPM_ALG_SYMCIPHER);
  check_uint64("tpm load external aes key size", command[19],
               ER_TPM_AES_128_KEY_LEN);
  check_uint64("tpm load external aes key byte0", command[20], signature[0]);
  check_uint64("tpm load external aes public size", command[37], 18u);
  check_uint64("tpm load external aes public type", command[39],
               ER_TPM_ALG_SYMCIPHER);
  check_uint64("tpm load external aes public attrs", command[45], 0x40u);
  check_uint64("tpm load external aes algorithm", command[49], ER_TPM_ALG_AES);
  check_uint64("tpm load external aes key bits", command[51],
               ER_TPM_AES_128_KEY_BITS);
  check_uint64("tpm load external aes mode", command[53], ER_TPM_ALG_CTR);
  check_uint64("tpm load external aes hierarchy lo", command[59], 0x07u);
  check_int64("tpm load external aes rejects mismatched key bits",
              er_tpm_build_load_external_aes_key_command(
                  signature, ER_TPM_AES_128_KEY_LEN,
                  ER_TPM_AES_256_KEY_BITS, ER_TPM_ALG_CTR,
                  command, (UINT32)sizeof(command), &command_len),
              0);
  check_int64("tpm load external aes rejects unknown mode",
              er_tpm_build_load_external_aes_key_command(
                  signature, ER_TPM_AES_128_KEY_LEN,
                  ER_TPM_AES_128_KEY_BITS, ER_TPM_ALG_KEYEDHASH,
                  command, (UINT32)sizeof(command), &command_len),
              0);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 14u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, 0x80000004u);
  check_int64("tpm parse handle",
              er_tpm_parse_handle_response(response_buffer, 14u, &primary.handle),
              1);
  check_uint64("tpm parsed handle", primary.handle, 0x80000004u);

  check_int64("tpm read public command",
              er_tpm_build_read_public_command(0x81000001u, command,
                                               (UINT32)sizeof(command),
                                               &command_len),
              1);
  check_uint64("tpm read public len", command_len, 14u);
  check_uint64("tpm read public handle hi", command[10], 0x81u);

  check_int64("tpm sign command",
              er_tpm_build_sign_p256_sha256_command(0x81000001u, digest,
                                                    command, (UINT32)sizeof(command),
                                                    &command_len),
              1);
  check_uint64("tpm sign command len", command_len, 73u);
  check_uint64("tpm sign tag sessions", command[1], 0x02u);
  check_uint64("tpm sign digest byte0", command[29], digest[0]);

  test_fill_bytes(signature, (UINTN)sizeof(signature), 0x24u);
  check_int64("tpm verify p256 command",
              er_tpm_build_verify_p256_sha256_command(0x80000004u, digest, signature,
                                                      command, (UINT32)sizeof(command),
                                                      &command_len),
              1);
  check_uint64("tpm verify p256 len", command_len, 120u);
  check_uint64("tpm verify p256 command code", command[9], 0x77u);
  check_uint64("tpm verify p256 digest len", command[15], 32u);
  check_uint64("tpm verify p256 digest byte0", command[16], digest[0]);
  check_uint64("tpm verify p256 scheme", command[49], ER_TPM_ALG_ECDSA);
  check_uint64("tpm verify p256 r size", command[53], 32u);
  check_uint64("tpm verify p256 r byte0", command[54], signature[0]);
  check_uint64("tpm verify p256 s byte0", command[88], signature[32]);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 18u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be16(response_buffer + 10u, ER_TPM_ST_HASHCHECK);
  test_put_be32(response_buffer + 12u, ER_TPM_RH_NULL);
  test_put_be16(response_buffer + 16u, 0u);
  check_int64("tpm parse verify ticket",
              er_tpm_parse_verify_ticket_response(response_buffer, 18u),
              1);

  test_fill_bytes(signature, ER_TPM_AES_BLOCK_LEN, 0x90u);
  check_int64("tpm encrypt decrypt2 command",
              er_tpm_build_encrypt_decrypt2_command(0x80000005u, 0u, ER_TPM_ALG_CTR,
                                                    signature, ER_TPM_AES_BLOCK_LEN,
                                                    random, ER_TPM_AES_BLOCK_LEN,
                                                    command, (UINT32)sizeof(command),
                                                    &command_len),
              1);
  check_uint64("tpm encrypt decrypt2 len", command_len, 66u);
  check_uint64("tpm encrypt decrypt2 command code", command[9], 0x93u);
  check_uint64("tpm encrypt decrypt2 auth size", command[17], 9u);
  check_uint64("tpm encrypt decrypt2 decrypt flag", command[27], 0u);
  check_uint64("tpm encrypt decrypt2 mode", command[29], ER_TPM_ALG_CTR);
  check_uint64("tpm encrypt decrypt2 iv size", command[31], ER_TPM_AES_BLOCK_LEN);
  check_uint64("tpm encrypt decrypt2 iv byte0", command[32], signature[0]);
  check_uint64("tpm encrypt decrypt2 input size", command[49], ER_TPM_AES_BLOCK_LEN);
  check_uint64("tpm encrypt decrypt2 input byte0", command[50], random[0]);
  check_int64("tpm encrypt decrypt2 rejects oversized command",
              er_tpm_build_encrypt_decrypt2_command(
                  0x80000005u, 0u, ER_TPM_ALG_CTR,
                  signature, 0xffffu,
                  random, ER_TPM_AES_BLOCK_LEN,
                  command, (UINT32)sizeof(command), &command_len),
              0);
  check_int64("tpm encrypt decrypt2 rejects unknown mode",
              er_tpm_build_encrypt_decrypt2_command(
                  0x80000005u, 0u, ER_TPM_ALG_KEYEDHASH,
                  signature, ER_TPM_AES_BLOCK_LEN,
                  random, ER_TPM_AES_BLOCK_LEN,
                  command, (UINT32)sizeof(command), &command_len),
              0);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x02u;
  test_put_be32(response_buffer + 2u, 50u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, 36u);
  test_put_be16(response_buffer + 14u, ER_TPM_AES_BLOCK_LEN);
  test_fill_bytes(response_buffer + 16u, ER_TPM_AES_BLOCK_LEN, 0xa0u);
  test_put_be16(response_buffer + 32u, ER_TPM_AES_BLOCK_LEN);
  test_fill_bytes(response_buffer + 34u, ER_TPM_AES_BLOCK_LEN, 0xb0u);
  check_int64("tpm parse encrypt decrypt2",
              er_tpm_parse_encrypt_decrypt2_response(response_buffer, 50u,
                                                     random, (UINT32)sizeof(random),
                                                     &cipher_len,
                                                     signature, (UINT32)sizeof(signature),
                                                     &iv_len),
              1);
  check_uint64("tpm encrypt decrypt2 data len", cipher_len, ER_TPM_AES_BLOCK_LEN);
  check_uint64("tpm encrypt decrypt2 data byte0", random[0], 0xa0u);
  check_uint64("tpm encrypt decrypt2 iv len", iv_len, ER_TPM_AES_BLOCK_LEN);
  check_uint64("tpm encrypt decrypt2 iv byte0 parsed", signature[0], 0xb0u);

  check_int64("tpm hmac command",
              er_tpm_build_hmac_sha256_command(0x81000002u, random, 4u,
                                               command, (UINT32)sizeof(command),
                                               &command_len),
              1);
  check_uint64("tpm hmac command len", command_len, 35u);
  check_uint64("tpm hmac command code", command[9], 0x55u);
  check_uint64("tpm hmac auth size", command[17], 9u);
  check_uint64("tpm hmac data len", command[28], 4u);
  check_uint64("tpm hmac data byte0", command[29], random[0]);
  check_uint64("tpm hmac algorithm", command[34], ER_TPM_ALG_SHA256);
  check_int64("tpm hmac rejects oversized command",
              er_tpm_build_hmac_sha256_command(0x81000002u, random, 0xffffu,
                                               command, (UINT32)sizeof(command),
                                               &command_len),
              0);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x02u;
  test_put_be32(response_buffer + 2u, 57u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, 34u);
  test_put_be16(response_buffer + 14u, ER_TPM_SHA256_DIGEST_LEN);
  test_fill_bytes(response_buffer + 16u, ER_TPM_SHA256_DIGEST_LEN, 0x33u);
  response_buffer[48] = 0x40u;
  response_buffer[49] = 0x00u;
  response_buffer[50] = 0x00u;
  response_buffer[51] = 0x09u;
  check_int64("tpm parse session digest",
              er_tpm_parse_sha256_digest_response(response_buffer, 57u, digest),
              1);
  check_uint64("tpm session digest byte0", digest[0], 0x33u);
  check_uint64("tpm session digest byte31", digest[31], 0x52u);

  test_fill_bytes(primary.public_key, ER_TPM_P256_PUBLIC_KEY_LEN, 0x81u);
  check_int64("tpm ecdh zgen command",
              er_tpm_build_ecdh_zgen_p256_command(0x81000003u, primary.public_key,
                                                  command, (UINT32)sizeof(command),
                                                  &command_len),
              1);
  check_uint64("tpm ecdh zgen command len", command_len, 97u);
  check_uint64("tpm ecdh zgen command code", command[9], 0x54u);
  check_uint64("tpm ecdh zgen point size", command[28], 68u);
  check_uint64("tpm ecdh zgen x size", command[30], 32u);
  check_uint64("tpm ecdh zgen x byte0", command[31], primary.public_key[0]);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  test_put_be32(response_buffer + 2u, 80u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be16(response_buffer + 10u, 68u);
  test_put_be16(response_buffer + 12u, 32u);
  test_fill_bytes(response_buffer + 14u, 32u, 0x44u);
  test_put_be16(response_buffer + 46u, 32u);
  test_fill_bytes(response_buffer + 48u, 32u, 0x64u);
  check_int64("tpm parse p256 point",
              er_tpm_parse_p256_point_response(response_buffer, 80u,
                                               primary.public_key),
              1);
  check_uint64("tpm p256 point x0", primary.public_key[0], 0x44u);
  check_uint64("tpm p256 point y0", primary.public_key[32], 0x64u);

  response_body_len = 4u + 2u + 31u + 2u + 32u;
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  response_buffer[2] = 0u;
  response_buffer[3] = 0u;
  response_buffer[4] = 0u;
  response_buffer[5] = (UINT8)(10u + response_body_len);
  response_buffer[6] = 0u;
  response_buffer[7] = 0u;
  response_buffer[8] = 0u;
  response_buffer[9] = 0u;
  response_buffer[10] = 0x00u;
  response_buffer[11] = 0x18u;
  response_buffer[12] = 0x00u;
  response_buffer[13] = 0x0bu;
  response_buffer[14] = 0u;
  response_buffer[15] = 31u;
  test_fill_bytes(response_buffer + 16u, 31u, 0x41u);
  response_buffer[47] = 0u;
  response_buffer[48] = 32u;
  test_fill_bytes(response_buffer + 49u, 32u, 0x61u);
  check_int64("tpm parse signature",
              er_tpm_parse_p256_sha256_signature_response(response_buffer,
                                                          10u + response_body_len,
                                                          signature),
              1);
  check_uint64("tpm signature pads r", signature[0], 0u);
  check_uint64("tpm signature r first", signature[1], 0x41u);
  check_uint64("tpm signature s first", signature[32], 0x61u);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x02u;
  test_put_be32(response_buffer + 2u, 10u + 4u + response_body_len + 9u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, response_body_len);
  response_buffer[14] = 0x00u;
  response_buffer[15] = 0x18u;
  response_buffer[16] = 0x00u;
  response_buffer[17] = 0x0bu;
  response_buffer[18] = 0u;
  response_buffer[19] = 31u;
  test_fill_bytes(response_buffer + 20u, 31u, 0x51u);
  response_buffer[51] = 0u;
  response_buffer[52] = 32u;
  test_fill_bytes(response_buffer + 53u, 32u, 0x71u);
  response_buffer[85] = 0x40u;
  response_buffer[86] = 0x00u;
  response_buffer[87] = 0x00u;
  response_buffer[88] = 0x09u;
  response_buffer[89] = 0u;
  response_buffer[90] = 0u;
  response_buffer[91] = 0u;
  response_buffer[92] = 0u;
  response_buffer[93] = 0u;
  check_int64("tpm parse sessions signature",
              er_tpm_parse_p256_sha256_signature_response(
                  response_buffer, 10u + 4u + response_body_len + 9u, signature),
              1);
  check_uint64("tpm sessions signature pads r", signature[0], 0u);
  check_uint64("tpm sessions signature r first", signature[1], 0x51u);
  check_uint64("tpm sessions signature s first", signature[32], 0x71u);

  check_int64("tpm flush command",
              er_tpm_build_flush_context_command(0x80000000u, command,
                                                 (UINT32)sizeof(command),
                                                 &command_len),
              1);
  check_uint64("tpm flush len", command_len, 14u);
  check_uint64("tpm flush code", command[9], 0x65u);
}

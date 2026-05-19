#include "test_core_internal.h"

static void test_bus_addresses(void) {
  uint32_t regs[2] = {0x11223344u, 0xaabbccddu};
  ErBusAddress pci;
  ErBusAddress mmio;
  ErBusAddress mmio_short;
  ErBusAddress ioport;
  ErBusOp32 op;
  ErBusPacket32 request;
  ErBusPacket32 response;
  ErBusIoPacket io_request;
  ErBusIoPacket io_response;
  UINT32 value = 0;
  UINT8 value8 = 0;
  UINT16 value16 = 0;

  check_uint64("driver abi bus address bytes",
               (UINT64)sizeof(ErBusAddress),
               ER_DRIVER_ABI_BUS_ADDRESS_BYTES);
  check_uint64("driver abi bus io packet bytes",
               (UINT64)sizeof(ErBusIoPacket),
               ER_DRIVER_ABI_BUS_PACKET_IO_BYTES);
  check_uint64("driver abi bus op32 packet bytes",
               (UINT64)sizeof(ErBusPacket32),
               ER_DRIVER_ABI_BUS_PACKET_OP32_BYTES);
  check_uint64("driver abi bus address kind offset",
               (UINT64)__builtin_offsetof(ErBusAddress, bus_kind),
               ER_DRIVER_ABI_BUS_ADDRESS_KIND_OFFSET);
  check_uint64("driver abi bus address mmio base offset",
               (UINT64)__builtin_offsetof(ErBusAddress, base),
               ER_DRIVER_ABI_BUS_ADDRESS_MMIO_BASE_OFFSET);
  check_uint64("driver abi bus packet op offset",
               (UINT64)__builtin_offsetof(ErBusIoPacket, op),
               ER_DRIVER_ABI_BUS_PACKET_OP_OFFSET);
  check_uint64("driver abi bus io op address offset",
               (UINT64)__builtin_offsetof(ErBusIoOp, address),
               ER_DRIVER_ABI_BUS_IO_OP_ADDRESS_OFFSET);
  check_uint64("driver abi bus io packet result offset",
               (UINT64)__builtin_offsetof(ErBusIoPacket, result),
               ER_DRIVER_ABI_BUS_PACKET_IO_RESULT_OFFSET);

  er_mmio_reset();

  check_int64("bus pci address",
              er_bus_prepare_pci_config_address(2u, 3u, 4u, ER_BUS_ACCESS_READ32, &pci),
              1);
  check_int64("bus pci kind", pci.bus_kind, ER_BUS_KIND_PCI_CONFIG);
  check_int64("bus pci supports read", er_bus_address_supports(&pci, ER_BUS_ACCESS_READ32), 1);
  check_int64("bus pci rejects write", er_bus_address_supports(&pci, ER_BUS_ACCESS_WRITE32), 0);
  check_int64("bus pci reject bad dev",
              er_bus_prepare_pci_config_address(0u, 32u, 0u, ER_BUS_ACCESS_READ32, &pci),
              0);

  check_int64("bus mmio address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)regs, (UINT64)sizeof(regs), 0u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL, &mmio),
              1);
  check_int64("bus mmio kind", mmio.bus_kind, ER_BUS_KIND_MMIO32);
  check_int64("bus mmio supports read", er_bus_address_supports(&mmio, ER_BUS_ACCESS_READ32), 1);
  check_int64("bus mmio supports write", er_bus_address_supports(&mmio, ER_BUS_ACCESS_WRITE32), 1);
  check_int64("bus mmio supports read8", er_bus_address_supports(&mmio, ER_BUS_ACCESS_READ8), 1);
  check_int64("bus mmio reject short",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)regs, 1u, 0u, ER_BUS_ACCESS_READ8, &mmio_short),
              1);

  check_int64("bus io port address",
              er_bus_prepare_io_port_address(0x0cf8u, ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL, &ioport),
              1);
  check_int64("bus io port kind", ioport.bus_kind, ER_BUS_KIND_IO_PORT);
  check_uint64("bus io port number", ioport.port, 0x0cf8u);
  check_int64("bus io port byte address",
              er_bus_prepare_io_port_address(0x0cf9u, ER_BUS_ACCESS_READ8, &ioport),
              1);
  check_int64("bus io port high byte address",
              er_bus_prepare_io_port_address(0xffffu, ER_BUS_ACCESS_READ8, &ioport),
              1);
  check_int64("bus io port reject high",
              er_bus_prepare_io_port_address(0x10000u, ER_BUS_ACCESS_READ8, &ioport),
              0);

  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = ER_BUS_KIND_MMIO32;
  op.access = ER_BUS_ACCESS_READ32;
  op.address = mmio;
  op.offset = 4u;
  op.value = 0;
  check_int64("bus op valid", er_bus_op32_valid(&op), 1);
  op.offset = 2u;
  check_int64("bus op reject unaligned", er_bus_op32_valid(&op), 0);
  op.offset = 8u;
  check_int64("bus op reject out of range", er_bus_op32_valid(&op), 0);

  check_int64("bus mmio read", er_bus_read32(&mmio, 0u, &value), 1);
  check_uint64("bus mmio read value", value, 0x11223344u);
  check_int64("bus mmio read8", er_bus_read8(&mmio, 1u, &value8), 1);
  check_uint64("bus mmio read8 value", value8, 0x33u);
  check_int64("bus mmio read16", er_bus_read16(&mmio, 2u, &value16), 1);
  check_uint64("bus mmio read16 value", value16, 0x1122u);
  check_int64("bus mmio write8", er_bus_write8(&mmio, 1u, 0x55u), 1);
  check_uint64("bus mmio write8 value", regs[0], 0x11225544u);
  check_int64("bus mmio write16", er_bus_write16(&mmio, 2u, 0x6677u), 1);
  check_uint64("bus mmio write16 value", regs[0], 0x66775544u);
  check_int64("bus mmio write", er_bus_write32(&mmio, 4u, 0x55667788u), 1);
  check_uint64("bus mmio write value", regs[1], 0x55667788u);

  mmio.access_flags = ER_BUS_ACCESS_READ_ALL;
  check_int64("bus mmio write denied", er_bus_write32(&mmio, 4u, 0x99u), 0);

  check_int64("bus packet read prepare",
              er_bus_prepare_op32_packet(7u, &mmio, ER_BUS_ACCESS_READ32, 0u, 0u, &request),
              1);
  check_int64("bus packet kind", request.packet_kind, ER_BUS_PACKET_OP32_REQUEST);
  check_uint64("bus packet id", request.packet_id, 7u);
  check_int64("bus packet execute read", er_bus_execute_op32_packet(&request, &response), 1);
  check_int64("bus packet response kind", response.packet_kind, ER_BUS_PACKET_OP32_RESPONSE);
  check_int64("bus packet response ok", response.status, ER_BUS_STATUS_OK);
  check_uint64("bus packet response copies packet id", response.packet_id, 7u);
  check_uint64("bus packet response copies address base", response.op.address.base, mmio.base);
  check_uint64("bus packet response copies address len", response.op.address.len, mmio.len);
  check_uint64("bus packet response copies offset", response.op.offset, 0u);
  check_uint64("bus packet response value", response.result, 0x66775544u);

  mmio.access_flags = ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL;
  check_int64("bus packet write prepare",
              er_bus_prepare_op32_packet(8u, &mmio, ER_BUS_ACCESS_WRITE32, 4u, 0x01010101u, &request),
              1);
  check_int64("bus packet execute write", er_bus_execute_op32_packet(&request, &response), 1);
  check_uint64("bus packet write value", regs[1], 0x01010101u);

  check_int64("bus packet reject invalid",
              er_bus_prepare_op32_packet(9u, &mmio, ER_BUS_ACCESS_READ32, 2u, 0u, &request),
              0);
  check_int64("bus io packet read8 prepare",
              er_bus_prepare_io_packet(10u, &mmio, ER_BUS_ACCESS_READ8, 1u, 1u, 0u, &io_request),
              1);
  check_int64("bus io packet read8 valid", er_bus_io_op_valid(&io_request.op), 1);
  check_int64("bus io packet read8 execute", er_bus_execute_io_packet(&io_request, &io_response), 1);
  check_int64("bus io packet response kind", io_response.packet_kind, ER_BUS_PACKET_IO_RESPONSE);
  check_uint64("bus io packet response copies packet id", io_response.packet_id, 10u);
  check_uint64("bus io packet response copies width", io_response.op.width, 1u);
  check_uint64("bus io packet response copies address base", io_response.op.address.base, mmio.base);
  check_uint64("bus io packet response copies offset", io_response.op.offset, 1u);
  check_uint64("bus io packet read8 result", io_response.result, 0x55u);
  check_int64("bus io packet reject width access mismatch",
              er_bus_prepare_io_packet(11u, &mmio, ER_BUS_ACCESS_READ16, 1u, 1u, 0u, &io_request),
              0);
}

static void test_driver_event_queue(void) {
  enum {
    DRIVER_EVENT_TEST_CAPACITY = 2u,
    DRIVER_EVENT_TEST_IRQ_SOURCE = 7u,
    DRIVER_EVENT_TEST_QUEUE_SOURCE = 9u,
    DRIVER_EVENT_TEST_DEVICE_SOURCE = 11u,
    DRIVER_EVENT_TEST_IRQ_ARG0 = 0x20u,
    DRIVER_EVENT_TEST_IRQ_ARG1 = 0x03u,
    DRIVER_EVENT_TEST_QUEUE_ARG0 = 1u,
    DRIVER_EVENT_TEST_QUEUE_ARG1 = 2u,
    DRIVER_EVENT_TEST_DEVICE_ARG0 = 0x44u,
    DRIVER_EVENT_TEST_DEVICE_ARG1 = 0x55u,
    DRIVER_EVENT_TEST_SECOND_SEQUENCE = 2u,
    DRIVER_EVENT_TEST_THIRD_SEQUENCE = 3u
  };
  ErDriverEvent events[DRIVER_EVENT_TEST_CAPACITY];
  ErDriverEventQueue queue;
  ErDriverEvent pushed;
  ErDriverEvent popped;
  ErDriverEvent rejected_event;

  check_uint64("driver abi event bytes",
               (UINT64)sizeof(ErDriverEvent),
               ER_DRIVER_ABI_EVENT_BYTES);
  check_uint64("driver abi event version offset",
               (UINT64)__builtin_offsetof(ErDriverEvent, abi_version),
               ER_DRIVER_ABI_EVENT_ABI_VERSION_OFFSET);
  check_uint64("driver abi event kind offset",
               (UINT64)__builtin_offsetof(ErDriverEvent, event_kind),
               ER_DRIVER_ABI_EVENT_KIND_OFFSET);
  check_uint64("driver abi event source offset",
               (UINT64)__builtin_offsetof(ErDriverEvent, source_id),
               ER_DRIVER_ABI_EVENT_SOURCE_ID_OFFSET);
  check_uint64("driver abi event sequence offset",
               (UINT64)__builtin_offsetof(ErDriverEvent, sequence),
               ER_DRIVER_ABI_EVENT_SEQUENCE_OFFSET);
  check_uint64("driver abi event arg0 offset",
               (UINT64)__builtin_offsetof(ErDriverEvent, arg0),
               ER_DRIVER_ABI_EVENT_ARG0_OFFSET);
  check_uint64("driver abi event arg1 offset",
               (UINT64)__builtin_offsetof(ErDriverEvent, arg1),
               ER_DRIVER_ABI_EVENT_ARG1_OFFSET);

  er_mem_zero((UINT8*)&queue, (UINTN)sizeof(queue));
  er_mem_zero((UINT8*)&pushed, (UINTN)sizeof(pushed));
  er_mem_zero((UINT8*)&popped, (UINTN)sizeof(popped));
  er_mem_zero((UINT8*)&rejected_event, (UINTN)sizeof(rejected_event));

  check_int64("driver event rejects none",
              er_driver_event_kind_valid(ER_DRIVER_EVENT_KIND_NONE),
              0);
  check_int64("driver event accepts irq",
              er_driver_event_kind_valid(ER_DRIVER_EVENT_KIND_IRQ),
              1);
  check_int64("driver event rejects null init",
              er_driver_event_queue_init(0, events, DRIVER_EVENT_TEST_CAPACITY),
              0);
  check_int64("driver event rejects zero capacity",
              er_driver_event_queue_init(&queue, events, 0u),
              0);
  check_int64("driver event init",
              er_driver_event_queue_init(&queue, events, DRIVER_EVENT_TEST_CAPACITY),
              1);
  check_int64("driver event empty after init",
              er_driver_event_queue_empty(&queue),
              1);
  check_int64("driver event not full after init",
              er_driver_event_queue_full(&queue),
              0);

  check_int64("driver event push irq",
              er_driver_event_push(&queue, ER_DRIVER_EVENT_KIND_IRQ,
                                   DRIVER_EVENT_TEST_IRQ_SOURCE,
                                   DRIVER_EVENT_TEST_IRQ_ARG0,
                                   DRIVER_EVENT_TEST_IRQ_ARG1, &pushed),
              1);
  check_uint64("driver event pushed version", pushed.abi_version, ER_DRIVER_EVENT_ABI_VERSION);
  check_uint64("driver event pushed kind", pushed.event_kind, ER_DRIVER_EVENT_KIND_IRQ);
  check_uint64("driver event pushed source", pushed.source_id, DRIVER_EVENT_TEST_IRQ_SOURCE);
  check_uint64("driver event first sequence", pushed.sequence, ER_DRIVER_EVENT_FIRST_SEQUENCE);
  check_uint64("driver event pushed arg0", pushed.arg0, DRIVER_EVENT_TEST_IRQ_ARG0);
  check_uint64("driver event pushed arg1", pushed.arg1, DRIVER_EVENT_TEST_IRQ_ARG1);

  check_int64("driver event push queue used",
              er_driver_event_push(&queue, ER_DRIVER_EVENT_KIND_QUEUE_USED,
                                   DRIVER_EVENT_TEST_QUEUE_SOURCE,
                                   DRIVER_EVENT_TEST_QUEUE_ARG0,
                                   DRIVER_EVENT_TEST_QUEUE_ARG1, 0),
              1);
  check_int64("driver event full",
              er_driver_event_queue_full(&queue),
              1);
  check_int64("driver event rejects overflow",
              er_driver_event_push(&queue, ER_DRIVER_EVENT_KIND_DEVICE,
                                   DRIVER_EVENT_TEST_DEVICE_SOURCE,
                                   DRIVER_EVENT_TEST_DEVICE_ARG0,
                                   DRIVER_EVENT_TEST_DEVICE_ARG1, &rejected_event),
              0);
  check_uint64("driver event overflow preserves out", rejected_event.sequence, 0u);
  check_uint64("driver event overflow preserves next sequence",
               queue.next_sequence,
               DRIVER_EVENT_TEST_THIRD_SEQUENCE);

  check_int64("driver event pop irq",
              er_driver_event_pop(&queue, &popped),
              1);
  check_uint64("driver event pop irq kind", popped.event_kind, ER_DRIVER_EVENT_KIND_IRQ);
  check_uint64("driver event pop irq sequence", popped.sequence, ER_DRIVER_EVENT_FIRST_SEQUENCE);
  check_uint64("driver event pop irq source", popped.source_id, DRIVER_EVENT_TEST_IRQ_SOURCE);

  check_int64("driver event push wraps",
              er_driver_event_push(&queue, ER_DRIVER_EVENT_KIND_DEVICE,
                                   DRIVER_EVENT_TEST_DEVICE_SOURCE,
                                   DRIVER_EVENT_TEST_DEVICE_ARG0,
                                   DRIVER_EVENT_TEST_DEVICE_ARG1, 0),
              1);
  check_int64("driver event pop queue used",
              er_driver_event_pop(&queue, &popped),
              1);
  check_uint64("driver event pop queue kind", popped.event_kind, ER_DRIVER_EVENT_KIND_QUEUE_USED);
  check_uint64("driver event pop queue sequence", popped.sequence, DRIVER_EVENT_TEST_SECOND_SEQUENCE);
  check_uint64("driver event pop queue source", popped.source_id, DRIVER_EVENT_TEST_QUEUE_SOURCE);
  check_int64("driver event pop device",
              er_driver_event_pop(&queue, &popped),
              1);
  check_uint64("driver event pop device kind", popped.event_kind, ER_DRIVER_EVENT_KIND_DEVICE);
  check_uint64("driver event pop device sequence", popped.sequence, DRIVER_EVENT_TEST_THIRD_SEQUENCE);
  check_uint64("driver event pop device source", popped.source_id, DRIVER_EVENT_TEST_DEVICE_SOURCE);
  check_int64("driver event empty after pops",
              er_driver_event_queue_empty(&queue),
              1);
  check_int64("driver event rejects empty pop",
              er_driver_event_pop(&queue, &popped),
              0);

  queue.next_sequence = ER_DRIVER_EVENT_SEQUENCE_MAX;
  check_int64("driver event rejects sequence exhaustion",
              er_driver_event_push(&queue, ER_DRIVER_EVENT_KIND_IRQ,
                                   DRIVER_EVENT_TEST_IRQ_SOURCE,
                                   DRIVER_EVENT_TEST_IRQ_ARG0,
                                   DRIVER_EVENT_TEST_IRQ_ARG1, &rejected_event),
              0);
}

static void test_driver_policy(void) {
  enum {
    DRIVER_POLICY_MEMORY_BYTES = 65536u,
    DRIVER_POLICY_MMIO_BASE = 4096u,
    DRIVER_POLICY_MMIO_LEN = 4u,
    DRIVER_POLICY_PACKET_ID = 21u
  };
  ErDriverAdmissionPolicy policy;
  ErBusAddress mmio;
  ErBusAddress denied_mmio;
  ErBusIoPacket packet;

  check_int64("driver policy prepare",
              er_driver_policy_prepare_mmio32(DRIVER_POLICY_MEMORY_BYTES,
                                              DRIVER_POLICY_MMIO_BASE,
                                              DRIVER_POLICY_MMIO_LEN,
                                              ER_BUS_ACCESS_READ8,
                                              &policy),
              1);
  check_int64("driver policy rejects zero memory",
              er_driver_policy_prepare_mmio32(0u, DRIVER_POLICY_MMIO_BASE,
                                              DRIVER_POLICY_MMIO_LEN,
                                              ER_BUS_ACCESS_READ8,
                                              &policy),
              0);
  check_int64("driver policy memory allowed",
              er_driver_policy_memory_allowed(&policy, DRIVER_POLICY_MEMORY_BYTES),
              1);
  check_int64("driver policy memory rejects larger",
              er_driver_policy_memory_allowed(&policy, DRIVER_POLICY_MEMORY_BYTES + 1u),
              0);

  check_int64("driver policy mmio address",
              er_bus_prepare_mmio32_address(DRIVER_POLICY_MMIO_BASE,
                                            DRIVER_POLICY_MMIO_LEN,
                                            0u, ER_BUS_ACCESS_READ8, &mmio),
              1);
  check_int64("driver policy packet",
              er_bus_prepare_io_packet(DRIVER_POLICY_PACKET_ID, &mmio,
                                       ER_BUS_ACCESS_READ8, 1u, 0u, 0u, &packet),
              1);
  check_int64("driver policy allows packet",
              er_driver_policy_bus_packet_allowed(&policy, &packet),
              1);
  check_int64("driver policy rejects write packet",
              er_bus_prepare_io_packet(DRIVER_POLICY_PACKET_ID, &mmio,
                                       ER_BUS_ACCESS_WRITE8, 1u, 0u, 0u, &packet),
              0);
  packet.op.access = ER_BUS_ACCESS_WRITE8;
  check_int64("driver policy denies write access",
              er_driver_policy_bus_packet_allowed(&policy, &packet),
              0);
  check_int64("driver policy denied address",
              er_bus_prepare_mmio32_address(DRIVER_POLICY_MMIO_BASE + DRIVER_POLICY_MMIO_LEN,
                                            DRIVER_POLICY_MMIO_LEN,
                                            0u, ER_BUS_ACCESS_READ8, &denied_mmio),
              1);
  check_int64("driver policy denied packet",
              er_bus_prepare_io_packet(DRIVER_POLICY_PACKET_ID, &denied_mmio,
                                       ER_BUS_ACCESS_READ8, 1u, 0u, 0u, &packet),
              1);
  check_int64("driver policy denies out of range",
              er_driver_policy_bus_packet_allowed(&policy, &packet),
              0);
}

static void test_virtio_mmio_transport(void) {
  enum {
    VIRTIO_TEST_MMIO_DWORDS = 128u,
    VIRTIO_TEST_QUEUE_INDEX = 3u,
    VIRTIO_TEST_QUEUE_MAX = 8u,
    VIRTIO_TEST_DESC_ADDR = 0x1122334455667788ull,
    VIRTIO_TEST_DRIVER_ADDR = 0x2233445566778899ull,
    VIRTIO_TEST_DEVICE_ADDR = 0x33445566778899aau,
    VIRTIO_TEST_INTERRUPT_STATUS = 3u
  };
  UINT32 regs[VIRTIO_TEST_MMIO_DWORDS] = {0};
  ErVirtioMmioTransport transport;
  ErVirtioMmioTransport rejected_transport;
  ErVirtioFeatureSet features;
  UINT16 queue_size = 0;
  UINT8 interrupt_status = 0;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_TEST_QUEUE_MAX;
  regs[ER_VIRTIO_MMIO_INTERRUPT_STATUS_OFFSET / sizeof(UINT32)] = VIRTIO_TEST_INTERRUPT_STATUS;

  check_int64("virtio mmio init",
              er_virtio_mmio_transport_init((UINT64)(UINTN)regs, (UINT64)sizeof(regs),
                                            ER_VIRTIO_DEVICE_TYPE_NET, &transport),
              1);
  check_uint64("virtio mmio device type", transport.device_type, ER_VIRTIO_DEVICE_TYPE_NET);
  check_int64("virtio mmio reject wrong type",
              er_virtio_mmio_transport_init((UINT64)(UINTN)regs, (UINT64)sizeof(regs),
                                            ER_VIRTIO_DEVICE_TYPE_BLK, &rejected_transport),
              0);
  check_int64("virtio mmio negotiate",
              er_virtio_mmio_negotiate_features(&transport, ER_VIRTIO_F_VERSION_1 | 1u, &features),
              1);
  check_uint64("virtio mmio host features", features.host, ER_VIRTIO_F_VERSION_1 | 1u);
  check_uint64("virtio mmio driver features", features.driver, ER_VIRTIO_F_VERSION_1 | 1u);
  check_uint64("virtio mmio status features ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER | ER_VIRTIO_STATUS_FEATURES_OK);
  check_uint64("virtio mmio driver feature selector",
               regs[ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET / sizeof(UINT32)],
               1u);
  check_uint64("virtio mmio driver feature high",
               regs[ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET / sizeof(UINT32)],
               1u);

  check_int64("virtio mmio configure queue",
              er_virtio_mmio_configure_split_queue(&transport, VIRTIO_TEST_QUEUE_INDEX,
                                                   ER_VIRTIO_QUEUE_SIZE, 1u,
                                                   VIRTIO_TEST_DESC_ADDR, VIRTIO_TEST_DRIVER_ADDR,
                                                   VIRTIO_TEST_DEVICE_ADDR, &queue_size),
              1);
  check_uint64("virtio mmio queue size", queue_size, VIRTIO_TEST_QUEUE_MAX);
  check_uint64("virtio mmio queue select",
               regs[ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET / sizeof(UINT32)], VIRTIO_TEST_QUEUE_INDEX);
  check_uint64("virtio mmio queue desc low",
               regs[ER_VIRTIO_MMIO_QUEUE_DESC_LOW_OFFSET / sizeof(UINT32)],
               (UINT32)VIRTIO_TEST_DESC_ADDR);
  check_uint64("virtio mmio queue desc high",
               regs[ER_VIRTIO_MMIO_QUEUE_DESC_HIGH_OFFSET / sizeof(UINT32)],
               (UINT32)(VIRTIO_TEST_DESC_ADDR >> 32));
  check_uint64("virtio mmio queue driver low",
               regs[ER_VIRTIO_MMIO_QUEUE_DRIVER_LOW_OFFSET / sizeof(UINT32)],
               (UINT32)VIRTIO_TEST_DRIVER_ADDR);
  check_uint64("virtio mmio queue device high",
               regs[ER_VIRTIO_MMIO_QUEUE_DEVICE_HIGH_OFFSET / sizeof(UINT32)],
               (UINT32)(VIRTIO_TEST_DEVICE_ADDR >> 32));
  check_uint64("virtio mmio queue ready",
               regs[ER_VIRTIO_MMIO_QUEUE_READY_OFFSET / sizeof(UINT32)], 1u);
  check_int64("virtio mmio notify", er_virtio_mmio_notify_queue(&transport, VIRTIO_TEST_QUEUE_INDEX), 1);
  check_uint64("virtio mmio notify value",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], VIRTIO_TEST_QUEUE_INDEX);
  check_int64("virtio mmio interrupt",
              er_virtio_mmio_take_interrupt_status(&transport, &interrupt_status), 1);
  check_uint64("virtio mmio interrupt value", interrupt_status, VIRTIO_TEST_INTERRUPT_STATUS);
  check_uint64("virtio mmio interrupt ack",
               regs[ER_VIRTIO_MMIO_INTERRUPT_ACK_OFFSET / sizeof(UINT32)], VIRTIO_TEST_INTERRUPT_STATUS);
}

static void test_virtio_modern_pci_transport_registers(void) {
  enum {
    VIRTIO_PCI_TEST_QUEUE_INDEX = 2u,
    VIRTIO_PCI_TEST_QUEUE_MAX = 8u,
    VIRTIO_PCI_TEST_QUEUE_NOTIFY_OFF = 3u,
    VIRTIO_PCI_TEST_NOTIFY_MULT = 4u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_SELECT_OFFSET = 22u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_SIZE_OFFSET = 24u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_ENABLE_OFFSET = 28u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_NOTIFY_OFF_OFFSET = 30u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_DESC_OFFSET = 32u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_DRIVER_OFFSET = 40u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_DEVICE_OFFSET = 48u,
    VIRTIO_PCI_TEST_NOTIFY_OFFSET = VIRTIO_PCI_TEST_QUEUE_NOTIFY_OFF * VIRTIO_PCI_TEST_NOTIFY_MULT,
    VIRTIO_PCI_TEST_DESC_ADDR = 0x1122334455667788ull,
    VIRTIO_PCI_TEST_DRIVER_ADDR = 0x2233445566778899ull,
    VIRTIO_PCI_TEST_DEVICE_ADDR = 0x33445566778899aau
  };
  UINT32 common[32] = {0};
  UINT32 notify[8] = {0};
  UINT32 device[8] = {0};
  UINT32 isr[1] = {0};
  ErVirtioMmioTransport transport;
  UINT16 queue_size = 0;

  er_mem_zero((UINT8*)&transport, (UINTN)sizeof(transport));
  transport.transport_kind = ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI;
  transport.device_type = ER_VIRTIO_DEVICE_TYPE_NET;
  transport.vendor_id = ER_VIRTIO_VENDOR_ID;
  transport.common.present = 1u;
  transport.notify.present = 1u;
  transport.device.present = 1u;
  transport.isr.present = 1u;
  transport.notify.notify_off_multiplier = VIRTIO_PCI_TEST_NOTIFY_MULT;
  check_int64("virtio pci common address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)common, (UINT64)sizeof(common), 0u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.common.address),
              1);
  check_int64("virtio pci notify address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)notify, (UINT64)sizeof(notify), 1u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.notify.address),
              1);
  check_int64("virtio pci device address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)device, (UINT64)sizeof(device), 2u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.device.address),
              1);
  check_int64("virtio pci isr address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)isr, (UINT64)sizeof(isr), 3u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.isr.address),
              1);
  *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_SIZE_OFFSET) = VIRTIO_PCI_TEST_QUEUE_MAX;
  *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_NOTIFY_OFF_OFFSET) = VIRTIO_PCI_TEST_QUEUE_NOTIFY_OFF;

  check_int64("virtio pci configure queue",
              er_virtio_mmio_configure_split_queue(&transport, VIRTIO_PCI_TEST_QUEUE_INDEX,
                                                   ER_VIRTIO_QUEUE_SIZE, 1u,
                                                   VIRTIO_PCI_TEST_DESC_ADDR,
                                                   VIRTIO_PCI_TEST_DRIVER_ADDR,
                                                   VIRTIO_PCI_TEST_DEVICE_ADDR,
                                                   &queue_size),
              1);
  check_uint64("virtio pci queue size", queue_size, VIRTIO_PCI_TEST_QUEUE_MAX);
  check_uint64("virtio pci queue select",
               *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_SELECT_OFFSET),
               VIRTIO_PCI_TEST_QUEUE_INDEX);
  check_uint64("virtio pci queue desc low",
               *(UINT32*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_DESC_OFFSET),
               (UINT32)VIRTIO_PCI_TEST_DESC_ADDR);
  check_uint64("virtio pci queue driver high",
               *(UINT32*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_DRIVER_OFFSET + sizeof(UINT32)),
               (UINT32)(VIRTIO_PCI_TEST_DRIVER_ADDR >> 32));
  check_uint64("virtio pci queue device high",
               *(UINT32*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_DEVICE_OFFSET + sizeof(UINT32)),
               (UINT32)(VIRTIO_PCI_TEST_DEVICE_ADDR >> 32));
  check_uint64("virtio pci queue enabled",
               *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_ENABLE_OFFSET), 1u);

  check_int64("virtio pci notify", er_virtio_mmio_notify_queue(&transport, VIRTIO_PCI_TEST_QUEUE_INDEX), 1);
  check_uint64("virtio pci notify value",
               *(UINT16*)((UINT8*)notify + VIRTIO_PCI_TEST_NOTIFY_OFFSET), VIRTIO_PCI_TEST_QUEUE_INDEX);
}

static void test_virtio_split_queue(void) {
  ErVirtioQueueDesc desc[ER_VIRTIO_QUEUE_SIZE];
  ErVirtioQueueAvail avail;
  ErVirtioQueueUsed used;
  ErVirtioQueueUsedElem elem;
  UINT16 last_used_idx = 0;

  er_virtio_queue_clear(desc, &avail, &used);
  check_uint64("virtio queue desc clear", desc[0].addr, 0u);
  check_uint64("virtio queue avail clear", avail.idx, 0u);
  check_uint64("virtio queue used clear", used.idx, 0u);
  check_int64("virtio queue post first", er_virtio_queue_post_descriptor(&avail, 4u, 2u), 1);
  check_uint64("virtio queue avail idx first", avail.idx, 1u);
  check_uint64("virtio queue avail ring first", avail.ring[0], 2u);
  check_int64("virtio queue post second", er_virtio_queue_post_descriptor(&avail, 4u, 3u), 1);
  check_uint64("virtio queue avail idx second", avail.idx, 2u);
  check_uint64("virtio queue avail ring second", avail.ring[1], 3u);
  check_int64("virtio queue reject high desc", er_virtio_queue_post_descriptor(&avail, 4u, 4u), 0);

  used.idx = 2u;
  used.ring[0].id = 2u;
  used.ring[0].len = 64u;
  used.ring[1].id = 3u;
  used.ring[1].len = 128u;
  check_int64("virtio queue take first",
              er_virtio_queue_take_next_used(&used, 4u, &last_used_idx, &elem), 1);
  check_uint64("virtio queue used first id", elem.id, 2u);
  check_uint64("virtio queue used first len", elem.len, 64u);
  check_uint64("virtio queue last first", last_used_idx, 1u);
  check_int64("virtio queue take second",
              er_virtio_queue_take_next_used(&used, 4u, &last_used_idx, &elem), 1);
  check_uint64("virtio queue used second id", elem.id, 3u);
  check_uint64("virtio queue used second len", elem.len, 128u);
  check_uint64("virtio queue last second", last_used_idx, 2u);
  check_int64("virtio queue take empty",
              er_virtio_queue_take_next_used(&used, 4u, &last_used_idx, &elem), 0);
}

static void test_virtio_blk_mmio(void) {
  enum {
    VIRTIO_BLK_TEST_MMIO_DWORDS = 128u,
    VIRTIO_BLK_TEST_QUEUE_MAX = ER_VIRTIO_QUEUE_SIZE,
    VIRTIO_BLK_TEST_CAPACITY = 64u,
    VIRTIO_BLK_TEST_SECTOR = 2u,
    VIRTIO_BLK_TEST_BAD_SECTOR = VIRTIO_BLK_TEST_CAPACITY,
    VIRTIO_BLK_TEST_NOTIFY_QUEUE = ER_VIRTIO_BLK_QUEUE,
    VIRTIO_BLK_TEST_DATA_BYTES = ER_VIRTIO_BLK_SECTOR_BYTES
  };
  UINT32 regs[VIRTIO_BLK_TEST_MMIO_DWORDS] = {0};
  ErVirtioBlk blk;
  ErVirtioBlkStats stats;
  ErVirtioQueueDesc* desc;
  ErVirtioQueueAvail* avail;
  ErVirtioQueueUsed* used;
  ErVirtioBlkRequestHeader* request;
  UINT8* status_byte;
  UINT8 read_data[VIRTIO_BLK_TEST_DATA_BYTES] = {0};
  UINT8 write_data[VIRTIO_BLK_TEST_DATA_BYTES] = {0};
  UINT8 status = ER_VIRTIO_BLK_STATUS_IOERR;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_BLK;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_BLK_TEST_QUEUE_MAX;
  regs[ER_VIRTIO_MMIO_CONFIG_OFFSET / sizeof(UINT32)] = VIRTIO_BLK_TEST_CAPACITY;

  check_int64("virtio blk init",
              er_virtio_blk_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs),
                                      &blk),
              1);
  check_int64("virtio blk initialized", blk.initialized, 1);
  check_uint64("virtio blk features", blk.features, ER_VIRTIO_F_VERSION_1);
  check_uint64("virtio blk capacity", blk.capacity_sectors,
               VIRTIO_BLK_TEST_CAPACITY);
  check_uint64("virtio blk queue size", blk.queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio blk status driver ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER |
               ER_VIRTIO_STATUS_FEATURES_OK | ER_VIRTIO_STATUS_DRIVER_OK);
  check_int64("virtio blk deterministic reinit",
              er_virtio_blk_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs),
                                      &blk),
              1);

  desc = er_virtio_blk_test_desc();
  avail = er_virtio_blk_test_avail();
  used = er_virtio_blk_test_used();
  request = er_virtio_blk_test_request();
  status_byte = er_virtio_blk_test_status();
  check_uint64("virtio blk desc clear", desc[0].addr, 0u);
  check_uint64("virtio blk avail clear", avail->idx, 0u);
  check_uint64("virtio blk used clear", used->idx, 0u);

  check_int64("virtio blk submit read",
              er_virtio_blk_submit_read(&blk, VIRTIO_BLK_TEST_SECTOR,
                                        read_data,
                                        (UINT32)sizeof(read_data)),
              1);
  check_uint64("virtio blk read type", request->type, ER_VIRTIO_BLK_REQ_READ);
  check_uint64("virtio blk read sector", request->sector, VIRTIO_BLK_TEST_SECTOR);
  check_uint64("virtio blk read avail idx", avail->idx, 1u);
  check_uint64("virtio blk read avail head", avail->ring[0], 0u);
  check_uint64("virtio blk head flags", desc[0].flags, ER_VIRTIO_DESC_F_NEXT);
  check_uint64("virtio blk head next", desc[0].next, 1u);
  check_uint64("virtio blk read data addr", desc[1].addr, (UINT64)(UINTN)read_data);
  check_uint64("virtio blk read data len", desc[1].len, sizeof(read_data));
  check_uint64("virtio blk read data flags",
               desc[1].flags, ER_VIRTIO_DESC_F_NEXT | ER_VIRTIO_DESC_F_WRITE);
  check_uint64("virtio blk status flags", desc[2].flags, ER_VIRTIO_DESC_F_WRITE);
  check_uint64("virtio blk notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)],
               VIRTIO_BLK_TEST_NOTIFY_QUEUE);
  check_int64("virtio blk reject busy",
              er_virtio_blk_submit_read(&blk, VIRTIO_BLK_TEST_SECTOR,
                                        read_data,
                                        (UINT32)sizeof(read_data)),
              0);
  *status_byte = ER_VIRTIO_BLK_STATUS_OK;
  used->ring[0].id = 0u;
  used->ring[0].len = (UINT32)sizeof(*status_byte);
  used->idx = 1u;
  check_int64("virtio blk poll read ok", er_virtio_blk_poll(&blk, &status), 1);
  check_uint64("virtio blk poll read status", status, ER_VIRTIO_BLK_STATUS_OK);

  check_int64("virtio blk submit write",
              er_virtio_blk_submit_write(&blk, VIRTIO_BLK_TEST_SECTOR,
                                         write_data,
                                         (UINT32)sizeof(write_data)),
              1);
  check_uint64("virtio blk write type", request->type, ER_VIRTIO_BLK_REQ_WRITE);
  check_uint64("virtio blk write data addr", desc[1].addr, (UINT64)(UINTN)write_data);
  check_uint64("virtio blk write data flags", desc[1].flags, ER_VIRTIO_DESC_F_NEXT);
  *status_byte = ER_VIRTIO_BLK_STATUS_IOERR;
  used->ring[1].id = 0u;
  used->ring[1].len = (UINT32)sizeof(*status_byte);
  used->idx = 2u;
  check_int64("virtio blk poll write ioerr", er_virtio_blk_poll(&blk, &status), 0);
  check_uint64("virtio blk poll write status", status, ER_VIRTIO_BLK_STATUS_IOERR);

  check_int64("virtio blk reject unaligned len",
              er_virtio_blk_submit_read(&blk, VIRTIO_BLK_TEST_SECTOR,
                                        read_data,
                                        (UINT32)sizeof(read_data) - 1u),
              0);
  check_int64("virtio blk reject out of range",
              er_virtio_blk_submit_read(&blk, VIRTIO_BLK_TEST_BAD_SECTOR,
                                        read_data,
                                        (UINT32)sizeof(read_data)),
              0);
  stats = er_virtio_blk_stats(&blk);
  check_uint64("virtio blk submitted", stats.submitted, 2u);
  check_uint64("virtio blk completed", stats.completed, 1u);
  check_uint64("virtio blk failed", stats.failed, 1u);
  check_uint64("virtio blk busy", stats.busy, 1u);
  check_uint64("virtio blk invalid", stats.invalid, 2u);
}

static void test_virtio_net_mmio(void) {
  enum {
    VIRTIO_NET_TEST_MMIO_DWORDS = 128u,
    VIRTIO_NET_TEST_QUEUE_MAX = ER_VIRTIO_QUEUE_SIZE,
    VIRTIO_NET_TEST_FRAME_LEN = 4u,
    VIRTIO_NET_TEST_RX_DESC = 2u
  };
  UINT32 regs[VIRTIO_NET_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErVirtioNetStats stats;
  ErVirtioQueueDesc* rx_desc;
  ErVirtioQueueAvail* rx_avail;
  ErVirtioQueueUsed* rx_used;
  UINT8* rx_buffer;
  ErVirtioQueueDesc* tx_desc;
  ErVirtioQueueAvail* tx_avail;
  ErVirtioQueueUsed* tx_used;
  UINT8* tx_buffer;
  UINT8 frame[VIRTIO_NET_TEST_FRAME_LEN] = {0xdeu, 0xadu, 0xbeu, 0xefu};
  UINT8 recv_frame[8] = {0};
  UINT32 recv_len = 0;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_NET_TEST_QUEUE_MAX;

  check_int64("virtio net init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  check_int64("virtio net initialized", net.initialized, 1);
  check_int64("virtio net link up default", net.link_up, 1);
  check_uint64("virtio net queue size", net.queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio net features", net.features, ER_VIRTIO_F_VERSION_1);
  check_uint64("virtio net status driver ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER |
               ER_VIRTIO_STATUS_FEATURES_OK | ER_VIRTIO_STATUS_DRIVER_OK);
  check_uint64("virtio net initial notify rx",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], 0u);

  rx_desc = er_virtio_net_test_rx_desc();
  rx_avail = er_virtio_net_test_rx_avail();
  rx_used = er_virtio_net_test_rx_used();
  tx_desc = er_virtio_net_test_tx_desc();
  tx_avail = er_virtio_net_test_tx_avail();
  tx_used = er_virtio_net_test_tx_used();
  check_uint64("virtio net rx avail filled", rx_avail->idx, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio net rx desc write", rx_desc[0].flags, ER_VIRTIO_DESC_F_WRITE);
  check_uint64("virtio net tx avail empty", tx_avail->idx, 0u);

  check_int64("virtio net send", er_virtio_net_send(&net, frame, VIRTIO_NET_TEST_FRAME_LEN), 1);
  tx_buffer = er_virtio_net_test_tx_buffer(0u);
  check_uint64("virtio net tx avail idx", tx_avail->idx, 1u);
  check_uint64("virtio net tx avail desc", tx_avail->ring[0], 0u);
  check_uint64("virtio net tx desc len", tx_desc[0].len, 12u + VIRTIO_NET_TEST_FRAME_LEN);
  check_uint64("virtio net tx desc flags", tx_desc[0].flags, 0u);
  check_uint64("virtio net tx hdr zero", tx_buffer[0], 0u);
  check_uint64("virtio net tx payload0", tx_buffer[12], frame[0]);
  check_uint64("virtio net tx payload3", tx_buffer[15], frame[3]);
  check_uint64("virtio net tx notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], 1u);
  stats = er_virtio_net_stats(&net);
  check_uint64("virtio net tx submitted", stats.tx_submitted, 1u);
  check_uint64("virtio net tx completed before used", stats.tx_completed, 0u);

  tx_used->ring[0].id = 0u;
  tx_used->ring[0].len = 12u + VIRTIO_NET_TEST_FRAME_LEN;
  tx_used->idx = 1u;
  stats = er_virtio_net_stats(&net);
  check_uint64("virtio net tx completed after used", stats.tx_completed, 1u);

  rx_buffer = er_virtio_net_test_rx_buffer(VIRTIO_NET_TEST_RX_DESC);
  rx_buffer[12] = 0x11u;
  rx_buffer[13] = 0x22u;
  rx_buffer[14] = 0x33u;
  rx_used->ring[0].id = VIRTIO_NET_TEST_RX_DESC;
  rx_used->ring[0].len = 15u;
  rx_used->idx = 1u;
  check_int64("virtio net recv",
              er_virtio_net_recv(&net, recv_frame, (UINT32)sizeof(recv_frame), &recv_len),
              1);
  check_uint64("virtio net recv len", recv_len, 3u);
  check_uint64("virtio net recv byte0", recv_frame[0], 0x11u);
  check_uint64("virtio net recv byte2", recv_frame[2], 0x33u);
  check_uint64("virtio net rx repost", rx_avail->idx, ER_VIRTIO_QUEUE_SIZE + 1u);
  check_uint64("virtio net rx notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], 0u);
  stats = er_virtio_net_stats(&net);
  check_uint64("virtio net rx received", stats.rx_received, 1u);
  check_uint64("virtio net rx invalid", stats.rx_invalid, 0u);
}

static void test_virtio_gpu_mmio(void) {
  typedef struct {
    ErVirtioGpuControlHeader header;
    ErVirtioGpuRect rect;
    UINT64 offset;
    UINT32 resource_id;
    UINT32 padding;
  } TestVirtioGpuTransferToHost2d;
  typedef struct {
    ErVirtioGpuControlHeader header;
    ErVirtioGpuRect rect;
    UINT32 resource_id;
    UINT32 padding;
  } TestVirtioGpuResourceFlush;
  enum {
    VIRTIO_GPU_TEST_MMIO_DWORDS = 128u,
    VIRTIO_GPU_TEST_QUEUE_MAX = ER_VIRTIO_QUEUE_SIZE,
    VIRTIO_GPU_TEST_EVENTS_READ = 1u,
    VIRTIO_GPU_TEST_SCANOUTS = 2u,
    VIRTIO_GPU_TEST_CAPSETS = 3u,
    VIRTIO_GPU_TEST_CONTROL_RESPONSE_SIZE = 512u,
    VIRTIO_GPU_TEST_FB_RESOURCE_ID = 9u,
    VIRTIO_GPU_TEST_FB_SCANOUT_ID = 0u,
    VIRTIO_GPU_TEST_FB_WIDTH = 3u,
    VIRTIO_GPU_TEST_FB_HEIGHT = 2u,
    VIRTIO_GPU_TEST_FB_STRIDE = 4u,
    VIRTIO_GPU_TEST_FB_RECT_X = 1u,
    VIRTIO_GPU_TEST_FB_RECT_Y = 1u,
    VIRTIO_GPU_TEST_FB_RECT_WIDTH = 2u,
    VIRTIO_GPU_TEST_FB_RECT_HEIGHT = 1u,
    VIRTIO_GPU_TEST_FB_RECT_OFFSET =
        ((VIRTIO_GPU_TEST_FB_RECT_Y * VIRTIO_GPU_TEST_FB_STRIDE) +
         VIRTIO_GPU_TEST_FB_RECT_X) *
        ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL,
    VIRTIO_GPU_TEST_FB_PIXELS = VIRTIO_GPU_TEST_FB_STRIDE * VIRTIO_GPU_TEST_FB_HEIGHT,
    VIRTIO_GPU_TEST_FB_BYTES =
        VIRTIO_GPU_TEST_FB_PIXELS * ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL,
    VIRTIO_GPU_TEST_FB_CLEAR_COLOR = 0x00112233u,
    VIRTIO_GPU_TEST_FB_TOP_COLOR = 0x00445566u,
    VIRTIO_GPU_TEST_FB_BOTTOM_COLOR = 0x00778899u,
    VIRTIO_GPU_TEST_CONFIG_EVENTS_READ_DWORD =
        (ER_VIRTIO_MMIO_CONFIG_OFFSET + 0u) / sizeof(UINT32),
    VIRTIO_GPU_TEST_CONFIG_SCANOUTS_DWORD =
        (ER_VIRTIO_MMIO_CONFIG_OFFSET + 8u) / sizeof(UINT32),
    VIRTIO_GPU_TEST_CONFIG_CAPSETS_DWORD =
        (ER_VIRTIO_MMIO_CONFIG_OFFSET + 12u) / sizeof(UINT32)
  };
  UINT32 regs[VIRTIO_GPU_TEST_MMIO_DWORDS] = {0};
  ErVirtioGpu gpu;
  ErVirtioQueueDesc* control_desc;
  ErVirtioQueueAvail* control_avail;
  ErVirtioQueueUsed* control_used;
  ErVirtioQueueDesc* cursor_desc;
  ErVirtioQueueAvail* cursor_avail;
  ErVirtioQueueUsed* cursor_used;
  UINT8* control_request;
  UINT8* control_response;
  ErVirtioGpuDisplayInfo display_info;
  ErVirtioGpuControlHeader control_header;
  TestVirtioGpuTransferToHost2d transfer_request;
  TestVirtioGpuResourceFlush flush_request;
  ErVirtioGpuStats gpu_stats;
  ErVirtioGpuFramebuffer framebuffer;
  UINT32 framebuffer_pixels[VIRTIO_GPU_TEST_FB_PIXELS] = {0};
  ErUiSurface ui_surface;
  ErUiSurfaceRenderStats ui_render_stats;
  er_ui_rect_t ui_rects[1];
  er_ui_scene_t ui_scene;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_GPU;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_GPU_TEST_QUEUE_MAX;
  regs[VIRTIO_GPU_TEST_CONFIG_EVENTS_READ_DWORD] = VIRTIO_GPU_TEST_EVENTS_READ;
  regs[VIRTIO_GPU_TEST_CONFIG_SCANOUTS_DWORD] = VIRTIO_GPU_TEST_SCANOUTS;
  regs[VIRTIO_GPU_TEST_CONFIG_CAPSETS_DWORD] = VIRTIO_GPU_TEST_CAPSETS;

  check_int64("virtio gpu init",
              er_virtio_gpu_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &gpu),
              1);
  check_int64("virtio gpu initialized", gpu.initialized, 1);
  check_uint64("virtio gpu features", gpu.features, ER_VIRTIO_F_VERSION_1);
  check_uint64("virtio gpu control queue size", gpu.control_queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio gpu cursor queue size", gpu.cursor_queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio gpu events read", gpu.config.events_read, VIRTIO_GPU_TEST_EVENTS_READ);
  check_uint64("virtio gpu scanouts", gpu.config.num_scanouts, VIRTIO_GPU_TEST_SCANOUTS);
  check_uint64("virtio gpu capsets", gpu.config.num_capsets, VIRTIO_GPU_TEST_CAPSETS);
  check_uint64("virtio gpu status driver ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER |
               ER_VIRTIO_STATUS_FEATURES_OK | ER_VIRTIO_STATUS_DRIVER_OK);
  check_uint64("virtio gpu final queue select",
               regs[ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_GPU_CURSOR_QUEUE);
  check_uint64("virtio gpu queue ready",
               regs[ER_VIRTIO_MMIO_QUEUE_READY_OFFSET / sizeof(UINT32)], 1u);

  control_desc = er_virtio_gpu_test_control_desc();
  control_avail = er_virtio_gpu_test_control_avail();
  control_used = er_virtio_gpu_test_control_used();
  cursor_desc = er_virtio_gpu_test_cursor_desc();
  cursor_avail = er_virtio_gpu_test_cursor_avail();
  cursor_used = er_virtio_gpu_test_cursor_used();
  control_request = er_virtio_gpu_test_control_request();
  check_uint64("virtio gpu control desc clear", control_desc[0].addr, 0u);
  check_uint64("virtio gpu control avail clear", control_avail->idx, 0u);
  check_uint64("virtio gpu control used clear", control_used->idx, 0u);
  check_uint64("virtio gpu cursor desc clear", cursor_desc[0].addr, 0u);
  check_uint64("virtio gpu cursor avail clear", cursor_avail->idx, 0u);
  check_uint64("virtio gpu cursor used clear", cursor_used->idx, 0u);

  check_int64("virtio gpu display submit", er_virtio_gpu_submit_get_display_info(&gpu), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu display request type", control_header.type,
               ER_VIRTIO_GPU_CMD_GET_DISPLAY_INFO);
  check_uint64("virtio gpu control avail idx", control_avail->idx, 1u);
  check_uint64("virtio gpu control avail desc", control_avail->ring[0], 0u);
  check_uint64("virtio gpu control request len", control_desc[0].len,
               (UINT32)sizeof(ErVirtioGpuControlHeader));
  check_uint64("virtio gpu control request flags", control_desc[0].flags, ER_VIRTIO_DESC_F_NEXT);
  check_uint64("virtio gpu control request next", control_desc[0].next, 1u);
  check_uint64("virtio gpu control response len", control_desc[1].len,
               VIRTIO_GPU_TEST_CONTROL_RESPONSE_SIZE);
  check_uint64("virtio gpu control response flags", control_desc[1].flags, ER_VIRTIO_DESC_F_WRITE);
  check_uint64("virtio gpu control notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_GPU_CONTROL_QUEUE);
  check_int64("virtio gpu display busy rejected", er_virtio_gpu_submit_get_display_info(&gpu), 0);
  gpu_stats = er_virtio_gpu_stats(&gpu);
  check_uint64("virtio gpu submitted", gpu_stats.control_submitted, 1u);
  check_uint64("virtio gpu busy", gpu_stats.control_busy, 1u);

  control_response = er_virtio_gpu_test_control_response();
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  display_info.header.type = ER_VIRTIO_GPU_RESP_OK_DISPLAY_INFO;
  display_info.scanouts[0].rect.width = 800u;
  display_info.scanouts[0].rect.height = 600u;
  display_info.scanouts[0].enabled = 1u;
  er_mem_copy(control_response, (const UINT8*)&display_info, (UINTN)sizeof(display_info));
  control_used->ring[0].id = 0u;
  control_used->ring[0].len = (UINT32)sizeof(display_info);
  control_used->idx = 1u;
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  check_int64("virtio gpu display poll", er_virtio_gpu_poll_display_info(&gpu, &display_info), 1);
  check_uint64("virtio gpu display response type", display_info.header.type,
               ER_VIRTIO_GPU_RESP_OK_DISPLAY_INFO);
  check_uint64("virtio gpu display width", display_info.scanouts[0].rect.width, 800u);
  check_uint64("virtio gpu display height", display_info.scanouts[0].rect.height, 600u);
  check_uint64("virtio gpu display enabled", display_info.scanouts[0].enabled, 1u);
  gpu_stats = er_virtio_gpu_stats(&gpu);
  check_uint64("virtio gpu completed", gpu_stats.control_completed, 1u);

  check_int64("virtio gpu create resource",
              er_virtio_gpu_submit_resource_create_2d(&gpu, 7u,
                                                      ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                                      800u, 600u),
              1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu create request type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_CREATE_2D);
  check_int64("virtio gpu reject create zero resource",
              er_virtio_gpu_submit_resource_create_2d(&gpu, 0u,
                                                      ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                                      800u, 600u),
              0);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[1].id = 0u;
  control_used->ring[1].len = (UINT32)sizeof(control_header);
  control_used->idx = 2u;
  check_int64("virtio gpu create ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu attach backing",
              er_virtio_gpu_submit_resource_attach_backing(&gpu, 7u, 0x1000u, 800u * 600u * 4u),
              1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu attach request type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[2].id = 0u;
  control_used->ring[2].len = (UINT32)sizeof(control_header);
  control_used->idx = 3u;
  check_int64("virtio gpu attach ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu set scanout", er_virtio_gpu_submit_set_scanout(&gpu, 0u, 7u, 800u, 600u), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu scanout request type", control_header.type,
               ER_VIRTIO_GPU_CMD_SET_SCANOUT);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[3].id = 0u;
  control_used->ring[3].len = (UINT32)sizeof(control_header);
  control_used->idx = 4u;
  check_int64("virtio gpu scanout ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu transfer",
              er_virtio_gpu_submit_transfer_to_host_2d(&gpu, 7u, 800u, 600u), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu transfer request type", control_header.type,
               ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[4].id = 0u;
  control_used->ring[4].len = (UINT32)sizeof(control_header);
  control_used->idx = 5u;
  check_int64("virtio gpu transfer ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu flush", er_virtio_gpu_submit_resource_flush(&gpu, 7u, 800u, 600u), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu flush request type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[5].id = 0u;
  control_used->ring[5].len = (UINT32)sizeof(control_header);
  control_used->idx = 6u;
  check_int64("virtio gpu flush ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu framebuffer init",
              er_virtio_gpu_framebuffer_init(&framebuffer, VIRTIO_GPU_TEST_FB_RESOURCE_ID,
                                             VIRTIO_GPU_TEST_FB_SCANOUT_ID,
                                             ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                             VIRTIO_GPU_TEST_FB_HEIGHT,
                                             VIRTIO_GPU_TEST_FB_STRIDE,
                                             framebuffer_pixels,
                                             VIRTIO_GPU_TEST_FB_PIXELS),
              1);
  check_uint64("virtio gpu framebuffer bytes", framebuffer.byte_len, VIRTIO_GPU_TEST_FB_BYTES);
  check_int64("virtio gpu framebuffer reject stride",
              er_virtio_gpu_framebuffer_init(&framebuffer, VIRTIO_GPU_TEST_FB_RESOURCE_ID,
                                             VIRTIO_GPU_TEST_FB_SCANOUT_ID,
                                             ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                             VIRTIO_GPU_TEST_FB_HEIGHT,
                                             VIRTIO_GPU_TEST_FB_WIDTH - 1u,
                                             framebuffer_pixels,
                                             VIRTIO_GPU_TEST_FB_PIXELS),
              0);
  check_int64("virtio gpu framebuffer reinit",
              er_virtio_gpu_framebuffer_init(&framebuffer, VIRTIO_GPU_TEST_FB_RESOURCE_ID,
                                             VIRTIO_GPU_TEST_FB_SCANOUT_ID,
                                             ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                             VIRTIO_GPU_TEST_FB_HEIGHT,
                                             VIRTIO_GPU_TEST_FB_STRIDE,
                                             framebuffer_pixels,
                                             VIRTIO_GPU_TEST_FB_PIXELS),
              1);
  er_virtio_gpu_framebuffer_clear(&framebuffer, VIRTIO_GPU_TEST_FB_CLEAR_COLOR);
  check_uint64("virtio gpu framebuffer clear first", framebuffer_pixels[0],
               VIRTIO_GPU_TEST_FB_CLEAR_COLOR);
  check_uint64("virtio gpu framebuffer clear stride gap", framebuffer_pixels[3], 0u);
  check_uint64("virtio gpu framebuffer clear second row", framebuffer_pixels[4],
               VIRTIO_GPU_TEST_FB_CLEAR_COLOR);
  er_virtio_gpu_framebuffer_fill_halves(&framebuffer, VIRTIO_GPU_TEST_FB_TOP_COLOR,
                                        VIRTIO_GPU_TEST_FB_BOTTOM_COLOR);
  check_uint64("virtio gpu framebuffer top", framebuffer_pixels[0],
               VIRTIO_GPU_TEST_FB_TOP_COLOR);
  check_uint64("virtio gpu framebuffer bottom", framebuffer_pixels[4],
               VIRTIO_GPU_TEST_FB_BOTTOM_COLOR);
  er_mem_zero((UINT8*)&ui_scene, (UINTN)sizeof(ui_scene));
  ui_rects[0] = er_ui_rect_fill(0.0f, 0.0f, 2.0f, 1.0f, 0.0f,
                                er_ui_color_rgb_u8(255u, 0u, 0u));
  ui_scene.clear = er_ui_color_rgb_u8(0u, 0u, 0u);
  ui_scene.rects = ui_rects;
  ui_scene.rect_count = 1u;
  ui_scene.rect_capacity = 1u;
  ui_surface.pixels = framebuffer.pixels;
  ui_surface.width = framebuffer.width;
  ui_surface.height = framebuffer.height;
  ui_surface.stride = framebuffer.stride_pixels;
  ui_surface.pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  check_int64("virtio gpu framebuffer surface scene",
              er_ui_surface_render_scene_with_font_stats(&ui_surface, &ui_scene, 0, &ui_render_stats),
              1);
  check_uint64("virtio gpu framebuffer surface bytes", ui_render_stats.bytes_written, 32u);
  check_uint64("virtio gpu framebuffer surface rects", ui_render_stats.rects, 1u);
  check_uint64("virtio gpu framebuffer surface bgrx red", framebuffer_pixels[0], 0x000000ffu);
  check_uint64("virtio gpu framebuffer surface clear", framebuffer_pixels[4], 0u);
  check_int64("virtio gpu framebuffer create",
              er_virtio_gpu_submit_framebuffer_create(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer create type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_CREATE_2D);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[6].id = 0u;
  control_used->ring[6].len = (UINT32)sizeof(control_header);
  control_used->idx = 7u;
  check_int64("virtio gpu framebuffer create ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer attach",
              er_virtio_gpu_submit_framebuffer_attach(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer attach type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[7].id = 0u;
  control_used->ring[7].len = (UINT32)sizeof(control_header);
  control_used->idx = 8u;
  check_int64("virtio gpu framebuffer attach ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer scanout",
              er_virtio_gpu_submit_framebuffer_set_scanout(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer scanout type", control_header.type,
               ER_VIRTIO_GPU_CMD_SET_SCANOUT);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[8].id = 0u;
  control_used->ring[8].len = (UINT32)sizeof(control_header);
  control_used->idx = 9u;
  check_int64("virtio gpu framebuffer scanout ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer transfer",
              er_virtio_gpu_submit_framebuffer_transfer(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer transfer type", control_header.type,
               ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[9].id = 0u;
  control_used->ring[9].len = (UINT32)sizeof(control_header);
  control_used->idx = 10u;
  check_int64("virtio gpu framebuffer transfer ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer flush",
              er_virtio_gpu_submit_framebuffer_flush(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer flush type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[10].id = 0u;
  control_used->ring[10].len = (UINT32)sizeof(control_header);
  control_used->idx = 11u;
  check_int64("virtio gpu framebuffer flush ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu framebuffer transfer rect",
              er_virtio_gpu_submit_framebuffer_transfer_rect(&gpu,
                                                             &framebuffer,
                                                             VIRTIO_GPU_TEST_FB_RECT_X,
                                                             VIRTIO_GPU_TEST_FB_RECT_Y,
                                                             VIRTIO_GPU_TEST_FB_RECT_WIDTH,
                                                             VIRTIO_GPU_TEST_FB_RECT_HEIGHT),
              1);
  er_mem_zero((UINT8*)&transfer_request, (UINTN)sizeof(transfer_request));
  er_mem_copy((UINT8*)&transfer_request, control_request, (UINTN)sizeof(transfer_request));
  check_uint64("virtio gpu framebuffer transfer rect type",
               transfer_request.header.type, ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D);
  check_uint64("virtio gpu framebuffer transfer rect x",
               transfer_request.rect.x, VIRTIO_GPU_TEST_FB_RECT_X);
  check_uint64("virtio gpu framebuffer transfer rect y",
               transfer_request.rect.y, VIRTIO_GPU_TEST_FB_RECT_Y);
  check_uint64("virtio gpu framebuffer transfer rect width",
               transfer_request.rect.width, VIRTIO_GPU_TEST_FB_RECT_WIDTH);
  check_uint64("virtio gpu framebuffer transfer rect height",
               transfer_request.rect.height, VIRTIO_GPU_TEST_FB_RECT_HEIGHT);
  check_uint64("virtio gpu framebuffer transfer rect offset",
               transfer_request.offset, VIRTIO_GPU_TEST_FB_RECT_OFFSET);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[11].id = 0u;
  control_used->ring[11].len = (UINT32)sizeof(control_header);
  control_used->idx = 12u;
  check_int64("virtio gpu framebuffer transfer rect ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu framebuffer flush rect",
              er_virtio_gpu_submit_framebuffer_flush_rect(&gpu,
                                                          &framebuffer,
                                                          VIRTIO_GPU_TEST_FB_RECT_X,
                                                          VIRTIO_GPU_TEST_FB_RECT_Y,
                                                          VIRTIO_GPU_TEST_FB_RECT_WIDTH,
                                                          VIRTIO_GPU_TEST_FB_RECT_HEIGHT),
              1);
  er_mem_zero((UINT8*)&flush_request, (UINTN)sizeof(flush_request));
  er_mem_copy((UINT8*)&flush_request, control_request, (UINTN)sizeof(flush_request));
  check_uint64("virtio gpu framebuffer flush rect type",
               flush_request.header.type, ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH);
  check_uint64("virtio gpu framebuffer flush rect x",
               flush_request.rect.x, VIRTIO_GPU_TEST_FB_RECT_X);
  check_uint64("virtio gpu framebuffer flush rect y",
               flush_request.rect.y, VIRTIO_GPU_TEST_FB_RECT_Y);
  check_uint64("virtio gpu framebuffer flush rect width",
               flush_request.rect.width, VIRTIO_GPU_TEST_FB_RECT_WIDTH);
  check_uint64("virtio gpu framebuffer flush rect height",
               flush_request.rect.height, VIRTIO_GPU_TEST_FB_RECT_HEIGHT);
  check_int64("virtio gpu framebuffer reject transfer rect overflow",
              er_virtio_gpu_submit_framebuffer_transfer_rect(&gpu,
                                                             &framebuffer,
                                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                                             VIRTIO_GPU_TEST_FB_RECT_Y,
                                                             VIRTIO_GPU_TEST_FB_RECT_WIDTH,
                                                             VIRTIO_GPU_TEST_FB_RECT_HEIGHT),
              0);
}

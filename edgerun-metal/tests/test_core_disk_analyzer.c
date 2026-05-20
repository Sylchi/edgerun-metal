#include "test_core_internal.h"

enum {
  DISK_ANALYZER_TEST_BLOCK_BYTES = 512u,
  DISK_ANALYZER_TEST_BLOCK_COUNT = 2048u,
  DISK_ANALYZER_TEST_DEVICE_BYTES =
      DISK_ANALYZER_TEST_BLOCK_BYTES * DISK_ANALYZER_TEST_BLOCK_COUNT,
  DISK_ANALYZER_TEST_LABEL_BLOCKS =
      ER_ZFS_LABEL_BYTES / DISK_ANALYZER_TEST_BLOCK_BYTES,
  DISK_ANALYZER_TEST_UBERBLOCK_OFFSET = 128u * 1024u,
  DISK_ANALYZER_TEST_UBERBLOCK_TXG = 42u,
  DISK_ANALYZER_TEST_UBERBLOCK_TIMESTAMP = 77u,
  DISK_ANALYZER_TEST_CAP_DSTRD_SHIFT = 32u,
  DISK_ANALYZER_TEST_CAP_MPSMIN_SHIFT = 48u
};

typedef struct {
  UINT8 bytes[DISK_ANALYZER_TEST_DEVICE_BYTES];
  UINT8 flushed;
} DiskAnalyzerFakeDevice;

static void disk_analyzer_put_le64(UINT8* dst, UINT64 value) {
  UINT32 i;

  for (i = 0u; i < 8u; ++i) {
    dst[i] = (UINT8)(value >> ((UINT64)i * 8u));
  }
}

static UINT8 disk_analyzer_fake_read(void* ctx,
                                     UINT64 lba,
                                     UINT32 block_count,
                                     UINT8* out_bytes,
                                     UINT32 byte_len) {
  DiskAnalyzerFakeDevice* device = (DiskAnalyzerFakeDevice*)ctx;
  UINT64 offset = lba * DISK_ANALYZER_TEST_BLOCK_BYTES;

  if (device == 0 ||
      out_bytes == 0 ||
      byte_len != block_count * DISK_ANALYZER_TEST_BLOCK_BYTES ||
      offset > DISK_ANALYZER_TEST_DEVICE_BYTES ||
      byte_len > DISK_ANALYZER_TEST_DEVICE_BYTES - offset) {
    return 0u;
  }
  er_mem_copy(out_bytes, device->bytes + offset, byte_len);
  return 1u;
}

static UINT8 disk_analyzer_fake_write(void* ctx,
                                      UINT64 lba,
                                      UINT32 block_count,
                                      const UINT8* bytes,
                                      UINT32 byte_len) {
  DiskAnalyzerFakeDevice* device = (DiskAnalyzerFakeDevice*)ctx;
  UINT64 offset = lba * DISK_ANALYZER_TEST_BLOCK_BYTES;

  if (device == 0 ||
      bytes == 0 ||
      byte_len != block_count * DISK_ANALYZER_TEST_BLOCK_BYTES ||
      offset > DISK_ANALYZER_TEST_DEVICE_BYTES ||
      byte_len > DISK_ANALYZER_TEST_DEVICE_BYTES - offset) {
    return 0u;
  }
  er_mem_copy(device->bytes + offset, bytes, byte_len);
  return 1u;
}

static UINT8 disk_analyzer_fake_flush(void* ctx) {
  DiskAnalyzerFakeDevice* device = (DiskAnalyzerFakeDevice*)ctx;

  if (device == 0) {
    return 0u;
  }
  device->flushed = 1u;
  return 1u;
}

static void test_block_device_contract(void) {
  DiskAnalyzerFakeDevice fake;
  ErBlockDevice device;
  UINT8 id[ER_BLOCK_DEVICE_ID_BYTES];
  UINT8 write_bytes[DISK_ANALYZER_TEST_BLOCK_BYTES];
  UINT8 read_bytes[DISK_ANALYZER_TEST_BLOCK_BYTES];

  er_mem_zero((UINT8*)&fake, (UINTN)sizeof(fake));
  er_mem_zero(id, ER_BLOCK_DEVICE_ID_BYTES);
  er_mem_zero(write_bytes, DISK_ANALYZER_TEST_BLOCK_BYTES);
  er_mem_zero(read_bytes, DISK_ANALYZER_TEST_BLOCK_BYTES);
  id[0] = 1u;
  write_bytes[0] = 0xa5u;

  check_int64("block device prepare",
              er_block_device_prepare(&device,
                                      DISK_ANALYZER_TEST_BLOCK_BYTES,
                                      DISK_ANALYZER_TEST_BLOCK_COUNT,
                                      id,
                                      "nvme0n1",
                                      7u,
                                      &fake,
                                      disk_analyzer_fake_read,
                                      disk_analyzer_fake_write,
                                      disk_analyzer_fake_flush),
              1);
  check_int64("block device reject range",
              er_block_device_read(&device,
                                   DISK_ANALYZER_TEST_BLOCK_COUNT,
                                   1u,
                                   read_bytes,
                                   DISK_ANALYZER_TEST_BLOCK_BYTES),
              0);
  check_int64("block device write",
              er_block_device_write(&device,
                                    3u,
                                    1u,
                                    write_bytes,
                                    DISK_ANALYZER_TEST_BLOCK_BYTES),
              1);
  check_int64("block device read",
              er_block_device_read(&device,
                                   3u,
                                   1u,
                                   read_bytes,
                                   DISK_ANALYZER_TEST_BLOCK_BYTES),
              1);
  check_uint64("block device read byte", read_bytes[0], 0xa5u);
  check_int64("block device flush", er_block_device_flush(&device), 1);
  check_uint64("block device flushed", fake.flushed, 1u);
}

static void test_disk_analyzer_cache_policy(void) {
  ErDiskAnalyzerCacheMatch match;

  check_int64("cache policy classifies cmake",
              er_disk_analyzer_classify_cache_path("src/cmake-build-debug/app",
                                                   25u,
                                                   &match),
              1);
  check_uint64("cache policy cmake kind",
               match.cache_kind,
               ER_DISK_ANALYZER_CACHE_C_BUILD);
  check_uint64("cache policy cmake offset", match.segment_offset, 4u);
  check_int64("cache policy classifies node",
              er_disk_analyzer_classify_cache_path("web/node_modules/pkg",
                                                   20u,
                                                   &match),
              1);
  check_uint64("cache policy node kind",
               match.cache_kind,
               ER_DISK_ANALYZER_CACHE_NODE);
  check_int64("cache policy classifies python",
              er_disk_analyzer_classify_cache_path("pkg/.venv/lib",
                                                   13u,
                                                   &match),
              1);
  check_uint64("cache policy python kind",
               match.cache_kind,
               ER_DISK_ANALYZER_CACHE_PYTHON);
  check_int64("cache policy rejects normal path",
              er_disk_analyzer_classify_cache_path("home/user/doc.txt",
                                                   17u,
                                                   &match),
              0);
  check_cstr("cache policy label",
             er_disk_analyzer_cache_kind_label(ER_DISK_ANALYZER_CACHE_RUST),
             "rust");
}

static void test_zfs_label_probe(void) {
  DiskAnalyzerFakeDevice fake;
  ErBlockDevice device;
  ErZfsPoolProbe probe;
  ErZfsUberblockSummary summary;
  UINT8 id[ER_BLOCK_DEVICE_ID_BYTES];
  UINT8 label[ER_ZFS_LABEL_BYTES];
  UINT8* uberblock;
  UINT64 offset = 0u;

  er_mem_zero((UINT8*)&fake, (UINTN)sizeof(fake));
  er_mem_zero(id, ER_BLOCK_DEVICE_ID_BYTES);
  er_mem_zero(label, ER_ZFS_LABEL_BYTES);
  id[0] = 2u;
  uberblock = fake.bytes + DISK_ANALYZER_TEST_UBERBLOCK_OFFSET;
  disk_analyzer_put_le64(uberblock, ER_ZFS_UBERBLOCK_MAGIC);
  disk_analyzer_put_le64(uberblock + 8u, 1u);
  disk_analyzer_put_le64(uberblock + 16u, DISK_ANALYZER_TEST_UBERBLOCK_TXG);
  disk_analyzer_put_le64(uberblock + 24u, 9u);
  disk_analyzer_put_le64(uberblock + 32u, DISK_ANALYZER_TEST_UBERBLOCK_TIMESTAMP);
  disk_analyzer_put_le64(uberblock + 40u, 0xfeedu);

  check_int64("zfs head label offset",
              er_zfs_label_slot_offset(DISK_ANALYZER_TEST_DEVICE_BYTES,
                                       ER_ZFS_LABEL_SLOT_HEAD0,
                                       &offset),
              1);
  check_uint64("zfs head label offset value", offset, 0u);
  check_int64("zfs tail label offset",
              er_zfs_label_slot_offset(DISK_ANALYZER_TEST_DEVICE_BYTES,
                                       ER_ZFS_LABEL_SLOT_TAIL1,
                                       &offset),
              1);
  check_uint64("zfs tail label offset value",
               offset,
               DISK_ANALYZER_TEST_DEVICE_BYTES - ER_ZFS_LABEL_BYTES);
  check_int64("zfs probe label bytes",
              er_zfs_probe_label_bytes(fake.bytes,
                                       ER_ZFS_LABEL_BYTES,
                                       ER_ZFS_LABEL_SLOT_HEAD0,
                                       0u,
                                       &summary),
              1);
  check_uint64("zfs probe label txg", summary.txg, DISK_ANALYZER_TEST_UBERBLOCK_TXG);
  check_uint64("zfs probe label timestamp", summary.timestamp, DISK_ANALYZER_TEST_UBERBLOCK_TIMESTAMP);
  check_uint64("zfs probe rootbp word", summary.rootbp_words[0], 0xfeedu);

  check_int64("zfs fake block prepare",
              er_block_device_prepare(&device,
                                      DISK_ANALYZER_TEST_BLOCK_BYTES,
                                      DISK_ANALYZER_TEST_BLOCK_COUNT,
                                      id,
                                      "nvme0n1",
                                      7u,
                                      &fake,
                                      disk_analyzer_fake_read,
                                      disk_analyzer_fake_write,
                                      disk_analyzer_fake_flush),
              1);
  check_int64("zfs probe pool",
              er_zfs_probe_pool(&device, label, ER_ZFS_LABEL_BYTES, &probe),
              1);
  check_uint64("zfs pool labels", probe.label_count, 1u);
  check_uint64("zfs pool selected txg", probe.selected_txg, DISK_ANALYZER_TEST_UBERBLOCK_TXG);
}

static void test_nvme_register_helpers(void) {
  ErPciDeviceSnapshot snapshot;
  ErPciBarSelection bar;
  ErNvmeQueueMemory memory;
  ErNvmeController controller;
  UINT8 admin_sq[ER_NVME_ADMIN_QUEUE_DEPTH * 64u];
  UINT8 admin_cq[ER_NVME_ADMIN_QUEUE_DEPTH * 16u];
  UINT8 io_sq[ER_NVME_IO_QUEUE_DEPTH * 64u];
  UINT8 io_cq[ER_NVME_IO_QUEUE_DEPTH * 16u];
  UINT64 cap = (1ULL << DISK_ANALYZER_TEST_CAP_DSTRD_SHIFT) |
               (0ULL << DISK_ANALYZER_TEST_CAP_MPSMIN_SHIFT);

  er_mem_zero((UINT8*)&snapshot, (UINTN)sizeof(snapshot));
  er_mem_zero((UINT8*)&memory, (UINTN)sizeof(memory));
  snapshot.present = 1u;
  snapshot.id = 0x12348086u;
  snapshot.class_revision = 0x01080200u;
  snapshot.bars[0] = 0x80000000u;
  snapshot.bars[1] = 0u;
  memory.admin_sq = admin_sq;
  memory.admin_cq = admin_cq;
  memory.io_sq = io_sq;
  memory.io_cq = io_cq;
  memory.admin_sq_bytes = (UINT32)sizeof(admin_sq);
  memory.admin_cq_bytes = (UINT32)sizeof(admin_cq);
  memory.io_sq_bytes = (UINT32)sizeof(io_sq);
  memory.io_cq_bytes = (UINT32)sizeof(io_cq);

  check_int64("nvme pci snapshot supported",
              er_nvme_pci_snapshot_supported(&snapshot, &bar),
              1);
  check_uint64("nvme pci bar index", bar.index, 0u);
  check_uint64("nvme pci bar base", bar.info.base, 0x80000000u);
  check_uint64("nvme doorbell stride",
               er_nvme_doorbell_stride_from_cap(cap),
               8u);
  check_uint64("nvme page bytes",
               er_nvme_page_bytes_from_cap(cap),
               4096u);
  check_int64("nvme queue memory valid",
              er_nvme_queue_memory_valid(&memory),
              1);
  check_int64("nvme prepare controller",
              er_nvme_prepare_controller(0x80000000u,
                                         0x1000u,
                                         cap,
                                         0x00010400u,
                                         &memory,
                                         &controller),
              1);
  check_uint64("nvme controller page bytes", controller.page_bytes, 4096u);
  check_uint64("nvme controller initialized", controller.initialized, 1u);
}

static void test_disk_analyzer_storage_foundation(void) {
  test_block_device_contract();
  test_disk_analyzer_cache_policy();
  test_zfs_label_probe();
  test_nvme_register_helpers();
}

#define _POSIX_C_SOURCE 200809L

/*
 * Purpose:
 *   Boot BCM2708-family Raspberry Pi boards through Linux usbfs.
 * Intention:
 *   Keep Pi USB boot bring-up repository-owned instead of depending on
 *   external rpiboot/libusb helper binaries.
 */

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <linux/usbdevice_fs.h>

enum {
  ERPIUSB_VENDOR_BROADCOM = 0x0a5c,
  ERPIUSB_PRODUCT_BCM2708 = 0x2763,
  ERPIUSB_PRODUCT_BCM2709 = 0x2764,
  ERPIUSB_PRODUCT_BCM2711 = 0x2711,
  ERPIUSB_PRODUCT_BCM2712 = 0x2712,
  ERPIUSB_DESCRIPTOR_DEVICE = 1,
  ERPIUSB_DESCRIPTOR_CONFIG = 2,
  ERPIUSB_DESCRIPTOR_INTERFACE = 4,
  ERPIUSB_DESCRIPTOR_ENDPOINT = 5,
  ERPIUSB_DEVICE_DESCRIPTOR_BYTES = 18,
  ERPIUSB_CONFIG_HEAD_BYTES = 9,
  ERPIUSB_REQUEST_GET_DESCRIPTOR = 6,
  ERPIUSB_CONTROL_IN = 0x80,
  ERPIUSB_VENDOR_IN = 0xc0,
  ERPIUSB_VENDOR_OUT = 0x40,
  ERPIUSB_REQUEST_VENDOR = 0,
  ERPIUSB_VENDOR_CLASS = 0xff,
  ERPIUSB_BULK_ATTR = 0x02,
  ERPIUSB_ENDPOINT_IN = 0x80,
  ERPIUSB_DEFAULT_OUT_EP = 0x01,
  ERPIUSB_DEFAULT_IN_EP = 0x82,
  ERPIUSB_PACKET_BYTES = 64,
  ERPIUSB_BOOT_HEADER_BYTES = 24,
  ERPIUSB_FILE_NAME_BYTES = 256,
  ERPIUSB_FILE_REQUEST_BYTES = 260,
  ERPIUSB_PATH_BYTES = 4096,
  ERPIUSB_MAX_BULK_BYTES = 16384,
  ERPIUSB_SMALL_BULK_THRESHOLD_BYTES = 4096,
  ERPIUSB_SCAN_MAX = 255,
  ERPIUSB_REENUMERATE_TRIES = 100,
  ERPIUSB_REENUMERATE_DELAY_NS = 100000000,
  ERPIUSB_CONTROL_TIMEOUT_MS = 20000,
  ERPIUSB_BOOT_CONTROL_TIMEOUT_MS = 1000,
  ERPIUSB_BULK_TIMEOUT_MS = 20000,
  ERPIUSB_CMD_GET_FILE_SIZE = 0,
  ERPIUSB_CMD_READ_FILE = 1,
  ERPIUSB_CMD_DONE = 2,
  ERPIUSB_TEXT_BYTES = 64,
  ERPIUSB_EXIT_USAGE = 2
};

typedef struct {
  const char* boot_dir;
  const char* device_path;
  int dry_run;
  int verbose;
} ErPiUsbConfig;

typedef struct {
  int fd;
  uint16_t product_id;
  uint8_t serial_index;
  uint8_t interface_number;
  uint8_t out_endpoint_seen;
  uint8_t in_endpoint;
  uint8_t out_endpoint;
} ErPiUsbDevice;

typedef struct {
  int command;
  char name[ERPIUSB_FILE_NAME_BYTES];
} ErPiUsbFileRequest;

static int erpiusb_fail(const char* message) {
  fprintf(stderr, "pi-usb-boot: %s\n", message);
  return 1;
}

static int erpiusb_usage(const char* program) {
  fprintf(stderr,
          "usage: %s --boot-dir <dir> [--device /dev/bus/usb/BBB/DDD] [--dry-run] [--verbose]\n",
          program);
  return ERPIUSB_EXIT_USAGE;
}

static int erpiusb_parse_args(int argc, char** argv, ErPiUsbConfig* cfg) {
  int i;

  if (cfg == NULL) {
    return 1;
  }
  cfg->boot_dir = NULL;
  cfg->device_path = NULL;
  cfg->dry_run = 0;
  cfg->verbose = 0;
  for (i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--boot-dir") == 0) {
      ++i;
      if (i >= argc) {
        return erpiusb_usage(argv[0]);
      }
      cfg->boot_dir = argv[i];
    } else if (strcmp(argv[i], "--device") == 0) {
      ++i;
      if (i >= argc) {
        return erpiusb_usage(argv[0]);
      }
      cfg->device_path = argv[i];
    } else if (strcmp(argv[i], "--dry-run") == 0) {
      cfg->dry_run = 1;
    } else if (strcmp(argv[i], "--verbose") == 0) {
      cfg->verbose = 1;
    } else {
      return erpiusb_usage(argv[0]);
    }
  }
  if (cfg->boot_dir == NULL) {
    return erpiusb_usage(argv[0]);
  }
  return 0;
}

static uint16_t erpiusb_get_le16(const unsigned char* bytes) {
  return (uint16_t)((uint16_t)bytes[0] | ((uint16_t)bytes[1] << 8u));
}

static void erpiusb_put_le32(unsigned char* bytes, uint32_t value) {
  bytes[0] = (unsigned char)(value & 0xffu);
  bytes[1] = (unsigned char)((value >> 8u) & 0xffu);
  bytes[2] = (unsigned char)((value >> 16u) & 0xffu);
  bytes[3] = (unsigned char)((value >> 24u) & 0xffu);
}

static int erpiusb_path_join(char* out,
                             size_t out_len,
                             const char* left,
                             const char* right) {
  int written;

  if (out == NULL || left == NULL || right == NULL ||
      left[0] == '\0' || right[0] == '\0' ||
      right[0] == '/' || strstr(right, "..") != NULL) {
    return 0;
  }
  written = snprintf(out, out_len, "%s/%s", left, right);
  return written >= 0 && (size_t)written < out_len;
}

static int erpiusb_file_size(const char* path, uint32_t* out_size) {
  struct stat st;

  if (path == NULL || out_size == NULL ||
      stat(path, &st) != 0 || !S_ISREG(st.st_mode) ||
      st.st_size <= 0 || (uint64_t)st.st_size > UINT32_MAX) {
    return 0;
  }
  *out_size = (uint32_t)st.st_size;
  return 1;
}

static int erpiusb_read_file(const char* path,
                             unsigned char** out_bytes,
                             uint32_t* out_len) {
  FILE* file;
  unsigned char* bytes;
  uint32_t len;

  if (out_bytes == NULL || out_len == NULL ||
      erpiusb_file_size(path, &len) == 0) {
    return 0;
  }
  bytes = (unsigned char*)malloc((size_t)len);
  if (bytes == NULL) {
    return 0;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    free(bytes);
    return 0;
  }
  if (fread(bytes, 1u, (size_t)len, file) != (size_t)len ||
      fclose(file) != 0) {
    free(bytes);
    return 0;
  }
  *out_bytes = bytes;
  *out_len = len;
  return 1;
}

static const char* erpiusb_second_stage_name(uint16_t product_id) {
  switch (product_id) {
    case ERPIUSB_PRODUCT_BCM2708:
    case ERPIUSB_PRODUCT_BCM2709:
      return "bootcode.bin";
    case ERPIUSB_PRODUCT_BCM2711:
      return "bootcode4.bin";
    case ERPIUSB_PRODUCT_BCM2712:
      return "bootcode5.bin";
    default:
      return NULL;
  }
}

static int erpiusb_boot_dir_valid_for_product(const char* boot_dir,
                                              uint16_t product_id) {
  const char* second_stage = erpiusb_second_stage_name(product_id);
  char path[ERPIUSB_PATH_BYTES];
  uint32_t size;

  if (second_stage == NULL ||
      erpiusb_path_join(path, sizeof(path), boot_dir, second_stage) == 0 ||
      erpiusb_file_size(path, &size) == 0) {
    return erpiusb_fail("boot directory must contain the required non-empty Raspberry Pi second-stage bootcode");
  }
  return 0;
}

static int erpiusb_boot_dir_valid(const char* boot_dir) {
  char path[ERPIUSB_PATH_BYTES];
  uint32_t size;

  if (boot_dir == NULL ||
      erpiusb_path_join(path, sizeof(path), boot_dir, "bootcode.bin") == 0 ||
      erpiusb_file_size(path, &size) == 0) {
    return erpiusb_fail("boot directory must contain non-empty bootcode.bin");
  }
  return 0;
}

static int erpiusb_control(int fd,
                           uint8_t request_type,
                           uint16_t value,
                           uint16_t index,
                           void* data,
                           uint16_t length,
                           uint32_t timeout_ms) {
  struct usbdevfs_ctrltransfer transfer;
  int ret;

  memset(&transfer, 0, sizeof(transfer));
  transfer.bRequestType = request_type;
  transfer.bRequest = ERPIUSB_REQUEST_VENDOR;
  transfer.wValue = value;
  transfer.wIndex = index;
  transfer.wLength = length;
  transfer.timeout = timeout_ms;
  transfer.data = data;
  ret = ioctl(fd, USBDEVFS_CONTROL, &transfer);
  if (ret < 0) {
    return -errno;
  }
  return ret;
}

static int erpiusb_bulk(int fd,
                        uint8_t endpoint,
                        void* data,
                        uint32_t len) {
  struct usbdevfs_bulktransfer transfer;
  int ret;

  memset(&transfer, 0, sizeof(transfer));
  transfer.ep = endpoint;
  transfer.len = (unsigned int)len;
  transfer.timeout = ERPIUSB_BULK_TIMEOUT_MS;
  transfer.data = data;
  ret = ioctl(fd, USBDEVFS_BULK, &transfer);
  if (ret < 0) {
    return -errno;
  }
  return ret;
}

static int erpiusb_clear_halt(int fd, uint8_t endpoint) {
  unsigned int ep = endpoint;

  return ioctl(fd, USBDEVFS_CLEAR_HALT, &ep) == 0;
}

static int erpiusb_parse_config(const unsigned char* config,
                                uint16_t len,
                                ErPiUsbDevice* device) {
  uint16_t offset = 0u;
  uint8_t vendor_interface = 0u;

  device->interface_number = 0u;
  device->in_endpoint = ERPIUSB_DEFAULT_IN_EP;
  device->out_endpoint = ERPIUSB_DEFAULT_OUT_EP;
  while ((uint32_t)offset + 2u <= len) {
    uint8_t descriptor_len = config[offset];
    uint8_t descriptor_type = config[offset + 1u];
    if (descriptor_len == 0u || (uint32_t)offset + descriptor_len > len) {
      return 0;
    }
    if (descriptor_type == ERPIUSB_DESCRIPTOR_INTERFACE &&
        descriptor_len >= 9u) {
      vendor_interface = (uint8_t)(config[offset + 5u] == ERPIUSB_VENDOR_CLASS);
      if (vendor_interface != 0u) {
        device->interface_number = config[offset + 2u];
      }
    } else if (descriptor_type == ERPIUSB_DESCRIPTOR_ENDPOINT &&
               vendor_interface != 0u &&
               descriptor_len >= 7u &&
               config[offset + 3u] == ERPIUSB_BULK_ATTR &&
               erpiusb_get_le16(config + offset + 4u) == ERPIUSB_PACKET_BYTES) {
      if ((config[offset + 2u] & ERPIUSB_ENDPOINT_IN) != 0u) {
        device->in_endpoint = config[offset + 2u];
      } else if (device->out_endpoint_seen == 0u) {
        device->out_endpoint = config[offset + 2u];
        device->out_endpoint_seen = 1u;
      }
    }
    offset = (uint16_t)(offset + descriptor_len);
  }
  return 1;
}

static int erpiusb_read_exact_file(const char* path,
                                   unsigned char* out,
                                   size_t out_cap,
                                   size_t* out_len) {
  FILE* file;
  size_t len;

  if (path == NULL || out == NULL || out_len == NULL || out_cap == 0u) {
    return 0;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }
  len = fread(out, 1u, out_cap, file);
  if (ferror(file) != 0 || fclose(file) != 0) {
    return 0;
  }
  *out_len = len;
  return 1;
}

static int erpiusb_read_text_uint(const char* path,
                                  unsigned int radix,
                                  unsigned int* out_value) {
  char text[ERPIUSB_TEXT_BYTES];
  FILE* file;
  char* end;
  unsigned long value;

  if (path == NULL || out_value == NULL) {
    return 0;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }
  if (fgets(text, sizeof(text), file) == NULL || fclose(file) != 0) {
    return 0;
  }
  errno = 0;
  value = strtoul(text, &end, (int)radix);
  if (errno != 0 || end == text || value > UINT32_MAX) {
    return 0;
  }
  *out_value = (unsigned int)value;
  return 1;
}

static int erpiusb_sysfs_join(char* out,
                              size_t out_len,
                              const char* dir,
                              const char* name) {
  int written;

  if (out == NULL || dir == NULL || name == NULL ||
      dir[0] == '\0' || name[0] == '\0') {
    return 0;
  }
  written = snprintf(out, out_len, "%s/%s", dir, name);
  return written >= 0 && (size_t)written < out_len;
}

static int erpiusb_load_sysfs_device(const char* sysfs_dir,
                                     ErPiUsbDevice* device) {
  unsigned char descriptors[ERPIUSB_PATH_BYTES];
  char path[ERPIUSB_PATH_BYTES];
  size_t descriptors_len;
  uint16_t product;
  uint16_t cfg_len;

  if (sysfs_dir == NULL || device == NULL ||
      erpiusb_sysfs_join(path, sizeof(path), sysfs_dir, "descriptors") == 0 ||
      erpiusb_read_exact_file(path,
                              descriptors,
                              sizeof(descriptors),
                              &descriptors_len) == 0 ||
      descriptors_len < ERPIUSB_DEVICE_DESCRIPTOR_BYTES + ERPIUSB_CONFIG_HEAD_BYTES ||
      descriptors[1u] != ERPIUSB_DESCRIPTOR_DEVICE ||
      erpiusb_get_le16(descriptors + 8u) != ERPIUSB_VENDOR_BROADCOM) {
    return 0;
  }
  product = erpiusb_get_le16(descriptors + 10u);
  if (erpiusb_second_stage_name(product) == NULL ||
      descriptors[ERPIUSB_DEVICE_DESCRIPTOR_BYTES + 1u] != ERPIUSB_DESCRIPTOR_CONFIG) {
    return 0;
  }
  cfg_len = erpiusb_get_le16(descriptors + ERPIUSB_DEVICE_DESCRIPTOR_BYTES + 2u);
  if ((size_t)cfg_len + ERPIUSB_DEVICE_DESCRIPTOR_BYTES > descriptors_len) {
    return 0;
  }
  memset(device, 0, sizeof(*device));
  device->fd = -1;
  device->product_id = product;
  device->serial_index = descriptors[16u];
  return erpiusb_parse_config(descriptors + ERPIUSB_DEVICE_DESCRIPTOR_BYTES,
                              cfg_len,
                              device);
}

static int erpiusb_find_sysfs_by_bus_device(unsigned int wanted_bus,
                                            unsigned int wanted_dev,
                                            char* out_dir,
                                            size_t out_dir_len,
                                            ErPiUsbDevice* out_device) {
  DIR* dir;
  struct dirent* entry;
  char candidate[ERPIUSB_PATH_BYTES];
  char path[ERPIUSB_PATH_BYTES];
  unsigned int bus;
  unsigned int dev;
  int written;

  dir = opendir("/sys/bus/usb/devices");
  if (dir == NULL) {
    return 0;
  }
  while ((entry = readdir(dir)) != NULL) {
    if (entry->d_name[0] == '.') {
      continue;
    }
    written = snprintf(candidate,
                       sizeof(candidate),
                       "/sys/bus/usb/devices/%s",
                       entry->d_name);
    if (written < 0 || (size_t)written >= sizeof(candidate)) {
      closedir(dir);
      return 0;
    }
    if (erpiusb_sysfs_join(path, sizeof(path), candidate, "busnum") == 0 ||
        erpiusb_read_text_uint(path, 10u, &bus) == 0 ||
        erpiusb_sysfs_join(path, sizeof(path), candidate, "devnum") == 0 ||
        erpiusb_read_text_uint(path, 10u, &dev) == 0 ||
        bus != wanted_bus ||
        dev != wanted_dev ||
        erpiusb_load_sysfs_device(candidate, out_device) == 0) {
      continue;
    }
    written = snprintf(out_dir, out_dir_len, "%s", candidate);
    closedir(dir);
    return written >= 0 && (size_t)written < out_dir_len;
  }
  closedir(dir);
  return 0;
}

static int erpiusb_path_bus_device(const char* path,
                                   unsigned int* out_bus,
                                   unsigned int* out_dev) {
  unsigned int bus;
  unsigned int dev;

  if (path == NULL || out_bus == NULL || out_dev == NULL ||
      sscanf(path, "/dev/bus/usb/%u/%u", &bus, &dev) != 2) {
    return 0;
  }
  *out_bus = bus;
  *out_dev = dev;
  return 1;
}

static int erpiusb_open_path_with_metadata(const char* path,
                                           const ErPiUsbDevice* metadata,
                                           ErPiUsbDevice* device) {
  unsigned int interface_number;
  int fd;

  if (path == NULL || metadata == NULL || device == NULL) {
    return 0;
  }
  fd = open(path, O_RDWR);
  if (fd < 0) {
    return 0;
  }
  *device = *metadata;
  interface_number = device->interface_number;
  if (ioctl(fd, USBDEVFS_CLAIMINTERFACE, &interface_number) < 0) {
    close(fd);
    device->fd = -1;
    return 0;
  }
  device->fd = fd;
  return 1;
}

static int erpiusb_settle_before_open(void) {
  const struct timespec delay = {1, 0};

  return nanosleep(&delay, NULL) == 0;
}

static int erpiusb_open_any(const ErPiUsbConfig* cfg,
                            ErPiUsbDevice* device,
                            int honor_device_path) {
  char path[ERPIUSB_PATH_BYTES];
  char sysfs_dir[ERPIUSB_PATH_BYTES];
  unsigned int bus;
  unsigned int dev;
  int written;
  DIR* dir;
  struct dirent* entry;
  ErPiUsbDevice metadata;

  if (honor_device_path != 0 && cfg->device_path != NULL) {
    if (erpiusb_path_bus_device(cfg->device_path, &bus, &dev) == 0 ||
        erpiusb_find_sysfs_by_bus_device(bus,
                                         dev,
                                         sysfs_dir,
                                         sizeof(sysfs_dir),
                                         &metadata) == 0) {
      return 0;
    }
    if (erpiusb_settle_before_open() == 0) {
      return 0;
    }
    return erpiusb_open_path_with_metadata(cfg->device_path, &metadata, device);
  }
  dir = opendir("/sys/bus/usb/devices");
  if (dir == NULL) {
    return 0;
  }
  while ((entry = readdir(dir)) != NULL) {
    if (entry->d_name[0] == '.') {
      continue;
    }
    written = snprintf(sysfs_dir,
                       sizeof(sysfs_dir),
                       "/sys/bus/usb/devices/%s",
                       entry->d_name);
    if (written < 0 || (size_t)written >= sizeof(sysfs_dir)) {
      closedir(dir);
      return 0;
    }
    if (erpiusb_load_sysfs_device(sysfs_dir, &metadata) == 0) {
      continue;
    }
    if (erpiusb_sysfs_join(path, sizeof(path), sysfs_dir, "busnum") == 0 ||
        erpiusb_read_text_uint(path, 10u, &bus) == 0 ||
        erpiusb_sysfs_join(path, sizeof(path), sysfs_dir, "devnum") == 0 ||
        erpiusb_read_text_uint(path, 10u, &dev) == 0) {
      continue;
    }
    written = snprintf(path, sizeof(path), "/dev/bus/usb/%03u/%03u", bus, dev);
    if (written < 0 || (size_t)written >= sizeof(path)) {
      closedir(dir);
      return 0;
    }
    if (erpiusb_settle_before_open() == 0) {
      closedir(dir);
      return 0;
    }
    if (erpiusb_open_path_with_metadata(path, &metadata, device) != 0) {
      closedir(dir);
      return 1;
    }
  }
  closedir(dir);
  return 0;
}

static void erpiusb_close(ErPiUsbDevice* device) {
  unsigned int interface_number;

  if (device != NULL && device->fd >= 0) {
    interface_number = device->interface_number;
    (void)ioctl(device->fd, USBDEVFS_RELEASEINTERFACE, &interface_number);
    (void)close(device->fd);
    device->fd = -1;
  }
}

static int erpiusb_ep_write(ErPiUsbDevice* device,
                            const unsigned char* bytes,
                            uint32_t len,
                            int packetized) {
  uint32_t offset = 0u;
  int ret;

  ret = erpiusb_control(device->fd,
                        ERPIUSB_VENDOR_OUT,
                        (uint16_t)(len & 0xffffu),
                        (uint16_t)(len >> 16u),
                        NULL,
                        0u,
                        ERPIUSB_BOOT_CONTROL_TIMEOUT_MS);
  if (ret != 0) {
    fprintf(stderr, "pi-usb-boot: write-control failed: %d\n", ret);
    return 0;
  }
  while (offset < len) {
    uint32_t chunk = len - offset;
    uint32_t max_chunk = (packetized != 0 ||
                          len <= ERPIUSB_SMALL_BULK_THRESHOLD_BYTES) ?
                         ERPIUSB_PACKET_BYTES :
                         ERPIUSB_MAX_BULK_BYTES;
    if (chunk > max_chunk) {
      chunk = max_chunk;
    }
    ret = erpiusb_bulk(device->fd, device->out_endpoint, (void*)(bytes + offset), chunk);
    if (ret == -ETIMEDOUT &&
        erpiusb_clear_halt(device->fd, device->out_endpoint) != 0) {
      ret = erpiusb_bulk(device->fd,
                         device->out_endpoint,
                         (void*)(bytes + offset),
                         chunk);
    }
    if (ret < 0 || (uint32_t)ret != chunk) {
      fprintf(stderr,
              "pi-usb-boot: bulk write failed: ret=%d offset=%u chunk=%u total=%u endpoint=%u\n",
              ret, offset, chunk, len, device->out_endpoint);
      return 0;
    }
    offset += chunk;
  }
  return 1;
}

static int erpiusb_ep_read(ErPiUsbDevice* device,
                           unsigned char* bytes,
                           uint32_t len) {
  int ret = erpiusb_control(device->fd,
                            ERPIUSB_VENDOR_IN,
                            (uint16_t)(len & 0xffffu),
                            (uint16_t)(len >> 16u),
                            bytes,
                            (uint16_t)len,
                            ERPIUSB_CONTROL_TIMEOUT_MS);
  if (ret < 0) {
    return ret;
  }
  if (ret != (int)len) {
    return -EIO;
  }
  return (int)len;
}

static int erpiusb_send_second_stage(const ErPiUsbConfig* cfg,
                                     ErPiUsbDevice* device) {
  const char* name = erpiusb_second_stage_name(device->product_id);
  char path[ERPIUSB_PATH_BYTES];
  unsigned char header[ERPIUSB_BOOT_HEADER_BYTES];
  unsigned char* bytes = NULL;
  uint32_t len = 0u;
  uint32_t retcode = 1u;
  int ok;

  if (name == NULL ||
      erpiusb_path_join(path, sizeof(path), cfg->boot_dir, name) == 0 ||
      erpiusb_read_file(path, &bytes, &len) == 0) {
    return erpiusb_fail("failed to read second-stage bootcode");
  }
  memset(header, 0, sizeof(header));
  erpiusb_put_le32(header, len);
  if (cfg->verbose != 0) {
    fprintf(stderr, "pi-usb-boot: sending %s (%u bytes)\n", name, len);
  }
  ok = erpiusb_ep_write(device, header, sizeof(header), 0) != 0 &&
       erpiusb_ep_write(device, bytes, len, 0) != 0;
  free(bytes);
  if (ok == 0) {
    return 0;
  }
  if (erpiusb_ep_read(device,
                      (unsigned char*)&retcode,
                      (uint32_t)sizeof(retcode)) != (int)sizeof(retcode) ||
      retcode != 0u) {
    fprintf(stderr, "pi-usb-boot: boot ROM rejected second stage: 0x%08x\n",
            retcode);
    return 0;
  }
  return 1;
}

static int erpiusb_send_file_size(ErPiUsbDevice* device, uint32_t size) {
  return erpiusb_control(device->fd,
                         ERPIUSB_VENDOR_OUT,
                         (uint16_t)(size & 0xffffu),
                         (uint16_t)(size >> 16u),
                         NULL,
                         0u,
                         ERPIUSB_BOOT_CONTROL_TIMEOUT_MS) == 0;
}

static int erpiusb_serve_file(const ErPiUsbConfig* cfg,
                              ErPiUsbDevice* device,
                              const char* name) {
  char path[ERPIUSB_PATH_BYTES];
  unsigned char* bytes = NULL;
  uint32_t size = 0u;
  int ok;

  if (erpiusb_path_join(path, sizeof(path), cfg->boot_dir, name) == 0 ||
      erpiusb_read_file(path, &bytes, &size) == 0) {
    (void)erpiusb_ep_write(device, NULL, 0u, 0);
    fprintf(stderr, "pi-usb-boot: missing requested file %s\n", name);
    return 0;
  }
  if (cfg->verbose != 0) {
    fprintf(stderr, "pi-usb-boot: serving %s (%u bytes)\n", name, size);
  }
  ok = erpiusb_ep_write(device,
                        bytes,
                        size,
                        strcmp(name, "kernel.img") == 0);
  free(bytes);
  return ok;
}

static int erpiusb_file_server(const ErPiUsbConfig* cfg,
                               ErPiUsbDevice* device) {
  ErPiUsbFileRequest req;
  char path[ERPIUSB_PATH_BYTES];
  uint32_t size;
  int ret;

  for (;;) {
    memset(&req, 0, sizeof(req));
    ret = erpiusb_ep_read(device, (unsigned char*)&req, sizeof(req));
    if (ret < 0) {
      fprintf(stderr, "pi-usb-boot: request read failed: %d\n", ret);
      return 0;
    }
    req.name[ERPIUSB_FILE_NAME_BYTES - 1u] = '\0';
    if (req.command == ERPIUSB_CMD_DONE || req.name[0] == '\0') {
      (void)erpiusb_ep_write(device, NULL, 0u, 0);
      return 1;
    }
    if (cfg->verbose != 0) {
      fprintf(stderr, "pi-usb-boot: request command=%d file=%s\n",
              req.command, req.name);
    }
    switch (req.command) {
      case ERPIUSB_CMD_GET_FILE_SIZE:
        if (erpiusb_path_join(path, sizeof(path), cfg->boot_dir, req.name) == 0 ||
            erpiusb_file_size(path, &size) == 0) {
          if (erpiusb_ep_write(device, NULL, 0u, 0) == 0) {
            return 0;
          }
          break;
        }
        if (erpiusb_send_file_size(device, size) == 0) {
          return 0;
        }
        break;
      case ERPIUSB_CMD_READ_FILE:
        if (erpiusb_serve_file(cfg, device, req.name) == 0) {
          return 0;
        }
        break;
      default:
        return erpiusb_fail("unknown boot file-server command");
    }
  }
}

static int erpiusb_wait_for_second_stage(const ErPiUsbConfig* cfg,
                                         ErPiUsbDevice* device) {
  const struct timespec delay = {0, ERPIUSB_REENUMERATE_DELAY_NS};
  int tries;

  erpiusb_close(device);
  for (tries = 0; tries < ERPIUSB_REENUMERATE_TRIES; ++tries) {
    if (nanosleep(&delay, NULL) != 0) {
      return erpiusb_fail("second-stage reenumeration wait interrupted");
    }
    if (erpiusb_open_any(cfg, device, 0) != 0) {
      if (device->serial_index != 0u && device->serial_index != 3u) {
        return 0;
      }
      erpiusb_close(device);
    }
  }
  return erpiusb_fail("second-stage device did not enumerate");
}

static int erpiusb_boot(const ErPiUsbConfig* cfg) {
  ErPiUsbDevice device;

  if (erpiusb_boot_dir_valid(cfg->boot_dir) != 0) {
    return 1;
  }
  if (cfg->dry_run != 0) {
    printf("pi-usb-boot: boot directory ready: %s\n", cfg->boot_dir);
    return 0;
  }
  if (erpiusb_open_any(cfg, &device, 1) == 0) {
    return erpiusb_fail("Broadcom USB boot device not found");
  }
  if (erpiusb_boot_dir_valid_for_product(cfg->boot_dir, device.product_id) != 0) {
    erpiusb_close(&device);
    return 1;
  }
  if (device.serial_index == 0u || device.serial_index == 3u) {
    if (erpiusb_send_second_stage(cfg, &device) == 0 ||
        erpiusb_wait_for_second_stage(cfg, &device) != 0) {
      erpiusb_close(&device);
      return 1;
    }
  }
  if (cfg->verbose != 0) {
    fprintf(stderr, "pi-usb-boot: file server active\n");
  }
  if (erpiusb_file_server(cfg, &device) == 0) {
    erpiusb_close(&device);
    return 1;
  }
  erpiusb_close(&device);
  printf("pi-usb-boot: boot server completed\n");
  return 0;
}

int main(int argc, char** argv) {
  ErPiUsbConfig cfg;

  if (erpiusb_parse_args(argc, argv, &cfg) != 0) {
    return ERPIUSB_EXIT_USAGE;
  }
  return erpiusb_boot(&cfg);
}

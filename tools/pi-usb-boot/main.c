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
  ERPIUSB_SCAN_MAX = 255,
  ERPIUSB_REENUMERATE_TRIES = 100,
  ERPIUSB_REENUMERATE_DELAY_NS = 100000000,
  ERPIUSB_CONTROL_TIMEOUT_MS = 20000,
  ERPIUSB_BOOT_CONTROL_TIMEOUT_MS = 1000,
  ERPIUSB_BULK_TIMEOUT_MS = 5000,
  ERPIUSB_CMD_GET_FILE_SIZE = 0,
  ERPIUSB_CMD_READ_FILE = 1,
  ERPIUSB_CMD_DONE = 2,
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

static int erpiusb_descriptor(int fd,
                              uint8_t descriptor_type,
                              void* out,
                              uint16_t out_len) {
  struct usbdevfs_ctrltransfer transfer;
  int ret;

  memset(&transfer, 0, sizeof(transfer));
  transfer.bRequestType = ERPIUSB_CONTROL_IN;
  transfer.bRequest = ERPIUSB_REQUEST_GET_DESCRIPTOR;
  transfer.wValue = (uint16_t)((uint16_t)descriptor_type << 8u);
  transfer.wLength = out_len;
  transfer.timeout = ERPIUSB_CONTROL_TIMEOUT_MS;
  transfer.data = out;
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
      } else {
        device->out_endpoint = config[offset + 2u];
      }
    }
    offset = (uint16_t)(offset + descriptor_len);
  }
  return 1;
}

static int erpiusb_open_path(const char* path, ErPiUsbDevice* device) {
  unsigned char dev_desc[ERPIUSB_DEVICE_DESCRIPTOR_BYTES];
  unsigned char cfg_head[ERPIUSB_CONFIG_HEAD_BYTES];
  unsigned char* cfg;
  uint16_t product;
  uint16_t cfg_len;
  int fd;
  int ret;

  memset(device, 0, sizeof(*device));
  device->fd = -1;
  fd = open(path, O_RDWR);
  if (fd < 0) {
    return 0;
  }
  ret = erpiusb_descriptor(fd, ERPIUSB_DESCRIPTOR_DEVICE, dev_desc, sizeof(dev_desc));
  if (ret != ERPIUSB_DEVICE_DESCRIPTOR_BYTES ||
      erpiusb_get_le16(dev_desc + 8u) != ERPIUSB_VENDOR_BROADCOM) {
    close(fd);
    return 0;
  }
  product = erpiusb_get_le16(dev_desc + 10u);
  if (erpiusb_second_stage_name(product) == NULL) {
    close(fd);
    return 0;
  }
  ret = erpiusb_descriptor(fd, ERPIUSB_DESCRIPTOR_CONFIG, cfg_head, sizeof(cfg_head));
  if (ret != ERPIUSB_CONFIG_HEAD_BYTES) {
    close(fd);
    return 0;
  }
  cfg_len = erpiusb_get_le16(cfg_head + 2u);
  cfg = (unsigned char*)malloc(cfg_len);
  if (cfg == NULL) {
    close(fd);
    return 0;
  }
  ret = erpiusb_descriptor(fd, ERPIUSB_DESCRIPTOR_CONFIG, cfg, cfg_len);
  if (ret != (int)cfg_len || erpiusb_parse_config(cfg, cfg_len, device) == 0) {
    free(cfg);
    close(fd);
    return 0;
  }
  free(cfg);
  if (ioctl(fd, USBDEVFS_CLAIMINTERFACE, &device->interface_number) < 0) {
    close(fd);
    return 0;
  }
  device->fd = fd;
  device->product_id = product;
  device->serial_index = dev_desc[16u];
  return 1;
}

static int erpiusb_open_any(const ErPiUsbConfig* cfg, ErPiUsbDevice* device) {
  char path[ERPIUSB_PATH_BYTES];
  unsigned int bus;
  unsigned int dev;
  int written;

  if (cfg->device_path != NULL) {
    return erpiusb_open_path(cfg->device_path, device);
  }
  for (bus = 1u; bus <= ERPIUSB_SCAN_MAX; ++bus) {
    for (dev = 1u; dev <= ERPIUSB_SCAN_MAX; ++dev) {
      written = snprintf(path, sizeof(path), "/dev/bus/usb/%03u/%03u", bus, dev);
      if (written < 0 || (size_t)written >= sizeof(path)) {
        return 0;
      }
      if (erpiusb_open_path(path, device) != 0) {
        return 1;
      }
    }
  }
  return 0;
}

static void erpiusb_close(ErPiUsbDevice* device) {
  if (device != NULL && device->fd >= 0) {
    (void)ioctl(device->fd, USBDEVFS_RELEASEINTERFACE, &device->interface_number);
    (void)close(device->fd);
    device->fd = -1;
  }
}

static int erpiusb_ep_write(ErPiUsbDevice* device,
                            const unsigned char* bytes,
                            uint32_t len) {
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
    if (chunk > ERPIUSB_MAX_BULK_BYTES) {
      chunk = ERPIUSB_MAX_BULK_BYTES;
    }
    ret = erpiusb_bulk(device->fd, device->out_endpoint, (void*)(bytes + offset), chunk);
    if (ret < 0 || (uint32_t)ret != chunk) {
      fprintf(stderr, "pi-usb-boot: bulk write failed: %d\n", ret);
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
  return (int)len;
}

static int erpiusb_send_second_stage(const ErPiUsbConfig* cfg,
                                     ErPiUsbDevice* device) {
  const char* name = erpiusb_second_stage_name(device->product_id);
  char path[ERPIUSB_PATH_BYTES];
  unsigned char header[ERPIUSB_BOOT_HEADER_BYTES];
  unsigned char* bytes = NULL;
  uint32_t len = 0u;
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
  ok = erpiusb_ep_write(device, header, sizeof(header)) != 0 &&
       erpiusb_ep_write(device, bytes, len) != 0;
  free(bytes);
  return ok;
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
    (void)erpiusb_ep_write(device, NULL, 0u);
    fprintf(stderr, "pi-usb-boot: missing requested file %s\n", name);
    return 0;
  }
  if (cfg->verbose != 0) {
    fprintf(stderr, "pi-usb-boot: serving %s (%u bytes)\n", name, size);
  }
  ok = erpiusb_ep_write(device, bytes, size);
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
      (void)erpiusb_ep_write(device, NULL, 0u);
      return 1;
    }
    switch (req.command) {
      case ERPIUSB_CMD_GET_FILE_SIZE:
        if (erpiusb_path_join(path, sizeof(path), cfg->boot_dir, req.name) == 0 ||
            erpiusb_file_size(path, &size) == 0 ||
            erpiusb_send_file_size(device, size) == 0) {
          (void)erpiusb_ep_write(device, NULL, 0u);
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
    if (erpiusb_open_any(cfg, device) != 0) {
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
  if (erpiusb_open_any(cfg, &device) == 0) {
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

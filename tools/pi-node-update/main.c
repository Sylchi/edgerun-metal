/*
 * Purpose: send Pi Zero W v1.1 open update objects over the EdgeRun L2 path.
 * Intention: keep host-side bring-up using the same erwire/VFS packet shape as
 * the bare-metal receiver, with no alternate update format.
 */

#define _DEFAULT_SOURCE

#include <errno.h>
#include <inttypes.h>
#include <arpa/inet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <netpacket/packet.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "er_crypto_blake3.h"
#include "er_mem.h"
#include "er_pi_zero_w_v1_1_ota.h"
#include "er_vfs.h"

#define ER_PI_NODE_UPDATE_ETH_TYPE 0x88b5u
#define ER_PI_NODE_UPDATE_MAX_OBJECT_BYTES \
  (ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY * ER_VFS_OBJECT_PACKET_BYTES)
#define ER_PI_NODE_UPDATE_ERWIRE_MAGIC 0x31575245u
#define ER_PI_NODE_UPDATE_ERWIRE_VERSION 1u
#define ER_PI_NODE_UPDATE_ERWIRE_HEADER_BYTES 32u
#define ER_PI_NODE_UPDATE_ERWIRE_KIND_VFS_OBJECT_PACKET 48u
#define ER_PI_NODE_UPDATE_ERWIRE_FLAG_FIRST 0x0001u
#define ER_PI_NODE_UPDATE_ERWIRE_FLAG_LAST 0x0002u
#define ER_PI_NODE_UPDATE_ERWIRE_STREAM_ID 0x45525a57u
#define ER_PI_NODE_UPDATE_LIVE_SEND_SUPPORTED 0u
#define ER_PI_NODE_UPDATE_ERWIRE_PAYLOAD_BYTES_MAX \
  (ER_VFS_OBJECT_PACKET_HEADER_BYTES + ER_VFS_OBJECT_PACKET_BYTES)
#define ER_PI_NODE_UPDATE_ERWIRE_PACKET_BYTES_MAX \
  (ER_PI_NODE_UPDATE_ERWIRE_HEADER_BYTES + \
   ER_PI_NODE_UPDATE_ERWIRE_PAYLOAD_BYTES_MAX)
#define ER_PI_NODE_UPDATE_CRC32_INITIAL 0xffffffffu
#define ER_PI_NODE_UPDATE_CRC32_POLY 0xedb88320u
#define ER_PI_NODE_UPDATE_CRC32_BITS_PER_BYTE 8u
#define ER_PI_NODE_UPDATE_DEFAULT_REPEAT 1u
#define ER_PI_NODE_UPDATE_MIN_ARGC 2
#define ER_PI_NODE_UPDATE_MAX_REPEAT 32u
#define ER_PI_NODE_UPDATE_ETH_HEADER_BYTES 14u
#define ER_PI_NODE_UPDATE_ETH_DST_OFFSET 0u
#define ER_PI_NODE_UPDATE_ETH_SRC_OFFSET 6u
#define ER_PI_NODE_UPDATE_ETH_TYPE_OFFSET 12u
#define ER_PI_NODE_UPDATE_ETH_TYPE_HIGH_SHIFT 8u
#define ER_PI_NODE_UPDATE_BROADCAST_BYTE 0xffu
#define ER_PI_NODE_UPDATE_EXIT_USAGE 2
#define ER_PI_NODE_UPDATE_U16_HIGH_SHIFT 8u
#define ER_PI_NODE_UPDATE_U32_BYTE2_SHIFT 16u
#define ER_PI_NODE_UPDATE_U32_BYTE3_SHIFT 24u

typedef struct {
  const char* iface;
  const char* image_path;
  uint32_t repeat;
  uint8_t dry_run;
} ErPiNodeUpdateConfig;

static void er_pi_node_update_usage(const char* argv0) {
  fprintf(stderr,
          "usage: %s --iface <iface> --image <kernel.img> [--repeat N] [--dry-run]\n",
          argv0 == 0 ? "pi-node-update" : argv0);
}

static int er_pi_node_update_parse_u32(const char* text, uint32_t* out_value) {
  char* end = 0;
  unsigned long value;

  if (text == 0 || out_value == 0 || text[0] == '\0') {
    return 0;
  }
  errno = 0;
  value = strtoul(text, &end, 10);
  if (errno != 0 || end == text || end == 0 || *end != '\0' ||
      value == 0ul || value > ER_PI_NODE_UPDATE_MAX_REPEAT) {
    return 0;
  }
  *out_value = (uint32_t)value;
  return 1;
}

static int er_pi_node_update_parse_args(int argc,
                                        char** argv,
                                        ErPiNodeUpdateConfig* out_config) {
  int i;

  if (out_config == 0) {
    return 0;
  }
  out_config->iface = 0;
  out_config->image_path = 0;
  out_config->repeat = ER_PI_NODE_UPDATE_DEFAULT_REPEAT;
  out_config->dry_run = 0u;
  if (argc < ER_PI_NODE_UPDATE_MIN_ARGC) {
    return 0;
  }
  for (i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--iface") == 0 && i + 1 < argc) {
      ++i;
      out_config->iface = argv[i];
    } else if (strcmp(argv[i], "--image") == 0 && i + 1 < argc) {
      ++i;
      out_config->image_path = argv[i];
    } else if (strcmp(argv[i], "--repeat") == 0 && i + 1 < argc) {
      ++i;
      if (er_pi_node_update_parse_u32(argv[i], &out_config->repeat) == 0) {
        return 0;
      }
    } else if (strcmp(argv[i], "--dry-run") == 0) {
      out_config->dry_run = 1u;
    } else {
      return 0;
    }
  }
  if (out_config->image_path == 0 ||
      (out_config->dry_run == 0u && out_config->iface == 0)) {
    return 0;
  }
  return 1;
}

static int er_pi_node_update_read_file(const char* path,
                                       uint8_t** out_bytes,
                                       size_t* out_len) {
  FILE* file;
  struct stat st;
  uint8_t* bytes;
  size_t len;

  if (path == 0 || out_bytes == 0 || out_len == 0) {
    return 0;
  }
  *out_bytes = 0;
  *out_len = 0u;
  if (stat(path, &st) != 0 || st.st_size <= 0) {
    fprintf(stderr, "pi-node-update: invalid image: %s\n", path);
    return 0;
  }
  if ((uint64_t)st.st_size > ER_PI_NODE_UPDATE_MAX_OBJECT_BYTES) {
    fprintf(stderr,
            "pi-node-update: image too large: %" PRIu64 " > %u\n",
            (uint64_t)st.st_size,
            ER_PI_NODE_UPDATE_MAX_OBJECT_BYTES);
    return 0;
  }
  len = (size_t)st.st_size;
  bytes = (uint8_t*)malloc(len);
  if (bytes == 0) {
    fprintf(stderr, "pi-node-update: image allocation failed\n");
    return 0;
  }
  file = fopen(path, "rb");
  if (file == 0) {
    fprintf(stderr, "pi-node-update: open failed: %s\n", path);
    free(bytes);
    return 0;
  }
  if (fread(bytes, 1u, len, file) != len) {
    fprintf(stderr, "pi-node-update: read failed: %s\n", path);
    fclose(file);
    free(bytes);
    return 0;
  }
  fclose(file);
  *out_bytes = bytes;
  *out_len = len;
  return 1;
}

static void er_pi_node_update_put_eth_type(uint8_t* frame) {
  frame[ER_PI_NODE_UPDATE_ETH_TYPE_OFFSET] =
      (uint8_t)((ER_PI_NODE_UPDATE_ETH_TYPE >>
                 ER_PI_NODE_UPDATE_ETH_TYPE_HIGH_SHIFT) & 0xffu);
  frame[ER_PI_NODE_UPDATE_ETH_TYPE_OFFSET + 1u] =
      (uint8_t)(ER_PI_NODE_UPDATE_ETH_TYPE & 0xffu);
}

static int er_pi_node_update_open_l2(const char* iface,
                                     int* out_fd,
                                     struct sockaddr_ll* out_addr,
                                     uint8_t src_mac[ETH_ALEN]) {
  int fd;
  struct ifreq ifr;

  if (iface == 0 || out_fd == 0 || out_addr == 0 || src_mac == 0) {
    return 0;
  }
  fd = socket(AF_PACKET, SOCK_RAW, htons(ER_PI_NODE_UPDATE_ETH_TYPE));
  if (fd < 0) {
    perror("pi-node-update: socket");
    return 0;
  }
  memset(&ifr, 0, sizeof(ifr));
  if (strlen(iface) >= sizeof(ifr.ifr_name)) {
    fprintf(stderr, "pi-node-update: interface name too long\n");
    close(fd);
    return 0;
  }
  memcpy(ifr.ifr_name, iface, strlen(iface) + 1u);
  if (ioctl(fd, SIOCGIFINDEX, &ifr) != 0) {
    perror("pi-node-update: SIOCGIFINDEX");
    close(fd);
    return 0;
  }
  memset(out_addr, 0, sizeof(*out_addr));
  out_addr->sll_family = AF_PACKET;
  out_addr->sll_ifindex = ifr.ifr_ifindex;
  out_addr->sll_halen = ETH_ALEN;
  memset(out_addr->sll_addr, ER_PI_NODE_UPDATE_BROADCAST_BYTE, ETH_ALEN);
  memset(&ifr, 0, sizeof(ifr));
  memcpy(ifr.ifr_name, iface, strlen(iface) + 1u);
  if (ioctl(fd, SIOCGIFHWADDR, &ifr) != 0) {
    perror("pi-node-update: SIOCGIFHWADDR");
    close(fd);
    return 0;
  }
  memcpy(src_mac, ifr.ifr_hwaddr.sa_data, ETH_ALEN);
  *out_fd = fd;
  return 1;
}

static uint32_t er_pi_node_update_crc32(const uint8_t* bytes, uint32_t len) {
  uint32_t crc = ER_PI_NODE_UPDATE_CRC32_INITIAL;
  uint32_t i;

  if (bytes == 0 && len != 0u) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    uint32_t bit;

    crc ^= (uint32_t)bytes[i];
    for (bit = 0u; bit < ER_PI_NODE_UPDATE_CRC32_BITS_PER_BYTE; ++bit) {
      uint32_t mask = 0u - (crc & 1u);

      crc = (crc >> 1u) ^ (ER_PI_NODE_UPDATE_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static void er_pi_node_update_put_u16(uint8_t** cursor, uint16_t value) {
  (*cursor)[0] = (uint8_t)(value & 0xffu);
  (*cursor)[1] = (uint8_t)((value >> ER_PI_NODE_UPDATE_U16_HIGH_SHIFT) &
                           0xffu);
  *cursor += 2u;
}

static void er_pi_node_update_put_u32(uint8_t** cursor, uint32_t value) {
  (*cursor)[0] = (uint8_t)(value & 0xffu);
  (*cursor)[1] = (uint8_t)((value >> ER_PI_NODE_UPDATE_U16_HIGH_SHIFT) &
                           0xffu);
  (*cursor)[2] = (uint8_t)((value >> ER_PI_NODE_UPDATE_U32_BYTE2_SHIFT) &
                           0xffu);
  (*cursor)[3] = (uint8_t)((value >> ER_PI_NODE_UPDATE_U32_BYTE3_SHIFT) &
                           0xffu);
  *cursor += 4u;
}

static int er_pi_node_update_build_erwire(uint32_t seq,
                                          const uint8_t* payload,
                                          uint32_t payload_len,
                                          uint8_t* out_packet,
                                          uint32_t* out_packet_len) {
  uint8_t* cursor = out_packet;

  if (payload == 0 || out_packet == 0 || out_packet_len == 0 ||
      payload_len > ER_PI_NODE_UPDATE_ERWIRE_PAYLOAD_BYTES_MAX) {
    return 0;
  }
  er_pi_node_update_put_u32(&cursor, ER_PI_NODE_UPDATE_ERWIRE_MAGIC);
  er_pi_node_update_put_u16(&cursor, ER_PI_NODE_UPDATE_ERWIRE_VERSION);
  er_pi_node_update_put_u16(&cursor, ER_PI_NODE_UPDATE_ERWIRE_HEADER_BYTES);
  er_pi_node_update_put_u32(&cursor, ER_PI_NODE_UPDATE_ERWIRE_STREAM_ID);
  er_pi_node_update_put_u32(&cursor, seq);
  er_pi_node_update_put_u16(&cursor,
                            ER_PI_NODE_UPDATE_ERWIRE_KIND_VFS_OBJECT_PACKET);
  er_pi_node_update_put_u16(&cursor,
                            ER_PI_NODE_UPDATE_ERWIRE_FLAG_FIRST |
                                ER_PI_NODE_UPDATE_ERWIRE_FLAG_LAST);
  er_pi_node_update_put_u32(&cursor, payload_len);
  er_pi_node_update_put_u32(&cursor,
                            er_pi_node_update_crc32(payload, payload_len));
  er_pi_node_update_put_u32(&cursor, 0u);
  memcpy(cursor, payload, payload_len);
  *out_packet_len = ER_PI_NODE_UPDATE_ERWIRE_HEADER_BYTES + payload_len;
  return 1;
}

static int er_pi_node_update_send_packet(int fd,
                                         const struct sockaddr_ll* addr,
                                         const uint8_t src_mac[ETH_ALEN],
                                         const uint8_t* erwire_packet,
                                         uint32_t erwire_packet_len) {
  uint8_t frame[ER_PI_NODE_UPDATE_ETH_HEADER_BYTES +
                ER_PI_NODE_UPDATE_ERWIRE_PACKET_BYTES_MAX];
  uint32_t frame_len;
  ssize_t sent;

  if (addr == 0 || src_mac == 0 || erwire_packet == 0 ||
      erwire_packet_len > ER_PI_NODE_UPDATE_ERWIRE_PACKET_BYTES_MAX) {
    return 0;
  }
  memset(frame + ER_PI_NODE_UPDATE_ETH_DST_OFFSET,
         ER_PI_NODE_UPDATE_BROADCAST_BYTE,
         ETH_ALEN);
  memcpy(frame + ER_PI_NODE_UPDATE_ETH_SRC_OFFSET, src_mac, ETH_ALEN);
  er_pi_node_update_put_eth_type(frame);
  memcpy(frame + ER_PI_NODE_UPDATE_ETH_HEADER_BYTES,
         erwire_packet,
         erwire_packet_len);
  frame_len = ER_PI_NODE_UPDATE_ETH_HEADER_BYTES + erwire_packet_len;
  sent = sendto(fd,
                frame,
                frame_len,
                0,
                (const struct sockaddr*)addr,
                (socklen_t)sizeof(*addr));
  if (sent != (ssize_t)frame_len) {
    perror("pi-node-update: sendto");
    return 0;
  }
  return 1;
}

static int er_pi_node_update_run(const ErPiNodeUpdateConfig* config) {
  ErCryptoProvider crypto;
  uint8_t* image = 0;
  size_t image_len = 0u;
  uint32_t packet_count;
  uint32_t packet_index;
  uint32_t repeat;
  int fd = -1;
  struct sockaddr_ll addr;
  uint8_t src_mac[ETH_ALEN];

  if (config == 0 ||
      er_pi_node_update_read_file(config->image_path, &image, &image_len) == 0) {
    return 1;
  }
  if (config->dry_run == 0u &&
      ER_PI_NODE_UPDATE_LIVE_SEND_SUPPORTED == 0u) {
    fprintf(stderr,
            "pi-node-update: live send unsupported: host Ethernet frames do not reach the Pi Zero W v1.1 CYW shared-RAM OTA receiver\n");
    free(image);
    return 1;
  }
  packet_count = (uint32_t)((image_len + ER_VFS_OBJECT_PACKET_BYTES - 1u) /
                            ER_VFS_OBJECT_PACKET_BYTES);
  if (packet_count == 0u ||
      packet_count > ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY) {
    fprintf(stderr, "pi-node-update: unsupported packet count: %u\n",
            packet_count);
    free(image);
    return 1;
  }
  if (config->dry_run == 0u &&
      er_pi_node_update_open_l2(config->iface, &fd, &addr, src_mac) == 0) {
    free(image);
    return 1;
  }
  er_crypto_blake3_provider(&crypto);
  for (repeat = 0u; repeat < config->repeat; ++repeat) {
    for (packet_index = 0u; packet_index < packet_count; ++packet_index) {
      ErVfsObjectPacket object_packet;
      uint8_t payload[ER_PI_NODE_UPDATE_ERWIRE_PAYLOAD_BYTES_MAX];
      uint8_t erwire_packet[ER_PI_NODE_UPDATE_ERWIRE_PACKET_BYTES_MAX];
      uint32_t payload_len;
      uint32_t erwire_packet_len;
      uint32_t seq = (repeat * packet_count) + packet_index;
      UINTN offset = (UINTN)packet_index * (UINTN)ER_VFS_OBJECT_PACKET_BYTES;

      if (er_vfs_prepare_object_packet(&crypto,
                                       image,
                                       (UINTN)image_len,
                                       offset,
                                       packet_index,
                                       packet_count,
                                       &object_packet) == 0u ||
          er_pi_zero_w_v1_1_ota_encode_object_packet_payload(
              &object_packet,
              payload,
              (uint32_t)sizeof(payload),
              &payload_len) == 0 ||
          er_pi_node_update_build_erwire(seq,
                                         payload,
                                         payload_len,
                                         erwire_packet,
                                         &erwire_packet_len) == 0) {
        fprintf(stderr, "pi-node-update: packet build failed: %u\n",
                packet_index);
        if (fd >= 0) {
          close(fd);
        }
        free(image);
        return 1;
      }
      if (config->dry_run == 0u &&
          er_pi_node_update_send_packet(fd,
                                        &addr,
                                        src_mac,
                                        erwire_packet,
                                        erwire_packet_len) == 0) {
        close(fd);
        free(image);
        return 1;
      }
    }
  }
  if (fd >= 0) {
    close(fd);
  }
  printf("pi-node-update: image=%s bytes=%zu packets=%u repeat=%u mode=%s\n",
         config->image_path,
         image_len,
         packet_count,
         config->repeat,
         config->dry_run == 0u ? "l2" : "dry-run");
  free(image);
  return 0;
}

int main(int argc, char** argv) {
  ErPiNodeUpdateConfig config;

  if (er_pi_node_update_parse_args(argc, argv, &config) == 0) {
    er_pi_node_update_usage(argv == 0 ? 0 : argv[0]);
    return ER_PI_NODE_UPDATE_EXIT_USAGE;
  }
  return er_pi_node_update_run(&config);
}

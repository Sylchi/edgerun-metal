#define _POSIX_C_SOURCE 200809L

/*
 * Purpose: inspect host PCI Wi-Fi cards for same-PC burst-link testing.
 * Intention: prove the physical adapters are visible before firmware Wi-Fi bring-up work starts.
 */

#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "er_iwlwifi.h"
#include "er_mt7922.h"
#include "er_rtw89.h"

enum {
  ER_WIFI_HW_MAX_CARDS = 16,
  ER_WIFI_HW_PATH_BYTES = 512,
  ER_WIFI_HW_NAME_BYTES = 64,
  ER_WIFI_HW_HEX_BASE = 16,
  ER_WIFI_HW_VENDOR_MEDIATEK = ER_MT7922_PCI_VENDOR_MEDIATEK,
  ER_WIFI_HW_VENDOR_REALTEK = ER_RTW89_PCI_VENDOR_REALTEK,
  ER_WIFI_HW_VENDOR_INTEL = ER_IWLWIFI_PCI_VENDOR_INTEL,
  ER_WIFI_HW_VENDOR_QUALCOMM_ATHEROS = 0x168cu,
  ER_WIFI_HW_DEVICE_INTEL_AX210 = ER_IWLWIFI_PCI_DEVICE_AX210,
  ER_WIFI_HW_DEVICE_QCA6174 = 0x003eu,
  ER_WIFI_HW_DEVICE_MEDIATEK_MT7603 = 0x7603u,
  ER_WIFI_HW_DEVICE_MEDIATEK_MT7663 = 0x7663u,
  ER_WIFI_HW_UNSUPPORTED_MEDIATEK_DEVICE = 0x7961u,
  ER_WIFI_HW_QCA6174_PCI_ID = 0x003e168cu,
  ER_WIFI_HW_MT7922_PCI_ID = 0x061614c3u,
  ER_WIFI_HW_MT7603_PCI_ID = 0x760314c3u,
  ER_WIFI_HW_MT7663_PCI_ID = 0x766314c3u,
  ER_WIFI_HW_AX210_PCI_ID = 0x27258086u,
  ER_WIFI_HW_CLASS_NETWORK = 0x02u,
  ER_WIFI_HW_SUBCLASS_OTHER_NETWORK = 0x80u,
  ER_WIFI_HW_PCI_DEVICE_SHIFT = 16u,
  ER_WIFI_HW_PCI_CLASS_SHIFT = 16u,
  ER_WIFI_HW_PCI_SUBCLASS_SHIFT = 8u,
  ER_WIFI_HW_READY_CARDS = 2u,
  ER_WIFI_HW_ARGC_NO_ARGS = 1,
  ER_WIFI_HW_ARGC_SELF_TEST = 2,
  ER_WIFI_HW_ARGC_SYSFS = 3,
  ER_WIFI_HW_ARG_PROGRAM = 0,
  ER_WIFI_HW_ARG_COMMAND = 1,
  ER_WIFI_HW_ARG_SYSFS_ROOT = 2,
  ER_WIFI_HW_EXIT_NOT_READY = 2
};

typedef enum {
  ER_WIFI_HW_KIND_UNSUPPORTED = 0,
  ER_WIFI_HW_KIND_MT7922_RZ616 = 1,
  ER_WIFI_HW_KIND_RTW89 = 2,
  ER_WIFI_HW_KIND_INTEL_AX210 = 3,
  ER_WIFI_HW_KIND_MT7603 = 4,
  ER_WIFI_HW_KIND_MT7663 = 5,
  ER_WIFI_HW_KIND_QCA6174 = 6
} ErWifiHardwareKind;

typedef struct {
  char pci_name[ER_WIFI_HW_NAME_BYTES];
  char sysfs_path[ER_WIFI_HW_PATH_BYTES];
  char driver[ER_WIFI_HW_NAME_BYTES];
  char net_iface[ER_WIFI_HW_NAME_BYTES];
  uint16_t vendor_id;
  uint16_t device_id;
  uint8_t pci_class;
  uint8_t pci_subclass;
  ErWifiHardwareKind kind;
  uint8_t driver_bound;
  uint8_t net_ready;
} ErWifiHardwareCard;

typedef struct {
  ErWifiHardwareCard cards[ER_WIFI_HW_MAX_CARDS];
  size_t count;
} ErWifiHardwareInventory;

static void er_wifi_hw_zero(void* ptr, size_t bytes) {
  if (ptr != NULL) {
    memset(ptr, 0, bytes);
  }
}

static int er_wifi_hw_copy(char* dst, size_t dst_size, const char* src) {
  int written;

  if (dst == NULL || dst_size == 0u || src == NULL) {
    return 0;
  }
  written = snprintf(dst, dst_size, "%s", src);
  return (written >= 0 && (size_t)written < dst_size) ? 1 : 0;
}

static int er_wifi_hw_join(char* dst, size_t dst_size, const char* a, const char* b) {
  int written;

  if (dst == NULL || dst_size == 0u || a == NULL || b == NULL) {
    return 0;
  }
  written = snprintf(dst, dst_size, "%s/%s", a, b);
  return (written >= 0 && (size_t)written < dst_size) ? 1 : 0;
}

static int er_wifi_hw_read_line(const char* path, char* out, size_t out_size) {
  FILE* file;
  size_t len;

  if (path == NULL || out == NULL || out_size == 0u) {
    return 0;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }
  if (fgets(out, (int)out_size, file) == NULL) {
    (void)fclose(file);
    return 0;
  }
  if (fclose(file) != 0) {
    return 0;
  }
  len = strlen(out);
  while (len > 0u && (out[len - 1u] == '\n' || out[len - 1u] == '\r')) {
    out[len - 1u] = '\0';
    --len;
  }
  return 1;
}

static int er_wifi_hw_parse_hex_u32(const char* text, uint32_t* out_value) {
  char* end = NULL;
  unsigned long value;

  if (text == NULL || out_value == NULL || *text == '\0') {
    return 0;
  }
  errno = 0;
  value = strtoul(text, &end, ER_WIFI_HW_HEX_BASE);
  if (errno != 0 || end == text || end == NULL || *end != '\0' || value > UINT32_MAX) {
    return 0;
  }
  *out_value = (uint32_t)value;
  return 1;
}

static int er_wifi_hw_read_hex_u32(const char* dir, const char* file_name, uint32_t* out_value) {
  char path[ER_WIFI_HW_PATH_BYTES];
  char text[ER_WIFI_HW_NAME_BYTES];

  if (er_wifi_hw_join(path, sizeof(path), dir, file_name) == 0 ||
      er_wifi_hw_read_line(path, text, sizeof(text)) == 0) {
    return 0;
  }
  return er_wifi_hw_parse_hex_u32(text, out_value);
}

static uint32_t er_wifi_hw_make_pci_id(uint16_t vendor_id, uint16_t device_id) {
  return (uint32_t)vendor_id | ((uint32_t)device_id << ER_WIFI_HW_PCI_DEVICE_SHIFT);
}

static ErWifiHardwareKind er_wifi_hw_kind(uint16_t vendor_id, uint16_t device_id) {
  if (vendor_id == ER_MT7922_PCI_VENDOR_MEDIATEK &&
      device_id == ER_MT7922_PCI_DEVICE_MT7922_RZ616) {
    return ER_WIFI_HW_KIND_MT7922_RZ616;
  }
  if (vendor_id == ER_MT7922_PCI_VENDOR_MEDIATEK &&
      device_id == ER_WIFI_HW_DEVICE_MEDIATEK_MT7603) {
    return ER_WIFI_HW_KIND_MT7603;
  }
  if (vendor_id == ER_MT7922_PCI_VENDOR_MEDIATEK &&
      device_id == ER_WIFI_HW_DEVICE_MEDIATEK_MT7663) {
    return ER_WIFI_HW_KIND_MT7663;
  }
  if (vendor_id == ER_RTW89_PCI_VENDOR_REALTEK) {
    switch (device_id) {
      case ER_RTW89_PCI_DEVICE_RTL8922AE:
      case ER_RTW89_PCI_DEVICE_RTL8922AE_VS:
        return ER_WIFI_HW_KIND_RTW89;
      default:
        break;
    }
  }
  if (vendor_id == ER_WIFI_HW_VENDOR_INTEL && device_id == ER_WIFI_HW_DEVICE_INTEL_AX210) {
    return ER_WIFI_HW_KIND_INTEL_AX210;
  }
  if (vendor_id == ER_WIFI_HW_VENDOR_QUALCOMM_ATHEROS &&
      device_id == ER_WIFI_HW_DEVICE_QCA6174) {
    return ER_WIFI_HW_KIND_QCA6174;
  }
  return ER_WIFI_HW_KIND_UNSUPPORTED;
}

static const char* er_wifi_hw_kind_label(ErWifiHardwareKind kind) {
  switch (kind) {
    case ER_WIFI_HW_KIND_MT7922_RZ616:
      return "mt7922-rz616";
    case ER_WIFI_HW_KIND_MT7603:
      return "mt7603";
    case ER_WIFI_HW_KIND_MT7663:
      return "mt7663";
    case ER_WIFI_HW_KIND_RTW89:
      return "rtw89";
    case ER_WIFI_HW_KIND_INTEL_AX210:
      return "intel-ax210";
    case ER_WIFI_HW_KIND_QCA6174:
      return "qca6174";
    case ER_WIFI_HW_KIND_UNSUPPORTED:
    default:
      return "unsupported";
  }
}

static int er_wifi_hw_find_driver(const char* dir, char* out, size_t out_size) {
  char path[ER_WIFI_HW_PATH_BYTES];
  char link_target[ER_WIFI_HW_PATH_BYTES];
  ssize_t len;
  const char* slash;

  if (out == NULL || out_size == 0u ||
      er_wifi_hw_join(path, sizeof(path), dir, "driver") == 0) {
    return 0;
  }
  len = readlink(path, link_target, sizeof(link_target) - 1u);
  if (len <= 0) {
    return 0;
  }
  link_target[len] = '\0';
  slash = strrchr(link_target, '/');
  if (slash == NULL || slash[1] == '\0') {
    return 0;
  }
  return er_wifi_hw_copy(out, out_size, slash + 1);
}

static int er_wifi_hw_find_net_iface(const char* dir, char* out, size_t out_size) {
  char path[ER_WIFI_HW_PATH_BYTES];
  DIR* net_dir;
  struct dirent* entry;
  int found = 0;

  if (out == NULL || out_size == 0u ||
      er_wifi_hw_join(path, sizeof(path), dir, "net") == 0) {
    return 0;
  }
  net_dir = opendir(path);
  if (net_dir == NULL) {
    return 0;
  }
  while ((entry = readdir(net_dir)) != NULL) {
    if (entry->d_name[0] == '.') {
      continue;
    }
    found = er_wifi_hw_copy(out, out_size, entry->d_name);
    break;
  }
  if (closedir(net_dir) != 0) {
    return 0;
  }
  return found;
}

static int er_wifi_hw_card_from_sysfs(const char* pci_name,
                                      const char* dir,
                                      ErWifiHardwareCard* out_card) {
  uint32_t vendor;
  uint32_t device;
  uint32_t class_value;

  if (pci_name == NULL || dir == NULL || out_card == NULL) {
    return 0;
  }
  er_wifi_hw_zero(out_card, sizeof(*out_card));
  if (er_wifi_hw_read_hex_u32(dir, "vendor", &vendor) == 0 ||
      er_wifi_hw_read_hex_u32(dir, "device", &device) == 0 ||
      er_wifi_hw_read_hex_u32(dir, "class", &class_value) == 0 ||
      vendor > UINT16_MAX ||
      device > UINT16_MAX) {
    return 0;
  }

  out_card->vendor_id = (uint16_t)vendor;
  out_card->device_id = (uint16_t)device;
  out_card->pci_class = (uint8_t)(class_value >> ER_WIFI_HW_PCI_CLASS_SHIFT);
  out_card->pci_subclass = (uint8_t)(class_value >> ER_WIFI_HW_PCI_SUBCLASS_SHIFT);
  out_card->kind = er_wifi_hw_kind(out_card->vendor_id, out_card->device_id);
  if (out_card->kind == ER_WIFI_HW_KIND_UNSUPPORTED ||
      out_card->pci_class != ER_WIFI_HW_CLASS_NETWORK ||
      out_card->pci_subclass != ER_WIFI_HW_SUBCLASS_OTHER_NETWORK) {
    return 0;
  }

  if (er_wifi_hw_copy(out_card->pci_name, sizeof(out_card->pci_name), pci_name) == 0 ||
      er_wifi_hw_copy(out_card->sysfs_path, sizeof(out_card->sysfs_path), dir) == 0) {
    return 0;
  }
  out_card->driver_bound =
      (uint8_t)er_wifi_hw_find_driver(dir, out_card->driver, sizeof(out_card->driver));
  out_card->net_ready =
      (uint8_t)er_wifi_hw_find_net_iface(dir, out_card->net_iface, sizeof(out_card->net_iface));
  return 1;
}

static int er_wifi_hw_scan_sysfs(const char* sysfs_root, ErWifiHardwareInventory* out_inventory) {
  DIR* root;
  struct dirent* entry;

  if (sysfs_root == NULL || out_inventory == NULL) {
    return 0;
  }
  er_wifi_hw_zero(out_inventory, sizeof(*out_inventory));
  root = opendir(sysfs_root);
  if (root == NULL) {
    return 0;
  }
  while ((entry = readdir(root)) != NULL) {
    char path[ER_WIFI_HW_PATH_BYTES];
    ErWifiHardwareCard card;

    if (entry->d_name[0] == '.') {
      continue;
    }
    if (er_wifi_hw_join(path, sizeof(path), sysfs_root, entry->d_name) == 0) {
      (void)closedir(root);
      return 0;
    }
    if (er_wifi_hw_card_from_sysfs(entry->d_name, path, &card) != 0) {
      if (out_inventory->count >= ER_WIFI_HW_MAX_CARDS) {
        (void)closedir(root);
        return 0;
      }
      out_inventory->cards[out_inventory->count] = card;
      ++out_inventory->count;
    }
  }
  return closedir(root) == 0 ? 1 : 0;
}

static size_t er_wifi_hw_ready_count(const ErWifiHardwareInventory* inventory) {
  size_t i;
  size_t count = 0u;

  if (inventory == NULL) {
    return 0u;
  }
  for (i = 0u; i < inventory->count; ++i) {
    if (inventory->cards[i].driver_bound != 0u && inventory->cards[i].net_ready != 0u) {
      ++count;
    }
  }
  return count;
}

static void er_wifi_hw_print_inventory(const ErWifiHardwareInventory* inventory) {
  size_t i;
  size_t ready;

  if (inventory == NULL) {
    return;
  }
  printf("supported_wifi_cards=%zu\n", inventory->count);
  for (i = 0u; i < inventory->count; ++i) {
    const ErWifiHardwareCard* card = &inventory->cards[i];
    printf("card%zu.pci=%s\n", i, card->pci_name);
    printf("card%zu.kind=%s\n", i, er_wifi_hw_kind_label(card->kind));
    printf("card%zu.id=%04x:%04x\n", i, card->vendor_id, card->device_id);
    printf("card%zu.driver=%s\n", i, card->driver_bound != 0u ? card->driver : "none");
    printf("card%zu.net=%s\n", i, card->net_ready != 0u ? card->net_iface : "none");
  }
  ready = er_wifi_hw_ready_count(inventory);
  printf("ready_wifi_cards=%zu\n", ready);
  if (ready >= ER_WIFI_HW_READY_CARDS) {
    printf("same_host_burst_test=ready\n");
  } else {
    printf("same_host_burst_test=not-ready\n");
  }
}

static int er_wifi_hw_self_test(void) {
  ErWifiHardwareCard card;

  if (er_wifi_hw_make_pci_id(ER_WIFI_HW_VENDOR_MEDIATEK,
                             ER_MT7922_PCI_DEVICE_MT7922_RZ616) != ER_WIFI_HW_MT7922_PCI_ID) {
    return 1;
  }
  if (er_wifi_hw_make_pci_id(ER_WIFI_HW_VENDOR_MEDIATEK,
                             ER_WIFI_HW_DEVICE_MEDIATEK_MT7603) != ER_WIFI_HW_MT7603_PCI_ID) {
    return 1;
  }
  if (er_wifi_hw_make_pci_id(ER_WIFI_HW_VENDOR_MEDIATEK,
                             ER_WIFI_HW_DEVICE_MEDIATEK_MT7663) != ER_WIFI_HW_MT7663_PCI_ID) {
    return 1;
  }
  if (er_wifi_hw_make_pci_id(ER_WIFI_HW_VENDOR_INTEL,
                             ER_WIFI_HW_DEVICE_INTEL_AX210) != ER_WIFI_HW_AX210_PCI_ID) {
    return 1;
  }
  if (er_wifi_hw_make_pci_id(ER_WIFI_HW_VENDOR_QUALCOMM_ATHEROS,
                             ER_WIFI_HW_DEVICE_QCA6174) != ER_WIFI_HW_QCA6174_PCI_ID) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_MEDIATEK, ER_MT7922_PCI_DEVICE_MT7922_RZ616) !=
      ER_WIFI_HW_KIND_MT7922_RZ616) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_MEDIATEK, ER_WIFI_HW_DEVICE_MEDIATEK_MT7603) !=
      ER_WIFI_HW_KIND_MT7603) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_MEDIATEK, ER_WIFI_HW_DEVICE_MEDIATEK_MT7663) !=
      ER_WIFI_HW_KIND_MT7663) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_REALTEK, ER_RTW89_PCI_DEVICE_RTL8922AE) !=
      ER_WIFI_HW_KIND_RTW89) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_REALTEK, ER_RTW89_PCI_DEVICE_RTL8922AE_VS) !=
      ER_WIFI_HW_KIND_RTW89) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_INTEL, ER_WIFI_HW_DEVICE_INTEL_AX210) !=
      ER_WIFI_HW_KIND_INTEL_AX210) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_QUALCOMM_ATHEROS, ER_WIFI_HW_DEVICE_QCA6174) !=
      ER_WIFI_HW_KIND_QCA6174) {
    return 1;
  }
  if (er_wifi_hw_kind(ER_WIFI_HW_VENDOR_MEDIATEK, ER_WIFI_HW_UNSUPPORTED_MEDIATEK_DEVICE) !=
      ER_WIFI_HW_KIND_UNSUPPORTED) {
    return 1;
  }
  er_wifi_hw_zero(&card, sizeof(card));
  if (card.kind != ER_WIFI_HW_KIND_UNSUPPORTED ||
      card.driver_bound != 0u ||
      card.net_ready != 0u) {
    return 1;
  }
  return 0;
}

int main(int argc, char** argv) {
  const char* sysfs_root = "/sys/bus/pci/devices";
  ErWifiHardwareInventory inventory;

  if (argc == ER_WIFI_HW_ARGC_SELF_TEST && strcmp(argv[ER_WIFI_HW_ARG_COMMAND], "--self-test") == 0) {
    return er_wifi_hw_self_test();
  }
  if (argc == ER_WIFI_HW_ARGC_SYSFS && strcmp(argv[ER_WIFI_HW_ARG_COMMAND], "--sysfs") == 0) {
    sysfs_root = argv[ER_WIFI_HW_ARG_SYSFS_ROOT];
  } else if (argc != ER_WIFI_HW_ARGC_NO_ARGS) {
    fprintf(stderr, "usage: %s [--sysfs /sys/bus/pci/devices] [--self-test]\n",
            argv[ER_WIFI_HW_ARG_PROGRAM]);
    return 1;
  }

  if (er_wifi_hw_scan_sysfs(sysfs_root, &inventory) == 0) {
    fprintf(stderr, "wifi hardware probe failed: %s\n", sysfs_root);
    return 1;
  }
  er_wifi_hw_print_inventory(&inventory);
  return er_wifi_hw_ready_count(&inventory) >= ER_WIFI_HW_READY_CARDS ? 0 : ER_WIFI_HW_EXIT_NOT_READY;
}

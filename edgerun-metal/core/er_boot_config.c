#include "er_boot_config.h"
#include "er_mem.h"

static const char g_er_boot_config_wifi_fixed_ssid[ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN] = {
  'e', 'd', 'g', 'e', 'r', 'u', 'n'
};

static const char g_er_boot_config_firmware_path_prefix[] = {
  '/', 'E', 'F', 'I', '/', 'f', 'i', 'r', 'm', 'w', 'a', 'r', 'e', '/'
};

#define ER_BOOT_CONFIG_FIRMWARE_PATH_PREFIX_LEN 14u
#define ER_BOOT_CONFIG_FIRMWARE_HEX_DIGITS 4u
#define ER_BOOT_CONFIG_FIRMWARE_VENDOR_OFFSET ER_BOOT_CONFIG_FIRMWARE_PATH_PREFIX_LEN
#define ER_BOOT_CONFIG_FIRMWARE_SEPARATOR0_OFFSET 18u
#define ER_BOOT_CONFIG_FIRMWARE_DEVICE_OFFSET 19u
#define ER_BOOT_CONFIG_FIRMWARE_SEPARATOR1_OFFSET 23u
#define ER_BOOT_CONFIG_FIRMWARE_INSTANCE_OFFSET 24u
#define ER_BOOT_CONFIG_FIRMWARE_INSTANCE_ZERO 0u
#define ER_BOOT_CONFIG_FIRMWARE_INSTANCE_ZERO_CHAR '0'
#define ER_BOOT_CONFIG_HEX_NIBBLE_MASK 0x0fu
#define ER_BOOT_CONFIG_HEX_NIBBLE_BITS 4u

static UINT8 er_boot_config_channel_kind_valid(UINT8 channel_kind) {
  switch (channel_kind) {
    case ER_CHANNEL_KIND_NATIVE_ETH:
    case ER_CHANNEL_KIND_TCP_IP:
    case ER_CHANNEL_KIND_WIFI_OPEN_L2:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_boot_config_wifi_role_valid(UINT8 wifi_role) {
  switch (wifi_role) {
    case ER_BOOT_CONFIG_WIFI_ROLE_AUTO:
    case ER_BOOT_CONFIG_WIFI_ROLE_AP:
    case ER_BOOT_CONFIG_WIFI_ROLE_STA:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_boot_config_label_valid(const char* label, UINT16 label_len) {
  UINT16 i;

  if (label == 0 || label_len == 0u || label_len > ER_BOOT_CONFIG_LABEL_MAX) {
    return 0u;
  }
  for (i = 0u; i < label_len; ++i) {
    if (label[i] == 0) {
      return 0u;
    }
  }
  return 1u;
}

static char er_boot_config_hex_char(UINT8 value) {
  static const char hex_chars[16] = {
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
  };

  return hex_chars[value & ER_BOOT_CONFIG_HEX_NIBBLE_MASK];
}

static void er_boot_config_write_hex16(char* out, UINT16 value) {
  UINT16 i;
  UINT8 shift;

  if (out == 0) {
    return;
  }

  for (i = 0u; i < ER_BOOT_CONFIG_FIRMWARE_HEX_DIGITS; ++i) {
    shift = (UINT8)((ER_BOOT_CONFIG_FIRMWARE_HEX_DIGITS - 1u - i) *
                    ER_BOOT_CONFIG_HEX_NIBBLE_BITS);
    out[i] = er_boot_config_hex_char((UINT8)(value >> shift));
  }
}

static void er_boot_config_write_firmware_path(ErBootFirmwareSourceConfig* source) {
  if (source == 0) {
    return;
  }

  er_mem_zero((UINT8*)source->path, (UINTN)sizeof(source->path));
  er_mem_copy((UINT8*)source->path,
              (const UINT8*)g_er_boot_config_firmware_path_prefix,
              ER_BOOT_CONFIG_FIRMWARE_PATH_PREFIX_LEN);
  er_boot_config_write_hex16(&source->path[ER_BOOT_CONFIG_FIRMWARE_VENDOR_OFFSET],
                             source->pci_vendor_id);
  source->path[ER_BOOT_CONFIG_FIRMWARE_SEPARATOR0_OFFSET] = '.';
  er_boot_config_write_hex16(&source->path[ER_BOOT_CONFIG_FIRMWARE_DEVICE_OFFSET],
                             source->pci_device_id);
  source->path[ER_BOOT_CONFIG_FIRMWARE_SEPARATOR1_OFFSET] = '.';
  source->path[ER_BOOT_CONFIG_FIRMWARE_INSTANCE_OFFSET] = ER_BOOT_CONFIG_FIRMWARE_INSTANCE_ZERO_CHAR;
  source->path_len = ER_BOOT_CONFIG_FIRMWARE_PATH_LEN;
}

static UINT8 er_boot_config_firmware_path_canonical(const ErBootFirmwareSourceConfig* source) {
  ErBootFirmwareSourceConfig expected;

  if (source == 0 || source->path_len != ER_BOOT_CONFIG_FIRMWARE_PATH_LEN) {
    return 0u;
  }

  er_mem_zero((UINT8*)&expected, (UINTN)sizeof(expected));
  expected.pci_vendor_id = source->pci_vendor_id;
  expected.pci_device_id = source->pci_device_id;
  er_boot_config_write_firmware_path(&expected);
  return er_mem_equal((const UINT8*)source->path,
                      (const UINT8*)expected.path,
                      ER_BOOT_CONFIG_FIRMWARE_PATH_LEN);
}

static UINT8 er_boot_config_firmware_source_valid(const ErBootFirmwareSourceConfig* source) {
  if (source == 0 ||
      source->enabled != ER_BOOT_CONFIG_CHANNEL_ENABLED ||
      source->source_kind != ER_BOOT_CONFIG_FIRMWARE_SOURCE_EFI_PARTITION ||
      source->instance != ER_BOOT_CONFIG_FIRMWARE_INSTANCE_ZERO ||
      source->reserved != 0u ||
      source->pci_vendor_id == 0u ||
      source->pci_device_id == 0u ||
      er_boot_config_firmware_path_canonical(source) == 0u) {
    return 0u;
  }

  return 1u;
}

static void er_boot_config_set_fixed_wifi_ssid(ErBootRelayChannelConfig* channel) {
  if (channel == 0) {
    return;
  }
  channel->ssid_len = ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN;
  er_mem_copy((UINT8*)channel->ssid, (const UINT8*)g_er_boot_config_wifi_fixed_ssid,
              ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN);
}

void er_boot_config_init(ErBootConfig* config) {
  if (config == 0) {
    return;
  }
  er_mem_zero((UINT8*)config, (UINTN)sizeof(*config));
  config->abi_version = ER_BOOT_CONFIG_ABI_VERSION;
}

UINT8 er_boot_config_set_admission_identity(ErBootConfig* config,
                                            const ErIdentity* admission_identity) {
  if (config == 0 || er_identity_valid(admission_identity) == 0u) {
    return 0u;
  }
  config->admission_identity = *admission_identity;
  return 1u;
}

UINT8 er_boot_config_add_channel(ErBootConfig* config, UINT8 channel_kind,
                                 const char* label, UINT16 label_len) {
  ErBootRelayChannelConfig* channel;

  if (config == 0 ||
      config->channel_count >= ER_BOOT_CONFIG_CHANNEL_CAPACITY ||
      er_boot_config_channel_kind_valid(channel_kind) == 0u ||
      er_boot_config_label_valid(label, label_len) == 0u) {
    return 0u;
  }

  channel = &config->channels[config->channel_count];
  er_mem_zero((UINT8*)channel, (UINTN)sizeof(*channel));
  channel->enabled = ER_BOOT_CONFIG_CHANNEL_ENABLED;
  channel->channel_kind = channel_kind;
  channel->label_len = label_len;
  er_mem_copy((UINT8*)channel->label, (const UINT8*)label, label_len);
  config->channel_count += 1u;
  return 1u;
}

UINT8 er_boot_config_add_open_wifi_channel(ErBootConfig* config,
                                           UINT8 wifi_role,
                                           const char* label,
                                           UINT16 label_len) {
  ErBootRelayChannelConfig* channel;

  if (config == 0 ||
      config->channel_count >= ER_BOOT_CONFIG_CHANNEL_CAPACITY ||
      er_boot_config_wifi_role_valid(wifi_role) == 0u ||
      er_boot_config_label_valid(label, label_len) == 0u) {
    return 0u;
  }

  channel = &config->channels[config->channel_count];
  er_mem_zero((UINT8*)channel, (UINTN)sizeof(*channel));
  channel->enabled = ER_BOOT_CONFIG_CHANNEL_ENABLED;
  channel->channel_kind = ER_CHANNEL_KIND_WIFI_OPEN_L2;
  channel->label_len = label_len;
  channel->wifi_role = wifi_role;
  channel->wifi_security = ER_BOOT_CONFIG_WIFI_SECURITY_OPEN;
  er_mem_copy((UINT8*)channel->label, (const UINT8*)label, label_len);
  er_boot_config_set_fixed_wifi_ssid(channel);
  config->channel_count += 1u;
  return 1u;
}

UINT8 er_boot_config_add_efi_firmware_source(ErBootConfig* config,
                                             UINT16 pci_vendor_id,
                                             UINT16 pci_device_id) {
  ErBootFirmwareSourceConfig* source;

  if (config == 0 ||
      config->firmware_source_count >= ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY ||
      pci_vendor_id == 0u ||
      pci_device_id == 0u) {
    return 0u;
  }

  source = &config->firmware_sources[config->firmware_source_count];
  er_mem_zero((UINT8*)source, (UINTN)sizeof(*source));
  source->enabled = ER_BOOT_CONFIG_CHANNEL_ENABLED;
  source->source_kind = ER_BOOT_CONFIG_FIRMWARE_SOURCE_EFI_PARTITION;
  source->instance = ER_BOOT_CONFIG_FIRMWARE_INSTANCE_ZERO;
  source->pci_vendor_id = pci_vendor_id;
  source->pci_device_id = pci_device_id;
  er_boot_config_write_firmware_path(source);
  config->firmware_source_count += 1u;
  return 1u;
}

const ErBootFirmwareSourceConfig* er_boot_config_find_efi_firmware_source(const ErBootConfig* config,
                                                                          UINT16 pci_vendor_id,
                                                                          UINT16 pci_device_id) {
  UINT16 i;
  const ErBootFirmwareSourceConfig* source;

  if (config == 0 ||
      pci_vendor_id == 0u ||
      pci_device_id == 0u ||
      config->firmware_source_count > ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY) {
    return 0;
  }

  for (i = 0u; i < config->firmware_source_count; ++i) {
    source = &config->firmware_sources[i];
    if (er_boot_config_firmware_source_valid(source) != 0u &&
        source->pci_vendor_id == pci_vendor_id &&
        source->pci_device_id == pci_device_id) {
      return source;
    }
  }

  return 0;
}

UINT8 er_boot_config_valid(const ErBootConfig* config) {
  UINT16 i;
  const ErBootRelayChannelConfig* channel;
  const ErBootFirmwareSourceConfig* firmware_source;

  if (config == 0 ||
      config->abi_version != ER_BOOT_CONFIG_ABI_VERSION ||
      config->generation == ER_BOOT_CONFIG_GENERATION_INVALID ||
      config->channel_count == 0u ||
      config->channel_count > ER_BOOT_CONFIG_CHANNEL_CAPACITY ||
      config->firmware_source_count > ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY ||
      er_identity_valid(&config->admission_identity) == 0u) {
    return 0u;
  }

  for (i = 0u; i < config->channel_count; ++i) {
    channel = &config->channels[i];
    if (channel->enabled != ER_BOOT_CONFIG_CHANNEL_ENABLED ||
        er_boot_config_channel_kind_valid(channel->channel_kind) == 0u ||
        er_boot_config_label_valid(channel->label, channel->label_len) == 0u) {
      return 0u;
    }
    switch (channel->channel_kind) {
      case ER_CHANNEL_KIND_WIFI_OPEN_L2:
        if (channel->wifi_security != ER_BOOT_CONFIG_WIFI_SECURITY_OPEN ||
            er_boot_config_wifi_role_valid(channel->wifi_role) == 0u ||
            channel->ssid_len != ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN ||
            er_mem_equal((const UINT8*)channel->ssid,
                         (const UINT8*)g_er_boot_config_wifi_fixed_ssid,
                         ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN) == 0u) {
          return 0u;
        }
        break;
      default:
        if (channel->wifi_role != ER_BOOT_CONFIG_WIFI_ROLE_NONE ||
            channel->wifi_security != 0u ||
            channel->ssid_len != 0u) {
          return 0u;
        }
        break;
    }
  }

  for (i = 0u; i < config->firmware_source_count; ++i) {
    firmware_source = &config->firmware_sources[i];
    if (er_boot_config_firmware_source_valid(firmware_source) == 0u) {
      return 0u;
    }
  }

  return 1u;
}

const char* er_boot_config_wifi_fixed_ssid(void) {
  return g_er_boot_config_wifi_fixed_ssid;
}

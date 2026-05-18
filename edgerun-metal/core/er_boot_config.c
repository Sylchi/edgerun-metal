#include "er_boot_config.h"
#include "er_mem.h"

static const char g_er_boot_config_wifi_fixed_ssid[ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN] = {
  'e', 'd', 'g', 'e', 'r', 'u', 'n'
};

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

static UINT8 er_boot_config_firmware_path_char_valid(char c) {
  if (c >= 'a' && c <= 'z') {
    return 1u;
  }
  if (c >= 'A' && c <= 'Z') {
    return 1u;
  }
  if (c >= '0' && c <= '9') {
    return 1u;
  }

  switch (c) {
    case '/':
    case '-':
    case '_':
    case '.':
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_boot_config_firmware_path_valid(const char* path, UINT16 path_len) {
  UINT16 i;

  if (path == 0 || path_len == 0u || path_len > ER_BOOT_CONFIG_FIRMWARE_PATH_MAX) {
    return 0u;
  }
  if (path[0] == '/' || path[path_len - 1u] == '/') {
    return 0u;
  }
  for (i = 0u; i < path_len; ++i) {
    if (path[i] == 0 || er_boot_config_firmware_path_char_valid(path[i]) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_boot_config_firmware_source_valid(const ErBootFirmwareSourceConfig* source) {
  if (source == 0 ||
      source->enabled != ER_BOOT_CONFIG_CHANNEL_ENABLED ||
      source->source_kind != ER_BOOT_CONFIG_FIRMWARE_SOURCE_EFI_PARTITION ||
      source->pci_vendor_id == 0u ||
      source->pci_device_id == 0u ||
      er_boot_config_firmware_path_valid(source->path, source->path_len) == 0u) {
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
                                             UINT16 pci_device_id,
                                             const char* path,
                                             UINT16 path_len) {
  ErBootFirmwareSourceConfig* source;

  if (config == 0 ||
      config->firmware_source_count >= ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY ||
      pci_vendor_id == 0u ||
      pci_device_id == 0u ||
      er_boot_config_firmware_path_valid(path, path_len) == 0u) {
    return 0u;
  }

  source = &config->firmware_sources[config->firmware_source_count];
  er_mem_zero((UINT8*)source, (UINTN)sizeof(*source));
  source->enabled = ER_BOOT_CONFIG_CHANNEL_ENABLED;
  source->source_kind = ER_BOOT_CONFIG_FIRMWARE_SOURCE_EFI_PARTITION;
  source->pci_vendor_id = pci_vendor_id;
  source->pci_device_id = pci_device_id;
  source->path_len = path_len;
  er_mem_copy((UINT8*)source->path, (const UINT8*)path, path_len);
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

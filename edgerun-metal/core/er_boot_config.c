#include "er_boot_config.h"
#include "er_mem.h"

static UINT8 er_boot_config_channel_kind_valid(UINT8 channel_kind) {
  switch (channel_kind) {
    case ER_CHANNEL_KIND_NATIVE_ETH:
    case ER_CHANNEL_KIND_TCP_IP:
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

UINT8 er_boot_config_valid(const ErBootConfig* config) {
  UINT16 i;
  const ErBootRelayChannelConfig* channel;

  if (config == 0 ||
      config->abi_version != ER_BOOT_CONFIG_ABI_VERSION ||
      config->generation == ER_BOOT_CONFIG_GENERATION_INVALID ||
      config->channel_count == 0u ||
      config->channel_count > ER_BOOT_CONFIG_CHANNEL_CAPACITY ||
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
  }
  return 1u;
}

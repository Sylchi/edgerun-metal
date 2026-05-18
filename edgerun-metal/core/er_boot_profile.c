#include "er_boot_profile.h"

const char* er_boot_profile_label(UINT32 profile) {
  switch (profile) {
    case ER_BOOT_PROFILE_UI:
      return "ui";
    case ER_BOOT_PROFILE_NATIVE:
      return "native";
    case ER_BOOT_PROFILE_TPM:
      return "tpm";
    case ER_BOOT_PROFILE_GPU:
      return "gpu";
    default:
      return "invalid";
  }
}

UINT8 er_boot_profile_valid(UINT32 profile) {
  switch (profile) {
    case ER_BOOT_PROFILE_UI:
    case ER_BOOT_PROFILE_NATIVE:
    case ER_BOOT_PROFILE_TPM:
    case ER_BOOT_PROFILE_GPU:
      return 1u;
    default:
      return 0u;
  }
}

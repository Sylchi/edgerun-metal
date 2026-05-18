#include "er_boot_profile.h"

const char* er_boot_profile_label(UINT32 profile) {
  switch (profile) {
    case ER_BOOT_PROFILE_OS:
      return "os";
    default:
      return "invalid";
  }
}

UINT8 er_boot_profile_valid(UINT32 profile) {
  switch (profile) {
    case ER_BOOT_PROFILE_OS:
      return 1u;
    default:
      return 0u;
  }
}

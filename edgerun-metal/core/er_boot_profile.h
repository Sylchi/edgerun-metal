#ifndef ER_BOOT_PROFILE_H
#define ER_BOOT_PROFILE_H

#include "er_types.h"

enum {
  ER_BOOT_PROFILE_UI = 4u,
  ER_BOOT_PROFILE_NATIVE = 5u,
  ER_BOOT_PROFILE_TPM = 6u,
  ER_BOOT_PROFILE_GPU = 7u
};

const char* er_boot_profile_label(UINT32 profile);
UINT8 er_boot_profile_valid(UINT32 profile);

#endif

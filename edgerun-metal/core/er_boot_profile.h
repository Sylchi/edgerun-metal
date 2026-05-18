#ifndef ER_BOOT_PROFILE_H
#define ER_BOOT_PROFILE_H

#include "er_types.h"

enum {
  ER_BOOT_PROFILE_OS = 4u
};

const char* er_boot_profile_label(UINT32 profile);
UINT8 er_boot_profile_valid(UINT32 profile);

#endif

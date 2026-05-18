#ifndef ER_IDENTITY_H
#define ER_IDENTITY_H

/*
 * Purpose: normalize identity records across signing keys and hash commitments.
 * Intention: keep identity type and backing explicit so admission can decide trust.
 */

#include "er_work.h"

UINT8 er_identity_prepare(UINT16 identity_type, UINT16 backing_type,
                          const UINT8* material, UINT16 material_len,
                          ErIdentity* out_identity);
UINT8 er_identity_valid(const ErIdentity* identity);
UINT8 er_identity_equal(const ErIdentity* left, const ErIdentity* right);

#endif

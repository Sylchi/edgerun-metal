#ifndef ER_CREDENTIAL_H
#define ER_CREDENTIAL_H

/*
 * Purpose: carry compact signing key or hash material inside metal admission records.
 * Intention: avoid defining identity bytes; routable identities belong to edgerun-identity.
 */

#include "er_work.h"

UINT8 er_credential_prepare(UINT16 credential_kind, UINT16 backing_type,
                            const UINT8* material, UINT16 material_len,
                            ErCredential* out_credential);
UINT8 er_credential_valid(const ErCredential* credential);
UINT8 er_credential_equal(const ErCredential* left, const ErCredential* right);

#endif

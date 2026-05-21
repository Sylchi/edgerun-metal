#ifndef ER_IDENTITY_H
#define ER_IDENTITY_H

/*
 * Purpose: define routable EdgeRun identities independent of transport media.
 * Intention: let wire, storage, VFS, apps, and admission reference the same
 * fixed identity primitive without embedding auth, login, or policy decisions.
 */

#include <stddef.h>
#include <stdint.h>

#define ER_IDENTITY_OK 0
#define ER_IDENTITY_ERR_BADARG -1
#define ER_IDENTITY_ERR_TOOBIG -2
#define ER_IDENTITY_ERR_CORRUPT -3

#define ER_IDENTITY_ABI_VERSION 1u
#define ER_IDENTITY_ID_SIZE 32u
#define ER_IDENTITY_HASH_SIZE 32u
#define ER_IDENTITY_MATERIAL_MAX 96u
#define ER_IDENTITY_ED25519_PUBLIC_SIZE 32u
#define ER_IDENTITY_P256_PUBLIC_SIZE 64u
#define ER_IDENTITY_ENDPOINT_MIN_SIZE 1u
#define ER_IDENTITY_DELEGATION_MATERIAL_SIZE 96u

#define ER_IDENTITY_KIND_USER 1u
#define ER_IDENTITY_KIND_DEVICE 2u
#define ER_IDENTITY_KIND_APP 3u
#define ER_IDENTITY_KIND_STORAGE 4u
#define ER_IDENTITY_KIND_RELAY 5u
#define ER_IDENTITY_KIND_RESOURCE 6u
#define ER_IDENTITY_KIND_OBJECT 7u
#define ER_IDENTITY_KIND_EPHEMERAL 8u
#define ER_IDENTITY_KIND_DELEGATED 9u

#define ER_IDENTITY_SOURCE_HASH 1u
#define ER_IDENTITY_SOURCE_ED25519_PUBLIC 2u
#define ER_IDENTITY_SOURCE_P256_PUBLIC 3u
#define ER_IDENTITY_SOURCE_TPM_P256_PUBLIC 4u
#define ER_IDENTITY_SOURCE_OBJECT_ID 5u
#define ER_IDENTITY_SOURCE_ENDPOINT 6u
#define ER_IDENTITY_SOURCE_DERIVED 7u
#define ER_IDENTITY_SOURCE_DELEGATION 8u

typedef struct er_identity_id {
  uint8_t bytes[ER_IDENTITY_ID_SIZE];
} er_identity_id_t;

typedef struct er_identity_source {
  uint16_t source_kind;
  uint16_t material_len;
  uint8_t material[ER_IDENTITY_MATERIAL_MAX];
} er_identity_source_t;

typedef struct er_identity {
  uint16_t abi_version;
  uint16_t identity_kind;
  er_identity_id_t id;
  er_identity_source_t source;
} er_identity_t;

int er_identity_id_nonzero(const er_identity_id_t* id);
int er_identity_id_equal(const er_identity_id_t* left,
                         const er_identity_id_t* right);
int er_identity_source_prepare(uint16_t source_kind,
                               const void* material,
                               size_t material_len,
                               er_identity_source_t* out_source);
int er_identity_source_prepare_delegation(const er_identity_id_t* parent,
                                          const er_identity_id_t* delegate,
                                          const uint8_t scope_hash[ER_IDENTITY_HASH_SIZE],
                                          er_identity_source_t* out_source);
int er_identity_source_valid(const er_identity_source_t* source);
int er_identity_id_from_source(const er_identity_source_t* source,
                               er_identity_id_t* out_id);
int er_identity_prepare(uint16_t identity_kind,
                        const er_identity_source_t* source,
                        er_identity_t* out_identity);
int er_identity_valid(const er_identity_t* identity);
int er_identity_equal(const er_identity_t* left,
                      const er_identity_t* right);
int er_identity_derive_child(const er_identity_t* parent,
                             uint16_t child_kind,
                             const void* label,
                             size_t label_len,
                             const void* material,
                             size_t material_len,
                             er_identity_t* out_child);

#endif

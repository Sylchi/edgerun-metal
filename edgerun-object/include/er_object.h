#ifndef ER_OBJECT_H
#define ER_OBJECT_H

/*
 * Purpose: define EdgeRun canonical object nodes.
 * Intention: give memory, wire, durable storage, and apps one deterministic
 * object format that carries requirements, owner layers, envelopes, and child
 * references without embedding authority or device policy.
 */

#include <stddef.h>
#include <stdint.h>

#include "er_clock.h"

#define ER_OBJECT_OK 0
#define ER_OBJECT_ERR_BADARG -1
#define ER_OBJECT_ERR_TOOBIG -2
#define ER_OBJECT_ERR_CORRUPT -3
#define ER_OBJECT_ERR_UNSUPPORTED -4

#define ER_OBJECT_ID_SIZE 32u
#define ER_OBJECT_MAGIC_SIZE 8u
#define ER_OBJECT_ABI_VERSION 1u
#define ER_OBJECT_MAX_OWNERS 16u
#define ER_OBJECT_MAX_ENVELOPES 16u
#define ER_OBJECT_MAX_CHILDREN 65536u
#define ER_OBJECT_SIGNATURE_MAX_SIZE 128u

#define ER_OBJECT_KIND_BYTES 1u
#define ER_OBJECT_KIND_TREE 2u
#define ER_OBJECT_KIND_RECEIPT 4u

#define ER_OBJECT_DURABILITY_MEMORY 1u
#define ER_OBJECT_DURABILITY_DURABLE 2u
#define ER_OBJECT_DURABILITY_REPLICATED 3u

#define ER_OBJECT_CONFIDENTIALITY_PUBLIC 1u
#define ER_OBJECT_CONFIDENTIALITY_INTEGRITY_ONLY 2u
#define ER_OBJECT_CONFIDENTIALITY_APP_PRIVATE 3u
#define ER_OBJECT_CONFIDENTIALITY_USER_PRIVATE 4u
#define ER_OBJECT_CONFIDENTIALITY_USER_APP_PRIVATE 5u
#define ER_OBJECT_CONFIDENTIALITY_DEVICE_PRIVATE 6u
#define ER_OBJECT_CONFIDENTIALITY_LAYERED 7u

#define ER_OBJECT_PORTABILITY_MACHINE_BOUND 1u
#define ER_OBJECT_PORTABILITY_USER_PORTABLE 2u
#define ER_OBJECT_PORTABILITY_APP_PORTABLE 3u
#define ER_OBJECT_PORTABILITY_PUBLIC_PORTABLE 4u

#define ER_OBJECT_INTEGRITY_HASH_ONLY 1u
#define ER_OBJECT_INTEGRITY_SIGNED 2u
#define ER_OBJECT_INTEGRITY_SEALED 3u

#define ER_OBJECT_LIFETIME_TRANSIENT 1u
#define ER_OBJECT_LIFETIME_SESSION 2u
#define ER_OBJECT_LIFETIME_CACHE 3u
#define ER_OBJECT_LIFETIME_RETAINED 4u
#define ER_OBJECT_LIFETIME_PINNED 5u

#define ER_OBJECT_VISIBILITY_PRIVATE 1u
#define ER_OBJECT_VISIBILITY_APP_NAMESPACE 2u
#define ER_OBJECT_VISIBILITY_USER_NAMESPACE 3u
#define ER_OBJECT_VISIBILITY_PUBLIC 4u

#define ER_OBJECT_ACCESS_EXPLICIT_IO 1u
#define ER_OBJECT_ACCESS_HOT_MEMORY_ALLOWED 2u

#define ER_OBJECT_OWNER_DEVICE 1u
#define ER_OBJECT_OWNER_STORAGE 2u
#define ER_OBJECT_OWNER_APP 3u
#define ER_OBJECT_OWNER_USER 4u

#define ER_OBJECT_ENVELOPE_NONE 0u
#define ER_OBJECT_ENVELOPE_DEVICE 1u
#define ER_OBJECT_ENVELOPE_STORAGE 2u
#define ER_OBJECT_ENVELOPE_APP 3u
#define ER_OBJECT_ENVELOPE_USER 4u
#define ER_OBJECT_ENVELOPE_SIGNATURE 5u

#define ER_OBJECT_ALGORITHM_NONE 0u
#define ER_OBJECT_ALGORITHM_BLAKE3 1u
#define ER_OBJECT_ALGORITHM_AES_GCM_256 2u
#define ER_OBJECT_ALGORITHM_XCHACHA20_POLY1305 3u
#define ER_OBJECT_ALGORITHM_ED25519 4u
#define ER_OBJECT_ALGORITHM_ECDSA_P256_SHA256 5u

typedef struct er_object_requirements {
  uint32_t durability;
  uint32_t confidentiality;
  uint32_t portability;
  uint32_t integrity;
  uint32_t lifetime;
  uint32_t visibility;
  uint32_t access_cost;
} er_object_requirements_t;

typedef struct er_object_owner {
  uint32_t owner_kind;
  uint8_t node_id[ER_OBJECT_ID_SIZE];
} er_object_owner_t;

typedef struct er_object_envelope {
  uint32_t envelope_kind;
  uint16_t owner_index;
  uint16_t algorithm;
  uint32_t flags;
  uint8_t key_id[ER_OBJECT_ID_SIZE];
  uint8_t metadata_hash[ER_OBJECT_ID_SIZE];
} er_object_envelope_t;

typedef struct er_object_child_ref {
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  uint64_t logical_offset; //@optimizer-ignore object offsets are canonical 64-bit fields
  uint64_t logical_len; //@optimizer-ignore object lengths are canonical 64-bit fields
  uint16_t node_kind;
  uint16_t reserved;
  uint8_t requirements_hash[ER_OBJECT_ID_SIZE];
} er_object_child_ref_t;

typedef struct er_object_info {
  uint16_t node_kind;
  uint32_t flags;
  uint16_t owner_count;
  uint16_t envelope_count;
  uint32_t child_count;
  uint64_t logical_len; //@optimizer-ignore object lengths are canonical 64-bit fields
  uint64_t body_len; //@optimizer-ignore object body lengths are canonical 64-bit fields
  er_clock_epoch_stamp_t epoch;
  er_object_requirements_t requirements;
  uint8_t object_id[ER_OBJECT_ID_SIZE];
  const uint8_t* body;
} er_object_info_t;

typedef struct er_object_signature_info {
  uint8_t signer_id[ER_OBJECT_ID_SIZE];
  uint8_t challenge_id[ER_OBJECT_ID_SIZE];
  uint8_t subject_id[ER_OBJECT_ID_SIZE];
  uint16_t algorithm;
  uint16_t signature_len;
  uint8_t signature[ER_OBJECT_SIGNATURE_MAX_SIZE];
} er_object_signature_info_t;

int er_object_requirements_valid(const er_object_requirements_t* requirements);
int er_object_requirements_hash(const er_object_requirements_t* requirements,
                                uint8_t out_hash[ER_OBJECT_ID_SIZE]);
int er_object_canonical_size(uint16_t node_kind, size_t body_len,
                             uint16_t owner_count, uint16_t envelope_count,
                             uint32_t child_count, size_t* out_len);
int er_object_build_node(uint16_t node_kind, uint32_t flags,
                         const er_object_requirements_t* requirements,
                         er_clock_epoch_stamp_t epoch,
                         const er_object_owner_t* owners, uint16_t owner_count,
                         const er_object_envelope_t* envelopes, uint16_t envelope_count,
                         const er_object_child_ref_t* children, uint32_t child_count,
                         const void* body, size_t body_len,
                         void* out, size_t out_cap, size_t* out_len,
                         uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_object_sign(const void* subject_canonical, size_t subject_len,
                   const void* challenge_canonical, size_t challenge_len,
                   const uint8_t signer_id[ER_OBJECT_ID_SIZE],
                   uint16_t algorithm, const void* signature,
                   size_t signature_len, er_clock_epoch_stamp_t epoch,
                   void* out, size_t out_cap, size_t* out_len,
                   uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_object_signature_verify(const void* canonical, size_t len,
                               er_object_signature_info_t* out_info);
int er_object_id(const void* canonical, size_t len,
                 uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_object_id_for_bytes(const er_object_requirements_t* requirements,
                           er_clock_epoch_stamp_t epoch,
                           const void* body, size_t body_len,
                           uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_object_verify(const void* canonical, size_t len,
                     er_object_info_t* out_info);
int er_object_owner_at(const void* canonical, size_t len, uint16_t index,
                       er_object_owner_t* out_owner);
int er_object_envelope_at(const void* canonical, size_t len, uint16_t index,
                          er_object_envelope_t* out_envelope);
int er_object_child_at(const void* canonical, size_t len, uint32_t index,
                       er_object_child_ref_t* out_child);

#endif

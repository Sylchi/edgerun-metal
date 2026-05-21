#ifndef ER_NODE_ID_H
#define ER_NODE_ID_H

/*
 * Purpose: derive stable node identifiers from explicit endpoint identity material.
 * Intention: keep every node-id source mapped through one deterministic API.
 */

#include "er_types.h"

#define ER_NODE_ID_LEN 32u
#define ER_NODE_ID_SOURCE_MATERIAL_MAX 96u
#define ER_NODE_ID_SOURCE_HASH_LEN 32u
#define ER_NODE_ID_SOURCE_MAC_LEN 6u
#define ER_NODE_ID_SOURCE_MEMORY_ADDRESS_LEN 8u
#define ER_NODE_ID_SOURCE_PUBLIC_KEY_ED25519_LEN 32u
#define ER_NODE_ID_SOURCE_PUBLIC_KEY_P256_LEN 64u

#define ER_NODE_ID_SOURCE_HASH 1u
#define ER_NODE_ID_SOURCE_MAC 2u
#define ER_NODE_ID_SOURCE_MEMORY_ADDRESS 3u
#define ER_NODE_ID_SOURCE_PUBLIC_KEY 4u
#define ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY 5u
#define ER_NODE_ID_SOURCE_ENDPOINT 6u

typedef struct ErCryptoProvider ErCryptoProvider;

typedef struct {
  UINT8 bytes[ER_NODE_ID_LEN];
} ErNodeId;

typedef struct {
  UINT16 kind;
  UINT16 material_len;
  UINT8 material[ER_NODE_ID_SOURCE_MATERIAL_MAX];
} ErNodeIdSource;

UINT8 er_node_id_equal(const ErNodeId* left, const ErNodeId* right);
UINT8 er_node_id_nonzero(const ErNodeId* value);
UINT8 er_node_id_source_prepare(UINT16 kind,
                                const UINT8* material,
                                UINT16 material_len,
                                ErNodeIdSource* out_source);
UINT8 er_node_id_source_prepare_memory_address(UINT64 address,
                                               ErNodeIdSource* out_source);
UINT8 er_node_id_from_source(const ErCryptoProvider* crypto,
                             const ErNodeIdSource* source,
                             ErNodeId* out_node_id);
UINT8 er_node_id_from_material(const ErCryptoProvider* crypto,
                               UINT16 kind,
                               const UINT8* material,
                               UINT16 material_len,
                               ErNodeId* out_node_id);

#endif

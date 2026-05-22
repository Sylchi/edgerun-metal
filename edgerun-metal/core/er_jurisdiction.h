#ifndef ER_JURISDICTION_H
#define ER_JURISDICTION_H

/*
 * Purpose: define local jurisdiction and node-instance records for admission.
 * Intention: make each node an explicit policy authority before it routes work.
 */

#include "er_crypto.h"

#define ER_JURISDICTION_ABI_VERSION 1u

#define ER_ADMISSION_POLICY_SOURCE_DAO 1u
#define ER_ADMISSION_POLICY_SOURCE_USER 2u
#define ER_ADMISSION_POLICY_SOURCE_INHERITED 3u

#define ER_RUNTIME_TARGET_FIRMWARE 4u

#define ER_NODE_INSTANCE_STATUS_PENDING 1u
#define ER_NODE_INSTANCE_STATUS_RUNNING 2u
#define ER_NODE_INSTANCE_STATUS_STOPPED 3u
#define ER_NODE_INSTANCE_STATUS_REVOKED 4u

typedef struct {
  UINT16 abi_version;
  UINT16 source;
  ErHash policy_id;
  ErCredential owner_identity;
  ErNodeIdentity admission_node;
  ErHash policy_hash;
  UINT64 max_budget;
  UINT64 valid_from_ms;
  UINT64 valid_until_ms;
} ErAdmissionPolicyRecord;

typedef struct {
  UINT16 abi_version;
  UINT16 role;
  ErHash instance_id;
  ErCredential owner_identity;
  ErNodeId node_id;
  UINT16 runtime_target;
  UINT16 status;
  ErHash policy_hash;
  UINT64 admitted_budget;
  ErHash route_scope_hash;
  UINT64 valid_from_ms;
  UINT64 valid_until_ms;
} ErNodeInstanceRecord;

UINT8 er_jurisdiction_node_identity_authority_valid(const ErNodeIdentity* identity);
UINT8 er_admission_policy_source_valid(UINT16 source);
UINT8 er_node_instance_status_valid(UINT16 status);
UINT8 er_runtime_target_valid(UINT16 runtime_target);
UINT8 er_admission_policy_prepare(const ErCryptoProvider* crypto,
                                  UINT16 source,
                                  const ErCredential* owner_identity,
                                  const ErNodeIdentity* admission_node,
                                  const ErHash* policy_hash,
                                  UINT64 max_budget,
                                  UINT64 valid_from_ms,
                                  UINT64 valid_until_ms,
                                  ErAdmissionPolicyRecord* out_policy);
UINT8 er_admission_policy_valid(const ErCryptoProvider* crypto,
                                const ErAdmissionPolicyRecord* policy);
UINT8 er_node_instance_prepare(const ErCryptoProvider* crypto,
                               const ErCredential* owner_identity,
                               const ErNodeId* node_id,
                               UINT16 role,
                               UINT16 runtime_target,
                               const ErHash* policy_hash,
                               UINT64 admitted_budget,
                               const ErHash* route_scope_hash,
                               UINT64 valid_from_ms,
                               UINT64 valid_until_ms,
                               UINT16 status,
                               ErNodeInstanceRecord* out_instance);
UINT8 er_node_instance_valid(const ErCryptoProvider* crypto,
                             const ErNodeInstanceRecord* instance);

#endif

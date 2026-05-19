#include "er_ephemeral_node.h"
#include "er_mem.h"

/*
 * Purpose: bind a fresh boot nonce to the admission id that this node serves.
 * Intention: persistence belongs to admission/object storage, not SD-card node
 * secrets.
 */

static const UINT8 g_ephemeral_node_domain[] =
    "edgerun:c:v1:ephemeral-node";

enum {
  ER_EPHEMERAL_NODE_ADMISSION_SPAN = 0u,
  ER_EPHEMERAL_NODE_NONCE_SPAN = 1u,
  ER_EPHEMERAL_NODE_SPAN_COUNT = 2u
};

UINT8 er_ephemeral_node_derive(const ErCryptoProvider* crypto,
                               const ErHash* admission_id,
                               const UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN],
                               ErEphemeralNode* out_node) {
  ErHash node_hash;
  ErByteSpan spans[ER_EPHEMERAL_NODE_SPAN_COUNT];

  if (crypto == 0 ||
      admission_id == 0 ||
      boot_nonce == 0 ||
      out_node == 0 ||
      er_hash_nonzero(admission_id) == 0u ||
      er_mem_any_nonzero(boot_nonce, ER_EPHEMERAL_NODE_BOOT_NONCE_LEN) == 0u) {
    return 0u;
  }

  spans[ER_EPHEMERAL_NODE_ADMISSION_SPAN].bytes = admission_id->bytes;
  spans[ER_EPHEMERAL_NODE_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_EPHEMERAL_NODE_NONCE_SPAN].bytes = boot_nonce;
  spans[ER_EPHEMERAL_NODE_NONCE_SPAN].len = ER_EPHEMERAL_NODE_BOOT_NONCE_LEN;
  if (er_crypto_hash(crypto,
                     g_ephemeral_node_domain,
                     (UINTN)(sizeof(g_ephemeral_node_domain) - 1u),
                     spans,
                     ER_EPHEMERAL_NODE_SPAN_COUNT,
                     &node_hash) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_node, (UINTN)sizeof(*out_node));
  out_node->abi_version = ER_EPHEMERAL_NODE_ABI_VERSION;
  out_node->admission_id = *admission_id;
  er_mem_copy(out_node->boot_nonce,
              boot_nonce,
              ER_EPHEMERAL_NODE_BOOT_NONCE_LEN);
  er_mem_copy(out_node->node_id.bytes, node_hash.bytes, ER_NODE_ID_LEN);
  return 1u;
}

UINT8 er_ephemeral_node_wifi_l2_prepare(const ErCryptoProvider* crypto,
                                        const ErHash* admission_id,
                                        const UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN],
                                        UINT8 channel,
                                        ErEphemeralNodeWifiL2* out_binding) {
  ErEphemeralNode node;
  ErWifiL2ApPlan ap_plan;

  if (out_binding == 0 ||
      er_ephemeral_node_derive(crypto,
                               admission_id,
                               boot_nonce,
                               &node) == 0u ||
      er_wifi_l2_ap_plan_prepare(&node.node_id, channel, &ap_plan) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_binding, (UINTN)sizeof(*out_binding));
  out_binding->abi_version = ER_EPHEMERAL_NODE_ABI_VERSION;
  out_binding->node = node;
  out_binding->ap_plan = ap_plan;
  return 1u;
}

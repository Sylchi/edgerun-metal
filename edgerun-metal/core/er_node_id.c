#include "er_node_id.h"
#include "er_crypto.h"
#include "er_mem.h"

static const UINT8 g_er_node_id_domain[] = "edgerun:c:v1:node-id";

enum {
  ER_NODE_ID_SOURCE_HEADER_BYTES = 4u,
  ER_NODE_ID_SOURCE_KIND_OFFSET = 0u,
  ER_NODE_ID_SOURCE_LEN_OFFSET = 2u,
  ER_NODE_ID_SOURCE_HEADER_SPAN = 0u,
  ER_NODE_ID_SOURCE_MATERIAL_SPAN = 1u,
  ER_NODE_ID_SOURCE_SPAN_COUNT = 2u,
  ER_NODE_ID_U16_HIGH_SHIFT = 8u,
  ER_NODE_ID_U64_BYTE0 = 0u,
  ER_NODE_ID_U64_BYTE1 = 1u,
  ER_NODE_ID_U64_BYTE2 = 2u,
  ER_NODE_ID_U64_BYTE3 = 3u,
  ER_NODE_ID_U64_BYTE4 = 4u,
  ER_NODE_ID_U64_BYTE5 = 5u,
  ER_NODE_ID_U64_BYTE6 = 6u,
  ER_NODE_ID_U64_BYTE7 = 7u,
  ER_NODE_ID_U64_SHIFT0 = 56u,
  ER_NODE_ID_U64_SHIFT1 = 48u,
  ER_NODE_ID_U64_SHIFT2 = 40u,
  ER_NODE_ID_U64_SHIFT3 = 32u,
  ER_NODE_ID_U64_SHIFT4 = 24u,
  ER_NODE_ID_U64_SHIFT5 = 16u,
  ER_NODE_ID_U64_SHIFT6 = 8u,
  ER_NODE_ID_BYTE_MASK = 0xffu
};

static UINT8 er_node_id_source_kind_valid(UINT16 kind) {
  switch (kind) {
    case ER_NODE_ID_SOURCE_HASH:
    case ER_NODE_ID_SOURCE_MAC:
    case ER_NODE_ID_SOURCE_MEMORY_ADDRESS:
    case ER_NODE_ID_SOURCE_PUBLIC_KEY:
    case ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY:
    case ER_NODE_ID_SOURCE_ENDPOINT:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_node_id_source_material_len_valid(UINT16 kind, UINT16 material_len) {
  switch (kind) {
    case ER_NODE_ID_SOURCE_HASH:
      return (UINT8)(material_len == ER_NODE_ID_SOURCE_HASH_LEN);
    case ER_NODE_ID_SOURCE_MAC:
      return (UINT8)(material_len == ER_NODE_ID_SOURCE_MAC_LEN);
    case ER_NODE_ID_SOURCE_MEMORY_ADDRESS:
      return (UINT8)(material_len == ER_NODE_ID_SOURCE_MEMORY_ADDRESS_LEN);
    case ER_NODE_ID_SOURCE_PUBLIC_KEY:
      return (UINT8)(material_len == ER_NODE_ID_SOURCE_PUBLIC_KEY_ED25519_LEN ||
                     material_len == ER_NODE_ID_SOURCE_PUBLIC_KEY_P256_LEN);
    case ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY:
      return (UINT8)(material_len == ER_NODE_ID_SOURCE_PUBLIC_KEY_P256_LEN);
    case ER_NODE_ID_SOURCE_ENDPOINT:
      return (UINT8)(material_len > 0u && material_len <= ER_NODE_ID_SOURCE_MATERIAL_MAX);
    default:
      return 0u;
  }
}

static void er_node_id_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value >> ER_NODE_ID_U16_HIGH_SHIFT);
  dst[1] = (UINT8)(value & ER_NODE_ID_BYTE_MASK);
}

static void er_node_id_put_be64(UINT8* dst, UINT64 value) {
  dst[ER_NODE_ID_U64_BYTE0] = (UINT8)(value >> ER_NODE_ID_U64_SHIFT0);
  dst[ER_NODE_ID_U64_BYTE1] = (UINT8)((value >> ER_NODE_ID_U64_SHIFT1) & ER_NODE_ID_BYTE_MASK);
  dst[ER_NODE_ID_U64_BYTE2] = (UINT8)((value >> ER_NODE_ID_U64_SHIFT2) & ER_NODE_ID_BYTE_MASK);
  dst[ER_NODE_ID_U64_BYTE3] = (UINT8)((value >> ER_NODE_ID_U64_SHIFT3) & ER_NODE_ID_BYTE_MASK);
  dst[ER_NODE_ID_U64_BYTE4] = (UINT8)((value >> ER_NODE_ID_U64_SHIFT4) & ER_NODE_ID_BYTE_MASK);
  dst[ER_NODE_ID_U64_BYTE5] = (UINT8)((value >> ER_NODE_ID_U64_SHIFT5) & ER_NODE_ID_BYTE_MASK);
  dst[ER_NODE_ID_U64_BYTE6] = (UINT8)((value >> ER_NODE_ID_U64_SHIFT6) & ER_NODE_ID_BYTE_MASK);
  dst[ER_NODE_ID_U64_BYTE7] = (UINT8)(value & ER_NODE_ID_BYTE_MASK);
}

UINT8 er_node_id_equal(const ErNodeId* left, const ErNodeId* right) {
  if (left == 0 || right == 0) {
    return 0u;
  }
  return er_mem_equal(left->bytes, right->bytes, ER_NODE_ID_LEN);
}

UINT8 er_node_id_nonzero(const ErNodeId* value) {
  if (value == 0) {
    return 0u;
  }
  return er_mem_any_nonzero(value->bytes, ER_NODE_ID_LEN);
}

UINT8 er_node_id_source_prepare(UINT16 kind,
                                const UINT8* material,
                                UINT16 material_len,
                                ErNodeIdSource* out_source) {
  if (out_source == 0 ||
      material == 0 ||
      material_len == 0u ||
      material_len > ER_NODE_ID_SOURCE_MATERIAL_MAX ||
      er_node_id_source_kind_valid(kind) == 0u ||
      er_node_id_source_material_len_valid(kind, material_len) == 0u ||
      er_mem_any_nonzero(material, material_len) == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)out_source, (UINTN)sizeof(*out_source));
  out_source->kind = kind;
  out_source->material_len = material_len;
  er_mem_copy(out_source->material, material, material_len);
  return 1u;
}

UINT8 er_node_id_source_prepare_memory_address(UINT64 address,
                                               ErNodeIdSource* out_source) {
  UINT8 material[8];

  if (address == 0u) {
    return 0u;
  }

  er_node_id_put_be64(material, address);
  return er_node_id_source_prepare(ER_NODE_ID_SOURCE_MEMORY_ADDRESS,
                                   material,
                                   (UINT16)sizeof(material),
                                   out_source);
}

UINT8 er_node_id_from_source(const ErCryptoProvider* crypto,
                             const ErNodeIdSource* source,
                             ErNodeId* out_node_id) {
  UINT8 header[ER_NODE_ID_SOURCE_HEADER_BYTES];
  ErHash hash;
  ErByteSpan spans[ER_NODE_ID_SOURCE_SPAN_COUNT];

  if (crypto == 0 ||
      source == 0 ||
      out_node_id == 0 ||
      source->material_len == 0u ||
      source->material_len > ER_NODE_ID_SOURCE_MATERIAL_MAX ||
      er_node_id_source_kind_valid(source->kind) == 0u ||
      er_node_id_source_material_len_valid(source->kind, source->material_len) == 0u ||
      er_mem_any_nonzero(source->material, source->material_len) == 0u) {
    return 0u;
  }

  er_node_id_put_be16(header + ER_NODE_ID_SOURCE_KIND_OFFSET, source->kind);
  er_node_id_put_be16(header + ER_NODE_ID_SOURCE_LEN_OFFSET, source->material_len);
  spans[ER_NODE_ID_SOURCE_HEADER_SPAN].bytes = header;
  spans[ER_NODE_ID_SOURCE_HEADER_SPAN].len = (UINTN)sizeof(header);
  spans[ER_NODE_ID_SOURCE_MATERIAL_SPAN].bytes = source->material;
  spans[ER_NODE_ID_SOURCE_MATERIAL_SPAN].len = source->material_len;

  if (er_crypto_hash(crypto,
                     g_er_node_id_domain,
                     (UINTN)(sizeof(g_er_node_id_domain) - 1u),
                     spans,
                     ER_NODE_ID_SOURCE_SPAN_COUNT,
                     &hash) == 0u) {
    er_mem_zero((UINT8*)out_node_id, (UINTN)sizeof(*out_node_id));
    return 0u;
  }

  er_mem_copy(out_node_id->bytes, hash.bytes, ER_NODE_ID_LEN);
  return 1u;
}

UINT8 er_node_id_from_material(const ErCryptoProvider* crypto,
                               UINT16 kind,
                               const UINT8* material,
                               UINT16 material_len,
                               ErNodeId* out_node_id) {
  ErNodeIdSource source;

  if (er_node_id_source_prepare(kind, material, material_len, &source) == 0u) {
    return 0u;
  }
  return er_node_id_from_source(crypto, &source, out_node_id);
}

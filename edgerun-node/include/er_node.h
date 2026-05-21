#ifndef ER_NODE_H
#define ER_NODE_H

/*
 * Purpose: expose EdgeRun object-oriented node interactions in C.
 * Intention: let developers instantiate a routable node and perform explicit
 * object-in/object-out operations without learning storage, clock, identity,
 * or wire internals. No operation creates hidden authority or mutable shadow
 * state; outputs are canonical edgerun-object bytes or ids.
 */

#include <stddef.h>
#include <stdint.h>

#include "er_clock.h"
#include "er_identity.h"
#include "er_object.h"
#include "er_store.h"

#define ER_NODE_OK 0
#define ER_NODE_ERR_BADARG -1
#define ER_NODE_ERR_CORRUPT -2
#define ER_NODE_ERR_TOOBIG -3
#define ER_NODE_ERR_NOSTORE -4

#define ER_NODE_HANDLE_BYTES 1024u
#define ER_NODE_METHOD_STORE 1u
#define ER_NODE_METHOD_FETCH 2u
#define ER_NODE_METHOD_REQUEST 3u
#define ER_NODE_METHOD_SIGN 4u
#define ER_NODE_METHOD_SPAWN 5u

typedef struct er_node {
  uint64_t opaque[ER_NODE_HANDLE_BYTES / sizeof(uint64_t)];
} er_node_t;

typedef struct er_node_config {
  const er_identity_t* identity;
  const er_clock_t* clock;
  er_store_t* store;
  void* arena;
  size_t arena_len;
  uint64_t storage_limit;
} er_node_config_t;

typedef struct er_node_budget {
  size_t memory_len;
  size_t memory_used;
  uint64_t storage_limit;
  uint64_t storage_used;
} er_node_budget_t;

typedef struct er_node_receipt {
  uint32_t method;
  uint32_t status;
  uint8_t subject_id[ER_OBJECT_ID_SIZE];
  uint8_t result_id[ER_OBJECT_ID_SIZE];
  uint8_t log_root[ER_OBJECT_ID_SIZE];
  er_clock_epoch_stamp_t epoch;
} er_node_receipt_t;

int er_node_open_config(er_node_t* node, const er_node_config_t* config);
int er_node_open(er_node_t* node, const er_identity_t* identity,
                 const er_clock_t* clock, er_store_t* store);
int er_node_identity(const er_node_t* node, er_identity_t* out_identity);
int er_node_epoch(const er_node_t* node, er_clock_epoch_stamp_t* out_epoch);
int er_node_budget(const er_node_t* node, er_node_budget_t* out_budget);
int er_node_spawn(er_node_t* parent, const er_identity_t* child_identity,
                  const er_clock_t* child_clock, size_t memory_len,
                  uint64_t storage_limit, er_store_t* child_store,
                  er_node_t* out_child, void* out_receipt_object,
                  size_t out_cap, size_t* out_len,
                  uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_node_describe_identity(const er_node_t* node, void* out, size_t out_cap,
                              size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_node_describe_clock(const er_node_t* node, void* out, size_t out_cap,
                           size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_node_describe_store(const er_node_t* node, void* out, size_t out_cap,
                           size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_node_build_object(er_node_t* node, uint16_t node_kind, uint32_t flags,
                         const er_object_requirements_t* requirements,
                         const er_object_child_ref_t* children,
                         uint32_t child_count, const void* body,
                         size_t body_len, void* out, size_t out_cap,
                         size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_node_store_object(er_node_t* node, const void* canonical,
                         size_t canonical_len,
                         er_node_receipt_t* out_receipt);
int er_node_fetch_object(er_node_t* node, const uint8_t object_id[ER_OBJECT_ID_SIZE],
                         void* out, size_t out_cap, size_t* out_len,
                         er_node_receipt_t* out_receipt);
int er_node_request(er_node_t* node, const void* capability_object,
                    size_t capability_len, void* out_receipt_object,
                    size_t out_cap, size_t* out_len,
                    uint8_t out_id[ER_OBJECT_ID_SIZE]);
int er_node_sign(er_node_t* node, const void* subject_canonical,
                 size_t subject_len, const void* challenge_canonical,
                 size_t challenge_len, uint16_t algorithm,
                 const void* signature, size_t signature_len,
                 void* out_signature_object, size_t out_cap,
                 size_t* out_len, uint8_t out_id[ER_OBJECT_ID_SIZE]);

#endif

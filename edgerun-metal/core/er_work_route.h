#ifndef ER_WORK_ROUTE_H
#define ER_WORK_ROUTE_H

/*
 * Purpose: derive and check admission-defined routes for universal relay traffic.
 * Intention: keep relays as cheap packet movers while preserving transit accounting evidence.
 */

#include "er_crypto.h"
#include "er_epoch_clock.h"

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash challenge_id;
  ErHash route_id;
  ErHash request_hash;
  ErHash admission_hash;
  ErNodeId worker_node_id;
  ErNodeId relay_node_id;
  ErEpochStamp issued_at;
  ErEpochStamp valid_until;
} ErWorkRouteChallenge;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash proof_hash;
  ErHash challenge_id;
  ErHash route_id;
  ErNodeId worker_node_id;
  ErNodeId relay_node_id;
  ErEpochStamp started_at;
  ErWorkSignature signature;
} ErWorkRouteStartProof;

UINT8 er_work_admitted_route_from_admission(const ErCryptoProvider* crypto,
                                            const ErWorkRequest* request,
                                            const ErWorkAdmission* admission,
                                            const ErNodeId* source_node_id,
                                            const ErNodeId* relay_node_id,
                                            UINT16 target_role,
                                            ErAdmittedRoute* out_route);
UINT8 er_work_verify_channel_envelope_for_route(const ErChannelEnvelopeHeader* envelope,
                                                const ErAdmittedRoute* route);
UINT8 er_work_prepare_relay_forward_intent(const ErWorkAdmission* admission,
                                           const ErChannelEnvelopeHeader* envelope,
                                           const ErNodeId* current_relay_node_id,
                                           const ErChannelEndpoint* from_endpoint,
                                           const ErChannelEndpoint* to_endpoint,
                                           ErRelayForwardIntent* out_intent);
UINT8 er_work_ordered_message_input_hash(const ErCryptoProvider* crypto,
                                         const ErChannelEnvelopeHeader* envelope,
                                         ErHash* out_hash);
UINT8 er_work_prepare_relay_transit_hop(const ErCryptoProvider* crypto,
                                        const ErRelayForwardIntent* intent,
                                        const ErHash* input_hash,
                                        const ErHash* previous_transit_hash,
                                        UINT16 hop_index,
                                        ErRelayTransitHop* out_hop);
UINT8 er_work_prepare_relay_accounting_claim(const ErRelayTransitHop* hop,
                                             const ErHash* request_hash,
                                             const ErHash* admission_hash,
                                             UINT64 packet_bytes,
                                             UINT64 unit_price,
                                             UINT64 receipt_base,
                                             ErRelayAccountingClaim* out_claim);
UINT8 er_work_route_challenge_prepare(const ErCryptoProvider* crypto,
                                      const ErAdmittedRoute* route,
                                      ErEpochStamp issued_at,
                                      ErEpochStamp valid_until,
                                      ErWorkRouteChallenge* out_challenge);
UINT8 er_work_route_challenge_valid_at(const ErWorkRouteChallenge* challenge,
                                       ErEpochStamp now);
UINT8 er_work_route_start_proof_sign(const ErCryptoProvider* crypto,
                                     const ErWorkRouteChallenge* challenge,
                                     const ErIdentity* worker_identity,
                                     ErEpochStamp started_at,
                                     ErWorkRouteStartProof* out_proof);
UINT8 er_work_route_start_proof_verify(const ErCryptoProvider* crypto,
                                       const ErWorkRouteChallenge* challenge,
                                       const ErWorkRouteStartProof* proof,
                                       ErEpochStamp now);
UINT8 er_work_prepare_capability_envelope_header(UINT16 kind,
                                                 UINT16 operation,
                                                 UINT16 content_type,
                                                 UINT32 risk_flags,
                                                 const ErHash* session_id,
                                                 const ErHash* invocation_id,
                                                 const ErHash* capability_id,
                                                 const ErNodeId* source_node_id,
                                                 const ErNodeId* target_node_id,
                                                 UINT64 sequence,
                                                 UINT64 timestamp_ms,
                                                 const ErHash* payload_hash,
                                                 UINT32 payload_len,
                                                 ErCapabilityEnvelopeHeader* out_header);
UINT8 er_work_capability_envelope_header_valid(const ErCapabilityEnvelopeHeader* header);

#endif

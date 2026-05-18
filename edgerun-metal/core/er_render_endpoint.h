#ifndef ER_RENDER_ENDPOINT_H
#define ER_RENDER_ENDPOINT_H

/*
 * Purpose: capture admitted render capability work before device-specific drawing.
 * Intention: keep render endpoints as adapters for verified relay work, not app-owned framebuffers.
 */

#include "er_work_route.h"
#include "wasm_vm.h"

#define ER_RENDER_ENDPOINT_ABI_VERSION 1u

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash capture_id;
  ErHash route_id;
  ErHash capability_id;
  ErHash invocation_id;
  ErHash scene_hash;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  UINT64 sequence;
  UINT64 timestamp_ms;
  UINT32 scene_bytes;
  UINT32 risk_flags;
} ErRenderEndpointCapture;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash scene_id;
  ErHash capture_id;
  ErHash scene_hash;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  UINT64 sequence;
  UINT32 scene_bytes;
  er_ui_scene_stats_t scene_stats;
} ErRenderEndpointScene;

UINT8 er_render_endpoint_scene_payload_hash(const ErCryptoProvider* crypto,
                                            const UINT8* bytes,
                                            UINT32 len,
                                            ErHash* out_hash);
UINT8 er_render_endpoint_capture(const ErCryptoProvider* crypto,
                                 const ErAdmittedRoute* route,
                                 const ErChannelEnvelopeHeader* envelope,
                                 const ErCapabilityEnvelopeHeader* capability,
                                 ErRenderEndpointCapture* out_capture);
UINT8 er_render_endpoint_decode_scene_payload(const ErCryptoProvider* crypto,
                                              const ErRenderEndpointCapture* capture,
                                              const UINT8* bytes,
                                              UINT32 len,
                                              er_ui_scene_t* out_scene,
                                              ErRenderEndpointScene* out_endpoint_scene);

#endif

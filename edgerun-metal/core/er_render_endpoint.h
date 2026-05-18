#ifndef ER_RENDER_ENDPOINT_H
#define ER_RENDER_ENDPOINT_H

/*
 * Purpose: capture admitted render capability work before device-specific drawing.
 * Intention: keep render endpoints as adapters for verified relay work, not app-owned framebuffers.
 */

#include "er_work_route.h"

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

UINT8 er_render_endpoint_capture(const ErCryptoProvider* crypto,
                                 const ErAdmittedRoute* route,
                                 const ErChannelEnvelopeHeader* envelope,
                                 const ErCapabilityEnvelopeHeader* capability,
                                 ErRenderEndpointCapture* out_capture);

#endif

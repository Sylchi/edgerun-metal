#ifndef ER_RELAY_ROUTER_H
#define ER_RELAY_ROUTER_H

/*
 * Purpose: choose hardware relay targets for parsed erwire packets.
 * Intention: keep route policy explicit and separate from endpoint movement.
 */

#include "er_hw_relay.h"

typedef struct {
  ErChannelEndpoint storage;
  ErChannelEndpoint display;
  UINT8 storage_ready;
  UINT8 display_ready;
} ErRelayVirtioRoutes;

UINT8 er_relay_prepare_default_virtio_routes(ErRelayVirtioRoutes* out_routes);
UINT8 er_relay_route_erwire_to_virtio(const ErChannelEndpoint* ingress,
                                      UINT16 erwire_kind,
                                      const UINT8* payload, UINT32 payload_len,
                                      const ErRelayVirtioRoutes* routes,
                                      ErRelayForwardIntent* out_intent);

#endif

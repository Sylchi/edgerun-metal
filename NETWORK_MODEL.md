# EdgeRun Network Specification

This file is the canonical networking specification for `edgerun-c`.
Reference code in the Rust repository is prior art only. The deployable network
model, public C API, and implementation milestones are defined here.

## Scope

EdgeRun networking moves sealed EdgeRun work between local devices. It does not
replace IP as a universal network stack and does not make transport addresses
authoritative.

This specification is publicizable as the EdgeRun C networking model and API
contract. It defines the behavior implementations must converge on. Milestones
below state which parts are already contract-only and which parts require
implementation and tests before being described as shipped behavior.

Normative words are used literally: `MUST` is required, `MUST NOT` is
prohibited, and failure cases return `0` unless a function documents a more
specific result.

Authority is carried by existing EdgeRun records:

- `ErWorkAdmission`
- `ErAdmittedRoute`
- `ErChannelEnvelopeHeader`
- `ErRelayTransitHop`
- `ErRelayAccountingClaim`
- `ErCapabilityEnvelopeHeader`
- `erwire` packet header and payload bytes

Transport addresses are local locators only. MAC addresses, SSIDs, IP
addresses, BLE advertisements, Wi-Fi channels, and router reachability do not
identify a node and do not authorize work.

## Existing Modules

The network specification uses these existing modules:

- `erwire.h`: packet envelope for EdgeRun bytes.
- `er_native_eth.h`: native L2 carrier for `erwire` packets.
- `er_net_frame.h`: Ethernet, ARP, IPv4, UDP, and EdgeRun EtherType framing.
- `er_ble_adv.h`: compact BLE advertisement records for pre-runtime presence.
- `er_wifi_burst.h`: short-lived open Wi-Fi AP/STA burst planning.
- `er_work_route.h`: admitted route checks, relay forwarding intent, transit
  evidence, accounting claims, and capability packet headers.
- `er_boot_admission_record.h`: boot authority and bootstrap carrier choice.

No additional wire protocol is introduced by this specification.

## Terms

`Node`
: A device or runtime instance identified by `ErNodeId`.

`Locator`
: A short-lived local delivery address for native Ethernet, open Wi-Fi,
  firmware UDP, memory, or another explicit carrier.

`Peer`
: A node plus its currently known locators.

`Route`
: A deterministic selection result containing the target node, next-hop node,
  selected peer index, selected locator index, and copied selected locator.

`Carrier`
: The mechanism that physically moves `erwire` bytes.

`Admission`
: The local authority decision that permits a node to spend resources.

`I/O binding`
: Caller-owned carrier handles used for one send or poll operation. I/O
  bindings are not locators and are not authority.

## Invariants

1. `erwire` is the only packet envelope for native EdgeRun network traffic.
2. A carrier MUST carry unmodified `erwire` packet bytes.
3. A locator MUST NOT be treated as node identity.
4. A route MUST NOT authorize work by itself.
5. Relay or endpoint work MUST pass `er_work_route` validation before local
   resources are spent.
6. BLE advertisements MUST remain compact presence records. They MUST NOT carry
   work payloads.
7. Wi-Fi burst links MUST be temporary locators derived from explicit role
   agreement.
8. Firmware UDP MUST be an explicit bootstrap locator, not a silent fallback.
9. Native Ethernet MUST use EdgeRun EtherType `0x88b5`.
10. Unsupported locator kinds, invalid lengths, expired locators, and malformed
    `erwire` packets MUST fail closed.
11. Route selection MUST be pure and deterministic.
12. Carrier I/O handles MUST NOT be serialized into locators or routes.

## Data Model

The public API exposes only selection data. It does not store authority inside
selected routes. Admission records stay owned by `er_work_route`.

```c
#define ER_NETWORK_ABI_VERSION 1u
#define ER_NETWORK_MAX_LOCATORS 4u
#define ER_NETWORK_LOCATOR_NATIVE_ETH_LEN ER_HW_RELAY_NATIVE_ETH_ADDR_LEN
#define ER_NETWORK_LOCATOR_FIRMWARE_UDP_LEN ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN
#define ER_NETWORK_LOCATOR_WIFI_OPEN_HEADER_LEN 6u

typedef enum {
  ER_NETWORK_LOCATOR_KIND_NONE = 0,
  ER_NETWORK_LOCATOR_KIND_NATIVE_ETH = 1,
  ER_NETWORK_LOCATOR_KIND_WIFI_OPEN = 2,
  ER_NETWORK_LOCATOR_KIND_FIRMWARE_UDP = 3,
  ER_NETWORK_LOCATOR_KIND_MEMORY = 4
} ErNetworkLocatorKind;

typedef enum {
  ER_NETWORK_DIRECTNESS_NONE = 0,
  ER_NETWORK_DIRECTNESS_DIRECT = 1,
  ER_NETWORK_DIRECTNESS_RELAYED = 2,
  ER_NETWORK_DIRECTNESS_BRIDGE_REQUIRED = 3,
  ER_NETWORK_DIRECTNESS_STORE_FORWARD = 4
} ErNetworkDirectness;

typedef struct {
  UINT16 abi_version;
  UINT8 kind;
  UINT8 directness;
  UINT16 priority;
  UINT64 valid_until_ms;
  UINT32 cost_per_packet;
  UINT32 cost_per_byte;
  UINT8 address_len;
  UINT8 address[ER_CHANNEL_ADDRESS_MAX];
} ErNetworkLocator;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNodeId node_id;
  UINT8 locator_count;
  ErNetworkLocator locators[ER_NETWORK_MAX_LOCATORS];
} ErNetworkPeer;

typedef struct {
  UINT16 abi_version;
  UINT8 peer_index;
  UINT8 locator_index;
  ErNodeId target_node_id;
  ErNodeId next_hop_node_id;
  ErNetworkLocator selected_locator;
} ErNetworkRoute;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErNativeEth* native_eth;
  ErChannelEndpoint* firmware_udp;
} ErNetworkIo;
```

### Locator Encoding

Locator address bytes are carrier-specific:

- `NATIVE_ETH`: 6 bytes, peer MAC address.
- `WIFI_OPEN`: 4 byte group id, 1 byte channel, 1 byte SSID length, then SSID
  bytes. SSID length MUST be at most `ER_WIFI_BURST_SSID_BYTES`.
- `FIRMWARE_UDP`: 4 byte IPv4 address followed by 2 byte port, matching the
  existing firmware UDP endpoint layout.
- `MEMORY`: zero bytes.

All multi-byte integer fields in locator address bytes are little-endian unless
the referenced existing endpoint format already defines a byte order.

### API Optimization Decisions

The public API uses these constraints to keep the surface stable:

- No heap ownership crosses the API.
- No API function stores caller pointers.
- No route owns or copies `ErAdmittedRoute`.
- No carrier-specific device object is hidden inside `ErNetworkRoute`.
- Carrier handles are passed through `ErNetworkIo` only for the send or poll
  call that uses them. `ErNetworkIo` is process-local state and has no wire
  representation.
- Route selection is pure: identical peer input and time input produce identical
  route output.
- Packet transmission receives the selected route and any required admission as
  separate arguments.
- Carrier-specific setup remains in the existing carrier modules.

## Public API

The public API is `er_network.h`. It coordinates existing modules and does not
replace them.

```c
UINT8 er_network_locator_prepare_native_eth(const UINT8 mac[ER_NET_MAC_LEN],
                                            UINT16 priority,
                                            UINT64 valid_until_ms,
                                            ErNetworkLocator* out_locator);

UINT8 er_network_locator_prepare_wifi_open(UINT32 group_id,
                                           UINT8 channel,
                                           const UINT8* ssid,
                                           UINT8 ssid_len,
                                           UINT16 priority,
                                           UINT64 valid_until_ms,
                                           ErNetworkLocator* out_locator);

UINT8 er_network_locator_prepare_firmware_udp(UINT8 a,
                                              UINT8 b,
                                              UINT8 c,
                                              UINT8 d,
                                              UINT16 port,
                                              UINT16 priority,
                                              UINT64 valid_until_ms,
                                              ErNetworkLocator* out_locator);

UINT8 er_network_locator_prepare_memory(UINT16 priority,
                                        UINT64 valid_until_ms,
                                        ErNetworkLocator* out_locator);

UINT8 er_network_locator_from_wifi_burst(const ErWifiBurstPlan* plan,
                                         UINT16 priority,
                                         UINT64 valid_until_ms,
                                         ErNetworkLocator* out_locator);

UINT8 er_network_locator_valid(const ErNetworkLocator* locator,
                               UINT64 now_ms);

UINT8 er_network_peer_prepare(const ErNodeId* node_id,
                              const ErNetworkLocator* locators,
                              UINT8 locator_count,
                              ErNetworkPeer* out_peer);

UINT8 er_network_peer_add_locator(ErNetworkPeer* peer,
                                  const ErNetworkLocator* locator);

UINT8 er_network_route_select(const ErNetworkPeer* peers,
                              UINT8 peer_count,
                              const ErNodeId* target_node_id,
                              UINT64 now_ms,
                              ErNetworkRoute* out_route);

UINT8 er_network_erwire_kind_requires_admission(UINT16 kind);

UINT8 er_network_send_erwire(ErNetworkIo* io,
                             const ErNetworkRoute* route,
                             const ErAdmittedRoute* admitted_route,
                             UINT16 kind,
                             UINT16 flags,
                             const UINT8* payload,
                             UINT32 payload_len);

UINT8 er_network_poll_erwire(ErNetworkIo* io,
                             const ErNetworkPeer* peers,
                             UINT8 peer_count,
                             UINT64 now_ms,
                             ErNetworkRoute* out_route,
                             ErwirePacketHeader* out_header,
                             UINT8* out_payload,
                             UINT32 out_capacity,
                             UINT32* out_payload_len);
```

All API functions return `1` for accepted input and completed local work. They
return `0` for null pointers, bad ABI version, invalid locator kind, invalid
length, expired locator, unsupported carrier, malformed packet, missing required
admission, or admission failure.

`er_network_send_erwire` MUST reject work packet kinds when
`admitted_route == 0`. It MUST ignore `admitted_route` for packet kinds that do
not require admission.

For `NATIVE_ETH` routes, `io->native_eth` MUST be non-null and already
initialized for the route's peer MAC. `er_network_send_erwire` MUST reject the
send if the selected locator MAC does not match the configured native Ethernet
peer.

For `FIRMWARE_UDP` routes, `io->firmware_udp` MUST be non-null and MUST match
the selected firmware UDP locator. Firmware UDP remains bootstrap-only.

`WIFI_OPEN` locator selection is valid before Wi-Fi L2 transmission is
implemented. `er_network_send_erwire` MUST reject `WIFI_OPEN` routes until a
runtime-owned Wi-Fi L2 carrier is added to `ErNetworkIo`.

## Route Selection

`er_network_route_select` MUST select exactly one locator or fail.

Selection order:

1. Ignore peers whose `node_id` does not match `target_node_id`.
2. Ignore locators with invalid ABI version, invalid kind, invalid directness,
   invalid address length, or `valid_until_ms <= now_ms`.
3. Prefer lower `directness` value after excluding `NONE`.
4. Prefer lower `cost_per_packet`.
5. Prefer lower `cost_per_byte`.
6. Prefer higher `priority`.
7. Prefer later `valid_until_ms`.
8. If still tied, prefer the earliest peer index, then earliest locator index.

This tie-break order keeps selection deterministic and testable.

## Carrier Behavior

### Native Ethernet

`NATIVE_ETH` routes use `erwire_set_native_eth_sink` and `er_native_eth`.
Frames MUST use EdgeRun EtherType `0x88b5`. The destination MAC is the locator
address. The MAC is not trusted beyond local delivery.

Inbound native Ethernet polling matches `io->native_eth->peer_mac` against
known `NATIVE_ETH` peer locators. If no matching non-expired peer locator
exists, polling MUST reject the packet after parsing it.

### Wi-Fi Open Burst

`WIFI_OPEN` routes are produced by `er_wifi_burst_plan_prepare` or by direct
locator preparation. The locator describes an open Wi-Fi carrier only. Payloads
remain sealed `erwire` bytes. The receiver MUST validate the work route before
relay or endpoint execution.

### Firmware UDP

`FIRMWARE_UDP` routes are bootstrap-only. They MUST be configured by
`er_boot_admission_record` or explicit caller input. The implementation MUST NOT
fall back to firmware UDP when another carrier fails.

Inbound firmware UDP polling matches the received endpoint against known
`FIRMWARE_UDP` peer locators. If no matching non-expired peer locator exists,
polling MUST reject the packet after parsing it.

### Memory

`MEMORY` routes are local-process or local-runtime routes. They MUST NOT be
advertised as remote reachability.

## State Ownership

The network coordinator owns no global peer table in this API. Callers own peer
arrays, I/O bindings, and admission records. The coordinator prepares locators,
prepares peers, selects routes, sends one packet, or polls one packet.

The only existing global state touched by this API is the current `erwire`
native Ethernet sink. Implementations of `er_network_send_erwire` MUST configure
that sink only for the duration of the send operation and MUST clear it before
returning.

## Presence Behavior

Presence creates locators. Presence does not carry work.

BLE role advertisements use `ErBleWifiRoleAdvert`. A valid local and remote
advertisement pair produces `ErWifiBurstPlan`. A burst plan with `open != 0`
produces a `WIFI_OPEN` locator through `er_network_locator_from_wifi_burst`.

The presence path MUST reject:

- invalid BLE role advertisements
- AP/STA role conflicts
- invalid Wi-Fi group id
- invalid channel
- SSID length greater than `ER_WIFI_BURST_SSID_BYTES`

## Admission Behavior

`er_network_erwire_kind_requires_admission` MUST return `1` for:

- `ERWIRE_KIND_CHANNEL_ENVELOPE`
- `ERWIRE_KIND_CAPABILITY_ENVELOPE`
- `ERWIRE_KIND_RELAY_TRANSIT_HOP`

It MUST return `0` for log, blob, PCI, bus, ACPI, app identity, app IPC route,
and VFS packet kinds.

`er_network_send_erwire` permits non-work packet kinds without an admitted
route. Packet kinds requiring admission MUST pass an `ErAdmittedRoute` with the
work ABI version, non-zero admitted budget, and a target node matching the
selected route.

Before accepting relay or endpoint work from a received packet, the consumer
MUST verify the corresponding channel envelope with
`er_work_verify_channel_envelope_for_route`. Relayed work MUST prepare transit
evidence with `er_work_prepare_relay_transit_hop` before an accounting claim is
created.

## Deployment Spec

For the container deployment, the outside OpenWrt device is a carrier extender,
not an authority root.

Required behavior:

- Linux nodes inside the container keep independent identities.
- The outside device improves radio placement and Ethernet reachability only as
  a carrier.
- Nodes select direct locators when available.
- Removing the outside device must not invalidate node identities or admitted
  work records.
- Removing one node must not require reconfiguring every other node.

## Tradeoffs

Benefits:

- Transport change does not change work authority.
- Kernel mesh modules are not required.
- Direct L2 works without DHCP, DNS, or IP routing.
- BLE discovers Wi-Fi burst opportunities without carrying work payloads.
- Multiple locators reduce single-controller dependence.

Costs:

- Userspace route selection has more latency than kernel bridging.
- Radio quality still depends on placement, antennas, power, and channel use.
- Locator ranking starts simple until runtime telemetry exists.
- Multi-hop relay requires strict admission and accounting.
- Open Wi-Fi burst links require sealed payloads and admission checks to be
  non-optional.

## Milestones

### M1: Specification

Acceptance:

- This file defines the canonical model.
- `README.md` links to this file.
- Existing `erwire`, native Ethernet, BLE advertisement, Wi-Fi burst, and work
  route tests remain passing.

### M2: Coordinator API

Acceptance:

- `er_network.h` exists.
- Locator, peer, route, and I/O structs match this spec.
- Native Ethernet and Wi-Fi-open locator preparation are implemented.
- Tests cover invalid ABI version, invalid kind, invalid length, expiry,
  deterministic route selection, tie-breaking, locator validation, and peer
  locator insertion.

### M3: Erwire Carrier Integration

Acceptance:

- `er_network_send_erwire` sends through selected native Ethernet routes.
- `er_network_poll_erwire` accepts only valid `erwire` packets.
- Work packet kind admission requirements are enforced by
  `er_network_erwire_kind_requires_admission`.
- Firmware UDP is used only when explicitly selected.
- Tests prove the same `erwire` packet bytes are carried through the selected
  carrier.

### M4: Presence Inputs

Acceptance:

- `ErWifiBurstPlan` converts to `WIFI_OPEN` locator.
- BLE AP/STA agreement creates a temporary Wi-Fi-open locator.
- BLE conflicts and invalid burst plans fail closed.

### M5: Admission-Gated Work

Acceptance:

- Relay, endpoint, capability, and channel work packet kinds require a non-null
  admitted route at send time.
- Tests cover channel envelope verification, transit hop preparation, and
  accounting claim preparation for relayed packets.

### M6: Linux Deployment Adapter

Acceptance:

- A host-side tool or daemon publishes locators and carries `erwire` packets.
- Linux Wi-Fi, Bluetooth, and Ethernet APIs stay adapters only.
- Protocol authority remains in `edgerun-c` records.
- A three-node test with the outside OpenWrt carrier exercises direct path,
  carrier loss, and recovery.

### M7: Multi-Hop And Store-Forward

Acceptance:

- Multi-hop selection uses admitted relay cost.
- Store-forward locators require expiry, storage budget, and receipt behavior.
- Tests cover node removal, node movement, relay failure, and direct-path
  recovery.

## Non-Goals

- No Rust mesh packet format is ported into C.
- No dependency on `batman-adv`.
- No dependency on DHCP, DNS, or IP routing for native EdgeRun traffic.
- No central OpenWrt authority.
- No general-purpose control protocol beside `erwire`.
- No mandatory BLE.
- No identity derived from MAC addresses, SSIDs, IP addresses, or routers.

# Device Beacon, Link Handshake & Route Announcement Spec

This document specifies the device-to-device discovery and routing protocol.
It is the missing piece between Tor's cell format (which we use verbatim)
and the identity-based OS networking model.

## Principles

1. **Cell format is Tor-compatible** at 514 bytes: CircID[4] + Command[1] + Body[509].
   All existing Tor relays forward our cells as normal RELAY/RELAY_EARLY cells.
2. **Devices discover each other on local links** via beacon frames.
   No IP, no DHCP, no DNS at this layer.
3. **Devices announce routes** for identities they can reach (their own apps,
   their neighbors' apps, recursively).
4. **Routes propagate** through the network like a distance-vector protocol.
5. **The wire is irrelevant** — ethernet, WiFi, Bluetooth, serial, email.
   Cell is the universal envelope.

---

## 1. Device Identity

Each device has a persistent Ed25519 keypair (`KP_device_id`, `KS_device_id`)
provisioned at manufacture or first boot (TPM-backed).

Device ID = `H(KP_device_id)` (32 bytes, SHA3-256 of public key).

The device ID is the only identifier used in routing.
No MAC address, no IP address in the routing plane.

---

## 2. Device Beacon (Local Link Discovery)

Sent periodically (every 5-30 seconds) on all active local links.
The beacon is a raw frame — no IP, no TLS, no cell encapsulation.
On ethernet, use an unregistered ethertype `0x0B1D` (Tor-related).
On Bluetooth, use an advertisement payload.
On serial, send as a raw datagram.

### Beacon Frame Format

For raw ethernet:

```
Offset  Size  Field
0       6     Destination MAC  (broadcast FF:FF:FF:FF:FF:FF)
6       6     Source MAC
12      2     Ethertype  (0x0B1D)
14      1     Frame version  (currently 0x01)
15      4     Beacon sequence number  (big-endian, incrementing)
19      32    Device ID  (SHA3-256 of Ed25519 public key)
51      32    Device Ed25519 public key  (KP_device_id)
83      4     Supported link protocols bitfield
87      4     Current route table hash  (CRC32 of serialized route table)
91      1     Hop count to internet exit  (255 = no exit known)
92      4     Signal strength or link quality  (0 = unknown)
96      1     Flags:
              bit 0:  has_exit_capability (can reach legacy IP)
              bit 1:  is_da (runs Directory Authority)
              bit 2:  accepts_circuits (can forward cells)
              bit 3:  is_gateway (connected to internet)
              bit 4-7: reserved
97      1     TTL  (starting at 3, decremented by each relay)
98      18    Reserved (zero-filled)
---     128 bytes total (fits in minimal Ethernet payload)
```

Total: 128 bytes including Ethernet header. Leaves room in a standard MTU.

### Receiving Beacons

When a device receives a beacon from a new device ID:
1. Add/update neighbor table entry: `[device_id, mac, public_key, seq, routes_hash, flags, last_seen, link_quality]`
2. If `routes_hash` differs from cached value, request route table delta
3. If the beacon indicates `is_da`, establish a DA-to-DA link for route exchange
4. If `has_exit_capability` and we have no exit route, note this as an exit path

When a beacon from a known device ID is received:
1. Update `last_seen`
2. If `seq` wraps or jumps unexpectedly, possibly re-request routes

If no beacon received from a neighbor within 3× the beacon interval,
mark the neighbor as `stale`. After 10× the interval, remove.

---

## 3. Link Handshake (Direct Device-to-Device Channel)

Before exchanging route announcements or user data, two devices
establish an encrypted channel. This replaces Tor's CERTS/AUTH/TLS.

### Handshake Sequence

```
Initiator                    Responder
    |                            |
    |------- VERSIONS (cmd 7) -->|    negotiate link protocol (Tor compat)
    |<------ VERSIONS -----------|
    |                            |
    |--- AUTH_CHALLENGE (cmd) -->|    send 32-byte random challenge
    |<-- AUTH_CHALLENGE ---------|
    |                            |
    |--- AUTHENTICATE (cmd) ---->|    sign(challenge | responder_id, KS_device_id)
    |<-- AUTHENTICATE -----------|    sign(challenge | initiator_id, KS_device_id)
    |                            |
    |--- BEACON_SYNC (cmd) ----->|    route table hash
    |<-- BEACON_SYNC ------------|    route table hash
    |                            |
    |--- ROUTE_DELTA (cmd) ----->|    new/adjusted routes
    |<-- ROUTE_DELTA ------------|    new/adjusted routes
    |                            |
    Channel open for cells       |
```

### New Cell Commands (Variable-length, ≥128)

We define new variable-length cell commands for the link-level protocol:

| Value | Identifier | Description |
|---|---|---|
| 133 | `AUTH_CHALLENGE` | 32-byte random challenge |
| 134 | `AUTHENTICATE` | Signed challenge response |
| 135 | `BEACON_SYNC` | Route table hash sync |
| 136 | `ROUTE_DELTA` | Route table update |
| 137 | `ROUTE_REQUEST` | Request full route table |

### AUTH_CHALLENGE Cell Body
```
Challenge [32 bytes]
```

### AUTHENTICATE Cell Body
```
InitiatorID     [32 bytes]  SHA3-256(initiator KP_device_id)
ResponderID     [32 bytes]  SHA3-256(responder KP_device_id)
Challenge       [32 bytes]  Echo of the challenge received
Signature       [64 bytes]  Ed25519 sign(KS_device_id, all previous fields)
```

Both sides verify that the signature matches the expected device ID's public key.

### BEACON_SYNC Cell Body
```
RouteTableHash  [4 bytes]   CRC32 of device's full route table
```

### ROUTE_REQUEST Cell Body
```
RequestAll      [1 byte]    0x01 = request full table
```

### ROUTE_DELTA Cell Body
```
NumRoutes       [2 bytes]   Number of route entries in this delta
  For each route:
    IdentityID    [32 bytes]  Destination identity (app, user, or device)
    NextHopID     [32 bytes]  Next hop device ID (or all-zero for local)
    Cost          [2 bytes]   Hop count (0 = local, 1 = neighbor, etc.)
    Expiry        [4 bytes]   Unix timestamp (0 = no expiry)
    PrefixLen     [1 byte]    Number of significant bytes in identity (32 = exact)
    Flags         [1 byte]    bit 0: is_exit_route
                              bit 1: is_device_route
                              bit 2: is_app_route
                              bit 3: is_user_route
                              bit 4: is_default_route
                              bits 5-7: reserved
```

### Encryption Key Derivation

After authentication, both sides derive a shared link encryption key:
```
shared_secret = X25519(KS_ephemeral, KP_neighbor_ephemeral)
link_key = HKDF_SHA256(shared_secret | initiator_id | responder_id, "tor-device-link-v1")
```

All subsequent cells (BEACON_SYNC, ROUTE_DELTA, and DATA cells)
are encrypted with this key using AES-256-CTR.

---

## 4. Route Table

Each device maintains a route table with fixed maximum entries (e.g., 1024).

### Entry Format (internal representation)
```
identity      [32 bytes]  Destination identity hash
next_hop      [32 bytes]  Device ID to forward to (zero = local)
cost          [2 bytes]   Hop count
expiry        [4 bytes]   Unix timestamp when route expires (0 = permanent)
flags         [1 byte]    See ROUTE_DELTA flags
source        [1 byte]    0 = local, 1 = beacon, 2 = DA sync, 3 = static config
last_used     [4 bytes]   Timestamp of last route lookup hit
```

### Route Types

| Type | Cost | Description |
|---|---|---|
| Local process | 0 | Process on this device |
| Local device | 0 | This device's own identity |
| Neighbor device | 1 | Directly connected device |
| Neighbor's app | 2 | App on a directly connected device |
| Remote (2 hops) | 3+ | Reachable through neighbor's neighbor |
| Internet exit | varies | Path to a device with legacy IP bridging |

### Default Route

A device without an exit path does not know how to reach identities
outside its local network. The exit path is learned via beacons from
gateway devices that announce `is_gateway`.

---

## 5. Route Propagation Rules

### Local Routes (Cost 0)
- When a process calls `register_handler(id)`, the device creates
  a route entry: `id → cost=0, next_hop=zero`.
- The device includes this route in its next beacon's `routes_hash`.
- On BEACON_SYNC, the device sends a ROUTE_DELTA for this identity.

### Neighbor Routes (Cost 1)
- When a beacon is received from a new device, create a route:
  `device_id → cost=1, next_hop=device_id`.
- If the neighbor announces routes for identities, create routes:
  `identity → cost=neighbor_cost+1, next_hop=device_id`.

### Route Advertisement
- A device advertises its entire route table (via BEACON_SYNC + ROUTE_DELTA)
  to each authenticated neighbor.
- Advertised routes have their cost incremented by 1 before comparison.
- If the neighbor already has a cheaper route to the same identity,
  it ignores the announcement.
- If the neighbor has a more expensive route, it replaces it and
  propagates to its own neighbors (split horizon: don't re-advertise
  to the device that gave you the route).

### Split Horizon
- Route learned from device X is NOT re-advertised to device X.
- All other neighbors get the route.

### Route Expiry
- Routes from beacons expire after 3 missed beacon intervals.
- Routes from DA sync have the expiry set by the DA.
- Local routes never expire.

### Route Conflict Resolution
- Lower cost wins.
- Same cost: lower device ID (lexicographic) wins.
- If next_hop becomes unreachable (stale), all routes through it
  are invalidated.

---

## 6. Internet Routing via Tor Network

For reachability beyond the local mesh, devices use the existing Tor network
as a transport backbone.

### Bootstrapping
1. Device discovers a Tor relay on the local network (or via hardcoded fallback).
2. Device establishes a Tor circuit to a well-known directory/rendezvous point.
3. Device registers its DA's identity with the Tor network (like a hidden service).
4. Remote devices find the device via Tor's HSDir mechanism.

### Cell-in-Cell Encapsulation
- The identity-addressed cell is placed inside a Tor RELAY cell:
  ```
  Tor RELAY cell (514 bytes):
    CircID [4] | Command=3 [1] | Body [509]
      Body contains:
        Tor Relay Header [11]:  cmd | recognized | streamID | digest | len
        Payload [498]:
          Inner cell (our protocol):
            IdentityDest [32] | IdentitySrc [32] | AppPayload [434]
  ```
- The Tor network sees standard RELAY cells and forwards them normally.
- Only the exit bridge or the destination device decrypts the inner payload.

### Tor as Transport
- The device's DA speaks Tor's HS protocol to publish its presence.
- Remote devices resolve identities via Tor's .onion addressing.
- The exit bridge translates identity-addressed cells to/from IP when
  connecting to legacy hosts.

### No Changes to Tor Protocol
- Existing Tor relays see standard cells.
- No new Tor cell commands needed.
- The identity layer is entirely in the payload.

---

## 7. Beacon over Non-Ethernet Links

### Bluetooth (LE Advertising)
```
AD Structure:
  Length  [1 byte]  30 (total following bytes)
  Type    [1 byte]  0xFF (Manufacturer Specific)
  Company [2 bytes] 0x0B1D (Tor Project)
  Data:
    Version     [1]   0x01
    DeviceID    [32]  SHA3-256(KP_device_id)
    PubKeyHash  [4]   CRC32(KP_device_id)
    Seq         [4]   beacon sequence
    Flags       [1]   same as ethernet beacon
    Remaining   [6]   zero-filled
```

Maximum Bluetooth LE advertisement payload is 31 bytes.
The full device ID (32 bytes) alone exceeds this — so BT beacons
send a hash prefix and the full ID is exchanged after connection.

### WiFi (802.11 Probe Request / Vendor-Specific IE)
```
Vendor-Specific Information Element:
  Element ID  [1]  0xDD (vendor specific)
  Length      [1]  39
  OUI         [3]  0x0B1D00 (Tor Project)
  Type        [1]  0x01
  DeviceID    [32] SHA3-256(KP_device_id)
  Seq         [2]  beacon sequence
```

### Serial / LoRa / Other Low-Bandwidth
Send beacon at negotiated interval; full format only when link quality allows.
Minimum: `DeviceID[32] + Seq[2] + CRC[2]` = 36 bytes.

---

## 8. Address Mapping for Media Access

Since we use device IDs (not MAC addresses) for routing, the kernel needs
a mapping from device ID to link-layer address for each medium.

```
neighbor_table_entry:
  device_id     [32 bytes]  SHA3-256(KP_device_id)
  link_addr     [6-32 var]  MAC, BT address, serial path, etc.
  link_type     [1 byte]    0 = ethernet, 1 = WiFi, 2 = BT, 3 = serial, 4 = loopback
  last_beacon   [4 bytes]   timestamp
  link_key      [32 bytes]  AES-256 key for this link
  state         [1 byte]    0 = discovered, 1 = authenticated, 2 = active
```

The neighbor table is consulted when the routing table yields a next_hop device ID.
The link_addr is filled in from the beacon frame's source address.

---

## 9. Beacon Sequence Numbers & Replay

Beacon `seq` is a monotonically increasing counter. Devices receiving
a beacon with `seq <= last_seq` for a given device ID SHOULD ignore it
(except to update link quality). On reboot, the seq resets; if a device
receives a seq far below the last known value, it SHOULD re-authenticate.

---

## 10. Implementation Considerations

- **Fixed allocation**: neighbor table, route table, circuit table all have
  compile-time maximum sizes.
- **No dynamic memory** in the beacon/route path.
- **Route table sorting**: routes should be sorted by cost for fast lookup.
- **Beacon noise**: in dense networks, randomize beacon timing to avoid
  synchronization (each device picks a random offset in the interval).
- **DA synchronization**: when a DA is present, it acts as the authoritative
  route distributor. Non-DA devices only advertise local routes (cost 0-1)
  and rely on the DA for wider routing.

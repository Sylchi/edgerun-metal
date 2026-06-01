# 14 Proof Of Work

The overall denial-of-service prevention strategies in Tor are described in the Denial-of-service prevention mechanisms in Tor document. This document describes one specific mitigation, the proof-of-work client puzzle for onion service introduction.

This was originally proposal 327, A First Take at PoW Over Introduction Circuits authored by George Kadianakis, Mike Perry, David Goulet, and tevador.

# Common protocol

We have made an effort to split the design of the proof-of-work subsystem into an algorithm-specific piece that can be upgraded, and a core protocol that provides queueing and effort adjustment.

Currently there is only one versioned subprotocol defined:

  * Version 1, Equi-X and Blake2b

## Overview
[code]
                                              +----------------------------------+
                                              |          Onion Service           |
       +-------+ INTRO1  +-----------+ INTRO2 +--------+                         |
       |Client |-------->|Intro Point|------->|  PoW   |-----------+             |
       +-------+         +-----------+        |Verifier|           |             |
                                              +--------+           |             |
                                              |                    |             |
                                              |                    |             |
                                              |         +----------v---------+   |
                                              |         |Intro Priority Queue|   |
                                              +---------+--------------------+---+
                                                               |  |  |
                                                    Rendezvous |  |  |
                                                      circuits |  |  |
                                                               v  v  v

[/code]

The proof-of-work scheme specified in this document takes place during the introduction phase of the onion service protocol.

The system described in this proposal is not meant to be on all the time, and it can be entirely disabled for services that do not experience DoS attacks.

When the subsystem is enabled, suggested effort is continuously adjusted and the computational puzzle can be bypassed entirely when the effort reaches zero. In these cases, the proof-of-work subsystem can be dormant but still provide the necessary parameters for clients to voluntarily provide effort in order to get better placement in the priority queue.

The protocol involves the following major steps:

  1. Service encodes PoW parameters in descriptor: `pow-params` in the second layer plaintext format.
  2. Client fetches descriptor and begins solving. Currently this must use the `v1` solver algorithm.
  3. Client finishes solving and sends results using the proof-of-work extension to INTRODUCE1.
  4. Service verifies the proof and queues an introduction based on proven effort. This currently uses the `v1` verify algorithm only.
  5. Requests are continuously drained from the queue, highest effort first, subject to multiple constraints on speed. See below for more on handling queued requests.

## Replay protection

The service MUST NOT accept introduction requests with the same (seed, nonce) tuple. For this reason a replay protection mechanism must be employed.

The simplest way is to use a hash table to check whether a (seed, nonce) tuple has been used before for the active duration of a seed. Depending on how long a seed stays active this might be a viable solution with reasonable memory/time overhead.

If there is a worry that we might get too many introductions during the lifetime of a seed, we can use a Bloom filter or similar as our replay cache mechanism. A probabilistic filter means that we will potentially flag some connections as replays even if they are not, with this false positive probability increasing as the number of entries increase. With the right parameter tuning this probability should be negligible, and dropped requests will be retried by the client.

## The introduction queue

When proof-of-work is enabled for a service, that service diverts all incoming introduction requests to a priority queue system rather than handling them immediately.

### Adding introductions to the introduction queue

When PoW is enabled and an introduction request includes a verified proof, the service queues each request in a data structure sorted by effort. Requests including no proof at all MUST be assigned an effort of zero. Requests with a proof that fails to verify MUST be rejected and not enqueued.

Services MUST check whether the queue is overfull when adding to it, not just when processing requests. Floods of low-effort and zero-effort introductions need to be efficiently discarded when the queue is growing faster than it’s draining.

The C implementation chooses a maximum number of queued items based on its configured dequeue rate limit multiplied by the circuit timeout. In effect, items past this threshold are expected not to be reachable by the time they will timeout. When this limit is exceeded, the queue experiences a mass trim event where the lowest effort half of all items are discarded.

### Handling queued introductions

When deciding which introduction request to consider next, the service chooses the highest available effort. When efforts are equivalent, the oldest queued request is chosen.

The service should handle introductions only by pulling from the introduction queue. We call this part of introduction handling the “bottom half” because most of the computation happens in this stage.

For more on how we expect such a system to work in Tor, see the scheduler analysis and discussion section.

## Effort control

### Overall strategy for effort determination

Denial-of-service is a dynamic problem where the attacker’s capabilities constantly change, and hence we want our proof-of-work system to be dynamic and not stuck with a static difficulty setting. Instead of forcing clients to go below a static target configured by the service operator, we ask clients to “bid” using their PoW effort. Effectively, a client gets higher priority the higher effort they put into their proof-of-work. Clients automatically increase their bid when retrying, and services regularly offer a suggested starting point based on the recent queue status.

Motivated users can spend a high amount of effort in their PoW computation, which should guarantee access to the service given reasonable adversary models.

An effective effort control algorithm will improve reachability and UX by suggesting values that reduce overall service load to tolerable values while also leaving users with a tolerable overall delay.

The service starts with a default suggested-effort value of 0, which keeps the PoW defenses dormant until we notice signs of queue overload.

The entire process of determining effort can be thought of as a set of multiple coupled feedback loops. Clients perform their own effort adjustments via timeout retry atop a base effort suggested by the service. That suggestion incorporates the service’s control adjustments atop a base effort calculated using a sum of currently-queued client effort.

Each feedback loop has an opportunity to cover different time scales. Clients can make adjustments at every single circuit creation request, whereas services are limited by the extra load that frequent updates would place on HSDir nodes.

In the combined client/service system these client-side increases are expected to provide the most effective quick response to an emerging DoS attack. After early clients increase the effort using timeouts, later clients benefit from the service detecting this increased queued effort and publishing a larger suggested effort.

Effort increases and decreases both have a cost. Increasing effort will make the service more expensive to contact, and decreasing effort makes new requests likely to become backlogged behind older requests. The steady state condition is preferable to either of these side-effects, but ultimately it’s expected that the control loop always oscillates to some degree.

### Service-side effort control

Services keep an internal suggested effort target which updates on a regular periodic timer in response to measurements made on queue behavior in the previous update period. These internal effort changes can optionally trigger client-visible descriptor changes when the difference is great enough to warrant republication to the HSDir.

This evaluation and update period is referred to as `HS_UPDATE_PERIOD`. The service-side effort control loop takes inspiration from TCP congestion control’s additive increase / multiplicative decrease approach, but unlike a typical AIMD this algorithm is fixed-rate and doesn’t update immediately in response to events.

TODO: `HS_UPDATE_PERIOD` is hardcoded to 300 (5 minutes) currently, but it should be configurable in some way. Is it more appropriate to use the service’s torrc here or a consensus parameter?

#### Per-update-period service state

During each update period, the service maintains some state:

  1. `TOTAL_EFFORT`, a sum of all effort values for rendezvous requests that were successfully validated and enqueued.
  2. `REND_HANDLED`, a count of rendezvous requests that were actually launched. Requests that made it to dequeueing but were too old to launch by then are not included.
  3. `HAD_QUEUE`, a flag which is set if at any time in the update period we saw the priority queue filled with more than a minimum amount of work, greater than we would expect to process in approximately 1/4 second using the configured dequeue rate.
  4. `MAX_TRIMMED_EFFORT`, the largest observed single request effort that we discarded during the update period. Requests are discarded either due to age (timeout) or during culling events that discard the bottom half of the entire queue when it’s too full.

#### Service AIMD conditions

At the end of each update period, the service may decide to increase effort, decrease effort, or make no changes, based on these accumulated state values:

  1. If `MAX_TRIMMED_EFFORT` > our previous internal `suggested_effort`, always INCREASE. Requests that follow our latest advice are being dropped.
  2. If the `HAD_QUEUE` flag was set and the queue still contains at least one item with effort >= our previous internal `suggested_effort`, INCREASE. Even if we haven’t yet reached the point of dropping requests, this signal indicates that our latest suggestion isn’t high enough and requests will build up in the queue.
  3. If neither condition 1 or 2 are taking place and the queue is below a level we would expect to process in approximately 1/4 second, choose to DECREASE.
  4. If none of these conditions match, the `suggested_effort` is unchanged.

When we INCREASE, the internal `suggested_effort` is increased to either its previous value + 1, or (`TOTAL_EFFORT` / `REND_HANDLED`), whichever is larger.

When we DECREASE, the internal `suggested_effort` is scaled by 2/3rds.

Over time, this will continue to decrease our effort suggestion any time the service is fully processing its request queue. If the queue stays empty, the effort suggestion decreases to zero and clients should no longer submit a proof-of-work solution with their first connection attempt.

It’s worth noting that the `suggested_effort` is not a hard limit to the efforts that are accepted by the service, and it’s only meant to serve as a guideline for clients to reduce the number of unsuccessful requests that get to the service. When adding requests to the queue, services do accept valid solutions with efforts higher or lower than the published values from `pow-params`.

#### Updating descriptor with new suggested effort

The service descriptors may be updated for multiple reasons including introduction point rotation common to all v3 onion services, scheduled seed rotations like the one described for `v1` parameters, and updates to the effort suggestion. Even though the internal effort value updates on a regular timer, we avoid propagating those changes into the descriptor and the HSDir hosts unless there is a significant change.

If the PoW params otherwise match but the seed has changed by less than 15 percent, services SHOULD NOT upload a new descriptor.

### Client-side effort control

Clients are responsible for making their own effort adjustments in response to connection trouble, to allow the system a chance to react before the service has published new effort values. This is an important tool to uphold UX expectations without relying on excessively frequent updates through the HSDir.

TODO: This is the weak link in user experience for our current implementation. The C tor implementation does not detect and retry onion service connections as reliably as we would like. Currently our best strategy to improve retry behavior is the Arti rewrite.

#### Failure ambiguity

The first challenge in reacting to failure, in our case, is to even accurately and quickly understand when a failure has occurred.

This proposal introduces a bunch of new ways where a legitimate client can fail to reach the onion service. Furthermore, there is currently no end-to-end way for the onion service to inform the client that the introduction failed. The INTRODUCE_ACK message is not end-to-end (it’s from the introduction point to the client) and hence it does not allow the service to inform the client that the rendezvous is never gonna occur.

From the client’s perspective there’s no way to attribute this failure to the service itself rather than the introduction point, so error accounting is performed separately for each introduction-point. Prior mechanisms will discard an introduction point that’s required too many retries.

#### Clients handling timeouts

Alice can fail to reach the onion service if her introduction request gets trimmed off the priority queue when enqueueing new requests, or if the service does not get through its priority queue in time and the connection times out.

This section presents a heuristic method for the client getting service even in such scenarios.

If the rendezvous request times out, the client SHOULD fetch a new descriptor for the service to make sure that it’s using the right suggested-effort for the PoW and the right PoW seed. If the fetched descriptor includes a new suggested effort or seed, it should first retry the request with these parameters.

TODO: This is not actually implemented yet, but we should do it. How often should clients at most try to fetch new descriptors? Determined by a consensus parameter? This change will also allow clients to retry effectively in cases where the service has just been reconfigured to enable PoW defenses.

Every time the client retries the connection, it will count these failures per-introduction-point. These counts of previous retries are combined with the service’s `suggested_effort` when calculating the actual effort to spend on any individual request to a service that advertises PoW support, even when the currently advertised `suggested_effort` is zero.

On each retry, the client modifies its solver effort:

  1. If the effort is below `CLIENT_POW_EFFORT_DOUBLE_UNTIL` (= 1000) it will be doubled.
  2. Otherwise, multiply the effort by `CLIENT_POW_RETRY_MULTIPLIER` (= 1.5).
  3. Constrain the effort to no less than `CLIENT_MIN_RETRY_POW_EFFORT` (= 8). Note that this limit is specific to retries only. Clients may use a lower effort for their first connection attempt.
  4. Apply the maximum effort limit described below.

#### Client-imposed effort limits

There isn’t a practical upper limit on effort defined by the protocol itself, but clients may choose a maximum effort limit to enforce. It may be desirable to do this in some cases to improve responsiveness, but the main reason for this limit currently is as a workaround for weak cancellation support in our implementation.

Effort values used for both initial connections and retries are currently limited to no greater than `CLIENT_MAX_POW_EFFORT` (= 10000).

TODO: This hardcoded limit should be replaced by timed limits and/or an unlimited solver with robust cancellation. This is issue 40787 in C tor.

## Motivation

See the denial-of-service overview for the big-picture view. Here we are focusing on a mitigation for attacks on one specific resource: onion service introductions.

Attackers can generate low-effort floods of introductions which cause the onion service and all involved relays to perform a disproportionate amount of work, leading to a denial-of-service opportunity. This proof-of-work scheme intends to make introduction floods unattractive to attackers, reducing the network-wide impact of this activity.

Previous to this work, our attempts at limiting the impact of introduction flooding DoS attacks on onion services has been focused on horizontal scaling with Onionbalance, optimizing the CPU usage of Tor and applying rate limiting. While these measures move the goalpost forward, a core problem with onion service DoS is that building rendezvous circuits is a costly procedure both for the service and for the network.

For more information on the limitations of rate-limiting when defending against DDoS, see `draft-nygren-tls-client-puzzles-02`.

If we ever hope to have truly reachable global onion services, we need to make it harder for attackers to overload the service with introduction requests. This proposal achieves this by allowing onion services to specify an optional dynamic proof-of-work scheme that its clients need to participate in if they want to get served.

With the right parameters, this proof-of-work scheme acts as a gatekeeper to block amplification attacks by attackers while letting legitimate clients through.

## Related work

For a similar concept, see the three internet drafts that have been proposed for defending against TLS-based DDoS attacks using client puzzles:

  * `draft-nygren-tls-client-puzzles-02`
  * `draft-nir-tls-puzzles-00`
  * `draft-ietf-ipsecme-ddos-protection-10`

## Threat model

### Attacker profiles

This mitigation is written to thwart specific attackers. The current protocol is not intended to defend against all and every DoS attack on the Internet, but there are adversary models we can defend against.

Let’s start with some adversary profiles:

  * “The script-kiddie”

The script-kiddie has a single computer and pushes it to its limits. Perhaps it also has a VPS and a pwned server. We are talking about an attacker with total access to 10 GHz of CPU and 10 GB of RAM. We consider the total cost for this attacker to be zero $.

  * “The small botnet”

The small botnet is a bunch of computers lined up to do an introduction flooding attack. Assuming 500 medium-range computers, we are talking about an attacker with total access to 10 THz of CPU and 10 TB of RAM. We consider the upfront cost for this attacker to be about $400.

  * “The large botnet”

The large botnet is a serious operation with many thousands of computers organized to do this attack. Assuming 100k medium-range computers, we are talking about an attacker with total access to 200 THz of CPU and 200 TB of RAM. The upfront cost for this attacker is about $36k.

We hope that this proposal can help us defend against the script-kiddie attacker and small botnets. To defend against a large botnet we would need more tools at our disposal (see the discussion on future designs).

### User profiles

We have attackers and we have users. Here are a few user profiles:

  * “The standard web user”

This is a standard laptop/desktop user who is trying to browse the web. They don’t know how these defences work and they don’t care to configure or tweak them. If the site doesn’t load, they are gonna close their browser and be sad at Tor. They run a 2GHz computer with 4GB of RAM.

  * “The motivated user”

This is a user that really wants to reach their destination. They don’t care about the journey; they just want to get there. They know what’s going on; they are willing to make their computer do expensive multi-minute PoW computations to get where they want to be.

  * “The mobile user”

This is a motivated user on a mobile phone. Even tho they want to read the news article, they don’t have much leeway on stressing their machine to do more computation.

We hope that this proposal will allow the motivated user to always connect where they want to connect to, and also give more chances to the other user groups to reach the destination.

### The DoS Catch-22

This proposal is not perfect and it does not cover all the use cases. Still, we think that by covering some use cases and giving reachability to the people who really need it, we will severely demotivate the attackers from continuing the DoS attacks and hence stop the DoS threat all together. Furthermore, by increasing the cost to launch a DoS attack, a big class of DoS attackers will disappear from the map, since the expected ROI will decrease.

## Version 1, Equi-X and Blake2b

# Onion service proof-of-work: Scheme v1, Equi-X and Blake2b

## Implementations

For our `v1` proof-of-work function we use the Equi-X asymmetric client puzzle algorithm by tevador. The concept and the C implementation were developed specifically for our use case by tevador, based on a survey of existing work and an analysis of Tor’s requirements.

  * Original Equi-X source repository
  * Development log

Equi-X is an asymmetric PoW function based on Equihash<60,3>, using HashX as the underlying layer. It features lightning fast verification speed, and also aims to minimize the asymmetry between CPU and GPU. Furthermore, it’s designed for this particular use-case and hence cryptocurrency miners are not incentivized to make optimized ASICs for it.

At this point there is no formal specification for Equi-X or the underlying HashX function. We have two actively maintained implementations of both components, which we subject to automated cross-compatibility and fuzz testing:

  * A fork of tevador’s implementation is maintained within the C tor repository.

This is the `src/ext/equix` subdirectory. Currently this contains important fixes for security, portability, and testability which have not been merged upstream! This implementation is released under the LGPL license. When `tor` is built with the required `--enable-gpl` option this code will be statically linked.

  * As part of Arti, a new Rust re-implementation was written based loosely on tevador’s original.

This is the `equix` crate. This implementation currently has somewhat lower verification performance than the original but otherwise offers equivalent features.

## Algorithm overview

The overall scheme consists of several layers that provide different pieces of this functionality:

  1. At the lowest layers, Blake2b and siphash are used as hashing and PRNG algorithms that are well suited to common 64-bit CPUs.
  2. A custom hash function family, HashX, randomizes its implementation for each new seed value. These functions are tuned to utilize the pipelined integer performance on a modern 64-bit CPU. This layer provides the strongest ASIC resistance, since a hardware reimplementation would need to include a CPU-like pipelined execution unit to keep up.
  3. The Equi-X layer itself builds on HashX and adds an algorithmic puzzle that’s designed to be strongly asymmetric and to require RAM to solve efficiently.
  4. The PoW protocol itself builds on this Equi-X function with a particular construction of the challenge input and particular constraints on the allowed Blake2b hash of the solution. This layer provides a linearly adjustable effort that we can verify.
  5. At this point, all further layers are part of the common protocol. Above the level of individual PoW handshakes, the client and service form a closed-loop system that adjusts the effort of future handshakes.

Equi-X itself provides two functions that will be used in this proposal:

  * `equix_solve`(`challenge`) which solves a puzzle instance, returning a variable number of solutions per invocation depending on the specific challenge value.
  * `equix_verify`(`challenge`, `solution`) which verifies a puzzle solution quickly. Verification still depends on executing the HashX function, but far fewer times than when searching for a solution.

For the purposes of this proposal, all cryptographic algorithms are assumed to produce and consume byte strings, even if internally they operate on some other data type like 64-bit words. This is conventionally little endian order for Blake2b, which contrasts with Tor’s typical use of big endian. HashX itself is configured with an 8-byte output but its input is a single 64-bit word of undefined byte order, of which only the low 16 bits are used by Equi-X in its solution output. We treat Equi-X solution arrays as byte arrays using their packed little endian 16-bit representation.

## Linear effort adjustment

The underlying Equi-X puzzle has an approximately fixed computational cost. Adjustable effort comes from the construction of the overlying Blake2b layer, which requires clients to test a variable number of Equi-X solutions in order to find answers which also satisfy this layer’s effort constraint.

It’s common for proof-of-work systems to define an exponential effort function based on a particular number of leading zero bits or equivalent. For the benefit of our effort control system, it’s quite useful if we have a linear scale instead. We use the first 32 bits of a hashed version of the Equi-X solution as a uniformly distributed random value.

Conceptually we could define a function:
[code]
    unsigned effort(uint8_t *token)

[/code]

which takes as its argument a hashed solution, interprets it as a bitstring, and returns the quotient of dividing a bitstring of 1s by it.

So for example:
[code]
    effort(00000001100010101101) = 11111111111111111111
                                     / 00000001100010101101

[/code]

or the same in decimal:
[code]
    effort(6317) = 1048575 / 6317 = 165.

[/code]

In practice we can avoid even having to perform this division, performing just one multiply instead to see if a request’s claimed effort is supported by the smallness of the resulting 32-bit hash prefix. This assumes we send the desired effort explicitly as part of each PoW solution. We do want to force clients to pick a specific effort before looking for a solution, otherwise a client could opportunistically claim a very large effort any time a lucky hash prefix comes up. Thus the effort is communicated explicitly in our protocol, and it forms part of the concatenated Equi-X challenge.

## Parameter descriptor

This whole protocol starts with the service encoding its parameters in a `pow-params` line within the ‘encrypted’ (inner) part of the v3 descriptor. The second layer plaintext format describes it canonically. The parameters offered are:

  * `scheme`, always `v1` for the algorithm described here
  * `seed-b64`, a periodically updated 32-byte random seed, base64 encoded
  * `suggested-effort`, the latest output from the service-side effort controller
  * `expiration-time`, a timestamp when we plan to replace the seed.

Seed expiration and rotation allows used nonces to expire from the anti-replay memory. At every seed rotation, a new expiration time is chosen uniformly at random from the recommended range:

  * At the earliest, 105 minutes in the future
  * At the latest, 2 hours in the future (15 minutes later)

The service SHOULD refresh its seed when expiration-time passes. The service SHOULD keep its previous seed in memory and accept PoWs using it to avoid race-conditions with clients that have an old seed. The service SHOULD avoid generating two consequent seeds that have a common 4 bytes prefix; see the usage of seed headings below in the introduction extension.

## Client computes a solution

If a client receives a descriptor with `pow-params`, it should assume that the service is prepared to receive PoW solutions as part of the introduction protocol.

The client parses the descriptor and extracts the PoW parameters. It makes sure that the `expiration-time` has not expired. If it has, the descriptor may be out of date. Clients SHOULD fetch a fresh descriptor if the descriptor is stale and the seed is expired.

Inputs to the solver:

  1. Effort `E`, the client-side effort choice made based on the server’s `suggested-effort` and the client’s connection attempt history. This is a 32-bit unsigned integer.
  2. Constant personalization string `P`, equal to the following nul-terminated ASCII text: `"Tor hs intro v1\0"`.
  3. Identity string `ID`, a 32-byte value unique to the specific onion service. This is the blinded public ID key `KP_hs_blind_id`.
  4. Seed `C`, a 32-byte random value decoded from `seed-b64` above.
  5. Initial nonce `N`, a 16-byte value generated using a secure random generator.

The solver itself is iterative; the following steps are repeated until they succeed:

  1. Construct the _challenge string_ by concatenating `P || ID || C || N || htonl(E)`.

  2. Calculate a candidate proof `S` by passing this challenge to Equi-X.

`S = equix_solve(P || ID || C || N || htonl(E))`

  3. Calculate a 32-bit check value by interpreting a 32-bit Blake2b hash of the concatenated challenge and solution as an integer in network byte order.

`R = ntohl(blake2b_32(P || ID || C || N || htonl(E) || S))`

  4. Check if 32-bit multiplication of `R * E` would overflow

If `R * E` overflows (the result would be greater than `UINT32_MAX`) the solver must retry with another nonce value. The client interprets N as a 16-byte little-endian integer, increments it by 1, and goes back to step 1.

If there is no overflow (the result is less than or equal to `UINT32_MAX`) this is a valid solution. The client can submit final nonce `N`, effort `E`, the first 4 bytes of seed `C`, and proof `S`.

Note that the Blake2b hash includes the output length parameter in its initial state vector, so a `blake2b_32` is not equivalent to the prefix of a `blake2b_512`. We calculate the 32-bit Blake2b specifically, and interpret it in network byte order as an unsigned integer.

At the end of the above procedure, the client should have calculated a proof `S` and final nonce `N` that satisfies both the Equi-X proof conditions and the Blake2b effort test. The time taken, on average, is linearly proportional with the target effort `E` parameter.

The algorithm as described is suitable for single-threaded computation. Optionally, a client may choose multiple nonces and attempt several solutions in parallel on separate CPU cores. The specific choice of nonce is entirely up to the client, so parallelization choices like this do not impact the network protocol’s interoperability at all.

## Client sends its proof in an INTRO1 extension

Now that the client has an answer to the puzzle it’s time to encode it into an INTRODUCE1 message. To do so the client adds an extension to the encrypted portion of the INTRODUCE1 message by using the EXTENSIONS field. The encrypted portion of the INTRODUCE1 message only gets read by the onion service and is ignored by the introduction point.

This extension includes the chosen nonce and effort in full, as well as the actual Equi-X proof. Clients provide only the first 4 bytes of the seed, enough to disambiguate between multiple recent seeds offered by the service.

This format is defined canonically as the proof-of-work extension to INTRODUCE1.

## Service verifies PoW and handles the introduction

When a service receives an INTRODUCE1 with the `PROOF_OF_WORK` extension, it should check its configuration on whether proof-of-work is enabled on the service. If it’s not enabled, the extension SHOULD BE ignored. If enabled, even if the suggested effort is currently zero, the service follows the procedure detailed in this section.

If the service requires the `PROOF_OF_WORK` extension but received an INTRODUCE1 message without any embedded proof-of-work, the service SHOULD consider this message as a zero-effort introduction for the purposes of the priority queue.

To verify the client’s proof-of-work the service MUST do the following steps:

  1. Find a valid seed `C` that starts with `POW_SEED`. Fail if no such seed exists.
  2. Fail if `N = POW_NONCE` is present in the replay protection data structure.
  3. Construct the _challenge string_ as above by concatenating `P || ID || C || N || htonl(E)`. In this case, `E` and `N` are values provided by the client.
  4. Calculate `R = ntohl(blake2b_32(P || ID || C || N || htonl(E) || S))`, as above
  5. Fail if the the effort test overflows (`R * E > UINT32_MAX`).
  6. Fail if Equi-X reports that the proof `S` is malformed or not applicable (`equix_verify(P || ID || C || N || htonl(E), S) != EQUIX_OK`)
  7. If both the Blake2b and Equi-X tests pass, the request can be enqueued with priority `E`.

It’s a minor performance optimization for services to compute the effort test before invoking `equix_verify`. Blake2b verification is cheaper than Equi-X verification, so this ordering slightly raises the minimum effort required to perform a top-half attack.

If any of these steps fail the service MUST ignore this introduction request and abort the protocol.

In this document we call the above steps the “top half” of introduction handling. If all the steps of the “top half” have passed, then the circuit is added to the introduction queue.

---

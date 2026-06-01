# 08 Dos Prevention

This document covers the strategy, motivation, and implementation for denial-of-service mitigation systems designed into Tor.

The older `dos-spec` document is now the Memory exhaustion section here.

An in-depth description of the proof of work mechanism for onion services, originally proposal 327, is now in the Proof of Work for onion service introduction spec.

## Memory exhaustion

Memory exhaustion is a broad issue with many underlying causes. The Tor protocol requires clients, onion services, relays, and authorities to store various kind of information in buffers and caches. But an attacker can use these buffers and queues to exhaust the memory of the a targeted Tor process, and force the operating system to kill that process.

With this in mind, any Tor implementation (especially one that runs as a relay or onion service) must take steps to prevent memory-based denial-of-service attacks.

## Detecting low memory

The easiest way to notice you’re out of memory would, in theory, be getting an error when you try to allocate more. Unfortunately, some systems (e.g. Linux) won’t actually give you an “out of memory” error when you’re low on memory. Instead, they overcommit and promise you memory that they can’t actually provide… and then later on, they might kill processes that actually try to use more memory than they wish they’d given out.

So in practice, the mainline Tor implementation uses a different strategy. It uses a self-imposed “MaxMemInQueues” value as an upper bound for how much memory it’s willing to allocate to certain kinds of queued usages. This value can either be set by the user, or derived from a fraction of the total amount of system RAM.

As of Tor 0.4.7.x, the MaxMemInQueues mechanism tracks the following kinds of allocation:

  * Relay cells queued on circuits.
  * Per-connection read or write buffers.
  * On-the-fly compression or decompression state.
  * Half-open stream records.
  * Cached onion service descriptors (hsdir only).
  * Cached DNS resolves (relay only).
  * GEOIP-based usage activity statistics.

Note that directory caches aren’t counted, since those are stored on disk and accessed via mmap.

### Responding to low memory

If our allocations exceed MaxMemInQueues, then we take the following steps to reduce our memory allocation.

_Freeing from caches_ : For each of our onion service descriptor cache, our DNS cache, and our GEOIP statistics cache, we check whether they account for greater than 20% of our total allocation. If they do, we free memory from the offending cache until the total remaining is no more than 10% of our total allocation.

When freeing entries from a cache, we aim to free (approximately) the oldest entries first.

_Freeing from buffers_ : After freeing data from caches, we see whether allocations are still above 90% of MaxMemInQueues. If they are, we try to close circuits and connections until we are below 90% of MaxMemInQueues.

When deciding to what circuits to free, we sort them based on the age of the oldest data in their queues, and free the ones with the oldest data. (For example, a circuit on which a single cell has been queued for 5 minutes would be freed before a circuit where 100 cells have been queued for 5 seconds.) “Data queued on a circuit” includes all data that we could drop if the circuit were destroyed: not only the cells on the circuit’s relay cell queue, but also any bytes queued in buffers associated with streams or half-stream records attached to the circuit.

We free non-tunneled directory connections according to a similar rule, according to the age of their oldest queued data.

Upon freeing a circuit, a “DESTROY cell” must be sent in both directions.

### Reporting low memory

We define a “low threshold” equal to 3/4 of MaxMemInQueues. Every time our memory usage is above the low threshold, we record ourselves as being “under memory pressure”.

(This is not currently reported.)

## Overview

As a public and anonymous network, Tor is open to many types of denial-of-service attempts. It’s necessary to constantly develop a variety of defenses that mitigate specific types of attacks.

These mitigations are expected to improve network availability, but DoS mitigation is also important for limiting the avenues an attacker could use to perform active attacks on anonymity. For example, the ability to kill targeted Tor instances can be used to facilitate traffic analysis. See the “Sniper Attack” paper by Jansen, Tschorsch, Johnson, and Scheuermann.

The attack and defense environment changes over time. Expect that this document is an attempt to describe the current state of things, but that it may not be complete.

The defenses here are organized by the type of resource under contention. These can be physical resources (Memory, CPU, Bandwidth) or protocol resources (Channels, Circuits, Introductions).

In practice there are always overlaps between these resource types. Connecting to an onion service, for example, puts some strain on every resource type here.

## Physical resources

### Memory

Memory exhaustion is both one of the most serious denial-of-service avenues and the subject of the most fully developed defense mechanisms so far. We track overall memory use and free the most disposable objects first when usage is over threshold.

### CPU

The available CPU time on a router can be exhausted, assuming the implementation is not capable of processing network input at line rate in all circumstances. This is especially problematic in the single-threaded C implementation. Certain expensive operations like circuit extension handshakes are deferred to a thread pool, but time on the main thread is still a precious resource.

We currently don’t directly monitor and respond to CPU usage. Instead C Tor relies on limits for protocol resources, like circuits extensions and onion service introductions, that are associated with this CPU load.

### Bandwidth

Relay operators can place hard limits on total bandwidth using the `Bandwidth` or `RelayBandwidth` options. These options can help relay operators avoid bandwidth peaks on their network, however they aren’t designed as denial of service prevention mechanisms.

Beyond just shaving off harmful bandwidth peaks it’s important that normal service is not disrupted too much, and especially not disrupted in a targetable way. To approximate this goal we rely on flow control and fair dequeueing of relay cells.

## Protocol resources

### Channels

All channels to some extent are a limited resource, but we focus specifically on preventing floods of incoming TLS connections.

Excessive incoming TLS connections consume memory as well as limited network and operating system resources. Excessive incoming connections typically signal a low-effort denial of service attack.

The C Tor implementation establishes limits on both the number of concurrent connections per IP address and the rate of new connections, using the `DoSConnection` family of configuration options and their corresponding consensus parameters.

### Circuits

Excessive circuit creation can impact the entire path of that circuit, so it’s important to reject these attacks any time they can be identified. Ideally we reject them as early as possible, before they have fully built the circuit.

Because of Tor’s anonymity, most affected nodes experience the circuit flood as coming from every direction. The guard position, however, has a chance to notice specific peers that are creating too many circuits.

The C Tor implementation limits the acceptable rate of circuit creation per client IP address using the `DoSCircuit` configuration options and their corresponding consensus parameters.

### Onion service introductions

Flooding an onion service with introduction attempts causes significant network load. In addition to the CPU, memory, and bandwidth load experienced by the introduction point and the service, all involved relays experience a circuit creation flood.

We have two types of onion service DoS mitigations currently. Both are optional, enabled as needed by individual onion servce operators.

#### Mitigation by rate limiting

Introduction attempts can be rate-limited by each introduction point, at the request of the service.

This defense is configured by an operator using the `HiddenServiceEnableIntroDos` configuration options. Services use the introduction DoS extension to communicate these settings to each introduction point.

#### Mitigation using proof of work

A short non-interactive computational puzzle can be solved with each connection attempt. Requests provided by the client will be entered into a queue prioritized by their puzzle solution’s effort score. Requests are processed by the service at a limited rate, which can be adjusted to a value within the server’s capabilities.

Based on the queue behavior, servers will continuously provide an updated effort suggestion. Queue backlogs cause the effort to rise, and an idle server will cause the effort to decay. If the queue is never overfull the effort decays to zero, asking clients not to include a proof-of-work solution at all.

We may support multiple cryptographic algorithms for this puzzle in the future, but currently we support one type. It’s called `v1` in our protocol, and it’s based on the Equi-X algorithm developed for this purpose. See the document on Proof of Work for onion service introduction.

This defense is configured by an operator using the `HiddenServicePoW` configuration options. Additionally, it requires both the client and the onion service to be compiled with the `pow` module (and `--enable-gpl` mode) available. Despite this non-default build setting, proof of work _is_ available through common packagers like the Tor Browser and Debian.

---

# 04 Path Spec
[code]
                                  Roger Dingledine
                                   Nick Mathewson

[/code]

Note: This is an attempt to specify Tor as currently implemented. Future versions of Tor will implement improved algorithms.

This document tries to cover how Tor chooses to build circuits and assign streams to circuits. Other implementations MAY take other approaches, but implementors should be aware of the anonymity and load-balancing implications of their choices.

THIS SPEC ISN’T DONE YET.

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

## Attaching streams to circuits

When a circuit that might support a request is built, Tor tries to attach the request’s stream to the circuit and sends a BEGIN, BEGIN_DIR, or RESOLVE relay cell as appropriate. If the request completes unsuccessfully, Tor considers the reason given in the CLOSE relay cell. [XXX yes, and?]

After a request has remained unattached for SocksTimeout (2 minutes by default), Tor abandons the attempt and signals an error to the client as appropriate (e.g., by closing the SOCKS connection).

XXX Timeouts and when Tor auto-retries.

  * What stream-end-reasons are appropriate for retrying.

If no reply to BEGIN/RESOLVE, then the stream will timeout and fail.

## Building circuits

Here we describe a number of rules for building circuits: under what circumstances we do so, how we choose the paths for them, when we give up on an in-progress circuits, and what we do when circuit construction fails.

## Cannibalizing circuits

If we need a circuit and have a clean one already established, in some cases we can adapt the clean circuit for our new purpose. Specifically,

For hidden service interactions, we can “cannibalize” a clean internal circuit if one is available, so we don’t need to build those circuits from scratch on demand.

We can also cannibalize clean circuits when the client asks to exit at a given node – either via the “.exit” notation or because the destination is running at the same location as an exit node.

## Detecting route manipulation by Guard nodes (Path Bias)

The Path Bias defense is designed to defend against a type of route capture where malicious Guard nodes deliberately fail or choke circuits that extend to non-colluding Exit nodes to maximize their network utilization in favor of carrying only compromised traffic.

In the extreme, the attack allows an adversary that carries c/n of the network capacity to deanonymize c/n of the network connections, breaking the O((c/n)^2) property of Tor’s original threat model. It also allows targeted attacks aimed at monitoring the activity of specific users, bridges, or Guard nodes.

There are two points where path selection can be manipulated: during construction, and during usage. Circuit construction can be manipulated by inducing circuit failures during circuit extend steps, which causes the Tor client to transparently retry the circuit construction with a new path. Circuit usage can be manipulated by abusing the stream retry features of Tor (for example by withholding stream attempt responses from the client until the stream timeout has expired), at which point the tor client will also transparently retry the stream on a new path.

The defense as deployed therefore makes two independent sets of measurements of successful path use: one during circuit construction, and one during circuit usage.

The intended behavior is for clients to ultimately disable the use of Guards responsible for excessive circuit failure of either type (for the parameters to do this, see “Parameterization” below); however known issues with the Tor network currently restrict the defense to being informational only at this stage (see “Known barriers to enforcement”).

## Measuring path construction success rates

Clients maintain two counts for each of their guards: a count of the number of times a circuit was extended to at least two hops through that guard, and a count of the number of circuits that successfully complete through that guard. The ratio of these two numbers is used to determine a circuit success rate for that Guard.

Circuit build timeouts are counted as construction failures if the circuit fails to complete before the 95% “right-censored” timeout interval, not the 80% timeout condition.

If a circuit closes prematurely after construction but before being requested to close by the client, this is counted as a failure.

## Measuring path usage success rates

Clients maintain two usage counts for each of their guards: a count of the number of usage attempts, and a count of the number of successful usages.

A usage attempt means any attempt to attach a stream to a circuit.

Usage success status is temporarily recorded by state flags on circuits. Guard usage success counts are not incremented until circuit close. A circuit is marked as successfully used if we receive a properly recognized RELAY cell on that circuit that was expected for the current circuit purpose.

If subsequent stream attachments fail or time out, the successfully used state of the circuit is cleared, causing it once again to be regarded as a usage attempt only.

Upon close by the client, all circuits that are still marked as usage attempts are probed using a RELAY_BEGIN cell constructed with a destination of the form 0.a.b.c:25, where a.b.c is a 24 bit random nonce. If we get a RELAY_COMMAND_END in response matching our nonce, the circuit is counted as successfully used.

If any unrecognized RELAY cells arrive after the probe has been sent, the circuit is counted as a usage failure.

If the stream failure reason codes DESTROY, TORPROTOCOL, or INTERNAL are received in response to any stream attempt, such circuits are not probed and are declared usage failures.

Prematurely closed circuits are not probed, and are counted as usage failures.

## Scaling success counts

To provide a moving average of recent Guard activity while still preserving the ability to verify correctness, we periodically “scale” the success counts by multiplying them by a scale factor between 0 and 1.0.

Scaling is performed when either usage or construction attempt counts exceed a parametrized value.

To avoid error due to scaling during circuit construction and use, currently open circuits are subtracted from the usage counts before scaling, and added back after scaling.

## Parametrization

The following consensus parameters tune various aspects of the defense.
[code]
         pb_mincircs
           Default: 150
           Min: 5
           Effect: This is the minimum number of circuits that must complete
                   at least 2 hops before we begin evaluating construction rates.

         pb_noticepct
           Default: 70
           Min: 0
           Max: 100
           Effect: If the circuit success rate falls below this percentage,
                   we emit a notice log message.

         pb_warnpct
           Default: 50
           Min: 0
           Max: 100
           Effect: If the circuit success rate falls below this percentage,
                   we emit a warn log message.

         pb_extremepct
           Default: 30
           Min: 0
           Max: 100
           Effect: If the circuit success rate falls below this percentage,
                   we emit a more alarmist warning log message. If
                   pb_dropguard is set to 1, we also disable the use of the
                   guard.

         pb_dropguards
           Default: 0
           Min: 0
           Max: 1
           Effect: If the circuit success rate falls below pb_extremepct,
                   when pb_dropguard is set to 1, we disable use of that
                   guard.

         pb_scalecircs
           Default: 300
           Min: 10
           Effect: After this many circuits have completed at least two hops,
                   Tor performs the scaling described in
    	       "Scaling success counts".

         pb_multfactor and pb_scalefactor
           Default: 1/2
           Min: 0.0
           Max: 1.0
           Effect: The double-precision result obtained from
                   pb_multfactor/pb_scalefactor is multiplied by our current
                   counts to scale them.

         pb_minuse
           Default: 20
           Min: 3
           Effect: This is the minimum number of circuits that we must attempt to
                   use before we begin evaluating construction rates.

         pb_noticeusepct
           Default: 80
           Min: 3
           Effect: If the circuit usage success rate falls below this percentage,
                   we emit a notice log message.

         pb_extremeusepct
           Default: 60
           Min: 3
           Effect: If the circuit usage success rate falls below this percentage,
                   we emit a warning log message. We also disable the use of the
                   guard if pb_dropguards is set.

         pb_scaleuse
           Default: 100
           Min: 10
           Effect: After we have attempted to use this many circuits,
                   Tor performs the scaling described in
          	       "Scaling success counts".

[/code]

## Known barriers to enforcement

Due to intermittent CPU overload at relays, the normal rate of successful circuit completion is highly variable. The Guard-dropping version of the defense is unlikely to be deployed until the ntor circuit handshake is enabled, or the nature of CPU overload induced failure is better understood.

## A simpler path-bias enforcement

Implementations that are less vulnerable to tagging based side channels due to improved cryptography and better cell handling may implement a simpler “Path bias lite” approach.

> This approach is implemented in Arti; there is no plan to implement it in C tor. Similarly, there is no plan to implement the full path-bias approach above in Arti.

In this approach, we classify the outcome of circuit build attempt into these kinds:

  * _Successful_ (`SUCCESS`). Completely built, with the path intended.
  * _Failed and attributable_. The circuit failed to build and we know which relay is at fault.
    * _Failure connecting to guard._ This happens when the circuit fails or times out before its first hop completely built.
    * _Failure attributable to other relay_. This happens only when we get a problematic response or message from some other relay, and that cell is authenticated, and it represents a protocol violation _even in the presence of a misbehaving guard_.1
  * _Failed and indeterminate_. The circuit has failed to build, and we do not know which relay is at fault.
    * _Indeterminate failure with random path_ (`IND_RND`). The circuit’s path contains only relays that we chose randomly ourselves. (Or the failure definitely occurred before we tried to extend to any non-randomly chosen relay2.)
    * _Indeterminate failure with nonrandom path_. The circuit’s path contains at least one relay that we did not choose randomly ourselves. (This typically happens because the circuit is chosen to end with some onion-service-related hop that we did not select.)

Given this classification, we track the number of circuit outcomes of each type, for each guard. Let `TOTAL` = `IND_RND + SUCCESS`. If `TOTAL` for a single guard is at least `MIN_OBSERVATIONS` then:

  * If `IND_RND / TOTAL > WARN_THRESHOLD`, we warn the user that the guard is behaving questionably.
  * If `IND_RND / TOTAL > DISABLE_THRESHOLD`, then we warn the user again, and _permanently_ disable the guard.

The current values for constants above are:

  * `MIN_OBSERVATIONS = 15`
  * `WARN_THRESHOLD = 0.50`
  * `DISABLE_THRESHOLD = 0.70`

Implementations MAY persist these counts over time across program invocations. If they do,3 they SHOULD ensure that newer measurements count more than old ones.

  1. It is rare for a failure to be definitively attributable to a relay other than the guard. As a simplification, implementations MAY treat these failures as “indeterminate”. (Arti takes this approach.) ↩

  2. As a simplification, implementations MAY treat all failures for non-randomly-selected paths as “Indeterminate failure with nonrandom path”, even if those failures occurred before any nonrandom part of the path. (Arti takes this approach.) ↩

  3. Arti does not currently persist circuit observations. ↩

## General operation

Tor begins building circuits as soon as it has enough directory information to do so. Some circuits are built preemptively because we expect to need them later (for user traffic), and some are built because of immediate need (for user traffic that no current circuit can handle, for testing the network or our reachability, and so on).
[code]
      [Newer versions of Tor (0.2.6.2-alpha and later):
       If the consensus contains Exits (the typical case), Tor will build both
       exit and internal circuits. When bootstrap completes, Tor will be ready
       to handle an application requesting an exit circuit to services like the
       World Wide Web.

       If the consensus does not contain Exits, Tor will only build internal
       circuits. In this case, earlier statuses will have included "internal"
       as indicated above. When bootstrap completes, Tor will be ready to handle
       an application requesting an internal circuit to hidden services at
       ".onion" addresses.

       If a future consensus contains Exits, exit circuits may become available.]

[/code]

When a client application creates a new stream (by opening a SOCKS connection or launching a resolve request), we attach it to an appropriate open circuit if one exists, or wait if an appropriate circuit is in-progress. We launch a new circuit only if no current circuit can handle the request. We rotate circuits over time to avoid some profiling attacks.

To build a circuit, we choose all the nodes we want to use, and then construct the circuit. Sometimes, when we want a circuit that ends at a given hop, and we have an appropriate unused circuit, we “cannibalize” the existing circuit and extend it to the new terminus.

These processes are described in more detail below.

This document describes Tor’s automatic path selection logic only; path selection can be overridden by a controller (with the EXTENDCIRCUIT and ATTACHSTREAM commands). Paths constructed through these means may violate some constraints given below.

## Terminology

A “path” is an ordered sequence of nodes, not yet built as a circuit.

A “clean” circuit is one that has not yet been used for any traffic.

A “fast” or “stable” or “valid” node is one that has the ‘Fast’ or ‘Stable’ or ‘Valid’ flag set respectively, based on our current directory information. A “fast” or “stable” circuit is one consisting only of “fast” or “stable” nodes.

In an “exit” circuit, the final node is chosen based on waiting stream requests if any, and in any case it avoids nodes with exit policy of “reject *:*”. An “internal” circuit, on the other hand, is one where the final node is chosen just like a middle node (ignoring its exit policy).

A “request” is a client-side stream or DNS resolve that needs to be served by a circuit.

A “pending” circuit is one that we have started to build, but which has not yet completed.

A circuit or path “supports” a request if it is okay to use the circuit/path to fulfill the request, according to the rules given below. A circuit or path “might support” a request if some aspect of the request is unknown (usually its target IP), but we believe the path probably supports the request according to the rules given below.

## A relay’s bandwidth

Old versions of Tor did not report bandwidths in network status documents, so clients had to learn them from the routers’ advertised relay descriptors.

For versions of Tor prior to 0.2.1.17-rc, everywhere below where we refer to a relay’s “bandwidth”, we mean its clipped advertised bandwidth, computed by taking the smaller of the ‘rate’ and ‘observed’ arguments to the “bandwidth” element in the relay’s descriptor. If a router’s advertised bandwidth is greater than MAX_BELIEVABLE_BANDWIDTH (currently 10 MB/s), we clipped to that value.

For more recent versions of Tor, we take the bandwidth value declared in the consensus, and fall back to the clipped advertised bandwidth only if the consensus does not have bandwidths listed.

## Guard nodes

We use Guard nodes (also called “helper nodes” in the research literature) to prevent certain profiling attacks. For an overview of our Guard selection algorithm – which has grown rather complex – see guard-spec.txt.

## How consensus bandwidth weights factor into entry guard selection

When weighting a list of routers for choosing an entry guard, the following consensus parameters (from the “bandwidth-weights” line) apply:
[code]
          Wgg - Weight for Guard-flagged nodes in the guard position
          Wgm - Weight for non-flagged nodes in the guard Position
          Wgd - Weight for Guard+Exit-flagged nodes in the guard Position
          Wgb - Weight for BEGIN_DIR-supporting Guard-flagged nodes
          Wmb - Weight for BEGIN_DIR-supporting non-flagged nodes
          Web - Weight for BEGIN_DIR-supporting Exit-flagged nodes
          Wdb - Weight for BEGIN_DIR-supporting Guard+Exit-flagged nodes

[/code]

Please see “bandwidth-weights” in §3.4.1 of dir-spec.txt for more in depth descriptions of these parameters.

If a router has been marked as both an entry guard and an exit, then we prefer to use it more, with our preference for doing so (roughly) linearly increasing w.r.t. the router’s non-guard bandwidth and bandwidth weight (calculated without taking the guard flag into account). From proposal 236:

| | Let Wpf denote the weight from the ‘bandwidth-weights’ line a | client would apply to N for position p if it had the guard | flag, Wpn the weight if it did not have the guard flag, and B the | measured bandwidth of N in the consensus. Then instead of choosing | N for position p proportionally to Wpf _B or Wpn_ B, clients should | choose N proportionally to F _Wpf_ B + (1-F)_Wpn_ B.

where F is the weight as calculated using the above parameters.

## Handling failure

If an attempt to extend a circuit fails (either because the first create failed or a subsequent extend failed) then the circuit is torn down and is no longer pending. (XXXX really?) Requests that might have been supported by the pending circuit thus become unsupported, and a new circuit needs to be constructed.

If a stream “begin” attempt fails with an EXITPOLICY error, we decide that the exit node’s exit policy is not correctly advertised, so we treat the exit node as if it were a non-exit until we retrieve a fresh descriptor for it.

Excessive amounts of either type of failure can indicate an attack on anonymity. See discussion of path bias detection for how excessive failure is handled.

## Hidden-service related circuits

XXX Tracking expected hidden service use (client-side and hidserv-side)

## Learning when to give up (&amp;quot;timeout&amp;quot;) on circuit construction

# Learning when to give up (“timeout”) on circuit construction

Since version 0.2.2.8-alpha, Tor clients attempt to learn when to give up on circuits based on network conditions.

## Distribution choice

Based on studies of build times, we found that the distribution of circuit build times appears to be a Frechet distribution (and a multi-modal Frechet distribution, if more than one guard or bridge is used). However, estimators and quantile functions of the Frechet distribution are difficult to work with and slow to converge. So instead, since we are only interested in the accuracy of the tail, clients approximate the tail of the multi-modal distribution with a single Pareto curve.

## How much data to record

From our observations, the minimum number of circuit build times for a reasonable fit appears to be on the order of 100. However, to keep a good fit over the long term, clients store 1000 most recent circuit build times in a circular array.

These build times only include the times required to build three-hop circuits, and the times required to build the first three hops of circuits with more than three hops. Circuits of fewer than three hops are not recorded, and hops past the third are not recorded.

The Tor client should build test circuits at a rate of one every ‘cbttestfreq’ (10 seconds) until ‘cbtmincircs’ (100 circuits) are built, with a maximum of ‘cbtmaxopencircs’ (default: 10) circuits open at once. This allows a fresh Tor to have a CircuitBuildTimeout estimated within 30 minutes after install or network change (see Detecting Changing Network Conditions below.)

Timeouts are stored on disk in a histogram of 10ms bin width, the same width used to calculate the Xm value above. The timeouts recorded in the histogram must be shuffled after being read from disk, to preserve a proper expiration of old values after restart.

Thus, some build time resolution is lost during restart. Implementations may choose a different persistence mechanism than this histogram, but be aware that build time binning is still needed for parameter estimation.

## Parameter estimation

Once ‘cbtmincircs’ build times are recorded, Tor clients update the distribution parameters and recompute the timeout every circuit completion (though see below for when to pause and reset timeout due to too many circuits timing out).

Tor clients calculate the parameters for a Pareto distribution fitting the data using the maximum likelihood estimator. For derivation, see: <https://en.wikipedia.org/wiki/Pareto_distribution#Estimation_of_parameters>

Because build times are not a true Pareto distribution, we alter how Xm is computed. In a max likelihood estimator, the mode of the distribution is used directly as Xm.

Instead of using the mode of discrete build times directly, Tor clients compute the Xm parameter using the weighted average of the midpoints of the ‘cbtnummodes’ (10) most frequently occurring 10ms histogram bins. Ties are broken in favor of earlier bins (that is, in favor of bins corresponding to shorter build times).

(The use of 10 modes was found to minimize error from the selected cbtquantile, with 10ms bins for quantiles 60-80, compared to many other heuristics).

To avoid ln(1.0+epsilon) precision issues, use log laws to rewrite the estimator for ‘alpha’ as the sum of logs followed by subtraction, rather than multiplication and division:

`alpha = n/(Sum_n{ln(MAX(Xm, x_i))} - n\*ln(Xm))`

In this, n is the total number of build times that have completed, x_i is the ith recorded build time, and Xm is the modes of x_i as above.

All times below Xm are counted as having the Xm value via the MAX(), because in Pareto estimators, Xm is supposed to be the lowest value. However, since clients use mode averaging to estimate Xm, there can be values below our Xm. Effectively, the Pareto estimator then treats that everything smaller than Xm happened at Xm. One can also see that if clients did not do this, alpha could underflow to become negative, which results in an exponential curve, not a Pareto probability distribution.

The timeout itself is calculated by using the Pareto Quantile function (the inverted CDF) to give us the value on the CDF such that 80% of the mass of the distribution is below the timeout value (parameter ‘cbtquantile’).

The Pareto Quantile Function (inverse CDF) is:

`F(q) = Xm/((1.0-q)^(1.0/alpha))`

Thus, clients obtain the circuit build timeout for 3-hop circuits by computing:

`timeout_ms = F(0.8) # 'cbtquantile' == 0.8`

With this, we expect that the Tor client will accept the fastest 80% of the total number of paths on the network.

Clients obtain the circuit close time to completely abandon circuits as:

`close_ms = F(0.99) # 'cbtclosequantile' == 0.99`

To avoid waiting an unreasonably long period of time for circuits that simply have relays that are down, Tor clients cap timeout_ms at the max build time actually observed so far, and cap close_ms at twice this max, but at least 60 seconds:
[code]
         timeout_ms = MIN(timeout_ms, max_observed_timeout)
         close_ms = MAX(MIN(close_ms, 2*max_observed_timeout), 'cbtinitialtimeout')

[/code]

## Calculating timeouts thresholds for circuits of different lengths

The timeout_ms and close_ms estimates above are good only for 3-hop circuits, since only 3-hop circuits are recorded in the list of build times.

To calculate the appropriate timeouts and close timeouts for circuits of other lengths, the client multiples the timeout_ms and close_ms values by a scaling factor determined by the number of communication hops needed to build their circuits:
[code]
    timeout_ms\[hops=n\] = timeout_ms * Actions(N) / Actions(3)

    close_ms\[hops=n\] = close_ms * Actions(N) / Actions(3)

[/code]

where `Actions(N) = N * (N + 1) / 2.`

To calculate timeouts for operations other than circuit building, the client should add X to Actions(N) for every round-trip communication required with the Xth hop.

## How to record timeouts

Pareto estimators begin to lose their accuracy if the tail is omitted. Hence, Tor clients actually calculate two timeouts: a usage timeout, and a close timeout.

Circuits that pass the usage timeout are marked as measurement circuits, and are allowed to continue to build until the close timeout corresponding to the point ‘cbtclosequantile’ (default 99) on the Pareto curve, or 60 seconds, whichever is greater.

The actual completion times for these measurement circuits should be recorded.

Implementations should completely abandon a circuit and ignore the circuit if the total build time exceeds the close threshold. Such closed circuits should be ignored, as this typically means one of the relays in the path is offline.

## Detecting Changing Network Conditions

Tor clients attempt to detect both network connectivity loss and drastic changes in the timeout characteristics.

To detect changing network conditions, clients keep a history of the timeout or non-timeout status of the past ‘cbtrecentcount’ circuits (20 circuits) that successfully completed at least one hop. If more than 90% of these circuits timeout, the client discards all buildtimes history, resets the timeout to ‘cbtinitialtimeout’ (60 seconds), and then begins recomputing the timeout.

If the timeout was already at least `cbtinitialtimeout`, the client doubles the timeout.

The records here (of how many circuits succeeded or failed among the most recent ‘cbrrecentcount’) are not stored as persistent state. On reload, we start with a new, empty state.

## Consensus parameters governing behavior

Clients that implement circuit build timeout learning should obey the following consensus parameters that govern behavior, in order to allow us to handle bugs or other emergent behaviors due to client circuit construction. If these parameters are not present in the consensus, the listed default values should be used instead.
[code]
          cbtdisabled
            Default: 0
            Min: 0
            Max: 1
            Effect: If 1, all CircuitBuildTime learning code should be
                    disabled and history should be discarded. For use in
                    emergency situations only.

          cbtnummodes
            Default: 10
            Min: 1
            Max: 20
            Effect: This value governs how many modes to use in the weighted
            average calculation of Pareto parameter Xm. Selecting Xm as the
            average of multiple modes improves accuracy of the Pareto tail
            for quantile cutoffs from 60-80% (see cbtquantile).

          cbtrecentcount
            Default: 20
            Min: 3
            Max: 1000
            Effect: This is the number of circuit build outcomes (success vs
                    timeout) to keep track of for the following option.

          cbtmaxtimeouts
            Default: 18
            Min: 3
            Max: 10000
            Effect: When this many timeouts happen in the last 'cbtrecentcount'
                    circuit attempts, the client should discard all of its
                    history and begin learning a fresh timeout value.

                    Note that if this parameter's value is greater than the value
                    of 'cbtrecentcount', then the history will never be
                    discarded because of this feature.

          cbtmincircs
            Default: 100
            Min: 1
            Max: 10000
            Effect: This is the minimum number of circuits to build before
                    computing a timeout.

                    Note that if this parameter's value is higher than 1000 (the
                    number of time observations that a client keeps in its
                    circular buffer), circuit build timeout calculation is
                    effectively disabled, and the default timeouts are used
                    indefinitely.

          cbtquantile
            Default: 80
            Min: 10
            Max: 99
            Effect: This is the position on the quantile curve to use to set the
                    timeout value. It is a percent (10-99).

          cbtclosequantile
            Default: 99
            Min: Value of cbtquantile parameter
            Max: 99
            Effect: This is the position on the quantile curve to use to set the
                    timeout value to use to actually close circuits. It is a
                    percent (0-99).

          cbttestfreq
            Default: 10
            Min: 1
            Max: 2147483647 (INT32_MAX)
            Effect: Describes how often in seconds to build a test circuit to
                    gather timeout values. Only applies if less than 'cbtmincircs'
                    have been recorded.

          cbtmintimeout
            Default: 10
            Min: 10
            Max: 2147483647 (INT32_MAX)
            Effect: This is the minimum allowed timeout value in milliseconds.

          cbtinitialtimeout
            Default: 60000
            Min: Value of cbtmintimeout
            Max: 2147483647 (INT32_MAX)
            Effect: This is the timeout value to use before we have enough data
                    to compute a timeout, in milliseconds.  If we do not have
                    enough data to compute a timeout estimate (see cbtmincircs),
                    then we use this interval both for the close timeout and the
                    abandon timeout.

          cbtlearntimeout
            Default: 180
            Min: 10
            Max: 60000
            Effect: This is how long idle circuits will be kept open while cbt is
                    learning a new timeout value.

          cbtmaxopencircs
            Default: 10
            Min: 0
            Max: 14
            Effect: This is the maximum number of circuits that can be open at
                    at the same time during the circuit build time learning phase.

[/code]

## Path selection and constraints

We choose the path for each new circuit before we build it, based on our current directory information. (Clients and relays use the latest directory information they have; directory authorities use their own opinions.)

We choose the exit node first, followed by the other nodes in the circuit, front to back. (In other words, for a 3-hop circuit, we first pick hop 3, then hop 1, then hop 2.)

## Universal constraints

~~All~~ Most paths we generate obey the following constraints:

  * We do not choose relays without the Fast flag for any non-testing circuit.
  * We do not choose the same router twice for the same path.
  * We do not choose any router in the same family as another in the same path.
  * We do not choose more than one router in a given network range, which defaults to /16 for IPv4 and /32 for IPv6. (C Tor overrides this with `EnforceDistinctSubnets`; Arti overrides this with `ipv[46]_subnet_family_prefix`.)
  * The first node must be a Guard (see discussion below and in the guard specification).
  * XXXX Choosing the length

> Note: There are exceptions to some of these rules, in order to balance the risk of traffic confirmation attacks and the risk of guard inference attacks. As of this writing (Feb 2025) we are revisiting these tradeoffs; see torspec#307.

### Determining family membership

There are two mechanisms for determining whether two relays belong to the same family.

First, two relays belong to the same family if each relay lists the other relay in its _family list_. (A _family list_ is the contents of a `family` entry in a router descriptor or a `family` entry in a microdescriptor.) This rule is only enforced when the `use-family-lists` parameter is set to 1.

Second, two relays belong to the same family if they have at least one _family ID_ in common. (A relay has a family ID if that ID is listed in the `family-ids` entry in its microdescriptor, or if that ID corresponds to the signing key of a well-formed `family-cert` entry in its router descriptor.) This rule is only enforced when the `use-family-ids` parameter is set to 1.

## Special-purpose constraints

Additionally, we may be building circuits with one or more requests in mind. Each kind of request puts certain constraints on paths.

Similarly, some circuits need to be “Stable”. For these, we only choose nodes with the Stable flag.

  * All service-side introduction circuits and all rendezvous paths should be Stable, and their endpoints should not be flagged MiddleOnly.
  * All connection requests for connections that we think will need to stay open a long time require Stable circuits. Currently, Tor decides this by examining the request’s target port, and comparing it to a list of “long-lived” ports. (Default: 21, 22, 706, 1863, 5050, 5190, 5222, 5223, 6667, 6697, 8300.)

## Weighting node selection

For all circuits, we weight node selection according to router bandwidth.

We also weight the bandwidth of Exit and Guard flagged nodes depending on the fraction of total bandwidth that they make up and depending upon the position they are being selected for.

These weights are published in the consensus, and are computed as described in “Computing Bandwidth Weights” in the directory specification. They are:
[code]
          Wgg - Weight for Guard-flagged nodes in the guard position
          Wgm - Weight for non-flagged nodes in the guard Position
          Wgd - Weight for Guard+Exit-flagged nodes in the guard Position

          Wmg - Weight for Guard-flagged nodes in the middle Position
          Wmm - Weight for non-flagged nodes in the middle Position
          Wme - Weight for Exit-flagged nodes in the middle Position
          Wmd - Weight for Guard+Exit flagged nodes in the middle Position

          Weg - Weight for Guard flagged nodes in the exit Position
          Wem - Weight for non-flagged nodes in the exit Position
          Wee - Weight for Exit-flagged nodes in the exit Position
          Wed - Weight for Guard+Exit-flagged nodes in the exit Position

          Wgb - Weight for BEGIN_DIR-supporting Guard-flagged nodes
          Wmb - Weight for BEGIN_DIR-supporting non-flagged nodes
          Web - Weight for BEGIN_DIR-supporting Exit-flagged nodes
          Wdb - Weight for BEGIN_DIR-supporting Guard+Exit-flagged nodes

          Wbg - Weight for Guard+Exit-flagged nodes for BEGIN_DIR requests
          Wbm - Weight for Guard+Exit-flagged nodes for BEGIN_DIR requests
          Wbe - Weight for Guard+Exit-flagged nodes for BEGIN_DIR requests
          Wbd - Weight for Guard+Exit-flagged nodes for BEGIN_DIR requests

[/code]

If any of those weights is malformed or not present in a consensus, clients proceed with the regular path selection algorithm setting the weights to the default value of 10000.

## Choosing an exit

If we know what IP address we want to connect to, we can trivially tell whether a given router will support it by simulating its declared exit policy.

(DNS resolve requests are only sent to relays whose exit policy is not equivalent to “reject *:*”.)

Because we often connect to addresses of the form hostname:port, we do not always know the target IP address when we select an exit node. In these cases, we need to pick an exit node that “might support” connections to a given address port with an unknown address. An exit node “might support” such a connection if any clause that accepts any connections to that port precedes all clauses (if any) that reject all connections to that port.

Unless requested to do so by the user, we never choose an exit node flagged as “BadExit” by more than half of the authorities who advertise themselves as listing bad exits.

## User configuration

Users can alter the default behavior for path selection with configuration options.
[code]
       - If "ExitNodes" is provided, then every request requires an exit node on
         the ExitNodes list.  (If a request is supported by no nodes on that list,
         and StrictExitNodes is false, then Tor treats that request as if
         ExitNodes were not provided.)

       - "EntryNodes" and "StrictEntryNodes" behave analogously.

       - If a user tries to connect to or resolve a hostname of the form
         <target>.<servername>.exit, the request is rewritten to a request for
         <target>, and the request is only supported by the exit whose nickname
         or fingerprint is <servername>.

       - When set, "HSLayer2Nodes" and "HSLayer3Nodes" relax Tor's path
         restrictions to allow nodes in the same /16 and node family to reappear
         in the path. They also allow the guard node to be chosen as the RP, IP,
         and HSDIR, and as the hop before those positions.

[/code]

## Server descriptor purposes

There are currently three “purposes” supported for server descriptors: general, controller, and bridge. Most descriptors are of type general – these are the ones listed in the consensus, and the ones fetched and used in normal cases.

Controller-purpose descriptors are those delivered by the controller and labelled as such: they will be kept around (and expire like normal descriptors), and they can be used by the controller in its CIRCUITEXTEND commands. Otherwise they are ignored by Tor when it chooses paths.

Bridge-purpose descriptors are for routers that are used as bridges. See doc/design-paper/blocking.pdf for more design explanation, or proposal 125 for specific details. Currently bridge descriptors are used in place of normal entry guards, for Tor clients that have UseBridges enabled.

## Stream isolation and circuit sharing

> When two streams share a circuit, a hostile exit node learns that those streams belong to the same user. An observer between the exit and the destination, and the destination itself, can also infer this fact with reasonably high probability. Therefore, it’s important for streams that are logically isolated not to share circuits with one another. For example, streams from two different applications, or streams representing two different accounts within an application, or streams representing two different sessions from an application, should generally not share the same circuit.
>
> Tor clients cannot infer on their own which streams come from the same application, account, or session. Therefore, they need to provide a mechanism for applications to tell the client which streams are related, and which are not.

Every stream has a collection of _isolation properties_ that define its _isolation profile_. Two streams may share a circuit if (and only if) their isolation profiles are _compatible_.

Semantically, every isolation property has:

  * A key.
  * A value.
  * An “isolate” flag.

Two isolation properties are _incompatible_ when:

  * they have the same key,
  * they have different values,
  * and at least one of them has the “isolate” flag set to true.

Two isolation profiles are _incompatible_ if they contain a pair of isolation properties that is incompatible.

> Implementation note:
>
> When searching for a circuit on which a given stream can be used, it is inefficient to check every stream on that circuit for compatibility with the stream we’re trying to attach. Instead, implementations can merge the current set of isolation properties on _all_ streams currently on a circuit, and only compare the stream’s properties to the circuit’s properties. For a description of this algorithm see the “Implementation Notes” section of proposal 171.

Implementations SHOULD provide at least the following isolation properties; they should by default have their “isolate” flag set to true.

  * _Application Address_. The address (not port) from which the application connected to the Tor client.
  * _Proxy Address_. The specific proxy address and port provided by the Tor client to which the application connected.
  * _Proxy Protocol_. The proxy protocol that the application used when connecting to Tor client. (For example, SOCKS4, SOCKS5, HTTP CONNECT, etc)
  * _Application-provided Isolation Tokens_. A set of values provided by the application, either via a library API, or via the specific proxy protocol. See the set of isolation tokens recommended for SOCKS and the set of and isolation tokens recommended for HTTP CONNECT.

Implementations MAY provide additional isolation properties, such as for destination port, or destination address, or destination domain. These properties SHOULD NOT have their “isolate” flags set by default, since their benefit is limited and their usage can consume excessive resources.

## Isolation and circuit rotation

> Some _strong_ isolation properties are better than others at ensuring that streams from different accounts, applications, and sessions are placed on different circuits. For example, applications that provide their own application tokens are generally trusted to manage which streams are isolated from one another; whereas the application address generally only distinguishes whether the application is using 127.0.0.1 or ::1.
>
> When no isolation property is _strong_ , it makes sense to rotate circuits after they have been in use for a while. (You can think of this as adding “approximate stream creation time” as an isolation property, but this is not usually the most convenient implementation.) But when a strong isolation property _is_ present, it makes sense to use the same circuit for a long time. See proposal 368 for further discussion.

Some isolation properties are _strong_ , meaning that they are usually effective at isolating streams from different contexts.

Among the properties listed above, only “Application-provided Isolation Tokens” are _strong_.

When a circuit contains any streams _without_ strong isolation properties, then after it has been in use for streams for a sufficient time, no additional streams SHOULD be attached to it.

> In C tor this timeout is `MaxCircuitDirtiness`. In arti it is `circuit_timing.max_dirtiness`.

If a circuit contains only streams _with_ strong isolation properties, then it can be used indefinitely, and only needs to be closed after it has been unused for a long while.

> In C tor this is controlled by `KeepAliveSocksAuth`.

## When we build

## We don’t build circuits until we have enough directory info

There’s a class of possible attacks where our directory servers only give us information about the relays that they would like us to use. To prevent this attack, we don’t build multi-hop circuits (including preemptive circuits, on-demand circuits, onion-service circuits] or self-testing testing circuits) for real traffic until we have enough directory information to be reasonably confident this attack isn’t being done to us.

Here, “enough” directory information is defined as:
[code]
          * Having a consensus that's been valid at some point in the
            last REASONABLY_LIVE_TIME interval (24 hours).

          * Having enough descriptors that we could build at least some
            fraction F of all bandwidth-weighted paths, without taking
            ExitNodes/EntryNodes/etc into account.

            (F is set by the PathsNeededToBuildCircuits option,
            defaulting to the 'min_paths_for_circs_pct' consensus
            parameter, with a final default value of 60%.)

          * Having enough descriptors that we could build at least some
            fraction F of all bandwidth-weighted paths, _while_ taking
            ExitNodes/EntryNodes/etc into account.

            (F is as above.)

          * Having a descriptor for every one of the first
            NUM_USABLE_PRIMARY_GUARDS guards among our primary guards. (see
            guard-spec.txt)

[/code]

We define the “fraction of bandwidth-weighted paths” as the product of these three fractions.
[code]
          * The fraction of descriptors that we have for nodes with the Guard
            flag, weighted by their bandwidth for the guard position.
          * The fraction of descriptors that we have for all nodes,
            weighted by their bandwidth for the middle position.
          * The fraction of descriptors that we have for nodes with the Exit
            flag, weighted by their bandwidth for the exit position.

[/code]

If the consensus has zero weighted bandwidth for a given kind of relay (Guard, Middle, or Exit), Tor instead uses the fraction of relays for which it has the descriptor (not weighted by bandwidth at all).

If the consensus lists zero exit-flagged relays, Tor instead uses the fraction of middle relays.

## Clients build circuits preemptively

When running as a client, Tor tries to maintain at least a certain number of clean circuits, so that new streams can be handled quickly. To increase the likelihood of success, Tor tries to predict what circuits will be useful by choosing from among nodes that support the ports we have used in the recent past (by default one hour). Specifically, on startup Tor tries to maintain one clean fast exit circuit that allows connections to port 80, and at least two fast clean stable internal circuits in case we get a resolve request or hidden service request (at least three if we _run_ a hidden service).

After that, Tor will adapt the circuits that it preemptively builds based on the requests it sees from the user: it tries to have two fast clean exit circuits available for every port seen within the past hour (each circuit can be adequate for many predicted ports – it doesn’t need two separate circuits for each port), and it tries to have the above internal circuits available if we’ve seen resolves or hidden service activity within the past hour. If there are 12 or more clean circuits open, it doesn’t open more even if it has more predictions.

Only stable circuits can “cover” a port that is listed in the LongLivedPorts config option. Similarly, hidden service requests to ports listed in LongLivedPorts make us create stable internal circuits.

Note that if there are no requests from the user for an hour, Tor will predict no use and build no preemptive circuits.

The Tor client SHOULD NOT store its list of predicted requests to a persistent medium.

## Clients build circuits on demand

Additionally, when a client request exists that no circuit (built or pending) might support, we create a new circuit to support the request. For exit connections, we pick an exit node that will handle the most pending requests (choosing arbitrarily among ties), launch a circuit to end there, and repeat until every unattached request might be supported by a pending or built circuit. For internal circuits, we pick an arbitrary acceptable path, repeating as needed.

Clients consider a circuit to become “dirty” as soon as a stream is attached to it, or some other request is performed over the circuit. If a circuit has been “dirty” for at least MaxCircuitDirtiness seconds, new streams may not be attached to it.

In some cases we can reuse an already established circuit if it’s clean; see “cannibalizing circuits”

for details.

## Relays build circuits for testing reachability and bandwidth

Tor relays test reachability of their ORPort once they have successfully built a circuit (on startup and whenever their IP address changes). They build an ordinary fast internal circuit with themselves as the last hop. As soon as any testing circuit succeeds, the Tor relay decides it’s reachable and is willing to publish a descriptor.

We launch multiple testing circuits (one at a time), until we have NUM_PARALLEL_TESTING_CIRC (4) such circuits open. Then we do a “bandwidth test” by sending a certain number of relay drop cells down each circuit: BandwidthRate * 10 / CELL_NETWORK_SIZE total cells divided across the four circuits, but never more than CIRCWINDOW_START (1000) cells total. This exercises both outgoing and incoming bandwidth, and helps to jumpstart the observed bandwidth (see dir-spec.txt).

Tor relays also test reachability of their DirPort once they have established a circuit, but they use an ordinary exit circuit for this purpose.

## Hidden-service circuits

See section 4 below.

## Rate limiting of failed circuits

If we fail to build a circuit N times in a X second period (see “Handling failure” for how this works), we stop building circuits until the X seconds have elapsed. XXXX

## When to tear down circuits

Clients should tear down circuits (in general) only when those circuits have no streams on them. Additionally, clients should tear-down stream-less circuits only under one of the following conditions:
[code]
         - The circuit has never had a stream attached, and it was created too
           long in the past (based on CircuitsAvailableTimeout or
           cbtlearntimeout, depending on timeout estimate status).

         - The circuit is dirty (has had a stream attached), and it has been
           dirty for at least MaxCircuitDirtiness.

[/code]

---

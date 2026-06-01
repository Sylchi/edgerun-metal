# 06 Vanguards Spec

## Introduction and motivation

A guard discovery attack allows attackers to determine the guard relay of a Tor client. The hidden service protocol provides an attack vector for a guard discovery attack since anyone can force an HS to construct a 3-hop circuit to a relay, and repeat this process until one of the adversary’s middle relays eventually ends up chosen in a circuit. These attacks are also possible to perform against clients, by causing an application to make repeated connections to multiple unique onion services.

The adversary must use a protocol side channel to confirm that their relay was chosen in this position (see Proposal #344), and then learns the guard relay of a client, or service.

When a successful guard discovery attack is followed with compromise or coercion of the guard relay, the onion service or onion client can be deanonymized. Alternatively, Netflow analytics data purchase can be (and has been) used for this deanonymization, without interacting with the Guard relay directly (see again Proposal #344).

This specification assumes that Tor protocol side channels have 100% accuracy and are undetectable, for simplicity in reasoning about expected attack times. Presently, such 100% accurate side channels exist in silent form, in the Tor Protocol itself.

As work on addressing Tor’s protocol side channels progresses, these attacks will require application-layer activity that can be monitored and managed by service operators, as opposed to silent and unobservable side channel activity via the Tor Protocol itself. Application-layer side channels are also expected to have less accuracy than native Tor protocol side channels, due to the possibility of false positives caused by similar application activity elsewhere on the Tor network. Despite this, we will preserve the original assumption of 100% accuracy, for simplicity of explanation.

## Overview

In this specification, we specify two forms of a multi-layered Guard system: one for long-lived services, called Full Vanguards, and one for onion clients and short-lived services, called Vanguards-Lite.

Both approaches use a mesh topology, where circuits can be created from any relay in a preceding layer to any relay in a subsequent layer.

The core difference between these two mechanisms is that Full Vanguards has two additional layers of fixed vanguard relays, which results in longer path lengths and higher latency. In contrast, Vanguards-Lite has only one additional layer of fixed vanguard relays, and preserves the original path lengths in use by onion services. Thus, Full Vanguards comes with a performance cost, where as Vanguards-Lite does not. The rotation periods of the two approaches also differ.

Vanguards-Lite MUST be the default for all onion service and onion client activity; Full Vanguards SHOULD be available as an optional configuration option for services.

Neither system applies to Exit activity.

### Terminology

Tor’s original guards are called First Layer Guards.

The first layer of vanguards is at the second hop, and is called the Second Layer Guards.

The second layer of vanguards is at the third hop, and is called the Third Layer Guards.

A circuit stem is the beginning portion of a hidden service circuit that is common to all hidden service circuit types, under a given vanguards behavior option (none, lite, or full). Abstracting this common portion is useful for circuit prebuilding, to maintain a pool of circuit prefixes (stems) that can be used for any hidden service circuit.

> Note: In Arti, this circuit stem prefix is further abstracted, to handle the fact that some hidden circuit types require an additional random middle node, where as others do not (see diagrams below). Other than easing circuit pre-building, this distinction has no consequence on paths. The below diagrams are canonical behavior for each given circuit type.

### Visualizing Full Vanguards

Full Vanguards pins these two middle positions into a mesh topology, where any relay in a layer can be used in that position in a circuit, as follows:
[code]
                           -> vanguard_2A
                                          -> vanguard_3A
              -> guard_1A  -> vanguard_2B -> vanguard_3B
           HS                             -> vanguard_3C
              -> guard_1B  -> vanguard_2C -> vanguard_3D
                                          -> vanguard_3E
                           -> vanguard_2D -> vanguard_3F

[/code]

Additionally, to avoid trivial discovery of the third layer, and to minimize linkability, we insert an extra middle relay after the third layer guard for client side intro and hsdir circuits, and service-side rendezvous circuits. This means that the set of paths for Client (C) and Service (S) side look like this:
[code]
         Client hsdir:  C - G - L2 - L3 - M - HSDIR
         Client intro:  C - G - L2 - L3 - M - I
         Client rend:   C - G - L2 - L3 - R
         Service hsdir: S - G - L2 - L3 - HSDIR
         Service intro: S - G - L2 - L3 - I
         Service rend:  S - G - L2 - L3 - M - R

[/code]

### Visualizing Vanguards-Lite

Vanguards-Lite uses only one layer of vanguards:
[code]
                           -> vanguard_2A

              -> guard_1A  -> vanguard_2B
           HS
              -> guard_1B  -> vanguard_2C

                           -> vanguard_2D

[/code]

This yields shorter path lengths, of the following form:
[code]
         Client hsdir:  C -> G -> L2 -> M -> HSDir
         Client intro:  C -> G -> L2 -> M -> Intro
         Client rend:   C -> G -> L2 -> Rend
         Service hsdir: C -> G -> L2 -> M -> HSDir
         Service intro: C -> G -> L2 -> M -> Intro
         Service rend:  C -> G -> L2 -> M -> Rend

[/code]

## Alternatives

An alternative to vanguards for client activity is to restrict the number of onion services that a Tor client is allowed to connect to, in a certain period of time. This defense was explored in Onion Not Found.

We have opted not to deploy this defense, for three reasons:

  1. It does not generalize to the service-side of onion services
  2. Setting appropriate rate limits on the number of onion service content elements on a page for Tor Browser is difficult. Sites like Facebook use multiple onion domains for various content elements on a single page.
  3. It is even more difficult to limit the number of service connections for arbitrary applications, such as cryptocurrency wallets, mining, and other distributed apps deployed on top of onion services that connect to multiple services (such as Ricochet).

## Full Vanguards

Full Vanguards is intended for use by long-lived onion services, which intend to remain in operation for longer than one month.

Full Vanguards achieves this longer expected duration by having two layers of additional fixed relays, of different rotation periods.

The rotation period of the first vanguard layer (layer 2 guards) is chosen such that it requires an extremely long and persistent Sybil attack, or a coercion/compromise attack.

The rotation period of the second vanguard layer (layer 3 guards) is chosen to be small enough to force the adversary to perform a Sybil attack against this layer, rather than attempting to coerce these relays.

## Threat model, Assumptions, and Goals

Consider an adversary with the following powers:
[code]
         - Can launch a Sybil guard discovery attack against any position of a
           rendezvous circuit. The slower the rotation period of their target
           position, the longer the attack takes. Similarly, the higher the
           percentage of the network is controlled by them, the faster the
           attack runs.

         - Can compromise additional relays on the network, but this compromise
           takes time and potentially even coercive action, and also carries risk
           of discovery.

[/code]

We also make the following assumptions about the types of attacks:

  1. A Sybil attack is observable by both people monitoring the network for large numbers of new relays, as well as vigilant hidden service operators. It will require large amounts of traffic sent towards the hidden service over many many test circuits.

  2. A Sybil attack requires either a protocol side channel or an application-layer timing side channel in order to determine successful placement next to the relay that the adversary is attempting to discover. When Tor’s internal protocol side channels are dealt with, this will be both observable and controllable at the Application Layer, by operators.

  3. The adversary is strongly disincentivized from compromising additional relays that may prove useless, as active compromise attempts are even more risky for the adversary than a Sybil attack in terms of being noticed. In other words, the adversary is unlikely to attempt to compromise or coerce additional relays that are in use for only a short period of time.

Given this threat model, our security parameters were selected so that the first two layers of guards should take a very long period of time to attack using a Sybil guard discovery attack and hence require a relay compromise attack.

On the other hand, the outermost layer of guards (the third layer) should rotate fast enough to _require_ a Sybil attack. If the adversary were to attempt to compromise or coerce these relays after they are discovered, their rotation times should be fast enough that the adversary has a very high probability of them no longer being in use.

# Design

When a hidden service picks its guard relays, it also picks an additional NUM_LAYER2_GUARDS-sized set of middle relays for its `second_guard_set`, as well as a NUM_LAYER3_GUARDS-sized set of middle relays for its `third_guard_set`.

When a hidden service needs to establish a circuit to an HSDir, introduction point or a rendezvous point, it uses relays from `second_guard_set` as the second hop of the circuit and relays from `third_guard_set` as third hop of the circuit.

A hidden service rotates relays from the ‘second_guard_set’ at a uniformly random time between MIN_SECOND_GUARD_LIFETIME hours and MAX_SECOND_GUARD_LIFETIME hours, chosen for each layer 2 relay. Implementations MAY expose this layer as an explicit configuration option to pin specific relays, similar to how a user is allowed to pin specific Guards.

A hidden service rotates relays from the ‘third_guard_set’ at a random time between MIN_THIRD_GUARD_LIFETIME and MAX_THIRD_GUARD_LIFETIME hours, as weighted by the max(X,X) distribution, chosen for each relay. This skewed distribution was chosen so that there is some probability of a very short rotation period, to deter compromise/coercion, but biased towards the longer periods, in favor of a somewhat lengthy Sybil attack. For this reason, users SHOULD NOT be encouraged to pin this layer.

Each relay’s rotation time is tracked independently, to avoid disclosing the rotation times of the primary and second-level guards.

The selected vanguards and their rotation timestamp MUST be persisted to disk.

## Parameterization

We set NUM_LAYER2_GUARDS to 4 relays and NUM_LAYER3_GUARDS to 6 relays.

We set MIN_SECOND_GUARD_LIFETIME to 30 days, and MAX_SECOND_GUARD_LIFETIME to 60 days inclusive, for an average rotation rate of 45 days, using a uniform distribution. This range was chosen to average out to half of the Guard rotation period; there is no strong motivation for it otherwise, other than to be long. In fact, it could be set as long as the Guard rotation, and longer periods MAY be provided as a configuration parameter.

From the Sybil rotation table in statistical analysis, with NUM_LAYER2_GUARDS=4, it can be seen that this means that the Sybil attack on layer3 will complete with 50% chance in 18*45 days (2.2 years) for the 1% adversary, 180 days for the 5% adversary, and 90 days for the 10% adversary, with a 45 day average rotation period.

If this range is set equal to the Guard rotation period (90 days), the 50% probability of Sybil success requires 18*90 days (4.4 years) for the 1% adversary, 4*90 days (1 year) for the 5% adversary, and 2*90 days (6 months) for the 10% adversary.

We set MIN_THIRD_GUARD_LIFETIME to 1 hour, and MAX_THIRD_GUARD_LIFETIME to 48 hours inclusive, for an average rotation rate of 31.5 hours, using the max(X,X) distribution. (Again, this wide range and bias is used to discourage the adversary from exclusively performing coercive attacks, as opposed to mounting the Sybil attack, so increasing it substantially is not recommended).

From the Sybil rotation table in statistical analysis, with NUM_LAYER3_GUARDS=6, it can be seen that this means that the Sybil attack on layer3 will complete with 50% chance in 9*31.5 hours (15.75 days) for the 1% adversary, ~4 days for the 5% adversary, and 2.62 days for the 10% adversary.

See the statistical analysis for more analysis on these constants.

## Path Construction

Both vanguards systems use a mesh topology: this means that circuits select a hop from each layer independently, allowing paths from any relay in a layer to any relay in the next layer.

## Selecting Relays

Vanguards relays are selected from relays with the Stable and Fast flags.

Tor replaces a vanguard whenever it is no longer listed in the most recent consensus, with the goal that we will always have the right number of vanguards ready to be used.

For implementation reasons, we also replace a vanguard if it loses the Fast or Stable flag, because the path selection logic wants middle nodes to have those flags when it’s building preemptive vanguard-using circuits.

The design doesn’t have to be this way: we might instead have chosen to keep vanguards in our list as long as possible, and continue to use them even if they have lost some flags. This tradeoff is similar to the one in Bug #17773, about whether to continue using Entry Guards if they lose the Guard flag – and Tor’s current choice is “no, rotate” for that case too.

## Path Restriction Changes

Path restrictions, as well as the ordering of their application, are currently extremely problematic, resulting in information leaks with this topology. Until they are reworked, we disable many of them for onion service circuits.

In particular, we allow the following:

  1. Nodes from the same /16 and same family for any/all hops in a circuit
  2. Guard nodes can be chosen for RP/IP/HSDIR
  3. Guard nodes can be chosen for hop before RP/IP/HSDIR.

The first change prevents the situation where paths cannot be built if two layers all share the same subnet and/or node family, or if a layer consists of only one family and that family is the same as the RP/IP/HSDIR. It also prevents the the use of a different entry guard based on the family or subnet of the IP, HSDIR, or RP. (Alternatives of this permissive behavior are possible: For example, each layer could ensure that it does not consist solely of the same family or /16, but this property cannot easily apply to conflux circuits).

The second change prevents an adversary from forcing the use of a different entry guard by enumerating all guard-flagged nodes as the RP. This change is important once onion services support conflux.

The third change prevents an adversary from learning the guard node by way of noticing which nodes were not chosen for the hop before it. This change is important once onion services support conflux.

## Vanguards-Lite

Vanguards-Lite is meant for short-lived onion services such as OnionShare, as well as for onion client activity.

It is designed for clients and services that expect to have an uptime of no longer than 1 month.

## Design

Because it is for short-lived activity, its rotation times are chosen with the Sybil adversary in mind, using the max(X,X) skewed distribution.

We let NUM_LAYER2_GUARDS=4. We also introduce a consensus parameter `guard-hs-l2-number` that controls the number of layer2 guards (with a maximum of 19 layer2 guards).

No third layer of guards is used.

We don’t write guards on disk. This means that the guard topology resets when tor restarts.

## Rotation Period

The Layer2 lifetime uses the max(x,x) distribution with a minimum of one day and maximum of 22 days. This makes the average lifetime of approximately two weeks. Significant extensions of this lifetime are not recommended, as they will shift the balance in favor of coercive attacks.

From the Sybil Rotation Table, with NUM_LAYER2_GUARDS=4 it can be seen that this means that the Sybil attack on Layer2 will complete with 50% chance in 18*14 days (252 days) for the 1% adversary, 4*14 days (two months) for the 5% adversary, and 2*14 days (one month) for the 10% adversary.

## Statistical Analysis

# Vanguard Rotation Statistics

## Sybil rotation counts for a given number of Guards

The probability of Sybil success for Guard discovery can be modeled as the probability of choosing 1 or more malicious middle nodes for a sensitive circuit over some period of time.
[code]
      P(At least 1 bad middle) = 1 - P(All Good Middles)
                               = 1 - P(One Good middle)^(num_middles)
                               = 1 - (1 - c/n)^(num_middles)

[/code]

c/n is the adversary compromise percentage

In the case of Vanguards, num_middles is the number of Guards you rotate through in a given time period. This is a function of the number of vanguards in that position (v), as well as the number of rotations (r).
[code]
      P(At least one bad middle) = 1 - (1 - c/n)^(v*r)

[/code]

Here’s detailed tables in terms of the number of rotations required for a given Sybil success rate for certain number of guards.
[code]
      1.0% Network Compromise:
       Sybil Success   One   Two  Three  Four  Five  Six  Eight  Nine  Ten  Twelve  Sixteen
        10%            11     6     4     3     3     2     2     2     2     1       1
        15%            17     9     6     5     4     3     3     2     2     2       2
        25%            29    15    10     8     6     5     4     4     3     3       2
        50%            69    35    23    18    14    12     9     8     7     6       5
        60%            92    46    31    23    19    16    12    11    10     8       6
        75%           138    69    46    35    28    23    18    16    14    12       9
        85%           189    95    63    48    38    32    24    21    19    16      12
        90%           230   115    77    58    46    39    29    26    23    20      15
        95%           299   150   100    75    60    50    38    34    30    25      19
        99%           459   230   153   115    92    77    58    51    46    39      29

      5.0% Network Compromise:
       Sybil Success   One   Two  Three  Four  Five  Six  Eight  Nine  Ten  Twelve  Sixteen
        10%             3     2     1     1     1     1     1     1     1     1       1
        15%             4     2     2     1     1     1     1     1     1     1       1
        25%             6     3     2     2     2     1     1     1     1     1       1
        50%            14     7     5     4     3     3     2     2     2     2       1
        60%            18     9     6     5     4     3     3     2     2     2       2
        75%            28    14    10     7     6     5     4     4     3     3       2
        85%            37    19    13    10     8     7     5     5     4     4       3
        90%            45    23    15    12     9     8     6     5     5     4       3
        95%            59    30    20    15    12    10     8     7     6     5       4
        99%            90    45    30    23    18    15    12    10     9     8       6

      10.0% Network Compromise:
       Sybil Success   One   Two  Three  Four  Five  Six  Eight  Nine  Ten  Twelve  Sixteen
        10%             2     1     1     1     1     1     1     1     1     1       1
        15%             2     1     1     1     1     1     1     1     1     1       1
        25%             3     2     1     1     1     1     1     1     1     1       1
        50%             7     4     3     2     2     2     1     1     1     1       1
        60%             9     5     3     3     2     2     2     1     1     1       1
        75%            14     7     5     4     3     3     2     2     2     2       1
        85%            19    10     7     5     4     4     3     3     2     2       2
        90%            22    11     8     6     5     4     3     3     3     2       2
        95%            29    15    10     8     6     5     4     4     3     3       2
        99%            44    22    15    11     9     8     6     5     5     4       3

[/code]

The rotation counts in these tables were generated with:

## Skewed Rotation Distribution

In order to skew the distribution of the third layer guard towards higher values, we use max(X,X) for the distribution, where X is a random variable that takes on values from the uniform distribution.

Here’s a table of expectation (arithmetic means) for relevant ranges of X (sampled from 0..N-1). The table was generated with the following python functions:
[code]
      def ProbMinXX(N, i): return (2.0*(N-i)-1)/(N*N)
      def ProbMaxXX(N, i): return (2.0*i+1)/(N*N)

      def ExpFn(N, ProbFunc):
        exp = 0.0
        for i in range(N): exp += i*ProbFunc(N, i)
        return exp

[/code]

The current choice for second-layer Vanguards-Lite guards is noted with **, and the current choice for third-layer Full Vanguards is noted with ***.
[code]
       Range  Min(X,X)   Max(X,X)
       22      6.84        14.16**
       23      7.17        14.83
       24      7.51        15.49
       25      7.84        16.16
       26      8.17        16.83
       27      8.51        17.49
       28      8.84        18.16
       29      9.17        18.83
       30      9.51        19.49
       31      9.84        20.16
       32      10.17       20.83
       33      10.51       21.49
       34      10.84       22.16
       35      11.17       22.83
       36      11.50       23.50
       37      11.84       24.16
       38      12.17       24.83
       39      12.50       25.50
       40      12.84       26.16
       40      12.84       26.16
       41      13.17       26.83
       42      13.50       27.50
       43      13.84       28.16
       44      14.17       28.83
       45      14.50       29.50
       46      14.84       30.16
       47      15.17       30.83
       48      15.50       31.50***

[/code]

The Cumulative Density Function (CDF) tells us the probability that a guard will no longer be in use after a given number of time units have passed.

Because the Sybil attack on the third node is expected to complete at any point in the second node’s rotation period with uniform probability, if we want to know the probability that a second-level Guard node will still be in use after t days, we first need to compute the probability distribution of the rotation duration of the second-level guard at a uniformly random point in time. Let’s call this P(R=r).

For P(R=r), the probability of the rotation duration depends on the selection probability of a rotation duration, and the fraction of total time that rotation is likely to be in use. This can be written as:
[code]
      P(R=r) = ProbMaxXX(X=r)*r / \sum_{i=1}^N ProbMaxXX(X=i)*i

[/code]

or in Python:
[code]
      def ProbR(N, r, ProbFunc=ProbMaxXX):
         return ProbFunc(N, r)*r/ExpFn(N, ProbFunc)

[/code]

For the full CDF, we simply sum up the fractional probability density for all rotation durations. For rotation durations less than t days, we add the entire probability mass for that period to the density function. For durations d greater than t days, we take the fraction of that rotation period’s selection probability and multiply it by t/d and add it to the density. In other words:
[code]
      def FullCDF(N, t, ProbFunc=ProbR):
        density = 0.0
        for d in range(N):
          if t >= d: density += ProbFunc(N, d)
          # The +1's below compensate for 0-indexed arrays:
          else: density += ProbFunc(N, d)*(float(t+1))/(d+1)
        return density

[/code]

Computing this yields the following distribution for our current parameters:
[code]
       t          P(SECOND_ROTATION <= t)
       1               0.03247
       2               0.06494
       3               0.09738
       4               0.12977
       5               0.16207
      10               0.32111
      15               0.47298
      20               0.61353
      25               0.73856
      30               0.84391
      35               0.92539
      40               0.97882
      45               1.00000

[/code]

This CDF tells us that for the second-level Guard rotation, the adversary can expect that 3.3% of the time, their third-level Sybil attack will provide them with a second-level guard node that has only 1 day remaining before it rotates. 6.5% of the time, there will be only 2 day or less remaining, and 9.7% of the time, 3 days or less.

Note that this distribution is still a day-resolution approximation.

---

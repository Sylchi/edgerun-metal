# 21 Parameters

## Tor network parameters

This file lists the recognized parameters that can appear on the “params” line of a directory consensus.

## Network protocol parameters

“circwindow” – the default package window that circuits should be established with. It started out at 1000 DATA-bearing relay cells, but some research indicates that a lower value would mean fewer cells in transit in the network at any given time. Min: 100, Max: 1000, Default: 1000 First-appeared: Tor 0.2.1.20

“UseOptimisticData” – If set to zero, clients by default shouldn’t try to send optimistic data to servers until they have received a CONNECTED message. Min: 0, Max: 1, Default: 1 First-appeared: 0.2.3.3-alpha Default was 0 before: 0.2.9.1-alpha Removed in 0.4.5.1-alpha; now always on.

“usecreatefast” – Used to control whether clients use the CREATE_FAST handshake on the first hop of their circuits. Min: 0, Max: 1. Default: 1. First-appeared: 0.2.4.23, 0.2.5.2-alpha Removed in 0.4.5.1-alpha; now always off.

“min_paths_for_circs_pct” – A percentage threshold that determines whether clients believe they have enough directory information to build circuits. This value applies to the total fraction of bandwidth-weighted paths that the client could build; see path-spec.txt for more information. Min: 25, Max: 95, Default: 60 First-appeared: 0.2.4

“ExtendByEd25519ID” – If true, clients should include Ed25519 identities for relays when generating EXTEND2 messages. Min: 0. Max: 1. Default: 0. First-appeared: 0.3.0

“sendme_emit_min_version” – Minimum SENDME version that can be sent. Min: 0. Max: 255. Default 1. First appeared: 0.4.1.1-alpha. Default was 0 before: 0.4.2.8 / 0.4.3.4-rc

“sendme_accept_min_version” – Minimum SENDME version that is accepted. Min: 0. Max: 255. Default 0. First appeared: 0.4.1.1-alpha.

“allow-network-reentry” – If true, the Exit relays allow connections that are exiting the network to re-enter. If false, any exit connections going to a relay ORPort or an authority ORPort and DirPort is denied and the stream is terminated. Min: 0. Max: 1. Default: 0 First appeared: 0.4.5.1-alpha.

## Performance-tuning parameters

“CircuitPriorityHalflifeMsec” – the halflife parameter used when weighting which circuit will send the next relay cell. Obeyed by Tor 0.2.2.10-alpha and later. (Versions of Tor between 0.2.2.7-alpha and 0.2.2.10-alpha recognized a “CircPriorityHalflifeMsec” parameter, but mishandled it badly.) Min: 1, Max: 2147483647 (INT32_MAX), Default: 30000. First-appeared: Tor 0.2.2.11-alpha
[code]
        "perconnbwrate" and "perconnbwburst" -- if set, each relay sets up a
        separate token bucket for every client OR connection, and rate limits
        that connection independently. Typically left unset, except when used for
        performance experiments around trac entry 1750. Only honored by relays
        running Tor 0.2.2.16-alpha and later. (Note that relays running
        0.2.2.7-alpha through 0.2.2.14-alpha looked for bwconnrate and
        bwconnburst, but then did the wrong thing with them; see bug 1830 for
        details.)
        Min: 1, Max: 2147483647 (INT32_MAX), Default: (user setting of
            BandwidthRate/BandwidthBurst).
        First-appeared: 0.2.2.7-alpha
        Removed-in: 0.2.2.16-alpha

[/code]

“NumNTorsPerTAP” – When balancing ntor and TAP requests at relays, how many ntor handshakes should we perform for each TAP handshake? Min: 1. Max: 100000. Default: 10. First-appeared: 0.2.4.17-rc

“circ_max_cell_queue_size” – This parameter determines the maximum number of relay cells allowed per circuit queue. Min: 1000. Max: 2147483647 (INT32_MAX). Default: 50000. First-appeared: 0.3.3.6-rc.

“KISTSchedRunInterval” – How frequently should the “KIST” scheduler run in order to decide which data to write to the network? Value in units of milliseconds. Min: 2. Max: 100. Default: 2 First appeared: 0.3.2

“KISTSchedRunIntervalClient” – How frequently should the “KIST” scheduler run in order to decide which data to write to the network, on clients? Value in units of milliseconds. The client value needs to be much lower than the relay value. Min: 2. Max: 100. Default: 2. First appeared: 0.4.8.2

## Voting-related parameters

“bwweightscale” – Value that bandwidth-weights are divided by. If not present then this defaults to 10000. Min: 1 First-appeared: 0.2.2.10-alpha

“maxunmeasuredbw” – Used by authorities during voting with method 17 or later. The maximum value to give for any Bandwidth= entry for a router that isn’t based on at least three measurements.

(Note: starting in version 0.4.6.1-alpha there was a bug where Tor authorities would instead look at a parameter called “maxunmeasurdbw”, without the “e”. This bug was fixed in 0.4.9.1-alpha and in 0.4.8.8. Until all relays are running a fixed version, then either this parameter must not be set, or it must be set to the same value for both spellings.)

First-appeared: 0.2.4.11-alpha

“FastFlagMinThreshold”, “FastFlagMaxThreshold” – lowest and highest allowable values for the cutoff for routers that should get the Fast flag. This is used during voting to prevent the threshold for getting the Fast flag from being too low or too high. FastFlagMinThreshold: Min: 4. Max: INT32_MAX: Default: 4. FastFlagMaxThreshold: Min: -. Max: INT32_MAX: Default: INT32_MAX First-appeared: 0.2.3.11-alpha

“AuthDirNumSRVAgreements” – Minimum number of agreeing directory authority votes required for a fresh shared random value to be written in the consensus (this rule only applies on the first commit round of the shared randomness protocol). Min: 1. Max: INT32_MAX. Default: 2/3 of the total number of dirauth.

## Circuit-build-timeout parameters

“cbtdisabled”, “cbtnummodes”, “cbtrecentcount”, “cbtmaxtimeouts”, “cbtmincircs”, “cbtquantile”, “cbtclosequantile”, “cbttestfreq”, “cbtmintimeout”, “cbtlearntimeout”, “cbtmaxopencircs”, and “cbtinitialtimeout” – see “2.4.5. Consensus parameters governing behavior” in path-spec.txt for a series of circuit build time related consensus parameters.

## Directory-related parameters

“max-consensus-age-to-cache-for-diff” – Determines how much consensus history (in hours) relays should try to cache in order to serve diffs. (min 0, max 8192, default 72)

“try-diff-for-consensus-newer-than” – This parameter determines how old a consensus can be (in hours) before a client should no longer try to find a diff for it. (min 0, max 8192, default 72)

## Pathbias parameters

“pb_mincircs”, “pb_noticepct”, “pb_warnpct”, “pb_extremepct”, “pb_dropguards”, “pb_scalecircs”, “pb_scalefactor”, “pb_multfactor”, “pb_minuse”, “pb_noticeusepct”, “pb_extremeusepct”, “pb_scaleuse” – DOCDOC

## Family-related parameters

`publish-family-list`: If 1, relays should include any configured or derived family list in their published descriptors. If 0, they should not. (Min: 0, Max: 1. Default: 1.) First-appeared-in: 0.4.9.1-alpha

`use-family-ids`: If 1, clients should consider family IDs (including those from microdescriptors' `family-ids` and those from router descriptors' `family-cert` entries) when building paths. If 0, they should not. (Min: 0, Max: 1. Default: 1) First-appeared-in: 0.4.9.1-alpha

`use-family-lists`: If 1, clients should consider legacy family lists (including `family` entries in router descriptors and microdescriptors) when building paths. If 0, they should not. (Min: 0, Max: 1. Default: 1.) First-appeared-in: 0.4.9.1-alpha

## Relay behavior parameters

“refuseunknownexits” – if set to one, exit relays look at the previous hop of circuits that ask to open an exit stream, and refuse to exit if they don’t recognize it as a relay. The goal is to make it harder for people to use them as one-hop proxies. See trac entry 1751 for details. Min: 0, Max: 1 First-appeared: 0.2.2.17-alpha

“onion-key-rotation-days” – (min 1, max 90, default 28)

“onion-key-grace-period-days” – (min 1, max onion-key-rotation-days, default 7)

Every relay should list each onion key it generates for onion-key-rotation-days days after generating it, and then replace it. Relays should continue to accept their most recent previous onion key for an additional onion-key-grace-period-days days after it is replaced. (Introduced in 0.3.1.1-alpha; prior versions of tor hardcoded both of these values to 7 days.)

“AllowNonearlyExtend” – If true, permit EXTEND/EXTEND2 requests that are not inside RELAY_EARLY cells. Min: 0. Max: 1. Default: 0. First-appeared: 0.2.3.11-alpha

“overload_dns_timeout_scale_percent” – This value is a percentage of how many DNS timeout over N seconds we accept before reporting the overload general state. It is scaled by a factor of 1000 in order to be able to represent decimal point. As an example, a value of 1000 means 1%. Min: 0. Max: 100000. Default: 1000. First-appeared: 0.4.6.8 Deprecated: 0.4.7.3-alpha-dev

“overload_dns_timeout_period_secs” – This value is the period in seconds of the DNS timeout measurements (the N in the “overload_dns_timeout_scale_percent” parameter). For this amount of seconds, we will gather DNS statistics and at the end, we’ll do an assessment on the overload general signal with regards to DNS timeouts. Min: 0. Max: 2147483647. Default: 600 First-appeared: 0.4.6.8 Deprecated: 0.4.7.3-alpha-dev

“overload_onionskin_ntor_scale_percent” – This value is a percentage of how many onionskin ntor drop over N seconds we accept before reporting the overload general state. It is scaled by a factor of 1000 in order to be able to represent decimal point. As an example, a value of 1000 means 1%. Min: 0. Max: 100000. Default: 1000. First-appeared: 0.4.7.5-alpha

“overload_onionskin_ntor_period_secs” – This value is the period in seconds of the onionskin ntor overload measurements (the N in the “overload_onionskin_ntor_scale_percent” parameter). For this amount of seconds, we will gather onionskin ntor statistics and at the end, we’ll do an assessment on the overload general signal. Min: 0. Max: 2147483647. Default: 21600 (6 hours) First-appeared: 0.4.7.5-alpha

“assume-reachable” – If true, relays should publish descriptors even when they cannot make a connection to their IPv4 ORPort. Min: 0. Max: 1. Default: 0. First appeared: 0.4.5.1-alpha.

“assume-reachable-ipv6” – If true, relays should publish descriptors even when they cannot make a connection to their IPv6 ORPort. Min: 0. Max: 1. Default: 0. First appeared: 0.4.5.1-alpha.

“exit_dns_timeout” – The time in milliseconds an Exit sets libevent to wait before it considers the DNS timed out. The corresponding libevent option is “timeout:”. Min: 1. Max: 120000. Default: 1000 (1sec) First appeared: 0.4.7.5-alpha.

“exit_dns_num_attempts” – How many attempts _after the first_ should an Exit should try a timing-out DNS query before calling it hopeless? (Each of these attempts will wait for “exit_dns_timeout” independently). The corresponding libevent option is “attempts:”. Min: 0. Max: 255. Default: 2 First appeared: 0.4.7.5-alpha.

"publish-dummy-tap-key" -- If set to 1, relays must include a TAP `onion-key` and `onion-key-crosscert` field in their descriptors, or else authorities may reject those descriptors. Min: 0. Max: 1. Default: 1. First appeared: 0.4.9.x.

“onion_queue_wait_cutoff” – If the relay has queued create cells that have been pending this many seconds waiting for a cpuworker, it is time to cancel them and send a destroy response back. Min: 1. Max: INT32_MAX. Default: 5. First appeared: 0.4.7.11.

“MaxOnionQueueDelay” – If we have more onionskins queued for processing than we can process in this amount of time (in milliseconds), reject new ones. Min: 1. Max: INT32_MAX. Default: 1750. First appeared: 0.4.7.11.

## V3 onion service parameters

“hs_intro_min_introduce2”, “hs_intro_max_introduce2” – Minimum/maximum amount of INTRODUCE2 messages allowed per circuit before rotation (actual amount picked at random between these two values). Min: 0. Max: INT32_MAX. Defaults: 16384, 32768.

“hs_intro_min_lifetime”, “hs_intro_max_lifetime” – Minimum/maximum lifetime in seconds that a service should keep an intro point for (actual lifetime picked at random between these two values). Min: 0. Max: INT32_MAX. Defaults: 18 hours, 24 hours.

“hs_intro_num_extra” – Number of extra intro points a service is allowed to open. This concept comes from proposal #155. Min: 0. Max: 128. Default: 2.

“hsdir_interval” – The length of a time period, _in minutes_. See rend-spec-v3.txt section [TIME-PERIODS]. Min: 5. Max: 14400. Default: 1440.

“hsdir_n_replicas” – Number of HS descriptor replicas. Min: 1. Max: 16. Default: 2.

“hsdir_spread_fetch” – Total number of HSDirs per replica a tor client should select to try to fetch a descriptor. Min: 1. Max: 128. Default: 3.

“hsdir_spread_store” – Total number of HSDirs per replica a service will upload its descriptor to. Min: 1. Max: 128. Default: 4

“HSV3MaxDescriptorSize” – Maximum descriptor size (in bytes). Min: 1. Max: INT32_MAX. Default: 50000

“hs_service_max_rdv_failures” – This parameter determines the maximum number of rendezvous attempt an HS service can make per introduction. Min 1. Max 10. Default 2. First-appeared: 0.3.3.0-alpha.

“HiddenServiceEnableIntroDoSDefense” – This parameter makes introduction points start using a rate-limiting defense if they support it. Introduction points use this value when no `DOS_PARAMS` extension is sent in the ESTABLISH_INTRO message. Min: 0. Max: 1. Default: 0. First appeared: 0.4.2.1-alpha.

“HiddenServiceEnableIntroDoSBurstPerSec” – Default maximum burst rate to be used for token bucket for the introduction point rate-limiting. Introduction points use this value when no `DOS_PARAMS` extension is sent in the ESTABLISH_INTRO message. Min: 0. Max: INT32_MAX. Default: 200 First appeared: 0.4.2.1-alpha.

“HiddenServiceEnableIntroDoSRatePerSec” – Default maximum rate per second to be used for token bucket for the introduction point rate-limiting. Introduction points use this value when no `DOS_PARAMS` extension is sent. Min: 0. Max: INT32_MAX. Default: 25 First appeared: 0.4.2.1-alpha.

## Vanguard parameters
[code]
        "vanguards-enabled" -- The type of vanguards to use by default when
        building onion service circuits
            0: No vanguards.
            1: Lite vanguards.
            2: Full vanguards.

[/code]
[code]
        "vanguards-hs-service" -- If higher than vanguards-enabled, and we are
        running an onion service, we use this level for all our onion service
        circuits
            0: No vanguards.
            1: Lite vanguards.
            2: Full vanguards.

[/code]

“guard-hs-l2-number” – The number of guards in the L2 guardset Min: 1. Max: INT32_MAX. Default: 4

“guard-hs-l2-lifetime-min” – The minimum lifetime of L2 guards Min: 1. Max: INT32_MAX. Default: 86400 (1 day)

“guard-hs-l2-lifetime-max” – The maximum lifetime of L2 guards Min: 1. Max: INT32_MAX. Default: 1036800 (12 days)

“guard-hs-l3-number” – The number of guards in the L3 guardset Min: 1. Max: INT32_MAX. Default: 8

“guard-hs-l3-lifetime-min” – The minimum lifetime of L3 guards Min: 1. Max: INT32_MAX. Default: 3600 (1 hour)

“guard-hs-l3-lifetime-max” – The maximum lifetime of L3 guards Min: 1. Max: INT32_MAX. Default: 172800 (48 hours)

## Denial-of-service parameters

Denial of Service mitigation parameters. Introduced in 0.3.3.2-alpha:

“DoSCircuitCreationEnabled” – Enable the circuit creation DoS mitigation.

“DoSCircuitCreationMinConnections” – Minimum threshold of concurrent connections before a client address can be flagged as executing a circuit creation DoS

“DoSCircuitCreationRate” – Allowed circuit creation rate per second per client IP address once the minimum concurrent connection threshold is reached.

“DoSCircuitCreationBurst” – The allowed circuit creation burst per client IP address once the minimum concurrent connection threshold is reached.
[code]
        "DoSCircuitCreationDefenseType" -- Defense type applied to a
        detected client address for the circuit creation mitigation.
            1: No defense.
            2: Refuse circuit creation for the length of
              "DoSCircuitCreationDefenseTimePeriod".

[/code]

“DoSCircuitCreationDefenseTimePeriod” – The base time period that the DoS defense is activated for.

“DoSConnectionEnabled” – Enable the connection DoS mitigation.

“DoSConnectionMaxConcurrentCount” – The maximum threshold of concurrent connection from a client IP address.
[code]
        "DoSConnectionDefenseType" -- Defense type applied to a detected
        client address for the connection mitigation. Possible values are:
            1: No defense.
            2: Immediately close new connections.

[/code]

“DoSRefuseSingleHopClientRendezvous” – Refuse establishment of rendezvous points for single hop clients.

“DoSStreamCreationEnabled” – Enable the stream creation DoS mitigation. First appeared: 0.4.9.0-alpha-dev.

“DoSStreamCreationRate” – Allowed stream creation rate per second per circuit. First appeared: 0.4.9.0-alpha-dev.

“DoSStreamCreationBurst” – The allowed stream creation burst per circuit. First appeared: 0.4.9.0-alpha-dev.
[code]
        "DoSStreamCreationDefenseType" -- Defense type applied to a
        stream for the stream creation mitigation.
            1: No defense.
            2: Reject the stream or resolve request.
            3: Close the underlying circuit.
        First appeared: 0.4.9.0-alpha-dev.

[/code]

## Padding-related parameters

“circpad_max_circ_queued_cells” – The circuitpadding module will stop sending more padding relay cells if more than this many cells are in the circuit queue a given circuit. Min: 0. Max: 50000. Default 1000. First appeared: 0.4.0.3-alpha.

“circpad_global_allowed_cells” – This is the number of padding relay cells that must be sent before the ‘circpad_global_max_padding_percent’ parameter is applied. Min: 0. Max: 65535. Default: 0

“circpad_global_max_padding_pct” – This is the maximum ratio of padding relay cells to total relay cells, specified as a percent. If the global ratio of padding cells to total cells across all circuits exceeds this percent value, no more padding is sent until the ratio becomes lower. 0 means no limit. Min: 0. Max: 100. Default: 0

“circpad_padding_disabled” – If set to 1, no circuit padding machines will negotiate, and all current padding machines will cease padding immediately. Min: 0. Max: 1. Default: 0

“circpad_padding_reduced” – If set to 1, only circuit padding machines marked as “reduced”/“low overhead” will be used. (Currently no such machines are marked as “reduced overhead”). Min: 0. Max: 1. Default: 0

“nf_conntimeout_clients”

  * The number of seconds to keep never-used circuits opened and available for clients to use. Note that the actual client timeout is randomized uniformly from this value to twice this value.
  * The number of seconds to keep idle (not currently used) canonical channels are open and available. (We do this to ensure a sufficient time duration of padding, which is the ultimate goal.)
  * This value is also used to determine how long, after a port has been used, we should attempt to keep building predicted circuits for that port. (See path-spec.txt section 2.1.1.) This behavior was originally added to work around implementation limitations, but it serves as a reasonable default regardless of implementation.
  * For all use cases, reduced padding clients use half the consensus value.
  * Implementations MAY mark circuits held open past the reduced padding quantity (half the consensus value) as “not to be used for streams”, to prevent their use from becoming a distinguisher. Min: 60. Max: 86400. Default: 1800

“nf_conntimeout_relays” – The number of seconds that idle relay-to-relay connections are kept open. Min: 60. Max: 604800. Default: 3600

“nf_ito_low” – The low end of the range to send padding when inactive, in ms. Min: 0. Max: 60000. Default: 1500

“nf_ito_high” – The high end of the range to send padding, in ms. If nf_ito_low == nf_ito_high == 0, padding will be disabled. Min: nf_ito_low. Max: 60000. Default: 9500

“nf_ito_low_reduced” – For reduced padding clients: the low end of the range to send padding when inactive, in ms. Min: 0. Max: 60000. Default: 9000

“nf_ito_high_reduced” – For reduced padding clients: the high end of the range to send padding, in ms. Min: nf_ito_low_reduced. Max: 60000. Default: 14000

“nf_pad_before_usage” – If set to 1, OR connections are padded before the client uses them for any application traffic. If 0, OR connections are not padded until application data begins. Min: 0. Max: 1. Default: 1

“nf_pad_relays” – If set to 1, we also pad inactive relay-to-relay connections. Min: 0. Max: 1. Default: 0

“nf_pad_single_onion” – DOCDOC

## Guard-related parameters

(See guard-spec.txt for more information on the vocabulary used here.)

“UseGuardFraction” – If true, clients use `GuardFraction` information from the consensus in order to decide how to weight guards when picking them. Min: 0. Max: 1. Default: 0. First appeared: 0.2.6

“guard-lifetime-days” – Controls guard lifetime. If an unconfirmed guard has been sampled more than this many days ago, it should be removed from the guard sample. Min: 1. Max: 3650. Default: 120. First appeared: 0.3.0

“guard-confirmed-min-lifetime-days” – Controls confirmed guard lifetime: if a guard was confirmed more than this many days ago, it should be removed from the guard sample. Min: 1. Max: 3650. Default: 60. First appeared: 0.3.0

“guard-internet-likely-down-interval” – If Tor has been unable to build a circuit for this long (in seconds), assume that the internet connection is down, and treat guard failures as unproven. Min: 1. Max: INT32_MAX. Default: 600. First appeared: 0.3.0

“guard-max-sample-size” – Largest number of guards that clients should try to collect in their sample. Min: 1. Max: INT32_MAX. Default: 60. First appeared: 0.3.0

“guard-max-sample-threshold-percent” – Largest bandwidth-weighted fraction of guards that clients should try to collect in their sample. Min: 1. Max: 100. Default: 20. First appeared: 0.3.0

“guard-meaningful-restriction-percent” – If the client has configured tor to exclude so many guards that the available guard bandwidth is less than this percentage of the total, treat the guard sample as “restricted”, and keep it in a separate sample. Min: 1. Max: 100. Default: 20. First appeared: 0.3.0

“guard-extreme-restriction-percent” – Warn the user if they have configured tor to exclude so many guards that the available guard bandwidth is less than this percentage of the total. Min: 1. Max: 100. Default: 1. First appeared: 0.3.0. MAX was INT32_MAX, which would have no meaningful effect. MAX lowered to 100 in 0.4.7.

“guard-min-filtered-sample-size” – If fewer than this number of guards is available in the sample after filtering out unusable guards, the client should try to add more guards to the sample (if allowed). Min: 1. Max: INT32_MAX. Default: 20. First appeared: 0.3.0

“guard-n-primary-guards” – The number of confirmed guards that the client should treat as “primary guards”. Min: 1. Max: INT32_MAX. Default: 3. First appeared: 0.3.0
[code]
        "guard-n-primary-guards-to-use", "guard-n-primary-dir-guards-to-use"
        -- number of primary guards and primary directory guards that the
        client should be willing to use in parallel.  Other primary guards
        won't get used unless the earlier ones are down.
        "guard-n-primary-guards-to-use":
           Min 1, Max INT32_MAX: Default: 1.
        "guard-n-primary-dir-guards-to-use"
           Min 1, Max INT32_MAX: Default: 3.
        First appeared: 0.3.0

[/code]

“guard-nonprimary-guard-connect-timeout” – When trying to confirm nonprimary guards, if a guard doesn’t answer for more than this long in seconds, treat lower-priority guards as usable. Min: 1. Max: INT32_MAX. Default: 15 First appeared: 0.3.0

“guard-nonprimary-guard-idle-timeout” – When trying to confirm nonprimary guards, if a guard doesn’t answer for more than this long in seconds, treat it as down. Min: 1. Max: INT32_MAX. Default: 600 First appeared: 0.3.0

“guard-remove-unlisted-guards-after-days” – If a guard has been unlisted in the consensus for at least this many days, remove it from the sample. Min: 1. Max: 3650. Default: 20. First appeared: 0.3.0

## Obsolete parameters

“NumDirectoryGuards”, “NumEntryGuards” – Number of guard nodes clients should use by default. If NumDirectoryGuards is 0, we default to NumEntryGuards. NumDirectoryGuards: Min: 0. Max: 10. Default: 0 NumEntryGuards: Min: 1. Max: 10. Default: 3 First-appeared: 0.2.4.23, 0.2.5.6-alpha Removed in: 0.3.0

“GuardLifetime” – Duration for which clients should choose guard nodes, in seconds. Min: 30 days. Max: 1826 days. Default: 60 days. First-appeared: 0.2.4.12-alpha Removed in: 0.3.0.

“UseNTorHandshake” – If true, then versions of Tor that support NTor will prefer to use it by default. Min: 0, Max: 1. Default: 1. First-appeared: 0.2.4.8-alpha Removed in: 0.2.9.

“Support022HiddenServices” – Used to implement a mass switch-over from sending timestamps to hidden services by default to sending no timestamps at all. If this option is absent, or is set to 1, clients with the default configuration send timestamps; otherwise, they do not. Min: 0, Max: 1. Default: 1. First-appeared: 0.2.4.18-rc Removed in: 0.2.6

## Enabling and disabling subprotocol capabilities

Sometimes we want the ability to enable or disable a feature across all relays or clients.

To do so, when the feature corresponds to a subprotocol capability we can follow the following pattern.

Let CAP be the string formed by putting the capability in lowercase and replacing its `=` with a `-`. (For example, a hypothetical `Relay=33` capability would be represented with a CAP string of `relay-33`.)

We use CAP to derive some or all of these parameters. All are booleans, and have Min 0, Max 1, and default of 0 or 1.

  * `client-CAP`: Tells clients to use the capability where available.
  * `relay-CAP`: Tells relays to provide the capability if possible.
  * `advertise-CAP`: Tells relays to advertise the capability if they provide it.
  * `hsc-CAP`: Tells clients to use the capability with onion services where available.
  * `hss-CAP`: Tells onion services to provide the capability if possible.
  * `hss-advertise-CAP`: Tells onion services to advertise the capability if they provide it.

These parameters do not automatically exist for every capability. Instead, they are added to the specification when a new capability seems as if it may need to be enabled or disabled in this way.

> For rationales, discussion, and example timelines for disabling or enabling features, see proposal 346.

---

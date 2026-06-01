# 03 Directory Protocol

This directory protocol is used by Tor version 0.2.0.x-alpha and later. See dir-spec-v1.txt for information on the protocol used up to the 0.1.0.x series, and dir-spec-v2.txt for information on the protocol used by the 0.1.1.x and 0.1.2.x series.

This document merges and supersedes the following proposals:

  * 101 Voting on the Tor Directory System
  * 103 Splitting identity key from regularly used signing key
  * 104 Long and Short Router Descriptors

XXX timeline XXX fill in XXXXs

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

## History

The earliest versions of Onion Routing shipped with a list of known routers and their keys. When the set of routers changed, users needed to fetch a new list.

### The Version 1 Directory protocol

Early versions of Tor (0.0.2) introduced “Directory authorities”: servers that served signed “directory” documents containing a list of signed “server descriptors”, along with short summary of the status of each router. Thus, clients could get up-to-date information on the state of the network automatically, and be certain that the list they were getting was attested by a trusted directory authority.

Later versions (0.0.8) added directory caches, which download directories from the authorities and serve them to clients. Non-caches fetch from the caches in preference to fetching from the authorities, thus distributing bandwidth requirements.

Also added during the version 1 directory protocol were “router status” documents: short documents that listed only the up/down status of the routers on the network, rather than a complete list of all the descriptors. Clients and caches would fetch these documents far more frequently than they would fetch full directories.

### The Version 2 Directory Protocol

During the Tor 0.1.1.x series, Tor revised its handling of directory documents in order to address two major problems:
[code]
          * Directories had grown quite large (over 1MB), and most directory
            downloads consisted mainly of server descriptors that clients
            already had.

          * Every directory authority was a trust bottleneck: if a single
            directory authority lied, it could make clients believe for a time
            an arbitrarily distorted view of the Tor network.  (Clients
            trusted the most recent signed document they downloaded.) Thus,
            adding more authorities would make the system less secure, not
            more.

[/code]

To address these, we extended the directory protocol so that authorities now published signed “network status” documents. Each network status listed, for every router in the network: a hash of its identity key, a hash of its most recent descriptor, and a summary of what the authority believed about its status. Clients would download the authorities’ network status documents in turn, and believe statements about routers iff they were attested to by more than half of the authorities.

Instead of downloading all server descriptors at once, clients downloaded only the descriptors that they did not have. Descriptors were indexed by their digests, in order to prevent malicious caches from giving different versions of a server descriptor to different clients.

Routers began working harder to upload new descriptors only when their contents were substantially changed.

### Goals of the version 3 protocol

Version 3 of the Tor directory protocol tries to solve the following issues:
[code]
          * A great deal of bandwidth used to transmit server descriptors was
            used by two fields that are not actually used by Tor routers
            (namely read-history and write-history).  We save about 60% by
            moving them into a separate document that most clients do not
            fetch or use.

          * It was possible under certain perverse circumstances for clients
            to download an unusual set of network status documents, thus
            partitioning themselves from clients who have a more recent and/or
            typical set of documents.  Even under the best of circumstances,
            clients were sensitive to the ages of the network status documents
            they downloaded.  Therefore, instead of having the clients
            correlate multiple network status documents, we have the
            authorities collectively vote on a single consensus network status
            document.

          * The most sensitive data in the entire network (the identity keys
            of the directory authorities) needed to be stored unencrypted so
            that the authorities can sign network-status documents on the fly.
            Now, the authorities' identity keys are stored offline, and used
            to certify medium-term signing keys that can be rotated.

[/code]

## Accepting server descriptor and extra-info document uploads

When a router posts a signed descriptor to a directory authority, the authority first checks whether it is well-formed and correctly self-signed. If it is, the authority next verifies that the nickname in question is not already assigned to a router with a different public key. Finally, the authority MAY check that the router is not blacklisted because of its key, IP, or another reason.

An authority also keeps a record of all the Ed25519/RSA1024 identity key pairs that it has seen before. It rejects any descriptor that has a known Ed/RSA identity key that it has already seen accompanied by a different RSA/Ed identity key in an older descriptor.

At a future date, authorities will begin rejecting all descriptors whose RSA key was previously accompanied by an Ed25519 key, if the descriptor does not list an Ed25519 key.

At a future date, authorities will begin rejecting all descriptors that do not list an Ed25519 key.

If the descriptor passes these tests, and the authority does not already have a descriptor for a router with this public key, it accepts the descriptor and remembers it.

If the authority _does_ have a descriptor with the same public key, the newly uploaded descriptor is remembered if its publication time is more recent than the most recent old descriptor for that router, and either:
[code]
          - There are non-cosmetic differences between the old descriptor and the
            new one.
          - Enough time has passed between the descriptors' publication times.
            (Currently, 2 hours.)

[/code]

Differences between server descriptors are “non-cosmetic” if they would be sufficient to force an upload as described in section 2.1 above.

Note that the “cosmetic difference” test only applies to uploaded descriptors, not to descriptors that the authority downloads from other authorities.

When a router posts a signed extra-info document to a directory authority, the authority again checks it for well-formedness and correct signature, and checks that its matches the extra-info-digest in some router descriptor that it believes is currently useful. If so, it accepts it and stores it and serves it as requested. If not, it drops it.

## Assigning flags in a vote

(This section describes how directory authorities choose which status flags to apply to routers. Later directory authorities MAY do things differently, so long as clients keep working well. Clients MUST NOT depend on the exact behaviors in this section.)

In the below definitions, a router is considered “active” if it is running, valid, and not hibernating.

When we speak of a router’s bandwidth in this section, we mean either its measured bandwidth, or its advertised bandwidth. If a sufficient threshold (configurable with MinMeasuredBWsForAuthToIgnoreAdvertised, 500 by default) of routers have measured bandwidth values, then the authority bases flags on _measured_ bandwidths, and treats nodes with non-measured bandwidths as if their bandwidths were zero. Otherwise, it uses measured bandwidths for nodes that have them, and advertised bandwidths for other nodes.

When computing thresholds based on percentiles of nodes, an authority only considers nodes that are active, that have not been omitted as a sybil (see below), and whose bandwidth is at least 4 KB. Nodes that don’t meet these criteria do not influence any threshold calculations (including calculation of stability and uptime and bandwidth thresholds) and also do not have their Exit status change.

“Valid” – a router is ‘Valid’ if it is running a version of Tor not known to be broken, and the directory authority has not blacklisted it as suspicious.
[code]
       "Named" --
       "Unnamed" -- Directory authorities no longer assign these flags.
          They were once used to determine whether a relay's nickname was
          canonically linked to its public key.

[/code]

“Running” – A router is ‘Running’ if the authority managed to connect to it successfully within the last 45 minutes on all its published ORPorts. Authorities check reachability on:
[code]
         * the IPv4 ORPort in the "r" line, and
         * the IPv6 ORPort considered for the "a" line, if:
           * the router advertises at least one IPv6 ORPort, and
           * AuthDirHasIPv6Connectivity 1 is set on the authority.

[/code]

A minority of voting authorities that set AuthDirHasIPv6Connectivity will drop unreachable IPv6 ORPorts from the full consensus. Consensus method 27 in 0.3.3.x puts IPv6 ORPorts in the microdesc consensus, so that authorities can drop unreachable IPv6 ORPorts from all consensus flavors. Consensus method 28 removes IPv6 ORPorts from microdescriptors.

“Stable” – A router is ‘Stable’ if it is active, and either its Weighted MTBF is at least the median for known active routers or its Weighted MTBF corresponds to at least 7 days. Routers are never called Stable if they are running a version of Tor known to drop circuits stupidly. (0.1.1.10-alpha through 0.1.1.16-rc are stupid this way.)

To calculate weighted MTBF, compute the weighted mean of the lengths of all intervals when the router was observed to be up, weighting intervals by $\alpha^n$, where $n$ is the amount of time that has passed since the interval ended, and $\alpha$ is chosen so that measurements over approximately one month old no longer influence the weighted MTBF much.

[XXXX what happens when we have less than 4 days of MTBF info.]

“Exit” – A router is called an ‘Exit’ iff it allows exits to at least one /8 address space on each of ports 80 and 443. (Up until Tor version 0.3.2, the flag was assigned if relays exit to at least two of the ports 80, 443, and 6667.)

“Fast” – A router is ‘Fast’ if it is active, and its bandwidth is either in the top 7/8ths for known active routers or at least 100KB/s.

“Guard” – A router is a possible Guard if all of the following apply:
[code]
           - It is Fast,
           - It is Stable,
           - Its Weighted Fractional Uptime is at least the median for "familiar"
             active routers,
           - It is "familiar",
           - Its bandwidth is at least AuthDirGuardBWGuarantee (if set, 2 MB by
             default), OR its bandwidth is among the 25% fastest relays,
           - It qualifies for the V2Dir flag as described below (this
             constraint was added in 0.3.3.x, because in 0.3.0.x clients
             started avoiding guards that didn't also have the V2Dir flag).

[/code]

To calculate weighted fractional uptime, compute the fraction of time that the router is up in any given day, weighting so that downtime and uptime in the past counts less.

A node is ‘familiar’ if 1/8 of all active nodes have appeared more recently than it, OR it has been around for a few weeks.

“Authority” – A router is called an ‘Authority’ if the authority generating the network-status document believes it is an authority.

“V2Dir” – A router supports the v2 directory protocol or higher if it has an open directory port OR a tunnelled-dir-server line in its router descriptor, and it is running a version of the directory protocol that supports the functionality clients need. (Currently, every supported version of Tor supports the functionality that clients need, but some relays might set “DirCache 0” or set really low rate limiting, making them unqualified to be a directory mirror, i.e. they will omit the tunnelled-dir-server line from their descriptor.)

“HSDir” – A router is a v2 hidden service directory if it stores and serves v2 hidden service descriptors, has the Stable and Fast flag, and the authority believes that it’s been up for at least 96 hours (or the current value of MinUptimeHidServDirectoryV2).

“MiddleOnly” – An authority should vote for this flag if it believes that a relay is unsuitable for use except as a middle relay. When voting for this flag, the authority should also vote against “Exit”, “Guard”, “HsDir”, and “V2Dir”. When voting for this flag, if the authority votes on the “BadExit” flag, the authority should vote in favor of “BadExit”. (This flag was added in 0.4.7.2-alpha.)

“NoEdConsensus” – authorities should not vote on this flag; it is produced as part of the consensus for consensus method 22 or later.

“StaleDesc” – authorities should vote to assign this flag if the published time on the descriptor is over 18 hours in the past. (This flag was added in 0.4.0.1-alpha.)

“Sybil” – authorities SHOULD NOT accept more than 2 relays on a single IP. If this happens, the authority _should_ vote for the excess relays, but should omit the Running or Valid flags and instead should assign the “Sybil” flag. When there are more than 2 (or AuthDirMaxServersPerAddr) relays to choose from, authorities should first prefer authorities to non-authorities, then prefer Running to non-Running, and then prefer high-bandwidth to low-bandwidth relays. In this comparison, measured bandwidth is used unless it is not present for a router, in which case advertised bandwidth is used.

Thus, the network-status vote includes all non-blacklisted, non-expired, non-superseded descriptors.

The bandwidth in a “w” line should be taken as the best estimate of the router’s actual capacity that the authority has. For now, this should be the lesser of the observed bandwidth and bandwidth rate limit from the server descriptor. It is given in kilobytes per second, and capped at some arbitrary value (currently 10 MB/s).

The Measured= keyword on a “w” line vote is currently computed by multiplying the previous published consensus bandwidth by the ratio of the measured average node stream capacity to the network average. If 3 or more authorities provide a Measured= keyword for a router, the authorities produce a consensus containing a “w” Bandwidth= keyword equal to the median of the Measured= votes.

As a special case, if the “w” line in a vote is about a relay with the Authority flag, it should not include a Measured= keyword. The goal is to leave such relays marked as Unmeasured, so they can reserve their attention for authority-specific activities. “w” lines for votes about authorities may include the bandwidth authority’s measurement using a different keyword, e.g. MeasuredButAuthority=, so it can still be reported and recorded for posterity.

The ports listed in a “p” line should be taken as those ports for which the router’s exit policy permits ‘most’ addresses, ignoring any accept not for all addresses, ignoring all rejects for private netblocks. “Most” addresses are permitted if no more than 2^25 IPv4 addresses (two /8 networks) were blocked. The list is encoded as described in section 3.8.2.

## Client operation

Every Tor that is not a directory server (that is, those that do not have a DirPort set) implements this section.

## Downloading network-status documents

Each client maintains a list of directory authorities. Insofar as possible, clients SHOULD all use the same list.
[code]
      [Newer versions of Tor (0.2.8.1-alpha and later):
       Each client also maintains a list of default fallback directory mirrors
       (fallbacks). Each released version of Tor MAY have a different list,
       depending on the mirrors that satisfy the fallback directory criteria at
       release time.]

[/code]

Clients try to have a live consensus network-status document at all times. A network-status document is “live” if the time in its valid-after field has passed, and the time in its valid-until field has not passed.

When a client has no consensus network-status document, it downloads it from a randomly chosen fallback directory mirror or authority. Clients prefer fallbacks to authorities, trying them earlier and more frequently. In all other cases, the client downloads from caches randomly chosen from among those believed to be V3 directory servers. (This information comes from the network-status documents.)

After receiving any response client MUST discard any network-status documents that it did not request.

On failure, the client waits briefly, then tries that network-status document again from another cache. The client does not build circuits until it has a live network-status consensus document, and it has descriptors for a significant proportion of the routers that it believes are running (this is configurable using torrc options and consensus parameters).
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

(Note: clients can and should pick caches based on the network-status information they have: once they have first fetched network-status info from an authority or fallback, they should not need to go to the authority directly again, and should only choose the fallback at random, based on its consensus weight in the current consensus.)

To avoid swarming the caches whenever a consensus expires, the clients download new consensuses at a randomly chosen time after the caches are expected to have a fresh consensus, but before their consensus will expire. (This time is chosen uniformly at random from the interval between the time 3/4 into the first interval after the consensus is no longer fresh, and 7/8 of the time remaining after that before the consensus is invalid.)
[code]
       [For example, if a client has a consensus that became valid at 1:00,
        and is fresh until 2:00, and expires at 4:00, that client will fetch
        a new consensus at a random time between 2:45 and 3:50, since 3/4
        of the one-hour interval is 45 minutes, and 7/8 of the remaining 75
        minutes is 65 minutes.]

[/code]

Clients may choose to download the microdescriptor consensus instead of the general network status consensus. In that case they should use the same update strategy as for the normal consensus. They should not download more than one consensus flavor.

When a client does not have a live consensus, it will generally use the most recent consensus it has if that consensus is “reasonably live”. A “reasonably live” consensus is one that expired less than 24 hours ago.

## Downloading server descriptors or microdescriptors

Clients try to have the best descriptor for each router. A descriptor is “best” if:

  * It is listed in the consensus network-status document.

Periodically (currently every 10 seconds) clients check whether there are any “downloadable” descriptors. A descriptor is downloadable if:
[code]
          - It is the "best" descriptor for some router.
          - The descriptor was published at least 10 minutes in the past.
            (This prevents clients from trying to fetch descriptors that the
            mirrors have probably not yet retrieved and cached.)
          - The client does not currently have it.
          - The client is not currently trying to download it.
          - The client would not discard it immediately upon receiving it.
          - The client thinks it is running and valid (see section 5.4.1 below).

[/code]

If at least 16 known routers have downloadable descriptors, or if enough time (currently 10 minutes) has passed since the last time the client tried to download descriptors, it launches requests for all downloadable descriptors.

When downloading multiple server descriptors, the client chooses multiple mirrors so that:
[code]
         - At least 3 different mirrors are used, except when this would result
           in more than one request for under 4 descriptors.
         - No more than 128 descriptors are requested from a single mirror.
         - Otherwise, as few mirrors as possible are used.
       After choosing mirrors, the client divides the descriptors among them
       randomly.

[/code]

After receiving any response the client MUST discard any descriptors that it did not request.

When a descriptor download fails, the client notes it, and does not consider the descriptor downloadable again until a certain amount of time has passed. (Currently 0 seconds for the first failure, 60 seconds for the second, 5 minutes for the third, 10 minutes for the fourth, and 1 day thereafter.) Periodically (currently once an hour) clients reset the failure count.

Clients retain the most recent descriptor they have downloaded for each router so long as it is listed in the consensus. If it is not listed, they keep it so long as it is not too old (currently, ROUTER_MAX_AGE=48 hours) and no better router descriptor has been downloaded for the same relay. Caches retain descriptors until they are at least OLD_ROUTER_DESC_MAX_AGE=5 days old.

Clients which chose to download the microdescriptor consensus instead of the general consensus must download the referenced microdescriptors instead of server descriptors. Clients fetch and cache microdescriptors preemptively from dir mirrors when starting up, like they currently fetch descriptors. After bootstrapping, clients only need to fetch the microdescriptors that have changed.

When a client gets a new microdescriptor consensus, it looks to see if there are any microdescriptors it needs to learn, and launches a request for them.

Clients maintain a cache of microdescriptors along with metadata like when it was last referenced by a consensus, and which identity key it corresponds to. They keep a microdescriptor until it hasn’t been mentioned in any consensus for a week. Future clients might cache them for longer or shorter times.

## Downloading extra-info documents

Any client that uses extra-info documents should implement this section.

Note that generally, clients don’t need extra-info documents.

Periodically, the Tor instance checks whether it is missing any extra-info documents: in other words, if it has any server descriptors with an extra-info-digest field that does not match any of the extra-info documents currently held. If so, it downloads whatever extra-info documents are missing. Clients try to download from caches. We follow the same splitting and back-off rules as in section 5.2.

## Retrying failed downloads

This section applies to caches as well as to clients.

When a client fails to download a resource (a consensus, a router descriptor, a microdescriptor, etc) it waits for a certain amount of time before retrying the download. To determine the amount of time to wait, clients use a randomized exponential backoff algorithm. (Specifically, they use a variation of the “decorrelated jitter” algorithm from <https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/> .)

The specific formula used to compute the ’i+1’th delay is:
[code]
            Delay_0     = 0

            Delay_{i+1} = MIN(cap, random_between(lower_bound, upper_bound)))
              where upper_bound = MAX(lower_bound + epsilon, Delay_i * 3)
                    lower_bound = MAX(1, base_delay).

[/code]

After the first download attempt fails, we wait for `Delay_1` before retrying; after the second failed attempt, we wait for `Delay_2`, and so on.

The value of `cap` is whatever largest duration we can conveniently represent (such as `INT_MAX` seconds, or `U32_MAX` milliseconds); the value of `epsilon` is the unit of time we’re using for our calculations (typically 1 second or 1 millisecond); the value of `base_delay` depends on what is being downloaded, whether the client is fully bootstrapped, how the client is configured, and where it is downloading from. Current base_delay values are:
[code]
       Consensus objects, as a non-bridge cache:
             0 (TestingServerConsensusDownloadInitialDelay)

       Consensus objects, as a client or bridge that has bootstrapped:
             0 (TestingClientConsensusDownloadInitialDelay)

       Consensus objects, as a client or bridge that is bootstrapping,
       when connecting to an authority because no "fallback" caches are
       known:
             0 (ClientBootstrapConsensusAuthorityOnlyDownloadInitialDelay)

       Consensus objects, as a client or bridge that is bootstrapping,
       when "fallback" caches are known but connecting to an authority
       anyway:
             6 (ClientBootstrapConsensusAuthorityDownloadInitialDelay)

       Consensus objects, as a client or bridge that is bootstrapping,
       when downloading from a "fallback" cache.
             0 (ClientBootstrapConsensusFallbackDownloadInitialDelay)

       Bridge descriptors, as a bridge-using client when at least one bridge
       is usable:
             10800 (TestingBridgeDownloadInitialDelay)

       Bridge descriptors, otherwise:
             0 (TestingBridgeBootstrapDownloadInitialDelay)

       Other objects, as cache or authority:
             0 (TestingServerDownloadInitialDelay)

       Other objects, as client:
             0 (TestingClientDownloadInitialDelay)

[/code]

## Computing a consensus from a set of votes

Given a set of votes, authorities compute the contents of the consensus.

The consensus status, along with as many signatures as the server currently knows (see section 3.10 below), should be available at

`http://<hostname>/tor/status-vote/next/consensus`

The contents of the consensus document are as follows:

The “valid-after”, “valid-until”, and “fresh-until” times are taken as the median of the respective values from all the votes.

The times in the “voting-delay” line are taken as the median of the VoteSeconds and DistSeconds times in the votes.

Known-flags is the union of all flags known by any voter.

Entries are given on the “params” line for every keyword on which a majority of authorities (total authorities, not just those participating in this vote) voted on, or if at least three authorities voted for that parameter. The values given are the low-median of all votes on that keyword.

(In consensus methods 7 to 11 inclusive, entries were given on the “params” line for every keyword on which _any_ authority voted, the value given being the low-median of all votes on that keyword.)
[code]
        "client-versions" and "server-versions" are sorted in ascending
         order; A version is recommended in the consensus if it is recommended
         by more than half of the voting authorities that included a
         client-versions or server-versions lines in their votes.

[/code]

With consensus methods 19 through 33, a package line is generated for a given PACKAGENAME/VERSION pair if at least three authorities list such a package in their votes. (Call these lines the “input” lines for PACKAGENAME.) The consensus will contain every “package” line that is listed verbatim by more than half of the authorities listing a line for the PACKAGENAME/VERSION pair, and no others.

The authority item groups (dir-source, contact, fingerprint, vote-digest) are taken from the votes of the voting authorities. These groups are sorted by the digests of the authorities identity keys, in ascending order. If the consensus method is 3 or later, a dir-source line must be included for every vote with legacy-key entry, using the legacy-key’s fingerprint, the voter’s ordinary nickname with the string “-legacy” appended, and all other fields as from the original vote’s dir-source line.
[code]
         A router status entry:
            * is included in the result if some router status entry with the same
              identity is included by more than half of the authorities (total
              authorities, not just those whose votes we have).
              (Consensus method earlier than 21)

            * is included according to the rules in section 3.8.0.1 and
              3.8.0.2 below. (Consensus method 22 or later)

            * For any given RSA identity digest, we include at most
              one router status entry.

            * For any given Ed25519 identity, we include at most one router
              status entry.

            * A router entry has a flag set if that is included by more than half
              of the authorities who care about that flag.

            * Two router entries are "the same" if they have the same
              (descriptor digest, published time, nickname, IP, ports> tuple.
              We choose the tuple for a given router as whichever tuple appears
              for that router in the most votes.  We break ties first in favor of
              the more recently published, then in favor of smaller server
              descriptor digest.

           [
            * The Named flag appears if it is included for this routerstatus by
              _any_ authority, and if all authorities that list it list the same
              nickname. However, if consensus-method 2 or later is in use, and
              any authority calls this identity/nickname pair Unnamed, then
              this routerstatus does not get the Named flag.

            * If consensus-method 2 or later is in use, the Unnamed flag is
              set for a routerstatus if any authorities have voted for a different
              identities to be Named with that nickname, or if any authority
              lists that nickname/ID pair as Unnamed.

              (With consensus-method 1, Unnamed is set like any other flag.)

              [But note that authorities no longer vote for the Named flag,
              and the above two bulletpoints are now irrelevant.]
           ]

            * The version is given as whichever version is listed by the most
              voters, with ties decided in favor of more recent versions.

            * If consensus-method 4 or later is in use, then routers that
              do not have the Running flag are not listed at all.

            * If consensus-method 5 or later is in use, then the "w" line
              is generated using a low-median of the bandwidth values from
              the votes that included "w" lines for this router.

            * If consensus-method 5 or later is in use, then the "p" line
              is taken from the votes that have the same policy summary
              for the descriptor we are listing.  (They should all be the
              same.  If they are not, we pick the most commonly listed
              one, breaking ties in favor of the lexicographically larger
              vote.)  The port list is encoded as specified in section 3.8.2.

            * If consensus-method 6 or later is in use and if 3 or more
              authorities provide a Measured= keyword in their votes for
              a router, the authorities produce a consensus containing a
              Bandwidth= keyword equal to the median of the Measured= votes.

            * If consensus-method 7 or later is in use, the params line is
              included in the output.

            * If the consensus method is under 11, bad exits are considered as
              possible exits when computing bandwidth weights.  Otherwise, if
              method 11 or later is in use, any router that is determined to get
              the BadExit flag doesn't count when we're calculating weights.

            * If consensus method 12 or later is used, only consensus
              parameters that more than half of the total number of
              authorities voted for are included in the consensus.

            [ As of 0.2.6.1-alpha, authorities no longer advertise or negotiate
              any consensus methods lower than 13. ]

            * If consensus method 13 or later is used, microdesc consensuses
              omit any router for which no microdesc was agreed upon.

            * If consensus method 14 or later is used, the ns consensus and
              microdescriptors may include an "a" line for each router, listing
              an IPv6 OR port.

            * If consensus method 15 or later is used, microdescriptors
              include "p6" lines including IPv6 exit policies.

            * If consensus method 16 or later is used, ntor-onion-key
              are included in microdescriptors

            * If consensus method 17 or later is used, authorities impose a
              maximum on the Bandwidth= values that they'll put on a 'w'
              line for any router that doesn't have at least 3 measured
              bandwidth values in votes. They also add an "Unmeasured=1"
              flag to such 'w' lines.

            * If consensus method 18 or later is used, authorities include
              "id" lines in microdescriptors. This method adds RSA ids.

            * If consensus method 19 or later is used, authorities may include
              "package" lines in consensuses.

            * If consensus method 20 or later is used, authorities may include
              GuardFraction information in microdescriptors.

            * If consensus method 21 or later is used, authorities may include
              an "id" line for ed25519 identities in microdescriptors.

            [ As of 0.2.8.2-alpha, authorities no longer advertise or negotiate
              consensus method 21, because it contains bugs. ]

            * If consensus method 22 or later is used, and the votes do not
              produce a majority consensus about a relay's Ed25519 key (see
              3.8.0.1 below), the consensus must include a NoEdConsensus flag on
              the "s" line for every relay whose listed Ed key does not reflect
              consensus.

            * If consensus method 23 or later is used, authorities include
              shared randomness protocol data on their votes and consensus.

            * If consensus-method 24 or later is in use, then routers that
              do not have the Valid flag are not listed at all.

            [ As of 0.3.4.1-alpha, authorities no longer advertise or negotiate
              any consensus methods lower than 25. ]

            * If consensus-method 25 or later is in use, then we vote
              on recommended-protocols and required-protocols lines in the
              consensus.  We also include protocols lines in routerstatus
              entries.

            * If consensus-method 26 or later is in use, then we initialize
              bandwidth weights to 1 in our calculations, to avoid
              division-by-zero errors on unusual networks.

            * If consensus method 27 or later is used, the microdesc consensus
              may include an "a" line for each router, listing an IPv6 OR port.

            [ As of 0.4.3.1-alpha, authorities no longer advertise or negotiate
              any consensus methods lower than 28. ]

            * If consensus method 28 or later is used, microdescriptors no longer
              include "a" lines.

            * If consensus method 29 or later is used, microdescriptor "family"
              lines are canonicalized to improve compression.

            * If consensus method 30 or later is used, the base64 encoded
              ntor-onion-key does not include the trailing = sign.

            * If consensus method 31 or later is used, authorities parse the
              "bwweightscale" and "maxunmeasuredbw" parameters correctly when
              computing votes.

            * If consensus method 32 or later is used, authorities handle the
              "MiddleOnly" flag specially when computing a consensus.  When the
              voters agree to include "MiddleOnly" in a routerstatus, they
              automatically remove "Exit", "Guard", "V2Dir", and "HSDir".  If
              the BadExit flag is included in the consensus, they automatically
              add it to the routerstatus.

            * If consensus method 33 or later is used, and the consensus
              flavor is "microdesc", then the "Publication" field in the "r"
              line is set to "2038-01-01 00:00:00".

            * If consensus method 34 or later is used, the consensus
              does not include any "package" lines.

[/code]

The signatures at the end of a consensus document are sorted in ascending order by identity digest.

All ties in computing medians are broken in favor of the smaller or earlier item.

## Deciding which Ids to include

This sorting algorithm is used for consensus-method 22 and later.
[code]
      First, consider each listing by tuple of <Ed,Rsa> identities, where 'Ed'
        may be "None" if the voter included "id ed25519 none" to indicate that
        the authority knows what ed25519 identities are, and thinks that the RSA
        key doesn't have one.

      For each such <Ed, RSA> tuple that is listed by more than half of the
        total authorities (not just total votes), include it.  (It is not
        possible for any other <id-Ed, id-RSA'> to have as many votes.)  If more
        than half of the authorities list a single <Ed,Rsa> pair of this type, we
        consider that Ed key to be "consensus"; see description of the
        NoEdConsensus flag.

      Log any other id-RSA values corresponding to an id-Ed we included, and any
        other id-Ed values corresponding to an id-RSA we included.

      For each <id-RSA> that is not yet included, if it is listed by more than
        half of the total authorities, and we do not already have it listed with
        some <id-Ed>, include it, but do not consider its Ed identity canonical.

[/code]

### Deciding which descriptors to include

Deciding which descriptors to include.

A tuple belongs to an `<id-RSA, id-Ed>` identity if it is a new tuple that matches both ID parts, or if it is an old tuple (one with no Ed opinion) that matches the RSA part. A tuple belongs to an `<id-RSA>` identity if its RSA identity matches.

A tuple matches another tuple if all the fields that are present in both tuples are the same.

For every included identity, consider the tuples belonging to that identity. Group them into sets of matching tuples. Include the tuple that matches the largest set, breaking ties in favor of the most recently published, and then in favor of the smaller server descriptor digest.

## Forward compatibility

Future versions of Tor will need to include new information in the consensus documents, but it is important that all authorities (or at least half) generate and sign the same signed consensus.

To achieve this, authorities list in their votes their supported methods for generating consensuses from votes. Later methods will be assigned higher numbers. Currently specified methods:
[code]
         "1" -- The first implemented version.
         "2" -- Added support for the Unnamed flag.
         "3" -- Added legacy ID key support to aid in authority ID key rollovers
         "4" -- No longer list routers that are not running in the consensus
         "5" -- adds support for "w" and "p" lines.
         "6" -- Prefers measured bandwidth values rather than advertised
         "7" -- Provides keyword=integer pairs of consensus parameters
         "8" -- Provides microdescriptor summaries
         "9" -- Provides weights for selecting flagged routers in paths
         "10" -- Fixes edge case bugs in router flag selection weights
         "11" -- Don't consider BadExits when calculating bandwidth weights
         "12" -- Params are only included if enough auths voted for them
         "13" -- Omit router entries with missing microdescriptors.
         "14" -- Adds support for "a" lines in ns consensuses and microdescriptors.
         "15" -- Adds support for "p6" lines.
         "16" -- Adds ntor keys to microdescriptors
         "17" -- Adds "Unmeasured=1" flags to "w" lines
         "18" -- Adds 'id' to microdescriptors.
         "19" -- Adds "package" lines to consensuses
         "20" -- Adds GuardFraction information to microdescriptors.
         "21" -- Adds Ed25519 keys to microdescriptors.
         "22" -- Instantiates Ed25519 voting algorithm correctly.
         "23" -- Adds shared randomness protocol data.
         "24" -- No longer lists routers that are not Valid in the consensus.
         "25" -- Vote on recommended-protocols and required-protocols.
         "26" -- Initialize bandwidth weights to 1 to avoid division-by-zero.
         "27" -- Adds support for "a" lines in microdescriptor consensuses.
         "28" -- Removes "a" lines from microdescriptors.
         "29" -- Canonicalizes families in microdescriptors.
         "30" -- Removes padding from ntor-onion-key.
         "31" -- Uses correct parsing for bwweightscale and maxunmeasuredbw
                 when computing weights
         "32" -- Adds special handling for MiddleOnly flag.
         "33" -- Sets "publication" field in microdesc consensus "r" lines
                 to a meaningless value.
         "34" -- Removes "package" lines from consensus.
         "35" -- Includes "family-ids" entry in microdescriptors.

[/code]

Before generating a consensus, an authority must decide which consensus method to use. To do this, it looks for the highest version number supported by more than 2/3 of the authorities voting. If it supports this method, then it uses it. Otherwise, it falls back to the newest consensus method that it supports (which will probably not result in a sufficiently signed consensus).

All authorities MUST support method 25; authorities SHOULD support more recent methods as well. Authorities SHOULD NOT support or advertise support for any method before 25. Clients MAY assume that they will never see a current valid signed consensus for any method before method 25.

(The consensuses generated by new methods must be parsable by implementations that only understand the old methods, and must not cause those implementations to compromise their anonymity. This is a means for making changes in the contents of consensus; not for making backward-incompatible changes in their format.)

The following methods have incorrect implementations; authorities SHOULD NOT advertise support for them:

“21” – Did not correctly enable support for ed25519 key collation.

## Exit policy summaries

Exit policy summaries appear in:

  * `ipv6-policy` in server descriptors
  * `p` in votes and consensuses

The format is:

  * _keyword_ `accept`|`reject` _PortList_
  * **_PortList_** = __PortList_ `,` _PortOrRange_
  * **_PortOrRange_** = INT `-` INT / INT

> For the avoidance of doubt, _PortList_ is a single argument, so it cannot contain spaces.

Whether the summary shows the list of accepted ports or the list of rejected ports depends on which list is shorter (has a shorter string representation). In case of ties we choose the list of accepted ports. As an exception to this rule an allow-all policy is represented as “accept 1-65535” instead of “reject “ and a reject-all policy is similarly given as “reject 1-65535”.

Summary items are compressed, that is instead of “80-88,89-100” there only is a single item of “80-100”, similarly instead of “20,21” a summary will say “20-21”.

Port lists are sorted in ascending order.

The maximum allowed length of a policy summary (including the “accept “ or “reject “) is 1000 characters. If a summary exceeds that length we use an accept-style summary and list as much of the port list as is possible within these 1000 bytes. [XXXX be more specific.]

## Computing Bandwidth Weights

Let weight_scale = 10000, or the value of the “bwweightscale” parameter. (Before consensus method 31 there was a bug in parsing bwweightscale, so that if there were any consensus parameters after it alphabetically, it would always be treated as 10000. A similar bug existed for “maxunmeasuredbw”.)

Starting with consensus method 26, G, M, E, and D are initialized to 1 and T to 4. Prior consensus methods initialize them all to 0. With this change, test tor networks that are small or new are much more likely to produce bandwidth-weights in their consensus. The extra bandwidth has a negligible impact on the bandwidth weights in the public tor network.

Let G be the total bandwidth for Guard-flagged nodes. Let M be the total bandwidth for non-flagged nodes. Let E be the total bandwidth for Exit-flagged nodes. Let D be the total bandwidth for Guard+Exit-flagged nodes. Let T = G+M+E+D

Let Wgd be the weight for choosing a Guard+Exit for the guard position. Let Wmd be the weight for choosing a Guard+Exit for the middle position. Let Wed be the weight for choosing a Guard+Exit for the exit position.

Let Wme be the weight for choosing an Exit for the middle position. Let Wmg be the weight for choosing a Guard for the middle position.

Let Wgg be the weight for choosing a Guard for the guard position. Let Wee be the weight for choosing an Exit for the exit position.

Balanced network conditions then arise from solutions to the following system of equations:

Wgg _G + Wgd_ D == M + Wmd _D + Wme_ E + Wmg _G (guard bw = middle bw) Wgg_ G + Wgd _D == Wee_ E + Wed _D (guard bw = exit bw) Wed_ D + Wmd _D + Wgd_ D == D (aka: Wed+Wmd+Wdg = weight_scale) Wmg _G + Wgg_ G == G (aka: Wgg = weight_scale-Wmg) Wme _E + Wee_ E == E (aka: Wee = weight_scale-Wme)

We are short 2 constraints with the above set. The remaining constraints come from examining different cases of network load. The following constraints are used in consensus method 10 and above. There are another incorrect and obsolete set of constraints used for these same cases in consensus method 9. For those, see dir-spec.txt in Tor 0.2.2.10-alpha to 0.2.2.16-alpha.

Case 1: E >= T/3 && G >= T/3 (Neither Exit nor Guard Scarce)

In this case, the additional two constraints are: Wmg == Wmd, Wed == 1/3.
[code]
        This leads to the solution:
            Wgd = weight_scale/3
            Wed = weight_scale/3
            Wmd = weight_scale/3
            Wee = (weight_scale*(E+G+M))/(3*E)
            Wme = weight_scale - Wee
            Wmg = (weight_scale*(2*G-E-M))/(3*G)
            Wgg = weight_scale - Wmg

      Case 2: E < T/3 && G < T/3 (Both are scarce)

[/code]

Let R denote the more scarce class (Rare) between Guard vs Exit. Let S denote the less scarce class.

Subcase a: R+D < S

In this subcase, we simply devote all of D bandwidth to the scarce class.
[code]
           Wgg = Wee = weight_scale
           Wmg = Wme = Wmd = 0;
           if E < G:
             Wed = weight_scale
             Wgd = 0
           else:
             Wed = 0
             Wgd = weight_scale

        Subcase b: R+D >= S

[/code]

In this case, if M <= T/3, we have enough bandwidth to try to achieve a balancing condition.

Add constraints Wgg = weight_scale, Wmd == Wgd to maximize bandwidth in the guard position while still allowing exits to be used as middle nodes:

Wee = (weight_scale*(E - G + M))/E Wed = (weight_scale*(D - 2 _E + 4_ G - 2 _M))/(3_ D) Wme = (weight_scale*(G-M))/E Wmg = 0 Wgg = weight_scale Wmd = (weight_scale - Wed)/2 Wgd = (weight_scale - Wed)/2

If this system ends up with any values out of range (ie negative, or above weight_scale), use the constraints Wgg == weight_scale and Wee == weight_scale, since both those positions are scarce:
[code]
             Wgg = weight_scale
             Wee = weight_scale
             Wed = (weight_scale*(D - 2*E + G + M))/(3*D)
             Wmd = (weight_Scale*(D - 2*M + G + E))/(3*D)
             Wme = 0
             Wmg = 0
             Wgd = weight_scale - Wed - Wmd

          If M > T/3, then the Wmd weight above will become negative. Set it to 0
          in this case:
             Wmd = 0
             Wgd = weight_scale - Wed

      Case 3: One of E < T/3 or G < T/3

        Let S be the scarce class (of E or G).

        Subcase a: (S+D) < T/3:
          if G=S:
            Wgg = Wgd = weight_scale;
            Wmd = Wed = Wmg = 0;
            // Minor subcase, if E is more scarce than M,
            // keep its bandwidth in place.
            if (E < M) Wme = 0;
            else Wme = (weight_scale*(E-M))/(2*E);
            Wee = weight_scale-Wme;
          if E=S:
            Wee = Wed = weight_scale;
            Wmd = Wgd = Wme = 0;
            // Minor subcase, if G is more scarce than M,
            // keep its bandwidth in place.
            if (G < M) Wmg = 0;
            else Wmg = (weight_scale*(G-M))/(2*G);
            Wgg = weight_scale-Wmg;

        Subcase b: (S+D) >= T/3
          if G=S:
            Add constraints Wgg = weight_scale, Wmd == Wed to maximize bandwidth
            in the guard position, while still allowing exits to be
            used as middle nodes:
              Wgg = weight_scale
              Wgd = (weight_scale*(D - 2*G + E + M))/(3*D)
              Wmg = 0
              Wee = (weight_scale*(E+M))/(2*E)
              Wme = weight_scale - Wee
              Wmd = (weight_scale - Wgd)/2
              Wed = (weight_scale - Wgd)/2
          if E=S:
            Add constraints Wee == weight_scale, Wmd == Wgd to maximize bandwidth
            in the exit position:
              Wee = weight_scale;
              Wed = (weight_scale*(D - 2*E + G + M))/(3*D);
              Wme = 0;
              Wgg = (weight_scale*(G+M))/(2*G);
              Wmg = weight_scale - Wgg;
              Wmd = (weight_scale - Wed)/2;
              Wgd = (weight_scale - Wed)/2;

[/code]

To ensure consensus, all calculations are performed using integer math with a fixed precision determined by the bwweightscale consensus parameter (defaults at 10000, Min: 1, Max: INT32_MAX). (See note above about parsing bug in bwweightscale before consensus method 31.)

For future balancing improvements, Tor clients support 11 additional weights for directory requests and middle weighting. These weights are currently set at weight_scale, with the exception of the following groups of assignments:

Directory requests use middle weights:

Wbd=Wmd, Wbg=Wmg, Wbe=Wme, Wbm=Wmm

Handle bridges and strange exit policies:

Wgm=Wgg, Wem=Wee, Weg=Wed

## Computing consensus flavors

Consensus flavors are variants of the consensus that clients can choose to download and use instead of the unflavored consensus. The purpose of a consensus flavor is to remove or replace information in the unflavored consensus without forcing clients to download information they would not use anyway.

Directory authorities can produce and serve an arbitrary number of flavors of the same consensus. A downside of creating too many new flavors is that clients will be distinguishable based on which flavor they download. A new flavor should not be created when adding a field instead wouldn’t be too onerous.

Examples for consensus flavors include:
[code]
          - Publishing hashes of microdescriptors instead of hashes of
            full descriptors (see section 3.9.2).
          - Including different digests of descriptors, instead of the
            perhaps-soon-to-be-totally-broken SHA1.

[/code]

Consensus flavors are derived from the unflavored consensus once the voting process is complete. This is to avoid consensus synchronization problems.

Every consensus flavor has a name consisting of a sequence of one or more alphanumeric characters and dashes. For compatibility, the original (unflavored) consensus type is called “ns”.

The supported consensus flavors are defined as part of the authorities’ consensus method.

All consensus flavors have in common that their first line is “network-status-version” where version is 3 or higher, and the flavor is a string consisting of alphanumeric characters and dashes:

“network-status-version” SP version [SP flavor] NL

### ns consensus

The ns consensus flavor is equivalent to the unflavored consensus. When the flavor is omitted from the “network-status-version” line, it should be assumed to be “ns”. Some implementations may explicitly state that the flavor is “ns” when generating consensuses, but should accept consensuses where the flavor is omitted.

### Microdescriptor consensus

The microdescriptor consensus is a consensus flavor that contains microdescriptor hashes instead of descriptor hashes and that omits exit-policy summaries which are contained in microdescriptors. The microdescriptor consensus was designed to contain elements that are small and frequently changing. Clients use the information in the microdescriptor consensus to decide which servers to fetch information about and which servers to fetch information from.

The microdescriptor consensus is based on the unflavored consensus with the exceptions as follows:

“network-status-version” SP version SP “microdesc” NL

[At start, exactly once.]

The flavor name of a microdescriptor consensus is “microdesc”.

Changes to router status entries are as follows:
[code]
        "r" SP nickname SP identity SP publication SP IP SP ORPort
            SP DirPort NL

            [At start, exactly once.]

            Similar to "r" lines in section 3.4.1, but without the digest element.

        "a" SP address ":" port NL

            [Any number]

            Identical to the "a" lines in section 3.4.1.

[/code]

(Only included when the vote is generated with consensus-method 14 or later, and the consensus is generated with consensus-method 27 or later.)

“p” … NL

[At most once]

Not currently generated.

Exit policy summaries are contained in microdescriptors and therefore omitted in the microdescriptor consensus.

“m” SP digest NL

[Exactly once.*]

“digest” is the base64 of the SHA256 hash of the router’s microdescriptor with trailing =s omitted. For a given router descriptor digest and consensus method there should only be a single microdescriptor digest in the “m” lines of all votes. If different votes have different microdescriptor digests for the same descriptor digest and consensus method, at least one of the authorities is broken. If this happens, the microdesc consensus should contain whichever microdescriptor digest is most common. If there is no winner, we break ties in the favor of the lexically earliest.

[*Before consensus method 13, this field was sometimes erroneously omitted.]

Additionally, a microdescriptor consensus SHOULD use the sha256 digest algorithm for its signatures.

## Computing microdescriptors

Microdescriptors are a stripped-down version of server descriptors generated by the directory authorities which may additionally contain authority-generated information. Microdescriptors contain only the most relevant parts that clients care about. Microdescriptors are expected to be relatively static and only change about once per week. Microdescriptors do not contain any information that clients need to use to decide which servers to fetch information about, or which servers to fetch information from.

Microdescriptors are a straight transform from the server descriptor and the consensus method. Microdescriptors have no header or footer. A microdescriptor is identified by the SHA256 hash of its concatenated elements without a signature by the router. Microdescriptors do not contain any version information, because their version is determined by the consensus method.

Starting with consensus method 8, microdescriptors contain the following elements taken from or based on the server descriptor. Order matters here, because different directory authorities must be able to transform a given server descriptor and consensus method into the exact same microdescriptor.

“onion-key” NL (Optionally, a public key in PEM format)

[Exactly once, at start] [No extra arguments]

Optionally, an obsolete TAP key. (Note that while the _key_ is optional, the `onion-key` element itself is not. It is used to denote the start of a microdescriptor.)

This key is no longer used for anything. If present, it MUST be in the same format as described for relay descriptors.

All current consensus methods generate a key in this position.

“ntor-onion-key” SP base-64-encoded-key NL

[Exactly once]

The “ntor-onion-key” element as specified in section 2.1.1.

When generating microdescriptors for consensus method 30 or later, the trailing = sign must be absent. For consensus method 29 or earlier, the trailing = sign must be present.

(Only included when generating microdescriptors for consensus-method 16 or later.)

[Before Tor 0.4.5.1-alpha, this field was optional.]

“a” SP address “:” port NL

[Any number]

Additional advertised addresses for the OR.

Present currently only if the OR advertises at least one IPv6 address; currently, the first address is included and all others are omitted. Any other IPv4 or IPv6 addresses should be ignored.

Address and port are as for “or-address” as specified in section 2.1.1.

(Only included when generating microdescriptors for consensus-methods 14 to 27.)

"family" names NL

[At most once]

The “family” element as specified in server descriptors.

When generating microdescriptors for consensus method 29 or later, the following canonicalization algorithm is applied to improve compression:
[code]
               For all entries of the form $hexid=name or $hexid~name,
               remove the =name or ~name portion.

               Remove all entries of the form $hexid, where hexid is not
               40 hexadecimal characters long.

               If an entry is a valid nickname, put it into lower case.

               If an entry is a valid $hexid, put it into upper case.

               If there are any entries, add a single $hexid entry for
               the relay in question, so that it is a member of its own
               family.

               Sort all entries in lexical order.

               Remove duplicate entries.

[/code]

(Note that if an entry is not of the form “nickname”, “$hexid”, “$hexid=nickname” or “$hexid~nickname”, then it will be unchanged: this is what makes the algorithm forward-compatible.)

Clients use these family lists to determine family membership when building paths.

"family-ids" SP ids SP NL

[At most once.]

**ids** is a space-separated list of _Family IDs_. Each family ID consists of any number of otherwise valid nonspace characters.

Authorities generate a `family-ids` entry by deriving an ID from each of the `family-cert`s listed in the relay’s router descriptor, sorting those IDs in lexicographic order, and removing any duplicates.

Clients use these family IDs to determine family membership when building paths.

Clients SHOULD accept family IDs in unrecognized formats.

[This entry first appeared in consensus method 35. Earlier methods should omit it.]

“p” SP (“accept” / “reject”) SP PortList NL

[At most once.]

The exit-policy summary as specified in sections 3.4.1 and 3.8.2.

[With microdescriptors, clients don’t learn exact exit policies: clients can only guess whether a relay accepts their request, try the BEGIN request, and might get end-reason-exit-policy if they guessed wrong, in which case they’ll have to try elsewhere.]

[In consensus methods before 5, this line was omitted.]

“p6” SP (“accept” / “reject”) SP PortList NL

[At most once]

The IPv6 exit policy summary as specified in sections 3.4.1 and 3.8.2. A missing “p6” line is equivalent to “p6 reject 1-65535”.

(Only included when generating microdescriptors for consensus-method 15 or later.)

“id” SP “rsa1024” SP base64-encoded-identity-digest NL

[At most once]

The node identity digest `SHA1(DER(KP_relayid_rsa))`, base64 encoded, without trailing =s. This line is included to prevent collisions between microdescriptors.

Implementations SHOULD ignore these lines: they are added to microdescriptors only to prevent collisions.

(Only included when generating microdescriptors for consensus-method 18 or later.)

“id” SP “ed25519” SP base64-encoded-ed25519-identity NL

[At most once]

The node’s master Ed25519 identity key, base64 encoded, without trailing =s.

All implementations MUST ignore this key for any microdescriptor whose corresponding entry in the consensus includes the ‘NoEdConsensus’ flag.

(Only included when generating microdescriptors for consensus-method 21 or later.)

“id” SP keytype … NL

[At most once per distinct keytype.]

Implementations MUST ignore “id” lines with unrecognized key-types in place of “rsa1024” or “ed25519”

(Note that with microdescriptors, clients do not learn the RSA identity of their routers: they only learn a hash of the RSA identity key. This is all they need to confirm the actual identity key when doing a TLS handshake, and all they need to put the identity key digest in their CREATE cells.)

## Vote and consensus status document formats

Each status document contains (in this order):

  * a preamble
  * an authority section
  * zero or more router status entries
  * a footer
  * one or more signatures.

Some items appear only in votes, and some items appear only in consensuses. Unless specified, items occur in both. Items appearing only in certain documents is indicated by one of the following in the Item’s syntax bullet points:

  * In votes only
  * In consensus only

Consensus documents may also be available in “flavored” forms computed (deterministically) from the information desccribed here.

> Generation rules for consensus items are, partly, specified separately. and partly here. Refer to both places.

> The procedure for deciding when to generate vote and consensus status documents are described in the section on the voting timeline

## Consensus documents — reproducibility

Consensus documents generated by each dirauth must be byte-for-byte identical, as the same document must be countersigned by multiple dirauths.

Therefore, when generating a consensus document, certain of the metaformat rules are tightened:

  * Each WS is precisely a single SP.
  * Extra arguments are not allowed.
  * Items (and where applicable, arguments) are ordered as presented/specified here.

These rules MUST be followed by a dirauth when generating a consensus. When reading a vote or consensus, an implementation MUST NOT insist on them.

> When reading, the usual relaxed parsing is needed to support future compatibility. When writing, `consensus-methods` in votes allows the participating dirauths to negotiate protocol upgrades.

## Vote and consensus document, preamble items

The preamble contains the following items.

### `network-status-version` — Document format version

  * **`network-status-version`** version [flavor] ..
  * At start, exactly once.
  * No extra arguments in votes.

The document format **version**. For this specification, the version is “3”.

**flavor** is **`ns`** for the plain consensus, described here, or omitted. Other values are for flavored consensuses. Votes are not differentiated by flavor. To avoid ambiguity, in a vote, the flavor MUST be omitted, and no additional arguments are permitted.

### `vote-status` — Declare document type

  * **`vote-status`** type ..
  * Exactly once.
  * **_type_** is `vote` or `consensus`

### `consensus-methods` – Supported consensus methods

  * **`consensus-methods`** _method_ _method_ ..
  * At most once
  * In votes only
  * At least one _method_ argument.

The consensus methods supported by this voter. Each **_method_** is a as a decimal integer. See Computing a consensus for details. Absence of the line means that only method “1” is supported.

### `consensus-method` — Consensus method used

  * **`consensus-method`** _method_
  * At most once
  * In consensus only

See Computing a consensus for details.

(Only included when the vote is generated with consensus-method 2 or later.)

### `published` — Publication time

  * **`published` DateWsTime ..
  * Exactly once
  * In votes only

The publication time for this vote.

See Voting timeline.

### `valid-after` — Start of the Interval

  * **`valid-after`** DateWsTime ..
  * Exactly once

The start of the Interval for this vote. Before this time, the consensus document produced from this vote is not officially in use.

(Note that because of propagation delays, clients and relays may see consensus documents that are up to `DistSeconds` earlier than this time, and should not warn about them.)

See Voting timeline.

### `fresh-until` — Time until no longer fresh

  * **`fresh-until`** DateWsTime ..
  * Exactly once

The time at which the next consensus should be produced; before this time, there is no point in downloading another consensus, since there won’t be a new one.

See Voting timeline.

### `valid-until` — Time until no longer valid

  * **`valid-until`** DateWsTime ..
  * Exactly once

The end of the Interval for this vote. After this time, all clients should try to find a more recent consensus.

In practice, clients continue to use the consensus for up to 24 hours after it is no longer valid, if no more recent consensus can be downloaded.

See Voting timeline.

### `voting-delay` — Vote timing parameters

  * **`voting-delay`** _VoteSeconds_ _DistSeconds_ ..
  * Exactly once

VoteSeconds is the number of seconds that we will allow to collect votes from all authorities; DistSeconds is the number of seconds we’ll allow to collect signatures from all authorities.

See Voting timeline.

### `client-versions` — Recommended Tor client software

  * **`client-versions`** _version_ ,_version_ ,.. ..
  * At most once

A comma-separated list of recommended Tor **_version_ **s for client usage, in ascending order. The versions are given as defined by version-spec.txt. If absent, no opinion is held about client versions.

### `server-versions` — Recommended Tor server software

  * `server-versions` _version_ ,_version_ ,.. ..
  * At most once.

A comma-separated list of recommended Tor versions for relay usage, in ascending order. The versions are given as defined by version-spec.txt. If absent, no opinion is held about server versions.

### `package` — Software distribution hashes (obsolete)

“package” SP PackageName SP Version SP URL SP DIGESTS NL

[Any number of times.]

For this element:
[code]
            PACKAGENAME = NONSPACE
            VERSION = NONSPACE
            URL = NONSPACE
            DIGESTS = DIGEST | DIGESTS SP DIGEST
            DIGEST = DIGESTTYPE "=" DIGESTVAL
            NONSPACE = one or more non-space printing characters
            DIGESTVAL = DIGESTTYPE = one or more non-space printing characters
                  other than "=".

[/code]

Indicates that a package called “package” of version VERSION may be found at URL, and its digest as computed with DIGESTTYPE is equal to DIGESTVAL. In consensuses, these lines are sorted lexically by “PACKAGENAME VERSION” pairs, and DIGESTTYPES must appear in ascending order. A consensus must not contain the same “PACKAGENAME VERSION” more than once. If a vote contains the same “PACKAGENAME VERSION” more than once, all but the last is ignored.

Included in consensuses only for methods 19-33. Earlier methods did not include this; method 34 removed it.

### `known-flags` — Router flags which could be determined

  * **`known-flags`** _flag_ _flag_ ..
  * Exactly once.
  * One or more distinct `_flag_` arguments, in lexical order

A space-separated list of all of the flags that this document might contain in `s` Items.

A flag is “known” either because the authority knows about them and might set them (if in a vote), or because enough votes were counted for the consensus for an authoritative opinion to have been formed about their status.

### `flag-thresholds` — Authority’s performance thresholds

  * `flag-thresholds` _threshold_ _threshold_ ..
  * One or more _threshold_ arguments
  * At most once for votes; does not occur in consensuses.

[code]
             The metaformat is:
                threshold = ThresholdKey '=' ThresholdVal
                ThresholdKey = (KeywordChar | "_") +
                ThresholdVal = [0-9]+("."[0-9]+)? "%"?

[/code]

A space-separated list of the internal performance thresholds that the directory authority had at the moment it was forming a vote.

Commonly used _ThresholdKey_ s at this point include:

  * **`stable-uptime`** – Uptime (in seconds) required for a relay to be marked as stable.

  * **`stable-mtbf`** – MTBF (in seconds) required for a relay to be marked as stable.

  * **`enough-mtbf`** – Whether we have measured enough MTBF to look at stable-mtbf instead of stable-uptime.

  * **`fast-speed`** – Bandwidth (in bytes per second) required for a relay to be marked as fast.

  * **`guard-wfu`** – WFU (in seconds) required for a relay to be marked as guard.

  * **`guard-tk`** – Weighted Time Known (in seconds) required for a relay to be marked as guard.

  * **`guard-bw-inc-exits`** – If exits can be guards, then all guards must have a bandwidth this high.

  * **`guard-bw-exc-exits`** – If exits can’t be guards, then all guards must have a bandwidth this high.

  * **`ignoring-advertised-bws`** – 1 if we have enough measured bandwidths that we’ll ignore the advertised bandwidth claims of routers without measured bandwidth.

### `required-` / `recommended-*-protocols` — Minimum protocol features

  * **`recommended-client-protocols`** _entry_ _entry_ ..
  * **`recommended-relay-protocols`** _entry_ _entry_ ..
  * **`required-client-protocols`** _entry_ _entry_ ..
  * **`required-relay-protocols`** _entry_ _entry_ ..
  * At most once each.
  * Zero or more _entry_ arguments.

**_entry_** is as for `proto` in a server descriptor.

To vote on these entries, a protocol/version combination is included only if it is listed by a majority of the voters.

These lines should be voted on. A majority of votes is sufficient to make a protocol un-supported. A supermajority of authorities (2/3) are needed to make a protocol required. The required protocols should not be locally configurable, but rather should be hardwired in the dirauth implementation.

See Subprotocol versioning for details of how a relay and a client should behave when they encounter these lines in the consensus.

Because of the implications for required-*-protocols (see below), certain safety mechanisms are strongly recommended:

  1. An authority SHOULD NOT vote for any protocol in one of these “required” lists that it does not itself support.
  2. Authority implementations SHOULD NOT support configurable lists of required protocols: instead, those lists should be hard-coded.

#### Implications of `required-*-protocols`

> A consensus containing erroneous `required-*-protocols` has the potential to take down the network: clients and relays that see requirements, that they do not meet, will shut down, and not retry.
>
>
> For further information, see notes in the C Tor source code.

### `params` — Network parameters

  * **`params`** [_Keyword_ =_Value_ _Keyword_ =_Value_ ..]
  * Distinct _Keyword_s, in lexical order
  * At most once

Each **_Keyword_** is a parameter keyword. Each **_Value_** is a signed 32-bit integer, in decimal.

When reading a document, unknown parameters MUST be tolerated.

When a dirauth computes a consensus from votes, every parameter, even one unknown to that dirauth, MUST be included in the consensus if it appears in enough votes.

### `shared-rand-*-value` — Shared random values (in consensus)

  * **`shared-rand-previous-value`** _NumReveals_ _Value_ ..
  * **`shared-rand-current-value`** _NumReveals_ _Value_ ..
  * At most once each
  * In preamble in consensus only
  * (In authority section in votes.)

**_Value_** is the shared random value (256 bits) encoded in base64, as calculated by the shared random protocol.

**_NumReveals_** is the number of commits used to generate _Value_.

**`shared-rand-current-value`** is the value that was generated during the latest shared randomness protocol run. **`shared-rand-previous-value`** is the value generated during the second-to-last run.

> For example, if this document was created on the 5th of November, `current` carries the value generated during the protocol run of the 4th of November, and `previous` carries the value generated during the protocol run of the 3rd of November.
>
> See CONS for why we include old values in votes and consensus.

### `bandwidth-file-headers` — Bandwidth file metadata

“bandwidth-file-headers” SP KeyValues NL

[At most once for votes; does not occur in consensuses.]

KeyValues ::= “” | KeyValue | KeyValues SP KeyValue KeyValue ::= Keyword ‘=’ Value Value ::= ArgumentCharValue+ ArgumentCharValue ::= any printing ASCII character except NL and SP.

The headers from the bandwidth file used to generate this vote.

If an authority is not configured with a V3BandwidthsFile, this line SHOULD NOT appear in its vote.

If an authority is configured with a V3BandwidthsFile, but parsing fails, this line SHOULD appear in its vote, but without any headers.

First-appeared: Tor 0.3.5.1-alpha.

### `bandwidth-file-digest` — Bandwidth file

  * **`bandwidth-file-digest`** _algorithm_ =_digest_ ..
  * One or more _algorithm_ =_digest_ arguments
  * At most once
  * In votes only

Each **_digest_** is the hash using _algorithm_ of the bandwidth file used to generate this vote, in base64, unpadded.

**_algorithm_** is `sha256` or another algorithm.

If an authority is not configured with a bandwidth file, this line SHOULD NOT appear in its vote.

If an authority is configured with a bandwidth file, but parsing fails, this line SHOULD appear in its vote, with the digest(s) of the unparseable file.

First-appeared: Tor 0.4.0.4-alpha

> In C Tor this file is configured with `V3BandwidthsFile` in torrc

## Vote and consensus document, authority section

The authority section differs between votes and the consensus.

In a consensus, the authority section consists of:

  * One or more authority entries, for the actual authorities, in order by authority identity digest.
  * Zero or more **superseded authority key entries** , each consisting of only a `dir-source` item.
  * No authority key certificates.

In a vote, the authority section gives details of this directory authority, and consists of:

  * One authority entry.
  * One authority key certificate.

## Vote and consensus document, authority entry items

Each authority entry contains the following items. The entries are sorted by authority identity digest.

### `dir-source` — Introduces authority entry

  * **`dir-source`** _nickname_ _fingerprint_ _hostname_ _ip-address_ _dirport_ _orport_ ..
  * At start of authority entry, exactly once

Describes this authority.

**_nickname_** is a convenient identifier for the authority. **_fingerprint_** is H(KP_auth_id_rsa) as in the **`fingerprint`** item in the authority’s authority key certificate. **_hostname_** is the server’s hostname or IP address. **_ip-address_** is the server’s current IP address, and **_dirport_** is its current directory port. **_orport_** is the port at that address where the authority listens for OR connections.

A `dir-source` line for a superseded authority key entry is identical to the entry for that authority, except that:

  * _nickname_ has `-legacy` appended
  * _identity_ is the superseded key

### `contact` — Authority contact information

  * **`contact`** _info_ ….
  * Exactly once
  * _info_ is the whole rest of the line

Syntax and semantics are as for `contact` in server descriptors.

### `vote-digest` — Contributing vote

  * **`vote-digest`** _digest_ ..
  * Exactly once
  * In consensus only

The digest of the vote from the authority that contributed to this consensus, as signed (that is, not including the signature). (Hex, upper-case.)

The algorithm is not specified!

If the digest is 20 bytes (40 hex digits), it is SHA-1; if it is 32 bytes it is SHA-256.

### `legacy-dir-key` — Superseded authority key

  * **`legacy-dir-key`** _fingerprint_ ..
  * At most once
  * In votes only

Lists a fingerprint for a superseded identity key still used by this authority to keep older clients working. This optionis used to keep key around for a little while in case the authorities need to migrate many identity keys at once. (Generally, this would only happen because of a security vulnerability that affected multiple authorities, like the Debian OpenSSL RNG bug of May 2008.)

For each `legacy-dir-key` in the vote, there is a supserseded authority key entry in the consensus.

This item does not appear in votes or consensuses, as of May 2025.

### `shared-rand-participate` — Indicates shared random participation

  * **`shared-rand-participate`** ..
  * At most once
  * In votes only

Denotes that the directory authority supports and can participate in the shared random protocol.

### `shared-rand-commit` — Shared random commitment

  * `shared-rand-commit` _Version_ _AlgName_ _Identity_ _Commit_ [ Reveal ]
  * Any number of times
  * In votes only

[code]
    Version ::= An integer greater or equal to 0.
    AlgName ::= 1\*(ALPHA / DIGIT / "\_" / "-")
    Identity ::= 40\* HEXDIG

[/code]

Denotes a directory authority commit for the shared randomness protocol, containing the commitment value and potentially also the reveal value. See sections [COMMITREVEAL] and [VALIDATEVALUES] of srv-spec.txt on how to generate and validate these values.

  * **_Version_** is the current shared randomness protocol version.
  * **_AlgName_** is the hash algorithm that is used (e.g. “sha3-256”).
  * **_Identity_** is the authority’s SHA1 v3 identity fingerprint.
  * **_Commit_** is the encoded commitment value in base64.
    * The commitment value is specified in srv-spec.
  * **_Reveal_** (optional) contains the reveal value in base64.
    * The reveal value is specified in srv-spec.

If a vote contains multiple commits from the same authority, the receiver MUST only consider the first commit listed.

### `shared-rand-*-value` — Shared random values (in votes)

  * **`shared-rand-previous-value`** _NumReveals_ _Value_ ..
  * **`shared-rand-current-value`** _NumReveals_ _Value_ ..
  * In authority section in votes.
  * In preamble section in consensus.
  * See description in the preamble section

## Vote and consensus document, router status entries

Each router status entry contains the following items. Router status entries are sorted in ascending order by identity digest.

### `r` — Introduce a router status entry

  * **`r`** _nickname_ _identity_ _digest_ _publication_ _IP_ _ORPort_ _DirPort_ ..
  * At start of router status entry, exactly once

**_Nickname_** is the OR’s nickname. **_Identity_** is its SHA1(DER(KP_relayid_rsa)) in unpadded base64. **_Digest_** is a hash of its most recent descriptor as signed (that is, not including the signature) by the RSA identity key (see section 1.3.), encoded in base64.

**_Publication_** was once the publication time of the router’s most recent descriptor, in the DateWsTime format. Now it is only used in votes, and may be set to a fixed value in consensus documents. Implementations SHOULD ignore this value in non-vote documents.

**_IP_** is its current IPv4 address. **_ORPort_** is its current OR port. **_DirPort_** is its directory port or `0` for “none”.

### `a` — Further router address(es) (IPv6)

  * **`a`** _address_ :_port_
  * Any number

**_address_** and **_port_** are as for `or-address`.

Additional reachable address(es) for the OR. Used to convey the OR’s IPv6 address.

Clients should ignore any IPv4 addresses in `a`s, and use only the first IPv6 address, if there is one.

Authorities should include only the first advertised IPv6 address, if it is reachable.

> We may extend the protocol in the future to support multiple addresses for each address family.

(Only included when the vote or consensus is generated with consensus-method 14 or later.)

### `s` — Router status flags

  * **`s`** [_flag_ _flag_ ..]
  * Exactly once.
  * Zero or more distinct `_flag_` arguments, in lexical order

Each **_flag_** argument states a property of the router. If a particular flag is present in `known-flags`, but absent from the router entry, the document states that the router does _not_ have the property in question. If a flag is absent from `known-flags`, information about the property is not available in this document. (Every flag in an `s` item MUST be in `known-flags`.)

Currently specified flags are:

  * **`Authority`** — is a directory authority.
  * **`BadExit`** — is believed to be useless as an exit node (because its ISP censors it, because it is behind a restrictive proxy, or for some similar reason).
  * **`Exit`** — supports commonly used exit ports, and should be treated specially in the path building algorithm.
  * **`Fast`** — is suitable for high-bandwidth circuits.
  * **`Guard`** — is suitable for use as an entry guard.
  * **`HSDir`** — is considered a v2 hidden service directory.
  * **`MiddleOnly`** — is considered unsuitable for usage other than as a middle relay. Since 0.4.7.2-alpha, when it is present, the authorities will automatically vote against flags that would make the router usable in Guard, HSDir, Exit, and V2Dir. Additionally, since Tor 0.4.8.15, clients and services will also avoid usage of MiddleOnly nodes in IP and RP positions.
  * **`NoEdConsensus`** — any Ed25519 key in the router’s descriptor or microdescriptor does not reflect authority consensus.
  * **`Stable`** — is suitable for long-lived circuits.
  * **`StaleDesc`** — should upload a new descriptor because the old one is too old.
  * **`Running`** — is currently usable over all its published ORPorts. (Authorities ignore IPv6 ORPorts unless configured to check IPv6 reachability.) Relays without this flag are omitted from the consensus, and current clients (since 0.2.9.4-alpha) assume that every listed relay has this flag.
  * **`Valid`** — has been ‘validated’. Clients before 0.2.9.4-alpha would not use routers without this flag by default. Currently, relays without this flag are omitted from the consensus, and current (post-0.2.9.4-alpha) clients assume that every listed relay has this flag.
  * **`V2Dir`** — implements the v2 directory protocol or higher.

Unknown flags must be ignored (in `s` and in `known-flags`) when reading a document. Except, they must be processed by an authority, when generating a consensus from votes.

### `v` — Relay’s Tor (protocol) version

  * `v` _version_ ….
  * At most once
  * _version_ is the whole rest of the line

The version of the Tor protocol that this relay is running. If _version_ begins with `Tor` SP, the rest of the string is a Tor version number, and the protocol is “The Tor protocol as supported by the given version of Tor.” Otherwise, Tor has upgraded to a more sophisticated protocol versioning system, and the protocol is “a version of the Tor protocol more recent than any we recognize.”

Directory authorities SHOULD omit version strings they receive from descriptors f they would cause `v` lines to be over 128 characters long.

### `pr` — Subprotocol capabilities supported

  * `pr` _entry_ _entry_ ..
  * Exactly once
  * Syntax and semantics as for `proto` in a server descriptor

When a descriptor does not contain a “proto” entry, the authorities should reconstruct it using the approach described below in section D. They are included in the consensus using the same rules as currently used for “v” lines, if a sufficiently late consensus method is in use.

### `w` — Bandwidth estimate

  * `w` _Keyword_ =_value_ ..
  * At most once

The following **_Keyword_ **s are defined:

  * **`Bandwidth`** : Estimated bandwidth of this relay. Used to weight router selection.

  * **`Measured`** : Total measured bandwidth, produced by measuring stream capacities. In votes from bandwidth measurement authorities, only.

  * **`Unmeasured=1`** : Present unless `Bandwidth` is based 3 or more `Measured` values for this relay. In consensus, only.

`Bandwidth` and `Measured` **`value`**s are 32-bit unsigned integers, in decimal, representing kilobytes per second.

Other weighting keywords may be added later. Unknown keywords (or keywords unexpectedly present in this kind of document) must be ignored.

> When generating a consensus from votes, the consensus method determines precisely which set of keywords are to be recognised/included.

### `p` — Exit ports summary

  * `p` `accept`|`reject` _PortList_
  * At most once

An exit-policy summary summarizing the router’s supported exit ports, to “most addresses”.

### `m` — Microdescriptor hashes

  * `m` _methods_ _algorithm_ =_digest_ ..
  * Any number
  * In votes only
  * One or more _algorithm_ =_digest_ arguments

The `m` items taken together give the microdescriptor hashes, for this router, for each consensus method listed in `consensus-methods`.

**_methods_** is a comma-separated list of all the the consensus methods that generate precisely this microdescriptor.

Each **_algorithm_** is the name of the hash algorithm producing _digest_ , which can be `sha256` or something else, depending on the consensus “methods” supporting this algorithm. **_digest_** is hash of the microdescriptor in base64, unpadded.

> In consensuses, the microdescriptors appear only in the microdescriptor consensus.

### `id` — Relay’s (ed25519) identity

  * **`id`** `ed25519` _KP_relayid_ed_
  * **`id`** `ed25519` `none`
  * In votes only
  * At most once

**_KP_relayid_ed_** is encoded in base64, unpadded.

### `stats` — Statistics for this relay

  * **`stats`** [_Keyword_ =_Number_ _Keyword_ =_Number_ ..]
  * At most once
  * In votes only

**`Number`** has the syntax `[0-9]+(\.[0-9]+)?`.

Various statistics that the authority has computed for this relay.

Reported keys are:

  * **`wfu`** – Weighted Fractional Uptime
  * **`"tk`** – Weighted Time Known
  * **`mtbf`** – Mean Time Between Failure (stability)

(As of tor-0.4.6.1-alpha)

## Vote and consensus document, footer

The footer section contains the following items.

> The footer section was omitted prior to consensus method 9.

### `directory-footer` — Introduce directory footer

  * **`directory-footer`**
  * No extra arguments
  * Exactly once, at start of the footer

### `bandwidth-weights` — Weights to apply during path selection

  * **`bandwidth-weights`** [_Keyword_ =_Int32_ _Keyword_ =_Int32_ ..]
  * At most once
  * In consensus only
  * **`Int32`** is a decimal integer between -2147483648 and 2147483647.

List of optional weights to apply to router bandwidths during path selection. They are sorted in lexical order and values are divided by the consensus’ “bwweightscale” param. Definition of our known entries are…

  * **`Wgg`** – Weight for Guard-flagged nodes in the guard position
  * **`Wgm`** – Weight for non-flagged nodes in the guard Position
  * **`Wgd`** – Weight for Guard+Exit-flagged nodes in the guard Position
  * **`Wmg`** – Weight for Guard-flagged nodes in the middle Position
  * **`Wmm`** – Weight for non-flagged nodes in the middle Position
  * **`Wme`** – Weight for Exit-flagged nodes in the middle Position
  * **`Wmd`** – Weight for Guard+Exit flagged nodes in the middle Position
  * **`Weg`** – Weight for Guard flagged nodes in the exit Position
  * **`Wem`** – Weight for non-flagged nodes in the exit Position
  * **`Wee`** – Weight for Exit-flagged nodes in the exit Position
  * **`Wed`** – Weight for Guard+Exit-flagged nodes in the exit Position
  * **`Wgb`** – Weight for BEGIN_DIR-supporting Guard-flagged nodes
  * **`Wmb`** – Weight for BEGIN_DIR-supporting non-flagged nodes
  * **`Web`** – Weight for BEGIN_DIR-supporting Exit-flagged nodes
  * **`Wdb`** – Weight for BEGIN_DIR-supporting Guard+Exit-flagged nodes
  * **`Wbg`** – Weight for Guard flagged nodes for BEGIN_DIR requests
  * **`Wbm`** – Weight for non-flagged nodes for BEGIN_DIR requests
  * **`Wbe`** – Weight for Exit-flagged nodes for BEGIN_DIR requests
  * **`Wbd`** – Weight for Guard+Exit-flagged nodes for BEGIN_DIR requests

These values are calculated as specified in section 3.8.3.

### Vote and consensus document, signatures

The Signature Item is:

### `directory-signature` — Signature

  * **`directory-signature`** [_Algorithm_] _identity_ _signing-key-digest_ ..
  * _Signature_ , Object, `SIGNATURE`
  * Exactly once in votes
  * At least once in consensus

This is a signature of the status document, with the initial item “network-status-version”, and the signature item “directory-signature”, using the signing key. (In this case, we take the hash through the _space_ after directory-signature, not the newline: this ensures that all authorities sign the same thing.) “identity” is the hex-encoded digest of the authority identity key of the signing authority, and “signing-key-digest” is the hex-encoded digest of the current authority signing key of the signing authority.

The Algorithm is one of “sha1” or “sha256” if it is present; implementations MUST ignore directory-signature entries with an unrecognized Algorithm. “sha1” is the default, if no Algorithm is given. The algorithm describes how to compute the hash of the document before signing it.

“ns”-flavored consensus documents must contain only sha1 signatures. Votes and microdescriptor documents may contain other signature types. Note that only one signature from each authority should be “counted” as meaning that the authority has signed the consensus.

(Tor clients before 0.2.3.x did not understand the ‘algorithm’ field.)

## Consensus-negotiation timeline.

# Consensus-negotiation timeline
[code]
       Period begins: this is the Published time.
         Everybody sends votes
       Reconciliation: everybody tries to fetch missing votes.
         consensus may exist at this point.
       End of voting period:
         everyone swaps signatures.
       Now it's okay for caches to download
         Now it's okay for clients to download.

       Valid-after/valid-until switchover

[/code]

## Converting a curve25519 public key to an ed25519 public key

Given an X25519 key, that is, an affine point (u,v) on the Montgomery curve defined by

bv^2 = u(u^2 + au +1)

where
[code]
             a = 486662
             b = 1

[/code]

and comprised of the compressed form (i.e. consisting of only the u-coordinate), we can retrieve the y-coordinate of the affine point (x,y) on the twisted Edwards form of the curve defined by

-x^2 + y^2 = 1 + d x^2 y^2

where

d = - 121665/121666

by computing

y = (u-1)/(u+1).

and then we can apply the usual curve25519 twisted Edwards point decompression algorithm to find _an_ x-coordinate of an affine twisted Edwards point to check signatures with. Signing keys for ed25519 are compressed curve points in twisted Edwards form (so a y-coordinate and the sign of the x-coordinate), and X25519 keys are compressed curve points in Montgomery form (i.e. a u-coordinate).

However, note that compressed point in Montgomery form neglects to encode what the sign of the corresponding twisted Edwards x-coordinate would be. Thus, we need the sign of the x-coordinate to do this operation; otherwise, we’ll have two possible x-coordinates that might have correspond to the ed25519 public key.

To get the sign, the easiest way is to take the corresponding private key, feed it to the ed25519 public key generation algorithm, and see what the sign is.

[Recomputing the sign bit from the private key every time sounds rather strange and inefficient to me… —isis]

Note that in addition to its coordinates, an expanded Ed25519 private key also has a 32-byte random value, “prefix”, used to compute internal `r` values in the signature. For security, this prefix value should be derived deterministically from the curve25519 key. The Tor implementation derives it as `SHA512(private_key | STR)[0..32]`, where STR is the nul-terminated string:

“Derive high part of ed25519 key from curve25519 key\0”

On the client side, where there is no access to the curve25519 private keys, one may use the curve25519 public key’s Montgomery u-coordinate to recover the Montgomery v-coordinate by computing the right-hand side of the Montgomery curve equation:

bv^2 = u(u^2 + au +1)

where
[code]
             a = 486662
             b = 1

[/code]

Then, knowing the intended sign of the Edwards x-coordinate, one may recover said x-coordinate by computing:

x = (u/v) * sqrt(-a - 2)

## Authority key certificates

# Directory authority key certificates

Directory authorities create key certificates to certify their medium-term signing keys (`KP_auth_sign_rsa`) with their long-term authority identity keys (`KP_auth_id_rsa`).

An authority key certificate is a netdoc. Authority key certificates can appear as a sub-section of other documents, notably network status votes.

Authorities MUST generate a new signing key and corresponding certificate before the key expires.

## Authority key certificate items

### `dir-key-certificate-version` — Introduce an auth key cert

  * **`dir-key-certificate-version`** _version_ ..
  * At start, exactly once

States the protocol version of the key certificate.

**`version`** MUST be `3`. Implementations MUST reject formats they don’t understand.

### `dir-address` — Public directory service address

  * **`dir-address`** _address_ :_port_ ..
  * At most once

The IP address and TCP port at which this authority serves directory requests over HTTP,

### `fingerprint` — authority identity, H(KP_auth_id_rsa)

  * **`fingerprint`** _fingerprint_ ..
  * Exactly once.

**_fingerprint_** is SHA1(DER(KP_auth_id_rsa)), in uppercase hex.

### `dir-key-published` — Certificate generation time

  * **`dir-key-published`** _date_ _time_ ..
  * Exactly once.

**_date_** and **_time_** are as for `published` in a router descriptor.

The time when this document and corresponding key were last generated.

Implementations SHOULD reject certificates that are published too far in the future, though they MAY tolerate some clock skew.

### `dir-key-expires` – Certificate expiry time

  * **`dir-key-expires`** _date_ _time_ ..
  * Exactly once.

The time after which this certificate is no longer valid. **_date_** and **_time_** are as for `dir-key-published`.

Implementations SHOULD reject expired certificates, though they MAY tolerate some clock skew.

### `dir-identity-key` — authority identity key, KP_auth_id_rsa

  * **`dir-identity-key`**
  * _key_ _ Object, `RSA PUBLIC KEY`
  * Exactly once.
  * No extra arguments

The long-term authority identity key KP_auth_id_rsa for this authority. **_key_** is a DER PKCS#1 RSAPublicKey structure encoded as an Object.

This key SHOULD be at least 2048 bits long; it MUST NOT be shorter than 1024 bits.

#### `dir-signing-key` — Signing key, KP_auth_sign_rsa

  * **`dir-signing-key`**
  * _key_ _ Object, `RSA PUBLIC KEY`
  * Exactly once
  * No extra arguments.

The directory server’s public signing key `KP_auth_sign_rsa`. This key MUST be at least 1024 bits, and MAY be longer.

### `dir-key-crosscert` — Cross-certificate by KP_auth_sign_rsa

  * **`dir-key-crosscert`**
  * _CrossSignature_ , Object `ID SIGNATURE` or `SIGNATURE`
  * Exactly once.
  * No extra arguments.

CrossSignature is a signature, made using the certificate’s signing key `KP_auth_sign_rsa`, of the PKCS1-padded hash of the certificate’s identity key: `SHA1(DER(KP_auth_id_rsa))`. For backward compatibility with broken versions of the parser, we wrap the base64-encoded signature in `-----BEGIN ID SIGNATURE----` and `-----END ID SIGNATURE-----` tags. Implementations MUST allow the “ID “ portion to be omitted, however.

Implementations MUST verify that the signature is a correct signature of the hash of the identity key using the signing key.

### `dir-key-certification` — Signature

  * **`dir-key-certification`**
  * RSA signature of the document by KP_auth_id_rsa.
  * At end, exactly once.
  * No extra argument.

## Forbidden item keywords in authority key certificates

Authority key certificates are embedded in votes. A vote’s structure is formed from items with certain keywords (“structural keywords”), which introduce sections or sub-documents.

Authority key certificates must be copied into votes verbatim so that the signatures are preserved.

This presents a possible parsing ambiguity when deconstructing a vote, especially for naive or partial parsers, if unexpected keywords appear in an authority certificate.

> The precise processing rules below describe the boundaries of permissible behaviour for conformant implementations. A single parsing/processing/checking implementation can be used for all purposes provided it does all the checks.

### Requirements for generators of authority key certificates

Authority key certificates MUST NOT be generated containing any items which are meaningful elsewhere in votes (or parts of votes).

Authority key certificates MUST be generated containing ONLY items with keywords starting `dir-`, or that are `fingerprint`.

> `fingerprint` in an authcert is anomalous. There are no `fingerprint` item elsewhere in votes.

### Requirements for all parsers of votes

When parsing, documents where structural keywords appear apparently within an authority certificate (ie, between `dir-key-certificate-version` and `dir-key-certification`) SHOULD be rejected.

For example, a vote where an authority key certificate contain items with any of the following keywords SHOULD be rejected:

  * **`r`**
  * **`directory-footer`**

Documents (including votes and individual authority key certificates) where items meaningful elsewhere in votes appear in authority key certificates MAY be rejected.

### Requirements for authorities when parsing votes

When parsing another authority’s vote, as part of determining the consensus, an authority MUST perform additional checks:

Votes (or individual authority certificates) where authority certificates’ `dir-key-certificate-version` and `dir-key-certification` are not properly paired, MUST be rejected (treated as unparseable).

Votes where items recognised elsewhere in a vote appear within an authority certificate, SHOULD be rejected. For example, a vote SHOULD be rejected if an authority certificate contains a `client-versions` item.

### Requirements for authorities when generating votes

When an authority generates a vote, authority certificates which are included MUST be checked for **`r`** and **`directory-footer`**.

Authority certificates SHOULD be checked for keywords which are structural in votes, or which don’t start with `dir-` and aren’t `fingerprint`.

In each case, if such a keyword is checked for and found, the authority certificate MUST NOT be included in the vote. These checks MAY be performed during parsing of documents arriving from other authorities.

## Directory authority operation and formats

Every authority has two keys used in this protocol:

`KP_auth_id_rsa`: a long-term RSA authority identity key. This key MUST be at least 3072 bits long;

`KP_auth_sign_rsa`: a medium-term RSA authority signing key. This key MUST be at least 2048 bits long;

The identity key `KP_auth_id_rsa` is used from time to time to sign new key certificates containing (and authenticating) new `KP_auth_sign_rsa` signing keys; it is very sensitive. It may be kept offline.

The signing key `KP_auth_sign_rsa` is used to sign consensuses, votes, and similar documents.

(Authorities also have a router identity key `KP_relayid_rsa`, and other keys used in their role as a router, and by earlier versions of the directory protocol.)

## Directory cache operation

All directory caches implement this section, except as noted.

> Note: Directory caches are currently in the process of being renamed to “Directory Mirrors”, in order to better reflect their purpose. You might encounter both terms in the wild.

## General download behavior

For directory caches, a few general rules apply, which are outlined here.

Downloads always take place over ordinary TCP and plain-text HTTP through the ordinary dirport of the authorities. A directory cache SHOULD NOT download from another directory cache and SHOULD NOT use a Tor circuit or anything else besides ordinary TCP for that.

When downloading a consensus, a directory cache tries all directory authorities sequentially (linear, non-parallel), in a randomized round-robin order. It stops after the first successful response, remembering that authority that returned the successful response.

For all subsequent downloads associated with the consensus, this remembered authority will be used as the primary upstream source. In other words: All subsequent attempts within the context of the just obtained consensus will try to use that authority, with the failure handling described below.

In the case that a subsequent download within the context of the consensus fails and the failure is a network failure, the directory cache SHOULD pick a new directory authority determined in the same fashion as the previous outlined above, with the obvious exception of excluding the failed authority.

By network failure, we mean the following:

  * TCP failure or an even lower error in the OSI stack.
  * All `5xx` HTTP error codes.

The idea behind this is, that retrying a request where the first authority responded with `404` SHOULD stay the same with all authorities, as this is the main idea behind signing such a thing together.

Please keep in mind that further rules apply for retrying failed downloads, with this section primarily trying to outline the idea behind trying to stay consistent with a single authority for the context of a single consensus. See also Retrying failed downloads.

## Downloading consensus status documents from directory authorities

All directory caches try to keep a recent network-status consensus document to serve to clients. A cache ALWAYS downloads a network-status consensus if any of the following are true:

  * The cache has no consensus document.
  * The cache’s consensus document is no longer valid.

Otherwise, the cache downloads a new consensus document at a randomly chosen time in the first half-interval after its current consensus stops being fresh. (This time is chosen at random to avoid swarming the authorities at the start of each period. The interval size is inferred from the difference between the valid-after time and the fresh-until time on the consensus.)
[code]
       [For example, if a cache has a consensus that became valid at 1:00,
        and is fresh until 2:00, that cache will fetch a new consensus at
        a random time between 2:00 and 2:30.]

[/code]

Directory caches also fetch consensus flavors from the authorities. Caches check the correctness of consensus flavors, but do not check anything about an unrecognized consensus document beyond its digest and length. Caches serve all consensus flavors from the same locations as the directory authorities.

## Downloading server descriptors from directory authorities

Periodically (currently, every 10 seconds), directory caches check whether there are any specific descriptors that they do not have and that they are not currently trying to download. Caches identify these descriptors by hash in the recent network-status consensus documents.

If so, the directory cache launches requests to the authorities for these descriptors.

If one of these downloads fails, we do not try to download that descriptor from the authority that failed to serve it again unless we receive a newer network-status consensus that lists the same descriptor.

Directory caches must potentially cache multiple descriptors for each router. Caches must not discard any descriptor listed by any recent consensus. If there is enough space to store additional descriptors, caches SHOULD try to hold those which clients are likely to download the most. (Currently, this is judged based on the interval for which each descriptor seemed newest.)

[XXXX define recent]

## Downloading microdescriptors from directory authorities

Directory mirrors should fetch, cache, and serve each microdescriptor from the authorities.

The microdescriptors with base64 SHA256 hashes `<D1>`, `<D2>`, `<D3>` are available at:

`http://<hostname>/tor/micro/d/<D1>-<D2>-<D3>`

`<Dn>` are base64 encoded with trailing =s omitted for size and for consistency with the microdescriptor consensus format. -s are used instead of +s to separate items, since the + character is used in base64 encoding.

Directory mirrors should check to make sure that the microdescriptors they’re about to serve match the right hashes (either the hashes from the fetch URL or the hashes from the consensus, respectively).

(NOTE: Due to squid proxy url limitations at most 92 microdescriptor hashes can be retrieved in a single request.)

## Downloading extra-info documents from directory authorities

Any cache that chooses to cache extra-info documents should implement this section.

Periodically, the Tor instance checks whether it is missing any extra-info documents: in other words, if it has any server descriptors with an extra-info-digest field that does not match any of the extra-info documents currently held. If so, it downloads whatever extra-info documents are missing. Caches download from authorities. We follow the same splitting and back-off rules as in section 4.2.

## Consensus diffs

Instead of downloading an entire consensus, clients may download a “diff” document containing an ed-style diff from a previous consensus document. Caches (and authorities) make these diffs as they learn about new consensuses. To do so, they must store a record of older consensuses.

Support for consensus diffs was added in 0.3.1.1-alpha, and is advertised with the subprotocol “DirCache=2” (`DIRCACHE_CONSDIFF`).

### Consensus diff format

Consensus diffs are formatted as follows:

The first line is “network-status-diff-version 1” NL

The second line is

“hash” SP FromDigest SP ToDigest NL

where FromDigest is the hex-encoded SHA3-256 digest of the _signed part_ of the consensus that the diff should be applied to, and ToDigest is the hex-encoded SHA3-256 digest of the _entire_ consensus resulting from applying the diff. (See 3.4.1 for information on that part of a consensus is signed.)

The third and subsequent lines encode the diff from FromDigest to ToDigest in a limited subset of the ed diff format, as specified in appendix E.

### Serving and requesting diffs

When downloading the current consensus, a client may include an HTTP header of the form

X-Or-Diff-From-Consensus: HASH1, HASH2, …

where the HASH values are hex-encoded SHA3-256 digests of the _signed part_ of one or more consensuses that the client knows about.

If a cache knows a consensus diff from one of those consensuses to the most recent consensus of the requested flavor, it may send that diff instead of the specified consensus.

Caches also serve diffs from the URIs:
[code]
    /tor/status-vote/current/consensus/diff/<HASH>/<FPRLIST>
    /tor/status-vote/current/consensus-<FLAVOR>/diff/<HASH>/<FPRLIST>

[/code]

where FLAVOR is the consensus flavor, defaulting to “ns”, and FPRLIST is +-separated list of recognized authority identity fingerprints as in appendix B.

## Retrying failed downloads

See section 5.5 below; it applies to caches as well as clients.

Also, General download behavior explains some directory cache specific characteristics that apply partially to the retrying of failed downloads, but concern more about the selection of a static upstream directory authority for the duration/context of an active consensus.

## Downloading information from other directory authorities

## Downloading missing certificates from other directory authorities

XXX when to download certificates.

## Downloading server descriptors from other directory authorities

Periodically (currently, every 10 seconds), directory authorities check whether there are any specific descriptors that they do not have and that they are not currently trying to download. Authorities identify them by hash in vote (if publication date is more recent than the descriptor we currently have).

[XXXX need a way to fetch descriptors ahead of the vote? v2 status docs can do that for now.]

If so, the directory authority launches requests to the authorities for these descriptors, such that each authority is only asked for descriptors listed in its most recent vote. If more than one authority lists the descriptor, we choose which to ask at random.

If one of these downloads fails, we do not try to download that descriptor from the authority that failed to serve it again unless we receive a newer network-status (consensus or vote) from that authority that lists the same descriptor.
[code]
       Directory authorities must potentially cache multiple descriptors for each
       router. Authorities must not discard any descriptor listed by any recent
       consensus.  If there is enough space to store additional descriptors,
       authorities SHOULD try to hold those which clients are likely to download the
       most.  (Currently, this is judged based on the interval for which each
       descriptor seemed newest.)
    [XXXX define recent]

[/code]

Authorities SHOULD NOT download descriptors for routers that they would immediately reject for reasons listed in section 3.2.

## Downloading extra-info documents from other directory authorities

Periodically, an authority checks whether it is missing any extra-info documents: in other words, if it has any server descriptors with an extra-info-digest field that does not match any of the extra-info documents currently held. If so, it downloads whatever extra-info documents are missing. We follow the same splitting and back-off rules as in section 3.6.

## Exchanging detached signatures

Once an authority has computed and signed a consensus network status, it should send its detached signature to each other authority in an HTTP POST request to the URL:

`http://<hostname>/tor/post/consensus-signature`

[XXX Note why we support push-and-then-pull.]

All of the detached signatures it knows for consensus status should be available at:

`http://<hostname>/tor/status-vote/next/consensus-signatures`

Assuming full connectivity, every authority should compute and sign the same consensus including any flavors in each period. Therefore, it isn’t necessary to download the consensus or any flavors of it computed by each authority; instead, the authorities only push/fetch each others’ signatures. A “detached signature” document contains items as follows:

“consensus-digest” SP Digest NL

[At start, at most once.]

The digest of the consensus being signed.

“valid-after” SP DateWsTime NL “fresh-until” SP DateWsTime NL “valid-until” SP DateWsTime NL

[As in the consensus]

“additional-digest” SP flavor SP algname SP digest NL

[Any number.]

For each supported consensus flavor, every directory authority adds one or more “additional-digest” lines. “flavor” is the name of the consensus flavor, “algname” is the name of the hash algorithm that is used to generate the digest, and “digest” is the hex-encoded digest.

The hash algorithm for the microdescriptor consensus flavor is defined as SHA256 with algname “sha256”.
[code]
        "additional-signature" SP flavor SP algname SP identity SP
             signing-key-digest NL signature.

            [Any number.]

[/code]

For each supported consensus flavor and defined digest algorithm, every directory authority adds an “additional-signature” line. “flavor” is the name of the consensus flavor. “algname” is the name of the algorithm that was used to hash the identity and signing keys, and to compute the signature. “identity” is the hex-encoded digest of the authority identity key of the signing authority, and “signing-key-digest” is the hex-encoded digest of the current authority signing key of the signing authority.

The “sha256” signature format is defined as the RSA signature of the OAEP+-padded SHA256 digest of the item to be signed. When checking signatures, the signature MUST be treated as valid if the signature material begins with SHA256(document), so that other data can get added later. [To be honest, I didn’t fully understand the previous paragraph and only copied it from the proposals. Review carefully. -KL]

“directory-signature”

[As in the consensus; the signature object is the same as in the consensus document.]

## Exchanging votes

Authorities divide time into Intervals. Authority administrators SHOULD try to all pick the same interval length, and SHOULD pick intervals that are commonly used divisions of time (e.g., 5 minutes, 15 minutes, 30 minutes, 60 minutes, 90 minutes). Voting intervals SHOULD be chosen to divide evenly into a 24-hour day.

Authorities SHOULD act according to interval and delays in the latest consensus. Lacking a latest consensus, they SHOULD default to a 30-minute Interval, a 5 minute VotingDelay, and a 5 minute DistDelay.

Authorities MUST take pains to ensure that their clocks remain accurate within a few seconds. (Running NTP is usually sufficient.)

The first voting period of each day begins at 00:00 (midnight) UTC. If the last period of the day would be truncated by one-half or more, it is merged with the second-to-last period.

An authority SHOULD publish its vote immediately at the start of each voting period (minus VoteSeconds+DistSeconds). It does this by making it available at

`http://<hostname>/tor/status-vote/next/authority`

and sending it in an HTTP POST request to each other authority at the URL

`http://<hostname>/tor/post/vote`

If, at the start of the voting period, minus DistSeconds, an authority does not have a current statement from another authority, the first authority downloads the other’s statement.

Once an authority has a vote from another authority, it makes it available at

`http://<hostname>/tor/status-vote/next/<fp>`

where `<fp>` is the fingerprint of the other authority’s identity key. And at

`http://<hostname>/tor/status-vote/next/d/<d>`

where `<d>` is the digest of the vote document.

Also, once an authority receives a vote from another authority, it examines it for new descriptors and fetches them from that authority. This may be the only way for an authority to hear about relays that didn’t publish their descriptor to all authorities, and, while it’s too late for the authority to include relays in its current vote, it can include them in its next vote. See section 3.6 below for details.

## Extra-info document format

A server descriptor can reference an extra-info netdoc, by specifying an `extra-info-digest` Item.

## extra-info items

Some Items are precisely as in the router descriptor:

  * **`identity-ed25519`**
  * **`published`**

### `extra-info` — Introduce a server’s extra-info

  * **`extra-info`** _Nickname_ _Fingerprint_ ..
  * At start, exactly once.

Identifies what router this is an extra-info descriptor for. **_Fingerprint_** is encoded in hex (using upper-case letters), with no spaces.

### `read-history`, `write-history`, `ipv6-read-history`, `ipv6-write-history` — Recent bandwidth use
[code]
        "read-history" DateWsTime (NSEC s) NUM,NUM,NUM,NUM,NUM... NL
            [At most once.]
        "write-history" DateWsTime (NSEC s) NUM,NUM,NUM,NUM,NUM... NL
            [At most once.]

[/code]

Declare how much bandwidth the OR has used recently. Usage is divided into intervals of NSEC seconds. The DateWsTime field defines the end of the most recent interval. The numbers are the number of bytes used in the most recent intervals, ordered from oldest to newest.

These fields include both IPv4 and IPv6 traffic.
[code]
        "ipv6-read-history" DateWsTime (NSEC s) NUM,NUM,NUM... NL
            [At most once]
        "ipv6-write-history" DateWsTime (NSEC s) NUM,NUM,NUM... NL
            [At most once]

[/code]

Declare how much bandwidth the OR has used recently, on IPv6 connections. See “read-history” and “write-history” for full details.

### `geoip-db-digest`, `geoip6-db-digest` — Digests of GeoIP databases

  * **`geoip-db-digest`** _sha1-digest_ ..
  * **`geoip6-db-digest`** _sha1-digest_ ..
  * At most once each

**_sha1-digest_** is the SHA1 digest of the GeoIP database file that is used to resolve IPv4 or IPv6 addresses (respectively) to country codes, encoded in hexadecimal.

### `geoip-start-time`, `geoip-client-origins` — Obsolete usage info

(“geoip-start-time” DateWsTime NL) (“geoip-client-origins” CC=NUM,CC=NUM,… NL)

Only generated by bridge routers (see blocking.pdf), and only when they have been configured with a geoip database. Non-bridges SHOULD NOT generate these fields. Contains a list of mappings from two-letter country codes (CC) to the number of clients that have connected to that bridge from that country (approximate, and rounded up to the nearest multiple of 8 in order to hamper traffic analysis). A country is included only if it has at least one address. The time in “geoip-start-time” is the time at which we began collecting geoip statistics.

“geoip-start-time” and “geoip-client-origins” have been replaced by “bridge-stats-end” and “bridge-ips” in 0.2.2.4-alpha. The reason is that the measurement interval with “geoip-stats” as determined by subtracting “geoip-start-time” from “published” could have had a variable length, whereas the measurement interval in 0.2.2.4-alpha and later is set to be exactly 24 hours long. In order to clearly distinguish the new measurement intervals from the old ones, the new keywords have been introduced.

### `bridge-stats-end` — Bridge stats interval

  * **`bridge-stats-end`** DateWsTime (_NSEC_ s)
  * At most once
  * Anomalous argument format

**_DateWsTime_** defines the end of the included measurement interval of length **_NSEC_** seconds (86400 seconds by default).

A `bridge-stats-end` item, as well as any other `bridge-*` item, is only added when the relay has been running as a bridge for at least 24 hours.

### `bridge-ips` — Bridge country code stats

  * **`bridge-ips`** _CC_ =_NUM_ ,__CC_ =_NUM__ ,… ..
  * First argument is one or more _CC_ =_NUM_ , comma-separated.
  * At most once

List of mappings from two-letter country codes **_CC_** to the number of unique IP addresses **_NUM_** that have connected from that country to the bridge and which are no known relays, rounded up to the nearest multiple of 8.

### `bridge-ip-versions` — Bridge IP protocol version stats

  * **`bridge-ip-versions`** _VER_ =_NUM_ ,_VER_ =_NUM_ ,… ..
  * First argument is one or more _VER_ =_NUM_ , comma-separated.
  * At most once

List of counts **_NUM_** of unique IP addresses that have connected to the bridge per IP protocol version **_VER_** (`4` or `6`).

### `bridge-ip-transports` — Bridge pluggable transport stats

  * **`bridge-ip-transports`** _PT_ =_NUM_ ,_PT_ =_NUM_ ,…..
  * First argument is zero or more _PT_ =_NUM_ , comma-separated.
  * At most once

List of mappings from pluggable transport names to the number of unique IP addresses that have connected using that pluggable transport. Unobfuscated connections are counted using the reserved pluggable transport name “`<OR>`” (without quotes). If we received a connection from a transport proxy but we couldn’t figure out the name of the pluggable transport, we use the reserved pluggable transport name “`<??>`”.

(“`<OR>`” and “`<??>`” are reserved because normal pluggable transport names MUST match the following regular expression: “`[a-zA-Z_][a-zA-Z0-9_]*`” )

The pluggable transport name list is sorted into lexically ascending order.

If no clients have connected to the bridge yet, we only write “bridge-ip-transports” to the stats file.

### (extra-info document items in ad-hoc representation)
[code]
        "dirreq-stats-end" DateWsTime (NSEC s) NL
            [At most once.]

[/code]

The DateWsTime defines the end of the included measurement interval of length NSEC seconds (86400 seconds by default).

A “dirreq-stats-end” line, as well as any other “dirreq-*” line, is only added when the relay has opened its Dir port and after 24 hours of measuring directory requests.
[code]
        "dirreq-v2-ips" CC=NUM,CC=NUM,... NL
            [At most once.]
        "dirreq-v3-ips" CC=NUM,CC=NUM,... NL
            [At most once.]

[/code]

List of mappings from two-letter country codes to the number of unique IP addresses that have connected from that country to request a v2/v3 network status, rounded up to the nearest multiple of 8. Only those IP addresses are counted that the directory answered with a 200 OK status code, and (as of 0.4.8.22 / 0.4.9.4-alpha) finished sending. (Note here and below: current Tor versions, as of 0.2.5.2-alpha, no longer cache or serve v2 networkstatus documents.)
[code]
        "dirreq-v2-reqs" CC=NUM,CC=NUM,... NL
            [At most once.]
        "dirreq-v3-reqs" CC=NUM,CC=NUM,... NL
            [At most once.]

[/code]

List of mappings from two-letter country codes to the number of requests for v2/v3 network statuses from that country, rounded up to the nearest multiple of 8. Only those requests are counted that the directory can answer with a 200 OK status code.
[code]
        "dirreq-v2-share" NUM% NL
            [At most once.]
        "dirreq-v3-share" NUM% NL
            [At most once.]

[/code]

The share of v2/v3 network status requests that the directory expects to receive from clients based on its advertised bandwidth compared to the overall network bandwidth capacity. Shares are formatted in percent with two decimal places. Shares are calculated as means over the whole 24-hour interval.
[code]
        "dirreq-v2-resp" status=NUM,... NL
            [At most once.]
        "dirreq-v3-resp" status=NUM,... NL
            [At most once.]

[/code]

List of mappings from response statuses to the number of requests for v2/v3 network statuses that were answered with that response status, rounded up to the nearest multiple of 4. Only response statuses with at least 1 response are reported. New response statuses can be added at any time. The current list of response statuses is as follows:
[code]
            "served": (added as of 0.4.8.22 / 0.4.9.4-alpha) a network status
               request is answered, meaning it was a valid request and the
               answer used a 200 OK status code.
            "ok": a served network status request was successfully sent;
               this number is a subset of the "served" number above, and
               corresponds to the sum of all requests as reported in
               "dirreq-v2-reqs" or "dirreq-v3-reqs", respectively, before
               rounding up.
            "not-enough-sigs: a version 3 network status is not signed by a
               sufficient number of requested authorities.
            "unavailable": a requested network status object is unavailable.
            "not-found": a requested network status is not found.
            "not-modified": a network status has not been modified since the
               If-Modified-Since time that is included in the request.
            "busy": the directory is busy.

        "dirreq-v2-direct-dl" key=NUM,... NL
            [At most once.]
        "dirreq-v3-direct-dl" key=NUM,... NL
            [At most once.]
        "dirreq-v2-tunneled-dl" key=NUM,... NL
            [At most once.]
        "dirreq-v3-tunneled-dl" key=NUM,... NL
            [At most once.]

[/code]

List of statistics about possible failures in the download process of v2/v3 network statuses. Requests are either “direct” HTTP-encoded requests over the relay’s directory port, or “tunneled” requests using a BEGIN_DIR relay message over the relay’s OR port. The list of possible statistics can change, and statistics can be left out from reporting. The current list of statistics is as follows:

Successful downloads and failures:
[code]
            "complete": a client has finished the download successfully.
            "timeout": a download did not finish within 10 minutes after
               starting to send the response.
            "running": a download is still running at the end of the
               measurement period for less than 10 minutes after starting to
               send the response.

            Download times:

            "min", "max": smallest and largest measured bandwidth in B/s.
            "d[1-4,6-9]": 1st to 4th and 6th to 9th decile of measured
               bandwidth in B/s. For a given decile i, i/10 of all downloads
               had a smaller bandwidth than di, and (10-i)/10 of all downloads
               had a larger bandwidth than di.
            "q[1,3]": 1st and 3rd quartile of measured bandwidth in B/s. One
               fourth of all downloads had a smaller bandwidth than q1, one
               fourth of all downloads had a larger bandwidth than q3, and the
               remaining half of all downloads had a bandwidth between q1 and
               q3.
            "md": median of measured bandwidth in B/s. Half of the downloads
               had a smaller bandwidth than md, the other half had a larger
               bandwidth than md.

        "dirreq-read-history" DateWsTime (NSEC s) NUM,NUM,NUM... NL
            [At most once]
        "dirreq-write-history" DateWsTime (NSEC s) NUM,NUM,NUM... NL
            [At most once]

[/code]

Declare how much bandwidth the OR has spent on answering directory requests. Usage is divided into intervals of NSEC seconds. The DateWsTime field defines the end of the most recent interval. The numbers are the number of bytes used in the most recent intervals, ordered from oldest to newest.
[code]
        "entry-stats-end" DateWsTime (NSEC s) NL
            [At most once.]

[/code]

The DateWsTime defines the end of the included measurement interval of length NSEC seconds (86400 seconds by default).

An “entry-stats-end” line, as well as any other “entry-*” line, is first added after the relay has been running for at least 24 hours.
[code]
        "entry-ips" CC=NUM,CC=NUM,... NL
            [At most once.]

[/code]

List of mappings from two-letter country codes to the number of unique IP addresses that have connected from that country to the relay and which are no known other relays, rounded up to the nearest multiple of 8.
[code]
        "cell-stats-end" DateWsTime (NSEC s) NL
            [At most once.]

[/code]

The DateWsTime defines the end of the included measurement interval of length NSEC seconds (86400 seconds by default).

A “cell-stats-end” line, as well as any other “cell-*” line, is first added after the relay has been running for at least 24 hours.
[code]
        "cell-processed-cells" NUM,...,NUM NL
            [At most once.]

[/code]

Mean number of processed cells per circuit, subdivided into deciles of circuits by the number of cells they have processed in descending order from loudest to quietest circuits.
[code]
        "cell-queued-cells" NUM,...,NUM NL
            [At most once.]

[/code]

Mean number of cells contained in queues by circuit decile. These means are calculated by 1) determining the mean number of cells in a single circuit between its creation and its termination and 2) calculating the mean for all circuits in a given decile as determined in “cell-processed-cells”. Numbers have a precision of two decimal places.

Note that this statistic can be inaccurate for circuits that had queued cells at the start or end of the measurement interval.
[code]
        "cell-time-in-queue" NUM,...,NUM NL
            [At most once.]

[/code]

Mean time cells spend in circuit queues in milliseconds. Times are calculated by 1) determining the mean time cells spend in the queue of a single circuit and 2) calculating the mean for all circuits in a given decile as determined in “cell-processed-cells”.

Note that this statistic can be inaccurate for circuits that had queued cells at the start or end of the measurement interval.
[code]
        "cell-circuits-per-decile" NUM NL
            [At most once.]

[/code]

Mean number of circuits that are included in any of the deciles, rounded up to the next integer.
[code]
        "conn-bi-direct" DateWsTime (NSEC s) BELOW,READ,WRITE,BOTH NL
            [At most once]

[/code]

Number of connections, split into 10-second intervals, that are used uni-directionally or bi-directionally as observed in the NSEC seconds (usually 86400 seconds) before the DateWsTime field. Every 10 seconds, we determine for every connection whether we read and wrote less than a threshold of 20 KiB (BELOW), read at least 10 times more than we wrote (READ), wrote at least 10 times more than we read (WRITE), or read and wrote more than the threshold, but not 10 times more in either direction (BOTH). After classifying a connection, read and write counters are reset for the next 10-second interval.

This measurement includes both IPv4 and IPv6 connections.
[code]
        "ipv6-conn-bi-direct" DateWsTime (NSEC s) BELOW,READ,WRITE,BOTH NL
            [At most once]

[/code]

Number of IPv6 connections that are used uni-directionally or bi-directionally. See “conn-bi-direct” for more details.
[code]
        "exit-stats-end" DateWsTime (NSEC s) NL
            [At most once.]

[/code]

The DateWsTime defines the end of the included measurement interval of length NSEC seconds (86400 seconds by default).

An “exit-stats-end” line, as well as any other “exit-*” line, is first added after the relay has been running for at least 24 hours and only if the relay permits exiting (where exiting to a single port and IP address is sufficient).
[code]
        "exit-kibibytes-written" port=N,port=N,... NL
            [At most once.]
        "exit-kibibytes-read" port=N,port=N,... NL
            [At most once.]

[/code]

List of mappings from ports to the number of kibibytes that the relay has written to or read from exit connections to that port, rounded up to the next full kibibyte. Relays may limit the number of listed ports and subsume any remaining kibibytes under port “other”.
[code]
        "exit-streams-opened" port=N,port=N,... NL
            [At most once.]

[/code]

List of mappings from ports to the number of opened exit streams to that port, rounded up to the nearest multiple of 4. Relays may limit the number of listed ports and subsume any remaining opened streams under port “other”.
[code]
        "hidserv-stats-end" DateWsTime (NSEC s) NL
            [At most once.]
        "hidserv-v3-stats-end" DateWsTime (NSEC s) NL
            [At most once.]

[/code]

The DateWsTime defines the end of the included measurement interval of length NSEC seconds (86400 seconds by default).

A “hidserv-stats-end” line, as well as any other “hidserv-*” line, is first added after the relay has been running for at least 24 hours.

(Introduced in tor-0.4.6.1-alpha)
[code]
        "hidserv-rend-relayed-cells" SP NUM SP key=val SP key=val ... NL
            [At most once.]
        "hidserv-rend-v3-relayed-cells" SP NUM SP key=val SP key=val ... NL
            [At most once.]

[/code]

Approximate number of relay cells seen in either direction on a circuit after receiving and successfully processing a RENDEZVOUS1 cell.

The original measurement value is obfuscated in several steps: first, it is rounded up to the nearest multiple of ‘bin_size’ which is reported in the key=val part of this line; second, a (possibly negative) noise value is added to the result of the first step by randomly sampling from a Laplace distribution with mu = 0 and b = (delta_f / epsilon) with ‘delta_f’ and ‘epsilon’ being reported in the key=val part, too; third, the result of the previous obfuscation steps is truncated to the next smaller integer and included as ‘NUM’. Note that the overall reported value can be negative.

(Introduced in tor-0.4.6.1-alpha)
[code]
        "hidserv-dir-onions-seen" SP NUM SP key=val SP key=val ... NL
            [At most once.]
        "hidserv-dir-v3-onions-seen" SP NUM SP key=val SP key=val ... NL
            [At most once.]

[/code]

Approximate number of unique hidden-service identities seen in descriptors published to and accepted by this hidden-service directory.

The original measurement value is obfuscated in the same way as the ‘NUM’ value reported in “hidserv-rend-relayed-cells”, but possibly with different parameters as reported in the key=val part of this line. Note that the overall reported value can be negative.

(Introduced in tor-0.4.6.1-alpha)
[code]
        "transport" transportname address:port [arglist] NL
            [Any number.]

[/code]

Signals that the router supports the ‘transportname’ pluggable transport in IP address ‘address’ and TCP port ‘port’. A single descriptor MUST not have more than one transport line with the same ‘transportname’.

Pluggable transports are only relevant to bridges, but these entries can appear in non-bridge relays as well.
[code]
        "transport-info" [version=VersionString] [implementation=ImplementationString] NL
            [Any number.]

[/code]

There will be one “transport-info” line after one or multiple “transport” lines describing the implementation of those transport lines. It can optionally contain the version in the ‘VersionString’ and the implementation in the ‘ImplementationString’ or be empty if the pluggable transport doesn’t inform of its implementation.
[code]
        "padding-counts" DateWsTime (NSEC s) key=NUM key=NUM ... NL
            [At most once.]

[/code]

The DateWsTime defines the end of the included measurement interval of length NSEC seconds (86400 seconds by default). Counts are reset to 0 at the end of this interval.

The keyword list is currently as follows:
[code]
             bin-size
               - The current rounding value for cell count fields (10000 by
                 default)
             write-drop
               - The number of RELAY_DROP messages this relay sent
             write-pad
               - The number of PADDING cells this relay sent
             write-total
               - The total number of cells this relay cent
             read-drop
               - The number of RELAY_DROP messages this relay received
             read-pad
               - The number of PADDING cells this relay received
             read-total
               - The total number of cells this relay received
             enabled-read-pad
               - The number of PADDING cells this relay received on
                 connections that support padding
             enabled-read-total
               - The total number of cells this relay received on connections
                 that support padding
             enabled-write-pad
               - The total number of cells this relay received on connections
                 that support padding
             enabled-write-total
               - The total number of cells sent by this relay on connections
                 that support padding
             max-chanpad-timers
               - The maximum number of timers that this relay scheduled for
                 padding in the previous NSEC interval

        "overload-ratelimits" SP version SP DateWsTime
                          SP rate-limit SP burst-limit
                          SP read-overload-count SP write-overload-count NL
            [At most once.]

            Indicates that a bandwidth limit was exhausted for this relay.

[/code]

The “rate-limit” and “burst-limit” are the raw values from the BandwidthRate and BandwidthBurst found in the torrc configuration file.

The “{read|write}-overload-count” are the counts of how many times the reported limits of burst/rate were exhausted and thus the maximum between the read and write count occurrences. To make the counter more meaningful and to avoid multiple connections saturating the counter when a relay is overloaded, we only increment it once a minute.

The ‘version’ field is set to ‘1’ for now.

(Introduced in tor-0.4.6.1-alpha)
[code]
        "overload-fd-exhausted" SP version DateWsTime NL
            [At most once.]

[/code]

Indicates that a file descriptor exhaustion was experienced by this relay.

The timestamp indicates that the maximum was reached between the timestamp and the “published” timestamp of the document.

This overload field should remain in place for 72 hours since last triggered. If the limits are reached again in this period, the timestamp is updated, and this 72 hour period restarts.

The ‘version’ field is set to ‘1’ for the initial implementation which detects fd exhaustion only when a socket open fails.

(Introduced in tor-0.4.6.1-alpha)
[code]
        "router-sig-ed25519"
            [As in router descriptors]

        "router-signature" NL Signature NL
            [At end, exactly once.]
            [No extra arguments]

[/code]

A document signature as documented in section 1.3, using the initial item “extra-info” and the final item “router-signature”, signed with the router’s identity key.

## General-use HTTP URLs

Unless otherwise stated, “fingerprints” in these URLs are base16-encoded SHA1 hashes.

The most recent v3 consensus should be available at:

`http://<hostname>/tor/status-vote/current/consensus`

Similarly, the v3 microdescriptor consensus should be available at:

`http://<hostname>/tor/status-vote/current/consensus-microdesc`

A directory cache SHOULD start serving a new consensus document as soon as it is available and valid, regardless of how many router microdescriptors the cache is missing.

> Clients with an existing valid copy of the Tor directory won’t be troubled by these missing descriptors because they don’t start to use a new consensus right away.
>
> Even for new clients, in practice most microdescriptors don’t change from one consensus to the next, so a cache is likely to have a complete enough set even if it serves a new consensus right away.

Starting with Tor version 0.2.1.1-alpha is also available at:

`http://<hostname>/tor/status-vote/current/consensus/<F1>+<F2>+<F3>`

Where F1, F2, etc. are fingerprints of the authority identity keys (`SHA1(DER(KP_auth_id_rsa))`) for the authorities that the client trusts. Servers will only return a consensus if more than half of the requested authorities have signed the document, otherwise a 404 error will be sent back. The fingerprints can be shortened to a length of any multiple of two, using only the leftmost part of the encoded fingerprint. Tor uses 3 bytes (6 hex characters) of the fingerprint.

Clients SHOULD sort the fingerprints in ascending order. Server MUST accept any order.

Clients SHOULD use this format when requesting consensus documents from directory authority servers and from caches running a version of Tor that is known to support this URL format.

Consensus documents are also available as diffs by specifying a `X-Or-Diff-From-Consensus` header, or by fetching from:
[code]
    http://<hostname>/tor/status-vote/current/consensus/diff/<HASH>/<FPRLIST>
    http://<hostname>/tor/status-vote/current/consensus-<FLAVOR>/diff/<HASH>/<FPRLIST>

[/code]

With `<HASH>` being the SHA3-256 hash of the signed part of the consensus including the first `directory-signature<SPACE><EOF>` and `<FPRLIST>` a plus concatenated list of authority identity fingerprints as used elsewhere throughout the specification.

A concatenated set of all the current authority key certificates (from the current consensus) should be available at:

`http://<hostname>/tor/keys/all`

The authority key certificate for this authority should be available at:

`http://<hostname>/tor/keys/authority`

The authority key certificate for an authority whose authority identity fingerprint (`HEX(SHA1(DER(KP_auth_id_rsa)))`) is `<F>` should be available at:

`http://<hostname>/tor/keys/fp/<F>`

The authority key certificate whose signing key fingerprint (`HEX(SHA1(DER(KP_auth_sign_rsa)))`) is `<F>` should be available at:

`http://<hostname>/tor/keys/sk/<F>`

The authority key certificate whose authority identity key fingerprint is `<F>` and whose signing key fingerprint is `<S>` should be available at:

`http://<hostname>/tor/keys/fp-sk/<F>-<S>`

(As usual, clients may request multiple certificates using:

`http://<hostname>/tor/keys/fp-sk/<F1>-<S1>+<F2>-<S2>` )

[The above fp-sk format was not supported before Tor 0.2.1.9-alpha.]

The most recent descriptor for a relay whose identity key has a fingerprint (`HEX(SHA1(DER(KP_relayid_rsa)))`) of `<F>` should be available at:

`http://<hostname>/tor/server/fp/<F>`

The most recent descriptors for relays with identity fingerprints `<F1>`, `<F2>`,`<F3>` should be available at:

`http://<hostname>/tor/server/fp/<F1>+<F2>+<F3>`

(NOTE: Due to squid proxy url limitations at most 96 fingerprints can be retrieved in a single request.

Implementations SHOULD NOT download descriptors by identity key fingerprint. This allows a corrupted server (in collusion with a cache) to provide a unique descriptor to a client, and thereby partition that client from the rest of the network.)

The server descriptor with SHA1 (descriptor) digest `<D>` (in hex) should be available at:

`http://<hostname>/tor/server/d/<D>`

The most recent descriptors with SHA1 digests `<D1>`, `<D2>`, `<D3>` should be available at:

`http://<hostname>/tor/server/d/<D1>+<D2>+<D3>.z`

The most recent router descriptor for this server should be at:

`http://<hostname>/tor/server/authority`

This is used by authorities, and also if a server is configured as a bridge. The official Tor implementations (starting at 0.1.1.x) use this resource to test whether a server’s own DirPort is reachable. It is also useful for debugging purposes.

> The path element **`authority`** here is misleading. This is nothing to do with directory authorities. It’s the server’s own router descriptor, `authority` refers here merely to the fact that this server is (obviously) authoritative for its own descriptor.

A concatenated set of the most recent available descriptors for all known servers should be available at:

`http://<hostname>/tor/server/all`

> `all` is used for archiving and monitoring. Descriptors may be missing, for example descriptors for relays recently added to the consensus, which the directory server hasn’t yet managed to obtained.

Microdescriptors are available at:

`http://<hostname>/tor/micro/d/<D1>-<D2>-<D3>`

whereas `<Dn`> are base64 encoded SHA256 hashes of the microdescriptors with the trailing =s omitted. -s are used instead of +s to separate items, since the + character is used in base64 encoding. (See also Downloading microdescriptors

Extra-info documents are available at the URLS:
[code]
          http://<hostname>/tor/extra/d/...
          http://<hostname>/tor/extra/fp/...
          http://<hostname>/tor/extra/all
          http://<hostname>/tor/extra/authority

[/code]

(These work like the `/tor/server/` URLs: they support fetching extra-info documents by their SHA1 digest, by the fingerprint of their servers, or all at once. When serving by fingerprint, we serve the extra-info that corresponds to the descriptor we would serve by that fingerprint. Only directory authorities of version 0.2.0.1-alpha or later are guaranteed to support the first three classes of URLs. Caches may support them, and MUST support them if they have advertised “caches-extra-info”.)

Clients SHOULD use upper case letters (A-F) when base16-encoding fingerprints. Servers MUST accept both upper and lower case fingerprints in requests.

## Inferring missing proto lines.

# Inferring missing proto lines

The directory authorities no longer allow versions of Tor before 0.2.4.18-rc. But right now, there is no version of Tor in the consensus before 0.2.4.19. Therefore, we should disallow versions of Tor earlier than 0.2.4.19, so that we can have the protocol list for all current Tor versions include:

Cons=1-2 Desc=1-2 DirCache=1 HSDir=1 HSIntro=3 HSRend=1-2 Link=1-4 LinkAuth=1 Microdesc=1-2 Relay=1-2

For Desc, Microdesc and Cons, Tor versions before 0.2.7.stable should be taken to only support version 1.

## Limited ed diff format

We support the following format for consensus diffs. It’s a subset of the ed diff format, but clients MUST NOT accept other ed commands.

We support the following ed commands, each on a line by itself:
[code]
        - "<n1>d"          Delete line n1
        - "<n1>,<n2>d"     Delete lines n1 through n2, inclusive
        - "<n1>,$d"        Delete line n1 through the end of the file, inclusive.
        - "<n1>c"          Replace line n1 with the following block
        - "<n1>,<n2>c"     Replace lines n1 through n2, inclusive, with the
                           following block.
        - "<n1>a"          Append the following block after line n1.

[/code]

Note that line numbers always apply to the file after all previous commands have already been applied. Note also that line numbers are 1-indexed.

The commands MUST apply to the file from back to front, such that lines are only ever referred to by their position in the original file.

If there are any directory signatures on the original document, the first command MUST be a “`<n1>,$d`” form to remove all of the directory signatures. Using this format ensures that the client will successfully apply the diff even if they have an unusual encoding for the signatures.

The replace and append command take blocks. These blocks are simply appended to the diff after the line with the command. A line with just a period (“.”) ends the block (and is not part of the lines to add).

Note that it is impossible to insert a line with just a single dot. Implementations MUST NOT generate diffs consisting of a single dot followed by an arbitrary amount of whitespace characters. Implementations SHOULD reject such diffs.

## netdoc document meta-format

Server descriptors, directories, and running-routers documents all obey the following lightweight extensible information format, known as **netdoc** format.

## netdoc syntax

A netdoc is a text file, with Unix line endings.

The highest level object is a Document, which consists of one or more Items. Every Item begins with a KeywordLine, followed by zero or more Objects. A KeywordLine begins with a Keyword, optionally followed by whitespace and more non-newline characters, and ends with a newline. A Keyword is a sequence of one or more characters in the set [A-Za-z0-9-], but may not start with -. An Object is a block of encoded data in pseudo-Privacy-Enhanced-Mail (PEM) style format: that is, lines of encoded data MAY be wrapped by inserting an ascii linefeed (“LF”, also called newline, or “NL” here) character (cf. RFC 4648 §3.1). When line wrapping, implementations MUST wrap lines at 64 characters. Upon decoding, implementations MUST ignore and discard all linefeed characters.

A netdoc consists of unicode code points, and MUST be encoded as UTF-8 without a BOM prefix. Implementations SHOULD reject netdocs that are not UTF-8, or which contain the NUL character.

> **Future directions** :
>
> (Note that we may impose additional restrictions on the set of allowable Unicode characters in future, to restrict control characters and other oddities.)

> **Conformance** :
>
> Arti currently rejects all non-UTF-8 documents.
>
> C Tor directory authorities (as of 0.4.8.x) reject non-UTF-8 and UTF-with-BOMs when receiving router descriptors; C tor accepts arbitrary non-NUL byte sequences otherwise.

More formally:
[code]
    NL = The ascii LF character (hex value 0x0a).
    Document ::= (Item | NL)+
    Item ::= KeywordLine Object?
    KeywordLine ::= (Opt WS)? ItemKeyword (WS Arguments)? NL
    ItemKeyword = Keyword
    Arguments ::= Any sequence of unicode characters encoded in UTF-8, excluding NL and NUL.
    WS = (SP | TAB)+
    Object ::= BeginLine Base64-encoded-data EndLine
    BeginLine ::= "-----BEGIN " Keyword (" " Keyword)*"-----" NL
    EndLine ::= "-----END " Keyword (" " Keyword)* "-----" NL
    Keyword = KeywordStart KeywordChar*
    KeywordStart ::= 'A' ... 'Z' | 'a' ... 'z' | '0' ... '9'
    KeywordChar ::= KeywordStart | '-'
    Opt ::= "opt"

[/code]

The documentation for each ItemKeyword must specify its expected Arguments and Objects. Unless otherwise stated, a KeywordLine contains a sequence of space/tab-separated arguments:
[code]
    Arguments ::= Argument (WS Arguments)?
    Argument := ArgumentChar+
    ArgumentChar ::=  Any unicode characters encoded in UTF-8,
              excluding NL, NUL, TAB, and SP.

[/code]

A ItemKeyword may not be `opt`.

Implementations MUST NOT generate “Opt” in a keyword line, though they SHOULD accept it.

> **Conformance:**
>
> Some implementations do not accept Opt on all items. Notably, C Tor will reject many netdocs if they use “Opt” on an KeywordLine used to indicate the start or end of a section, or an a KeywordLine containing a signature.

> Before Tor 0.1.2.5-alpha, Opt was used to indicate that if a parser did not recognize an ItemKeyword, it should ignore it. Now all unrecognized ItemKeywords are treated that way.
>
> In Tor 0.2.0.5-alpha through 0.2.4.1-alpha we stopped generating Opt. No currently supported Tor release generates it.

The BeginLine and EndLine of an Object must use the same keyword.

## Compatibility and extensibility

When interpreting a Document, software MUST ignore any KeywordLine that starts with a keyword it doesn’t recognize; future implementations MUST NOT require current clients to understand any KeywordLine not currently described.

Other implementations that want to extend Tor’s directory format MAY introduce their own items. The keywords for extension items SHOULD start with the characters “x-” or “X-”, to guarantee that they will not conflict with keywords used by future versions of Tor.

### Permit additional arguments

For forward compatibility, each item MUST allow extra arguments at the end of the line unless otherwise noted. So, for example, if an item’s description is given as:

  * **`thing` int int int ..**

then implementations SHOULD accept this string as well:

`thing 5 9 11 13 16 12` NL

but not this string:

`thing 5` NL

Typically the text would state that the `int` arguments are integers, so the implementation should also reject this string:

`thing 5 10 thing` NL

Whenever an item DOES NOT allow extra arguments, we will tag it with **“No extra arguments”** in the syntax bullet points. (If the .. has been omitted, but there is no “no extra arguments” statement, the omission of the .. is a spec mistake and extra arguments _are_ allowed.)

## netdoc structure

Each type of netdoc requires, and permits, certain ItemKeywords, with certain restrictions on their order. In some cases ItemKeywords can introduce sections, providing structure to the document; this will be stated in the description for that ItemKeyword in that type of document.

## netdoc format description conventions

**NB** these conventions are not yet followed everywhere in the Tor Specifications.

When presenting a specific document format, the Items forming the document are shown one per subsection.

The syntax of each item is defined in detail with a bulleted list at the start of the section.

The first bullet point shows the syntax of the line introducing the item. Literal parts (including the Item Keyword) are shown in `fixed width`. Arguments are shown with _italic emphasis_. The spaces between arguments, and the final newline, are not depicted. If (as is usual) extra arguments are to be tolerated (for future expansion), a short ellipsis .. is shown as a reminder. Optional arguments are shown in [ ].

When an Item has (or may have) an Object, that is shown as the 2nd line in the bullet list, in the form:

  * _something_ , Object, `OBJECT KEYWORD` where _something_ will be used to refer to the Object in the text, and `OBJECT KEYWORD` is the Object’s Keyword in the base64 delimiters. (The `----BEGIN` etc. are not depicted.)

Further bullet points give further information about the syntax - often, in terms defined more fully here.

The type (therefore, format) of arguments, and permissible values, are stated in the text. The argument is named in **_bold-italic_** in its principal description.

### Position and multiplicity

The syntax bullet points for an Item state its permissible multiplicity and position, within each Document of its particular document type, in the following terms:

  * **“At start, exactly once”** — MUST occur exactly once, and MUST be the first item.

  * **“Exactly once”** — MUST occur exactly once.

  * **“At end, exactly once”** — MUST occur exactly once, and MUST be the last item.

  * **“At most once”** — MAY occur zero or one times but MUST NOT occur more than once.

  * **“Any number”** — MAY occur zero, one, or more times.

  * **“Once or more”** — MUST occur at least once and MAY occur more than once.

### Rest-of-line arguments

Exceptionally, for some items there is a “rest of line” argument. This is denoted by writing ARGUMENT…. in the syntax summary, in the first bullet point, and stating

  * _ARGUMENT_ is the whole rest of the line,

in the syntax description.

In this case, the value of the argument is all the characters after the SP following the keyword or previous argument.

## Signing documents

Every signable document below is signed in a similar manner, using a given “Initial Item”, a final “Signature Item”, a digest algorithm, and a signing key.

The Initial Item must be the first item in the document.

The Signature Item has the following format:

`<signature item keyword> [arguments] NL SIGNATURE NL`

The “SIGNATURE” Object contains a signature (using the signing key) of the PKCS#1 1.5 padded digest of the entire document, taken from the beginning of the Initial item, through the newline after the Signature Item’s keyword and its arguments.

The signature does not include the algorithmIdentifier specified in PKCS #1.

Unless specified otherwise, the digest algorithm is SHA-1.

All documents are invalid unless signed with the correct signing key.

The “Digest” of a document, unless stated otherwise, is its digest _as signed by this signature scheme_.

If a document may contain multiple signatures, it will be explicitly stated which signature item(s) are included in the digest(s) of which other signature item(s).

## Nonterminals in server descriptors

nickname ::= between 1 and 19 alphanumeric characters ([A-Za-z0-9]), case-insensitive.

hexdigest ::= a ‘$’, followed by 40 hexadecimal characters ([A-Fa-f0-9]) encoding a relay’s `SHA1(DER(KP_relayid_rsa))`.

bool ::= “0” | “1”

## Outline

There is a small set (say, around 5-10) of semi-trusted directory authorities. A default list of authorities is shipped with the Tor software. Users can change this list, but are encouraged not to do so, in order to avoid partitioning attacks.

Every authority has a very-secret, long-term “Authority Identity Key”. This is stored encrypted and/or offline, and is used to sign “key certificate” documents. Every key certificate contains a medium-term (3-12 months) “authority signing key”, that is used by the authority to sign other directory information. (Note that the authority identity key is distinct from the router identity key that the authority uses in its role as an ordinary router.)

Routers periodically upload signed “routers descriptors” to the directory authorities describing their keys, capabilities, and other information. Routers may also upload signed “extra-info documents” containing information that is not required for the Tor protocol. Directory authorities serve server descriptors indexed by router identity, or by hash of the descriptor.

Routers may act as directory caches to reduce load on the directory authorities. They announce this in their descriptors.

Periodically, each directory authority generates a view of the current descriptors and status for known routers. They send a signed summary of this view (a “status vote”) to the other authorities. The authorities compute the result of this vote, and sign a “consensus status” document containing the result of the vote.

Directory caches download, cache, and re-serve consensus documents.

Clients, directory caches, and directory authorities all use consensus documents to find out when their list of routers is out-of-date. (Directory authorities also use vote statuses.) If it is, they download any missing server descriptors. Clients download missing descriptors from caches; caches and authorities download from authorities. Descriptors are downloaded by the hash of the descriptor, not by the relay’s identity key: this prevents directory servers from attacking clients by giving them descriptors nobody else uses.

All directory information is uploaded and downloaded with HTTP.

## What’s different from version 2?

Clients used to download multiple network status documents, corresponding roughly to “status votes” above. They would compute the result of the vote on the client side.

Authorities used to sign documents using the same private keys they used for their roles as routers. This forced them to keep these extremely sensitive keys in memory unencrypted.

All of the information in extra-info documents used to be kept in the main descriptors.

## Voting timeline

Every consensus document has a “valid-after” (VA) time, a “fresh-until” (FU) time and a “valid-until” (VU) time. VA MUST precede FU, which MUST in turn precede VU. Times are chosen so that every consensus will be “fresh” until the next consensus becomes valid, and “valid” for a while after. At least 3 consensuses should be valid at any given time.

The timeline for a given consensus is as follows:

VA-DistSeconds-VoteSeconds: The authorities exchange votes. Each authority uploads their vote to all other authorities.

VA-DistSeconds-VoteSeconds/2: The authorities try to download any votes they don’t have.

`DistSeconds` and `VoteSeconds` are carried in the `voting-delay` item in the consensus.

Authorities SHOULD also reject any votes that other authorities try to upload after this time. (0.4.4.1-alpha was the first version to reject votes in this way.)

Note: Refusing late uploaded votes minimizes the chance of a consensus split, particular when authorities are under bandwidth pressure. If an authority is struggling to upload its vote, and finally uploads to a fraction of authorities after this period, they will compute a consensus different from the others. By refusing uploaded votes after this time, we increase the likelihood that most authorities will use the same vote set.

Rejecting late uploaded votes does not fix the problem entirely. If some authorities are able to download a specific vote, but others fail to do so, then there may still be a consensus split. However, this change does remove one common cause of consensus splits.

VA-DistSeconds: The authorities calculate the consensus and exchange signatures. (This is the earliest point at which anybody can possibly get a given consensus if they ask for it.)

VA-DistSeconds/2: The authorities try to download any signatures they don’t have.

VA: All authorities have a multiply signed consensus.
[code]
       VA ... FU: Caches download the consensus.  (Note that since caches have
            no way of telling what VA and FU are until they have downloaded
            the consensus, they assume that the present consensus's VA is
            equal to the previous one's FU, and that its FU is one interval after
            that.)

       FU: The consensus is no longer the freshest consensus.

       FU ... (the current consensus's VU): Clients download the consensus.
            (See note above: clients guess that the next consensus's FU will be
            two intervals after the current VA.)

[/code]

VU: The consensus is no longer valid; clients should continue to try to download a new consensus if they have not done so already.

VU + 24 hours: Clients will no longer use the consensus at all.

VoteSeconds and DistSeconds MUST each be at least 20 seconds; FU-VA and VU-FU MUST each be at least 5 minutes.

## Publishing the signed consensus

The voting period ends at the valid-after time. If the consensus has been signed by a majority of authorities, these documents are made available at

`http://<hostname>/tor/status-vote/current/consensus`

and

`http://<hostname>/tor/status-vote/current/consensus-signatures`
[code]
       [XXX current/consensus-signatures is not currently implemented, as it
        is not used in the voting protocol.]

       [XXX possible future features include support for downloading old
        consensuses.]

       The other vote documents are analogously made available under

    http://<hostname>/tor/status-vote/current/authority
    http://<hostname>/tor/status-vote/current/<fp>
    http://<hostname>/tor/status-vote/current/d/<d>
    http://<hostname>/tor/status-vote/current/bandwidth

[/code]

once the voting period ends, regardless of the number of signatures.

The authorities serve another consensus of each flavor “F” from the locations
[code]
    /tor/status-vote/(current|next)/consensus-F. and
    /tor/status-vote/(current|next)/consensus-F/<FP1>+....

[/code]

The standard URLs for bandwidth list files first-appeared in Tor 0.3.5.

## Router operation and formats

This section describes how relays must behave when publishing their information to the directory authorities, and the formats that they use to do so.

## Server descriptor format

Server descriptors consist of the following items.

In lines that take multiple arguments, extra arguments SHOULD be accepted and ignored. Many of the nonterminals below are defined in “Nonterminals in server descriptors”.

Note that many versions of Tor will generate an extra newline at the end of their descriptors. Implementations MUST tolerate one or more blank lines at the end of a single descriptor or a list of concatenated descriptors. New implementations SHOULD NOT generate such blank lines.

## Server descriptor items

### `router` — Introduce a router descriptor

  * **`router` _nickname_ _address_ _ORPort_ _SOCKSPort_ _DirPort_ ..**
  * At start, exactly once.

Indicates the beginning of a server descriptor.

**_nickname_** must be a valid router nickname as specified in “Nonterminals in server descriptors”. **_address_** must be an IPv4 address in dotted-quad format.

The last three numbers indicate the TCP ports at which this OR exposes functionality. **_ORPort_** is a port at which this OR accepts TLS connections for the main OR protocol; **_SOCKSPort_** is deprecated and should always be 0; and **_DirPort_** is the port at which this OR accepts directory-related HTTP connections. If any port is not supported, the value 0 is given instead of a port number. (At least one of _DirPort_ and _ORPort_ SHOULD be set; authorities MAY reject any descriptor with both _DirPort_ and _ORPort_ of 0.)

### `identity-ed25519` — Specify the router’s ed25519 identity

  * **`identity-ed25519`**
  * _certificate_ Object, `ED25519 CERT`
  * Exactly once, in second position in document.
  * No extra arguments.

**_certificate_** is an Ed25519 certificate on KP_relaysign_ed by KP_relayid_ed with terminating =s removed from its base64-encoding.

When this element is present, it MUST appear as the first or second element in the router descriptor.

_certificate_ has CERT_TYPE of [04]. It must include a signed-with-ed25519-key extension so that we can extract the master identity key.

[Before Tor 0.4.5.1-alpha, this field was optional.]

### `master-key-ed25519` — Redundantly specify the router’s ed25519 identity

  * **`master-key-ed25519` _MasterKey_ ..**
  * Exactly once.

Contains the base-64 encoded ed25519 master key as a single argument. If it is present, it MUST match the identity key in `identity-ed25519`.

[Before Tor 0.4.5.1-alpha, this field was optional.]

### `bandwidth` — Report router’s network bandwidth

  * **`bandwidth` _bandwidth-avg_ _bandwidth-burst_ _bandwidth-observed_ ..**
  * Exactly once.
  * Each argument is a number in decimal, in bytes per second.

Estimated bandwidth for this router. **_bandwidth-avg_** is the volume that the OR is willing to sustain over long periods; **_bandwidth-burst_** is the volume that the OR is willing to sustain in very short intervals.

**_bandwidth-observed_** is an estimate of the capacity this relay can handle: The relay remembers the max bandwidth sustained output over any ten second period in the past 5 days, and another sustained input. _bandwidth-observed_ value is the lesser of these two numbers.

Tor versions released before 2018 only kept bandwidth-observed for one day. These versions are no longer supported or recommended.

### `platform` — Describe the platform on which this relay is running

  * **`platform`** _string_ …
  * _string_ is the whole rest of the line
  * At most once

A human-readable string describing the system on which this OR is running. This MAY include the operating system, and SHOULD include the name and version of the software implementing the Tor protocol.

### `published` — Time this descriptor (and extra-info) was generated

  * **`published`** _date_ _time_ ..
  * _date_ _time_ is _YYYY_ -_MM_ -_DD_ _HH_ :_MM_ :_SS_ and is in UTC
  * Exactly once

When this descriptor (and its corresponding extra-info document if any) was generated.

### `fingerprint` – Redundant hash of ASN-1-encoding of router identity key

  * **`fingerprint`** _fingerprint_ ..
  * _fingerprint_ is multiple arguments — see below.
  * At most once

**_fingerprint_** is the hash `SHA1(DER(KP_relayid_rsa))`, encoded in hex, with a single space after every 4 characters. A descriptor is considered invalid (and MUST be rejected) if the fingerprint line does not match the public key.

### `hibernating` — Whether the relay is hibernating

  * **`hibernating`** bool ..
  * At most once

If the value is 1, then the Tor relay was hibernating when the descriptor was published, and shouldn’t be used to build circuits.

### `uptime` — How long this relay has been continuously running

  * **`uptime`** number
  * At most once

The number of seconds that this OR process has been running.

### `onion-key` — Relay’s obsolete RSA TAP key

  * **`onion-key`**
  * _key_ Object, `RSA PUBLIC KEY`
  * At most once, required if `onion-key-crosscert` is present
  * No extra arguments

This element MUST be present if `onion-key-crosscert` is present. Relays MUST generate this element unless the `publish-dummy-tap-key` network parameter is set to 0.

This obsolete RSA key was once used used to encrypt CREATE cells. It is no longer used. The key, if present, MUST be 1024 bits. Clients SHOULD validate this element if it is provided.

**_key_** is a DER PKCS#1 RSAPublicKey structure encoded as an Object.

### `onion-key-crosscert` — Reverse signature by obsolete TAP key

  * **`onion-key-crosscert`**
  * _signature_ cert NL a RSA signature in PEM format.
  * At most once, required if `onion-key` is present
  * No extra arguments

This element MUST be present if onion-key is present. Clients SHOULD validate this element if it is provided.

This element contains an RSA signature, generated using the onion-key, of the following:
[code]
              A SHA1 hash of the RSA identity key KP_relayid_rsa
                 from "signing-key" (see below) [20 bytes]
              The Ed25519 identity key KP_relayid_ed
                 from "master-key-ed25519" [32 bytes]

[/code]

If there is no Ed25519 identity key, or if in some future version there is no RSA identity key, the corresponding field must be zero-filled.

Parties verifying this signature MUST allow additional data beyond the 52 bytes listed above.

This signature proves that the party creating the descriptor had control over the secret key corresponding to the onion-key.

[Before Tor 0.4.5.1-alpha, this field was optional whenever identity-ed25519 was absent.]

### **`ntor-onion-key`** – KP_ntor, the circuit extension key

  * `ntor-onion-key` _KP_ntor_ ..
  * _KP_ntor_ is base64 (and MAY have the `=`-padding).
  * Exactly once

**_KP_ntor_** is the curve25519 public key used for the ntor circuit extended handshake.

The key MUST be accepted for at least 1 week after any new key is published in a subsequent descriptor.

[Before Tor 0.4.5.1-alpha, this field was optional.]

### `ntor-onion-key-crosscert` — Reverse cert by K_ntor on KP_relayid_ed

  * **`ntor-onion-key-crosscert`** _Bit_ ..
  * _certificate_ , Object `ED25519 CERT`
  * Exactly once
  * No extra arguments

**_certificate_** is an Ed25519 certificate created with the ntor-onion-key, with type [0a]. The certified key here is the master identity key. When validating this element, clients should use the signing key from the `ntor-onion-key` field, as the certificate _does not_ include the `signed-with-ed25519-key` extension.

**_Bit_** must be “0” or “1”. It indicates the sign of the ed25519 public key corresponding to the ntor onion key. If _Bit_ is “0”, then implementations MUST guarantee that the x-coordinate of the resulting ed25519 public key is positive. Otherwise, if _Bit_ is “1”, then the sign of the x-coordinate MUST be negative.

To compute the ed25519 public key corresponding to a curve25519 key, and for further explanation on key formats, see appendix C.

This signature proves that the party creating the descriptor had control over the secret key corresponding to the ntor-onion-key.

[Before Tor 0.4.5.1-alpha, this field was optional whenever identity-ed25519 was absent.]

### `signing-key` — KP_relayid_rsa, relay’s obsolete RSA identity key

  * **`signing-key`**
  * _KP_relayid_rsa_ , Object `RSA PUBLIC KEY`
  * Exactly once
  * No extra arguments

**_KP_relayid_rsa_** is the OR’s long-term RSA identity key. It MUST be 1024 bits.

The encoding is as for “onion-key” above.

### `accept`, `reject` — Exit policy

  * `accept` exitpattern
  * `reject`“ exitpattern
  * Any number

These lines describe the “exit policy”: the rules that this OR follows when deciding whether to allow a new stream to a given address.

There MUST be at least one such entry. The rules are considered in order; if no rule matches, the address will be accepted. For clarity, the last such entry SHOULD be accept _:_ or reject _:_.

The syntax is as follows:

exitpattern ::= addrspec “:” portspec

portspec ::= “*” | port | port “-” port

port ::= an integer between 1 and 65535, inclusive.

(Some implementations incorrectly generate ports with value 0. Implementations SHOULD accept this, and SHOULD NOT generate it. Connections to port 0 are never permitted.)

addrspec ::= “*” | ip4spec | ip6spec

ipv4spec ::= ip4 | ip4 “/” num_ip4_bits | ip4 “/” ip4mask

ip4 ::= an IPv4 address in dotted-quad format

ip4mask ::= an IPv4 mask in dotted-quad format

num_ip4_bits ::= an integer between 0 and 32

ip6spec ::= ip6 | ip6 “/” num_ip6_bits

ip6 ::= an IPv6 address, surrounded by square brackets.

num_ip6_bits ::= an integer between 0 and 128

### `ipv6-policy` — Exit policy summary for IPv6

  * `ipv6-policy` `accept`|`reject` _PortList_
  * At most once

An exit-policy summary summarizing the router’s rules for connecting to IPv6 addresses. A missing `ipv6-policy` line is equivalent to `ipv6-policy reject 1-65535`.

### `overload-general` — Relay is overloaded

  * `overload-general` _version_ _YYYY-MM-DD_ _HH:MM:SS_
  * At most once

Indicates that a relay has reached an “overloaded state” which can be one or many of the following load metrics:

  * Any OOM invocation due to memory pressure
  * Any ntor onionskins are dropped
  * TCP port exhaustion

The timestamp is when overload was detected by at least one metric. It should always be on the hour; so for example `2020-01-10 13:00:00` is an expected timestamp. Because this is a binary state, if the line is present, we consider that it was hit at the very least once somewhere between the `overload-general` timestamp, and the server descriptor’s `published` timestamp which is when the document was generated.

The `overload-general` line should remain in place for 72 hours after last triggered. If the limits are reached again in this period, the timestamp is updated, and this 72 hour period restarts.

The `version` field is set to `1` for now.

(Introduced in tor-0.4.6.1-alpha, but moved from extra-info to general descriptor in tor-0.4.6.2-alpha)

### `contact` — Server administrator contact information

  * `contact` _info_ ….
  * _info_ is the whole rest of the line
  * At most once

Describes a way to contact the relay’s administrator, preferably including an email address and a PGP key fingerprint.

**_info_** is starts with the first non-whitespace after the whitespace after `contact`, and is the whole rest of the line up to but not including the newline.

### `bridge-distribution-request` — Request distribution method

  * **`bridge-distribution-request`** _Method_ ..
  * At most once
  * Bridges only

**_Method_** describes how a Bridge address is distributed. Recognized methods are:

  * **`none`** — The distributor will avoid distributing your bridge address;
  * **`any``** — The distributor will choose how to distribute your bridge address;
  * **`https`** — specifies distribution via the web interface at https://bridges.torproject.org;
  * **`email`** — specifies distribution via the email autoresponder at bridges@torproject.org;
  * **`moat`** — specifies distribution via an interactive menu inside Tor Browser.

Potential future _Method_ s must be as follows:
[code]
    Method = (KeywordChar | "_") +

[/code]

All bridges SHOULD include this line. Non-bridges MUST NOT include it.

The bridge distributor SHOULD treat unrecognized Method values as if they were “none”.

(Default: “any”)

[This line was introduced in 0.3.2.3-alpha, with a minimal backport to 0.2.5.16, 0.2.8.17, 0.2.9.14, 0.3.0.13, 0.3.1.9, and later.]

> As of 2025, the bridge database is rdsys, which chooses from among many distribution methods. Previously, we used BridgeDB.

### `family` — Group relays for the purposes of path selectdion

  * **`family`** _name_ _name_ ..
  * One or more _name_ arguments
  * At most once

Each **_name_** _is a hexdigest. If two ORs list one another in their `family` entries, then OPs should treat them as a single OR for the purpose of path selection.

> In the past, we used to accept relay nicknames here as well. We started abolishing this implementation-wise in early 2026, because the format is basically not used anymore and opens a ton of open questions with regard to ambiguities.

For example, if node A’s descriptor contains `family B`, and node B’s descriptor contains `family A`, then node A and node B should never be used on the same circuit.

Relays should omit this entry if the `publish-family-list` parameter is 0.

### `family-cert` — Prove membership in a relay family

  * **`family-cert`**
  * _cert_ Object, `FAMILY CERT`.
  * Any number of times

The _cert_ object is a _family certificate_ , an ed25519 certificate proving this relay’s membership in the family corresponding to the certificate’s signing key.

In addition to regular validity and liveness constraints, the certificate must have these properties:

  * It must have its `CERT_TYPE` field set to `FAMILY_V_IDENTITY`.
  * It must include its signing key (KP_familyid_ed) in a signed-with-ed25519-key extension.
  * Its certified key must be the same as the relay’s KP_relayid_ed key, as listed in the identity-ed25519 entry.

A certificate meeting these constraints proves that the relay is a member of a family with the family ID `ed25519:`**FID** , where `FID` is the unpadded base-64 encoding of the certificate’s KP_relayid_ed key.

### `eventdns` — Declare support for non-obsolete DNS logic

“eventdns” bool NL

[At most once]

Declare whether this version of Tor is using the newer enhanced dns logic. Versions of Tor with this field set to false SHOULD NOT be used for reverse hostname lookups.

This option is obsolete. All Tor current relays should be presumed to have the evdns backend.

### `caches-extra-info` — Router hosts extra-info documents

“caches-extra-info” NL

[At most once.] [No extra arguments]

Present only if this router is a directory cache that provides extra-info documents.

[Versions before 0.2.0.1-alpha don’t recognize this]

### `extra-info-digest` — Hash of the extra-info document

  * **`extra-info-digest`** _sha1-digest_ [ _sha256-digest_ ] ..
  * At most once

**_sha1-digest_** is the SHA1 digest, hex-encoded using upper-case characters, of the router’s extra-info document, as signed in the router’s extra-info (that is, not including the signature).

If this Item is absent, the router does not have an extra-info document.

**_sha256-digest_** is the SHA256 digest, base64-encoded, of the extra-info document. Unlike the _sha1-digest_ , this digest is calculated over the entire document, including the signature.

> The difference in the inputs to the two digests is due to a long-lived bug in the tor implementation that it would be difficult to roll out an incremental fix for, not a design choice. Future digest algorithms specified should not include the signature in the data used to compute the digest.

[Versions before 0.2.7.2-alpha did not include a SHA256 digest.] [Versions before 0.2.0.1-alpha don’t recognize this field at all.]

### `hidden-service-dir` — Declares this router to be a Hidden Service directory

  * **`hidden-service-dir`** ..
  * At most once

Present only if this router stores and serves hidden service descriptors. This router supports the descriptor versions declared in the HSDir “proto” entry. If there is no “proto” entry, this router supports version 2 descriptors.

### `allow-single-hop-exits` — Declare support for single-hop exit circuits

“allow-single-hop-exits” NL

[At most once.] [No extra arguments]

Present only if the router allows single-hop circuits to make exit connections. Most Tor relays do not support this: this is included for specialized controllers designed to support perspective access and such. This is obsolete in tor version >= 0.3.1.0-alpha.

### `or-address` – Alternative ORport address and port

“or-address” SP ADDRESS “:” PORT NL

[Any number]

ADDRESS = IP6ADDR | IP4ADDR IPV6ADDR = an ipv6 address, surrounded by square brackets. IPV4ADDR = an ipv4 address, represented as a dotted quad. PORT = a number between 1 and 65535 inclusive.

An alternative for the address and ORPort of the “router” line, but with two added capabilities:
[code]
             * or-address can be either an IPv4 or IPv6 address
             * or-address allows for multiple ORPorts and addresses

[/code]

A descriptor SHOULD NOT include an or-address line that does nothing but duplicate the address:port pair from its “router” line.

An onion router MUST be reachable on all endpoints advertised here. Implementations MUST accept multiple values advertised here. Implementations MAY ignore values here at their discretion, but SHOULD accept at least the first IPv6 address/port pair.

The ordering of or-address lines and their PORT entries matter because Tor MAY only utilize a limited number of address/port pairs. As of Tor 0.2.3.x and Arti 2.3.0 only the first IPv6 address/port pair is advertised and used.

This means that right now, this item can practically only be used to advertise a single IPv6 endpoint for the relay, but this might change in the future for a round-robin approach.

### `tunnelled-dir-server` — Accepts BEGIN_DIR relay message via ORport

“tunnelled-dir-server” NL

[At most once.] [No extra arguments]
[code]
           Present if the router accepts "tunneled" directory requests using a
           BEGIN_DIR relay message over the router's OR port.
              (Added in 0.2.8.1-alpha. Before this, Tor relays accepted
              tunneled directory requests only if they had a DirPort open,
              or if they were bridges.)

[/code]

### `proto` \- Subprotocol capabilities supported

  * `proto` _entry_ _entry_ ..
  * Exactly once.
  * Zero or more _entry_ arguments.

Syntax of each _entry_ :
[code]
    entry = Keyword "=" Values

    Values =
    Values = Value
    Values = Value "," Values

    Value = Int
    Value = Int "-" Int

    Int = NON_ZERO_DIGIT
    Int = Int DIGIT

[/code]

Each **_entry_** indicates that the Tor relay supports all of the subprotocols capabilities in question. (See Subprotocol-based versioning for a definition of recognized keywords and values.) Entries should be sorted by keyword. Values should be numerically ascending within each entry. (This implies that there should be no overlapping ranges.) Ranges should be represented as compactly as possible. _Int_s must be no larger than 63.

This field was first added in Tor 0.2.9.x.

[Before Tor 0.4.5.1-alpha, this field was optional.]

### `router-sig-ed25519` — Signature

  * `router-sig-ed25519` _Signature_
  * Exactly once, at end, just before `router-signature`

Ed25519 signature by K_relaysign_ed (as certified in `identity-ed25519`) on the SHA256 digest of the document, as follows:

This digest is computed over:

  * the fixed string `Tor router descriptor signature v1`;
  * the contents of the document, starting at the beginning,
  * but, only up to and including the first space after the `router-sig-ed25519` keyword.

Note that this differs in several respects from the definition of a signature item.

The signature is encoded in Base64, with terminating =s removed.

[Before Tor 0.4.5.1-alpha, this field was optional whenever identity-ed25519 was absent.]

### `router-signature` — RSA signature

  * `router-signature`
  * _SIGNATURE_ Object, `SIGNATURE`
  * At end, exactly once
  * No extra arguments
  * RSA signature of the document by KP_relayid_rsa

The digest includes the `router-sig-ed25519` item.

## Serving bandwidth list files

If an authority has used a bandwidth list file to generate a vote document it SHOULD make it available at

`http://<hostname>/tor/status-vote/next/bandwidth`

at the start of each voting period.

It MUST NOT attempt to send its bandwidth list file in a HTTP POST to other authorities and it SHOULD NOT make bandwidth list files from other authorities available.

If an authority makes this file available, it MUST be the bandwidth file used to create the vote document available at

`http://<hostname>/tor/status-vote/next/authority`

To avoid inconsistent reads, authorities SHOULD only read the bandwidth file once per voting period. Further processing and serving SHOULD use a cached copy.

The bandwidth list format is described in bandwidth-file-spec.txt.

The standard URLs for bandwidth list files first-appeared in Tor 0.4.0.4-alpha.

## Standards compliance

All clients and servers MUST support HTTP 1.0. Clients and servers MAY support later versions of HTTP as well.

## HTTP headers

Servers SHOULD set Content-Encoding to the algorithm used to compress the document(s) being served. Recognized algorithms are:
[code]
         - "identity"     -- RFC2616 section 3.5
         - "deflate"      -- RFC2616 section 3.5
         - "gzip"         -- RFC2616 section 3.5
         - "x-zstd"       -- The zstandard compression algorithm (www.zstd.net)
         - "x-tor-lzma"   -- The lzma compression algorithm, with a "preset"
                             value no higher than 6.

[/code]

Clients SHOULD use Accept-Encoding on most directory requests to indicate which of the above compression algorithms they support.

Clients MUST NOT send wildcards (`*`) or qvalue weightings (`<ALGORITHM>`;q=<0-1>`).

Clients SHOULD NOT assume that the order of the supported algorithms in Accept-Encoding carries any signifcance.

Clients SHOULD write the Accept-Encoding as a single line separated by `, `.

In general, the grammar for the Accept-Encoding header can be summarized as:
[code]
    <ALGORITHM> ::= "identity" | "deflate" | "gzip" | "x-zstd" | "x-tor-lzma"
    <ACCEPT_ENCODING_VALUE> ::= <ALGORITHM> [ ", ", <ALGORITHM> ]*

[/code]

> The reason for these limitations lie within both: the primitiveness of the ctor `parse_accept_encoding_header` function as well as the lack of a widespread Rust library to support spec compliant parsing of this header, requiring us to implement it ourselves.
>
> Besides, the entire concept of this very advanced header syntax might have looked promising in the late 90s, but it is a rarely used feature these days, leading to not much of a good reason to support it.

To support older clients, and obsolete software, directory servers MUST also support GET requests to URLs with a “.z” suffix appended.

The semantics are as follows:

  * Clients SHOULD NOT request the `.z` URL.
  * Clients MUST NOT request a `.z` URL and include an `Accept-Encoding` hesder that fails to advertise `deflate`.
  * If the client does not send an `Accept-Encoding` header along with a `.z` URL, the server MUST send the response compressed with `deflate` and SHOULD NOT send a `Content-Encoding` header.
  * If the client _does_ send an `Accept-Encoding` header along with a `.z` URL, the server SHOULD treat the request the same way as for the URL without the `.z`. If `deflate` is included in the `Accept-Encoding`, the response MUST be encoded, once, with an encoding advertised by the client, and be accompanied by an appropriate `Content-Encoding`.

Note that these semantics are irreconcilable with the HTTP specifications, and may give rise to malfunctions or inconsistencies when `.z` URLs are queried by normal, standards-conforming, HTTP clients. This suffix is allowed on _all_ HTTP GET request URLs, except as explicitly noted. It is not supported on any HTTP POST request URLs.

> Tor clients started sending `Accept-Encoding` in 0.3.1.1-alpha, but they still request `.z` URLs when sending `Accept-Encoding`. Up until June 2025, Arti requested `.z` URLs. Other software that sends `.z` URLs probably also exists.

For all documents, servers MUST support `identity` and `deflate`, and SHOULD support `x-zstd`. Servers SHOULD support serving `current/consensus` and `current/consensus-microdesc` with `x-tor-lzma` compression; this includes consensus diffs.

For all documents, clients MUST support `identity` and `deflate`.

> For performance reasons, it will usually be necessary for each directory server to precalculate or cache the `x-tor-lzma` compressed form of the `consensus*` documents and diffs. For other documents and other compressions: `deflate` and `x-zstd` compression are cheap enough that it can be calculated on-the-fly in response to each directory client request.

Note that for anonymous directory requests (that is, requests made over multi-hop circuits, like those for onion service lookups) implementations SHOULD NOT advertise any Accept-Encoding values other than deflate. To do so would be to create a fingerprinting opportunity.

When receiving multiple documents, clients MUST accept compressed concatenated documents and concatenated compressed documents as equivalent.

Servers MAY set the Content-Length: header. When they do, it should match the number of compressed bytes that they are sending.

Servers MAY include an X-Your-Address-Is: header, whose value is the apparent IP address of the client connecting to them (as a dotted quad). For directory connections tunneled over a BEGIN_DIR stream, servers SHOULD report the IP from which the circuit carrying the BEGIN_DIR stream reached them.

Servers SHOULD disable caching of multiple network statuses or multiple server descriptors. Servers MAY enable caching of single descriptors, single network statuses, the list of all server descriptors, a v1 directory, or a v1 running routers document. XXX mention times.

## HTTP status codes

Tor delivers the following status codes. Some were chosen without much thought; other code SHOULD NOT rely on specific status codes yet.
[code]
      200 -- the operation completed successfully
          -- the user requested statuses or serverdescs, and none of the ones we
             requested were found (0.2.0.4-alpha and earlier).

      304 -- the client specified an if-modified-since time, and none of the
             requested resources have changed since that time.

      400 -- the request is malformed, or
          -- the URL is for a malformed variation of one of the URLs we support,
              or
          -- the client tried to post to a non-authority, or
          -- the authority rejected a malformed posted document, or

      404 -- the requested document was not found.
          -- the user requested statuses or serverdescs, and none of the ones
             requested were found (0.2.0.5-alpha and later).

      500 -- the server had an internal error, clients MAY retry.

      503 -- we are declining the request in order to save bandwidth
          -- user requested some items that we ordinarily generate or store,
             but we do not have any available.

[/code]

Tor HTTP server implementations MAY return status codes other than those listed here.

Tor HTTP client implementations MUST accept any status code and SHOULD consider them to be successful/failures according to IETF practices.

Tor HTTP server implementations SHOULD NOT return a 200 status code with an empty body in response to GET requests.

Tor HTTP client implementations SHOULD treat a 200 status code with an empty body from a GET request as an error and MAY handle it like a 404.

## Uploading server descriptors and extra-info documents

ORs SHOULD generate a new server descriptor and a new extra-info document whenever any of the following events have occurred:
[code]
          - A period of time (18 hrs by default) has passed since the last
            time a descriptor was generated.

          - A descriptor field other than bandwidth or uptime has changed.

          - Its uptime is less than 24h and bandwidth has changed by a factor of 2
            from the last time a descriptor was generated, and at least a given
            interval of time (3 hours by default) has passed since then.

          - Its uptime has been reset (by restarting).

          - It receives a networkstatus consensus in which it is not listed.

          - It receives a networkstatus consensus in which it is listed
            with the StaleDesc flag.

          [XXX this list is incomplete; see router_differences_are_cosmetic()
           in routerlist.c for others]

[/code]

ORs SHOULD NOT publish a new server descriptor or extra-info document if none of the above events have occurred and not much time has passed (12 hours by default).

Tor versions older than 0.3.5.1-alpha ignore uptime when checking for bandwidth changes.

After generating a descriptor, ORs upload them to every directory authority they know, by posting them (in order) to the URL

http://hostname:port/tor/

Server descriptors may not exceed 20,000 bytes in length; extra-info documents may not exceed 50,000 bytes in length. If they do, the authorities SHOULD reject them.

---

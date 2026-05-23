# The Dependency Problem: Nobody Knows What Their Software Runs Anymore

Modern software is no longer written as one program.

It is assembled from hundreds or thousands of small promises.

Each promise says: trust me.

The problem is that software does not only import code. It imports behavior, maintenance, politics, infrastructure, version drift, supply-chain risk, and hidden resource usage.

That is why the core rule for Edgerun is simple:

The core cannot depend on things the author cannot fully account for.

Start with the practical pain.

A program should not randomly write gigabytes of logs, caches, databases, traces, build artifacts, and temporary files because some dependency, tool, plugin, scanner, or helper decided that was normal.

If I cannot predict what the software will do on my own machine, I cannot responsibly ship it to someone else.

Dependencies are not just code reuse.

They are delegated authority.

A dependency may get access to:

- your build machine
- your filesystem
- your network
- your compiler
- your CI pipeline
- your release artifacts
- your users' data
- your package namespace
- your logs
- your update process

That is not free.

People say: just audit your dependencies.

That sounds responsible until the project has 1,000 packages, generated lockfiles, build scripts, platform-specific code paths, optional features, proc macros, native bindings, vendored archives, and transitive dependencies maintained by strangers.

At that point, auditing becomes theater.

You are not auditing the system.

You are sampling the pile and hoping the rest behaves.

A lockfile does not mean you understand your software. It only means the unknown pile is pinned in place.

Then comes the second ritual: automated scanning.

Scanners are useful. They catch known problems. They are better than doing nothing.

But a scanner can only report what its rules, databases, parsers, and integrations know how to see.

It does not make the dependency graph small. It does not make the code understandable. It does not remove build-time behavior. It does not prove the package is safe. It does not prove the program is sane.

And now the scanner itself becomes another dependency, another update feed, another parser of hostile files, another CI requirement, another trust root.

Scanning is a warning system. Minimalism is prevention.

We have already seen the pattern with security tools themselves: the tool added to reduce risk can become part of the risk surface.

That is not hypocrisy.

It is the nature of complexity.

This is why Edgerun has a zero-external-dependency rule for the core.

Not because code reuse is morally wrong.

Because the core is the trust boundary.

If the core protects identity, messages, storage, signing, routing, app containment, and resource accounting, then every external package inside that core becomes part of the trusted computing base.

That is unacceptable.

The smaller the core, the more honest the security claim.

Edgerun's zero-dependency rule is not minimalism for aesthetics.

It is accountability.

If the system is supposed to make everyone accountable for their actions, the system itself must be accountable for its own code.

The modern answer to complexity is usually more complexity: dependency managers, scanners, SBOMs, CI policies, container layers, signing services, admission controllers, and monitoring stacks.

Some of those tools are useful.

But they do not change the basic fact:

A system nobody understands cannot honestly be called secure.

Edgerun starts from the opposite direction.

Make the core small.

Make the behavior predictable.

Make resources explicit.

Make actions signed.

Make storage sealed.

Make dependencies exceptional, not normal.

Because if the foundation is supposed to protect the user, the foundation cannot be a thousand strangers in a trench coat.

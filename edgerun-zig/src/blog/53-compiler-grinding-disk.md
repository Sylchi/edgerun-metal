# My Computer Has 64GB of RAM. Why Is My Compiler Grinding My Disk?

I stopped using Rust and Cargo for one very simple reason: the build system was abusing my machine.

Not because Rust is a bad language. Not because memory safety is a bad goal. Not because package managers are useless.

Because the actual development experience became absurd.

I had vendored dependencies. I had plenty of RAM. I was not building on some tiny embedded machine. I was using a real workstation with 64GB of memory.

And still, the tooling was writing enormous amounts of data to disk. At one point, I was seeing what looked like terabytes of writes per day.

That was the moment I stopped seeing it as normal compiler behavior and started seeing it as a symptom of a deeper disease.

Modern development tooling still treats disk as the center of the universe.

Source code goes to disk. Dependencies go to disk. Build artifacts go to disk. Incremental state goes to disk. Metadata goes to disk. Caches go to disk. Temporary files go to disk. Logs go to disk.

Then the tool reads it all back, stats thousands of files, hashes them again, rebuilds dependency graphs, links artifacts, and writes another mountain of output.

Meanwhile, RAM sits there mostly empty.

This is insane.

RAM is where active computation should live. Disk should be for things worth keeping.

A build artifact that only exists to help the next build is not sacred user data. A temporary compiler output is not a personal memory. A cache is not the source of truth. It is disposable working state.

But because so much Unix-style tooling is built around everything being a file, disk becomes the coordination layer for everything. Instead of passing structured state through memory, tools serialize the world into files, then deserialize it again, over and over.

That model made sense when RAM was tiny, storage was simpler, and programs were smaller.

It makes much less sense when I have 64GB of RAM and my compiler still acts like the only reliable way to remember anything for five seconds is to scrape it across an SSD.

The problem is not just performance. It is observability and control.

When my computer becomes slow, I should not need to become a forensic investigator. I should not need to run tracing tools just to find out which build script, linker, cache, registry, proc macro, or hidden dependency is abusing the disk.

The machine should be able to tell me clearly:

- This app owns this memory.
- This app owns this storage.
- This cache is disposable.
- This output is durable.
- This process is writing 300GB today.
- This dependency is responsible.
- This state can be evicted safely.

Instead, modern development often gives you a giant pile of files and dares you to figure out what matters.

That is the deeper design failure.

We confuse stored with important.

Most things a computer touches are not worth storing forever. Most working state should live in memory. Things should become durable only when an authorized action makes them durable: a saved file, a signed message, a committed build output, a release artifact, a receipt, a checkpoint, an export.

Temporary computation should not constantly become disk pollution.

This is one of the reasons I moved toward a different model for Edgerun.

In Edgerun, memory is not treated as some accidental cache behind the real file system. Memory is the live world. Apps receive allocated memory from their parent. Subapps can only use what the parent gave them. If memory runs out, the user or parent runtime decides what to evict, prune, checkpoint, or kill.

Storage is not a dumping ground. It is preallocated, scoped, sealed, and accounted for.

An app that expects durable state should be given durable storage. An app that creates temporary working state should keep it in memory. If something matters, it should cross an explicit boundary: signature, authorization, storage commit, export, receipt, or checkpoint.

That is the difference.

Current model:

- The tool writes constantly.
- The disk suffers.
- The user investigates.

Better model:

- The runtime accounts for resources.
- The app lives inside its budget.
- Durable state is explicit.

I do not want my tools to treat my SSD like infinite scratch paper while my RAM sits unused.

I do not want build systems that hide resource abuse behind "that is just how compilers work."

I do not want to depend on ecosystems where even with vendored dependencies, my machine is still constantly churning through cache directories, artifact trees, metadata files, and hidden generated output.

A good tool should respect the machine it runs on.

A good runtime should know the difference between memory, storage, cache, and durable state.

A good system should not force the user to trace mystery I/O just to understand why their own computer is slow.

My computer has memory. Use it.

My disk is for things worth keeping.

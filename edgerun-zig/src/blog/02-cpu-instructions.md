# CPU: The Worker That Follows Instructions

The CPU does not understand apps, messages, photos, or websites.

It executes instructions.

Code becomes instructions. Instructions change memory. The operating system decides which program gets CPU time. Apps do not really run all at once; they take turns very fast.

## What the CPU does

- fetch an instruction
- decode what it means
- read values from memory or registers
- compute a result
- write the result somewhere
- move to the next instruction

## Main lesson

The CPU does not know what you want. It only knows the next instruction.

## Edgerun seed

A deterministic app runtime gives us a way to reason about what instructions were allowed to do, what memory they touched, and what authority they were given.

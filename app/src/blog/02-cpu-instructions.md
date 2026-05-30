# CPU: The Worker That Follows Instructions

The CPU does not understand apps, messages, photos, or websites.

It executes instructions.

Code becomes instructions. Instructions change memory. The operating system decides which program gets CPU time. Apps do not really run all at once; they take turns very fast.

That simple fact removes a lot of mystery. A program is not a spirit inside the machine. It is a long list of small operations: load this value, compare it with that value, jump here if the comparison passed, write the result back to memory, ask the operating system for permission to do something outside the process.

> Mental model: the CPU is obedient, not wise; it does exactly what authority lets code ask it to do.

## What the CPU does

- fetch an instruction
- decode what it means
- read values from memory or registers
- compute a result
- write the result somewhere
- move to the next instruction

The CPU is extremely literal. If the next instruction says to add two numbers, it adds them. If it says to copy bytes, it copies bytes. If it says to jump to a new location, it jumps. Meaning comes from the program, the data, and the authority around the instruction stream.

## Why apps take turns

A modern device runs many programs, but a CPU core still executes one instruction stream at a time. The operating system switches between tasks quickly enough that the user experiences overlap.

That switch is not free. The OS has to save the current task's state, choose another task, restore its state, and continue. This is why runaway software can make the whole device feel slow. It is also why a serious app runtime needs explicit limits instead of hoping every app behaves.

## When instructions leave the process

Many instructions only change private process state. Others request help from the operating system. Opening a file, sending a packet, drawing to a screen, reading a clock, or asking for randomness crosses out of the app's private world.

Those crossings matter more than the raw instruction count. A billion harmless arithmetic instructions may be less dangerous than one authorized write to the wrong key, file, or network destination.

## Tiny trace

```text
keypress -> app memory -> validate intent
intent -> OS boundary -> allowed action
allowed action -> object or packet
```

## Interactive model

[[demo:post_model]]

## Main lesson

The CPU does not know what you want. It only knows the next instruction and the boundaries that let that instruction affect the outside world.

## EdgeRun seed

A deterministic app runtime gives us a way to reason about what instructions were allowed to do, what memory they touched, and what authority they were given. The important question is not only "did the code run?" It is "what could the running code touch?"

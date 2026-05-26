# Radio Is Where Ownership Meets Physics, Law, And National Infrastructure

Your phone contains a second computer that talks to towers, and you are not really allowed to touch it.

Cellular modems, SIM and eSIM identity, IMEI, carrier locks, emergency calls, spectrum law, firmware blobs, and radio certification make phones different from ordinary computers.

> Mental model: radio is where personal computing meets shared spectrum and national infrastructure.

## Radio boundary

```text
apps and OS
  -> baseband
  -> carrier network
  -> regulated spectrum
  -> national infrastructure
```

Radio rules exist for real reasons. Bad transmitters can break shared spectrum. But the result is a major part of the device the owner cannot inspect or replace.

This is one of the places where simple slogans fail. "Open everything" runs into shared spectrum, emergency calling, carrier certification, lawful intercept rules, safety, and national infrastructure. But "lock everything forever" turns the user's device into a black box with an antenna.

## What the user controls

The phone has several authority zones:

- apps and user data
- main operating system
- SIM or eSIM identity
- baseband firmware
- carrier network policy
- radio certification
- emergency service requirements

The owner may control the first two partly, the SIM through a carrier relationship, and the rest barely at all.

## Honest boundary

A user-owned system should not pretend it controls the radio world. It should make the boundary visible:

```text
local app authority -> OS authority
OS authority -> modem interface
modem interface -> carrier authority
carrier authority -> regulated spectrum
```

Then it can minimize trust: keep user data sealed before it reaches radio paths, expose what the OS requested, avoid pretending carrier identity is personal identity, and support hardware where open control is legally possible.

## Interactive model

[[demo:post_model]]

Radio boundary map: separate OS control, SIM identity, carrier policy, emergency calling, firmware, and spectrum law.

## Main lesson

Radio is the place where personal ownership collides with physics, regulation, carriers, and national infrastructure.

## EdgeRun seed

A serious user-owned system should admit this boundary honestly and design around the parts users can control.

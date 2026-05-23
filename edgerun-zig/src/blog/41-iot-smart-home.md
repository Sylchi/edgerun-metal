# A Light Bulb Should Not Need A Cloud Account

Smart devices are only smart if they still work when the company goes offline.

Many smart home products require separate apps, cloud accounts, region locks, vendor servers, phone pairing, and proprietary firmware. A light switch becomes a dependency graph.

## Typical Path

```text
phone app
  -> vendor cloud
  -> account
  -> region policy
  -> home device
```

If the company dies, changes terms, or drops support, the device may become dumb or dead.

## Interactive Demo

Smart home dependency map: toggle local control, cloud control, Matter, Zigbee, MQTT, firmware updates, and account requirement. Watch what still works offline.

## Main Lesson

Local control should be the baseline. Cloud features can add convenience, but they should not be required to turn on a light.

## EdgeRun Seed

EdgeRun devices should expose local capabilities, signed firmware, and user-owned pairing so home infrastructure does not depend on vendor survival.

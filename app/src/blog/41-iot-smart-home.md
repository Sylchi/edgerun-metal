# A Light Bulb Should Not Need A Cloud Account

Smart devices are only smart if they still work when the company goes offline.

Many smart home products require separate apps, cloud accounts, region locks, vendor servers, phone pairing, and proprietary firmware. A light switch becomes a dependency graph.

> Mental model: home infrastructure should fail local, not depend on a vendor cloud staying kind.

## Typical path

```text
phone app
  -> vendor cloud
  -> account
  -> region policy
  -> home device
```

If the company dies, changes terms, or drops support, the device may become dumb or dead.

That is absurd for infrastructure. A light, lock, thermostat, sensor, camera, pump, or doorbell lives in a physical home. It should not need a remote account to perform the local job it was purchased for.

## Failure modes

Smart homes fail in ordinary ways:

- internet outage
- vendor cloud outage
- account lockout
- region change
- app removed from store
- unsupported phone OS
- abandoned firmware
- broken pairing server
- subscription added later

The house should not lose basic functions because a server far away changed mood.

## Better home shape

A good smart home has local authority first:

```text
owner key -> home hub
home hub -> device capability
device -> local action
cloud -> optional remote access
```

Cloud can help with remote control, backup, updates, and notification relay. It should not be the only brain.

Local protocols, signed firmware, inspectable pairing, and replaceable hubs make the home resilient instead of rented.

## Interactive model

[[demo:post_model]]

Smart home dependency map: toggle local control, cloud control, Matter, Zigbee, MQTT, firmware updates, and account requirement. Watch what still works offline.

## Main lesson

Local control should be the baseline. Cloud features can add convenience, but they should not be required to turn on a light.

## EdgeRun seed

EdgeRun devices should expose local capabilities, signed firmware, and user-owned pairing so home infrastructure does not depend on vendor survival.

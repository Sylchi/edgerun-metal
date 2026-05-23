# Every App Has A Second App Watching The First One

Telemetry is where private actions become business intelligence.

Even when message content is encrypted, modern systems collect logs, metrics, traces, crash reports, device IDs, performance timings, user journeys, A/B test buckets, fraud scores, and support events.

## The Shadow App

The visible app lets the user act.

The shadow app observes the action:

```text
tap
  -> analytics event
  -> trace
  -> metric
  -> experiment bucket
  -> fraud signal
  -> support log
```

## Interactive Demo

Shadow event stream: click "send message" and watch the invisible events that can be emitted around the visible action.

## Main Lesson

Encrypted transport does not stop internal extraction. Once an event reaches the service, it can be copied into every business system connected to it.

## EdgeRun Seed

Observability should belong to the user first. Local logs and signed receipts can prove behavior without turning every action into centralized intelligence.

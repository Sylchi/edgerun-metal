# Every App Has A Second App Watching The First One

Telemetry is where private actions become business intelligence.

Even when message content is encrypted, modern systems collect logs, metrics, traces, crash reports, device IDs, performance timings, user journeys, A/B test buckets, fraud scores, and support events.

> Mental model: telemetry is the second app watching what the first app does.

## The shadow app

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

The visible product may say "your message is private." That can be true for message content and still false for the surrounding behavior. The service may know when the app opened, how long the draft sat on screen, which button was tried first, which device was slow, which account looked risky, and which experiment changed the result.

## Why teams add it

Telemetry is not always malicious. Developers need crash reports. Operators need performance data. Fraud teams need abuse signals. Support teams need enough context to help users.

The problem is scope creep:

- debug event becomes product analytics
- product analytics becomes growth funnel
- growth funnel becomes ad profile
- ad profile becomes model training
- model training becomes hidden policy

The user clicked once. The organization learned many times.

## Better observability

Good observability answers a narrow question with minimum exposure:

- what failed
- which component failed
- what resource was used
- which version ran
- which signed action happened
- what the user can inspect later

It should not turn every action into a permanent behavioral dossier.

## Interactive model

[[demo:post_model]]

Shadow event stream: click "send message" and watch the invisible events that can be emitted around the visible action.

## Main lesson

Encrypted transport does not stop internal extraction. Once an event reaches the service, it can be copied into every business system connected to it.

## EdgeRun seed

Observability should belong to the user first. Local logs and signed receipts can prove behavior without turning every action into centralized intelligence.

# Your App Is Not One Thing

You opened a chat app. You may have also opened a tiny shopping mall of other people's code.

A modern app can include analytics, crash reporting, ad SDKs, notification SDKs, login providers, UI frameworks, crypto packages, cloud clients, logging, payments, experiments, feature flags, and many layers of dependencies below those.

## Purpose

Show that a friendly app icon can hide a large bundle of trust. The app is not just the feature the user asked for. It is the feature plus the code paths, update channels, telemetry, vendors, and policies attached to it.

## Visual idea

Chat App -> analytics -> ads -> push -> login -> cloud -> UI -> crypto -> logging -> payments -> experiments

## Interactive demo

Start with one block named Chat App. Click "install common SDKs" and it expands into the usual services. Click again and each dependency expands into sub-dependencies.

## Main lesson

Dependencies are not free. They consume storage, CPU, bandwidth, developer attention, update risk, and trust.

## EdgeRun seed

Small, inspectable apps running as deterministic WASM units can reduce the amount of code users must trust.

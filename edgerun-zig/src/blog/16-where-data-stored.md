# Where Is Your Data Actually Stored?

Your phone may show you the data, but the source of truth often lives somewhere else.

Phone data can live in local app storage, system storage, cloud sync, app backend databases, analytics systems, caches, logs, backups, notification providers, third-party SDKs, and AI or moderation pipelines.

## Purpose

Move from identity to memory. Deleting something from the app UI does not necessarily mean every copy disappeared.

## Visual idea

```text
photo, message, or note
  -> phone storage
  -> app storage
  -> cloud sync
  -> company database
  -> backups, logs, and analytics
```

## Interactive demo

A copy map follows a photo, message, or note through local storage, sync, database rows, search indexes, backups, analytics events, push systems, and moderation queues. Delete toggles show which copies remain.

## Main lesson

Modern apps often make the phone a viewer for a remote source of truth.

## EdgeRun seed

User-owned local-first storage should be the primary source of truth. Cloud should be replication, backup, or extra compute, not ownership.

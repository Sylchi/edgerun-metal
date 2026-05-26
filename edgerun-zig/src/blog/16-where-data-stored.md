# Where Is Your Data Actually Stored?

Your phone may show you the data, but the source of truth often lives somewhere else.

Phone data can live in local app storage, system storage, cloud sync, app backend databases, analytics systems, caches, logs, backups, notification providers, third-party SDKs, and AI or moderation pipelines.

The screen gives a false sense of location. If the phone shows the photo, note, or message, it feels like the phone owns it. Often the phone is only a cache, a viewer, or one replica in a larger company-controlled system.

> The trick: the screen is a receipt, not a deed. Ask which copy is allowed to overwrite the others.

## Copy map

[[demo:data_copy_map]]

One ordinary object can spread quickly:

```text
photo, message, or note
  -> phone storage
  -> app storage
  -> cloud sync
  -> company database
  -> backups, logs, and analytics
```

Deleting from the visible UI may remove one reference while other copies remain. Search indexes may keep derived text. Backups may retain old state. Logs may keep metadata. Analytics events may preserve behavior. Push providers may remember delivery. Moderation queues may hold review copies.

The user sees one object. The service may have a family of copies.

## Source of truth

The key question is not "where is a copy?" It is "which copy decides reality?"

If the company database is the source of truth, the phone is a window. If the local object store is the source of truth, the cloud can become replication. If both can write, the system needs conflict rules. If neither is verifiable, the user has to trust the app's story.

> Delete buttons are often theater unless backups, logs, indexes, analytics events, and derived models also lose authority over the story.

## A better storage question

Instead of asking "is it in the cloud?", ask "can I leave and still have the real object?"

For a note, that means the text, edit history, timestamps, attachments, and sharing state can export as something the user can verify. For a photo, it means the image, metadata, albums, edits, and permission history are not trapped in one database. For a message, it means the conversation has durable objects, not just a scroll view controlled by a server.

The cloud can still help. It can sync, back up, search, relay, and compute. But help is different from ownership.

## Main lesson

Modern apps often make the phone a viewer for a remote source of truth.

## EdgeRun seed

User-owned local-first storage should be the primary source of truth. Cloud should be replication, backup, or extra compute, not ownership. The user should be able to inspect, export, and verify the objects that define their own memory.

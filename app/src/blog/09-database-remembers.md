# The Database Remembers For You

When a service stores your message, it does more than remember text. It creates rows, indexes, backups, access paths, retention policy, deletion semantics, and breach risk.

Databases are powerful, but remote storage often turns memory into rent. The account owns access. The service owns the schema. The user hopes export, deletion, and migration work later.

A database is not a drawer. It is a machine for shaping memory. It decides which fields exist, which indexes are fast, which relations are possible, which old values remain in backups, and which questions the service can ask later.

> Mental model: a database does not merely remember; it decides what kinds of memory are easy to use.

## What a message becomes

```text
message -> row -> index -> replica
replica -> backup -> analytics copy -> export
```

A message that felt like text between two people becomes operational data. It may get an id, sender field, recipient field, timestamps, moderation state, delivery state, search index entry, notification record, backup copy, and metrics event.

Some of that is needed to run a service. The issue is authority. If the only meaningful copy lives in the service database, then the database defines reality.

## Remote memory changes behavior

Remote databases make product decisions easier for the operator:

- accounts can be suspended centrally
- features can query everyone at once
- analytics can measure behavior
- moderation can inspect state
- migrations can rewrite history
- exports can be limited
- deletion can mean policy, not physics

This can be useful for abuse control and service operation. It also means the user's memory is inside someone else's operating model.

## Local append history

An alternative is to treat important user events as signed local history:

```text
intent -> signed event -> canonical object
canonical object -> local store -> sync copy
```

The server may still store a copy, but it is no longer the only place reality exists. The user's device can verify and replay its own history.

## Interactive model

[[demo:post_model]]

## Main lesson

If someone else owns the memory of your app, they own the default future of your app.

## EdgeRun seed

Local object storage plus signed append-only history lets devices remember without surrendering the root of authority. A remote database can help distribute copies; it should not be the source of truth for what the user did.

# A Personal AI Must Not Belong To Someone Else

A personal AI is either the greatest user tool ever built or the most invasive surveillance product ever deployed. The difference is ownership.

The most useful assistant is the one that knows your messages, files, calendar, notes, photos, contacts, preferences, tasks, and history. The most dangerous assistant is also the one that knows all of that under someone else's account.

> Mental model: a personal AI is safe only when personal memory stays under personal authority.

## Authority map

- local model
- cloud model
- embeddings
- memory
- tool access
- private documents
- contact graph
- payment actions
- permission logs

An assistant is different from a search box because it can act. It may read files, summarize messages, send replies, schedule events, buy things, open links, call tools, and remember preferences.

That means the real question is not "is the model smart?" The real question is "who owns the context and who authorizes the actions?"

## Dangerous assistant shape

The dangerous shape is:

```text
all personal context -> cloud account
cloud account -> model memory
model memory -> tool access
tool access -> opaque actions
```

That creates a new root account with more intimate knowledge than email, search, photos, and chat combined.

## Better assistant shape

A personal assistant should be a local app with delegated authority:

- local memory by default
- explicit file scopes
- separate read and write permissions
- action previews
- signed action receipts
- revocable tool grants
- optional remote compute for narrow tasks
- visible retention

The assistant can be powerful without becoming a private cloud landlord for the user's mind.

## Interactive model

[[demo:post_model]]

Assistant authority map: grant an assistant access to files, messages, payments, contacts, and browser actions. The demo shows which data leaves the device and which actions are logged.

## Main lesson

AI memory must be local-first, inspectable, and governed by user capabilities. A helpful assistant should not require surrendering the user's life context to a platform.

## EdgeRun seed

EdgeRun should make personal AI an app under user authority: local context, sealed sharing, explicit tool grants, auditable actions, and optional external compute.

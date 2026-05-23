# The Server Receives Hello

The message reaches the server, but the server is not a neutral mailbox. It is code owned and operated by somebody else.

A simple "hello" can pass through load balancers, application handlers, queues, spam checks, moderation systems, logging, analytics, feature flags, and account policy before the other person ever sees it.

The word "server" hides a lot. It sounds like one machine waiting politely for requests. In practice, the message may enter a distributed operation owned by a company, shaped by deployment tools, observability systems, fraud checks, abuse policy, experiments, and retention rules.

## Inside the building

[[demo:server_pipeline]]

```text
TLS endpoint -> load balancer -> app handler
app handler -> policy -> queue -> delivery
app handler -> logs -> analytics -> database
```

That path can be reasonable engineering. Services need availability, spam control, retries, abuse handling, debugging, and delivery. The problem is that the same machinery can become the owner of the conversation.

## What the server can change

- accept or reject messages
- rewrite metadata
- delay delivery
- fan out copies
- create logs
- run policy checks
- attach account state
- decide which client sees which version
- keep backups after the user deletes local state

Once the server is authoritative, the user interface becomes a remote control for server policy. The app may show "your messages," but the service decides which account can open them, which export format exists, which history is retained, and which clients are allowed.

## Useful server, dangerous authority

A server can be useful without owning the state. It can relay sealed objects, help devices find each other, queue delivery while a peer is offline, rate-limit abuse, or provide paid capacity. Those are coordination jobs. They do not require the server to become the root of identity and memory.

## Main lesson

Once the server owns the state, the user is asking permission to use their own conversation.

## EdgeRun seed

EdgeRun apps should let the server become optional coordination, not the owner of the user's message state. The message should remain a verifiable object whose authority comes from the users, not from the database row that happened to store it.

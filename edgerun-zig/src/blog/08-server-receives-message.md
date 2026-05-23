# The Server Receives Hello

The message reaches the server, but the server is not a neutral mailbox. It is code owned and operated by somebody else.

A simple "hello" can pass through load balancers, application handlers, queues, spam checks, moderation systems, logging, analytics, feature flags, and account policy before the other person ever sees it.

## Purpose

Turn the server from a vague cloud shape into a concrete trust boundary. The server can help route messages, but it can also become the authority over state, accounts, policy, and access.

## Visual idea

TLS endpoint -> load balancer -> app handler -> policy -> queue -> logs -> delivery service

## Interactive demo

A server boundary map lets the reader move the message through each internal step. Clicking a step reveals who operates it, what it can change, and what metadata it can store.

## Main lesson

Once the server owns the state, the user is asking permission to use their own conversation.

## EdgeRun seed

EdgeRun apps should let the server become optional coordination, not the owner of the user's message state.

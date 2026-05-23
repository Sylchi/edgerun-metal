# How Does Your Phone Know You Are You?

When your phone says "this is you," who decided that?

A phone does not magically know you. It recognizes signals: SIM card, unlock PIN, fingerprint or face unlock, Apple ID, Google account, app accounts, phone number, email address, serial number, hardware identifiers, push tokens, payment cards, location history, contacts, and behavior patterns.

The phone is not identifying a soul. It is correlating evidence. Some evidence is local, like a PIN unlocking a device. Some is biometric, like face or fingerprint unlock. Some is networked, like a SIM registration or push token. Some is commercial, like a payment card or app account. Some is behavioral, like location and usage history.

## The signal stack

When a service decides "this is you," it may combine:

- device unlock
- SIM or eSIM
- phone number
- platform account
- app account
- payment method
- device attestation
- contacts and social graph
- location pattern
- notification token
- recovery email

Each signal has a different owner. The user may control a PIN, but not the cellular carrier database. The user may control an email password, but not the platform account's risk scoring. The user may present a fingerprint, but the trusted path that accepts it belongs to the device vendor.

## Correlation is not ownership

```text
person -> device unlock -> platform account
platform account -> app account -> service policy
```

This stack can be convenient. It can also trap identity inside systems the user cannot carry away. If the phone number is lost, the account may fail. If the platform account is locked, apps may fail. If the device attestation is rejected, the bank may fail. The person did not disappear. The correlation system stopped accepting them.

## Main lesson

Your identity on a phone is not one thing. It is a stack of proofs, accounts, permissions, and databases.

The phone does not know you. It recognizes enough signals to let different companies treat you as the same person.

## EdgeRun seed

Identity should start with keys controlled by the user and device, not with an email account or platform account. Other signals can help with names, recovery, reputation, and routing, but they should not become the root.

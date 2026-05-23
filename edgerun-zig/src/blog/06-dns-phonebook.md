# DNS: The Internet's Phonebook That Someone Else Controls

You do not really connect to a name. You ask someone where the name points today.

When you type a domain, your device asks a resolver for an address. The resolver may ask root servers, a top-level domain, and an authoritative server before returning an IP address. This makes names useful, but it also creates trust in resolvers, registrars, caches, domain owners, and network policy.

Names feel permanent because humans need them to be memorable. The machinery underneath is not permanent. It is delegated, cached, leased, updated, filtered, blocked, sold, seized, expired, and sometimes lied about.

## The lookup path

```text
friend.example -> resolver -> root
root -> example registry -> authoritative server
authoritative server -> address
```

Usually this happens quickly enough that it feels like the name just exists. But the result depends on which resolver you asked, which cache it used, whether the domain still belongs to the expected owner, whether the registrar changed records, whether the network is blocking names, and whether the authoritative server is available.

## A name is not an identity

A domain name is a routing label controlled through administrative systems. It is not the same thing as a cryptographic identity. The owner of the domain can change. The registrar can suspend it. The state can compel changes. The resolver can return different answers. A certificate can prove control of a name under the public certificate system, but that still roots trust in the naming system.

Names are useful because people can remember them. They are dangerous when treated as the root of truth.

## Failure modes

- resolver lies or filtering
- stale cache
- domain expiry
- registrar seizure
- typo or lookalike domain
- authoritative server compromise
- address change without user awareness

The user sees a friendly string. The network sees a chain of delegated control.

## Main lesson

Names are human-friendly, but ownership and routing are political and economic systems.

## EdgeRun seed

Identity should be cryptographic first. Names should be labels, not the root of trust. A friendly name can point to a key, but it should not be allowed to replace the key.

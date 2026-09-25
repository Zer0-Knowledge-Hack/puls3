# Proposal: identity-registry-cleanup

## Why
Comment hygiene and gitignore hardening for the identity registry.
Keeps the contract readable and prevents secret leaks.

## What
- Trim header and redundant docs in `identity-registry/src/lib.rs`.
- Keep only auth/error/event/TTL docs. No logic change.
- Harden root and `contracts/` gitignore files.

## Non-goals
- No interface, signature, error, event, or storage change.
- No behavior or gas change.

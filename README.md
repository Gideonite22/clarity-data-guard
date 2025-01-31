# DataGuard

A decentralized system for protecting sensitive data on the Stacks blockchain. DataGuard implements a secure access control system where data owners can grant and revoke access permissions to their encrypted data.

## Features

- Store encrypted data references on-chain
- Grant and revoke access permissions to specific principals
- Time-limited access control with automatic expiry
- Track access history
- Data owner controls
- Permission management system

## Getting Started

1. Deploy the contract
2. Store your encrypted data reference using `store-data`
3. Grant access to other users using:
   - `grant-access` for permanent access
   - `grant-access-with-expiry` for time-limited access
4. Revoke access using `revoke-access`

## Time-Limited Access Control

The new time-limited access control feature allows data owners to grant temporary access to their data. When granting access, owners can specify an expiry block height after which the access will automatically expire.

Example usage:
```clarity
;; Grant access that expires after 1000 blocks
(grant-access-with-expiry 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 (some (+ block-height u1000)))
```

Use `check-access` to verify if access is still valid - it will return false if the permission has expired.

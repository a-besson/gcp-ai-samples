# 002 — Agent Identity instead of service accounts
**Date:** 2026-10-01 | **Status:** accepted

## Context
Agent Gateway and semantic governance require agents deployed with `identity_type = "AGENT_IDENTITY"`. The project is not attached to an organization.

## Decision
Both agents use Agent Identity. The IAM principal is derived from the `effective_identity` output (trust domain `agents.global.proj-<PROJECT_NUMBER>.system.id.goog`), never hardcoded. Agent identities cannot receive `storage.legacyBucket*` roles, so bucket access uses `roles/storage.objectUser` on a managed folder.

## Consequences
No keys, no service-account impersonation chain. No organization means no org policy (`resourceLocations`): location control relies on resource configuration and validation blocks.

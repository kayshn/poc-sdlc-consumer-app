---
name: secure-api-review
description: Apply the API security standard. Use whenever creating or modifying an endpoint, reviewing API code, or writing a spec that adds or changes an endpoint.
---
# Secure API review

<!-- TEMPLATE: rewrite each rule in terms of this project's own helpers, types and function names.
     A rule that names the actual code ("every endpoint depends on require_user") is enforceable;
     a generic one is not. Delete this skill entirely if the project has no API. -->

When you create, change, specify or review an API endpoint:
1. Authentication: every endpoint goes through the project's auth dependency; no anonymous routes except an unauthenticated health check.
2. Input validation: request bodies are parsed into a declared schema type and unknown fields are rejected.
3. Audit: every state-changing endpoint records an audit event (actor, action, entity).
4. Ownership: every read and write is scoped to the authenticated caller's id; another user's record is a 404, not a 403.
5. Data classification: user-supplied content must never appear in logs or error messages. Use explicit response models so internal fields are never returned.

Run `make test` and include its output in your summary.

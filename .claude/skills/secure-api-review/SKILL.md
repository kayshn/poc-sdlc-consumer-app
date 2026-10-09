---
name: secure-api-review
description: Apply the API security standard. Use whenever creating or modifying an endpoint, reviewing API code, or writing a spec that adds or changes an endpoint.
---
# Secure API review

When you create, change, specify or review an API endpoint in `src/app/main.py`:

1. **Authentication.** Every route takes `user: str = Depends(require_user)`. The only anonymous
   routes are `GET /health` and `GET /{code}`, and adding a third needs a line in the spec saying why.
2. **Input validation.** Request bodies are a `BaseModel` with `model_config = ConfigDict(extra="forbid")`.
   Never read a field straight off the request.
3. **Redirect targets.** Any URL that will be returned in a `Location` header is parsed with
   `urlparse` and rejected unless its scheme is in `ALLOWED_SCHEMES` and it has a `netloc`.
   `javascript:`, `data:` and scheme-relative targets are open-redirect holes.
4. **Audit.** Every state-changing route by an authenticated caller calls
   `store.record(user, "<entity>.<action>", code)`. Pass the code, never the target.
   The one exemption is `GET /{code}`: it is anonymous, so there is no actor to record, and an
   audit entry for it could only be assembled from the request, which rule 7 forbids. It increments
   a bare counter through `store.count_follow` instead, which keeps nothing about the caller.
   A second exemption needs a line in the spec saying why, and a change to this rule.
5. **Ownership.** Reads and writes filter on `link.owner == user`. Another user's link is a **404,
   not a 403** — a 403 confirms the code exists.
6. **Codes are secrets.** Generate them with `secrets.token_urlsafe`, never a counter, a hash of the
   target, or anything guessable. `GET /{code}` is unauthenticated, so the code is the only control.
7. **Data classification.** A target URL is user content: it must never reach a log line, an error
   message or an audit entry. Return `LinkOut`, never the `Link` dataclass, so `owner` stays internal.

Run `make test` and include its output in your summary.

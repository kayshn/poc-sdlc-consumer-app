# Spec: link follow count
Intent: .sdlc/intent/002-link-follow-count.md. Skills applied: write-spec, secure-api-review. Status: approved (auto)

## Summary
Each link carries a `follow_count`: the number of times `GET /{code}` has successfully issued a
redirect for it. The count is returned as part of `LinkOut`, so an owner sees it on `POST /links`
(always 0) and on every entry of `GET /links`. The count is a bare integer on the link. It is not an
audit entry and records nothing about the request, the caller or the target.

## Requirements
1. `Link` gains an integer `follow_count`, initialised to 0 when the link is created.
2. A `GET /{code}` that returns the 307 redirect increments that link's `follow_count` by exactly 1.
3. A `GET /{code}` that returns 404 (unknown code, or expired link) increments nothing, for any link.
4. `LinkOut` gains `follow_count: int`. `POST /links` returns `follow_count == 0`; `GET /links`
   returns the current count for each of the caller's links.
5. A link that has never been followed shows `follow_count == 0` in `GET /links`.
6. Following a link does not call `store.record` and adds nothing to `store.audit`; `store.audit` is
   byte-for-byte unchanged by a follow.
7. Following stores nothing derived from the request (no caller identity, header, IP, timestamp of
   follow, or target). The only new state is the integer.
8. The responses for an unknown code, an expired code and another user's code on `GET /links`/
   `DELETE /links/{code}` are unchanged: same status and body as before this change. No new route
   or query parameter exposes a count by code.
9. `follow_count` is never returned to a non-owner: it only appears in `LinkOut`, which is only
   returned from owner-filtered routes. No count is added to the redirect response.
10. N concurrent successful follows of one link yield `follow_count == N` (no lost updates).
11. Deleting a link discards its count with it; no count survives for a deleted code.
12. No new dependency, no new datastore, no new log line. No route is added, so the `/{code}`
    catch-all ordering is unaffected.
13. No `follow_count` field is accepted on any request body (`CreateLink` is unchanged and keeps
    `extra="forbid"`), so a count cannot be set or reset by a caller.

## Design
- Data: `Link.follow_count: int = 0` in `src/app/main.py`. Storage stays in-memory.
- `follow()`: after the existing unknown/expired check (the single shared 404 branch, untouched),
  increment the count, then return the redirect. The increment sits strictly after the 404 branch
  so requirement 3 holds by construction.
- Concurrency: FastAPI runs sync handlers in a threadpool and `+= 1` on an attribute is not atomic.
  Guard the increment with a `threading.Lock` held on `Store` (stdlib, not a dependency) and expose
  it via a small `Store` method, e.g. `count_follow(link)`. Plan stage picks the exact shape.
- Response: add `follow_count: int` to `LinkOut` (resolves the intent's open question: nothing else
  consumes `LinkOut`, so one model is simpler than a separate list-only shape). `response_model`
  already strips `owner`. The field is additive, so existing clients are not broken.
- Semantics: the count is "redirects issued", not "browsers that landed". Prefetchers, link
  unfurlers and bots that hit the URL are counted. Documented, not filtered.
- Tests (for the plan): follow increments; 404 for unknown and expired does not; audit unchanged;
  other user's `GET /links` never shows the count; concurrent follows; `POST` returns 0; delete
  then re-list.

## Policy check
- secure-api-review 1 Authentication: satisfied. No route added or changed in auth. `GET /{code}` is
  already one of the two permitted anonymous routes; no third is introduced. `GET /links` and
  `POST /links` keep `require_user`.
- secure-api-review 2 Input validation: satisfied. No new request input; `CreateLink` untouched.
- secure-api-review 3 Redirect targets: concern. `follow()` already returns `link.target` without
  re-parsing; safety rests on validation in `create_link`. This change does not make it worse, and
  the spec does not widen scope to fix it, but see Areas of concern.
- secure-api-review 4 Audit: concern. `GET /{code}` now mutates state, and the rule says every
  state-changing route calls `store.record`. Intent constraint forbids this. See Areas of concern.
- secure-api-review 5 Ownership: satisfied. Counts are only exposed via owner-filtered routes;
  404-not-403 behaviour is unchanged and unknown/expired/foreign stay indistinguishable.
- secure-api-review 6 Codes are secrets: satisfied. Code generation unchanged. Counting does not
  create a way to confirm a code exists.
- secure-api-review 7 Data classification: satisfied. Target is not logged, audited or counted by
  value; `LinkOut` still excludes `owner`.
- Guardrail G3 (no new runtime dependency): satisfied; `threading` is stdlib.
- Guardrail G5 (user input never reaches a log/artefact): satisfied; nothing from the request is stored.

## Areas of concern
1. **Contradiction: audit rule vs intent constraint.** secure-api-review rule 4 and CLAUDE.md say
   every state-changing route calls `store.record(user, "<entity>.<action>", code)`. The intent says
   a follow count is not an audit trail and must not record who followed. `GET /{code}` is
   anonymous, so there is no `user` to record, and an entry would also create exactly the
   follow log the intent prohibits. This spec **follows the intent** (no `store.record` on follow)
   and treats the count as a counter, not a state change worth auditing. That deviates from the
   literal wording of rule 4. The policy owner should confirm, ideally by amending the rule to
   exempt anonymous counter increments. Until then this is a known, deliberate non-conformance.
2. **Anonymous write on a public route.** Anyone who knows a code can inflate its count with
   repeated requests, and bots/prefetchers are counted. The count is a usage hint, not a reliable
   metric. Rate limiting is out of scope and there is none today. Product owner should accept this.
3. **Pre-existing, not changed here:** `follow()` does not re-validate the target against
   `ALLOWED_SCHEMES` before the `Location` header (rule 3). Safe today only because `create_link`
   is the single writer. Recommend a separate intent rather than widening this one.
4. **Not addressed:** the intent's motivation (unbounded store growth) is only enabled by this
   change, not solved. Nothing deletes unused links automatically.

## Open questions carried forward
- Expired vs unknown counted separately: **answered, no.** Neither increments anything (req. 3, 7),
  so nothing new distinguishes them.
- Count in `LinkOut` or separate field: **answered, `LinkOut`** (see Design).
- Carried forward: confirmation of concern 1 (audit rule exemption) from the policy owner; this
  blocks approval of the spec, not the design.

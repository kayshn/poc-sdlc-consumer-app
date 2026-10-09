# Intent: show how many times a link has been followed
Author: K1 (platform). Status: accepted. Source: idea

## Problem
Someone who shortens a link has no way to tell whether anyone used it. There is no signal to
distinguish a link worth keeping from one that was created by mistake, so nothing is ever deleted
and the store grows without bound. Today the only record of a follow is the redirect itself, which
is not retained anywhere.

## Proposed outcome
A link reports how many times it has been followed. An owner listing their links sees the count
alongside each one, so a link that has never been used is visible at a glance.

## Affected users and systems
Authenticated callers of `GET /links` and `POST /links`. The redirect path `GET /{code}`, which
gains a write on a request that is currently read-only. No change for anonymous callers, who
continue to see only the redirect.

## Constraints
- In-memory storage stays in-memory; this is not a reason to add a datastore or a dependency.
- A follow count is not an audit trail. Counting must not start recording who followed a link,
  nor the target, nor anything else derived from the request.
- The count must not leak the existence of a link to someone who does not own it: an unknown code
  and someone else's code must stay indistinguishable.
- Expired links still answer 404 on follow, and a 404 must not increment anything.

## Out of scope
- Per-day, per-referrer or per-region breakdowns.
- Resetting or editing a count.
- Exposing counts to anyone other than the link's owner.

## Open questions
- Should a follow that lands on an expired link be counted separately from one that never matched
  a code at all? Default to no — both are 404s and distinguishing them in the data is a step
  towards distinguishing them to a caller.
- Is the count part of `LinkOut`, or a separate field only returned by `GET /links`? Spec stage to
  decide; `LinkOut` is the simpler answer if nothing else consumes it.

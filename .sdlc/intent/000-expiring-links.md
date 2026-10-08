# Intent: Expiring links
Author: kayshn (platform). Status: draft. Source: idea

## Problem
A short link lives forever. Someone who shares a link to a time-limited resource — a draft
document, a one-off download, an invite — has no way to make it stop working. The only way to
revoke access today is to remember to call `DELETE /links/{code}`, which in practice nobody does.
Codes are unguessable, so a link that leaks stays valid indefinitely, and the person who created it
usually does not find out.

## Proposed outcome
A caller can say how long a link should last when they create it. Once that time has passed,
following the link no longer resolves. Links created without a lifetime keep behaving exactly as
they do now.

## Affected users and systems
- Callers of `POST /links`, who gain an optional lifetime.
- Anyone following a `GET /{code}` link, who may now find it no longer resolves.
- Owners listing their links with `GET /links`.
- No other service. Storage is in-memory and there is no scheduler.

## Constraints
- Must not change the behaviour of existing calls: a request without a lifetime behaves as today.
- Storage stays in-memory (`store`); no database and no background cleanup process.
- Expiry is a property of the link, so it must not be inferable by someone who only has the code
  and no authorisation — see Open questions.
- The audit trail records codes, never targets, and that must continue to hold.

## Out of scope
- Changing or extending the lifetime of a link after it has been created.
- Bulk expiry, or expiring every link belonging to a user.
- Notifying an owner that a link has expired.
- Any form of scheduled or background cleanup.

## Open questions
- Should following an expired link return **404** or **410**? A 410 is more truthful, but it
  confirms to an unauthenticated caller that the code once existed, which a 404 does not.
- Does `GET /links` still list an owner's expired links, and if so are they marked?
- Is the lifetime expressed as a duration (seconds) or an absolute timestamp, and is there a
  maximum? Is there a default for callers who omit it, or does omitting it mean "never"?
- What should a zero or negative lifetime do — reject with 422, or create an already-expired link?
- Are expired links removed from `store.links`, or retained so their codes are never reissued?
  Reissuing a code that someone still holds would send them somewhere new without warning.

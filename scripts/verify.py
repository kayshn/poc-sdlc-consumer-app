"""Exercise the app directly, not through pytest: `make verify`.

The verifier agent runs this before a session reports done. It is deliberately not a test — it
prints what happened so a human or an agent can compare it against the plan's "Proof" section.
Exit status still matters: the ownership checks at the end are the ones most easily broken by a
change that looks right in isolation.
"""

import sys

from fastapi.testclient import TestClient

from app.main import app, store

c = TestClient(app, follow_redirects=False)


def show(label: str, value: object) -> None:
    print(f"{label:<28} {value}")


created = c.post("/links", json={"target": "https://example.com/a"}, headers={"X-User-Id": "alice"})
show("POST /links", f"{created.status_code} {created.json()}")
code = created.json()["code"]

followed = c.get(f"/{code}")
show("GET /{code}", f"{followed.status_code} -> {followed.headers.get('location')}")
show("audit after follow", store.audit)
show("follow_count", c.get("/links", headers={"X-User-Id": "alice"}).json()[0]["follow_count"])

# Another user must see a 404, never a 403, and never the link in their own list. A 403 would
# confirm the code exists, which is the whole reason this is checked separately from the tests.
as_bob = c.get("/links", headers={"X-User-Id": "bob"})
deleted_by_bob = c.delete(f"/links/{code}", headers={"X-User-Id": "bob"})
show("GET /links as bob", as_bob.json())
show("DELETE as bob", deleted_by_bob.status_code)

failures = []
if deleted_by_bob.status_code != 404:
    failures.append(f"another user's link returned {deleted_by_bob.status_code}, expected 404")
if as_bob.json():
    failures.append("another user's link is visible in their list")
if any(code not in entry.values() for entry in store.audit if entry["action"] == "link.create"):
    failures.append("audit entry does not carry the code")

for line in failures:
    print(f"FAIL {line}", file=sys.stderr)
sys.exit(1 if failures else 0)

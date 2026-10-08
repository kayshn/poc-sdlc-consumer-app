from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.main import MAX_TTL_SECONDS, app, store


@pytest.fixture(autouse=True)
def clean_store():
    store.links.clear()
    store.audit.clear()
    yield


@pytest.fixture
def client():
    return TestClient(app, follow_redirects=False)


def create(client, target, user="alice"):
    return client.post("/links", json={"target": target}, headers={"X-User-Id": user})


def test_health_needs_no_auth(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_create_then_follow(client):
    code = create(client, "https://example.com/a").json()["code"]
    response = client.get(f"/{code}")
    assert response.status_code == 307
    assert response.headers["location"] == "https://example.com/a"


def test_links_require_a_user(client):
    assert client.post("/links", json={"target": "https://example.com"}).status_code == 401


def test_non_http_targets_are_rejected(client):
    for target in ("javascript:alert(1)", "data:text/html,x", "/relative"):
        assert create(client, target).status_code == 422


def test_unknown_fields_are_rejected(client):
    response = client.post(
        "/links",
        json={"target": "https://example.com", "owner": "mallory"},
        headers={"X-User-Id": "alice"},
    )
    assert response.status_code == 422


def test_listing_shows_only_your_own(client):
    create(client, "https://example.com/alice", user="alice")
    create(client, "https://example.com/bob", user="bob")
    codes = client.get("/links", headers={"X-User-Id": "alice"}).json()
    assert [link["target"] for link in codes] == ["https://example.com/alice"]


def test_deleting_someone_elses_link_is_404(client):
    code = create(client, "https://example.com/a", user="alice").json()["code"]
    response = client.delete(f"/links/{code}", headers={"X-User-Id": "bob"})
    assert response.status_code == 404
    assert code in store.links


def test_owner_is_never_returned(client):
    assert "owner" not in create(client, "https://example.com/a").json()


def test_audit_records_the_code_not_the_target(client):
    create(client, "https://example.com/secret-path")
    assert store.audit[0]["action"] == "link.create"
    assert "secret-path" not in str(store.audit)


def create_ttl(client, ttl, user="alice"):
    return client.post(
        "/links",
        json={"target": "https://example.com/t", "ttl_seconds": ttl},
        headers={"X-User-Id": user},
    )


def expire(code):
    store.links[code].expires_at = datetime.now(UTC) - timedelta(seconds=1)


def test_no_ttl_never_expires(client):
    body = create(client, "https://example.com/a").json()
    assert body["expires_at"] is None
    assert body["expired"] is False
    assert client.get(f"/{body['code']}").status_code == 307


def test_ttl_link_redirects_before_expiry(client):
    body = create_ttl(client, 60).json()
    assert body["expires_at"] is not None
    assert body["expired"] is False
    assert client.get(f"/{body['code']}").status_code == 307


def test_expiry_boundary_is_inclusive(client):
    code = create_ttl(client, 60).json()["code"]
    link = store.links[code]
    assert not link.is_expired(link.expires_at - timedelta(microseconds=1))
    assert link.is_expired(link.expires_at)


def test_expired_follow_matches_unknown_code(client):
    code = create_ttl(client, 60).json()["code"]
    expire(code)
    expired = client.get(f"/{code}")
    unknown = client.get("/doesnotexist")
    assert expired.status_code == unknown.status_code == 404
    assert expired.content == unknown.content
    assert expired.headers == unknown.headers
    assert "location" not in expired.headers


def test_expired_links_are_retained_and_listed_for_owner_only(client):
    code = create_ttl(client, 60).json()["code"]
    expire(code)
    assert code in store.links
    mine = client.get("/links", headers={"X-User-Id": "alice"}).json()
    assert [(link["code"], link["expired"]) for link in mine] == [(code, True)]
    assert client.get("/links", headers={"X-User-Id": "bob"}).json() == []


def test_delete_expired_link(client):
    code = create_ttl(client, 60).json()["code"]
    expire(code)
    assert client.delete(f"/links/{code}", headers={"X-User-Id": "bob"}).status_code == 404
    assert client.delete(f"/links/{code}", headers={"X-User-Id": "alice"}).status_code == 204
    assert store.audit[-1]["action"] == "link.delete"
    assert store.audit[-1]["entity"] == code


def test_non_owner_delete_is_404_before_expiry(client):
    code = create_ttl(client, 60).json()["code"]
    assert client.delete(f"/links/{code}", headers={"X-User-Id": "bob"}).status_code == 404


def test_invalid_ttl_is_rejected_without_side_effects(client):
    for ttl in (0, -1, MAX_TTL_SECONDS + 1, 1.5, "60", True):
        assert create_ttl(client, ttl).status_code == 422
    assert store.links == {}
    assert store.audit == []


def test_max_ttl_is_accepted(client):
    assert create_ttl(client, MAX_TTL_SECONDS).status_code == 201


def test_null_ttl_means_never(client):
    assert create_ttl(client, None).json()["expires_at"] is None


def test_audit_never_holds_ttl_or_target(client):
    create_ttl(client, 60)
    assert "example.com" not in str(store.audit)
    assert "ttl" not in str(store.audit)

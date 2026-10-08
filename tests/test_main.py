import pytest
from fastapi.testclient import TestClient

from app.main import app, store


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

"""A deliberately small URL shortener: enough surface for a spec and a security review to bite on.

Storage is in-memory on purpose. The conventions that matter are in CLAUDE.md.
"""

import secrets
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from urllib.parse import urlparse

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, StrictInt

ALLOWED_SCHEMES = {"http", "https"}
CODE_BYTES = 8
MAX_TTL_SECONDS = 31_536_000  # 365 days


@dataclass
class Link:
    code: str
    target: str
    owner: str
    created_at: datetime
    expires_at: datetime | None = None

    def is_expired(self, now: datetime) -> bool:
        return self.expires_at is not None and now >= self.expires_at

    @property
    def expired(self) -> bool:
        """Read by LinkOut at serialisation time, so it reflects the clock when responding."""
        return self.is_expired(datetime.now(UTC))


@dataclass
class Store:
    links: dict[str, Link] = field(default_factory=dict)
    audit: list[dict[str, str]] = field(default_factory=list)

    def record(self, actor: str, action: str, entity: str) -> None:
        """Audit entries carry the code, never the target: a target is user content."""
        self.audit.append(
            {
                "actor": actor,
                "action": action,
                "entity": entity,
                "at": datetime.now(UTC).isoformat(),
            }
        )


store = Store()
app = FastAPI(title="poc-sdlc-consumer-app")


def require_user(x_user_id: str | None = Header(default=None)) -> str:
    if not x_user_id:
        raise HTTPException(status_code=401, detail="X-User-Id header is required")
    return x_user_id


class CreateLink(BaseModel):
    model_config = ConfigDict(extra="forbid")
    target: str
    ttl_seconds: StrictInt | None = Field(default=None, ge=1, le=MAX_TTL_SECONDS)


class LinkOut(BaseModel):
    """Explicit response model so owner and audit internals are never returned."""

    code: str
    target: str
    created_at: datetime
    expires_at: datetime | None
    expired: bool


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/links", response_model=LinkOut, status_code=201)
def create_link(body: CreateLink, user: str = Depends(require_user)) -> Link:
    parsed = urlparse(body.target)
    if parsed.scheme not in ALLOWED_SCHEMES or not parsed.netloc:
        raise HTTPException(status_code=422, detail="target must be an absolute http(s) URL")

    code = secrets.token_urlsafe(CODE_BYTES)
    now = datetime.now(UTC)
    expires_at = now + timedelta(seconds=body.ttl_seconds) if body.ttl_seconds is not None else None
    link = Link(code=code, target=body.target, owner=user, created_at=now, expires_at=expires_at)
    store.links[code] = link
    store.record(user, "link.create", code)
    return link


@app.get("/links", response_model=list[LinkOut])
def list_links(user: str = Depends(require_user)) -> list[Link]:
    return [link for link in store.links.values() if link.owner == user]


@app.delete("/links/{code}", status_code=204)
def delete_link(code: str, user: str = Depends(require_user)) -> None:
    link = store.links.get(code)
    # Someone else's link is a 404, not a 403: a 403 confirms the code exists.
    if link is None or link.owner != user:
        raise HTTPException(status_code=404, detail="no such link")
    del store.links[code]
    store.record(user, "link.delete", code)


@app.get("/{code}")
def follow(code: str) -> RedirectResponse:
    link = store.links.get(code)
    # Expired and unknown share one branch so nothing distinguishes them to a caller.
    if link is None or link.is_expired(datetime.now(UTC)):
        raise HTTPException(status_code=404, detail="no such link")
    return RedirectResponse(url=link.target, status_code=307)

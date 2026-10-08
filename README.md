# poc-sdlc-consumer-app

A deliberately small URL shortener, used to demonstrate the
[AI-native SDLC template](https://github.com/kayshn/poc-sdlc-template). The application is not the
point; the loop around it is.

```
intent → spec → plan + code → CI + AI review → deploy → monitor → intent
```

This repository consumes the standard at the tag recorded in `.sdlc/TEMPLATE_VERSION`. The files
listed in `.sdlc/invariant.txt` are pulled from there and are not edited here — `make template-check`
fails if they drift, and `sdlc-update.yml` opens a pull request when a newer tag is published.

## The API

Authentication is an `X-User-Id` header standing in for a real identity provider. Storage is
in-memory and resets on restart.

| Route | Auth | What it does |
|---|---|---|
| `GET /health` | none | Liveness |
| `POST /links` | required | Shortens an absolute `http(s)` URL, returns its code |
| `GET /links` | required | Lists the caller's own links |
| `DELETE /links/{code}` | required | Deletes one of the caller's links |
| `GET /{code}` | none | Redirects to the target |

## Commands

```bash
make install   # create .venv and install dependencies
make test      # pytest
make lint      # ruff check + format --check
make format    # ruff format + --fix
make run       # uvicorn on :8000
```

CI runs those plus `make flow-check` and `make template-check`.

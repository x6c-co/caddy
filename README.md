# caddy — pinned custom Caddy build

This repository's only job is to produce a **custom [Caddy](https://caddyserver.com)
binary** (Caddy + a fixed set of plugins) and publish it as a GitHub Release that a
separate (private Ansible) repo consumes. It contains no servers and no secrets, and
is public so the release artifact can be fetched without auth.

## Why this exists

We build the binary ourselves — pinned to exact versions and checksummed — instead of pulling it from an upstream server we don't control, ensuring a reproducible build for the fleet.

## What gets built

- **Base Caddy:** `v2.11.4` (matches the fleet).
- **Platform:** `linux/amd64` only.
- **Static:** `CGO_ENABLED=0` — runs across Debian versions without glibc surprises.
- **Modules compiled in** (all version-pinned in [`versions.env`](versions.env)):

  | Source package | Version | Registers module ID(s) |
  | --- | --- | --- |
  | `github.com/corazawaf/coraza-caddy/v2` | `v2.5.0` | `http.handlers.waf` (directive `coraza_waf`) |

  The Coraza WAF (`http.handlers.waf`) is **compiled in but inert** — it embeds the OWASP Core
  Rule Set v4 and does nothing until a downstream Caddyfile turns it on. See the note below.

### Captured module IDs (verified from the built binary)

These are read verbatim from `./caddy-linux-amd64 list-modules` and are the strings the
downstream Ansible role asserts on — do not guess them:

- Coraza WAF handler: **`http.handlers.waf`** (`v2.5.0`, Caddyfile directive `coraza_waf`)

> ℹ️ **`http.handlers.waf` is compiled in but inert.** It does nothing at runtime until a
> downstream Caddyfile uses the `coraza_waf` directive (which also needs the global
> `{ order coraza_waf first }` option), loads rules (e.g. the embedded OWASP CRS v4 via
> `load_owasp_crs`), and runs with `SecRuleEngine On`. A `list-modules` presence check
> verifies **availability, not active protection** — do not read "module present" as "the
> fleet is WAF-protected." All WAF configuration, rule tuning, and false-positive handling
> live in the downstream (Ansible) repo, not here. The WAF also buffers request/response
> bodies and does not pass through WebSockets or SSE, so downstream configs must matcher-
> exclude streaming/upload/WebSocket routes — plan a `DetectionOnly` → tune → `On` rollout.

`./caddy-linux-amd64 version` reports `v2.11.4`.

## Versioning & releasing

Tags drive releases. The convention is:

```
v2.11.4-a5t.2
└──┬──┘ └─┬─┘
 base    build suffix — bump the .N on every rebuild of the same base
```

- **Rebuild (bump a module/Go/xcaddy version):** edit [`versions.env`](versions.env),
  commit, then bump the `-a5t.N` suffix: `git tag v2.11.4-a5t.3 && git push origin v2.11.4-a5t.3`.
- **Caddy upgrade:** bump `CADDY_VERSION` in `versions.env` and tag the new base, e.g.
  `v2.11.5-a5t.1`.

Pushing a `v*` tag triggers [`.github/workflows/build.yml`](.github/workflows/build.yml),
which builds, **verifies the required modules are present** (the build never ships if a
module is missing), and publishes a release with two assets:

- `caddy-linux-amd64` — the binary.
- `SHA256SUMS` — `sha256sum -c`-compatible, containing the line
  `<sha256>  caddy-linux-amd64`.

`workflow_dispatch` (Actions → build → Run workflow) builds and verifies **without**
releasing — useful to test a `versions.env` bump on a branch before tagging.

### Stable download URLs

Per-tag, GitHub exposes stable asset URLs (substitute the release `<TAG>`):

```
https://github.com/x6c-co/caddy/releases/download/<TAG>/caddy-linux-amd64
https://github.com/x6c-co/caddy/releases/download/<TAG>/SHA256SUMS
```

For example, the current release `v2.11.4-a5t.2`:

```
https://github.com/x6c-co/caddy/releases/download/v2.11.4-a5t.2/caddy-linux-amd64
https://github.com/x6c-co/caddy/releases/download/v2.11.4-a5t.2/SHA256SUMS
```

The SHA256 is in `SHA256SUMS` and in the release notes (also given pre-formatted as
`sha256:<hash>` for Ansible).

## Building locally

Reproduces the exact CI build (same `xcaddy` invocation, same versions):

```sh
# Prereqs: Go matching GO_VERSION in versions.env, and the pinned xcaddy:
go install github.com/caddyserver/xcaddy/cmd/xcaddy@v0.4.5

./build.sh                 # -> ./caddy-linux-amd64
./caddy-linux-amd64 list-modules | grep -E 'http.handlers.waf'
```

### Go version note

`versions.env` pins **`GO_VERSION=1.26.2`**. `build.sh` sets `GOTOOLCHAIN=local` so a future dependency that demands a newer Go fails loudly here instead of silently downloading a different toolchain (which would defeat the pinning). If a bump raises the required Go, raise `GO_VERSION` to match.

## Consumer contract

A separate Ansible role consumes the release. It is **not** implemented here, but the
artifact is designed to satisfy it, so keep these stable across releases:

1. `get_url` the `caddy-linux-amd64` asset with `checksum: "sha256:<from SHA256SUMS>"`.
2. Install to `/usr/bin/caddy`, `apt-mark hold caddy`, restart.
3. Assert `caddy list-modules` contains `http.handlers.waf`.

**Stability guarantees:** the asset name (`caddy-linux-amd64`), the `SHA256SUMS` format
(`<sha256>  caddy-linux-amd64`), and the registered module ID above will not change
without a coordinated update to the consuming role.

## Files

| File | Purpose |
| --- | --- |
| [`versions.env`](versions.env) | Single source of truth for every pinned version. |
| [`build.sh`](build.sh) | Reproducible local build; CI runs the same script. |
| [`.github/workflows/build.yml`](.github/workflows/build.yml) | Build → verify → release on `v*` tags. |
| `LICENSE` | Apache-2.0 (matching Caddy). |

## License

[Apache-2.0](LICENSE), matching Caddy.

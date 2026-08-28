# AGENTS.md

Notes for humans and coding agents in this repo.

## What this is

`sah` is a Dart CLI and API client for SoftAtHome home gateways (KPN Experia Box, Livebox-style). It uses the same `X-Sah` / `application/x-sah-ws-4-call+json` protocol as the KPN web UI.

Run with `./run.sh <args>` (compiles to `build/sah` when sources change). API inventory: [docs/softathome-api.md](docs/softathome-api.md).

## Safety rules

- Do not mutate the live gateway (DHCP reserve/unreserve, rename, Wi-Fi toggles, firewall, reboot, etc.) unless the user asks and confirms. Prefer `--dry-run` on mutating commands.
- Read-only commands (`login`, `info`, `wan`, `devices`, `find`, `topology`, `dhcp leases`, `dhcp static`, `ports`, `wifi`, `firewall`, `speedtest`, `call` for gets) are fine on the LAN when debugging.
- Default gateway host is `192.168.2.254` (`SahConfig.defaultHost`, KPN default). Override with `-H` / `--host`.
- Session tokens: `~/.config/sah/session.json` (`contextId` + cookie). Passwords are not stored; use `--password` or `SAH_PASSWORD` at login only.

## Auth / session

```bash
./run.sh login --password '…'          # or SAH_PASSWORD=…
./run.sh logout
./run.sh --context '…' --cookie 'prefix/sessid=…' devices
```

## Example: find MacBook and reserve its IP

```bash
./run.sh find macbook
./run.sh find --active macbook
./run.sh dhcp static
./run.sh dhcp leases
./run.sh dhcp reserve --name macbook --dry-run
./run.sh dhcp reserve --name macbook --ip 192.168.2.100   # mutates; ask first
./run.sh dhcp unreserve --mac '02:00:00:00:00:01' --dry-run
```

SoftAtHome call for reserve: `DHCPv4.Server.Pool.default` / `addStaticLease` with `{ "MACAddress": "…", "IPAddress": "…" }`.

## Commands (overview)

| Command | SoftAtHome | Notes |
| --- | --- | --- |
| `login` / `logout` | `sah.Device.Information` / `createContext` | Session file |
| `info` | `DeviceInfo` / `get` | Modem identity |
| `wan` | `NMC` / `getWANStatus` | Public IP, link |
| `devices` [`--active`] | `Devices` / `get` | Host table |
| `find <query>` | `Devices` / `get` | Filtered hosts |
| `topology` | `Devices.Device.lan` / `topology` | Tree |
| `dhcp leases` | `DHCPv4.Server.Pool.default` / `getLeases` | Dynamic |
| `dhcp static` | `…` / `getStaticLeases` | Reservations |
| `dhcp reserve` | `…` / `addStaticLease` | **Mutates** |
| `dhcp unreserve` | `…` / `deleteStaticLease` | **Mutates** |
| `ports` | `Firewall` / `getPortForwarding` | Port forwards |
| `wifi` | `NMC.Wifi` / `get` | Radio status |
| `firewall` | `Firewall` / `getFirewallLevel` + `getDMZ` | Level / DMZ |
| `speedtest` | `IPPingDiagnostics` + `SpeedTest.Diagnostics.*` | WAN; Cloudflare from this host if SpeedTest API missing |
| `device rename <query> <newName> [--apply]` | `Devices.Device.<key>:setName` | Default dry-run |
| `call <svc> <method> [json]` | arbitrary | Escape hatch |

Global flags: `-H/--host`, `-c/--context`, `--cookie`, `--json`, `-v/--verbose`.

## Layout

```
bin/sah.dart
lib/sah.dart
lib/src/api/          # SahClient, SahSession, SahException
lib/src/commands/
lib/src/config.dart
lib/src/output.dart
run.sh
```

## Dev notes

- Dart SDK `^3.13`; run `dart analyze && dart test`
- Run `dart` / `./run.sh` outside the Cursor sandbox (`required_permissions: ["all"]`)
- Extend `SahClient` with typed helpers, then thin CLI commands
- KPN posts every call to `http://<host>/ws/NeMo/Intf/lan:getMIBs`
- Use `sah call` to probe unknown methods; permission errors are normal

### Dart 3.13: primary constructors and private fields

We use [primary constructors](https://dart.dev/language/primary-constructors) (Dart 3.13). `dart analyze` may report `use_primary_constructors` or `unnecessary_type_name_in_constructor` on types like `ProgressBar`. That is normal. Do not convert them to classic `this.field` constructors unless you need extra constructors, factories, a heavy initializer list, or generated code.

When one generative constructor mostly fills fields, use a primary constructor:

- Declaring parameters: `final int x`, `required final String host`. Not `this.x` plus a separate field.
- `const` after `class`: `class const SahConfig(…)`, not `const class`.
- Data-only types: semicolon body (`class const Point(final int x, final int y);`).
- Types with methods: keep `{ … }` after the header (`SahConfig`, `ProgressBar`).

[Private named parameters](https://dart.dev/language/constructors#private-named-parameters) (Dart 3.12): a parameter can be `final int _id`. Call sites use `id: 1`, not `_id:`.

Sometimes a parameter cannot map straight to a declaring field. Optional args with computed defaults, `late` state, or a public-to-private rename (`sink` → `_sink`) belong in the body. `ProgressBar` sets `final IOSink _sink = sink ?? stderr` that way.

In-body constructors: `new` / `new name()`, not the type name again. Call sites stay `Foo(…)`.

In `async` functions: `return await future;`, or drop `async`. Not `return future;`.

## Discovering SoftAtHome APIs

Primary refs: [docs/softathome-api.md](docs/softathome-api.md), [docs/ensemble-api-catalog.md](docs/ensemble-api-catalog.md).

Skip `main.dart.js`. Call defs live in Ensemble YAMLs on the gateway (`/assets/ensemble/apps/kpnApp/screens/*.yaml`).

1. Ensemble catalog (~146 pairs): refresh via gateway AssetManifest + screen YAMLs
2. Per-device `Actions` from `Devices.get` (`setName`, `getEventLog`, etc.)
3. `sah call` with minimal params; failures are normal
4. [LiveboxMonitor](https://github.com/p-dor/LiveboxMonitor), [rene-d/sysbus](https://github.com/rene-d/sysbus) for cross-ref
5. HAR from KPN web UI only if stuck

Wire new finds: typed helper on `SahClient`, thin command, mark **MUTATE** here.

## Commits and pull requests

### Titles (commits and PRs)

Conventional Commits, same shape for both:

```text
<type>(optional-scope): <imperative summary>
```

- Lowercase after the colon. No trailing period.
- Imperative verb: `add`, `fix`, `remove` (not `added` / `adds`).
- Scope when it helps: `feat(cli): add speedtest command`.
- Breaking: `feat(api)!: …` or `BREAKING CHANGE:` footer.
- One line. Say what changed. No sales language.

| Type | Use for | Commits | PRs |
| --- | --- | --- | --- |
| `feat` | New feature | yes | yes |
| `fix` | Bug fix | yes | yes |
| `docs` | Docs only | yes | yes |
| `style` | Formatting only | yes | yes |
| `refactor` | Neither fix nor feature | yes | yes |
| `perf` | Performance | yes | yes |
| `test` | Tests | yes | yes |
| `ci` | CI config | yes | yes |
| `chore` | Tooling, deps | yes | yes |
| `revert` | Revert | yes | yes |
| `release` | Release into main | no | yes |

Examples: `feat(cli): add speedtest command`, `fix(dhcp): handle empty lease list`.

Commit body only when it helps (why or caveats).

### CHANGELOG

If the repo has `CHANGELOG.md`:

```markdown
## 0.1.0 - 2026-08-27

- feat(scope): imperative summary
- fix(scope): another change (#123)
```

- Put the newest release first.
- Heading: `## {version} - {YYYY-MM-DD}`. Semver, or semver+build if the app uses build numbers (e.g. `0.1.3+11`).
- Each bullet is a conventional commit line. Use merge or squash titles; add `(#PR)` when it helps.
- Blank line after the heading, blank line between releases. No `# Changelog` title at the top.
- Only add bullets for work that actually shipped. Do not invent entries.

### PR body

Default when there is no template:

```markdown
## Description

This PR <one clear sentence starting with "This PR">.

### Changes

- <concrete change>
- <concrete change>
```

Add `### Notes` only when reviewers need extra context. Add `Closes #N` when it applies. No Test plan section unless asked.

Do not add "Made with Cursor" or other AI-tool credit to PRs, commits, code, or docs.

### PR and commit voice

Plain and dry. Open with what changed.

- No em dashes or en dashes. Use a period, comma, colon, or parentheses.
- No "it's not X, it's Y". No chatbot closers or "let's dive in".
- Skip hype: robust, seamless, comprehensive, leverage, etc.
- Concrete bullets. Same noun for the same thing throughout.
- Active voice with a clear subject.

## Writing style (docs, comments, PR text)

Docs and agent notes: plain and dry. Chat can be more direct.

- Lead with the fact or action. Cut filler and signposting.
- No em dashes. No rule-of-three padding. No inflated significance.
- No vague attributions ("experts say") without a source.
- Prefer short sentences. Keep technical terms that name real things (`SahClient`, sysbus, DHCP pool).
- Do not add warmth, praise, or AI self-reference in shipped text.

Banned patterns in prose you write for this repo:

- Em dashes, "it's not X, it's Y", trailing `-ing` depth clauses ("highlighting…", "ensuring…")
- Chatbot openers/closers: "Great question", "I hope this helps", "Here's what you need to know"
- Hype adjectives: crucial, pivotal, robust, seamless, comprehensive, leverage (verb), delve, showcase

When editing existing docs, preserve API field names, URLs, and code behavior.

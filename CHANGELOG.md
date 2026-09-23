## Upcoming

- feat(cli): `dhcp reserve` / `unreserve` by name, MAC, or IP, with an interactive topology picker (`-i`)
- fix(topology): keep offline parents under `--active` when they still have active children; picker cursor beside the device
- fix(dhcp): flatten lease nesting; static rows show name and active

## 0.1.2 - 2026-09-07

- feat(cli): auto-relogin with stored credentials on expired session
- feat(cli): fit tables to terminal width (`--sort-by`, `--fields`, `--no-truncate`)
- feat(cli): cargo-style error and tip lines
- feat(cli): add `--active` filters for devices, find, topology, dhcp, and rename
- feat(cli): color all bool values in key/value output
- feat(cli): show topology Active as green filled / grey hollow circles

## 0.1.1 - 2026-08-28

- feat: add speedtest progress bar
- refactor: change command output to be more user friendly
- docs: add more docs and rewrite

## 0.1.0 - 2026-08-27

- feat: initial sah CLI for SoftAtHome gateways
- docs: expand README About and tighten markdown prose

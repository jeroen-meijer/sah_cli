# 🌐 SoftAtHome Networking CLI

**CLI for KPN Experia / SoftAtHome home gateways.** List LAN devices, DHCP leases and reservations, Wi-Fi, firewall, WAN status, and run raw sysbus calls.

> [!NOTE]
> This package is not affiliated with KPN, SoftAtHome, Orange, or ZTE. See [Disclaimer](#disclaimer).

> [!WARNING]
> This project was partially written by AI. Use at your own risk.

## About

This is a CLI that lets you talk to SoftAtHome gateways from a machine on your LAN: list and find devices, manage DHCP leases and reservations, check WAN/Wi-Fi/firewall status, rename hosts, run a WAN speed test, or call raw sysbus methods without opening the web UI.

Under the hood it uses the same JSON API as the web UI. SoftAtHome ships no official consumer CLI.

Tested on KPN Experia Box V10 (ZTE H369A / H369As). Same protocol family as Orange Livebox-style gateways, though firmware and permissions vary by ISP and model.

## Safety

Some commands change gateway settings: DHCP reserve/unreserve, device rename, and anything you run through `call`. Use `--dry-run` where the command supports it. Only run mutating commands on your own box. Most commands are read-only and safe to run on your LAN.

## Requirements

- Dart SDK ^3.13 ([dart.dev/get-dart](https://dart.dev/get-dart))
- Your gateway admin password (for `login`; not stored on disk)
- A machine on the same LAN as the gateway

## Install

```bash
git clone https://github.com/jeroen-meijer/sah_cli.git
cd sah_cli
dart pub get
./run.sh --help
```

Or install globally from a clone:

```bash
dart pub global activate --source path .
sah --help
```

Ensure `~/.pub-cache/bin` is on your `PATH`.

## Quick start

```bash
./run.sh login --password '…'    # or SAH_PASSWORD=…
./run.sh info
./run.sh devices --active
./run.sh find macbook
./run.sh wan
./run.sh dhcp static
./run.sh speedtest
```

Default gateway host is `192.168.2.254` (common on KPN boxes). Override with `-H` / `--host`. Session lives in `~/.config/sah/session.json` (password is not stored).

## Commands

| Command                                                        | What it does                                   |
| -------------------------------------------------------------- | ---------------------------------------------- |
| `login` / `logout`                                             | Session                                        |
| `info`, `wan`                                                  | Modem identity, WAN link                       |
| `devices`, `find`, `topology`                                  | Hosts on the LAN                               |
| `dhcp leases`, `dhcp static`, `dhcp reserve`, `dhcp unreserve` | DHCP (reserve/unreserve change the gateway)    |
| `ports`, `wifi`, `firewall`                                    | Port forwards, radio, firewall level           |
| `speedtest`                                                    | WAN speed (gateway API or Cloudflare fallback) |
| `device rename`                                                | Rename a host (dry-run unless `--apply`)       |
| `call <service> <method> [json]`                               | Raw API: any supported SoftAtHome call         |

Add `--json` for machine output. See `./run.sh <command> --help` and [AGENTS.md](AGENTS.md) for agent notes and API docs.

## Docs

- [docs/softathome-api.md](docs/softathome-api.md): methods seen on KPN boxes
- [docs/ensemble-api-catalog.md](docs/ensemble-api-catalog.md): full Ensemble UI catalog

## Disclaimer

This tool is unofficial. It is not affiliated with or endorsed by KPN, SoftAtHome, Orange, ZTE, or your ISP.

The API is reverse-engineered from gateway web UIs. Methods, permissions, and behavior vary by firmware and ISP. What works on one box may fail on another. Commands such as `dhcp reserve`, `device rename`, and arbitrary `call` requests change gateway settings. Use them only on hardware you own. Prefer `--dry-run` when the command supports it.

The software is provided as-is, without warranty. You use it at your own risk.

## License

MIT. See [LICENSE](LICENSE).

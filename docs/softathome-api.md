# SoftAtHome / KPN API reference (sah)

SoftAtHome sysbus methods for this CLI and a KPN Experia Box 10 (ZTE H369As).
Enough for agents to extend `sah` without the original HAR or `main.dart.js`.

## Completeness warning

**`main.dart.js` is a dead end for API mining.** The Flutter/Ensemble UI does
not put SoftAtHome `service`/`method` strings in the JS bundle (false
positives only, e.g. DOM `createContextualFragment`). Real call definitions
live in **Ensemble screen YAMLs** on the gateway.

**A HAR is also incomplete.** It only records calls the web UI made in that
capture.

| Source | What it covers | Gap |
|---|---|---|
| **Ensemble YAMLs** (`/assets/ensemble/apps/kpnApp/…`) | ~146 `service`/`method` pairs the KPN UI can call | Params/body details vary; some paths template `${mac}` etc. |
| HAR(s) below | UI-exercised pairs in one session | Anything not opened in that capture |
| Live device `Actions` | Per-host methods (`setName`, eventing, …) | Global services |
| Livebox / sysbus docs | Same SoftAtHome PCB family (Orange) | Firmware/permissions differ; may be denied on KPN |

**Full Ensemble catalog:** [ensemble-api-catalog.md](ensemble-api-catalog.md)
(+ machine JSON: [ensemble-api-inventory.json](ensemble-api-inventory.json)).

If a method is missing, see discovery in
[AGENTS.md](../AGENTS.md#discovering-softathome-apis).
Missing here does not mean missing on the box.

### Capture sources used for this doc

- Gateway Ensemble assets: `http://<host>/assets/AssetManifest.json`, then
  `ensemble/apps/kpnApp/screens/*.yaml` (grep for `API:` blocks)
- HAR captures from the KPN web UI
- Live device probes via `sah` (DHCP, `Actions`, event types)
- Online SoftAtHome family (cross-ref only):
  - [LiveboxMonitor Livebox 5 API docs](https://github.com/p-dor/LiveboxMonitor/tree/main/docs/API%20Documentation/Livebox%205)
  - [rene-d/sysbus](https://github.com/rene-d/sysbus) (Orange Livebox HTTP/JSON)

---

## Transport / auth

All authenticated calls (KPN UI):

- **URL:** `http://<host>/ws/NeMo/Intf/lan:getMIBs`  
  (not `/ws` alone; KPN posts everything here)
- **Content-Type (calls):** `application/x-sah-ws-4-call+json`
- **Body:**
  ```json
  { "service": "<object.path>", "method": "<method>", "parameters": { } }
  ```
- **Headers:**
  - `Authorization: X-Sah <contextID>`
  - `X-Context: <contextID>`
  - `Cookie: <prefix>/sessid=…`

### Login (`createContext`)

Not present in the main-page HAR (session already open). Known SoftAtHome /
KPN flow used by `sah login`:

- **Content-Type:** `application/x-sah-ws-4-call+js` (note: `+js`, not `+json`)
- **Authorization:** `X-Sah-Login`
- **Body:**
  ```json
  {
    "service": "sah.Device.Information",
    "method": "createContext",
    "parameters": {
      "applicationName": "webui",
      "username": "admin",
      "password": "…"
    }
  }
  ```
- **Response:** `data.contextID` + `Set-Cookie` (prefer cookie whose name
  contains `sessid=`)

`sah` stores `{host, contextId, cookie}` in `~/.config/sah/session.json`
(password **not** stored).

---

## Legend

| Tag | Meaning |
|---|---|
| **ENSEMBLE** | Defined in KPN Ensemble screen YAML on this box |
| **HAR** | Seen in a HAR against this KPN box |
| **LIVE** | Confirmed via `sah` against this box |
| **LB5** | Documented on Livebox 5 SoftAtHome; **unverified / may differ on KPN** |
| **MUTATE** | Changes gateway state. Ask the user; prefer dry-run |

## Ensemble highlights (beyond HAR)

From UI YAML `API:` blocks. Probe with `sah call` before wiring CLI; many are
**MUTATE**.

| Area | Service examples | Useful methods |
|---|---|---|
| Auth | `sah.Device.Information` | `createContext`, `releaseContext` |
| DHCP | `DHCPv4.Server.Pool.default` | `getLeases`, `getStaticLeases`, `addStaticLease`, `deleteStaticLease`, `setStaticLease` |
| Devices | `Devices`, `Devices.Device.${mac}` | `get`, `setName`, `setType`, `destroyDevice`, `topology` |
| Firewall | `Firewall` | `get/setPortForwarding`, `get/setPinhole`, `get/setDMZ`, `get/setFirewallLevel`, custom rules, UPnP |
| Wi‑Fi | `NMC.Wifi`, `NeMo.Intf.rad*`, `NeMo.Intf.lan` | `get` / `set`, `setWLANConfig`, scan/spectrum, guest timer |
| LAN / DHCP UI | `NetMaster…`, `DHCPv4.Server` | IPv4/IPv6 LAN settings, hostname, guest pool |
| DynDNS | `DynDNS` | `getHosts`, `addHost`, `delHost` |
| Scheduler | `Scheduler` | device / Wi‑Fi schedules |
| Voice | `VoiceService.VoiceApplication` | trunks, call list, ring |
| Extenders | `Devices.Device.${mac}.SSW` | `execAPI` (nested SoftAtHome calls) |
| Misc | `Time`, `PasswordRecovery`, `SpeedTest.*`, `IPPingDiagnostics` | clock, recovery, diagnostics |

### SpeedTest / ping (Ensemble UI)

KPN UI dialog (`SpeedTestDialog`) calls, in order: `startPing`,
`runDownstreamSpeedTest`, `runUpstreamSpeedTest`. CLI: `sah speedtest`.

| Service | Method | Params | Notes |
|---|---|---|---|
| `IPPingDiagnostics` | `execDiagnostic` | `{ipHost, ProtocolVersion}` | UI default host `34.141.213.235`; often permission denied or all packets lost |
| `SpeedTest.Diagnostics.Download` | `runDiagnostics` | `""` | WAN download; status: `throughput` (kbps), `rxbytes`, `duration` (ms) |
| `SpeedTest.Diagnostics.Upload` | `runDiagnostics` | `""` | WAN upload; same status shape |

This is not a LAN/iperf test. H369As / V10 often has no `SpeedTest.*` objects
at all; `sah speedtest` then measures from the CLI host against Cloudflare.

See [ensemble-api-catalog.md](ensemble-api-catalog.md) for the full table.

---

## Methods seen on this KPN box (HAR)

### DeviceInfo

| Method | Params | Status shape | Tags |
|---|---|---|---|
| `get` | `{}` or `""` | map: ProductClass, SerialNumber, SoftwareVersion, BaseMAC, … | HAR, LIVE → `sah info` |

### Devices

| Method | Params (samples) | Status shape | Tags |
|---|---|---|---|
| `get` | see expressions below | list of hosts **or** `{wifi:[…], ethernet:[…]}` | HAR, LIVE → `sah devices` / `find` |

**Useful `expression` values (HAR):**

```text
not interface and not self and not voice          # hosts (CLI default)
not interface and not self and ssw                # + flags: full_links | alternatives
not interface and stb and .Active==true
{ "wifi": "not interface and wifi and .Active==true",
  "ethernet": "not interface and eth and .Active==true" }   # + flags: full_links
not interface and not self and not voice and .Active==false
```

**Useful `flags`:** `full_links`, `alternatives`, `no_recurse|no_actions` (topology).

### Devices.Device.\<key\>

| Method | Notes | Tags |
|---|---|---|
| `get` | Used for `HGW` key (`Devices.Device.HGW`) | HAR |
| `topology` | On `lan` / `guest`; params `{expression:"not logical", flags:"no_recurse\|no_actions"}` | HAR, LIVE → `sah topology` |
| `setName` | `{name, source?}` (UI "Edit Name") | LIVE (via Actions), LB5, **MUTATE** → `sah device rename` |
| `setType` | Advertised on hosts | LIVE (Actions), **MUTATE** |
| `startEventing` / `stopEventing` | Subscribe named listener | LIVE (Actions); don't leave dangling |
| `getEventLog` | `{type, since?, until?}` (often empty without prior activity) | LIVE |
| `listLiveEventTypes` / `listLogEventTypes` | On this box: `[{type:"network", interval:…}]` | LIVE |
| `listEventSubscribers` | Permission denied for admin on this box | LIVE |

**Host `Actions` frequencies in HAR devices dump:**  
`setName`, `setType` (most hosts); eventing cluster on a subset (~wifi/associated).

### NMC

| Method | Params | Notes | Tags |
|---|---|---|---|
| `getWANStatus` | `{}` | Response often `{status:true, data:{…}}` (status is **bool**, payload in **data**) | HAR, LIVE → `sah wan` |

### NMC.Wifi

| Method | Params | Tags |
|---|---|---|
| `get` | `{}` | HAR, LIVE → `sah wifi` |

### Firewall

| Method | Params | Tags |
|---|---|---|
| `getFirewallLevel` | `{}` → string e.g. `"Medium"` | HAR, LIVE → `sah firewall` |
| `getDMZ` | `{}` | HAR, LIVE |
| `getPortForwarding` | `{origin:"webui"}` | HAR, LIVE → `sah ports` (empty map if none) |
| `getPinhole` | `{}` | HAR |

### NeMo.Intf.\*

| Service | Method | Params | Tags |
|---|---|---|---|
| `NeMo.Intf.lan` | `getMIBs` | `{mibs:"wlanvap", flag:"!backhaul"}` | HAR |
| `NeMo.Intf.brguest` | `getMIBs` | `{mibs:"wlanvap", flag:"!backhaul", traverse:"one level down"}` | HAR |
| `NeMo.Intf.data` | `getMIBs` | `{mibs:"base ppp dhcp"}` | HAR |
| `NeMo.Intf.data` | `luckyAddrAddress` | `{flag:"ipv6 && global && @gua", traverse:"down"}` | HAR |
| `NeMo.Intf.iptv` | `get` / `luckyAddrAddress` | `{}` / `{flag:"ipv4", traverse:"down"}` | HAR |
| `NeMo.Intf.wwan` | `get` | `{}` (cellular modem status) | HAR |

### Other HAR services (mostly read)

| Service | Method | Notes | Tags |
|---|---|---|---|
| `HTTPService` | `getCurrentUser` | `{user, groups}` | HAR |
| `MSS` / `MSS.Config` | `get` | Multi-AP / SoftAtHome mesh-ish config | HAR |
| `Scheduler` | `getCompleteSchedules` | `{type:"ToD"}` → often `{status:true, …}` | HAR |
| `Tessares` | `get` | Multipath TCP / Tessares feature flag | HAR |
| `VoiceService.VoiceApplication` | `listTrunks` | VoIP trunks | HAR |
| `WebuiupgradeService` | `getLatestVersion` | Firmware UI check | HAR |

---

## DHCP (not in HAR; confirmed LIVE on this box)

The UI capture never opened the DHCP reservation screen. The SoftAtHome path still works:

**Service:** `DHCPv4.Server.Pool.default` (override with `--pool`)

| Method | Params | Tags | CLI |
|---|---|---|---|
| `getStaticLeases` | `{}` | LIVE | `sah dhcp static` |
| `getLeases` | optional `rule` | LIVE | `sah dhcp leases` |
| `addStaticLease` | `{MACAddress, IPAddress}` | LIVE, LB5, **MUTATE** | `sah dhcp reserve` |
| `deleteStaticLease` | `{MACAddress}` | LIVE, LB5, **MUTATE** | `sah dhcp unreserve` |

**LB5 also documents (unverified on KPN):**  
`setStaticLease`, `addLeaseFromPool`, `setLeaseTime`, `forceRenew` (on a lease object).

Hosts may show `IPv4Address[].Reserved: true` after a static lease exists.

---

## LB5 cross-ref: useful methods **not** seen in HAR

Treat these as **candidates** to probe with `sah call`. Expect permission
errors or missing methods on KPN.

### DHCPv4.Server.Pool (LB5)

- `addStaticLease` / `deleteStaticLease` / `setStaticLease` / `getStaticLeases` / `getLeases` / `addLeaseFromPool` / `setLeaseTime`

### Devices / Devices.Device (LB5)

- `find`, `destroyDevice`
- `setName` / `addName` / `removeName`
- `topology`, `set`, `getParameters`, …

### Firewall (LB5): many **MUTATE**

- `setPortForwarding`, `deletePortForwarding`, `enablePortForwarding`, `refreshPortForwarding`
- `setPinhole`, `setFirewallLevel`, `setFirewallIPv6Level`, `commit`
- Read counterparts mostly match HAR (`getPortForwarding`, `getFirewallLevel`, …)

### NMC (LB5): dangerous

- `getWANStatus` (HAR ✓)
- `reboot`, `reset`: **MUTATE / disruptive**
- `setLANIP`, `getLANIP`, `setWanMode`, …

### NMC.Wifi (LB5)

- `get` (HAR ✓); setters may exist under related WiFi objects; probe carefully

Full object list: LiveboxMonitor `docs/API Documentation/Livebox 5/`
(`_ALL SERVICES_.txt` index).

---

## Device expression / host field cheat sheet

Common host fields from `Devices.get`:

| Field | Use |
|---|---|
| `Key` / `PhysAddress` | MAC-ish id for `Devices.Device.<Key>` |
| `Name` / `Names[]` | Display + dhcp/mdns aliases |
| `Active` | Associated / recently seen |
| `IPAddress` / `IPv4Address[]` | Prefer dotted IPv4; `Reserved` flag |
| `InterfaceName` / `Layer2Interface` | e.g. `vap5g0priv`, `ETH3` |
| `DeviceType` | Mobile, Computer, HomePlug, … |
| `Tags` | `wifi`, `eth`, `dhcp`, `ssw_sta`, … |
| `Actions[]` | Discover per-device methods |

---

## How `sah` maps today

| CLI | SoftAtHome |
|---|---|
| `login` | `sah.Device.Information` / `createContext` |
| `info` | `DeviceInfo` / `get` |
| `wan` | `NMC` / `getWANStatus` |
| `devices` / `find` | `Devices` / `get` |
| `topology` | `Devices.Device.lan` / `topology` |
| `dhcp *` | `DHCPv4.Server.Pool.default` / … |
| `ports` | `Firewall` / `getPortForwarding` |
| `wifi` | `NMC.Wifi` / `get` |
| `firewall` | `getFirewallLevel` + `getDMZ` |
| `speedtest` | `IPPingDiagnostics` + `SpeedTest.Diagnostics.*` (WAN); Cloudflare from the CLI host if the gateway has no SpeedTest API |
| `device rename` | `Devices.Device.<key>` / `setName` |
| `call` | arbitrary |

When adding commands: typed helper on `SahClient` first, then a thin CLI
command. Document **MUTATE** in [AGENTS.md](../AGENTS.md).

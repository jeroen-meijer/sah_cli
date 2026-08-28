# KPN Ensemble SoftAtHome API catalog

From gateway Ensemble screen YAMLs
(`http://<host>/assets/ensemble/apps/kpnApp/screens/*.yaml` → `API:` blocks).

Screens scraped: Login, Home, Security, WiFi, LokaalNetwerk, Telefoon,
Landing, Logout, AppGateway, Feedback (+ scripts). Not from `main.dart.js`.

**Mutate?** is a heuristic (`set*` / `add*` / `delete*` / …). Confirm with the
user before calling mutating methods on a live gateway.

Machine-readable twin: [ensemble-api-inventory.json](ensemble-api-inventory.json).

---

### `DHCPv4.Server`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getDHCPServerPool` | `getDhcpSettings` |  |

### `DHCPv4.Server.Pool.default`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `addStaticLease` | `addStaticLease` | yes |
| `deleteStaticLease` | `deleteStaticLeases` | yes |
| `getLeases` | `getDHCPLeases` |  |
| `getStaticLeases` | `getStaticLeases` |  |
| `setStaticLease` | `setStaticLease` | yes |

### `DHCPv4.Server.Pool.guest`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getLeases` | `getGuestDHCPLeases` |  |

### `DNS`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDnsMode` |  |

### `DNS.Server.Route`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDnsRoutes` |  |

### `DeviceInfo`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDeviceInfo` |  |

### `Devices`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `destroyDevice` | `removeDevice` | yes |
| `get` | `getActiveDevices` |  |

### `Devices.Device.${mac}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDeviceDetails` |  |
| `setName` | `setDeviceName` | yes |
| `setType` | `setDeviceType` | yes |

### `Devices.Device.${mac}.SSW`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `execAPI` | `getExtenderWifiStatus` | yes |

### `Devices.Device.HGW`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDeviceInfoHGW` |  |
| `topology` | `getTopology` |  |

### `Devices.Device.guest`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `topology` | `getTopologyGuest` |  |

### `DynDNS`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `addHost` | `setDynDnsHost` | yes |
| `delHost` | `deleteDynDnsHost` | yes |
| `getHosts` | `getDynDnsHosts` |  |
| `setGlobalEnable` | `setGlobalEnable` | yes |

### `Firewall`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `deleteCustomRule` | `deleteCustomRule` | yes |
| `deleteDMZ` | `deleteDMZ` | yes |
| `deletePinhole` | `deleteIPv6OpenPorts` | yes |
| `deletePortForwarding` | `deleteIPv4Rules` | yes |
| `get` | `getUpnp` |  |
| `getChainPolicy` | `getFirewallPolicy` |  |
| `getCustomRule` | `getCustomRules` |  |
| `getDMZ` | `getDMZ` |  |
| `getFirewallLevel` | `getFirewallLevel` |  |
| `getPinhole` | `getIPv6OpenPorts` |  |
| `getPortForwarding` | `getIPv4Rules` |  |
| `getRespondToPing` | `getRespondToPing` |  |
| `set` | `setUpnp` | yes |
| `setChainPolicy` | `setFirewallPolicy` | yes |
| `setCustomRule` | `setCustomRule` | yes |
| `setDMZ` | `setDMZ` | yes |
| `setFirewallIPv6Level` | `setFirewallIPv6Level` | yes |
| `setFirewallLevel` | `setFirewallLevel` | yes |
| `setPinhole` | `addIPv6OpenPort` | yes |
| `setPortForwarding` | `editIPv4Rules` | yes |
| `setRespondToPing` | `setRespondToPing` | yes |

### `Firewall.ConnectionTracking.SIP`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getFirewallConnectionTrackingSIP` |  |
| `set` | `setFirewallConnectionTrackingSIP` | yes |

### `HTTPService`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getCurrentUser` | `getCurrentUser` |  |

### `IPPingDiagnostics`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `execDiagnostic` | `startPing` | yes |

### `LEDs`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getRootLEDs` | `getRootLEDs` |  |

### `LEDs.LED`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getV10Leds` |  |

### `LEDs.LED.WifiGreen`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setLedBrightness` | yes |

### `MQTT.Client.usp-client`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getMqttClient` |  |

### `MSS`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDeviceMode` |  |

### `MSS.Config`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getMSSConfig` |  |

### `NMC`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getWANStatus` | `getWANInfo` |  |

### `NMC.Devices`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `findSSW` | `findSSW` |  |
| `getDevice` | `getSSWInfo` |  |

### `NMC.GroupFunction`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `ResetAdminPassword` | `resetPassword` | yes |

### `NMC.Guest`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getGuestWiFiStatus` |  |
| `set` | `setGuestWiFiBandwidth` | yes |

### `NMC.Role`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getRole` |  |

### `NMC.Wifi`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getWifiStatus` |  |
| `set` | `setLocalWifiStatus` | yes |

### `NMC.WlanTimer`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `disableActivationTimer` | `disabledGuestWiFiTimer` | yes |
| `getActivationTimer` | `getGuestWiFiTimer` |  |
| `setActivationTimer` | `setGuestWiFiTimeLimit` | yes |

### `NeMo.Intf.${ethNum}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getWanPortParams` |  |

### `NeMo.Intf.${interface}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `toggleInterface` | yes |

### `NeMo.Intf.${port}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setDuplexMode` | yes |

### `NeMo.Intf.${service}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setWLanManager` | yes |

### `NeMo.Intf.ETH0`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getMIBs` | `getPort1Params` |  |
| `getNetDevStats` | `getPort1Usage` |  |

### `NeMo.Intf.ETH1`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getMIBs` | `getPort2Params` |  |
| `getNetDevStats` | `getPort2Usage` |  |

### `NeMo.Intf.ETH2`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getMIBs` | `getPort3Params` |  |
| `getNetDevStats` | `getPort3Usage` |  |

### `NeMo.Intf.ETH3`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getMIBs` | `getPort4Params` |  |
| `getNetDevStats` | `getPort4Usage` |  |

### `NeMo.Intf.brguest`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getMIBs` | `getGuestWiFiInfo` |  |

### `NeMo.Intf.bridge`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getSTPStatus` |  |
| `set` | `setSTPStatus` | yes |

### `NeMo.Intf.data`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getIntfs` | `getIntfs` |  |
| `getMIBs` | `getInternetConnection` |  |
| `luckyAddrAddress` | `getGlobalIPV6` | yes |

### `NeMo.Intf.iptv`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getIPTV` |  |
| `luckyAddrAddress` | `getIptvIp` | yes |

### `NeMo.Intf.lan`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getMIBs` | `getMacFiltering` |  |
| `setWLANConfig` | `setMacFiltering` | yes |

### `NeMo.Intf.rad2g0`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `get2gRadio` |  |
| `getScanResults` | `get2gScanResult` |  |
| `getSpectrumInfo` | `get2gSpectrum` |  |
| `set` | `setWifiStatus2g` | yes |
| `setWLANConfig` | `set2gRadioAutoChannel` | yes |

### `NeMo.Intf.rad5g0`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `get5gRadio` |  |
| `getScanResults` | `get5gScanResult` |  |
| `getSpectrumInfo` | `get5gSpectrum` |  |
| `set` | `setWifiStatus5g` | yes |
| `setWLANConfig` | `set5gRadioAutoChannel` | yes |

### `NeMo.Intf.vap2g0ext`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getExtra2gWifi` |  |

### `NeMo.Intf.vap5g0ext`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getExtra5gWifi` |  |

### `NeMo.Intf.wwan`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getWWAN` |  |

### `NetMaster`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getIpv6Status` |  |
| `set` | `setIpv6Status` | yes |

### `NetMaster.LAN.default.Bridge.${intf}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `addIntf` | `addIntf` | yes |
| `removeIntf` | `removeIntf` | yes |

### `NetMaster.LAN.default.Bridge.guest`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `setIPv4` | `setGuestDhcpSettings` | yes |

### `NetMaster.LAN.default.Bridge.guest.IPv6.guest.DHCPv6`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setGuestIpv6PrefixDelegationLength` | yes |

### `NetMaster.LAN.default.Bridge.lan`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setDhcpDomainName` | yes |
| `setHostName` | `setDhcpHostName` | yes |
| `setIPv4` | `setDhcpIPv4Settings` | yes |
| `setIPv6Configuration` | `setIpv6PrefixDelegation` | yes |

### `NetMaster.LAN.default.Bridge.lan.DHCPv4`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDHCPIPv4Authorative` |  |

### `NetMaster.LAN.default.Bridge.lan.HostName`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getDhcpHostName` |  |

### `NetMaster.LAN.default.Bridge.lan.IPv6.lan.DHCPv6`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setLanIpv6PrefixDelegationLength` | yes |

### `PasswordRecovery`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `start` | `startPasswordRecovery` | yes |

### `SAHPairing`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `unpair` | `unPairExtender` | yes |

### `SSW.Steering.MasterConfig`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getSswSteeringMaster` |  |
| `set` | `setSswSteeringMaster` | yes |

### `Scheduler`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `addSchedule` | `setDeviceSchedule` | yes |
| `enableSchedule` | `setWifiScheduleStatus` | yes |
| `getCompleteSchedules` | `getDevicesSchedule` |  |
| `getSchedule` | `getDeviceSchedule` |  |
| `overrideSchedule` | `toggleDeviceSchedule` | yes |
| `removeSchedules` | `deleteDeviceSchedule` | yes |

### `SpeedTest.Diagnostics.Download`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `runDiagnostics` | `runDownstreamSpeedTest` | yes |

### `SpeedTest.Diagnostics.Upload`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `runDiagnostics` | `runUpstreamSpeedTest` | yes |

### `Tessares`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getHybridAccessStatus` |  |

### `Time`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getTime` | `getTime` |  |

### `UserManagement`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `changePasswordSec` | `changePassword` | yes |

### `UserManagement.User.admin`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getUserSettingsPreLogin` |  |

### `VoiceService.VoiceApplication`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getCallList` | `getCallHistory` |  |
| `listGroups` | `getIncomingLineAssignment` |  |
| `listHandsets` | `getOutgoingLineAssignment` |  |
| `listTrunks` | `getPhoneLines` |  |
| `ring` | `testPhones` | yes |
| `setGroups` | `setIncomingLineAssignment` | yes |
| `setHandset` | `setOutingLineAssignment` | yes |
| `setTrunk` | `togglePhoneStatus` | yes |

### `VoiceService.VoiceApplication.VoiceProfile`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getTrunkNames` |  |

### `VoiceService.VoiceApplication.VoiceProfile.SIP-Trunk${lineNumber}`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `set` | `setPhoneLineName` | yes |

### `WLanManager.AccessPoint`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get` | `getWLanManager` |  |

### `WebuiupgradeService`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `getLatestVersion` | `getLatestVersion` |  |

### `eventmanager`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `get_events` | `getPasswordRecoveryEvents` |  |
| `open_channel` | `startPasswordRecoveryEvents` |  |

### `sah.Device.Information`

| Method | Ensemble API name | Mutate? |
|---|---|---|
| `createContext` | `login` | yes |
| `releaseContext` | `releaseContext` | yes |

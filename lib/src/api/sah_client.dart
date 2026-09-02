import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/api/sah_session.dart';

/// SoftAtHome WS-4 JSON client (KPN Experia / Box, Livebox-style).
///
/// Auth flow (from KPN web UI):
/// 1. `POST …/ws/NeMo/Intf/lan:getMIBs` with `Authorization: X-Sah-Login`
///    and body `sah.Device.Information` / `createContext`
/// 2. Store `data.contextID` + first `Set-Cookie`
/// 3. Authenticated calls use:
///    - `Authorization: X-Sah <contextID>`
///    - `X-Context: <contextID>`
///    - `Cookie: <sessid cookie>`
///    - `Content-Type: application/x-sah-ws-4-call+json`
class SahClient({
  /// Host or IP, without scheme (e.g. `192.168.2.254`).
  required final String host,
  http.Client? httpClient,

  /// SoftAtHome admin username (KPN uses `admin`).
  final String username = 'admin',

  /// Stored / env password for auto-relogin when the session expires.
  final String? password,

  /// Called after a successful login (including auto-relogin).
  final void Function(SahSession session)? persistSession,

  /// KPN posts every call to this path; Livebox often uses `/ws` or `/sysbus/…`.
  final String wsPath = '/ws/NeMo/Intf/lan:getMIBs',
}) {
  final http.Client _http = httpClient ?? http.Client();

  SahSession? _session;

  SahSession? get session => _session;

  Uri get _endpoint => Uri.parse('http://$host$wsPath');

  /// Restore a previously obtained session (CLI `--context` / saved file).
  set session(SahSession session) {
    _session = session;
  }

  /// Login and store session on this client.
  Future<SahSession> login(String password) async {
    final response = await _http.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/x-sah-ws-4-call+js',
        'Authorization': 'X-Sah-Login',
      },
      body: jsonEncode({
        'service': 'sah.Device.Information',
        'method': 'createContext',
        'parameters': {
          'applicationName': 'webui',
          'username': username,
          'password': password,
        },
      }),
    );

    if (response.statusCode == 401) {
      throw SahException.incorrectPassword(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final decoded = _decodeBody(response);
    final data = decoded['data'];
    if (data is! Map<String, dynamic> || data['contextID'] is! String) {
      throw SahException(
        'Login failed: missing contextID',
        statusCode: response.statusCode,
        body: decoded,
      );
    }

    final contextId = data['contextID'] as String;
    final cookie = _firstSetCookie(response.headers);
    if (cookie == null || cookie.isEmpty) {
      throw SahException(
        'Login failed: missing Set-Cookie',
        statusCode: response.statusCode,
        body: decoded,
      );
    }

    final session = SahSession(
      host: host,
      contextId: contextId,
      cookie: cookie,
    );
    _session = session;
    return session;
  }

  /// Generic SoftAtHome call (one auto-relogin + retry when [password] is set).
  Future<Map<String, dynamic>> call({
    required String service,
    required String method,
    Object? parameters,
    bool requireAuth = true,
  }) async {
    if (requireAuth && _session == null) {
      await _ensureSession();
    }

    try {
      return await _execute(
        service: service,
        method: method,
        parameters: parameters,
        requireAuth: requireAuth,
      );
    } on SahException catch (e) {
      if (!requireAuth || !e.isAuthFailure || password == null) {
        rethrow;
      }
      await _relogin();
      try {
        return await _execute(
          service: service,
          method: method,
          parameters: parameters,
          requireAuth: requireAuth,
        );
      } on SahException catch (retryError) {
        if (_isPermissionDenied(retryError)) {
          throw SahException(
            'permission denied',
            statusCode: retryError.statusCode,
            body: retryError.body,
          );
        }
        rethrow;
      }
    }
  }

  static bool _isPermissionDenied(SahException e) {
    final d = e.userMessage.toLowerCase();
    return d == 'permission denied' ||
        d == 'session expired or permission denied';
  }

  Future<void> _ensureSession() async {
    final stored = password;
    if (stored == null || stored.isEmpty) {
      throw SahException('Not authenticated. Run `sah login` first.');
    }
    await _relogin();
  }

  Future<void> _relogin() async {
    final stored = password;
    if (stored == null || stored.isEmpty) {
      throw SahException('Not authenticated. Run `sah login` first.');
    }
    try {
      final session = await login(stored);
      persistSession?.call(session);
    } on SahException catch (e) {
      if (e.statusCode == 401 || e.message == 'incorrect password') {
        throw SahException.incorrectPassword(
          statusCode: e.statusCode,
          body: e.body,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _execute({
    required String service,
    required String method,
    required bool requireAuth,
    Object? parameters,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/x-sah-ws-4-call+json',
    };

    if (requireAuth) {
      final session = _session;
      if (session == null) {
        throw SahException('Not authenticated. Run `sah login` first.');
      }
      headers['Authorization'] = 'X-Sah ${session.contextId}';
      headers['X-Context'] = session.contextId;
      headers['Cookie'] = session.cookie;
    }

    final response = await _http.post(
      _endpoint,
      headers: headers,
      body: jsonEncode({
        'service': service,
        'method': method,
        'parameters': parameters ?? <String, dynamic>{},
      }),
    );

    final decoded = _decodeBody(response);
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw SahException(
        'API error for $service::$method: ${jsonEncode(errors)}',
        statusCode: response.statusCode,
        body: decoded,
      );
    }
    // SoftAtHome sometimes returns a bare `{error, description, info}` body
    // with no `errors` list (e.g. missing SpeedTest.* objects).
    if (decoded.containsKey('error') &&
        !decoded.containsKey('status') &&
        !decoded.containsKey('data')) {
      throw SahException(
        'API error for $service::$method: ${jsonEncode(decoded)}',
        statusCode: response.statusCode,
        body: decoded,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> deviceInfo() =>
      call(service: 'DeviceInfo', method: 'get');

  Future<Map<String, dynamic>> wanStatus() =>
      call(service: 'NMC', method: 'getWANStatus');

  Future<Map<String, dynamic>> currentUser() =>
      call(service: 'HTTPService', method: 'getCurrentUser');

  /// Connected / known hosts (`Devices.get`).
  Future<Map<String, dynamic>> devices({Object? expression, String? flags}) {
    final parameters = <String, dynamic>{};
    if (expression != null) {
      parameters['expression'] = expression;
    }
    if (flags != null) {
      parameters['flags'] = flags;
    }
    return call(
      service: 'Devices',
      method: 'get',
      parameters: parameters.isEmpty ? <String, dynamic>{} : parameters,
    );
  }

  Future<Map<String, dynamic>> activeDevices() => devices(
    expression: {
      'wifi': 'not interface and not self and wifi and .Active==true',
      'ethernet': 'not interface and not self and eth and .Active==true',
    },
    flags: 'full_links',
  );

  Future<Map<String, dynamic>> topology() => call(
    service: 'Devices.Device.lan',
    method: 'topology',
    parameters: {'expression': 'not logical', 'flags': 'no_recurse|no_actions'},
  );

  Future<Map<String, dynamic>> lanMibs() => call(
    service: 'NeMo.Intf.lan',
    method: 'getMIBs',
    parameters: <String, dynamic>{},
  );

  /// SoftAtHome DHCP pool object path (KPN / Livebox default pool).
  static const defaultDhcpPool = 'DHCPv4.Server.Pool.default';

  Future<Map<String, dynamic>> dhcpStaticLeases({
    String pool = defaultDhcpPool,
  }) => call(service: pool, method: 'getStaticLeases');

  Future<Map<String, dynamic>> dhcpLeases({
    String pool = defaultDhcpPool,
    String? rule,
  }) {
    final parameters = <String, dynamic>{};
    if (rule != null) {
      parameters['rule'] = rule;
    }
    return call(service: pool, method: 'getLeases', parameters: parameters);
  }

  /// Persist a DHCP reservation (mutates the gateway).
  Future<Map<String, dynamic>> dhcpAddStaticLease({
    required String macAddress,
    required String ipAddress,
    String pool = defaultDhcpPool,
  }) => call(
    service: pool,
    method: 'addStaticLease',
    parameters: {'MACAddress': macAddress, 'IPAddress': ipAddress},
  );

  /// Remove a DHCP reservation (mutates the gateway).
  Future<Map<String, dynamic>> dhcpDeleteStaticLease({
    required String macAddress,
    String pool = defaultDhcpPool,
  }) => call(
    service: pool,
    method: 'deleteStaticLease',
    parameters: {'MACAddress': macAddress},
  );

  Future<Map<String, dynamic>> wifiStatus() =>
      call(service: 'NMC.Wifi', method: 'get');

  Future<Map<String, dynamic>> firewallLevel() =>
      call(service: 'Firewall', method: 'getFirewallLevel');

  Future<Map<String, dynamic>> firewallDmz() =>
      call(service: 'Firewall', method: 'getDMZ');

  Future<Map<String, dynamic>> portForwarding() => call(
    service: 'Firewall',
    method: 'getPortForwarding',
    parameters: {'origin': 'webui'},
  );

  Future<Map<String, dynamic>> hgw() =>
      call(service: 'Devices.Device.HGW', method: 'get');

  /// Ping host the KPN speed-test dialog uses by default.
  static const defaultSpeedTestPingHost = '34.141.213.235';

  /// `IPPingDiagnostics.execDiagnostic` (KPN speed-test dialog).
  Future<Map<String, dynamic>> pingDiagnostics({
    String host = defaultSpeedTestPingHost,
    String protocolVersion = 'IPv4',
  }) => call(
    service: 'IPPingDiagnostics',
    method: 'execDiagnostic',
    parameters: {'ipHost': host, 'ProtocolVersion': protocolVersion},
  );

  /// `SpeedTest.Diagnostics.Download.runDiagnostics`.
  ///
  /// Absent on some firmwares (H369As / V10: object not found). The KPN UI
  /// sends empty-string parameters.
  Future<Map<String, dynamic>> speedTestDownload() => call(
    service: 'SpeedTest.Diagnostics.Download',
    method: 'runDiagnostics',
    parameters: '',
  );

  /// `SpeedTest.Diagnostics.Upload.runDiagnostics`.
  Future<Map<String, dynamic>> speedTestUpload() => call(
    service: 'SpeedTest.Diagnostics.Upload',
    method: 'runDiagnostics',
    parameters: '',
  );

  /// Rename a device in the gateway UI (mutates the gateway).
  Future<Map<String, dynamic>> setDeviceName({
    required String deviceKey,
    required String name,
    String source = 'webui',
  }) => call(
    service: 'Devices.Device.$deviceKey',
    method: 'setName',
    parameters: {'name': name, 'source': source},
  );

  void close() => _http.close();

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SahException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw SahException(
        'Unexpected JSON type: ${decoded.runtimeType}',
        statusCode: response.statusCode,
        body: decoded,
      );
    } on FormatException catch (e) {
      throw SahException(
        'Invalid JSON: $e',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  /// Prefer the sessid cookie; fall back to the first Set-Cookie pair.
  @visibleForTesting
  static String? firstSetCookieForTest(Map<String, String> headers) =>
      _firstSetCookie(headers);

  static String? _firstSetCookie(Map<String, String> headers) {
    // package:http lowercases header names.
    final raw = headers['set-cookie'];
    if (raw == null || raw.isEmpty) {
      return null;
    }

    // May contain multiple cookies joined by ", "; pick sessid if present.
    final parts = raw.split(RegExp(r',\s*(?=[^ ;]+=)'));
    for (final part in parts) {
      final pair = part.split(';').first.trim();
      if (pair.toLowerCase().contains('sessid=')) {
        return pair;
      }
    }
    return raw.split(';').first.trim();
  }
}

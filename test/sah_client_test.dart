import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_credentials.dart';
import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/api/sah_session.dart';
import 'package:sah/src/cli_error.dart';
import 'package:sah/src/style.dart';
import 'package:test/test.dart';

void main() {
  group('SahClient cookie parsing', () {
    test('prefers sessid cookie', () {
      final cookie = SahClient.firstSetCookieForTest({
        'set-cookie':
            'a1b2c3d4/accept-language=en; Path=/, a1b2c3d4/sessid=abc123; Path=/',
      });
      expect(cookie, 'a1b2c3d4/sessid=abc123');
    });

    test('falls back to first pair', () {
      final cookie = SahClient.firstSetCookieForTest({
        'set-cookie': 'only=one; Path=/',
      });
      expect(cookie, 'only=one');
    });
  });

  group('SahClient auto-relogin', () {
    test('retries once after Permission denied when password is set', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'createContext') {
          return http.Response(
            jsonEncode({
              'status': 0,
              'data': {'contextID': 'new-ctx'},
            }),
            200,
            headers: {'set-cookie': 'prefix/sessid=new; Path=/'},
          );
        }
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'errors': [
                {'error': 1, 'description': 'Permission denied'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 0, 'data': {}}), 200);
      });

      final persisted = <SahSession>[];
      final client = SahClient(
        host: '192.168.2.254',
        httpClient: mock,
        password: 'secret',
        persistSession: persisted.add,
      )..session = const SahSession(
        host: '192.168.2.254',
        contextId: 'old',
        cookie: 'old/sessid=x',
      );

      final result = await client.call(service: 'Devices', method: 'get');
      expect(result['status'], 0);
      expect(persisted, hasLength(1));
      expect(persisted.single.contextId, 'new-ctx');
      expect(calls, 3); // failed call + login + retry
      client.close();
    });

    test('maps createContext 401 to incorrect password', () async {
      final mock = MockClient(
        (request) => Future.value(http.Response('Unauthorized', 401)),
      );
      final client = SahClient(
        host: '192.168.2.254',
        httpClient: mock,
        password: 'wrong',
      );
      try {
        await client.login('wrong');
        fail('expected SahException');
      } on SahException catch (e) {
        expect(e.userMessage, 'incorrect password');
      }
      client.close();
    });

    test('does not loop when retry still Permission denied', () async {
      var deviceCalls = 0;
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['method'] == 'createContext') {
          return http.Response(
            jsonEncode({
              'status': 0,
              'data': {'contextID': 'ctx'},
            }),
            200,
            headers: {'set-cookie': 'p/sessid=y; Path=/'},
          );
        }
        deviceCalls++;
        return http.Response(
          jsonEncode({
            'errors': [
              {'error': 1, 'description': 'Permission denied'},
            ],
          }),
          200,
        );
      });

      final client = SahClient(
        host: '192.168.2.254',
        httpClient: mock,
        password: 'secret',
      )..session = const SahSession(
        host: '192.168.2.254',
        contextId: 'old',
        cookie: 'old/sessid=x',
      );

      try {
        await client.call(service: 'Devices', method: 'get');
        fail('expected SahException');
      } on SahException catch (e) {
        expect(e.userMessage, 'permission denied');
        expect(e.tip, isNull);
      }
      expect(deviceCalls, 2);
      client.close();
    });
  });

  group('SahCredentials', () {
    test('round-trips through a temp file', () {
      final dir = Directory.systemTemp.createTempSync('sah-cred-');
      final file = File('${dir.path}/credentials.json');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });

      const SahCredentials(
        host: '192.168.2.254',
        password: 's3cret',
      ).save(file);

      final loaded = SahCredentials.load(file);
      expect(loaded?.host, '192.168.2.254');
      expect(loaded?.password, 's3cret');
      expect(loaded?.username, 'admin');

      if (!Platform.isWindows) {
        final mode = file.statSync().mode & 0x1FF;
        expect(mode, 0x180); // 0600
      }

      SahCredentials.clear(file);
      expect(SahCredentials.load(file), isNull);
    });
  });

  group('reportCliError', () {
    test('writes error and tip lines', () {
      final buffer = StringBuffer();
      reportCliError(
        SahException.incorrectPassword(),
        style: SahStyle(color: false),
        sink: buffer,
      );
      expect(
        buffer.toString(),
        'error: incorrect password\n'
        '  tip: check --password or SAH_PASSWORD, then run `sah login`\n',
      );
    });
  });
}

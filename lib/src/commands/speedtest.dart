import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/commands/sah_command.dart';
import 'package:sah/src/config.dart';
import 'package:sah/src/local_speed_test.dart';
import 'package:sah/src/progress_bar.dart';

/// WAN speed test.
///
/// Tries SoftAtHome `SpeedTest.*` first (same path as the KPN UI). Some
/// firmwares (H369As included) lack those objects. Then the CLI measures
/// from this machine against Cloudflare. Still WAN, not LAN/iperf.
class SpeedtestCommand() extends Command<int> with SahCommandContext {
  this {
    argParser
      ..addFlag(
        'ping',
        negatable: false,
        help: 'Latency only (gateway ping, else HTTP RTT).',
      )
      ..addFlag('download', negatable: false, help: 'Download only.')
      ..addFlag('upload', negatable: false, help: 'Upload only.')
      ..addFlag(
        'local',
        negatable: false,
        help: 'Skip the gateway; use Cloudflare from this machine.',
      )
      ..addFlag(
        'gateway',
        negatable: false,
        help: 'SoftAtHome APIs only (no Cloudflare fallback).',
      )
      ..addOption(
        'target',
        help:
            'Gateway ping host/IP (KPN UI default: '
            '${SahClient.defaultSpeedTestPingHost}).',
        defaultsTo: SahClient.defaultSpeedTestPingHost,
      )
      ..addOption(
        'ip-version',
        allowed: const ['IPv4', 'IPv6'],
        defaultsTo: 'IPv4',
        help: 'ProtocolVersion for the gateway ping.',
      )
      ..addOption(
        'download-bytes',
        help:
            'Local download size in bytes '
            '(default ${LocalSpeedTest.defaultDownloadBytes}, '
            '${LocalSpeedTest.defaultMegabits} Mbit).',
      )
      ..addOption(
        'upload-bytes',
        help:
            'Local upload size in bytes '
            '(default ${LocalSpeedTest.defaultUploadBytes}, '
            '${LocalSpeedTest.defaultMegabits} Mbit).',
      );
  }

  @override
  String get name => 'speedtest';

  @override
  String get description =>
      'WAN speed test via SoftAtHome, or Cloudflare from this machine. '
      'Not a LAN test.';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final onlyPing = argResults!['ping'] as bool;
    final onlyDownload = argResults!['download'] as bool;
    final onlyUpload = argResults!['upload'] as bool;
    final forceLocal = argResults!['local'] as bool;
    final gatewayOnly = argResults!['gateway'] as bool;
    if (forceLocal && gatewayOnly) {
      usageException('Use either --local or --gateway, not both.');
    }

    final exclusive = [
      onlyPing,
      onlyDownload,
      onlyUpload,
    ].where((v) => v).length;
    if (exclusive > 1) {
      usageException('Use at most one of --ping, --download, --upload.');
    }

    final runPing = exclusive == 0 || onlyPing;
    final runDownload = exclusive == 0 || onlyDownload;
    final runUpload = exclusive == 0 || onlyUpload;

    final target = argResults!['target'] as String;
    final ipVersion = argResults!['ip-version'] as String;
    final downloadBytes = _parseBytes(
      argResults!['download-bytes'] as String?,
      LocalSpeedTest.defaultDownloadBytes,
    );
    final uploadBytes = _parseBytes(
      argResults!['upload-bytes'] as String?,
      LocalSpeedTest.defaultUploadBytes,
    );

    final payload = <String, Object?>{};
    final errors = <String, String>{};
    var usedLocal = forceLocal;
    var noSpeedApi = false;

    void log(String message) {
      if (!config.jsonOutput && !config.quiet) {
        stderr.writeln(message);
      }
    }

    if (!forceLocal) {
      if (runPing) {
        log('Pinging $target via gateway ($ipVersion)...');
        try {
          final result = await client.pingDiagnostics(
            host: target,
            protocolVersion: ipVersion,
          );
          final status = result['status'] ?? result;
          payload['ping'] = status;
          if (status is Map && status['DiagnosticsState'] == 'Failed') {
            errors['ping'] =
                'Gateway ping failed (${status['packetsFailed']} lost)';
          }
        } on SahException catch (e) {
          errors['ping'] = e.userMessage;
          log('Gateway ping failed: ${e.userMessage}');
        }
      }

      if (runDownload) {
        log('Gateway download...');
        try {
          final result = await client.speedTestDownload();
          payload['download'] = result['status'] ?? result;
        } on SahException catch (e) {
          errors['download'] = e.userMessage;
          if (e.isObjectNotFound) {
            noSpeedApi = true;
          }
          log('Gateway download failed: ${e.userMessage}');
        }
      }

      if (runUpload) {
        log('Gateway upload...');
        try {
          final result = await client.speedTestUpload();
          payload['upload'] = result['status'] ?? result;
        } on SahException catch (e) {
          errors['upload'] = e.userMessage;
          if (e.isObjectNotFound) {
            noSpeedApi = true;
          }
          log('Gateway upload failed: ${e.userMessage}');
        }
      }
    }

    final needLocalDownload = runDownload && !payload.containsKey('download');
    final needLocalUpload = runUpload && !payload.containsKey('upload');
    final needLocalPing =
        runPing &&
        (forceLocal ||
            !payload.containsKey('ping') ||
            (payload['ping'] is Map &&
                (payload['ping']! as Map)['DiagnosticsState'] == 'Failed'));

    final useLocal =
        !gatewayOnly &&
        (forceLocal ||
            noSpeedApi ||
            needLocalDownload ||
            needLocalUpload ||
            needLocalPing);

    if (useLocal && (needLocalDownload || needLocalUpload || needLocalPing)) {
      usedLocal = true;
      if (!forceLocal) {
        log(
          noSpeedApi
              ? 'Gateway has no SpeedTest API; '
                    'running Cloudflare test on this machine...'
              : 'Running Cloudflare test on this machine...',
        );
      } else {
        log('Cloudflare test on this machine...');
      }

      final local = LocalSpeedTest();
      try {
        if (needLocalPing) {
          log('HTTP latency...');
          try {
            payload['ping'] = await local.latency();
            errors.remove('ping');
          } catch (e) {
            errors['ping'] = formatCliError(e);
            log('Local latency failed: ${formatCliError(e)}');
          }
        }
        if (needLocalDownload) {
          final progress = _transferProgress(
            config: config,
            total: downloadBytes,
            label: 'Download',
          );
          try {
            payload['download'] = await local.download(
              bytes: downloadBytes,
              onProgress: progress == null
                  ? null
                  : (current, total) => progress.update(current),
            );
            await progress?.finish();
            errors.remove('download');
          } catch (e) {
            await progress?.fail();
            errors['download'] = formatCliError(e);
            log('Local download failed: ${formatCliError(e)}');
          }
        }
        if (needLocalUpload) {
          final progress = _transferProgress(
            config: config,
            total: uploadBytes,
            label: 'Upload',
          );
          try {
            payload['upload'] = await local.upload(
              bytes: uploadBytes,
              onProgress: progress == null
                  ? null
                  : (current, total) => progress.update(current),
            );
            await progress?.finish();
            errors.remove('upload');
          } catch (e) {
            await progress?.fail();
            errors['upload'] = formatCliError(e);
            log('Local upload failed: ${formatCliError(e)}');
          }
        }
      } finally {
        local.close();
      }
    }

    if (errors.isNotEmpty) {
      payload['errors'] = errors;
    }
    if (usedLocal) {
      payload['mode'] = 'local';
    }
    if (!forceLocal && !usedLocal) {
      payload['mode'] = 'gateway';
    }
    if (!forceLocal && usedLocal) {
      payload['mode'] = 'local-fallback';
    }

    out.emit(payload, () => out.speedTest(payload));
    return errors.isEmpty ? 0 : 1;
  });

  ProgressBar? _transferProgress({
    required SahConfig config,
    required int total,
    required String label,
  }) {
    if (config.jsonOutput || config.quiet) {
      return null;
    }
    if (!stderr.hasTerminal) {
      stderr.writeln('$label (${_megabytes(total)} MB)...');
      return null;
    }
    return ProgressBar(total: total, prefix: '$label ');
  }

  static String _megabytes(int bytes) => (bytes / 1e6).toStringAsFixed(1);

  int _parseBytes(String? raw, int fallback) {
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    final value = int.tryParse(raw);
    if (value == null || value <= 0) {
      usageException('Bytes must be a positive integer, got: $raw');
    }
    return value;
  }
}

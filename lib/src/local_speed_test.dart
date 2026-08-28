import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Bytes sent/received so far and total size.
typedef TransferProgress = void Function(int current, int total);

/// WAN download/upload/latency against Cloudflare's public speed URLs.
///
/// Used when the gateway has no SoftAtHome `SpeedTest.*` objects.
class LocalSpeedTest({http.Client? httpClient}) {
  final http.Client _http = httpClient ?? http.Client();

  static const downloadUrl = 'https://speed.cloudflare.com/__down';
  static const uploadUrl = 'https://speed.cloudflare.com/__up';

  /// Cloudflare returns HTTP 403 when `?bytes=` is 10_000_001 to 19_999_999.
  static const maxDownloadChunkBytes = 10_000_000;

  /// Largest single GET verified against Cloudflare (Aug 2026).
  static const maxSingleDownloadBytes = 25_000_000;

  /// Default transfer size: 100 Mbit (12.5 MB) per direction.
  static const defaultMegabits = 100;
  static const int defaultDownloadBytes = defaultMegabits * 1000000 ~/ 8;
  static const int defaultUploadBytes = defaultDownloadBytes;

  void close() => _http.close();

  /// Split [totalBytes] into GET sizes Cloudflare accepts.
  @visibleForTesting
  static List<int> downloadChunks(int totalBytes) {
    if (totalBytes <= 0) {
      return const [];
    }
    if (totalBytes <= maxDownloadChunkBytes) {
      return [totalBytes];
    }
    if (totalBytes >= 20_000_000) {
      if (totalBytes <= maxSingleDownloadBytes) {
        return [totalBytes];
      }
      return [
        maxSingleDownloadBytes,
        ...downloadChunks(totalBytes - maxSingleDownloadBytes),
      ];
    }
    return [
      maxDownloadChunkBytes,
      ...downloadChunks(totalBytes - maxDownloadChunkBytes),
    ];
  }

  /// HTTP round-trip to Cloudflare, in ms.
  Future<Map<String, Object?>> latency() async {
    final uri = Uri.parse('$downloadUrl?bytes=0');
    final sw = Stopwatch()..start();
    final response = await _http.get(uri);
    sw.stop();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Latency HTTP ${response.statusCode}');
    }
    return {
      'source': 'local',
      'suite': 'cloudflare',
      'averageResponseTime': sw.elapsedMilliseconds,
      'minimumResponseTime': sw.elapsedMilliseconds,
      'maximumResponseTime': sw.elapsedMilliseconds,
      'DiagnosticsState': 'Success',
      'ipHost': uri.host,
    };
  }

  Future<Map<String, Object?>> download({
    int bytes = defaultDownloadBytes,
    TransferProgress? onProgress,
  }) async {
    final sw = Stopwatch()..start();
    var received = 0;
    onProgress?.call(0, bytes);

    for (final chunkBytes in downloadChunks(bytes)) {
      final uri = Uri.parse('$downloadUrl?bytes=$chunkBytes');
      final streamed = await _http.send(http.Request('GET', uri));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw StateError('Download HTTP ${streamed.statusCode}');
      }
      await for (final List<int> chunk in streamed.stream) {
        received += chunk.length;
        onProgress?.call(received.clamp(0, bytes), bytes);
      }
    }

    sw.stop();
    return _result(
      direction: 'download',
      bytes: received,
      elapsed: sw.elapsed,
    );
  }

  Future<Map<String, Object?>> upload({
    int bytes = defaultUploadBytes,
    TransferProgress? onProgress,
  }) async {
    final uri = Uri.parse(uploadUrl);
    final request = http.StreamedRequest('POST', uri)
      ..headers['Content-Type'] = 'application/octet-stream'
      ..contentLength = bytes;

    const chunkSize = 256 * 1024;
    unawaited(
      request.sink
          .addStream(
            _uploadBody(
              bytes: bytes,
              chunkSize: chunkSize,
              onProgress: onProgress,
            ),
          )
          .whenComplete(request.sink.close),
    );

    final sw = Stopwatch()..start();
    final streamed = await _http.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError('Upload HTTP ${streamed.statusCode}');
    }
    await streamed.stream.drain<void>();
    sw.stop();
    return _result(direction: 'upload', bytes: bytes, elapsed: sw.elapsed);
  }

  static Stream<List<int>> _uploadBody({
    required int bytes,
    required int chunkSize,
    TransferProgress? onProgress,
  }) async* {
    var sent = 0;
    onProgress?.call(0, bytes);
    while (sent < bytes) {
      final n = min(chunkSize, bytes - sent);
      yield Uint8List(n);
      sent += n;
      onProgress?.call(sent, bytes);
    }
  }

  Map<String, Object?> _result({
    required String direction,
    required int bytes,
    required Duration elapsed,
  }) {
    final int ms = max(1, elapsed.inMilliseconds);
    // SoftAtHome UI: throughput is kbps (`/ 1000` → Mbps).
    final throughputKbps = (bytes * 8) / ms;
    return {
      'source': 'local',
      'suite': 'cloudflare',
      'direction': direction,
      'rxbytes': bytes,
      'duration': ms,
      'throughput': throughputKbps.round(),
      'testserver': 'speed.cloudflare.com',
      'interface': 'host',
    };
  }
}

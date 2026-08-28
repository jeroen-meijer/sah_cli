import 'package:sah/src/local_speed_test.dart';
import 'package:sah/src/progress_bar.dart';
import 'package:test/test.dart';

void main() {
  group('LocalSpeedTest defaults', () {
    test('100 Mbit payload', () {
      expect(LocalSpeedTest.defaultMegabits, 100);
      expect(LocalSpeedTest.defaultDownloadBytes, 12500000);
      expect(
        LocalSpeedTest.defaultUploadBytes,
        LocalSpeedTest.defaultDownloadBytes,
      );
    });
  });

  group('LocalSpeedTest.downloadChunks', () {
    test('splits 12.5 MB around Cloudflare 403 window', () {
      expect(
        LocalSpeedTest.downloadChunks(12_500_000),
        [10_000_000, 2_500_000],
      );
    });

    test('keeps 10 MB as one request', () {
      expect(LocalSpeedTest.downloadChunks(10_000_000), [10_000_000]);
    });

    test('uses 20 MB when allowed', () {
      expect(LocalSpeedTest.downloadChunks(20_000_000), [20_000_000]);
    });
  });

  group('ProgressBar', () {
    test('0, half, full', () {
      final bar = ProgressBar(total: 100, enabled: false);
      expect(
        bar.renderLine(0),
        '[                                        ] 0%',
      );
      expect(
        bar.renderLine(50),
        '[===================>                    ] 50%',
      );
      expect(
        bar.renderLine(100),
        '[========================================] 100%',
      );
    });
  });
}

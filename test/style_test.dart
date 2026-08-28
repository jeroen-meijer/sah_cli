import 'package:sah/src/style.dart';
import 'package:test/test.dart';

void main() {
  group('SahStyle bool cells', () {
    final style = SahStyle(color: false);

    test('yesNo', () {
      expect(style.yesNo(true), SahStyle.yes);
      expect(style.yesNo(false), SahStyle.no);
      expect(style.yesNo(null), '');
      expect(style.yesNo('true'), '');
    });

    test('reserved', () {
      expect(style.reserved(true), SahStyle.yes);
      expect(style.reserved(false), SahStyle.no);
      expect(style.reserved(null), '');
    });

    test('upDown', () {
      expect(style.upDown(true), SahStyle.up);
      expect(style.upDown(false), SahStyle.down);
      expect(style.upDown(null), '');
    });
  });
}

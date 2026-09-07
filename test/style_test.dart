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

    test('activeDot', () {
      expect(style.activeDot(true), SahStyle.activeFilled);
      expect(style.activeDot(false), SahStyle.activeEmpty);
      expect(style.activeDot(null), '');
    });
  });

  group('SahStyle.fieldValue', () {
    final style = SahStyle(color: false);

    test('colors any bool, not only Enable/Status keys', () {
      expect(style.fieldValue('KickRoamingStation', true), 'true');
      expect(style.fieldValue('AP_Mode', false), 'false');
      expect(style.fieldValue('Enable', true), 'true');
    });

    test('status-like strings', () {
      expect(style.fieldValue('RadioStatus', 'Up'), 'Up');
      expect(style.fieldValue('Name', 'rad2g0'), 'rad2g0');
    });

    test('empty becomes em dash when color off still empty string path', () {
      expect(style.fieldValue('HeCapsSupported', ''), '');
    });
  });
}

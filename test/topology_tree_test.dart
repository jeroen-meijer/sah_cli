import 'package:sah/src/topology_tree.dart';
import 'package:test/test.dart';

void main() {
  group('flattenTopology', () {
    test('builds branch prefixes and selectable flags', () {
      final status = {
        'Name': 'lan',
        'Key': 'lan',
        'Active': true,
        'Children': [
          {
            'Name': 'MacBook',
            'PhysAddress': '02:00:00:00:00:01',
            'IPAddress': '192.168.2.50',
            'Active': true,
            'Children': <Object>[],
          },
          {
            'Name': 'AP',
            'PhysAddress': '02:00:00:00:00:02',
            'Active': true,
            'Children': [
              {
                'Name': 'Phone',
                'PhysAddress': '02:00:00:00:00:03',
                'IPAddress': '192.168.2.51',
                'Active': true,
              },
            ],
          },
        ],
      };

      final lines = flattenTopology(status);
      expect(lines, hasLength(4));
      expect(lines[0].branchPrefix, '');
      expect(lines[0].selectable, isFalse); // no MAC/IP on lan
      expect(lines[1].branchPrefix, '├─ ');
      expect(lines[1].selectable, isTrue);
      expect(lines[2].branchPrefix, '└─ ');
      expect(lines[2].selectable, isFalse); // MAC but no IP
      expect(lines[3].branchPrefix, '   └─ ');
      expect(lines[3].selectable, isTrue);
      expect(lines[3].node['Name'], 'Phone');
    });
  });
}

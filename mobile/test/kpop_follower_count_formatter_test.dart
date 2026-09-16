import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/utils/kpop_follower_count_formatter.dart';

void main() {
  group('formatKpopFollowerCount', () {
    test('uses Spanish singular and plural', () {
      expect(formatKpopFollowerCount(0), '0 seguidores');
      expect(formatKpopFollowerCount(1), '1 seguidor');
      expect(formatKpopFollowerCount(2), '2 seguidores');
    });

    test('uses dots as thousands separators', () {
      expect(formatKpopFollowerCount(1250), '1.250 seguidores');
      expect(formatKpopFollowerCount(12450), '12.450 seguidores');
      expect(formatKpopFollowerCount(1000000), '1.000.000 seguidores');
    });

    test('never formats negative totals', () {
      expect(formatKpopFollowerCount(-1), '0 seguidores');
    });
  });
}

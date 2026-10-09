import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy handler recreation overwrites persisted prefix (bug reproduction)',
    () {
      var persisted = List<int>.generate(2400, (i) => i);
      final recreatedHandlerRoute = <int>[];
      recreatedHandlerRoute.add(2400);
      persisted = List.of(recreatedHandlerRoute);
      expect(persisted, [2400]);
      expect(persisted.length, isNot(2401));
      // The old start time lived in a different preferences key and survived.
    },
  );
}

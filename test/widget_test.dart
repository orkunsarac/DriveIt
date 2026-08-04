import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/main.dart';

void main() {
  testWidgets('DriveIt home renders', (tester) async {
    await tester.pumpWidget(const DriveItApp());
    expect(find.text('Merhaba, Orkun'), findsOneWidget);
    expect(find.text('DÜNYA'), findsOneWidget);
  });
}

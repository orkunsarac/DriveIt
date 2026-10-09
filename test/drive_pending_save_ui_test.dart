import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/screens/drive_recovery_screen.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/drive_recovery_status.dart';
import 'package:driveit_project/services/gps_failure.dart';

void main() {
  testWidgets(
    'stopped session offers save recovery, user can leave without a write',
    (tester) async {
      final session = GpsSession(
        'synthetic',
        DateTime.utc(2026),
        'stopped',
        null,
      );
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DriveRecoveryScreen(
                      loadStatus: () async => DriveRecoveryStatus(
                        DriveRecoveryKind.verifiedSession,
                        session: session,
                      ),
                      loadSessions: () async => [session],
                      selectSession: (_) async {
                        selections++;
                      },
                    ),
                  ),
                ),
                child: const Text('Kurtarma'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Kurtarma'));
      await tester.pumpAndSettle();
      expect(find.text('Kurtar ve Kaydet'), findsOneWidget);
      expect(find.text('Sürüşü Bitir'), findsNothing);
      await tester.tap(find.text('Şimdi değil — kayıtları koru'));
      await tester.pumpAndSettle();
      expect(find.text('Kurtarma'), findsOneWidget);
      expect(selections, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown storage exposes safe exit and never a new-drive button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DriveRecoveryScreen(
            allowNewDrive: true,
            loadStatus: () async => DriveRecoveryStatus(
              DriveRecoveryKind.storageUnavailable,
              failure: GpsFailure(GpsErrorCode.sqliteRead),
            ),
            loadSessions: () async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sürüşü Başlat'), findsNothing);
      expect(find.textContaining('GPS_DB_READ'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

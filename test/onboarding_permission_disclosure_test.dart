import 'package:driveit_project/features/onboarding/screens/permissions_onboarding_page.dart';
import 'package:driveit_project/features/onboarding/services/onboarding_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePermissionGateway implements OnboardingPermissionGateway {
  FakePermissionGateway(this.nextSnapshot);

  OnboardingPermissionSnapshot nextSnapshot;
  var requests = 0;
  var settingsOpened = 0;

  @override
  Future<OnboardingPermissionSnapshot> readStatus() async =>
      const OnboardingPermissionSnapshot(
        locationGranted: false,
        locationPermanentlyDenied: false,
        notificationGranted: false,
      );

  @override
  Future<OnboardingPermissionSnapshot> requestSequentially() async {
    requests++;
    return nextSnapshot;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  testWidgets('disclosure precedes permission request and denial stays safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakePermissionGateway(
      const OnboardingPermissionSnapshot(
        locationGranted: false,
        locationPermanentlyDenied: false,
        notificationGranted: false,
      ),
    );
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionsOnboardingPage(
            permissionService: fake,
            onContinue: () => continued = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İzinleri Ayarla'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('location_prominent_disclosure_text')),
      findsOneWidget,
    );
    expect(find.textContaining('uygulama arka plandayken'), findsOneWidget);
    expect(find.textContaining('uygulama kapalı görünürken'), findsOneWidget);
    expect(fake.requests, 0);

    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
    expect(fake.requests, 0);
    expect(continued, isFalse);

    await tester.tap(find.text('İzinleri Ayarla'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('continue_to_location_permission')),
    );
    await tester.pumpAndSettle();
    expect(fake.requests, 1);
    expect(continued, isFalse);
  });

  testWidgets('granted location still shows disclosure before continuing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var continued = false;
    final gateway = _GrantedPermissionGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionsOnboardingPage(
            permissionService: gateway,
            onContinue: () => continued = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(continued, isFalse);
    expect(
      find.byKey(const ValueKey('location_prominent_disclosure_text')),
      findsOneWidget,
    );
    await tester.tap(find.text('Anladım, devam et'));
    await tester.pumpAndSettle();
    expect(continued, isTrue);
  });
}

class _GrantedPermissionGateway implements OnboardingPermissionGateway {
  @override
  Future<OnboardingPermissionSnapshot> readStatus() async =>
      const OnboardingPermissionSnapshot(
        locationGranted: true,
        locationPermanentlyDenied: false,
        notificationGranted: true,
      );

  @override
  Future<OnboardingPermissionSnapshot> requestSequentially() async =>
      throw StateError('No permission request expected');

  @override
  Future<bool> openSettings() async => false;
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:driveit_project/features/my_world/services/my_world_settings_service.dart';
import 'package:driveit_project/main.dart';
import 'package:driveit_project/screens/profile_settings_screen.dart';
import 'package:driveit_project/services/profile_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Gallery extends ImagePicker {
  XFile? selection;
  @override
  Future<LostDataResponse> retrieveLostData() async => LostDataResponse.empty();
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    expect(maxWidth, 512);
    expect(maxHeight, 512);
    return selection;
  }
}

// Widget tests use synchronous memory I/O; the tests above exercise real Hive.
class _MemoryBox implements Box<dynamic> {
  final _values = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    _values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProfileStorageService profile;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('driveit_profile_test_');
    Hive.init(directory.path);
    profile = await ProfileStorageService.open();
    await HiveMyWorldSettingsStore.openBox(Hive);
    PackageInfo.setMockInitialValues(
      appName: 'DriveIt',
      packageName: 'driveit',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.runAsync(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    }),
  );

  test(
    'name, photo and existing World preference survive Hive reopening',
    () async {
      await profile.saveName('  Çağrı Şahin  ');
      await profile.savePhoto(png);
      await const HiveMyWorldSettingsStore().setSkipIntroAnimation(true);
      await Hive.close();
      profile = await ProfileStorageService.open();
      await HiveMyWorldSettingsStore.openBox(Hive);
      expect(profile.name, 'Çağrı Şahin');
      expect(profile.photo, png);
      expect(const HiveMyWorldSettingsStore().skipIntroAnimation, isTrue);
    },
  );

  test(
    'invalid names and oversized or empty photos preserve saved values',
    () async {
      await profile.saveName('Orkun');
      await profile.savePhoto(png);
      await expectLater(profile.saveName('   '), throwsArgumentError);
      await expectLater(profile.saveName('a' * 41), throwsArgumentError);
      await expectLater(profile.savePhoto(Uint8List(0)), throwsArgumentError);
      await expectLater(
        profile.savePhoto(
          Uint8List(ProfileStorageService.maximumPhotoBytes + 1),
        ),
        throwsArgumentError,
      );
      expect(profile.name, 'Orkun');
      expect(profile.photo, png);
    },
  );

  testWidgets(
    'small screen edits name, toggles existing setting and shows version',
    (tester) async {
      profile = ProfileStorageService(_MemoryBox());
      final worldSettings = MemoryMyWorldSettingsStore();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfileSettingsScreen(
            profileLoader: () async => profile,
            worldSettings: worldSettings,
            imagePicker: _Gallery(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('İsim Belirle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      expect(find.text('Lütfen bir isim yaz.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Şule  ');
      await tester.runAsync(() async {
        await tester.tap(find.text('Kaydet'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(profile.name, 'Şule');
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Şule'), findsOneWidget);
      final toggle = find.byKey(const Key('world_intro_enabled_switch'));
      await tester.ensureVisible(toggle);
      await tester.runAsync(() async {
        await tester.tap(toggle);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(worldSettings.skipIntroAnimation, isTrue);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.ensureVisible(find.text('Sürüm'));
      expect(find.text('1.0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gallery saves image bytes and cancellation preserves avatar', (
    tester,
  ) async {
    profile = ProfileStorageService(_MemoryBox());
    final avatar = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      return bytes;
    });
    final gallery = _Gallery()
      ..selection = XFile.fromData(avatar!, name: 'avatar.png');
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSettingsScreen(
          profileLoader: () async => profile,
          imagePicker: gallery,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Fotoğraf Ekle'));
      // Native image decoding completes outside the fake widget-test clock.
      for (var i = 0; i < 50 && profile.photo == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(profile.photo, avatar);
    expect(find.text('Fotoğrafı Değiştir'), findsOneWidget);
    gallery.selection = null;
    await tester.tap(find.text('Fotoğrafı Değiştir'));
    await tester.pumpAndSettle();
    expect(profile.photo, avatar);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home hamburger opens full screen and back returns to home', (
    tester,
  ) async {
    await tester.pumpWidget(const DriveItApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('home_profile_settings')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProfileSettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProfileSettingsScreen), findsNothing);
    expect(find.text('Merhaba, Orkun'), findsOneWidget);
    expect(find.text('Dünya'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

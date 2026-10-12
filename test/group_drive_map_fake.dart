import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;

/// Host-only native map substitute. The real GoogleMap widget, controller,
/// marker updates and camera commands run, but no tiles/device GPS are read.
class GroupMapFake extends maps.MethodChannelGoogleMapsFlutter {
  final Set<int> ids = {};
  final List<MethodCall> calls = [];
  @override
  Future<void> updateGroundOverlays(
    maps.GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) {
    if (ids.add(creationId)) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('plugins.flutter.io/google_maps_$creationId'),
            (call) async {
              calls.add(call);
              return null;
            },
          );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onPlatformViewCreated(creationId),
      );
    }
    return const SizedBox();
  }

  void clearHandlers() {
    for (final id in ids) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('plugins.flutter.io/google_maps_$id'),
            null,
          );
    }
  }
}

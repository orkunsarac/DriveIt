import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/world_scoring_adapter.dart';
import '../tool/world_scoring_boundary_adapter.dart';

void main() {
  final cases =
      jsonDecode(
            File('test/fixtures/active_world_scoring.json').readAsStringSync(),
          )
          as List;
  final oracle =
      jsonDecode(
            File(
              'test/fixtures/active_world_scoring_oracle.json',
            ).readAsStringSync(),
          )
          as List;
  for (var i = 0; i < cases.length; i++) {
    final c = cases[i] as Json;
    test('native Dart source-of-truth scoring: ${c['name']}', () {
      final result = c['scores'] == null
          ? evaluateWorldScoring(c)
          : evaluateScriptedRegions(c);
      expect(result, oracle[i]);
    });
  }
  test('exact 1%, 200m bridge, 300m split, 1900/2000 region limits', () {
    Json result(String name) {
      final c = cases.firstWhere((c) => c['name'] == name) as Json;
      return evaluateScriptedRegions(c);
    }

    expect((result('D-exact-1pct')['winningRegions'] as List).length, 1);
    expect(result('C-under-1pct')['winningRegions'], isEmpty);
    expect((result('E-gap-200')['winningRegions'] as List).length, 1);
    expect((result('F-gap-300')['winningRegions'] as List).length, 2);
    expect(result('G-region-1900')['winningRegions'], isEmpty);
    expect(
      (result('H-region-2000')['winningRegions'] as List)
          .single['winningDistanceMeters'],
      2000,
    );
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/world_mutation_adapter.dart';

void main() {
  final cases =
      jsonDecode(
            File('test/fixtures/active_world_mutation.json').readAsStringSync(),
          )
          as List;
  final oracle =
      jsonDecode(
            File(
              'test/fixtures/active_world_mutation_oracle.json',
            ).readAsStringSync(),
          )
          as List;
  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    test(
      'native My World mutation oracle: ${c['name']}',
      () => expect(
        evaluateWorldMutation({
          'traces': c['snapshot']['candidates'],
          'challenger': c['challenger'],
          'now': c['now'],
          'inputs': (c['inputs'] as List)
              .map(
                (v) => {
                  'traceId': v['traceId'],
                  'match': v['coverage']['match'],
                  'regions': v['regions'],
                },
              )
              .toList(),
        }),
        oracle[i],
      ),
    );
  }
}

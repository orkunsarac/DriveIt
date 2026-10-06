import 'dart:convert';
import 'dart:io';
import 'world_mutation_adapter.dart';

void main(List<String> args) {
  final cases = jsonDecode(File(args[0]).readAsStringSync()) as List;
  final outputs = cases
      .map(
        (c) => evaluateWorldMutation({
          'traces': c['snapshot']['candidates'],
          'challenger': c['challenger'],
          'now': c['now'],
          'inputs': (c['inputs'] as List)
              .map(
                (i) => {
                  'traceId': i['traceId'],
                  'match': i['coverage']['match'],
                  'regions': i['regions'],
                },
              )
              .toList(),
        }),
      )
      .toList();
  File(args[1]).writeAsStringSync('${jsonEncode(outputs)}\n');
}

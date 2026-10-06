import 'dart:convert';
import 'dart:io';
import 'world_scoring_adapter.dart';
import 'world_scoring_boundary_adapter.dart';

void main(List<String> args) {
  final cases = jsonDecode(File(args.first).readAsStringSync()) as List;
  final output = jsonEncode(
    cases
        .map(
          (c) => c['scores'] == null
              ? evaluateWorldScoring(c as Json)
              : evaluateScriptedRegions(c as Json),
        )
        .toList(),
  );
  if (args.length == 2) {
    File(args[1]).writeAsStringSync(output);
  } else {
    stdout.write(output);
  }
}

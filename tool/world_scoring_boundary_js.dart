import 'dart:convert';
import 'dart:js_interop';
import 'world_scoring_boundary_adapter.dart';
import 'world_scoring_adapter.dart';

@JS('driveItWorldScoringBoundaryTest')
external set scoring(JSFunction value);
void main() {
  scoring = ((JSString input) => jsonEncode(
    evaluateScriptedRegions(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
}

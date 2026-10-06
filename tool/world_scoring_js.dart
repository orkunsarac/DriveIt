import 'dart:convert';
import 'dart:js_interop';
import 'world_scoring_adapter.dart';

@JS('driveItWorldScoring')
external set scoring(JSFunction value);
@JS('driveItActiveCoverage')
external set coverage(JSFunction value);
void main() {
  coverage = ((JSString input) => jsonEncode(
    evaluateActiveCoverage(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
  scoring = ((JSString input) => jsonEncode(
    evaluateWorldScoring(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
}

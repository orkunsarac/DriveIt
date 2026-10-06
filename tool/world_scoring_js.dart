import 'dart:convert';
import 'dart:js_interop';
import 'world_scoring_adapter.dart';

@JS('driveItWorldScoring')
external set scoring(JSFunction value);
void main() {
  scoring = ((JSString input) => jsonEncode(
    evaluateWorldScoring(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
}

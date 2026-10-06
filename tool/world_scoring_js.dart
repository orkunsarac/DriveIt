import 'dart:convert';
import 'dart:js_interop';
import 'world_scoring_adapter.dart';
import 'world_mutation_adapter.dart';

@JS('driveItWorldScoring')
external set scoring(JSFunction value);
@JS('driveItActiveCoverage')
external set coverage(JSFunction value);
@JS('driveItWorldMutation')
external set mutation(JSFunction value);
void main() {
  mutation = ((JSString input) => jsonEncode(
    evaluateWorldMutation(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
  coverage = ((JSString input) => jsonEncode(
    evaluateActiveCoverage(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
  scoring = ((JSString input) => jsonEncode(
    evaluateWorldScoring(jsonDecode(input.toDart) as Json),
  ).toJS).toJS;
}

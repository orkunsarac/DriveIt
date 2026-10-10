import 'package:integration_test/integration_test.dart';
import '../test/independent_lifecycle_test.dart' as synthetic_lifecycle;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Uses exclusively unique temporary fixture databases, never app/user boxes.
  synthetic_lifecycle.main();
}

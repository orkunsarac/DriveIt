import 'package:integration_test/integration_test.dart';
import '../test/owner_personal_screen_test.dart' as screens;

/// Runs the same synthetic Hive/owner and actual widget consumer tests inside
/// Android. No Supabase, production journal or physical device data is used.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  screens.main();
}

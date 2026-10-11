import 'package:integration_test/integration_test.dart';
import '../test/device_drive_archive_test.dart' as archive;

/// Synthetic isolated Hive and fake device grants. Credential UI is separately
/// tested by device_archive_credentials_android_test, not claimed here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  archive.main();
}

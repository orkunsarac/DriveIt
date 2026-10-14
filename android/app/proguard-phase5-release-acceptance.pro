# Keep only the native harness needed to execute Flutter's AOT integration
# acceptance APK. This rule file is selected only for the isolated release
# AndroidTest variant.
-keepattributes *Annotation*
-keep class androidx.test.runner.AndroidJUnitRunner { *; }
-keep class dev.flutter.plugins.integration_test.FlutterTestRunner { *; }
-keep class com.example.driveit_project.Phase5ReleaseAcceptanceTest { *; }
-keep class androidx.test.rule.ActivityTestRule { *; }

package com.example.driveit_project;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/** Runs the compiled Dart integration suite in the app's normal Activity. */
@RunWith(FlutterTestRunner.class)
public final class Phase5ReleaseAcceptanceTest {
  @Rule
  public ActivityTestRule<MainActivity> activityRule =
      new ActivityTestRule<>(MainActivity.class, true, false);
}

package dev.flutter.plugins.integration_test;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Regular release APKs do not ship the integration_test channel. Flutter's
 * generated registrant still references this class because the package is a
 * dev dependency, so this release-only no-op bridge satisfies registration
 * without packaging the test plugin. Isolated acceptance releases use the
 * actual integration_test dependency instead.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    // Intentionally no test channel in a normal release artifact.
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    // Nothing to detach.
  }
}

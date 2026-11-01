/// Fails closed if the Play application is ever configured for another project.
abstract final class SupabaseEnvironmentPolicy {
  static bool permits({required String applicationId, required String url}) {
    if (applicationId != 'com.osaracx.driveit') return true;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'arwnbogcswisfesayosy.supabase.co' &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}

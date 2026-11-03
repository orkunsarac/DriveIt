/// Strict DEV can be selected without changing an already installed binary.
abstract final class SupabaseEnvironmentPolicy {
  static bool permits({
    required String applicationId,
    required String url,
    bool strictDev = false,
  }) {
    final String host;
    if (applicationId == 'com.osaracx.driveit' && !strictDev) {
      host = 'arwnbogcswisfesayosy.supabase.co';
    } else if (strictDev &&
        (applicationId == 'com.example.driveit_project' ||
            applicationId == 'com.example.driveit_project.isolated_test')) {
      host = 'viqngnjfgknpxtoapzcg.supabase.co';
    } else {
      return !strictDev && applicationId == 'com.example.driveit_project';
    }
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == host &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}

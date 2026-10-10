import 'package:flutter/material.dart';
import '../services/local_owner_lifecycle.dart';
import 'local_owner_boundary.dart';

/// Put the Navigator INSIDE the epoch boundary: pushed detail/poster routes
/// must disappear with their owner, not remain above a replaced home screen.
/// Every route is explicitly registered and receives a revocable lease.
class LocalOwnerNavigator extends StatelessWidget {
  const LocalOwnerNavigator({
    super.key,
    required this.runtime,
    required this.legacyChild,
    required this.routes,
    this.initialRoute = '/',
  });
  final LocalOwnerLifecycle runtime;
  final Widget legacyChild;
  final Map<String, Widget Function(BuildContext, LocalOwnerLease, Object?)>
  routes;
  final String initialRoute;

  @override
  Widget build(BuildContext context) => LocalOwnerBoundary(
    runtime: runtime,
    legacyChild: legacyChild,
    personalBuilder: (context, lease) => Navigator(
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        final builder = routes[settings.name];
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            if (!lease.isCurrent || builder == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Kişisel veri erişimi hazır değil. Veriler korunuyor.',
                  ),
                ),
              );
            }
            return builder(context, lease, settings.arguments);
          },
        );
      },
    ),
  );
}

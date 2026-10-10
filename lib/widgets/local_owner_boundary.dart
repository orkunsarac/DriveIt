import 'package:flutter/material.dart';
import '../services/local_owner_lifecycle.dart';

/// Whole personal navigation subtree, not a row filter. The epoch key discards
/// old screens/controllers/map state. A blocked transition never renders child.
/// Only synthetic acceptance mounts this boundary until all providers are wired.
class LocalOwnerBoundary extends StatelessWidget {
  const LocalOwnerBoundary({
    super.key,
    required this.runtime,
    required this.personalBuilder,
    required this.legacyChild,
  });
  final LocalOwnerLifecycle runtime;
  final Widget Function(BuildContext, LocalOwnerLease) personalBuilder;
  final Widget legacyChild;
  @override
  Widget build(BuildContext context) {
    if (!runtime.gate.enabled) return legacyChild;
    return ListenableBuilder(
      listenable: runtime,
      builder: (context, _) {
        if (runtime.state == LocalOwnerState.ready) {
          return KeyedSubtree(
            key: ValueKey(runtime.epoch),
            child: Builder(
              builder: (context) => personalBuilder(context, runtime.lease),
            ),
          );
        }
        if (runtime.state == LocalOwnerState.preparing) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Text(
            runtime.errorCode == 'gps_owner_transition_blocked'
                ? 'Sürüş korunuyor. Hesap geçişinden önce mevcut sürüşü tamamla.'
                : 'Kişisel veriler şu anda açılamıyor. Veriler korunuyor.',
          ),
        );
      },
    );
  }
}

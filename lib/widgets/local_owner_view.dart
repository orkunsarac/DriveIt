import 'package:flutter/material.dart';
import '../services/local_owner_lifecycle.dart';

/// Revokes even a directly pushed route, not only the owner Navigator's home.
/// Build the personal child lazily: no storage/plugin read before validation.
class LocalOwnerView extends StatelessWidget {
  const LocalOwnerView({super.key, required this.lease, required this.builder});
  final LocalOwnerLease lease;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: lease.changes,
    builder: (context, _) => lease.isCurrent
        ? KeyedSubtree(
            key: ValueKey('${lease.owner.targetStore}:${lease.epoch}'),
            child: Builder(builder: builder),
          )
        : const OwnerAccessUnavailable(),
  );
}

class OwnerAccessUnavailable extends StatelessWidget {
  const OwnerAccessUnavailable({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
    ),
  );
}

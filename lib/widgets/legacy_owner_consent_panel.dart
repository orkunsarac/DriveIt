import 'package:flutter/material.dart';
import '../services/legacy_owner_consent.dart';

/// Not routed from production. No default selection and no implicit migration.
/// A production importer cannot be supplied until the complete copy contract
/// is proven; a quarantine preview therefore keeps approval disabled.
class LegacyOwnerConsentPanel extends StatefulWidget {
  const LegacyOwnerConsentPanel({
    super.key,
    required this.controller,
    required this.onApprove,
    required this.onSkip,
  });
  final LegacyOwnerConsentController controller;
  final Future<void> Function(LegacyOwnerConsent) onApprove;
  final VoidCallback onSkip;
  @override
  State<LegacyOwnerConsentPanel> createState() =>
      _LegacyOwnerConsentPanelState();
}

class _LegacyOwnerConsentPanelState extends State<LegacyOwnerConsentPanel> {
  bool _busy = false;
  bool _failed = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.runtime,
    builder: (context, _) {
      final controller = widget.controller;
      final preview = controller.preview;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Bu cihazda önceki sürümden kalan sürüş kayıtları bulundu.',
          ),
          Text('Sürüş sayısı: ${preview.driveCount}'),
          Text(
            preview.distanceKm == null
                ? 'Toplam mesafe bilinmiyor'
                : 'Toplam mesafe: ${preview.distanceKm!.toStringAsFixed(2)} km',
          ),
          Text('Dünya: ${preview.worldStatus}'),
          Text('Kariyer: ${preview.careerStatus}'),
          Text(
            'Hedef hesap: ${controller.destination.userId ?? "hesap gerekli"}',
          ),
          for (final issue in preview.unresolved) Text(issue),
          if (!controller.valid) const Text('Hesap değişti; bu onay geçersiz.'),
          if (!preview.canCopy)
            const Text(
              'Aktarım güvenliği henüz doğrulanmadı. Eski kayıtlar korunuyor.',
            ),
          if (_failed)
            const Text('Aktarım tamamlanmadı. Kaynak kayıtlar korunuyor.'),
          FilledButton(
            onPressed: _busy || !controller.valid || !preview.canCopy
                ? null
                : () async {
                    final consent = controller.approve();
                    setState(() {
                      _busy = true;
                      _failed = false;
                    });
                    try {
                      consent.verify(preview.manifestFingerprint);
                      await widget.onApprove(consent);
                      consent.verify(preview.manifestFingerprint);
                    } catch (_) {
                      if (mounted) setState(() => _failed = true);
                      // Never present this partial operation as completed. The durable
                      // importer, when implemented, must expose its retry manifest.
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Hazırlanıyor...' : 'Bu hesaba aktar'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    controller.skip();
                    widget.onSkip();
                  },
            child: const Text('Şimdilik geç'),
          ),
        ],
      );
    },
  );
}

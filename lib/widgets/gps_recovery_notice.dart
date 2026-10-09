import 'package:flutter/material.dart';
import '../services/gps_failure.dart';

/// No active-drive back guard, no stop/reset actions: leaving this view cannot
/// discard the journal or stop a real foreground recording.
class GpsRecoveryNotice extends StatelessWidget {
  const GpsRecoveryNotice({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onLeave,
    this.busy = false,
  });
  final GpsFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onLeave;
  final bool busy;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 44),
            const SizedBox(height: 16),
            const Text('Sürüş kurtarma', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Text(failure.id, key: const Key('gps-error-code')),
            const SizedBox(height: 8),
            Text(failure.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text(
              'Kayıtlar silinmez. Bu ekrandan çıkmak arka plan servisini durdurmaz. Yeni sürüş, durum doğrulanana kadar engellenir.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : onRetry,
              child: const Text('Tekrar Kontrol Et'),
            ),
            TextButton(
              onPressed: onLeave,
              child: const Text('Güvenli Bölümlere Dön'),
            ),
          ],
        ),
      ),
    ),
  );
}

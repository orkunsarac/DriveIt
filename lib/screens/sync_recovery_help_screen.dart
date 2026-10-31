import 'package:flutter/material.dart';

import '../services/local_owner_lifecycle.dart';
import '../widgets/local_owner_view.dart';

/// User-facing guidance for automatic sync failures. Technical manual tools
/// remain on the separate diagnostic route and are not exposed here.
class SyncRecoveryHelpScreen extends StatefulWidget {
  const SyncRecoveryHelpScreen({super.key, required this.lease});

  final LocalOwnerLease lease;

  @override
  State<SyncRecoveryHelpScreen> createState() => _SyncRecoveryHelpScreenState();
}

class _SyncRecoveryHelpScreenState extends State<SyncRecoveryHelpScreen> {
  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: widget.lease,
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Sürüş eşitleme yardımı')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.cloud_sync_outlined, size: 42),
          const SizedBox(height: 16),
          Text(
            widget.lease.cloudSyncNeedsHelp
                ? 'Sürüşler buluta henüz doğrulanarak aktarılamadı.'
                : 'Sürüş eşitlemesi için bekleyen bir hata görünmüyor.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            widget.lease.cloudSyncNeedsHelp
                ? 'Sürüş kayıtların bu cihazda korunur. Doğru hesapta oturum açtığını ve internet bağlantını kontrol et. DriveIt bağlantı uygun olduğunda otomatik yeniden dener.'
                : 'Bu ekranda bekleyen bir hata görünmüyor. Bulut yedeğinin tamamlandığı burada doğrulanmış sayılmaz.',
          ),
          if (widget.lease.cloudDownloadErrorCode ==
                  'owner_download_conflict' ||
              widget.lease.cloudSyncErrorCode ==
                  'owner_sync_retry_pending') ...[
            const SizedBox(height: 12),
            const Text(
              'Bazı kayıtlar otomatik olarak doğrulanamadı. Yerel kayıtlar korunuyor; destek alırken bu bilgi ve uygulama sürümünü paylaş.',
              key: Key('sync_help_validation_help'),
            ),
          ],
        ],
      ),
    ),
  );
}

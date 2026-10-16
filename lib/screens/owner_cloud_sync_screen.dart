import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/drive_session.dart';

import '../services/local_owner_lifecycle.dart';
import '../services/owner_drive_sync_client.dart';
import '../widgets/local_owner_view.dart';

/// Status view for automatic new-drive sync, with explicit recovery controls.
class OwnerCloudSyncScreen extends StatefulWidget {
  const OwnerCloudSyncScreen({super.key, required this.lease});
  final LocalOwnerLease lease;

  @override
  State<OwnerCloudSyncScreen> createState() => _OwnerCloudSyncScreenState();
}

class _OwnerCloudSyncScreenState extends State<OwnerCloudSyncScreen> {
  bool _busy = false;
  String _message = 'Bağlantı henüz kontrol edilmedi.';

  Future<void> _run(Future<String> Function() action) async {
    if (_busy || !widget.lease.isCurrent) return;
    setState(() {
      _busy = true;
      _message = 'İşlem sürüyor…';
    });
    try {
      final message = await action();
      if (mounted && widget.lease.isCurrent) setState(() => _message = message);
    } on OwnerSyncConflict catch (error) {
      if (mounted && widget.lease.isCurrent) {
        setState(
          () => _message =
              'Sunucu veya veri doğrulaması reddedildi (${error.code}). Yerel sürüş korundu.',
        );
      }
    } catch (_) {
      if (mounted && widget.lease.isCurrent) {
        setState(
          () => _message =
              'Bağlantı veya doğrulama tamamlanamadı. '
              'Yerel sürüşlerin korundu; yeniden deneyebilirsin.',
        );
      }
    } finally {
      if (mounted && widget.lease.isCurrent) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({required bool upload}) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(upload ? 'Tek sürüşü buluta yükle?' : 'Bir sayfa indir?'),
        content: Text(
          upload
              ? 'Yalnız seçtiğin hesap sürüşünün GPS rotası, telemetrisi ve mevcut detayları '
                    'DriveIt Planet DEV hesabına gönderilecek. Diğer sürüşler gönderilmez.'
              : 'Yalnız bu hesaba ait en fazla bir yeni sürüş indirilecek. Mevcut yerel '
                    'sürüşlerin üzerine yazılmaz. Bu işlem World/Career bulut aktarımı değildir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(upload ? 'Seçili Sürüşü Yükle' : 'İndir'),
          ),
        ],
      ),
    );
    return allowed == true && mounted && widget.lease.isCurrent;
  }

  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: widget.lease,
    builder: (_) {
      final available = widget.lease.manualCloudSyncAvailable;
      final List<({DriveSession drive, String? key, String state})> candidates;
      try {
        candidates = widget.lease.manualSyncCandidates();
      } catch (_) {
        return Scaffold(
          appBar: AppBar(title: const Text('Bulut Senkronizasyonu')),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Yerel sync kayıtları doğrulanamadı. Hiçbir veri gönderilmedi; sürüşlerin korunuyor.',
            ),
          ),
        );
      }
      final pending = candidates.where((c) => c.state != 'acknowledged').length;
      return Scaffold(
        appBar: AppBar(title: const Text('Bulut Senkronizasyonu')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Kontrollü M1 • Planet DEV',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yeni hesap sürüşleri önce bu cihaza kaydedilir, ardından otomatik ve sınırlı biçimde eşitlenir. Eski kayıtlar, Misafir ve Cihaz Arşivi sürüşleri onaysız gönderilmez.',
            ),
            const SizedBox(height: 8),
            Text(
              widget.lease.cloudDeletionEnabled
                  ? 'Bulut silme Sürüşlerim ekranında ayrı onay ister. Bekleyen silme sunucu onayına kadar tamamlanmış sayılmaz.'
                  : 'Silme yalnız bu cihazdadır; buluttan ve diğer cihazlardan silme henüz desteklenmiyor.',
            ),
            const SizedBox(height: 16),
            if (!available)
              const Text(
                'Gerçek hesabınla giriş yapmalısın. Hesap bağlantısı bu sürümde kullanılamıyorsa yeniden dene.',
              ),
            Text(
              'Bekleyen hesap sürüşü: $pending',
              key: const Key('cloud_pending_count'),
            ),
            Text(_message, key: const Key('cloud_sync_status')),
            if (widget.lease.cloudSyncErrorCode != null)
              const Text(
                'Senkronizasyon bekliyor. Yerel sürüş korunuyor; bağlantı veya oturum uygun olduğunda sınırlı yeniden deneme yapılacak.',
                key: Key('cloud_sync_retry_status'),
              ),
            if (_busy) const LinearProgressIndicator(),
            OutlinedButton(
              key: const Key('cloud_check_connection'),
              onPressed: !available || _busy
                  ? null
                  : () => _run(() async {
                      await widget.lease.checkManualCloudConnection();
                      return 'Planet DEV bağlantısı ve hesap yetkisi doğrulandı.';
                    }),
              child: const Text('Bağlantıyı Kontrol Et'),
            ),
            OutlinedButton(
              key: const Key('cloud_download_page'),
              onPressed: !available || _busy
                  ? null
                  : () async {
                      if (!await _confirm(upload: false)) return;
                      await _run(() async {
                        final result = await widget.lease
                            .downloadManualCloudPage();
                        return '${result.applied} yeni sürüş indirildi, ${result.duplicates} kayıt zaten mevcut. '
                            'Varsa sonraki sayfa için tekrar İndir seç.';
                      });
                    },
              child: const Text('Buluttan Bir Sayfa İndir'),
            ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Yüklenebilecek yeni ve doğrulanmış hesap sürüşü yok.',
                ),
              ),
            for (final candidate in candidates)
              Card(
                child: ListTile(
                  title: Text(
                    DateFormat(
                      'dd.MM.yyyy HH:mm',
                    ).format(candidate.drive.date.toLocal()),
                  ),
                  subtitle: Text(
                    '${(candidate.drive.distance / 1000).toStringAsFixed(2)} km • '
                    '${candidate.state == 'acknowledged'
                        ? 'Bulutta doğrulandı'
                        : candidate.state == 'deletionPending'
                        ? 'Bulut silme bekliyor; yükleme kapalı'
                        : candidate.state == 'ineligibleTelemetry'
                        ? 'Telemetri örneği yok; yalnız bu cihazda saklanır'
                        : candidate.state == 'conflict'
                        ? 'Çakışma; veri değiştirilmedi'
                        : candidate.state == 'sending'
                        ? 'Buluta yükleniyor'
                        : candidate.state == 'retryableFailure'
                        ? 'Senkronizasyon hatası; yeniden denenebilir'
                        : 'Senkronizasyon bekliyor'}',
                  ),
                  trailing: TextButton(
                    key: ValueKey('cloud_upload_${candidate.drive.id}'),
                    onPressed:
                        !available ||
                            _busy ||
                            candidate.state == 'conflict' ||
                            candidate.state == 'ineligibleTelemetry' ||
                            candidate.state == 'deletionPending'
                        ? null
                        : () async {
                            if (!await _confirm(upload: true)) return;
                            await _run(() async {
                              final ok = await widget.lease.uploadSelectedDrive(
                                candidate.drive.id,
                              );
                              return ok
                                  ? 'Seçili sürüş bulutta doğrulandı. Tekrar denemek çift kayıt oluşturmaz.'
                                  : 'Yükleme doğrulanamadı. Yerel sürüş korundu; bekleyen kaydı yeniden deneyebilirsin.';
                            });
                          },
                    child: Text(
                      candidate.state == 'acknowledged'
                          ? 'Durum'
                          : candidate.state == 'retryableFailure'
                          ? 'Yeniden Dene'
                          : 'Şimdi Eşitle',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

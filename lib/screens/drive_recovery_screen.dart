import 'package:flutter/material.dart';
import '../services/drive_recovery_status.dart';
import '../services/foreground_service.dart';
import '../services/gps_failure.dart';
import '../services/gps_session_store.dart';
import '../widgets/gps_recovery_notice.dart';
import 'map_screen.dart';

class DriveRecoveryScreen extends StatefulWidget {
  const DriveRecoveryScreen({
    super.key,
    this.initialStatus,
    this.allowNewDrive = false,
    this.loadStatus,
    this.loadSessions,
    this.selectSession,
  });
  final DriveRecoveryStatus? initialStatus;
  final bool allowNewDrive;
  final Future<DriveRecoveryStatus> Function()? loadStatus;
  final Future<List<GpsSession>> Function()? loadSessions;
  final Future<void> Function(String)? selectSession;
  @override
  State<DriveRecoveryScreen> createState() => _DriveRecoveryScreenState();
}

class _DriveRecoveryScreenState extends State<DriveRecoveryScreen> {
  DriveRecoveryStatus? _status;
  bool _busy = false;
  bool _openRecovered = false;
  List<GpsSession> _candidates = [];
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    if (_status == null) _check();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    var status =
        await (widget.loadStatus?.call() ??
            ForegroundService.inspectRecovery());
    try {
      _candidates = await (widget.loadSessions?.call() ?? _loadSessions());
    } catch (error) {
      status = DriveRecoveryStatus(
        DriveRecoveryKind.storageUnavailable,
        failure: GpsFailure.from(error, GpsErrorCode.recovery),
      );
    }
    if (mounted) {
      setState(() {
        _status = status;
        _busy = false;
      });
    }
  }

  Future<List<GpsSession>> _loadSessions() async =>
      (await ForegroundService.journal).recoverableSessions();

  Future<void> _choose(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.selectSession != null) {
        await widget.selectSession!(id);
      } else {
        await (await ForegroundService.journal).selectRecovery(id);
      }
      _openRecovered = false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              GpsFailure.from(error, GpsErrorCode.recovery).description,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _check();
  }

  Widget _sessionChoices() => Flexible(
    child: ListView(
      shrinkWrap: true,
      children: [
        for (final s in _candidates)
          ListTile(
            title: Text(
              s.state == 'stopped'
                  ? 'Kaydedilmemiş sürüş'
                  : 'Kesintiye uğramış sürüş',
            ),
            subtitle: Text('${s.startedAt}'),
            trailing: const Icon(Icons.restore),
            onTap: _busy ? null : () => _choose(s.id),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (status.hasVerifiedSession &&
        status.session?.state == 'stopped' &&
        !_openRecovered) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kaydedilmemiş sürüş')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sürüş durdurulmuş. GPS günlüğü korunuyor; yarım kalan kaydı güvenle tamamlayabilirsin.',
                ),
              ),
              FilledButton(
                onPressed: () => setState(() => _openRecovered = true),
                child: const Text('Kurtar ve Kaydet'),
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Şimdi değil — kayıtları koru'),
              ),
              if (_candidates.length > 1) _sessionChoices(),
              if (_candidates.isEmpty)
                TextButton(onPressed: _busy ? null : _check, child: const Text('Diğer kurtarılabilir sürüşleri kontrol et')),
            ],
          ),
        ),
      );
    }
    if (status.hasVerifiedSession ||
        (status.canStartNewDrive && widget.allowNewDrive)) {
      return MapScreen(resumeDrive: status.hasVerifiedSession);
    }
    if (status.canStartNewDrive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sürüş kurtarma')),
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Aktif sürüş bulunmadı. Ana ekrana dön'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Sürüş kurtarma')),
      body: Column(
        children: [
          Expanded(
            child: GpsRecoveryNotice(
              failure: status.failure ?? GpsFailure(GpsErrorCode.recovery),
              busy: _busy,
              onRetry: _check,
              onLeave: () => Navigator.maybePop(context),
            ),
          ),
          if (status.kind == DriveRecoveryKind.legacyPossible)
            SafeArea(
              top: false,
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _legacyPreview(status),
                ),
                child: Text(
                  'Eski Kaydı İncele (${status.legacyPoints.length} örnek)',
                ),
              ),
            ),
          if (_candidates.isNotEmpty) _sessionChoices(),
        ],
      ),
    );
  }

  Widget _legacyPreview(DriveRecoveryStatus status) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Eski sürüm kaydı — salt okunur. Yeni sürüşe eklenmez.',
            ),
          ),
          if (status.legacyPoints.isEmpty)
            const Text(
              'Kurtarılabilir nokta bulunamadı. Eski işaret değiştirilmedi.',
            ),
          Expanded(
            child: ListView.builder(
              itemCount: status.legacyPoints.length,
              itemBuilder: (_, i) {
                final row = status.legacyPoints[i];
                return ListTile(
                  title: Text('Örnek ${i + 1}'),
                  subtitle: Text(
                    'Zaman: ${row['time'] ?? row['timestamp'] ?? 'saklanmamış'}\nHız: ${row['speedMps'] ?? 'saklanmamış'} m/s',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

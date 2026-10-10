import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../models/drive_session.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../../../services/supabase_account_service.dart';
import '../services/world_publish_service.dart';
import '../widgets/drive_world_publish_section.dart';
import 'planet_segment.dart';
import 'planet_segment_outbox.dart';
import '../../my_world/repositories/world_source_snapshot_repository.dart';
import '../../../services/local_owner_lifecycle.dart';

/// Existing accepted/pending whole-drive publications keep their old recovery
/// UI. New candidates NEVER enter the legacy whole-drive submission service.
class PlanetPublicationSection extends StatefulWidget {
  const PlanetPublicationSection({
    super.key,
    required this.drive,
    this.record,
    this.existingLookup,
    this.outbox,
    this.ownerScope,
    this.publishService,
    this.ownerLease,
  });
  final DriveSession drive;
  final DriveTelemetryRecord? record;
  final Future<bool> Function()? existingLookup;
  final PlanetSegmentOutbox? outbox;
  final String? ownerScope;
  final WorldPublishService? publishService;
  final LocalOwnerLease? ownerLease;
  @override
  State<PlanetPublicationSection> createState() =>
      _PlanetPublicationSectionState();
}

class _PlanetPublicationSectionState extends State<PlanetPublicationSection> {
  bool? _existing;
  bool _failed = false, _busy = false;
  String? _message;
  PlanetSegmentPreview? _preview;
  late final LocalOwnerLease? _mountedOwner;
  bool get _ownerValid =>
      identical(widget.ownerLease, _mountedOwner) &&
      _mountedOwner?.isCurrent != false;
  DriveSession get _drive =>
      widget.ownerLease?.requireDrive(widget.drive.id) ?? widget.drive;
  String get _owner =>
      widget.ownerLease?.owner.targetStore ??
      widget.ownerScope ??
      SupabaseAccountService.instance.currentUser?.id ??
      'local-unassigned';
  PlanetSegmentOutbox? get _outbox => widget.ownerLease != null
      ? null
      : widget.outbox ??
            (Hive.isBoxOpen(PlanetSegmentOutbox.boxName)
                ? PlanetSegmentOutbox(
                    Hive.box<dynamic>(PlanetSegmentOutbox.boxName),
                  )
                : null);
  DriveTelemetryRecord? _telemetry() {
    if (widget.ownerLease case final lease?) return lease.telemetry(_drive.id);
    final record = widget.record ?? DriveTelemetryStorageService.get(_drive.id);
    if (record != null) return record;
    return Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName)
        ? WorldSourceSnapshotRepository(
            Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
          ).get(_drive.id)?.telemetry
        : null;
  }

  String _stateLabel(PlanetSegment s) {
    final lease = widget.ownerLease;
    final owned = lease
        ?.publicationEntries(_drive.id)
        .where((r) => (r['payload'] as Map)['id'] == s.id);
    final row = lease == null
        ? _outbox?.entry(_owner, s.id)
        : (owned!.isEmpty ? null : owned.first);
    return switch (row?['state']) {
      'queued' => 'Gönderim bekliyor — sunucu bağlantısı henüz etkin değil',
      'sending' => 'Gönderim sonucu belirsiz; sunucu durumu sorgulanmalı',
      'awaitingValidation' => 'Sunucu doğrulaması bekleniyor',
      'accepted' =>
        _outbox?.gateway.enabled == true
            ? 'Sunucu tarafından kabul edildi'
            : 'Yerel test durumu — gerçek Gezegen kabulü değildir',
      'rejected' => 'Sunucu tarafından reddedildi',
      'retryableFailure' => 'Yeniden denenebilir hata',
      _ => 'Hazır (yerel aday)',
    };
  }

  @override
  void initState() {
    super.initState();
    _mountedOwner = widget.ownerLease;
    widget.ownerLease?.changes.addListener(_ownerChanged);
    _load();
  }

  void _ownerChanged() {
    if (mounted) setState(() => _preview = null);
  }

  @override
  void dispose() {
    _mountedOwner?.changes.removeListener(_ownerChanged);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.ownerLease case final lease?) {
        lease.requireDrive(_drive.id);
        // No remote Auth/service fallback in the controlled scoped flow.
        if (mounted && lease.isCurrent) setState(() => _existing = false);
        return;
      }
      final service = widget.publishService ?? WorldPublishService();
      final existing = widget.existingLookup != null
          ? await widget.existingLookup!()
          : service.isAvailable && service.hasSession
          ? await service.getPublishForLocalDrive(_drive.id) != null
          : false;
      if (mounted && widget.ownerLease?.isCurrent != false) {
        setState(() => _existing = existing);
      }
    } catch (_) {
      if (mounted && widget.ownerLease?.isCurrent != false) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _prepare(PlanetSegmentPreview preview) async {
    if (_busy || !_ownerValid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yayın parçalarını hazırla'),
        content: Text(
          '${preview.eligible.length} uygun parça yerel kuyruğa hazırlanacak. '
          'Sunucuya gönderim henüz etkin değil; bu işlem Gezegen kabulü değildir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hazırla'),
          ),
        ],
      ),
    );
    if (!mounted || !_ownerValid || confirmed != true || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.ownerLease case final lease?) {
        await lease.preparePublication(_drive.id, preview.eligible);
      } else {
        final outbox = _outbox;
        if (outbox == null) throw StateError('Outbox unavailable');
        await outbox.prepare(_owner, preview.eligible);
      }
      if (mounted && widget.ownerLease?.isCurrent != false) {
        setState(
          () => _message =
              'Yayın için hazır — sunucu bağlantısı henüz etkin değil',
        );
      }
    } catch (_) {
      if (mounted && widget.ownerLease?.isCurrent != false) {
        setState(
          () => _message =
              'Yerel yayın kuyruğu kaydedilemedi. Veriler korunuyor; yeniden deneyebilirsin.',
        );
      }
    } finally {
      if (mounted && widget.ownerLease?.isCurrent != false) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ownerValid) {
      return const Text('Kişisel yayın durumu erişime kapalı.');
    }
    if (_failed) {
      return const Text(
        'Mevcut yayın durumu doğrulanamadı. Yeni yayın hazırlama durduruldu.',
      );
    }
    if (_existing == null) return const LinearProgressIndicator();
    if (_existing!) {
      return DriveWorldPublishSection(
        drive: _drive,
        publishService: widget.publishService,
        existingOnly: true,
      );
    }
    final preview = _preview ??= const PlanetSegmentBuilder().build(
      _drive.id,
      _telemetry(),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff091a31),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DriveIt Gezegeni — Yayın Durumu',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (preview.unavailableReason != null)
            Text(
              preview.unavailableReason!,
              style: const TextStyle(color: Colors.white70),
            ),
          Text(
            '${preview.segments.length} güvenilir parça',
            style: const TextStyle(color: Colors.white70),
          ),
          for (final s in preview.segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Parça ${s.order + 1} · ${(s.distanceMeters / 1000).toStringAsFixed(2)} km\n'
                '${s.reason ?? 'Yerel uygunluk sağlandı; sunucu doğrulaması bekleniyor.'}\n'
                'Drive Score: ${s.score?.toString() ?? 'Puanlanamadı (N/A)'}\n'
                '${s.eligible ? _stateLabel(s) : 'Yayına uygun değil'}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          Text(
            '${preview.eligible.length} uygun parça · ${(preview.eligibleDistance / 1000).toStringAsFixed(2)} km güvenilir ölçüm (nihai doğrulanmış mesafe değil)',
            style: const TextStyle(color: Colors.white70),
          ),
          const Text(
            'Yayın için hazır — sunucu bağlantısı henüz etkin değil',
            style: TextStyle(color: Colors.white70),
          ),
          FilledButton(
            onPressed: _busy || preview.eligible.isEmpty
                ? null
                : () => _prepare(preview),
            child: Text(_busy ? 'Hazırlanıyor…' : 'Uygun Parçaları Hazırla'),
          ),
          if (_message != null)
            Text(_message!, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

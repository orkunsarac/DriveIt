import 'package:flutter/material.dart';

import '../../../models/drive_session.dart';
import '../../my_world/config/my_world_rules.dart';
import '../models/world_publish.dart';
import '../services/world_publish_service.dart';
import '../services/world_publish_source_upload_service.dart';
import '../services/world_publish_processing_service.dart';
import '../services/world_publish_submission_service.dart';

class DriveWorldPublishSection extends StatefulWidget {
  const DriveWorldPublishSection({
    super.key,
    required this.drive,
    this.publishService,
    this.sourceUploadService,
    this.processingService,
  });

  final DriveSession drive;
  final WorldPublishService? publishService;
  final WorldPublishSourceUploadService? sourceUploadService;
  final WorldPublishProcessingService? processingService;

  @override
  State<DriveWorldPublishSection> createState() =>
      _DriveWorldPublishSectionState();
}

class _DriveWorldPublishSectionState extends State<DriveWorldPublishSection> {
  static const _blue = Color(0xff4e9fff);
  late WorldPublishService _service;
  late WorldPublishSubmissionService _submissionService;
  WorldPublish? _publish;
  bool _loading = true;
  bool _submitting = false;
  bool _processingAction = false;
  bool _lookupFailed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _service = widget.publishService ?? WorldPublishService();
    _submissionService = WorldPublishSubmissionService(
      publishService: _service,
      uploadService: widget.sourceUploadService,
      processingService: widget.processingService,
    );
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant DriveWorldPublishSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drive.id != widget.drive.id ||
        oldWidget.publishService != widget.publishService ||
        oldWidget.sourceUploadService != widget.sourceUploadService ||
        oldWidget.processingService != widget.processingService) {
      _service = widget.publishService ?? WorldPublishService();
      _submissionService = WorldPublishSubmissionService(
        publishService: _service,
        uploadService: widget.sourceUploadService,
        processingService: widget.processingService,
      );
      _publish = null;
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    if (!_service.isAvailable || !_service.hasSession) {
      if (mounted) {
        setState(() {
          _loading = false;
          _lookupFailed = false;
          _publish = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _lookupFailed = false;
      _message = null;
    });
    try {
      final publish = await _service.getPublishForLocalDrive(widget.drive.id);
      if (!mounted) return;
      setState(() {
        _publish = publish;
        _loading = false;
      });
    } on WorldPublishLookupException {
      if (mounted) {
        setState(() {
          _loading = false;
          _lookupFailed = true;
        });
      }
    }
  }

  Future<void> _confirmPublish() async {
    if (_submitting || _loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff091a31),
        title: const Text("DriveIt Gezegeni'ne yayınlansın mı?"),
        content: const Text(
          "Bu sürüşün rota verisi ortak DriveIt Gezegeni'ni oluşturmak için işlenecek. Sürüş kaydın cihazında kalmaya devam edecek.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yayınla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _publishDrive();
  }

  Future<void> _publishDrive({bool processingOnly = false}) async {
    if (_submitting || _loading) return;
    setState(() {
      _submitting = true;
      _processingAction = processingOnly;
      _message = null;
    });
    try {
      final result = processingOnly
          ? await _submissionService.processReadyPublishForDrive(
              widget.drive,
              onProcessingStarted: () {
                if (mounted) setState(() => _processingAction = true);
              },
            )
          : await _submissionService.submitDriveForPlanet(
              widget.drive,
              onProcessingStarted: () {
                if (mounted) setState(() => _processingAction = true);
              },
            );
      if (!mounted) return;
      if (result.publish != null) {
        setState(() => _publish = result.publish);
      }
      switch (result.status) {
        case WorldPublishSubmissionStatus.success:
        case WorldPublishSubmissionStatus.alreadyReady:
        case WorldPublishSubmissionStatus.processing:
        case WorldPublishSubmissionStatus.published:
        case WorldPublishSubmissionStatus.serverFailed:
          break;
        case WorldPublishSubmissionStatus.sourceNotReady:
          setState(() => _message = 'Yayın verisi henüz gönderilmedi.');
        case WorldPublishSubmissionStatus.processingRetryableFailure:
          setState(
            () => _message = 'İşleme başlatılamadı. Tekrar deneyebilirsin.',
          );
        case WorldPublishSubmissionStatus.processingPermanentFailure:
          setState(
            () => _message =
                'Bu sürüş doğrulanamadı. Daha sonra tekrar kontrol et.',
          );
        case WorldPublishSubmissionStatus.processingRefreshFailure:
          setState(
            () => _message =
                'İşleme sonucu yenilenemedi. Durumu tekrar kontrol et.',
          );
        case WorldPublishSubmissionStatus.notEligible:
          setState(
            () => _message = 'DriveIt Gezegeni için sürüş en az 5 km olmalı.',
          );
        case WorldPublishSubmissionStatus.notSignedIn:
          setState(
            () => _message =
                "DriveIt Gezegeni'ne yayınlamak için DriveIt hesabına giriş yap.",
          );
        case WorldPublishSubmissionStatus.supabaseUnavailable:
          setState(() => _message = 'Hesap hizmetine şu anda ulaşılamıyor.');
        case WorldPublishSubmissionStatus.invalidDrive:
          setState(() => _message = 'Sürüş kaydı doğrulanamadı.');
        case WorldPublishSubmissionStatus.missingCanonicalTelemetry:
          setState(() => _message = 'Sürüş telemetrisi bulunamadı.');
        case WorldPublishSubmissionStatus.invalidCanonicalTelemetry:
          setState(() => _message = 'Sürüş telemetrisi doğrulanamadı.');
        case WorldPublishSubmissionStatus.publishDriveMismatch:
          setState(() => _message = 'Yayın ve sürüş kaydı eşleşmiyor.');
        case WorldPublishSubmissionStatus.uploadFailure:
        case WorldPublishSubmissionStatus.attachFailure:
          setState(() => _message = 'Yayın verisi gönderilemedi.');
        case WorldPublishSubmissionStatus.lookupFailure:
        case WorldPublishSubmissionStatus.createFailure:
          setState(
            () => _message =
                'Yayın isteği gönderilemedi. Bağlantını kontrol edip tekrar dene.',
          );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Yayın isteği gönderilemedi. Bağlantını kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _status(IconData icon, String text, {Color color = _blue}) => Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _content() {
    if (!_service.isAvailable) {
      return _status(
        Icons.cloud_off_rounded,
        'Hesap hizmetine şu anda ulaşılamıyor.',
        color: Colors.white70,
      );
    }
    if (!_service.hasSession) {
      return _status(
        Icons.person_outline_rounded,
        "DriveIt Gezegeni'ne yayınlamak için DriveIt hesabına giriş yap.",
        color: Colors.white70,
      );
    }
    if (_loading || _submitting) {
      return Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
          ),
          const SizedBox(width: 12),
          Text(
            _submitting
                ? (_processingAction
                      ? 'DriveIt Gezegeni işleniyor...'
                      : 'Yayın verisi gönderiliyor...')
                : 'Yayın durumu kontrol ediliyor…',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }
    if (_lookupFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _status(
            Icons.cloud_off_rounded,
            'Yayın durumu alınamadı. Yeniden deneyebilirsin.',
            color: Colors.white70,
          ),
          TextButton(onPressed: _loadStatus, child: const Text('Yeniden Dene')),
        ],
      );
    }
    final publish = _publish;
    if (publish != null) {
      return switch (publish.status) {
        WorldPublishStatus.pending =>
          publish.sourceReady
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _status(Icons.hourglass_top_rounded, 'Yayın isteği alındı'),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('process_world_publish'),
                      onPressed: () => _publishDrive(processingOnly: true),
                      child: const Text('İşlemeyi Başlat'),
                    ),
                    if (_message != null)
                      Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xffff9c8e),
                          fontSize: 12,
                        ),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _status(
                      Icons.cloud_upload_outlined,
                      'Yayın verisi henüz gönderilmedi',
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('complete_world_publish_source'),
                      onPressed: _publishDrive,
                      child: const Text('Gönderimi Tamamla'),
                    ),
                    if (_message != null)
                      Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xffff9c8e),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
        WorldPublishStatus.processing => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _status(
              Icons.sync_rounded,
              "DriveIt Gezegeni'ne işleniyor",
            ),
            if (publish.sourceReady) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('resume_world_publish_processing'),
                onPressed: _submitting || _loading
                    ? null
                    : () => _publishDrive(processingOnly: true),
                child: const Text('İşlemeyi Sürdür'),
              ),
            ],
            if (_message != null)
              Text(
                _message!,
                style: const TextStyle(
                  color: Color(0xffff9c8e),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        WorldPublishStatus.published => _status(
          Icons.check_circle_outline_rounded,
          "DriveIt Gezegeni'nde",
          color: const Color(0xff4be0ca),
        ),
        WorldPublishStatus.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _status(
              Icons.error_outline_rounded,
              'Yayınlama işlenemedi',
              color: const Color(0xffff9c8e),
            ),
            if (publish.errorCode != null &&
                publish.errorCode!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Sürüş işlenirken bir sorun oluştu. Daha sonra durumu yeniden kontrol et.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      };
    }
    if (widget.drive.distance < MyWorldRules.minimumValidDistanceMeters) {
      return _status(
        Icons.info_outline_rounded,
        'Bu sürüş DriveIt Gezegeni için minimum 5 km şartını karşılamıyor.',
        color: Colors.white70,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('drive_world_publish_button'),
          onPressed: _confirmPublish,
          icon: const Icon(Icons.public_rounded, size: 19),
          label: const Text("DriveIt Gezegeni'ne Yayınla"),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff1765c5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: const TextStyle(color: Color(0xffff9c8e), fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('drive_world_publish_section'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff091a31),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff1b4779)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DriveIt Gezegeni',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _content(),
      ],
    ),
  );
}

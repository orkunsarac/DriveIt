import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/drive_session.dart';
import '../../services/drive_score_storage_service.dart';
import '../../services/drive_storage_service.dart';
import 'poster_background.dart';
import 'poster_canvas.dart';
import 'poster_layout.dart';
import 'poster_store.dart';
import 'drive_route_thumbnail.dart';

class PosterCenterScreen extends StatelessWidget {
  const PosterCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final drives = DriveStorageService.getAllDrives()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      backgroundColor: const Color(0xff020a18),
      appBar: AppBar(
        title: const Text('Sürüş Posteri'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SavedPostersScreen(),
              ),
            ),
            child: const Text('Posterlerim'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          const Text(
            'Poster oluşturmak için sürüş seçin',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          if (drives.isEmpty)
            const _PosterDriveEmptyState()
          else
            for (final drive in drives)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DriveSelectionCard(
                  drive: drive,
                  score: DriveScoreStorageService.get(
                    driveId: drive.id,
                  )?.totalScore,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PosterEditorScreen(drive: drive),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DriveSelectionCard extends StatefulWidget {
  const _DriveSelectionCard({
    required this.drive,
    required this.score,
    required this.onTap,
  });

  final DriveSession drive;
  final double? score;
  final VoidCallback onTap;

  @override
  State<_DriveSelectionCard> createState() => _DriveSelectionCardState();
}

class _DriveSelectionCardState extends State<_DriveSelectionCard> {
  late String _start = _fallbackEndpoint(widget.drive, true);
  late String _end = _fallbackEndpoint(widget.drive, false);

  @override
  void initState() {
    super.initState();
    _resolveNames();
  }

  Future<void> _resolveNames() async {
    if (widget.drive.route.isEmpty) return;
    try {
      final result = await PosterStore.channel
          .invokeMapMethod<String, String>('endpointNames', {
            'startLat': widget.drive.route.first.latitude,
            'startLng': widget.drive.route.first.longitude,
            'endLat': widget.drive.route.last.latitude,
            'endLng': widget.drive.route.last.longitude,
          })
          .timeout(const Duration(seconds: 6));
      if (!mounted || result == null) return;
      setState(() {
        _start = posterDistrict(result['start'] ?? _start);
        _end = posterDistrict(result['end'] ?? _end);
      });
    } catch (_) {
      // Coordinates remain a safe, immediately available fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final end = _end;
    return Material(
      color: const Color(0xff07172b),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0x22248fff),
        highlightColor: const Color(0x11248fff),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33248fff)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                height: 68,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: const Color(0xff041124),
                    child: DriveRouteThumbnail(route: widget.drive.route),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$start → $end',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd.MM.yyyy').format(widget.drive.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff9db0c9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(widget.drive.distance / 1000).toStringAsFixed(1)} km • ${posterDuration(widget.drive.durationSeconds)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xffc9d8eb),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.score?.toStringAsFixed(0) ?? '—',
                      style: const TextStyle(
                        color: Color(0xff59d9ff),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '/1000',
                      style: TextStyle(color: Color(0xff8298b5), fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xff6f8aa9)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterDriveEmptyState extends StatelessWidget {
  const _PosterDriveEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
    child: Column(
      children: const [
        Icon(Icons.alt_route, size: 48, color: Color(0xff59d9ff)),
        SizedBox(height: 16),
        Text(
          'Henüz poster oluşturabileceğin bir sürüş yok.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xffb7c8de), fontSize: 15),
        ),
      ],
    ),
  );
}

String _endpoint(DriveSession drive, bool start) {
  if (drive.route.isEmpty) return start ? 'Başlangıç' : 'Bitiş';
  final point = start ? drive.route.first : drive.route.last;
  return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
}

String _fallbackEndpoint(DriveSession drive, bool start) {
  final value = posterDistrict(_endpoint(drive, start));
  return value == '—' ? (start ? 'Başlangıç' : 'Bitiş') : value;
}

Future<void> offerDrivePoster(BuildContext context, DriveSession drive) async {
  final create = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xff091b30),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: posterBlue, size: 32),
            const SizedBox(height: 16),
            const Text(
              'Bu sürüş için poster oluşturmak ister misiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Poster Oluştur'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Daha Sonra'),
            ),
          ],
        ),
      ),
    ),
  );
  if (create == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PosterEditorScreen(drive: drive)),
    );
  }
}

enum _PosterEditorStage { background, preview }

class PosterEditorScreen extends StatefulWidget {
  const PosterEditorScreen({
    super.key,
    required this.drive,
    this.backgroundGenerator = const UnconfiguredPosterBackgroundGenerator(),
    this.savedPoster,
    this.savedBackgroundPath,
  });
  final DriveSession drive;
  final PosterBackgroundGenerator backgroundGenerator;
  final SavedDrivePoster? savedPoster;
  final String? savedBackgroundPath;

  @override
  State<PosterEditorScreen> createState() => _PosterEditorScreenState();
}

class _PosterEditorScreenState extends State<PosterEditorScreen> {
  late final _start = TextEditingController(
    text: _endpoint(widget.drive, true),
  );
  late final _end = TextEditingController(text: _endpoint(widget.drive, false));
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _picker = ImagePicker();
  _PosterEditorStage _stage = _PosterEditorStage.background;
  PosterScenePreset _scene = PosterScenePreset.nightCoastalRoad;
  PosterBackgroundSourceType? _sourceType;
  PosterBackgroundRequest? _aiRequest;
  PosterStore? _posterStore;
  SavedDrivePoster? _saved;
  String? _backgroundPath;
  String? _error;
  bool _busy = false;
  bool _showMaxSpeed = true;
  bool _showLocation = true;
  bool _showDate = true;
  bool _showScore = true;
  bool _showRoute = true;
  bool _routeSelected = true;
  bool _gestureActive = false;
  late PosterLayout _layout;

  @override
  void initState() {
    super.initState();
    _layout =
        widget.savedPoster?.layout ??
        automaticPosterLayout(projectPosterRoute(widget.drive.route));
    final saved = widget.savedPoster;
    if (saved != null && widget.savedBackgroundPath != null) {
      _start.text = saved.startLabel;
      _end.text = saved.endLabel;
      _showMaxSpeed = saved.showMaxSpeed;
      _showLocation = saved.showLocation;
      _showDate = saved.showDate;
      _showScore = saved.showScore;
      _showRoute = saved.showRoute;
      _routeSelected = saved.showRoute;
      _sourceType = saved.backgroundSourceType;
      _backgroundPath = widget.savedBackgroundPath;
      _stage = _PosterEditorStage.preview;
    } else {
      _resolveNames();
      _recoverPhoto();
    }
  }

  Future<void> _recoverPhoto() async {
    if (!Platform.isAndroid) return;
    try {
      final lost = await _picker.retrieveLostData();
      if (!mounted || lost.files?.isNotEmpty != true) return;
      setState(() {
        _backgroundPath = lost.files!.first.path;
        _sourceType = PosterBackgroundSourceType.customImage;
      });
    } catch (_) {
      // Background selection remains available.
    }
  }

  Future<void> _resolveNames() async {
    if (widget.drive.route.isEmpty) return;
    final initialStart = _start.text;
    final initialEnd = _end.text;
    try {
      final result = await PosterStore.channel
          .invokeMapMethod<String, String>('endpointNames', {
            'startLat': widget.drive.route.first.latitude,
            'startLng': widget.drive.route.first.longitude,
            'endLat': widget.drive.route.last.latitude,
            'endLng': widget.drive.route.last.longitude,
          })
          .timeout(const Duration(seconds: 8));
      if (!mounted || result == null) return;
      if (_start.text == initialStart && result['start']?.isNotEmpty == true) {
        _start.text = posterDistrict(result['start']!);
      }
      if (_end.text == initialEnd && result['end']?.isNotEmpty == true) {
        _end.text = posterDistrict(result['end']!);
      }
    } catch (_) {
      // Real coordinates remain as the safe fallback.
    }
  }

  Future<void> _pickBackground(PosterBackgroundSourceType source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 4267,
        imageQuality: 96,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
        compressQuality: 96,
        maxWidth: 1440,
        maxHeight: 2560,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: source == PosterBackgroundSourceType.vehiclePhoto
                ? 'Araç fotoğrafını konumlandır'
                : 'Poster arka planını konumlandır',
            toolbarColor: const Color(0xff091b30),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: posterBlue,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: '9:16 arka planı konumlandır'),
        ],
      );
      if (!mounted || cropped == null) return;
      setState(() {
        _backgroundPath = cropped.path;
        _sourceType = source;
        _aiRequest = null;
        _stage = _PosterEditorStage.preview;
        _saved = null;
      });
    } catch (_) {
      setState(() {
        _error = 'Görsel seçilemedi. Yeniden deneyin.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PosterBackgroundRequest? _buildAiRequest() {
    if ([
      _brand,
      _model,
      _year,
      _color,
    ].any((field) => field.text.trim().isEmpty)) {
      setState(
        () => _error = 'Marka, model, model yılı ve renk alanlarını doldurun.',
      );
      return null;
    }
    return PosterBackgroundRequest(
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      year: _year.text.trim(),
      color: _color.text.trim(),
      scene: _scene,
    );
  }

  Future<void> _generateAiBackground() async {
    final request = _buildAiRequest();
    if (request == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.backgroundGenerator.generate(request);
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(
          () => _error = result.errorMessage ?? 'Arka plan üretilemedi.',
        );
        return;
      }
      setState(() {
        _backgroundPath = result.imagePath;
        _sourceType = PosterBackgroundSourceType.aiGenerated;
        _aiRequest = request;
        _stage = _PosterEditorStage.preview;
        _saved = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'AI arka plan üretilemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PosterCanvas _canvas({bool editing = false}) => PosterCanvas(
    drive: widget.drive,
    score: DriveScoreStorageService.get(driveId: widget.drive.id)?.totalScore,
    startName: _start.text.trim().isEmpty
        ? _endpoint(widget.drive, true)
        : _start.text.trim(),
    endName: _end.text.trim().isEmpty
        ? _endpoint(widget.drive, false)
        : _end.text.trim(),
    showMaxSpeed: _showMaxSpeed,
    showLocation: _showLocation,
    showDate: _showDate,
    showScore: _showScore,
    showRoute: _showRoute,
    backgroundPath: _backgroundPath!,
    layout: _layout,
    selectedElement: editing && _showRoute && _routeSelected
        ? PosterElement.route
        : null,
    onTransform: editing && !_busy
        ? (element, transform) {
            if (element != PosterElement.route) return;
            _draftChanged(() {
              _layout = PosterLayout(score: _layout.score, route: transform);
            });
          }
        : null,
    onInteraction: editing
        ? (active) {
            _gestureActive = active;
          }
        : null,
    onRouteTap: editing && _showRoute
        ? () {
            if (!_routeSelected) setState(() => _routeSelected = true);
          }
        : null,
    onCanvasTap: editing && _routeSelected
        ? () => setState(() => _routeSelected = false)
        : null,
  );

  Future<ui.Image> _renderPosterImage() async {
    if (!mounted || _backgroundPath == null) throw StateError('Arka plan yok');
    debugPrint(
      '[POSTER_SAVE] render.start driveId=${widget.drive.id} '
      'background=$_backgroundPath target=1080x1920',
    );
    await precacheImage(FileImage(File(_backgroundPath!)), context);
    debugPrint('[POSTER_SAVE] render.backgroundReady');
    if (!mounted) throw StateError('Poster ekranı kapandı');
    await precacheImage(
      const AssetImage('assets/branding/driveit_logo_current.png'),
      context,
    );
    debugPrint('[POSTER_SAVE] render.logoReady');
    if (!mounted) throw StateError('Poster ekranı kapandı');
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: posterSize.width,
        height: posterSize.height,
        child: IgnorePointer(
          child: Opacity(
            // Values below 1/255 round to a zero alpha layer, so Flutter skips
            // painting the child and RenderRepaintBoundary.toImage fails.
            opacity: 0.01,
            child: RepaintBoundary(
              key: key,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: _canvas(),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      late RenderRepaintBoundary boundary;
      for (var attempt = 1; attempt <= 8; attempt++) {
        // Overlay insertion and image-stream listeners may request another
        // paint after the current frame. Capture only after the boundary has
        // remained paint-clean at the end of an explicitly scheduled frame.
        final painted = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) => painted.complete());
        WidgetsBinding.instance.scheduleFrame();
        await painted.future;
        boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        if (!boundary.debugNeedsPaint) break;
        debugPrint('[POSTER_SAVE] render.awaitPaint attempt=$attempt');
        if (attempt == 8) {
          throw StateError('Poster canvas paint aşamasını tamamlayamadı.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      debugPrint('[POSTER_SAVE] render.boundary size=${boundary.size}');
      final image = await boundary.toImage(pixelRatio: 3);
      debugPrint(
        '[POSTER_SAVE] render.imageReady width=${image.width} '
        'height=${image.height}',
      );
      return image;
    } finally {
      entry.remove();
    }
  }

  Future<SavedDrivePoster> _ensureSaved() async {
    if (_saved != null) {
      debugPrint('[POSTER_SAVE] reuse id=${_saved!.id}');
      return _saved!;
    }
    final png = await _renderPosterPng();
    final store = _posterStore ??= await PosterStore.open();
    debugPrint(
      '[POSTER_SAVE] store.open directory=${store.directory.path} '
      'boxOpen=${store.box.isOpen}',
    );
    final saved = await store.save(
      PosterSaveRequest(
        driveId: widget.drive.id,
        png: png,
        backgroundSourceType: _sourceType!,
        backgroundPath: _backgroundPath,
        aiVehicle: _aiRequest?.toMap() ?? widget.savedPoster?.aiVehicle,
        startLabel: _start.text.trim(),
        endLabel: _end.text.trim(),
        showMaxSpeed: _showMaxSpeed,
        showLocation: _showLocation,
        showDate: _showDate,
        showScore: _showScore,
        showRoute: _showRoute,
        layout: _layout,
      ),
    );
    debugPrint(
      '[POSTER_SAVE] complete id=${saved.id} '
      'path=${store.file(saved).path} hive=${store.box.containsKey(saved.id)}',
    );
    _saved = saved;
    return saved;
  }

  Future<Uint8List> _renderPosterPng() async {
    final image = await _renderPosterImage();
    try {
      debugPrint(
        '[POSTER_SAVE] png.encode.start width=${image.width} '
        'height=${image.height}',
      );
      if (image.width != 1080 || image.height != 1920) {
        throw StateError(
          'Poster render boyutu geçersiz: ${image.width}x${image.height}',
        );
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Poster PNG ByteData üretilemedi.');
      }
      debugPrint('[POSTER_SAVE] png.byteData.done bytes=${data.lengthInBytes}');
      final png = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (png.isEmpty) throw StateError('Poster PNG byte verisi boş.');
      debugPrint('[POSTER_SAVE] png.encode.done bytes=${png.length}');
      return png;
    } finally {
      image.dispose();
    }
  }

  Future<void> _performSaved(
    String failureMessage,
    Future<void> Function(PosterStore, SavedDrivePoster) action,
  ) async {
    setState(() => _busy = true);
    try {
      final poster = await _ensureSaved();
      final store = _posterStore ??= await PosterStore.open();
      await action(store, poster);
    } catch (error, stackTrace) {
      debugPrint('[POSTER_SAVE] failed error=$error');
      debugPrintStack(label: '[POSTER_SAVE] stack', stackTrace: stackTrace);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'drive_poster',
          context: ErrorDescription('while saving or exporting a poster'),
        ),
      );
      _message(failureMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveGallery() async {
    setState(() => _busy = true);
    try {
      final png = await _renderPosterPng();
      final store = _posterStore ??= await PosterStore.open();
      final uri = await store.savePngToGallery(png);
      debugPrint('[POSTER_SAVE] gallery.success uri=$uri');
      _message('Poster galeriye kaydedildi.');
    } catch (error, stackTrace) {
      debugPrint('[POSTER_SAVE] gallery.failed error=$error');
      debugPrintStack(
        label: '[POSTER_SAVE] gallery.stack',
        stackTrace: stackTrace,
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'drive_poster',
          context: ErrorDescription('while saving a poster to MediaStore'),
        ),
      );
      _message('Galeriye kaydedilemedi. Yeniden deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _draftChanged(VoidCallback change) {
    setState(() {
      change();
      _saved = null;
    });
  }

  @override
  void dispose() {
    for (final controller in [_start, _end, _brand, _model, _year, _color]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff020a18),
    appBar: AppBar(title: const Text('Sürüş Posteri')),
    body: SafeArea(
      child: _stage == _PosterEditorStage.background
          ? _backgroundStep()
          : _previewStep(),
    ),
  );

  Widget _backgroundStep() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Arkaplan Seç',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'DriveIt verileri ve gerçek rota, seçtiğiniz görselin üzerine uygulama tarafından eklenecek.',
      ),
      const SizedBox(height: 20),
      _backgroundChoice(
        Icons.wallpaper_outlined,
        'Kendi Görselimi Kullan',
        'Galeriden 9:16 poster arka planı seçin.',
        () => _pickBackground(PosterBackgroundSourceType.customImage),
      ),
      _backgroundChoice(
        Icons.directions_car_outlined,
        'Araç Fotoğrafımı Kullan',
        'Araç fotoğrafından AI arkaplan üretimi yakında.',
        _vehiclePhotoComingSoon,
        enabled: false,
        badge: 'Yakında',
      ),
      const SizedBox(height: 12),
      _aiPanel(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xffff7b8d)),
          ),
        ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: LinearProgressIndicator(),
        ),
    ],
  );

  Widget _backgroundChoice(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool enabled = true,
    String? badge,
  }) => Card(
    child: ListTile(
      leading: Icon(
        icon,
        color: enabled ? const Color(0xff63dcff) : const Color(0xff60748d),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.white : const Color(0xffa0afc2),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: enabled ? null : const Color(0xff71849d)),
      ),
      trailing: badge == null
          ? const Icon(Icons.chevron_right)
          : Chip(
              label: Text(badge),
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(
                color: Color(0xff9baec5),
                fontSize: 11,
              ),
              backgroundColor: const Color(0xff17263b),
              side: BorderSide.none,
            ),
      // Keep the row tappable so the user gets a short explanation, while
      // avoiding any picker/navigation for the future vehicle-photo flow.
      enabled: true,
      onTap: _busy ? null : onTap,
    ),
  );

  void _vehiclePhotoComingSoon() =>
      _message('Araç fotoğrafından AI arkaplan üretimi yakında.');

  Widget _aiPanel() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xaa07182b),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff315b86)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xff9d7cff)),
            SizedBox(width: 9),
            Text(
              'AI ile Arkaplan Oluştur',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _field(_brand, 'Marka')),
            const SizedBox(width: 10),
            Expanded(child: _field(_model, 'Model')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field(_year, 'Model yılı', number: true)),
            const SizedBox(width: 10),
            Expanded(child: _field(_color, 'Renk')),
          ],
        ),
        DropdownButtonFormField<PosterScenePreset>(
          initialValue: _scene,
          decoration: const InputDecoration(labelText: 'Sahne tipi'),
          items: PosterScenePreset.values
              .map(
                (scene) =>
                    DropdownMenuItem(value: scene, child: Text(scene.label)),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (scene) => setState(() => _scene = scene ?? _scene),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _generateAiBackground,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Arkaplan Oluştur'),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) => TextField(
    controller: controller,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label),
  );

  Widget _previewStep() => ListView(
    key: const ValueKey('poster_editor_scroll'),
    physics: _RouteEditingScrollPhysics(() => _gestureActive),
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Önizleme',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      AspectRatio(
        aspectRatio: 9 / 16,
        child: Listener(
          onPointerDown: (_) => _gestureActive = true,
          onPointerUp: (_) => _gestureActive = false,
          onPointerCancel: (_) => _gestureActive = false,
          child: FittedBox(fit: BoxFit.contain, child: _canvas(editing: true)),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Rota'),
            selected: _showRoute,
            onSelected: _busy
                ? null
                : (visible) => _draftChanged(() {
                    _showRoute = visible;
                    if (!visible) _routeSelected = false;
                  }),
          ),
        ],
      ),
      const Text('Seçili öğeyi sürükleyin veya iki parmakla ölçekleyin.'),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _busy
                ? null
                : () => _draftChanged(
                    () => _layout = automaticPosterLayout(
                      projectPosterRoute(widget.drive.route),
                    ),
                  ),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
      TextField(
        controller: _start,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Başlangıç'),
        onChanged: (_) => _draftChanged(() {}),
      ),
      TextField(
        controller: _end,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Bitiş'),
        onChanged: (_) => _draftChanged(() {}),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Maksimum hızı göster'),
        value: _showMaxSpeed,
        onChanged: _busy
            ? null
            : (value) => _draftChanged(() => _showMaxSpeed = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Lokasyon bilgisini göster'),
        value: _showLocation,
        onChanged: _busy
            ? null
            : (value) => _draftChanged(() => _showLocation = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Tarihi göster'),
        value: _showDate,
        onChanged: _busy
            ? null
            : (value) => _draftChanged(() => _showDate = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Drive Score göster'),
        value: _showScore,
        onChanged: _busy
            ? null
            : (value) => _draftChanged(() => _showScore = value),
      ),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => setState(() => _stage = _PosterEditorStage.background),
        icon: const Icon(Icons.wallpaper_outlined),
        label: Text(
          _sourceType == PosterBackgroundSourceType.aiGenerated
              ? 'Farklı arkaplan seç / yeniden AI üret'
              : 'Farklı arkaplan seç',
        ),
      ),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _performSaved(
                'Posterlerim’e kaydedilemedi. Yeniden deneyin.',
                (_, _) async => _message('Posterlerim’e kaydedildi.'),
              ),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: const Text('Posterlerime Kaydet'),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _saveGallery,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Galeriye Kaydet'),
      ),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _performSaved(
                'Poster paylaşılamadı. Yeniden deneyin.',
                (store, poster) => store.share(poster),
              ),
        icon: const Icon(Icons.share_outlined),
        label: const Text('Paylaş'),
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: LinearProgressIndicator(),
        ),
    ],
  );
}

class _RouteEditingScrollPhysics extends AlwaysScrollableScrollPhysics {
  const _RouteEditingScrollPhysics(
    this.isRouteInteractionActive, {
    super.parent,
  });

  final bool Function() isRouteInteractionActive;

  @override
  bool get allowUserScrolling => !isRouteInteractionActive();

  @override
  _RouteEditingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _RouteEditingScrollPhysics(
        isRouteInteractionActive,
        parent: buildParent(ancestor),
      );
}

class SavedPostersScreen extends StatefulWidget {
  const SavedPostersScreen({super.key, this.store});
  final Future<PosterStore>? store;
  @override
  State<SavedPostersScreen> createState() => _SavedPostersScreenState();
}

class _SavedPostersScreenState extends State<SavedPostersScreen> {
  late final Future<PosterStore> _store = widget.store ?? PosterStore.open();

  Future<void> _confirmDelete(
    PosterStore store,
    SavedDrivePoster poster,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff07152b),
        title: const Text('Posteri silmek istiyor musunuz?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffc62855),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await store.delete(poster);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Poster silindi')));
    } catch (error, stackTrace) {
      debugPrint('[POSTER_DELETE] ui.failed id=${poster.id} error=$error');
      debugPrintStack(
        label: '[POSTER_DELETE] ui.stack',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poster silinemedi. Tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff020a18),
    appBar: AppBar(title: const Text('Posterlerim')),
    body: FutureBuilder<PosterStore>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Posterler yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final store = snapshot.data!;
        final posters = store.all;
        if (posters.isEmpty) {
          return const Center(child: Text('Henüz kaydedilmiş poster yok.'));
        }
        return ListView.builder(
          itemCount: posters.length,
          itemBuilder: (context, index) {
            final poster = posters[index];
            return ListTile(
              leading: Image.file(
                store.file(poster),
                width: 44,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
              title: Text(
                DateFormat('dd.MM.yyyy · HH:mm').format(poster.createdAt),
              ),
              subtitle: Text(
                '${poster.backgroundSourceType.name} · Sürüş ${poster.driveId}',
              ),
              trailing: IconButton(
                key: ValueKey('poster_delete_${poster.id}'),
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xffaab8d5),
                onPressed: () => _confirmDelete(store, poster),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _SavedPosterViewer(store: store, poster: poster),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _SavedPosterViewer extends StatelessWidget {
  const _SavedPosterViewer({required this.store, required this.poster});
  final PosterStore store;
  final SavedDrivePoster poster;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff020a18),
    appBar: AppBar(
      title: const Text('Sürüş Posteri'),
      actions: [
        if (poster.backgroundFileName != null)
          TextButton(
            child: const Text('Düzenle'),
            onPressed: () async {
              final drives = DriveStorageService.getAllDrives().where(
                (drive) => drive.id == poster.driveId,
              );
              final path =
                  '${store.directory.path}/${poster.backgroundFileName}';
              if (drives.isEmpty || !await File(path).exists()) return;
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PosterEditorScreen(
                    drive: drives.first,
                    savedPoster: poster,
                    savedBackgroundPath: path,
                  ),
                ),
              );
            },
          ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: InteractiveViewer(child: Image.file(store.file(poster))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final uri = await store.saveToGallery(poster);
                        debugPrint(
                          '[POSTER_SAVE] savedViewer.gallery.success uri=$uri',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Poster galeriye kaydedildi.'),
                            ),
                          );
                        }
                      } catch (error, stackTrace) {
                        debugPrint(
                          '[POSTER_SAVE] savedViewer.gallery.failed error=$error',
                        );
                        debugPrintStack(
                          label: '[POSTER_SAVE] savedViewer.gallery.stack',
                          stackTrace: stackTrace,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Galeriye kaydedilemedi.'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await store.share(poster);
                      } catch (error, stackTrace) {
                        debugPrint(
                          '[POSTER_SAVE] savedViewer.share.failed error=$error',
                        );
                        debugPrintStack(
                          label: '[POSTER_SAVE] savedViewer.share.stack',
                          stackTrace: stackTrace,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Poster paylaşılamadı.'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Paylaş'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

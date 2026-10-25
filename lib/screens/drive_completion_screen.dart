import 'package:flutter/material.dart';

import '../features/drive_poster/poster_screens.dart';
import '../models/drive_session.dart';
import '../services/drive_storage_service.dart';
import '../services/local_owner_lifecycle.dart';
import '../widgets/local_owner_view.dart';
import 'drive_detail_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';

/// Reached only after the recorder has checked the VERIFIED journal receipt.
/// No save operation or poster generation is performed by this screen.
class DriveCompletionScreen extends StatefulWidget {
  const DriveCompletionScreen({
    super.key,
    required this.driveId,
    this.ownerLease,
  });

  final String driveId;
  final LocalOwnerLease? ownerLease;

  @override
  State<DriveCompletionScreen> createState() => _DriveCompletionScreenState();
}

class _DriveCompletionScreenState extends State<DriveCompletionScreen> {
  bool _opening = false;

  DriveSession _drive() {
    final lease = widget.ownerLease;
    if (lease != null) return lease.requireDrive(widget.driveId);
    final drive = DriveStorageService.getDrive(widget.driveId);
    if (drive == null) throw StateError('Saved drive unavailable');
    return drive;
  }

  void _home() {
    widget.ownerLease?.requireCurrent();
    final navigator = Navigator.of(context);
    if (widget.ownerLease != null) {
      navigator.pushNamedAndRemoveUntil('/', (_) => false);
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  void _newDrive() {
    widget.ownerLease?.requireCurrent();
    if (widget.ownerLease != null) {
      Navigator.of(context).pushReplacementNamed('/drive');
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MapScreen()),
      );
    }
  }

  Future<void> _open({required bool poster}) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final drive = _drive();
      final lease = widget.ownerLease;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => poster
              ? PosterEditorScreen(drive: drive, ownerLease: lease)
              : lease == null
              ? DriveDetailScreen(drive: drive)
              : OwnedDriveDetailScreen(lease: lease, driveId: drive.id),
        ),
      );
    } catch (_) {
      if (mounted && (widget.ownerLease?.isCurrent ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${poster ? 'Poster' : 'Sürüş detay'} ekranı açılamadı. Sürüşün kayıtlı.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _body(BuildContext context) {
    final drive = _drive();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_opening) _home();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff0a1830),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xff50e4cb),
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sürüş Kaydedildi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sürüşün başarıyla kaydedildi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(drive.distance / 1000).toStringAsFixed(2)} km · '
                          '${drive.durationSeconds ~/ 60} dk · ${drive.averageSpeed.toStringAsFixed(1)} km/sa',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        _button(
                          'ANA EKRAN',
                          Icons.home_outlined,
                          _home,
                          'drive_complete_home',
                        ),
                        _button(
                          'YENİ SÜRÜŞ',
                          Icons.play_arrow,
                          _newDrive,
                          'drive_complete_new',
                        ),
                        _button(
                          'SÜRÜŞÜ İNCELE',
                          Icons.route_outlined,
                          () => _open(poster: false),
                          'drive_complete_detail',
                        ),
                        _button(
                          'SÜRÜŞ POSTERİ OLUŞTUR',
                          Icons.auto_awesome,
                          () => _open(poster: true),
                          'drive_complete_poster',
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    String label,
    IconData icon,
    VoidCallback action,
    String key, {
    bool emphasized = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        key: Key(key),
        onPressed: _opening ? null : action,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          foregroundColor: Colors.white,
          backgroundColor: emphasized
              ? const Color(0xff245aa5)
              : const Color(0xff172a45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.center),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => widget.ownerLease == null
      ? _body(context)
      : LocalOwnerView(lease: widget.ownerLease!, builder: _body);
}

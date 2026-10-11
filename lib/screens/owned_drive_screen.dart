import 'package:flutter/material.dart';
import '../services/local_owner_lifecycle.dart';
import '../services/foreground_service.dart';
import '../services/drive_recovery_status.dart';
import '../widgets/local_owner_view.dart';
import 'drive_recovery_screen.dart';
import 'map_screen.dart';

/// Gate-open composition only. Uses the actual map/start/recovery/summary UI;
/// missing foreground attachment is an error, never a shared-store fallback.
class OwnedDriveScreen extends StatefulWidget {
  const OwnedDriveScreen({super.key, required this.lease});
  final LocalOwnerLease lease;
  @override
  State<OwnedDriveScreen> createState() => _OwnedDriveScreenState();
}

class _OwnedDriveScreenState extends State<OwnedDriveScreen> {
  late Future<DriveRecoveryStatus> _status;
  bool _repairing = false;
  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  Future<DriveRecoveryStatus> _load() async {
    ForegroundService.requireOwnerLease(widget.lease);
    final status = await ForegroundService.inspectRecovery();
    ForegroundService.requireOwnerLease(widget.lease);
    return status;
  }

  Future<void> _repair() async {
    if (_repairing) return;
    setState(() => _repairing = true);
    try {
      await ForegroundService.reconcileOwnerSaves(widget.lease);
      if (mounted && widget.lease.isCurrent) setState(() => _status = _load());
    } catch (_) {
      if (mounted && widget.lease.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kayıt tamamlanamadı. GPS günlüğü ve hesap verileri korunuyor.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: widget.lease,
    builder: (_) => FutureBuilder<DriveRecoveryStatus>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const OwnerAccessUnavailable();
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (widget.lease.pendingDriveFinalizations().isNotEmpty &&
            snapshot.data!.canStartNewDrive) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kaydı Tamamla')),
            body: Center(
              child: FilledButton(
                onPressed: _repairing ? null : _repair,
                child: const Text('Yarım kalan hesap kaydını tamamla'),
              ),
            ),
          );
        }
        if (snapshot.data!.canStartNewDrive) {
          return MapScreen(ownerLease: widget.lease);
        }
        return DriveRecoveryScreen(
          initialStatus: snapshot.data,
          loadStatus: _load,
          loadSessions: () async {
            ForegroundService.requireOwnerLease(widget.lease);
            final sessions = await (await ForegroundService.journal)
                .recoverableSessions();
            for (final session in sessions) {
              await ForegroundService.verifyOwnerSession(
                widget.lease,
                session.id,
              );
            }
            return sessions;
          },
          selectSession: (id) async {
            await ForegroundService.verifyOwnerSession(widget.lease, id);
            await (await ForegroundService.journal).selectRecovery(id);
          },
          recoveredScreenBuilder: (finish, resume) => MapScreen(
            ownerLease: widget.lease,
            resumeDrive: true,
            finishOnOpen: finish,
            resumeIfServiceStopped: resume,
          ),
        );
      },
    ),
  );
}

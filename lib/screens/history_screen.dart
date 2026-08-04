import 'package:flutter/material.dart';

import '../models/drive_session.dart';
import '../services/drive_storage_service.dart';
import '../widgets/neon_route_preview.dart';
import 'drive_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _background = Color(0xff020c1d);

  List<DriveSession> _drives = const [];

  @override
  void initState() {
    super.initState();
    _loadDrives();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDrives();
    });
  }

  void _loadDrives() {
    final loaded = DriveStorageService.getAllDrives();
    if (!mounted) {
      _drives = loaded;
      return;
    }
    setState(() => _drives = loaded);
  }

  Future<void> _openDetail(DriveSession drive) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DriveDetailScreen(drive: drive)));
    if (mounted) _loadDrives();
  }

  Future<void> _deleteDrive(DriveSession drive) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff0a1b33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sürüşü sil'),
        content: const Text('Bu kayıtlı sürüşü silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd33c57),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (result != true) return;
    await DriveStorageService.deleteDrive(drive.id);
    if (!mounted) return;
    _loadDrives();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff102747),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Text('Sürüş silindi'),
      ),
    );
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _timeRange(DateTime start, int durationSeconds) {
    final end = start.add(Duration(seconds: durationSeconds));
    String time(DateTime value) {
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${time(start)} - ${time(end)}';
  }

  String _duration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}s ${duration.inMinutes.remainder(60)} dk';
    }
    return '${duration.inMinutes} dk ${duration.inSeconds.remainder(60)} sn';
  }

  String _displayName(DriveSession drive) {
    final stored = DriveStorageService.getDriveName(drive.id);
    if (stored.isNotEmpty) return stored;
    return 'Sürüş • ${drive.date.day.toString().padLeft(2, '0')}.${drive.date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HistoryHeader(count: _drives.length),
            Expanded(
              child: _drives.isEmpty
                  ? const _EmptyHistory()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _drives.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final drive = _drives[index];
                        return _DriveListTile(
                          drive: drive,
                          name: _displayName(drive),
                          dateLabel: _date(drive.date),
                          timeRangeLabel: _timeRange(
                            drive.date,
                            drive.durationSeconds,
                          ),
                          durationLabel: _duration(drive.durationSeconds),
                          onTap: () => _openDetail(drive),
                          onDelete: () => _deleteDrive(drive),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int count;
  const _HistoryHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 14),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sürüşlerim',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Kayıtlı rotaların ve sürüş özetlerin',
                  style: TextStyle(color: Color(0xff9aaec9), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff10294a),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xff24528c)),
            ),
            child: Text(
              '$count sürüş',
              style: const TextStyle(
                color: Color(0xff8bc3ff),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _HeaderButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff0a1d36),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _DriveListTile extends StatelessWidget {
  static const _panel = Color(0xee091a31);
  static const _blue = Color(0xff3b93ff);
  static const _muted = Color(0xff9aaec9);

  final DriveSession drive;
  final String name;
  final String dateLabel;
  final String timeRangeLabel;
  final String durationLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DriveListTile({
    required this.drive,
    required this.name,
    required this.dateLabel,
    required this.timeRangeLabel,
    required this.durationLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xff1b4779), width: 1.1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 132,
                  height: 112,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      color: const Color(0xff061326),
                      child: Hero(
                        tag: 'history-route-${drive.id}',
                        child: NeonRoutePreview(route: drive.route),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: _blue,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                                Text(
                                  timeRangeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xff6f9ac8),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: onDelete,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: _muted,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              icon: Icons.route_rounded,
                              label: 'Mesafe',
                              value:
                                  '${(drive.distance / 1000).toStringAsFixed(2)} km',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Metric(
                              icon: Icons.timer_outlined,
                              label: 'Süre',
                              value: durationLabel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xff7fa9d7),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Metric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xff6faeff), size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xff8ca3c1), fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff0b2140),
                border: Border.all(color: const Color(0xff2f83e8)),
                boxShadow: const [
                  BoxShadow(color: Color(0x553b93ff), blurRadius: 22),
                ],
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Color(0xff72b5ff),
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Henüz kayıtlı sürüş yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'İlk rotanı kaydettiğinde burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff9aaec9), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

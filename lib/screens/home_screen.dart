import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/drive_session.dart';
import '../services/drive_storage_service.dart';
import '../widgets/neon_route_preview.dart';
import 'drive_center_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const blue = Color(0xff248fff);
  static const textFont = 'Noto Sans';

  @override
  Widget build(BuildContext context) {
    final drives = DriveStorageService.getAllDrives();
    final last = drives.isEmpty ? null : drives.first;
    final now = DateTime.now();
    final today = drives
        .where(
          (d) =>
              d.date.year == now.year &&
              d.date.month == now.month &&
              d.date.day == now.day,
        )
        .toList();
    final distance = today.fold<double>(0, (s, d) => s + d.distance) / 1000;
    final seconds = today.fold<int>(0, (s, d) => s + d.durationSeconds);
    return Scaffold(
      backgroundColor: const Color(0xff020a18),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 535,
              child: ClipRect(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: SizedBox(
                    width: double.infinity,
                    height: 553,
                    child: Image.asset(
                      'assets/branding/driveit_hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0x22020a18),
                      const Color(0xff020a18),
                    ],
                    stops: const [.2, .5, .78],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 26),
              child: Column(
                children: [
                  _header(),
                  SizedBox(height: MediaQuery.sizeOf(context).height * .20),
                  _heroCards(context, drives),
                  const SizedBox(height: 10),
                  _world(),
                  const SizedBox(height: 12),
                  _today(distance, seconds, today.length),
                  const SizedBox(height: 12),
                  _last(context, last),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottom(context),
    );
  }

  Widget _heroCards(BuildContext context, List<DriveSession> drives) =>
      SizedBox(
        height: 132,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final buttonSize = (constraints.maxWidth * .29).clamp(112.0, 115.0);
            final cardWidth = constraints.maxWidth * .32;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: cardWidth,
                  child: _career(),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: cardWidth,
                  child: _drives(context, drives),
                ),
                Positioned(
                  width: buttonSize,
                  height: buttonSize,
                  child: _driveButton(context),
                ),
              ],
            );
          },
        ),
      );

  Widget _header() => const Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: Color(0xff56d8de),
        child: Text(
          'OS',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Merhaba, Orkun',
              style: TextStyle(
                fontFamily: textFont,
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.25,
              ),
            ),
            Text(
              'Bugün daha iyi sür.',
              style: TextStyle(
                fontFamily: textFont,
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      Icon(Icons.notifications_none, color: Colors.white, size: 25),
      SizedBox(width: 8),
      Icon(Icons.menu, color: Colors.white, size: 27),
    ],
  );

  Widget _career() {
    final km = DriveStorageService.getCareerDistance() / 1000;
    final seconds = DriveStorageService.getCareerDurationSeconds();
    return _glass(
      blue,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: blue, size: 18),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Kariyerim',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: textFont,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _value(
            Icons.alt_route,
            '${km.toStringAsFixed(1)} km',
            'Toplam Mesafe',
          ),
          const Divider(color: Colors.white24, height: 10),
          _value(Icons.timer_outlined, _formatDuration(seconds), 'Toplam Süre'),
        ],
      ),
    );
  }

  Widget _drives(BuildContext context, List<DriveSession> drives) =>
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        ),
        child: _glass(
          const Color(0xff9d5cff),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.alt_route, color: Color(0xffbd82ff), size: 18),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Sürüşlerim',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: textFont,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 68,
                child: Builder(
                  builder: (_) {
                    final route = DriveStorageService.getSymbolicRoute(drives);
                    return route.length < 2
                        ? const Center(
                            child: Icon(
                              Icons.route,
                              color: Colors.white38,
                              size: 28,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: NeonRoutePreview(route: route),
                          );
                  },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      'Toplam Sürüş ${drives.length}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _driveButton(BuildContext context) => _AnimatedDriveButton(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriveCenterScreen()),
    ),
  );

  Widget _world() => _glass(
    const Color(0xff315071),
    const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.public, color: blue, size: 26),
            SizedBox(width: 8),
            Text(
              'DÜNYA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.white, size: 29),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'Gezegende iz bırakmaya hazır ol!',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.alt_route, color: Color(0xff9d5cff), size: 34),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YAKINDA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Dünya Sıralaması',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _today(double km, int seconds, int count) => _glass(
    const Color(0xff315071),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, color: blue, size: 24),
            SizedBox(width: 10),
            Text(
              'Bugünkü Özet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Spacer(),
            Text('Detay  ›', style: TextStyle(color: Colors.white70)),
          ],
        ),
        const Divider(color: Colors.white24, height: 28),
        Row(
          children: [
            Expanded(
              child: _summaryMetric(
                Icons.speed,
                '-',
                'Sürüş Skoru',
                'Yok',
                blue,
              ),
            ),
            _summaryDivider(),
            Expanded(
              child: _summaryMetric(
                Icons.alt_route,
                km.toStringAsFixed(1),
                'Mesafe km',
                'Bugün',
                Colors.green,
              ),
            ),
            _summaryDivider(),
            Expanded(
              child: _summaryMetric(
                Icons.timer_outlined,
                '${seconds ~/ 60} dk',
                'Süre',
                'Toplam',
                Colors.purple,
              ),
            ),
            _summaryDivider(),
            Expanded(
              child: _summaryMetric(
                Icons.directions_car,
                '$count',
                'Sürüş Sayısı',
                'Bugün',
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _last(BuildContext context, DriveSession? drive) => GestureDetector(
    onTap: drive == null
        ? null
        : () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
    child: _glass(
      const Color(0xff315071),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: blue),
              SizedBox(width: 10),
              Text(
                'Son Sürüş',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              if (drive != null)
                Text(
                  '${drive.date.day}.${drive.date.month} ${drive.date.hour.toString().padLeft(2, '0')}:${drive.date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          if (drive == null)
            const Text(
              'Henüz kayıtlı sürüş yok',
              style: TextStyle(color: Colors.white70),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 125,
                  height: 78,
                  child: NeonRoutePreview(route: drive.route),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _lastMetric(
                            Icons.alt_route,
                            '${(drive.distance / 1000).toStringAsFixed(1)}',
                            'Toplam Mesafe',
                            blue,
                          ),
                          _lastMetric(
                            Icons.timer_outlined,
                            '${(drive.durationSeconds / 60).round()}',
                            'Toplam Süre',
                            Colors.purple,
                          ),
                          _lastMetric(
                            Icons.speed,
                            '—',
                            'Sürüş Puanı',
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 15),
                          label: const Text(
                            'Sürüşü Görüntüle',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: blue,
                            side: const BorderSide(color: blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';
  }

  Widget _value(IconData icon, String value, String label) => Row(
    children: [
      Icon(icon, color: blue, size: 20),
      const SizedBox(width: 7),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _summaryDivider() =>
      Container(width: 1, height: 78, color: Colors.white12);

  Widget _summaryMetric(
    IconData icon,
    String value,
    String label,
    String badge,
    Color color,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 21),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          badge,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _lastMetric(IconData icon, String value, String label, Color color) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ),
        ],
      );
  Widget _glass(Color border, Widget child) => Container(
    clipBehavior: Clip.hardEdge,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xdd07162b),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border, width: .75),
    ),
    child: child,
  );
  Widget _bottom(BuildContext context) => BottomNavigationBar(
    type: BottomNavigationBarType.fixed,
    backgroundColor: const Color(0xff061024),
    selectedItemColor: blue,
    unselectedItemColor: Colors.white54,
    currentIndex: 0,
    onTap: (i) {
      if (i > 0)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
    },
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
      BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart),
        label: 'İstatistikler',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.emoji_events),
        label: 'Liderlik',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Garaj'),
    ],
  );
}

class _AnimatedDriveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedDriveButton({required this.onTap});

  @override
  State<_AnimatedDriveButton> createState() => _AnimatedDriveButtonState();
}

class _AnimatedDriveButtonState extends State<_AnimatedDriveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 115,
          height: 115,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Match the PNG's deep-navy canvas so the image blends into the
            // circular button without a visible rectangular band.
            color: const Color(0xff03122d),
            border: Border.all(color: const Color(0xff0a2b55), width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xaa248fff), blurRadius: 20),
            ],
          ),
          child: ClipOval(
            child: SizedBox(
              width: 111,
              height: 82,
              child: Image.asset(
                'assets/branding/driveit_logo_clean.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => CustomPaint(
            size: const Size(125, 125),
            painter: _DriveOrbitPainter(_controller.value),
          ),
        ),
      ],
    ),
  );
}

class _DriveOrbitPainter extends CustomPainter {
  final double progress;

  const _DriveOrbitPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final wave = (math.sin(progress * math.pi * 2 - math.pi / 2) + 1) / 2;
    final pulse = Curves.easeInOut.transform(wave);
    final glowAlpha = (45 + (190 * pulse)).round();
    final ringColor = Color.lerp(
      const Color(0xff0a2345),
      const Color(0xff6ed8ff),
      pulse,
    )!;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 + (pulse * 6)
      ..color = Color.fromARGB(glowAlpha, 36, 151, 255)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + (pulse * 9));
    canvas.drawCircle(center, radius, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 + (pulse * 2)
      ..color = ringColor;
    canvas.drawCircle(center, radius, ring);
  }

  @override
  bool shouldRepaint(covariant _DriveOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

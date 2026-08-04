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
              child: Image.asset(
                'assets/branding/driveit_hero.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
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
                  _last(last),
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
                height: 58,
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
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Toplam Sürüş ${drives.length}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _driveButton(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriveCenterScreen()),
    ),
    child: Container(
      width: 115,
      height: 115,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff06162d),
        border: Border.all(color: blue, width: 3),
        boxShadow: const [BoxShadow(color: Color(0xaa248fff), blurRadius: 20)],
      ),
      child: Image.asset(
        'assets/branding/driveit_logo.png',
        fit: BoxFit.contain,
      ),
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
        const Row(
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metric('-', 'Sürüş Skoru', Colors.blue),
            _metric(km.toStringAsFixed(1), 'Mesafe km', Colors.green),
            _metric('${seconds ~/ 60} dk', 'Süre', Colors.purple),
            _metric('$count', 'Sürüş Sayısı', Colors.orange),
          ],
        ),
      ],
    ),
  );

  Widget _last(DriveSession? drive) => _glass(
    const Color(0xff315071),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
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
            Icon(Icons.chevron_right, color: Colors.white70),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric(
                      '${(drive.distance / 1000).toStringAsFixed(1)}',
                      'Toplam Mesafe',
                      blue,
                    ),
                    _metric(
                      '${(drive.durationSeconds / 60).round()}',
                      'Toplam Süre',
                      Colors.purple,
                    ),
                    _metric('—', 'Sürüş Puanı', Colors.orange),
                  ],
                ),
              ),
            ],
          ),
      ],
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
  Widget _metric(String value, String label, Color color) => Column(
    children: [
      Icon(Icons.circle, color: color, size: 10),
      const SizedBox(height: 7),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
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

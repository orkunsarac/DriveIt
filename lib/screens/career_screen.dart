import 'package:flutter/material.dart';

import '../models/drive_session.dart';
import '../services/career_statistics_service.dart';
import 'drive_detail_screen.dart';

class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key});

  static const _bg = Color(0xff020a18);
  static const _blue = Color(0xff248fff);

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '$hours sa ${minutes.toString().padLeft(2, '0')} dk';
    return '$minutes dk';
  }

  String _distance(double meters) => '${(meters / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final stats = const CareerStatisticsService().calculate();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Kariyerim', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: stats.drives.isEmpty
          ? const Center(
              child: Text(
                'İlk sürüşünü tamamla ve kariyerini oluşturmaya başla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _hero(stats),
                const SizedBox(height: 14),
                _sectionTitle('Genel Kariyer'),
                _grid([
                  _metric('Toplam Sürüş', '${stats.drives.length}', Icons.route, _blue),
                  _metric('Toplam Mesafe', _distance(stats.totalDistanceMeters), Icons.alt_route, Colors.greenAccent),
                  _metric('Toplam Süre', _duration(stats.totalDurationSeconds), Icons.timer_outlined, Colors.deepPurpleAccent),
                  _metric('Ortalama Seyir Hızı', '${stats.lifetimeAverageSpeedKmh.toStringAsFixed(1)} km/h', Icons.speed, Colors.orangeAccent),
                ]),
                const SizedBox(height: 18),
                _sectionTitle('Kişisel Rekorlar'),
                _record('En Yüksek Hız', stats.maxSpeedDrive, '${stats.maxSpeedDrive?.maxSpeed.toStringAsFixed(1)} km/h', Icons.bolt, _blue),
                _record('En Uzun Sürüş', stats.longestDrive, _distance(stats.longestDrive?.distance ?? 0), Icons.route, Colors.greenAccent),
                _record('En Uzun Sürüş Süresi', stats.longestDurationDrive, _duration(stats.longestDurationDrive?.durationSeconds ?? 0), Icons.timer, Colors.deepPurpleAccent),
                _record('En Hızlı 0–100', stats.bestZeroToHundredDrive, stats.bestZeroToHundredDrive == null ? 'Henüz kayıt yok' : '${stats.bestZeroToHundredDrive!.bestZeroToHundredSeconds!.toStringAsFixed(2)} sn', Icons.speed, Colors.orangeAccent),
                const SizedBox(height: 18),
                _sectionTitle('Hız & Performans'),
                _grid([
                  _metric('Kariyer Maksimumu', '${stats.maxSpeedDrive?.maxSpeed.toStringAsFixed(1) ?? '-'} km/h', Icons.speed, _blue),
                  _metric('Ortalama Sürüş', '${(stats.drives.fold<double>(0, (s, d) => s + d.averageSpeed) / stats.drives.length).toStringAsFixed(1)} km/h', Icons.show_chart, Colors.cyanAccent),
                  _metric('Toplam Duruş', '${stats.totalStops}', Icons.pause_circle_outline, Colors.orangeAccent),
                  _metric('Algılanan Fren', '${stats.totalBrakingEvents}', Icons.warning_amber_rounded, Colors.redAccent),
                ]),
                const SizedBox(height: 18),
                _sectionTitle('Drive Score Kariyeri'),
                _grid([
                  _metric('Puanlanan Sürüş', '${stats.scoredDriveCount}', Icons.verified, _blue),
                  _metric('Kariyer Ortalaması', stats.averageScore == null ? 'Henüz kayıt yok' : stats.averageScore!.toStringAsFixed(0), Icons.insights, Colors.amberAccent),
                  _metric('En Yüksek Puan', stats.bestScore == null ? 'Henüz kayıt yok' : stats.bestScore!.totalScore.toStringAsFixed(0), Icons.emoji_events, Colors.deepPurpleAccent),
                  _metric('Son 5 Ortalama', stats.recentAverageScore == null ? 'Henüz kayıt yok' : stats.recentAverageScore!.toStringAsFixed(0), Icons.history, Colors.greenAccent),
                ]),
                const SizedBox(height: 18),
                _sectionTitle('Viraj & G Kuvvetleri'),
                _grid([
                  _metric('Analiz Edilen Viraj', '${stats.totalCorners}', Icons.turn_right, Colors.deepPurpleAccent),
                  _metric('Tahmini Maks. G', stats.maxAccelerationDrive == null ? 'Henüz kayıt yok' : '${stats.maxAccelerationDrive!.maxAccelerationG.toStringAsFixed(2)} G', Icons.speed, Colors.purpleAccent),
                  _metric('En Güçlü Frenleme', stats.strongestBrakingDrive == null ? 'Henüz kayıt yok' : '${stats.strongestBrakingDrive!.maxBrakingG.toStringAsFixed(2)} G', Icons.sports_motorsports, Colors.redAccent),
                  _metric('Sürüş Kaydı', '${stats.totalMovingSeconds ~/ 3600} sa', Icons.directions_car, _blue),
                ]),
                if (stats.longestDrive != null) ...[
                  const SizedBox(height: 18),
                  _sectionTitle('Kayıt Kaynağı'),
                  _sourceCard(context, stats.longestDrive!),
                ],
              ],
            ),
    );
  }

  Widget _hero(CareerStatistics stats) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(colors: [Color(0xff0a2b58), Color(0xff07162b)]),
      border: Border.all(color: Color(0xff248fff), width: .8),
      boxShadow: const [BoxShadow(color: Color(0x33248fff), blurRadius: 18)],
    ),
    child: Row(
      children: [
        const CircleAvatar(radius: 30, backgroundColor: Color(0xff56d8de), child: Text('OS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 20))),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sürüş kariyerin', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text('${stats.drives.length} sürüş • ${_distance(stats.totalDistanceMeters)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_duration(stats.totalDurationSeconds), style: const TextStyle(color: Color(0xff75baff), fontSize: 14)),
        ]),
      ],
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
  );

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.65,
    children: children,
  );

  Widget _metric(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xdd07162b), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .48))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 21),
      const Spacer(),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]),
  );

  Widget _record(String label, DriveSession? drive, String value, IconData icon, Color color) => InkWell(
    onTap: drive == null ? null : () {},
    borderRadius: BorderRadius.circular(16),
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xdd07162b), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .42))),
      child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
    ),
  );

  Widget _sourceCard(BuildContext context, DriveSession drive) => InkWell(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriveDetailScreen(drive: drive))),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xdd07162b), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xff315071))),
      child: Row(children: [const Icon(Icons.open_in_new, color: _blue), const SizedBox(width: 10), Expanded(child: Text('En uzun sürüşünü görüntüle', style: const TextStyle(color: Colors.white))), const Icon(Icons.chevron_right, color: Colors.white70)]),
    ),
  );
}

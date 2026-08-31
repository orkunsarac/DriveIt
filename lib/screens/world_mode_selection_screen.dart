import 'dart:async';

import 'package:flutter/material.dart';

import '../features/my_world/models/world_map_read_model.dart';
import '../features/my_world/services/my_world_runtime.dart';
import 'my_world_map_screen.dart';

typedef MyWorldDataLoader = Future<MyWorldMapData> Function();

class WorldModeSelectionScreen extends StatefulWidget {
  const WorldModeSelectionScreen({
    super.key,
    this.loadData,
    this.myWorldBuilder,
  });

  final MyWorldDataLoader? loadData;
  final WidgetBuilder? myWorldBuilder;

  @override
  State<WorldModeSelectionScreen> createState() =>
      _WorldModeSelectionScreenState();
}

class _WorldModeSelectionScreenState extends State<WorldModeSelectionScreen> {
  static const _background = Color(0xff020a18);
  static const _blue = Color(0xff3b93ff);
  late Future<MyWorldMapData> _data;

  @override
  void initState() {
    super.initState();
    _data = _loadWorldData();
  }

  Future<MyWorldMapData> _loadWorldData() async {
    if (widget.loadData != null) return widget.loadData!();
    final initial = await MyWorldRuntime.readWorldData();
    unawaited(_refreshAfterPendingDrain());
    return initial;
  }

  Future<void> _refreshAfterPendingDrain() async {
    await MyWorldRuntime.drainPendingJobs();
    if (!mounted) return;
    final refreshed = await MyWorldRuntime.readWorldData();
    if (mounted) {
      setState(() {
        _data = Future.value(refreshed);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      title: const Text('Dünya', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dünyanı seç',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kendi izlerini keşfet, geleceğin DriveIt gezegenine hazırlan.',
              style: TextStyle(color: Color(0xff9babc2), fontSize: 13),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: _WorldModeCard(
                key: const Key('my_world_card'),
                title: 'BENİM DÜNYAM',
                subtitle: 'Kendi sürüşlerinden oluşan kalıcı neon yol ağın.',
                accent: _blue,
                artworkAsset: 'assets/images/my_world_card_art.png',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        widget.myWorldBuilder ??
                        (_) => const MyWorldMapScreen(),
                  ),
                ),
                footer: FutureBuilder<MyWorldMapData>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _blue,
                            ),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Text(
                        'Dünya verileri şu anda okunamıyor.',
                        style: TextStyle(
                          color: Color(0xff8fa1ba),
                          fontSize: 12,
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    return Row(
                      children: [
                        _WorldStat(
                          value:
                              '${(data.totalActiveDistanceMeters / 1000).toStringAsFixed(1)} km',
                          label: 'Dünya İzlerin',
                        ),
                        const SizedBox(width: 24),
                        _WorldStat(
                          value: '${data.processedDriveCount}',
                          label: 'Sürüş',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _WorldModeCard(
                key: const Key('driveit_planet_card'),
                title: 'DRIVEIT GEZEGENİ',
                subtitle: 'DriveIt sürücülerinin küresel yol ağı.',
                accent: const Color(0xff9d5cff),
                artworkAsset: 'assets/images/driveit_planet_card_art.png',
                locked: true,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('DriveIt Gezegeni yakında.')),
                ),
                footer: const Align(
                  alignment: Alignment.centerLeft,
                  child: _ComingSoonBadge(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorldModeCard extends StatelessWidget {
  const _WorldModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    required this.footer,
    required this.artworkAsset,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final Widget footer;
  final bool locked;
  final String artworkAsset;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withAlpha(190), width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: locked
                ? const [Color(0xff0b1628), Color(0xff07101f)]
                : const [Color(0xff0c213d), Color(0xff061225)],
          ),
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: accent.withAlpha(35),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  artworkAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.center,
                      colors: [
                        const Color(0xee061225),
                        const Color(0xaa061225),
                        Colors.transparent,
                      ],
                      stops: const [0, .48, .82],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.fromBorderSide(
                      BorderSide(color: accent.withAlpha(190), width: 1.2),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      locked ? Icons.lock : Icons.arrow_forward_rounded,
                      color: locked ? Colors.white38 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: locked ? Colors.white60 : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xff9babc2),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  footer,
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorldStat extends StatelessWidget {
  const _WorldStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: Color(0xff8fa1ba), fontSize: 11),
      ),
    ],
  );
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(10),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white24),
    ),
    child: const Text(
      'YAKINDA',
      style: TextStyle(
        color: Colors.white60,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

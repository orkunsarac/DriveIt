import 'package:flutter/material.dart';

import '../features/drive_score/models/drive_score_result.dart';
import '../features/drive_score/services/drive_score_persistence_coordinator.dart';
import '../models/drive_score_record.dart';
import '../services/drive_score_storage_service.dart';

typedef DriveScoreRecordLoader =
    Future<DriveScoreRecord?> Function(String driveId);

/// Read-only presentation of the persisted Drive Score v1 snapshot.
///
/// It deliberately never runs analysis or scoring engines. The separate
/// storage read also keeps legacy drives and storage failures non-fatal.
class DriveScoreSummarySection extends StatefulWidget {
  const DriveScoreSummarySection({
    super.key,
    required this.driveId,
    this.loader,
  });

  final String driveId;
  final DriveScoreRecordLoader? loader;

  @override
  State<DriveScoreSummarySection> createState() =>
      _DriveScoreSummarySectionState();
}

class _DriveScoreSummarySectionState extends State<DriveScoreSummarySection> {
  late Future<DriveScoreRecord?> _record;

  @override
  void initState() {
    super.initState();
    _record = _load();
  }

  @override
  void didUpdateWidget(covariant DriveScoreSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driveId != widget.driveId ||
        oldWidget.loader != widget.loader) {
      _record = _load();
    }
  }

  Future<DriveScoreRecord?> _load() => Future.sync(
    () => (widget.loader ?? _readStoredRecord)(widget.driveId),
  );

  Future<DriveScoreRecord?> _readStoredRecord(String driveId) async {
    final existing = DriveScoreStorageService.get(driveId: driveId);
    if (existing != null) return existing;

    // This one-time recovery path is only reached for an absent v1 record.
    // The coordinator itself safely returns null for telemetry-less legacy
    // drives, and does not recompute a score when a record already exists.
    return const DriveScorePersistenceCoordinator()
        .calculateAndPersistForDrive(driveId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriveScoreRecord?>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _section(
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    key: Key('drive-score-loading'),
                    strokeWidth: 2,
                    color: Color(0xff4e9fff),
                  ),
                ),
                SizedBox(width: 12),
                Text('Drive Score yükleniyor…', style: _secondaryText),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _unavailable('Drive Score v1 yüklenemedi');
        }
        final record = snapshot.data;
        if (record == null) {
          return _unavailable(
            'Drive Score v1 mevcut değil',
            detail: 'Bu sürüş yeni skor sistemi öncesinde kaydedildi.',
          );
        }
        return _scoreCard(record);
      },
    );
  }

  Widget _scoreCard(DriveScoreRecord record) => _section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Drive Score', style: _titleText),
        const SizedBox(height: 4),
        Text(
          '${record.totalScore.round()} / 1000',
          style: const TextStyle(
            color: Color(0xff76b4ff),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xff1b3658), height: 1),
        const SizedBox(height: 5),
        for (final definition in _categories) ...[
          _CategoryRow(
            label: definition.label,
            category: _findCategory(record, definition.key),
          ),
          const Divider(color: Color(0xff143050), height: 1),
        ],
      ],
    ),
  );

  DriveScoreCategoryRecord? _findCategory(
    DriveScoreRecord record,
    String key,
  ) {
    for (final category in record.categories) {
      if (category.categoryKey == key) return category;
    }
    return null;
  }

  Widget _unavailable(String title, {String? detail}) => _section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Drive Score', style: _titleText),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail, style: _secondaryText),
        ],
      ],
    ),
  );

  Widget _section({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff091a31),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff1b4779)),
    ),
    child: child,
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.label, required this.category});

  final String label;
  final DriveScoreCategoryRecord? category;

  @override
  Widget build(BuildContext context) {
    final value = _displayValue(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: _valueColor(category),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _displayValue(DriveScoreCategoryRecord? value) {
    if (value != null &&
        (value.contributionSource ==
                DriveScoreContributionSource.neutralNotApplicable ||
            !value.applicable)) {
      return 'N/A';
    }
    if (value == null ||
        value.contributionSource ==
            DriveScoreContributionSource.neutralInsufficient ||
        !value.sampleSufficient) {
      return 'Yetersiz veri';
    }
    return '${value.rawScore.round()} / ${value.maximum.round()}';
  }

  Color _valueColor(DriveScoreCategoryRecord? value) {
    if (value == null ||
        value.contributionSource != DriveScoreContributionSource.actual ||
        !value.applicable ||
        !value.sampleSufficient) {
      return const Color(0xff8ea5c2);
    }
    return const Color(0xff76b4ff);
  }
}

class _CategoryDefinition {
  const _CategoryDefinition(this.key, this.label);

  final String key;
  final String label;
}

const _categories = <_CategoryDefinition>[
  _CategoryDefinition('brakingAnticipation', 'Frenleme & Öngörü'),
  _CategoryDefinition('tempoPerformance', 'Tempo & Performans'),
  _CategoryDefinition('corneringPerformance', 'Viraj Performansı'),
  _CategoryDefinition('drivingEndurance', 'Sürüş Dayanıklılığı'),
  _CategoryDefinition('drivingSmoothness', 'Sürüş Akıcılığı'),
  _CategoryDefinition('accelerationPerformance', 'Hızlanma & Gaz Performansı'),
  _CategoryDefinition('transitionControl', 'Geçiş Kontrolü'),
];

const _titleText = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w700,
);

const _secondaryText = TextStyle(color: Color(0xff8ea5c2), fontSize: 13);

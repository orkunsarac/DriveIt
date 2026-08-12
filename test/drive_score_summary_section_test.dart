import 'dart:async';

import 'package:driveit_project/features/drive_score/models/drive_score_result.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/widgets/drive_score_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DriveScoreRecord record() => DriveScoreRecord(
    driveId: 'drive-1',
    algorithmVersion: 1,
    telemetryDataVersion: 1,
    calculatedAt: DateTime(2026, 8, 12),
    totalScore: 834.5,
    overallConfidence: .7,
    categories: const [
      DriveScoreCategoryRecord(
        categoryKey: 'brakingAnticipation',
        rawScore: 312,
        maximum: 350,
        applicable: true,
        sampleSufficient: true,
        contributionUsed: 312,
        contributionSource: DriveScoreContributionSource.actual,
      ),
      DriveScoreCategoryRecord(
        categoryKey: 'tempoPerformance',
        rawScore: 120,
        maximum: 150,
        applicable: true,
        sampleSufficient: true,
        contributionUsed: 120,
        contributionSource: DriveScoreContributionSource.actual,
      ),
      DriveScoreCategoryRecord(
        categoryKey: 'corneringPerformance',
        rawScore: 0,
        maximum: 150,
        applicable: false,
        sampleSufficient: false,
        contributionUsed: 112.5,
        contributionSource:
            DriveScoreContributionSource.neutralNotApplicable,
      ),
      DriveScoreCategoryRecord(
        categoryKey: 'drivingEndurance',
        rawScore: 0,
        maximum: 150,
        applicable: true,
        sampleSufficient: false,
        contributionUsed: 112.5,
        contributionSource:
            DriveScoreContributionSource.neutralInsufficient,
      ),
      DriveScoreCategoryRecord(
        categoryKey: 'drivingSmoothness',
        rawScore: 85,
        maximum: 100,
        applicable: true,
        sampleSufficient: true,
        contributionUsed: 85,
        contributionSource: DriveScoreContributionSource.actual,
      ),
      DriveScoreCategoryRecord(
        categoryKey: 'accelerationPerformance',
        rawScore: 0,
        maximum: 50,
        applicable: true,
        sampleSufficient: false,
        contributionUsed: 37.5,
        contributionSource:
            DriveScoreContributionSource.neutralInsufficient,
      ),
      DriveScoreCategoryRecord(
        categoryKey: 'transitionControl',
        rawScore: 42,
        maximum: 50,
        applicable: true,
        sampleSufficient: true,
        contributionUsed: 42,
        contributionSource: DriveScoreContributionSource.actual,
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    required Future<DriveScoreRecord?> Function(String) loader,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriveScoreSummarySection(driveId: 'drive-1', loader: loader),
        ),
      ),
    );
  }

  testWidgets('uses persisted total rounding and category display states',
      (tester) async {
    await pump(tester, loader: (_) async => record());
    await tester.pumpAndSettle();

    expect(find.text('835 / 1000'), findsOneWidget);
    expect(find.text('312 / 350'), findsOneWidget);
    expect(find.text('Viraj Performansı'), findsOneWidget);
    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('Hızlanma & Gaz Performansı'), findsOneWidget);
    expect(find.text('Yetersiz veri'), findsNWidgets(2));
    expect(find.text('113 / 150'), findsNothing);
    expect(find.text('38 / 50'), findsNothing);
  });

  testWidgets('renders a safe legacy state when no record exists',
      (tester) async {
    await pump(tester, loader: (_) async => null);
    await tester.pumpAndSettle();

    expect(find.text('Drive Score v1 mevcut değil'), findsOneWidget);
  });

  testWidgets('renders loading then safely renders storage errors',
      (tester) async {
    final completer = Completer<DriveScoreRecord?>();
    await pump(tester, loader: (_) => completer.future);

    expect(find.byKey(const Key('drive-score-loading')), findsOneWidget);
    completer.completeError(StateError('storage unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Drive Score v1 yüklenemedi'), findsOneWidget);
  });
}

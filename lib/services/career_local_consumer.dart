import 'package:hive/hive.dart';
import 'career_contribution_repository.dart';
import 'career_statistics_service.dart';
import 'local_data_preparation_service.dart';

class CareerLocalConsumer {
  static Future<CareerStatistics>? _loading;
  static Future<CareerStatistics> load() {
    final prior = _loading;
    if (prior != null) return prior;
    final future = _load();
    _loading = future;
    return future.whenComplete(() => _loading = null);
  }

  static Future<CareerStatistics> _load() async {
    if (Hive.isBoxOpen(CareerContributionRepository.boxName) &&
        await LocalDataPreparationService.prepareLegacyCareer()) {
      final repository = CareerContributionRepository(
        Hive.box<dynamic>(CareerContributionRepository.boxName),
      );
      return repository.statistics(historyOrder: true)!;
    }
    // Ambiguous legacy history stays on the unchanged presentation. Deletion
    // is independently blocked, never replacing unknown metrics with zero.
    return const CareerStatisticsService().calculate();
  }
}

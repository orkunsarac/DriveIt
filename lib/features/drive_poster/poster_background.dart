enum PosterBackgroundSourceType { customImage, vehiclePhoto, aiGenerated }

enum PosterScenePreset {
  nightCoastalRoad('Gece Sahil Yolu'),
  sunsetMountainRoad('Gün Batımı Dağ Yolu'),
  cityLights('Şehir Işıkları'),
  rainyHighway('Yağmurlu Otoyol'),
  forestRoad('Orman Yolu'),
  darkPremiumAutomotive('Karanlık Premium Otomotiv'),
  tunnelExit('Tünel Çıkışı'),
  foggyMorningRoad('Sisli Sabah Yolu');

  const PosterScenePreset(this.label);
  final String label;
}

class PosterBackgroundRequest {
  const PosterBackgroundRequest({
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.scene,
  });

  final String brand;
  final String model;
  final String year;
  final String color;
  final PosterScenePreset scene;

  String get prompt =>
      '''Create a premium vertical 9:16 automotive poster background for a driving app.

Vehicle:
Brand: $brand
Model: $model
Year: $year
Color: $color

Scene: ${scene.label}

Create only the cinematic background image.
The vehicle must realistically match the selected brand, model, generation/year and color.

Style:
- premium automotive photography
- realistic
- cinematic
- dark navy / black atmosphere
- dramatic but natural lighting
- social-media-ready
- high detail
- strong road/environment composition

Composition requirements:
- preserve clean negative space in the upper area for later DriveIt branding and trip information
- preserve usable empty space in the upper/middle area for a large Drive Score and route overlay
- keep the car mainly in the lower half
- do not overcrowd the frame
- optimize composition for Instagram Story 9:16 safe areas

STRICT:
Do not generate any text.
Do not generate logos.
Do not generate numbers.
Do not generate maps.
Do not generate route lines.
Do not generate UI.
Do not generate watermarks.
Do not generate statistics.
The application will add all of these later.''';

  Map<String, String> toMap() => {
    'brand': brand,
    'model': model,
    'year': year,
    'color': color,
    'scene': scene.name,
  };
}

class PosterBackgroundGenerationResult {
  const PosterBackgroundGenerationResult.success(this.imagePath)
    : errorMessage = null;
  const PosterBackgroundGenerationResult.failure(this.errorMessage)
    : imagePath = null;

  final String? imagePath;
  final String? errorMessage;
  bool get isSuccess => imagePath != null;
}

abstract interface class PosterBackgroundGenerator {
  Future<PosterBackgroundGenerationResult> generate(
    PosterBackgroundRequest request,
  );
}

/// The API/provider is deliberately replaceable. No token is stored in source.
class UnconfiguredPosterBackgroundGenerator
    implements PosterBackgroundGenerator {
  const UnconfiguredPosterBackgroundGenerator();

  @override
  Future<PosterBackgroundGenerationResult> generate(
    PosterBackgroundRequest request,
  ) async => const PosterBackgroundGenerationResult.failure(
    'AI arka plan sağlayıcısı henüz yapılandırılmadı. Kendi görselinizle devam edebilirsiniz.',
  );
}

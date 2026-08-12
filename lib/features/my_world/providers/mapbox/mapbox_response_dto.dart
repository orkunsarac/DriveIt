class MapboxMapMatchingResponseDto {
  final String code;
  final String? message;
  final List<MapboxMatchingDto> matchings;

  const MapboxMapMatchingResponseDto({
    required this.code,
    required this.message,
    required this.matchings,
  });

  factory MapboxMapMatchingResponseDto.fromJson(Map<String, dynamic> json) {
    final rawMatchings = json['matchings'];
    return MapboxMapMatchingResponseDto(
      code: json['code'] as String? ?? '',
      message: json['message'] as String?,
      matchings: rawMatchings is List
          ? rawMatchings
                .whereType<Map>()
                .map(
                  (item) => MapboxMatchingDto.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class MapboxMatchingDto {
  final List<MapboxCoordinateDto> geometry;
  final double? confidence;

  const MapboxMatchingDto({required this.geometry, required this.confidence});

  factory MapboxMatchingDto.fromJson(Map<String, dynamic> json) {
    final rawGeometry = json['geometry'];
    final coordinates = rawGeometry is Map ? rawGeometry['coordinates'] : null;
    final confidence = json['confidence'];
    return MapboxMatchingDto(
      geometry: coordinates is List
          ? coordinates
                .whereType<List>()
                .where((coordinate) => coordinate.length >= 2)
                .map(
                  (coordinate) => MapboxCoordinateDto(
                    longitude: (coordinate[0] as num).toDouble(),
                    latitude: (coordinate[1] as num).toDouble(),
                  ),
                )
                .toList(growable: false)
          : const [],
      confidence: confidence is num ? confidence.toDouble() : null,
    );
  }
}

class MapboxCoordinateDto {
  final double latitude;
  final double longitude;

  const MapboxCoordinateDto({required this.latitude, required this.longitude});
}

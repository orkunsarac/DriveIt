class MapboxConfig {
  const MapboxConfig._();

  static const String _environmentToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  // This is a public Mapbox token intended for client-side map matching.
  // A dart-define always takes precedence for staging or token rotation.
  static const String _defaultPublicToken =
      'pk.eyJ1Ijoib3JrdW5zcmMiLCJhIjoiY21zcHl5aGR1MGlxYzJ4c2I3aXNmeTc3ciJ9.XFYFcxfJbEWImK1NDp4tcw';

  static const String accessToken = _environmentToken.length > 0
      ? _environmentToken
      : _defaultPublicToken;
}

import 'package:flutter/material.dart';

enum PosterThemeId { classic, softWhite, ice, blackout }

enum PosterLogoVariant { symbol, wordmark }

PosterThemeId posterThemeIdFromName(String? value) {
  if (value == 'mono') return PosterThemeId.blackout;
  for (final theme in PosterThemeId.values) {
    if (theme.name == value) return theme;
  }
  return PosterThemeId.classic;
}

PosterLogoVariant posterLogoVariantFromName(String? value) {
  for (final variant in PosterLogoVariant.values) {
    if (variant.name == value) return variant;
  }
  return PosterLogoVariant.symbol;
}

@immutable
class PosterThemeData {
  const PosterThemeData({
    required this.id,
    required this.displayName,
    required this.routeColor,
    required this.routeGlowColor,
    required this.routeGlowIntensity,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.scoreColor,
    required this.scoreGlowColor,
    required this.scoreGlowIntensity,
    required this.startPinColor,
    required this.endPinColor,
    required this.iconColor,
    required this.logoTintColor,
    required this.tintLogo,
    this.shadowColor,
    this.shadowOpacity = 0,
  });

  final PosterThemeId id;
  final String displayName;
  final Color routeColor;
  final Color routeGlowColor;
  final double routeGlowIntensity;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color scoreColor;
  final Color scoreGlowColor;
  final double scoreGlowIntensity;
  final Color startPinColor;
  final Color endPinColor;
  final Color iconColor;
  final Color logoTintColor;
  final bool tintLogo;
  final Color? shadowColor;
  final double shadowOpacity;

  static const classic = PosterThemeData(
    id: PosterThemeId.classic,
    displayName: 'Classic',
    routeColor: Color(0xff63e6ff),
    routeGlowColor: Color(0xff248fff),
    routeGlowIntensity: .608,
    primaryTextColor: Color(0xfff1f5fb),
    secondaryTextColor: Color(0x99ffffff),
    scoreColor: Color(0xff63dcff),
    scoreGlowColor: Color(0xff248fff),
    scoreGlowIntensity: .4,
    startPinColor: Color(0xff54e5a1),
    endPinColor: Color(0xffff637d),
    iconColor: Color(0xff63dcff),
    logoTintColor: Colors.white,
    tintLogo: false,
    shadowColor: Color(0xff248fff),
    shadowOpacity: .4,
  );

  static const softWhite = PosterThemeData(
    id: PosterThemeId.softWhite,
    displayName: 'Soft White',
    routeColor: Color(0xfff4f3ee),
    routeGlowColor: Color(0xfff4f3ee),
    routeGlowIntensity: .12,
    primaryTextColor: Color(0xfff4f3ee),
    secondaryTextColor: Color(0xffc6c7c9),
    scoreColor: Color(0xfff4f3ee),
    scoreGlowColor: Color(0xfff4f3ee),
    scoreGlowIntensity: .08,
    startPinColor: Color(0xffe4e5e6),
    endPinColor: Color(0xff74777b),
    iconColor: Color(0xffe4e5e6),
    logoTintColor: Color(0xfff4f3ee),
    tintLogo: true,
    shadowColor: Color(0xfff4f3ee),
    shadowOpacity: .08,
  );

  static const ice = PosterThemeData(
    id: PosterThemeId.ice,
    displayName: 'Ice',
    routeColor: Color(0xffbceaff),
    routeGlowColor: Color(0xff55bfe8),
    routeGlowIntensity: .24,
    primaryTextColor: Color(0xffeaf6fc),
    secondaryTextColor: Color(0xffa9c4d3),
    scoreColor: Color(0xffbceaff),
    scoreGlowColor: Color(0xff55bfe8),
    scoreGlowIntensity: .18,
    startPinColor: Color(0xffd7eaf2),
    endPinColor: Color(0xff607b8d),
    iconColor: Color(0xffbceaff),
    logoTintColor: Color(0xffd7f1ff),
    tintLogo: true,
    shadowColor: Color(0xff55bfe8),
    shadowOpacity: .18,
  );

  static const blackout = PosterThemeData(
    id: PosterThemeId.blackout,
    displayName: 'Blackout',
    routeColor: Color(0xff25282c),
    routeGlowColor: Color(0xffa4a8ac),
    routeGlowIntensity: .09,
    primaryTextColor: Color(0xffeeeeec),
    secondaryTextColor: Color(0xffaaadb0),
    scoreColor: Color(0xffe7e8e8),
    scoreGlowColor: Color(0xffa4a8ac),
    scoreGlowIntensity: .025,
    startPinColor: Color(0xffdedfe0),
    endPinColor: Color(0xff707478),
    iconColor: Color(0xffb6b9bc),
    logoTintColor: Color(0xffe2e4e5),
    tintLogo: true,
    shadowColor: Color(0xffa4a8ac),
    shadowOpacity: .025,
  );

  static const values = [classic, softWhite, ice, blackout];

  static PosterThemeData fromId(String? value) {
    final id = posterThemeIdFromName(value);
    return values.firstWhere((theme) => theme.id == id);
  }
}

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable JSON bytes for versioned sync payloads, using JSON Canonicalization
/// Scheme number layout and recursively ordered object keys. A
/// matching server implementation must use the same v2 rule. Callers must
/// bump the sync contract version before changing this encoding.
String canonicalOwnerSyncJson(Object? value) => _encodeCanonical(value);

List<int> canonicalOwnerSyncBytes(Object? value) =>
    utf8.encode(canonicalOwnerSyncJson(value));

String canonicalOwnerSyncSha256(Object? value) =>
    sha256.convert(canonicalOwnerSyncBytes(value)).toString();

String _encodeCanonical(Object? value) {
  if (value == null) return 'null';
  if (value is String) return jsonEncode(value);
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return _canonicalNumber(value);
  if (value is List) {
    return '[${value.map(_encodeCanonical).join(',')}]';
  }
  if (value is Map) {
    final keys = value.keys.toList(growable: false);
    if (keys.any((key) => key is! String)) {
      throw const FormatException('Sync object keys must be strings');
    }
    keys.sort((a, b) => (a as String).compareTo(b as String));
    return '{${keys.map((key) {
      final stringKey = key as String;
      return '${jsonEncode(stringKey)}:${_encodeCanonical(value[stringKey])}';
    }).join(',')}}';
  }
  throw FormatException('Unsupported sync JSON value: ${value.runtimeType}');
}

String _canonicalNumber(num value) {
  if (!value.isFinite) throw const FormatException('Non-finite sync number');
  if (value == 0) return '0';
  if (value is int && value.abs() > 9007199254740991) {
    throw const FormatException('Integer is outside the interoperable range');
  }

  final number = value.toDouble();
  if (number.abs() > 9007199254740991 &&
      number.truncateToDouble() == number) {
    throw const FormatException(
      'Integer is outside the interoperable range',
    );
  }
  final negative = number.isNegative;
  final raw = number.abs().toString().toLowerCase();
  final exponentSeparator = raw.indexOf('e');
  final significand = exponentSeparator < 0
      ? raw
      : raw.substring(0, exponentSeparator);
  final exponent = exponentSeparator < 0
      ? 0
      : int.parse(raw.substring(exponentSeparator + 1));
  final dot = significand.indexOf('.');
  final wholeDigits = dot < 0 ? significand.length : dot;
  var digits = significand.replaceAll('.', '');
  var decimalPosition = wholeDigits + exponent;
  final firstNonZero = digits.indexOf(RegExp('[1-9]'));
  if (firstNonZero < 0) return '0';
  decimalPosition -= firstNonZero;
  digits = digits.substring(firstNonZero);
  while (digits.length > 1 && digits.endsWith('0')) {
    digits = digits.substring(0, digits.length - 1);
  }

  final String rendered;
  if (decimalPosition > 0 && decimalPosition <= 21) {
    rendered = decimalPosition >= digits.length
        ? '$digits${List<String>.filled(
            decimalPosition - digits.length,
            '0',
          ).join()}'
        : '${digits.substring(0, decimalPosition)}.${digits.substring(decimalPosition)}';
  } else if (decimalPosition <= 0 && decimalPosition > -6) {
    rendered =
        '0.${List<String>.filled(-decimalPosition, '0').join()}$digits';
  } else {
    final scientificExponent = decimalPosition - 1;
    final coefficient = digits.length == 1
        ? digits
        : '${digits[0]}.${digits.substring(1)}';
    final exponentSign = scientificExponent >= 0 ? '+' : '';
    rendered = '${coefficient}e$exponentSign$scientificExponent';
  }
  return negative ? '-$rendered' : rendered;
}

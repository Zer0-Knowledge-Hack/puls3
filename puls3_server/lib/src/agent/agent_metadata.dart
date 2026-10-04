import 'dart:convert';
import 'dart:typed_data';

/// Parsers for the registry metadata values of one agent.
///
/// Each one takes the raw value (`null` when the key is unset) and returns the
/// parsed value, or `null` when it is missing or invalid. The rules mirror the
/// checks of `scripts/seed-demo-agents.sh`, so everything the seed accepts is
/// accepted here.

const _nameLength = (min: 3, max: 48);
const _descriptionLength = (min: 10, max: 280);
const _maxSkills = 5;

/// The largest integer a JavaScript client reads without losing precision.
const _maxPriceUsdcStroops = 9007199254740991;

final _kebabId = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final _positiveInteger = RegExp(r'^[1-9][0-9]*$');

/// The metadata id, for example `agt-001`: any non-empty text.
String? parseAgentId(Uint8List? value) => _text(value, min: 1);

/// The display name, 3 to 48 characters.
String? parseName(Uint8List? value) =>
    _text(value, min: _nameLength.min, max: _nameLength.max);

/// The description, 10 to 280 characters.
String? parseDescription(Uint8List? value) => _text(
  value,
  min: _descriptionLength.min,
  max: _descriptionLength.max,
);

/// A JSON array of 1 to 5 kebab-case skill ids, in the stored order.
List<String>? parseSkills(Uint8List? value) {
  final text = _text(value, min: 1);
  if (text == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! List || decoded.isEmpty || decoded.length > _maxSkills) {
    return null;
  }
  final skills = <String>[];
  for (final element in decoded) {
    if (element is! String || !_kebabId.hasMatch(element)) return null;
    skills.add(element);
  }
  return skills;
}

/// A positive base-10 integer of at most 2^53 - 1.
int? parsePriceUsdcStroops(Uint8List? value) {
  final text = _text(value, min: 1);
  if (text == null || !_positiveInteger.hasMatch(text)) return null;
  final price = BigInt.parse(text);
  return price > BigInt.from(_maxPriceUsdcStroops) ? null : price.toInt();
}

/// The optional model name. An unset or invalid value is simply `null`.
String? parseModel(Uint8List? value) => _text(value, min: 1);

/// [value] as strict UTF-8 whose length in characters is within the bounds.
String? _text(Uint8List? value, {required int min, int? max}) {
  if (value == null) return null;
  final String text;
  try {
    text = utf8.decode(value);
  } on FormatException {
    return null;
  }
  final length = text.runes.length;
  if (length < min || (max != null && length > max)) return null;
  return text;
}

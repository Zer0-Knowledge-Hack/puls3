/// USDC on Stellar uses 7 decimal places: 1 USDC = 10,000,000 stroops.
const int stroopsPerUsdc = 10000000;
const int usdcDecimals = 7;

/// Formats [stroops] for display, keeping at least two decimals and trimming
/// trailing zeros beyond that. Uses integer math only.
String formatUsdc(int stroops) {
  final negative = stroops < 0;
  final abs = stroops.abs();
  final whole = abs ~/ stroopsPerUsdc;
  var fraction = (abs % stroopsPerUsdc).toString().padLeft(usdcDecimals, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '${negative ? '-' : ''}$whole.$fraction';
}

/// Parses a user-typed amount such as "0.5" or "12.25" into stroops.
/// Returns null when the input is not a valid non-negative amount.
int? parseUsdcToStroops(String input) {
  final match = RegExp(r'^\s*(\d{0,9})(?:\.(\d{0,7}))?\s*$').firstMatch(input);
  if (match == null) return null;
  final wholePart = match.group(1) ?? '';
  final fractionPart = match.group(2) ?? '';
  if (wholePart.isEmpty && fractionPart.isEmpty) return null;
  final whole = wholePart.isEmpty ? 0 : int.parse(wholePart);
  final fraction = int.parse(fractionPart.padRight(usdcDecimals, '0'));
  return whole * stroopsPerUsdc + fraction;
}

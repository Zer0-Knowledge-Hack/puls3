import '../generated/protocol.dart';

/// The `PULS3_*` settings the escrow relay needs (P2).
///
/// None has a default, fallback or placeholder: a missing, empty, non-integer
/// or out-of-range value raises [HireConfigurationMissing] naming the key,
/// when the operation that needs it reads it, before anything is persisted.
final class HireRelayConfig {
  const HireRelayConfig(this._environment);

  /// Seconds an unsigned envelope stays valid (its `maxTime`).
  static const preparationValidityKey =
      'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS';

  /// Inclusion fee of every envelope, in stroops.
  static const inclusionFeeKey = 'PULS3_STELLAR_INCLUSION_FEE_STROOPS';

  /// The `max_fee_bps` of `fund`; equals `NetworkConfig.platformFeeBps`.
  static const platformFeeKey = 'PULS3_PLATFORM_FEE_BPS';

  /// Seconds from hire creation to the job's `expired_at`.
  static const jobDurationKey = 'PULS3_HIRE_JOB_DURATION_SECONDS';

  /// The contract's `MAX_FEE_BPS`.
  static const _maxFeeBps = 1000;

  final Map<String, String> _environment;

  int get preparationValiditySeconds => _positive(preparationValidityKey);

  int get inclusionFeeStroops => _positive(inclusionFeeKey);

  /// 0 to 1000; 0 is a real value (no platform fee).
  int get platformFeeBps => _read(platformFeeKey, 0, _maxFeeBps);

  int get jobDurationSeconds => _positive(jobDurationKey);

  int _positive(String key) => _read(key, 1, null);

  int _read(String key, int min, int? max) {
    final value = int.tryParse(_environment[key] ?? '');
    if (value == null || value < min || (max != null && value > max)) {
      throw HireConfigurationMissing(setting: key);
    }
    return value;
  }
}

import 'package:puls3_domain/puls3_domain.dart';

/// The network values the Soroban adapter needs (ADR-0001 §5).
///
/// Every value is public, so it is read from `PULS3_STELLAR_*` environment
/// variables and falls back to [testnet], never to `passwords.yaml`:
///
/// | Variable | Field |
/// |---|---|
/// | `PULS3_STELLAR_RPC_URL` | [rpcUrl] |
/// | `PULS3_STELLAR_NETWORK_PASSPHRASE` | [networkPassphrase] |
/// | `PULS3_STELLAR_USDC_SAC` | [usdcSac] |
/// | `PULS3_STELLAR_IDENTITY_REGISTRY` | [identityRegistry] |
/// | `PULS3_STELLAR_ESCROW` | [escrow] |
/// | `PULS3_STELLAR_REPUTATION_REGISTRY` | [reputationRegistry] |
/// | `PULS3_STELLAR_SIMULATION_SOURCE` | [simulationSource] |
/// | `PULS3_STELLAR_RPC_TIMEOUT_SECONDS` | [rpcTimeout] |
final class StellarConfig {
  const StellarConfig({
    required this.rpcUrl,
    required this.networkPassphrase,
    required this.usdcSac,
    required this.identityRegistry,
    required this.escrow,
    required this.simulationSource,
    this.reputationRegistry,
    this.rpcTimeout = defaultRpcTimeout,
  });

  /// Builds the configuration from [env] (normally `Platform.environment`).
  ///
  /// An unset or empty variable keeps its [testnet] value. A set variable
  /// overrides it. An invalid address throws [InvalidStellarAddress]. A
  /// timeout that is not a positive whole number of seconds throws
  /// [ArgumentError].
  factory StellarConfig.fromEnvironment(Map<String, String> env) {
    String? read(String name) {
      final value = env[name];
      return value == null || value.isEmpty ? null : value;
    }

    StellarAddress address(String name, StellarAddress fallback) {
      final value = read(name);
      return value == null ? fallback : StellarAddress.parse(value);
    }

    Duration timeout() {
      const name = 'PULS3_STELLAR_RPC_TIMEOUT_SECONDS';
      final value = read(name);
      if (value == null) return defaultRpcTimeout;
      final seconds = int.tryParse(value);
      if (seconds == null || seconds < 1) {
        throw ArgumentError.value(
          value,
          name,
          'must be a positive whole number of seconds',
        );
      }
      return Duration(seconds: seconds);
    }

    final rpcUrl = read('PULS3_STELLAR_RPC_URL');
    return StellarConfig(
      rpcUrl: rpcUrl == null ? testnet.rpcUrl : Uri.parse(rpcUrl),
      networkPassphrase:
          read('PULS3_STELLAR_NETWORK_PASSPHRASE') ?? testnet.networkPassphrase,
      usdcSac: address('PULS3_STELLAR_USDC_SAC', testnet.usdcSac),
      identityRegistry: address(
        'PULS3_STELLAR_IDENTITY_REGISTRY',
        testnet.identityRegistry,
      ),
      escrow: address('PULS3_STELLAR_ESCROW', testnet.escrow),
      simulationSource: address(
        'PULS3_STELLAR_SIMULATION_SOURCE',
        testnet.simulationSource,
      ),
      reputationRegistry: switch (read('PULS3_STELLAR_REPUTATION_REGISTRY')) {
        final value? => StellarAddress.parse(value),
        null => testnet.reputationRegistry,
      },
      rpcTimeout: timeout(),
    );
  }

  /// How long one Soroban RPC call may take before the chain counts as down.
  static const defaultRpcTimeout = Duration(seconds: 8);

  /// Public testnet values. A drift test keeps the contract ids equal to
  /// `contracts/deployments/testnet.json`.
  static final testnet = StellarConfig(
    rpcUrl: Uri.parse('https://soroban-testnet.stellar.org'),
    networkPassphrase: 'Test SDF Network ; September 2015',
    usdcSac: StellarAddress.parse(
      'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA',
    ),
    identityRegistry: StellarAddress.parse(
      'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
    ),
    escrow: StellarAddress.parse(
      'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
    ),
    simulationSource: StellarAddress.parse(
      'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
    ),
    reputationRegistry: StellarAddress.parse(
      'CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4',
    ),
  );

  final Uri rpcUrl;
  final String networkPassphrase;

  /// The Stellar Asset Contract of the accepted USDC.
  final StellarAddress usdcSac;
  final StellarAddress identityRegistry;
  final StellarAddress escrow;

  /// The Reputation Registry (#14), or `null` while none is configured.
  ///
  /// [testnet] has the registry recorded in `contracts/deployments/testnet.json`;
  /// `PULS3_STELLAR_REPUTATION_REGISTRY` overrides it. Without any id the
  /// feedback and reputation features stay unwired (`UnwiredReputationCalls`).
  final StellarAddress? reputationRegistry;

  /// An existing account used only as the source of unsigned simulations.
  final StellarAddress simulationSource;

  /// The client timeout of every Soroban RPC call (one request, not a whole
  /// catalog build). Not capped: other providers may use other limits.
  final Duration rpcTimeout;

  @override
  bool operator ==(Object other) =>
      other is StellarConfig &&
      other.rpcUrl == rpcUrl &&
      other.networkPassphrase == networkPassphrase &&
      other.usdcSac == usdcSac &&
      other.identityRegistry == identityRegistry &&
      other.escrow == escrow &&
      other.simulationSource == simulationSource &&
      other.reputationRegistry == reputationRegistry &&
      other.rpcTimeout == rpcTimeout;

  @override
  int get hashCode => Object.hash(
    rpcUrl,
    networkPassphrase,
    usdcSac,
    identityRegistry,
    escrow,
    simulationSource,
    reputationRegistry,
    rpcTimeout,
  );
}

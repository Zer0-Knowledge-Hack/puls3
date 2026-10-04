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
/// | `PULS3_STELLAR_SIMULATION_SOURCE` | [simulationSource] |
final class StellarConfig {
  const StellarConfig({
    required this.rpcUrl,
    required this.networkPassphrase,
    required this.usdcSac,
    required this.identityRegistry,
    required this.escrow,
    required this.simulationSource,
  });

  /// Builds the configuration from [env] (normally `Platform.environment`).
  ///
  /// An unset or empty variable keeps its [testnet] value. A set variable
  /// overrides it. An invalid address throws [InvalidStellarAddress].
  factory StellarConfig.fromEnvironment(Map<String, String> env) {
    String? read(String name) {
      final value = env[name];
      return value == null || value.isEmpty ? null : value;
    }

    StellarAddress address(String name, StellarAddress fallback) {
      final value = read(name);
      return value == null ? fallback : StellarAddress.parse(value);
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
    );
  }

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
  );

  final Uri rpcUrl;
  final String networkPassphrase;

  /// The Stellar Asset Contract of the accepted USDC.
  final StellarAddress usdcSac;
  final StellarAddress identityRegistry;
  final StellarAddress escrow;

  /// An existing account used only as the source of unsigned simulations.
  final StellarAddress simulationSource;

  @override
  bool operator ==(Object other) =>
      other is StellarConfig &&
      other.rpcUrl == rpcUrl &&
      other.networkPassphrase == networkPassphrase &&
      other.usdcSac == usdcSac &&
      other.identityRegistry == identityRegistry &&
      other.escrow == escrow &&
      other.simulationSource == simulationSource;

  @override
  int get hashCode => Object.hash(
    rpcUrl,
    networkPassphrase,
    usdcSac,
    identityRegistry,
    escrow,
    simulationSource,
  );
}

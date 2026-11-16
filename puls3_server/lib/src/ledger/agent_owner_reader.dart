import 'package:puls3_domain/puls3_domain.dart';

import 'contract_reader.dart';
import 'sc_val_json.dart';
import 'xdr_invoke_encoder.dart';

/// Identity registry `AgentNotFound`: no agent has this id.
const registryAgentNotFound = 3;

/// [AgentOwnerReader] over a [ContractReader] for the identity registry at
/// [identityRegistry]: the one `owner_of` read.
final class ContractAgentOwnerReader implements AgentOwnerReader {
  ContractAgentOwnerReader(this._reader, {required this.identityRegistry});

  final ContractReader _reader;
  final StellarAddress identityRegistry;

  @override
  Future<StellarAddress?> ownerOf(AgentId agent) async {
    final value = await _reader.read(
      identityRegistry,
      'owner_of',
      [ScArg.u32(agent.value)],
      absentErrors: const {registryAgentNotFound},
    );
    return value == null ? null : readAddress(value);
  }
}

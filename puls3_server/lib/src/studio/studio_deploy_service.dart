import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../agent/agent_wallet_custody.dart';
import '../agent/stellar_agent_wallet_custody.dart';
import '../chain/submission_ledger.dart';
import '../generated/protocol.dart' hide AgentManifestDraft;
import '../hire/chain_accounts.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/stellar_config.dart';
import 'auth_entry.dart';
import 'deploy_chain.dart';
import 'registration_call.dart';
import 'registration_document.dart';
import 'studio_agent_version.dart';
import 'studio_deploy_store.dart';
import 'studio_draft_errors.dart';
import 'studio_draft_service.dart';
import 'studio_model_policy.dart';

/// The deploy of one draft: `register_full`, `set_agent_wallet`, then the
/// public registration file and the manifest the runtime runs.
///
/// A later edit of a live agent keeps the same registry id and wallet.
/// The builder signs `set_metadata` for `manifestHash` and then for
/// `puls3.manifestVersion`. New hires follow the new version. A hire that
/// already pinned the previous version keeps that snapshot. The
/// registration file omits the prompt.
final class StudioDeployService {
  StudioDeployService({
    required StudioDraftService drafts,
    required StudioDeployStore deploys,
    required AgentVersionStore versions,
    required AgentWalletCustody wallets,
    required ChainAccounts accounts,
    required EnvelopeCodec codec,
    required AddressAuthAssembler assembler,
    required SubmissionLedger sender,
    required ChainTxReader transactions,
    required AccountFunder funder,
    required AgentEnvelopeSigner signer,
    required StellarConfig stellar,
    required Uri registrationBase,
    required int preparationValiditySeconds,
    required int inclusionFeeStroops,
    ModelPolicy? policy,
    DateTime Function()? now,
    String Function()? newPreparationId,
  }) : _drafts = drafts,
       _deploys = deploys,
       _versions = versions,
       _wallets = wallets,
       _accounts = accounts,
       _codec = codec,
       _assembler = assembler,
       _sender = sender,
       _transactions = transactions,
       _funder = funder,
       _signer = signer,
       _stellar = stellar,
       _registrationBase = registrationBase,
       _validitySeconds = preparationValiditySeconds,
       _inclusionFee = inclusionFeeStroops,
       _policy = policy ?? studioServerModelPolicy,
       _now = now ?? DateTime.now,
       _newPreparationId = newPreparationId ?? _randomPreparationId;

  final StudioDraftService _drafts;
  final StudioDeployStore _deploys;
  final AgentVersionStore _versions;
  final AgentWalletCustody _wallets;
  final ChainAccounts _accounts;
  final EnvelopeCodec _codec;
  final AddressAuthAssembler _assembler;
  final SubmissionLedger _sender;
  final ChainTxReader _transactions;
  final AccountFunder _funder;
  final AgentEnvelopeSigner _signer;
  final StellarConfig _stellar;
  final Uri _registrationBase;
  final int _validitySeconds;
  final int _inclusionFee;
  final ModelPolicy _policy;
  final DateTime Function() _now;
  final String Function() _newPreparationId;

  String get networkPassphrase => _stellar.networkPassphrase;

  Future<StudioDeployRow> prepareDeploy({
    required StellarAddress owner,
    required int draftId,
  }) async {
    final draft = await _drafts.get(owner: owner, draftId: draftId);
    final snapshot = jsonEncode(draft.manifest.toJson());
    final current = await _refresh(await _deploys.findByDraft(draftId));
    if (current != null && current.retryFromStep == 8) {
      return _publish(current);
    }
    if (current != null &&
        current.registryAgentId != null &&
        current.manifestJson != snapshot &&
        (current.state == 'active' ||
            (versionUpdateOf(current.walletAuthJson) != null &&
                current.state == 'failed'))) {
      final latest = await _versions.latest(current.registryAgentId!);
      final live = latest?.version ?? draft.liveVersion ?? 1;
      draft.manifest.validate(_policy, ManifestVersion(live).next());
      return _prepareVersion(owner, draft, current, snapshot, live + 1);
    }
    draft.manifest.validate(_policy, ManifestVersion.first);
    if (current != null && _reusableRegistration(current)) return current;
    return _prepareRegistration(owner, draft);
  }

  Future<StudioDeployRow> submitRegistration({
    required StellarAddress owner,
    required int draftId,
    required String preparationId,
    required String signedTransactionXdr,
  }) async {
    await _drafts.get(owner: owner, draftId: draftId);
    final row = await _requireRow(draftId);
    if (row.preparationId != preparationId) throw _api('PreparationNotFound');
    if (row.state == 'registrationSubmitted') {
      return await _refresh(row) ?? row;
    }
    if (row.registryAgentId != null &&
        row.state != 'awaitingRegistrationSignature') {
      return await _refresh(row) ?? row;
    }
    _requireFresh(row);
    final unsigned = row.unsignedEnvelopeXdr;
    if (unsigned == null) throw _api('PreparationNotFound');
    _verifyRegistration(unsigned, owner, signedTransactionXdr);
    final signed = _codec.parse(signedTransactionXdr);
    final updating = versionUpdateOf(row.walletAuthJson) != null;
    final submitted = await _deploys.save(
      row.copy(
        state: 'registrationSubmitted',
        registrationHash: updating ? null : signed.hashHex,
        walletTxHash: updating ? signed.hashHex : null,
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
    await _send(signedTransactionXdr);
    return await _refresh(submitted) ?? submitted;
  }

  Future<StudioDeployRow> getDeploySession({
    required StellarAddress owner,
    required int draftId,
  }) async {
    await _drafts.get(owner: owner, draftId: draftId);
    final row = await _deploys.findByDraft(draftId);
    if (row == null) throw const StudioDraftMissing();
    return await _refresh(row) ?? row;
  }

  Future<StudioDeployRow> prepareWalletAuthorization({
    required StellarAddress owner,
    required int draftId,
  }) async {
    await _drafts.get(owner: owner, draftId: draftId);
    final row = await _refresh(await _requireRow(draftId));
    final agentId = row?.registryAgentId;
    if (row == null || agentId == null) {
      throw _api('RegistrationNotConfirmed');
    }
    if (versionUpdateOf(row.walletAuthJson) != null) {
      final refreshed = await _refresh(row) ?? row;
      if (refreshed.state == 'awaitingWalletAuthorization' &&
          refreshed.unsignedEnvelopeXdr != null &&
          _fresh(refreshed)) {
        return refreshed;
      }
      throw _api('RegistrationNotConfirmed');
    }
    if (row.state == 'walletAuthorizationSubmitted' || row.state == 'active') {
      return row;
    }
    if (row.authorizationEntryXdr != null &&
        row.state == 'awaitingWalletAuthorization' &&
        _fresh(row)) {
      return row;
    }
    final wallet = StellarAddress.parse(row.agentWallet);
    if (await _accounts.authorityOf(wallet) == null) {
      try {
        await _funder.fund(wallet);
      } on LedgerException {
        throw _chain();
      }
    }
    final sequence = await _accounts.sequenceOf(wallet);
    final validUntil = _nowSeconds + _validitySeconds;
    final spec = EnvelopeSpec(
      source: wallet,
      accountSequence: sequence,
      contract: _stellar.identityRegistry,
      function: 'set_agent_wallet',
      args: setAgentWalletArgs(
        caller: owner,
        agentId: agentId,
        newWallet: wallet,
      ),
      inclusionFee: _inclusionFee,
      validUntil: validUntil,
    );
    final simulation = await _accounts.simulate(spec);
    final index = addressAuthIndex(simulation.auth);
    if (index == null) throw _chain();
    final AuthEntryView entry;
    try {
      entry = readAuthEntry(simulation.auth[index]);
    } on FormatException {
      throw _chain();
    }
    if (!entry.covers(owner) || entry.expirationLedger == null) {
      throw _chain();
    }
    final draft = WalletAuthDraft(
      accountSequence: sequence,
      validUntil: validUntil,
      inclusionFee: _inclusionFee,
      minResourceFee: simulation.minResourceFee,
      transactionData: simulation.transactionData,
      auth: simulation.auth,
      builderIndex: index,
    );
    return _deploys.save(
      row.copy(
        state: 'awaitingWalletAuthorization',
        authorizationEntryXdr: simulation.auth[index],
        signatureExpirationLedger: entry.expirationLedger,
        expiresAt: _expiry(validUntil),
        walletAuthJson: draft.toJson(),
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
  }

  Future<StudioDeployRow> submitWalletAuthorization({
    required StellarAddress owner,
    required int draftId,
    required String preparationId,
    required String signedAuthorizationEntryXdr,
  }) async {
    await _drafts.get(owner: owner, draftId: draftId);
    final row = await _requireRow(draftId);
    if (row.preparationId != preparationId) throw _api('PreparationNotFound');
    if (row.registryAgentId == null) throw _api('RegistrationNotConfirmed');
    if (row.state == 'walletAuthorizationSubmitted' || row.state == 'active') {
      return await _refresh(row) ?? row;
    }
    if (versionUpdateOf(row.walletAuthJson) != null) {
      return _submitVersionMetadata(
        row,
        owner,
        signedAuthorizationEntryXdr,
      );
    }
    _requireFresh(row);
    final preparedEntry = row.authorizationEntryXdr;
    final encoded = row.walletAuthJson;
    if (preparedEntry == null || encoded == null) {
      throw _api('PreparationNotFound');
    }
    _requireSignedEntry(preparedEntry, signedAuthorizationEntryXdr, owner);
    final WalletAuthDraft draft;
    try {
      draft = WalletAuthDraft.parse(encoded);
    } on FormatException {
      throw _api('PreparationNotFound');
    }
    final auth = [...draft.auth];
    if (draft.builderIndex < 0 || draft.builderIndex >= auth.length) {
      throw _api('InvalidAuthorizationEntry');
    }
    auth[draft.builderIndex] = signedAuthorizationEntryXdr;
    final wallet = StellarAddress.parse(row.agentWallet);
    final prepared = _assembler.assembleAllowingAddressAuth(
      EnvelopeSpec(
        source: wallet,
        accountSequence: draft.accountSequence,
        contract: _stellar.identityRegistry,
        function: 'set_agent_wallet',
        args: setAgentWalletArgs(
          caller: owner,
          agentId: row.registryAgentId!,
          newWallet: wallet,
        ),
        inclusionFee: draft.inclusionFee,
        validUntil: draft.validUntil,
      ),
      SimulationData(
        transactionData: draft.transactionData,
        minResourceFee: draft.minResourceFee,
        auth: auth,
      ),
    );
    final String signed;
    try {
      signed = await _signer.sign(prepared, wallet);
    } on AgentWalletCustodyUnavailable {
      throw _api('AgentWalletUnavailable');
    }
    final submitted = await _deploys.save(
      row.copy(
        state: 'walletAuthorizationSubmitted',
        walletTxHash: prepared.hashHex,
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
    await _send(signed);
    return await _refresh(submitted) ?? submitted;
  }

  Future<StudioDeployRow> _prepareRegistration(
    StellarAddress owner,
    OwnedStudioDraft draft,
  ) async {
    final StellarAddress wallet;
    try {
      wallet = await _wallets.create(
        owner: owner,
        idempotencyKey: 'draft:${draft.draftId}',
      );
    } on AgentWalletCustodyUnavailable {
      throw _api('AgentWalletCreationFailed');
    }
    final manifest = draft.manifest.validate(_policy, ManifestVersion.first);
    final snapshot = jsonEncode(draft.manifest.toJson());
    final hash = manifestHash(draft.manifest);
    final uri = registrationUri(_registrationBase, hash);
    final sequence = await _accounts.sequenceOf(owner);
    final validUntil = _nowSeconds + _validitySeconds;
    final spec = EnvelopeSpec(
      source: owner,
      accountSequence: sequence,
      contract: _stellar.identityRegistry,
      function: 'register_full',
      args: registerFullArgs(
        caller: owner,
        agentUri: uri,
        manifestHash: hash,
        manifest: manifest,
        catalogId: 'studio-${draft.draftId}',
      ),
      inclusionFee: _inclusionFee,
      validUntil: validUntil,
    );
    final simulation = await _accounts.simulate(spec);
    final PreparedEnvelope envelope;
    try {
      envelope = _codec.build(spec, simulation);
    } on UnsupportedAuthorization {
      throw _chain();
    }
    return _deploys.save(
      StudioDeployRow(
        draftId: draft.draftId,
        owner: owner.value,
        state: 'awaitingRegistrationSignature',
        agentWallet: wallet.value,
        registrationUri: uri,
        manifestJson: snapshot,
        preparationId: _newPreparationId(),
        unsignedEnvelopeXdr: envelope.envelopeXdr,
        registrationHash: envelope.hashHex,
        expiresAt: _expiry(validUntil),
        updatedAt: _now().toUtc(),
      ),
    );
  }

  /// `set_metadata` of `manifestHash` for version [next]. The live snapshot
  /// stays in [current] until both metadata transactions confirm.
  Future<StudioDeployRow> _prepareVersion(
    StellarAddress owner,
    OwnedStudioDraft draft,
    StudioDeployRow current,
    String snapshot,
    int next,
  ) async {
    final agentId = current.registryAgentId;
    if (agentId == null) throw _chain();
    final hash = manifestHash(draft.manifest);
    final sequence = await _accounts.sequenceOf(owner);
    final validUntil = _nowSeconds + _validitySeconds;
    final spec = EnvelopeSpec(
      source: owner,
      accountSequence: sequence,
      contract: _stellar.identityRegistry,
      function: 'set_metadata',
      args: setMetadataArgs(
        caller: owner,
        agentId: agentId,
        key: 'manifestHash',
        value: hash,
      ),
      inclusionFee: _inclusionFee,
      validUntil: validUntil,
    );
    final simulation = await _accounts.simulate(spec);
    final PreparedEnvelope envelope;
    try {
      envelope = _codec.build(spec, simulation);
    } on UnsupportedAuthorization {
      throw _chain();
    }
    return _deploys.save(
      current.copy(
        state: 'awaitingRegistrationSignature',
        preparationId: _newPreparationId(),
        unsignedEnvelopeXdr: envelope.envelopeXdr,
        walletAuthJson: versionUpdateJson(version: next, manifestJson: snapshot),
        expiresAt: _expiry(validUntil),
        clearAuthorization: true,
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
  }

  /// The second signature: `puls3.manifestVersion`. Prepared only after the
  /// hash transaction has confirmed, so a failed version leaves the chain
  /// on the previous number.
  Future<StudioDeployRow> _prepareManifestVersion(StudioDeployRow row) async {
    final update = versionUpdateOf(row.walletAuthJson);
    final agentId = row.registryAgentId;
    if (update == null || agentId == null) return _failedTx(row, 6);
    final owner = StellarAddress.parse(row.owner);
    final sequence = await _accounts.sequenceOf(owner);
    final validUntil = _nowSeconds + _validitySeconds;
    final spec = EnvelopeSpec(
      source: owner,
      accountSequence: sequence,
      contract: _stellar.identityRegistry,
      function: 'set_metadata',
      args: setMetadataArgs(
        caller: owner,
        agentId: agentId,
        key: 'puls3.manifestVersion',
        value: Uint8List.fromList(utf8.encode('${update.version}')),
      ),
      inclusionFee: _inclusionFee,
      validUntil: validUntil,
    );
    final simulation = await _accounts.simulate(spec);
    final PreparedEnvelope envelope;
    try {
      envelope = _codec.build(spec, simulation);
    } on UnsupportedAuthorization {
      return _failedTx(row, 6);
    }
    return _deploys.save(
      row.copy(
        state: 'awaitingWalletAuthorization',
        preparationId: _newPreparationId(),
        unsignedEnvelopeXdr: envelope.envelopeXdr,
        expiresAt: _expiry(validUntil),
        clearAuthorization: true,
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
  }

  Future<StudioDeployRow> _submitVersionMetadata(
    StudioDeployRow row,
    StellarAddress owner,
    String signedTransactionXdr,
  ) async {
    _requireFresh(row);
    final unsigned = row.unsignedEnvelopeXdr;
    if (unsigned == null || row.state != 'awaitingWalletAuthorization') {
      throw _api('PreparationNotFound');
    }
    _verifyRegistration(unsigned, owner, signedTransactionXdr);
    final signed = _codec.parse(signedTransactionXdr);
    final submitted = await _deploys.save(
      row.copy(
        state: 'walletAuthorizationSubmitted',
        walletTxHash: signed.hashHex,
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
    await _send(signedTransactionXdr);
    return await _refresh(submitted) ?? submitted;
  }

  Future<StudioDeployRow?> _refresh(StudioDeployRow? row) async {
    if (row == null) return null;
    if (row.state == 'publishing') return _publish(row);
    final updating = versionUpdateOf(row.walletAuthJson) != null;
    final hash = switch (row.state) {
      'registrationSubmitted' =>
        updating ? row.walletTxHash : row.registrationHash,
      'walletAuthorizationSubmitted' => row.walletTxHash,
      _ => null,
    };
    if (hash == null) return row;
    final ChainTx tx;
    try {
      tx = await _transactions.read(hash);
    } on LedgerException {
      return row;
    } on Puls3ApiException {
      return row;
    }
    if (tx.status == ChainTxStatus.pending) return row;
    if (row.state == 'registrationSubmitted') {
      if (tx.status == ChainTxStatus.success && updating) {
        return _prepareManifestVersion(row);
      }
      if (tx.status == ChainTxStatus.success && tx.agentId != null) {
        return _deploys.save(
          row.copy(
            state: 'awaitingWalletAuthorization',
            registryAgentId: tx.agentId,
            clearFailure: true,
            updatedAt: _now().toUtc(),
          ),
        );
      }
      return _failedTx(row, 6);
    }
    if (tx.status == ChainTxStatus.success) return _publish(row);
    return _failedTx(row, 7);
  }

  Future<StudioDeployRow> _failedTx(StudioDeployRow row, int step) =>
      _deploys.save(
        row.copy(
          state: 'failed',
          failureCode: 'TransactionFailed',
          retryFromStep: step,
          updatedAt: _now().toUtc(),
        ),
      );

  Future<StudioDeployRow> _publish(StudioDeployRow row) async {
    if (row.state == 'active') return row;
    final update = versionUpdateOf(row.walletAuthJson);
    final raw = update?.manifestJson ?? row.manifestJson;
    final version = update?.version ?? ManifestVersion.first.value;
    if (raw == null || row.registryAgentId == null) {
      return _publicationFailed(row);
    }
    final publishing = row.state == 'publishing'
        ? row
        : await _deploys.save(
            row.copy(
              state: 'publishing',
              clearFailure: true,
              updatedAt: _now().toUtc(),
            ),
          );
    try {
      final manifest = AgentManifestDraft.fromJson(
        jsonDecode(raw),
      ).validate(_policy, ManifestVersion(version));
      final encoded = jsonEncode(registrationDocument(manifest));
      if (encoded.contains(manifest.systemPrompt)) {
        return _publicationFailed(publishing);
      }
      await _versions.save(
        AgentVersion(
          registryAgentId: row.registryAgentId!,
          version: version,
          owner: row.owner,
          manifestJson: raw,
          updatedAt: _now().toUtc(),
        ),
      );
      await _drafts.markLive(
        draftId: row.draftId,
        liveVersion: version,
        agentId: '${row.registryAgentId}',
      );
    } on InvalidManifest {
      return _publicationFailed(publishing);
    } on FormatException {
      return _publicationFailed(publishing);
    }
    return _deploys.save(
      publishing.copy(
        state: 'active',
        manifestJson: raw,
        clearFailure: true,
        updatedAt: _now().toUtc(),
      ),
    );
  }

  Future<StudioDeployRow> _publicationFailed(StudioDeployRow row) =>
      _deploys.save(
        row.copy(
          state: 'failed',
          failureCode: 'PublicationFailed',
          retryFromStep: 8,
          updatedAt: _now().toUtc(),
        ),
      );

  void _verifyRegistration(
    String unsignedXdr,
    StellarAddress owner,
    String signedXdr,
  ) {
    final SignedEnvelope signed;
    try {
      signed = _codec.parse(signedXdr);
    } on InvalidSignedEnvelope catch (e) {
      throw _api('InvalidSignedEnvelope', {'reason': e.reason.name});
    }
    final expected = _codec.parse(unsignedXdr).body;
    if (!_same(expected, signed.body)) {
      throw _api('EnvelopeMismatch', {
        'field':
            _codec.firstDifference(expected, signed.body) ??
            EnvelopeField.other,
      });
    }
    final check = _codec.verify(signed, owner, signed.hash);
    if (check != SignatureCheck.valid) {
      throw _api('InvalidTransactionSignature', {'reason': check.name});
    }
  }

  void _requireSignedEntry(String prepared, String signed, StellarAddress owner) {
    if (prepared == signed) throw _api('InvalidAuthorizationEntry');
    final AuthEntryView preparedView;
    final AuthEntryView signedView;
    try {
      preparedView = readAuthEntry(prepared);
      signedView = readAuthEntry(signed);
    } on FormatException {
      throw _api('InvalidAuthorizationEntry');
    }
    if (!signedView.covers(owner) ||
        !sameAuthorization(preparedView, signedView)) {
      throw _api('InvalidAuthorizationEntry');
    }
  }

  bool _reusableRegistration(StudioDeployRow row) {
    if (row.registryAgentId != null) return true;
    if (row.state == 'registrationSubmitted') return true;
    if (row.state == 'failed') return false;
    return row.state == 'awaitingRegistrationSignature' && _fresh(row);
  }

  bool _fresh(StudioDeployRow row) {
    final expiry = row.expiresAt;
    return expiry != null && _now().toUtc().isBefore(expiry);
  }

  void _requireFresh(StudioDeployRow row) {
    if (row.state == 'failed' && row.retryFromStep == 6) {
      throw _api('PreparationExpired', {'reason': 'timeBounds'});
    }
    if (!_fresh(row)) throw _api('PreparationExpired', {'reason': 'timeBounds'});
  }

  Future<StudioDeployRow> _requireRow(int draftId) async {
    final row = await _deploys.findByDraft(draftId);
    if (row == null) throw _api('PreparationNotFound');
    return row;
  }

  Future<void> _send(String envelopeXdr) async {
    try {
      await _sender.resend(envelopeXdr);
    } on LedgerException {
      // The record stays submitted. The next read looks the hash up.
    }
  }

  int get _nowSeconds => _now().toUtc().millisecondsSinceEpoch ~/ 1000;

  DateTime _expiry(int unixSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

  static Puls3ApiException _api(String code, [Map<String, String>? details]) =>
      Puls3ApiException(code: code, details: details);

  static Puls3ApiException _chain() => Puls3ApiException(
    code: 'ChainUnavailable',
    details: {'reason': 'simulationFailed'},
  );

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

String _randomPreparationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

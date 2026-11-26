import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// The contract call a signed envelope makes: the contract and the function
/// of its one `InvokeHostFunction` operation.
typedef InvokedCall = ({StellarAddress contract, String function});

/// The call a signed, base64 envelope makes, or `null` when it is not a
/// version 1 envelope with exactly one `InvokeHostFunction` operation that
/// invokes a contract (#307).
///
/// It only reads the envelope; it does not check signatures. Use it on
/// envelopes the server stored after the chain confirmed them.
InvokedCall? invokedCallOf(String signedEnvelopeBase64) {
  try {
    final envelope = stellar.Envelope.fromXdr(
      base64Decode(signedEnvelopeBase64),
    );
    if (envelope is! stellar.TransactionV1Envelope) return null;
    final operations = envelope.tx.operations;
    if (operations.length != 1) return null;
    final operation = operations.single.body;
    if (operation is! stellar.InvokeHostFunctionOperation) return null;
    final function = operation.hostFunction;
    if (function is! stellar.HostFunctionTypeInvokeContract) return null;
    final call = function.args;
    return (
      contract: StellarAddress.parse(call.contractAddress.address.baseAddress),
      function: call.functionName.value,
    );
  } on Object {
    return null;
  }
}

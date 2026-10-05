// The stellar_flutter_sdk 3.8.0 barrel also exports its smart-account
// helpers, which import `package:flutter/services.dart` and therefore
// `dart:ui`. The plain Dart VM (`dart run`) cannot load `dart:ui`, so code
// shared with the RPC harness imports only the Flutter-free SDK libraries it
// needs from here. The SDK version is pinned exactly in pubspec.yaml, which
// keeps these `src/` paths stable; revisit this list on every SDK upgrade.
// ignore_for_file: implementation_imports
library;

export 'package:stellar_flutter_sdk/src/account.dart';
export 'package:stellar_flutter_sdk/src/assets.dart';
export 'package:stellar_flutter_sdk/src/key_pair.dart';
export 'package:stellar_flutter_sdk/src/muxed_account.dart';
export 'package:stellar_flutter_sdk/src/payment_operation.dart';
export 'package:stellar_flutter_sdk/src/soroban/soroban_ledger_event_responses.dart';
export 'package:stellar_flutter_sdk/src/soroban/soroban_rpc_requests.dart';
export 'package:stellar_flutter_sdk/src/soroban/soroban_server.dart';
export 'package:stellar_flutter_sdk/src/soroban/soroban_transaction_responses.dart';
export 'package:stellar_flutter_sdk/src/transaction.dart';
export 'package:stellar_flutter_sdk/src/xdr/xdr.dart';

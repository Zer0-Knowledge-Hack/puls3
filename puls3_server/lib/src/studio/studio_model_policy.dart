import 'package:puls3_domain/puls3_domain.dart';

/// The models the Studio accepts. Mirrors the app's `studioModelPolicy`.
/// Mistral Small 3.1 is the free model that calls tools, so it can
/// subcontract (`workersAiToolModels`, #334 T8.0).
final studioServerModelPolicy = ModelPolicy(
  workersAiModels: {
    '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    '@cf/mistralai/mistral-small-3.1-24b-instruct',
  },
  paidProviders: {'anthropic'},
);

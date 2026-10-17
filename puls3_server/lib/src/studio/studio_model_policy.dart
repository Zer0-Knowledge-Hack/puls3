import 'package:puls3_domain/puls3_domain.dart';

/// The models the Studio accepts. Mirrors the app's `studioModelPolicy`.
final studioServerModelPolicy = ModelPolicy(
  workersAiModels: {'@cf/meta/llama-3.3-70b-instruct-fp8-fast'},
  paidProviders: {'anthropic'},
);

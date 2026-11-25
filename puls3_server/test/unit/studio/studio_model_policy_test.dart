import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/runtime/adapters/workers_ai_runtime.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:test/test.dart';

void main() {
  bool allows(String provider, String id) =>
      studioServerModelPolicy.allows(ModelId(provider: provider, id: id));

  test('the Studio accepts the free Workers AI models and any Anthropic '
      'model', () {
    expect(
      allows('workers-ai', '@cf/meta/llama-3.3-70b-instruct-fp8-fast'),
      isTrue,
    );
    expect(
      allows('workers-ai', '@cf/mistralai/mistral-small-3.1-24b-instruct'),
      isTrue,
    );
    expect(allows('anthropic', 'claude-sonnet-5-5'), isTrue);
    expect(allows('workers-ai', '@cf/zai-org/glm-4.7-flash'), isFalse);
    expect(allows('openai', 'gpt-x'), isFalse);
  });

  test('every Workers AI model that calls tools can be deployed (#334 '
      'T8.0)', () {
    for (final id in workersAiToolModels) {
      expect(allows('workers-ai', id), isTrue, reason: id);
    }
  });
}

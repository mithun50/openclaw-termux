import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw/models/ai_provider.dart';

void main() {
  group('Ollama provider (#117)', () {
    test('is registered', () {
      expect(AiProvider.all.map((p) => p.id), contains('ollama'));
    });

    test('uses the native Ollama API URL, never the /v1 path', () {
      // OpenClaw talks to Ollama's native /api/chat endpoint. A /v1 base URL
      // selects OpenAI-compatible mode, where tool calling is unreliable.
      expect(AiProvider.ollama.baseUrl, 'http://127.0.0.1:11434');
      expect(AiProvider.ollama.baseUrl.endsWith('/v1'), isFalse);
    });

    test('pins api=ollama so native tool calling is guaranteed', () {
      expect(AiProvider.ollama.api, 'ollama');
    });

    test('needs no user-supplied API key but has a placeholder', () {
      expect(AiProvider.ollama.requiresApiKey, isFalse);
      expect(AiProvider.ollama.defaultApiKey, isNotNull);
      expect(AiProvider.ollama.defaultApiKey, isNotEmpty);
    });

    test('allows the host to be changed and sets a cold-start timeout', () {
      expect(AiProvider.ollama.editableBaseUrl, isTrue);
      expect(AiProvider.ollama.timeoutSeconds, greaterThan(0));
    });
  });

  group('hosted providers keep their existing contract', () {
    test('all still require an API key and preserve their API contract', () {
      for (final provider in AiProvider.all.where((p) => p.id != 'ollama')) {
        expect(provider.requiresApiKey, isTrue, reason: provider.id);
        expect(provider.api, provider.id == 'minimax' ? 'openai-completions' : null,
            reason: provider.id);
        expect(provider.editableBaseUrl, isFalse, reason: provider.id);
      }
    });

    test('every provider has a non-empty id, base URL and model list', () {
      for (final provider in AiProvider.all) {
        expect(provider.id, isNotEmpty);
        expect(provider.baseUrl, startsWith('http'));
        expect(provider.defaultModels, isNotEmpty, reason: provider.id);
      }
    });

    test('provider ids are unique', () {
      final ids = AiProvider.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}

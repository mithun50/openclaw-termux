import 'dart:convert';
import '../models/ai_provider.dart';
import 'native_bridge.dart';

/// Reads and writes AI provider configuration in openclaw.json.
class ProviderConfigService {
  static const _configPath = '/root/.openclaw/openclaw.json';

  /// Escape a string for use as a single-quoted shell argument.
  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  /// Read the current config and return a map with:
  /// - `activeModel`: the current primary model string (or null)
  /// - `providers`: `Map<providerId, {apiKey, model}>` for configured providers
  static Future<Map<String, dynamic>> readConfig() async {
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content == null || content.isEmpty) {
        return {'activeModel': null, 'providers': <String, dynamic>{}};
      }
      final config = jsonDecode(content) as Map<String, dynamic>;

      // Extract active model
      String? activeModel;
      final agents = config['agents'] as Map<String, dynamic>?;
      if (agents != null) {
        final defaults = agents['defaults'] as Map<String, dynamic>?;
        if (defaults != null) {
          final model = defaults['model'] as Map<String, dynamic>?;
          if (model != null) {
            activeModel = model['primary'] as String?;
          }
        }
      }

      // Extract configured providers
      final providers = <String, dynamic>{};
      final modelsSection = config['models'] as Map<String, dynamic>?;
      if (modelsSection != null) {
        final providerEntries = modelsSection['providers'] as Map<String, dynamic>?;
        if (providerEntries != null) {
          for (final entry in providerEntries.entries) {
            providers[entry.key] = entry.value;
          }
        }
      }

      return {'activeModel': activeModel, 'providers': providers};
    } catch (_) {
      return {'activeModel': null, 'providers': <String, dynamic>{}};
    }
  }

  /// Save a provider's API key and set its model as the active model.
  /// Tries a Node.js one-liner in proot first, then falls back to a direct
  /// file write via NativeBridge.writeRootfsFile if proot/DNS is unavailable.
  ///
  /// [baseUrlOverride] lets the user point a provider at a different host
  /// (used by Ollama, whose daemon may live on the LAN).
  static Future<void> saveProviderConfig({
    required AiProvider provider,
    required String apiKey,
    required String model,
    String? baseUrlOverride,
  }) async {
    // Local runtimes such as Ollama need no real credential, but OpenClaw
    // wants a non-empty value for availability checks.
    final effectiveKey = apiKey.trim().isEmpty
        ? (provider.defaultApiKey ?? '')
        : apiKey.trim();
    final effectiveBaseUrl =
        (baseUrlOverride != null && baseUrlOverride.trim().isNotEmpty)
            ? _normalizeBaseUrl(provider, baseUrlOverride.trim())
            : provider.baseUrl;
    // Saved MiniMax references already include the provider prefix. The model
    // entry needs the API model ID, while the active reference keeps its prefix.
    final modelId = provider.id == 'minimax' && model.startsWith('minimax/')
        ? model.substring('minimax/'.length)
        : model;
    // Model refs are provider-qualified for providers with an explicit api
    // flavour (e.g. `ollama/qwen3:8b`).
    final modelRef = provider.api != null ? '${provider.id}/$modelId' : modelId;

    final providerIdJson = jsonEncode(provider.id);
    final apiKeyJson = jsonEncode(effectiveKey);
    final baseUrlJson = jsonEncode(effectiveBaseUrl);
    final modelJson = jsonEncode(modelId);
    final modelRefJson = jsonEncode(modelRef);
    final apiJson = provider.api != null ? jsonEncode(provider.api) : null;
    final timeoutJson = provider.timeoutSeconds?.toString();

    // Build the provider object with the model as an object containing `id`,
    // not a bare string. OpenClaw expects: models: [{ id: "model-name" }].
    // Writing a bare string causes config validation failure (#83, #88).
    final script = '''
const fs = require("fs");
const p = "$_configPath";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.models) c.models = {};
if (!c.models.providers) c.models.providers = {};
c.models.providers[$providerIdJson] = {
  apiKey: $apiKeyJson,
  baseUrl: $baseUrlJson,
${apiJson != null ? '  api: $apiJson,\n' : ''}${timeoutJson != null ? '  timeoutSeconds: $timeoutJson,\n' : ''}  models: [{ id: $modelJson, name: $modelJson }]
};
if (!c.agents) c.agents = {};
if (!c.agents.defaults) c.agents.defaults = {};
if (!c.agents.defaults.model) c.agents.defaults.model = {};
c.agents.defaults.model.primary = $modelRefJson;
if (!c.gateway) c.gateway = {};
if (!c.gateway.mode) c.gateway.mode = "local";
fs.mkdirSync(require("path").dirname(p), { recursive: true });
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
    } catch (_) {
      // Fallback: write config directly via NativeBridge file I/O
      await _saveConfigDirect(
        provider: provider,
        apiKey: effectiveKey,
        baseUrl: effectiveBaseUrl,
        model: modelId,
        modelRef: modelRef,
      );
    }
  }

  /// Ollama's native API must not carry a `/v1` suffix - that path selects
  /// OpenAI-compatible mode, where tool calling is unreliable.
  static String _normalizeBaseUrl(AiProvider provider, String url) {
    var normalized = url;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (provider.api == 'ollama' && normalized.endsWith('/v1')) {
      normalized = normalized.substring(0, normalized.length - 3);
    }
    return normalized;
  }

  /// Direct file-write fallback that doesn't depend on proot or DNS.
  static Future<void> _saveConfigDirect({
    required AiProvider provider,
    required String apiKey,
    required String baseUrl,
    required String model,
    required String modelRef,
  }) async {
    Map<String, dynamic> config = {};
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content != null && content.isNotEmpty) {
        config = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {
      // Start fresh
    }

    // Merge provider entry - models must be objects with `id`, not bare strings (#83, #88).
    config['models'] ??= <String, dynamic>{};
    (config['models'] as Map<String, dynamic>)['providers'] ??= <String, dynamic>{};
    ((config['models'] as Map<String, dynamic>)['providers'] as Map<String, dynamic>)[provider.id] = {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      if (provider.api != null) 'api': provider.api,
      if (provider.timeoutSeconds != null)
        'timeoutSeconds': provider.timeoutSeconds,
      'models': [{'id': model, 'name': model}],
    };

    // Set active model
    config['agents'] ??= <String, dynamic>{};
    (config['agents'] as Map<String, dynamic>)['defaults'] ??= <String, dynamic>{};
    ((config['agents'] as Map<String, dynamic>)['defaults'] as Map<String, dynamic>)['model'] ??= <String, dynamic>{};
    (((config['agents'] as Map<String, dynamic>)['defaults'] as Map<String, dynamic>)['model'] as Map<String, dynamic>)['primary'] = modelRef;

    // Ensure gateway.mode is set (#93, #90)
    config['gateway'] ??= <String, dynamic>{};
    (config['gateway'] as Map<String, dynamic>)['mode'] ??= 'local';

    const encoder = JsonEncoder.withIndent('  ');
    await NativeBridge.writeRootfsFile(_configPath, encoder.convert(config));
  }

  /// Remove a provider's config entry and clear the active model if it
  /// belonged to this provider.
  static Future<void> removeProviderConfig({
    required AiProvider provider,
  }) async {
    final providerIdJson = jsonEncode(provider.id);
    // Build a list of this provider's known model names so we can clear
    // the active model if it matches one of them.
    final modelsJson = jsonEncode(provider.knownModels.toList());

    final script = '''
const fs = require("fs");
const p = "$_configPath";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (c.models && c.models.providers) {
  delete c.models.providers[$providerIdJson];
}
const known = $modelsJson;
if (c.agents && c.agents.defaults && c.agents.defaults.model) {
  const cur = c.agents.defaults.model.primary;
  if (cur && known.some(m => cur.includes(m))) {
    delete c.agents.defaults.model.primary;
  }
}
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    await NativeBridge.runInProot(
      'node -e ${_shellEscape(script)}',
      timeout: 15,
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Metadata for an AI model provider that can be configured
/// to power the OpenClaw gateway.
class AiProvider {
  final String id;
  final String nameKey;
  final String descriptionKey;
  final IconData icon;
  final Color color;
  final String baseUrl;
  final List<String> defaultModels;
  final String apiKeyHint;
  final bool supportsCustomBaseUrl;

  const AiProvider({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.icon,
    required this.color,
    required this.baseUrl,
    required this.defaultModels,
    required this.apiKeyHint,
    this.supportsCustomBaseUrl = false,
  });

  String name(AppLocalizations l10n) => l10n.t(nameKey);

  String description(AppLocalizations l10n) => l10n.t(descriptionKey);

  bool matchesModel(String model) {
    return defaultModels.any((candidate) => model.contains(candidate)) ||
        model.contains(id);
  }

  static const anthropic = AiProvider(
    id: 'anthropic',
    nameKey: 'providerNameAnthropic',
    descriptionKey: 'providerDescriptionAnthropic',
    icon: Icons.psychology,
    color: Color(0xFFD97706),
    baseUrl: 'https://api.anthropic.com/v1',
    defaultModels: [
      'claude-sonnet-4-20250514',
      'claude-opus-4-20250514',
      'claude-haiku-4-20250506',
      'claude-3-5-sonnet-20241022',
    ],
    apiKeyHint: 'sk-ant-...',
  );

  static const openai = AiProvider(
    id: 'openai',
    nameKey: 'providerNameOpenai',
    descriptionKey: 'providerDescriptionOpenai',
    icon: Icons.auto_awesome,
    color: Color(0xFF10A37F),
    baseUrl: 'https://api.openai.com/v1',
    defaultModels: [
      'gpt-4o',
      'gpt-4o-mini',
      'o1',
      'o1-mini',
      'gpt-4-turbo',
    ],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
  );

  static const google = AiProvider(
    id: 'google',
    nameKey: 'providerNameGoogle',
    descriptionKey: 'providerDescriptionGoogle',
    icon: Icons.diamond,
    color: Color(0xFF4285F4),
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    defaultModels: [
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
    ],
    apiKeyHint: 'AIza...',
  );

  static const openrouter = AiProvider(
    id: 'openrouter',
    nameKey: 'providerNameOpenrouter',
    descriptionKey: 'providerDescriptionOpenrouter',
    icon: Icons.route,
    color: Color(0xFF6366F1),
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModels: [
      'anthropic/claude-sonnet-4',
      'openai/gpt-4o',
      'google/gemini-2.5-pro',
      'meta-llama/llama-3.1-405b-instruct',
    ],
    apiKeyHint: 'sk-or-...',
  );

  static const nvidia = AiProvider(
    id: 'nvidia',
    nameKey: 'providerNameNvidia',
    descriptionKey: 'providerDescriptionNvidia',
    icon: Icons.memory,
    color: Color(0xFF76B900),
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    defaultModels: [
      'meta/llama-3.1-405b-instruct',
      'meta/llama-3.1-70b-instruct',
      'meta/llama-3.3-70b-instruct',
      'nvidia/nemotron-4-340b-instruct',
      'deepseek-ai/deepseek-r1',
    ],
    apiKeyHint: 'nvapi-...',
  );

  static const deepseek = AiProvider(
    id: 'deepseek',
    nameKey: 'providerNameDeepseek',
    descriptionKey: 'providerDescriptionDeepseek',
    icon: Icons.explore,
    color: Color(0xFF0EA5E9),
    baseUrl: 'https://api.deepseek.com/v1',
    defaultModels: [
      'deepseek-chat',
      'deepseek-reasoner',
    ],
    apiKeyHint: 'sk-...',
  );

  static const xai = AiProvider(
    id: 'xai',
    nameKey: 'providerNameXai',
    descriptionKey: 'providerDescriptionXai',
    icon: Icons.bolt,
    color: Color(0xFFEF4444),
    baseUrl: 'https://api.x.ai/v1',
    defaultModels: [
      'grok-3',
      'grok-3-mini',
      'grok-2',
    ],
    apiKeyHint: 'xai-...',
  );

  static const qwen = AiProvider(
    id: 'qwen',
    nameKey: 'providerNameQwen',
    descriptionKey: 'providerDescriptionQwen',
    icon: Icons.cloud,
    color: Color(0xFF2563EB),
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModels: [
      'qwen-max',
      'qwen-plus',
      'qwen-turbo',
      'qwen3-coder-plus',
    ],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
  );

  static const minimax = AiProvider(
    id: 'minimax',
    nameKey: 'providerNameMinimax',
    descriptionKey: 'providerDescriptionMinimax',
    icon: Icons.forum,
    color: Color(0xFFEC4899),
    baseUrl: 'https://api.minimax.chat/v1',
    defaultModels: [
      'MiniMax-Text-01',
      'MiniMax-M1',
      'abab7.5-chat',
    ],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
  );

  static const doubao = AiProvider(
    id: 'doubao',
    nameKey: 'providerNameDoubao',
    descriptionKey: 'providerDescriptionDoubao',
    icon: Icons.token,
    color: Color(0xFFEA580C),
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModels: [
      'doubao-seed-2-0-pro-260215',
      'doubao-seed-2-0-lite-260215',
      'doubao-seed-2-0-mini-260215',
      'doubao-seed-1-8-251228',
    ],
    apiKeyHint: 'ark-...',
    supportsCustomBaseUrl: true,
  );

  /// All available AI providers.
  static const all = [
    anthropic,
    openai,
    qwen,
    minimax,
    doubao,
    google,
    openrouter,
    nvidia,
    deepseek,
    xai,
  ];
}

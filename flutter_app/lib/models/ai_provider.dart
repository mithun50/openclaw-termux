import 'package:flutter/material.dart';

/// Metadata for an AI model provider that can be configured
/// to power the OpenClaw gateway.
class AiProvider {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String baseUrl;
  final List<String> defaultModels;
  final String apiKeyHint;

  const AiProvider({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.baseUrl,
    required this.defaultModels,
    required this.apiKeyHint,
  });

  static const anthropic = AiProvider(
    id: 'anthropic',
    name: 'Anthropic',
    description: 'Claude models �?advanced reasoning and coding',
    icon: Icons.psychology,
    color: Color(0xFFD97706),
    baseUrl: 'https://api.anthropic.com/v1',
    defaultModels: [
      'claude-sonnet-4-20250514',
      'claude-opus-4-20250514',
      'claude-haiku-4-20250506',
    ],
    apiKeyHint: 'sk-ant-...',
  );

  static const openai = AiProvider(
    id: 'openai',
    name: 'OpenAI',
    description: 'GPT and o-series models',
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
  );

  static const google = AiProvider(
    id: 'google',
    name: 'Google Gemini',
    description: 'Gemini family of multimodal models',
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
    name: 'OpenRouter',
    description: 'Unified API for hundreds of models',
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
    name: 'NVIDIA NIM',
    description: 'GPU-optimized inference endpoints',
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
    name: 'DeepSeek',
    description: 'High-performance open models',
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
    name: 'xAI',
    description: 'Grok models from xAI',
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

  static const custom = AiProvider(
    id: 'custom',
    name: 'Custom / CLIProxy',
    description: 'Any OpenAI-compatible API (e.g. CLIProxy on port 18790)',
    icon: Icons.tune,
    color: Color(0xFF8B5CF6),
    baseUrl: 'http://127.0.0.1:18790/v1',
    defaultModels: [
      'claude-sonnet-4-20250514',
      'gemini-2.5-pro',
      'gpt-4o',
    ],
    apiKeyHint: 'your-api-key (or any string if not required)',
  );

  /// All available AI providers.
  static const all = [
    anthropic,
    openai,
    google,
    openrouter,
    nvidia,
    deepseek,
    xai,
    custom
  ];
}

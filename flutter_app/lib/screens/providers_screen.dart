import 'package:flutter/material.dart';
import '../app.dart';
import '../l10n/app_localizations.dart';
import '../models/ai_provider.dart';
import '../services/provider_config_service.dart';
import 'provider_detail_screen.dart';

/// Lists all AI providers with their configuration status.
class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  String? _activeModel;
  Map<String, dynamic> _providers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final config = await ProviderConfigService.readConfig();
    if (mounted) {
      setState(() {
        _activeModel = config['activeModel'] as String?;
        _providers = config['providers'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    }
  }

  Future<void> _openProvider(AiProvider provider) async {
    final providerConfig = _providers[provider.id] as Map<String, dynamic>?;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProviderDetailScreen(
          provider: provider,
          existingApiKey: providerConfig?['apiKey'] as String?,
          existingBaseUrl: providerConfig?['baseUrl'] as String?,
          existingModel: providerConfig?['model'] as String? ?? _activeModel,
        ),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  ({String label, bool isActive}) _statusInfo(AiProvider provider) {
    final l10n = context.l10n;
    final isConfigured = _providers.containsKey(provider.id);
    if (!isConfigured) {
      return (label: '', isActive: false);
    }

    final providerConfig = _providers[provider.id] as Map<String, dynamic>?;
    final configuredModel = providerConfig?['model'] as String?;
    if (_activeModel != null) {
      final isActive = configuredModel == _activeModel ||
          provider.matchesModel(_activeModel!);
      if (isActive) {
        return (label: l10n.t('providersStatusActive'), isActive: true);
      }
    }
    return (
      label: l10n.t('providersStatusConfigured'),
      isActive: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('providersScreenTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Active model card
                if (_activeModel != null && _activeModel!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.statusGreen.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.statusGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('providersScreenActiveModel'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.statusGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _activeModel!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  l10n.t('providersScreenIntro'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final provider in AiProvider.all)
                  _buildProviderCard(theme, provider, isDark),
              ],
            ),
    );
  }

  Widget _buildProviderCard(ThemeData theme, AiProvider provider, bool isDark) {
    final iconBg = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF3F4F6);
    final status = _statusInfo(provider);
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openProvider(provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(provider.icon, color: provider.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          provider.name(l10n),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (status.label.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (status.isActive
                                      ? AppColors.statusGreen
                                      : AppColors.statusAmber)
                                  .withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: status.isActive
                                    ? AppColors.statusGreen
                                    : AppColors.statusAmber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description(l10n),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

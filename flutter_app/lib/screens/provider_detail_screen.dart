import 'package:flutter/material.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../models/ai_provider.dart';
import '../services/provider_config_service.dart';
import '../utils/responsive.dart';

class ProviderDetailScreen extends StatefulWidget {
  final AiProvider provider;
  final String? existingApiKey;
  final String? existingModel;

  const ProviderDetailScreen({
    super.key,
    required this.provider,
    this.existingApiKey,
    this.existingModel,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  static const _customModelSentinel = '__custom__';

  late final TextEditingController _apiKeyController;
  late final TextEditingController _customModelController;
  late final TextEditingController _baseUrlController;
  late String _selectedModel;
  bool _isCustomModel = false;
  bool _obscureKey = true;
  bool _saving = false;
  bool _removing = false;

  bool get _isCustomProvider => widget.provider.id == 'custom';

  bool get _isConfigured =>
      widget.existingApiKey != null && widget.existingApiKey!.isNotEmpty;

  String get _effectiveModel =>
      _isCustomModel ? _customModelController.text.trim() : _selectedModel;

  String get _effectiveBaseUrl => _isCustomProvider
      ? _baseUrlController.text.trim()
      : widget.provider.baseUrl;

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: widget.existingApiKey ?? '');
    _customModelController = TextEditingController();
    _baseUrlController = TextEditingController(text: widget.provider.baseUrl);

    final existing =
        widget.existingModel ?? widget.provider.defaultModels.first;
    if (widget.provider.defaultModels.contains(existing)) {
      _selectedModel = existing;
    } else {
      _selectedModel = _customModelSentinel;
      _isCustomModel = true;
      _customModelController.text = existing;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.apiKeyEmpty)),
      );
      return;
    }
    final model = _effectiveModel;
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.modelEmpty)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ProviderConfigService.saveProviderConfig(
        provider: widget.provider,
        apiKey: apiKey,
        model: model,
        baseUrl: _effectiveBaseUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${widget.provider.name} ${AppStrings.configuredAndActivated}')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.saveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppStrings.removeProvider} ${widget.provider.name}?'),
        content: Text(AppStrings.removeProviderContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await ProviderConfigService.removeProviderConfig(
          provider: widget.provider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${widget.provider.name} ${AppStrings.remove}')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.removeFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF3F4F6);

    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.name)),
      body: Responsive.constrain(
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                      child: Icon(widget.provider.icon,
                          color: widget.provider.color),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.provider.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.provider.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Base URL - 仅 custom 提供商可编辑，其他只读显示
            Text(
              'Base URL',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              readOnly: !_isCustomProvider,
              decoration: InputDecoration(
                hintText: 'http://127.0.0.1:18790/v1',
                helperText: _isCustomProvider ? AppStrings.baseUrlHelper : null,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.apiKey,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: widget.provider.apiKeyHint,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.model,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                ...widget.provider.defaultModels
                    .map((m) => DropdownMenuItem(value: m, child: Text(m))),
                DropdownMenuItem(
                  value: _customModelSentinel,
                  child: Text(AppStrings.customModel),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedModel = value;
                    _isCustomModel = value == _customModelSentinel;
                  });
                }
              },
            ),
            if (_isCustomModel) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customModelController,
                decoration: InputDecoration(
                  hintText: AppStrings.customModelHint,
                  labelText: AppStrings.customModelLabel,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(AppStrings.saveAndActivate),
            ),
            if (_isConfigured) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _removing ? null : _remove,
                child: _removing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.removeConfiguration),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

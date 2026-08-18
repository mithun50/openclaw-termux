import 'package:flutter/material.dart';
import '../app.dart';
import '../models/ai_provider.dart';
import '../services/provider_config_service.dart';

/// Form screen to configure API key and model for a single AI provider.
class ProviderDetailScreen extends StatefulWidget {
  final AiProvider provider;
  final String? existingApiKey;
  final String? existingModel;
  final String? existingBaseUrl;

  const ProviderDetailScreen({
    super.key,
    required this.provider,
    this.existingApiKey,
    this.existingModel,
    this.existingBaseUrl,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  static const _customModelSentinel = '__custom__';

  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _customModelController;
  late String _selectedModel;
  bool _isCustomModel = false;
  bool _obscureKey = true;
  bool _saving = false;
  bool _removing = false;

  bool get _isConfigured => widget.existingApiKey != null && widget.existingApiKey!.isNotEmpty;

  /// Returns the effective model name to save.
  String get _effectiveModel =>
      _isCustomModel ? _customModelController.text.trim() : _selectedModel;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.existingApiKey ?? '');
    _baseUrlController = TextEditingController(
      text: widget.existingBaseUrl ?? widget.provider.baseUrl,
    );
    _customModelController = TextEditingController();

    final existing = widget.existingModel ?? widget.provider.defaultModels.first;
    if (widget.provider.defaultModels.contains(existing)) {
      _selectedModel = existing;
    } else {
      // Existing model is not in the predefined list — treat as custom
      _selectedModel = _customModelSentinel;
      _isCustomModel = true;
      _customModelController.text = existing;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key cannot be empty')),
      );
      return;
    }
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL cannot be empty')),
      );
      return;
    }
    final model = _effectiveModel;
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model name cannot be empty')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ProviderConfigService.saveProviderConfig(
        provider: widget.provider,
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.provider.name} configured and activated')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
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
        title: Text('Remove ${widget.provider.name}?'),
        content: const Text('This will delete the API key and deactivate the model.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await ProviderConfigService.removeProviderConfig(provider: widget.provider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.provider.name} removed')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider header
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
                    child: Icon(widget.provider.icon, color: widget.provider.color),
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

          // API Key
          Text(
            'API Key',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              hintText: widget.provider.apiKeyHint,
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // API URL
          Text(
            'API URL',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com/v1',
            ),
          ),
          const SizedBox(height: 24),

          // Model selection
          Text(
            'Model',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedModel,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              ...widget.provider.defaultModels
                  .map((m) => DropdownMenuItem(value: m, child: Text(m))),
              const DropdownMenuItem(
                value: _customModelSentinel,
                child: Text('Custom...'),
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
              decoration: const InputDecoration(
                hintText: 'e.g. meta/llama-3.3-70b-instruct',
                labelText: 'Custom model name',
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Actions
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save & Activate'),
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
                  : const Text('Remove Configuration'),
            ),
          ],
        ],
      ),
    );
  }
}

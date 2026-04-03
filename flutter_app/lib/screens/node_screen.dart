import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../providers/node_provider.dart';
import '../services/preferences_service.dart';
import '../utils/responsive.dart';
import '../widgets/node_controls.dart';

class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

class _NodeScreenState extends State<NodeScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLocal = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = PreferencesService();
    await prefs.init();
    final host = prefs.nodeGatewayHost ?? '127.0.0.1';
    final port = prefs.nodeGatewayPort ?? 18789;
    final token = prefs.nodeGatewayToken ?? '';
    setState(() {
      _isLocal = host == '127.0.0.1' || host == 'localhost';
      _hostController.text = _isLocal ? '' : host;
      _portController.text = _isLocal ? '' : '$port';
      _tokenController.text = _isLocal ? '' : token;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.nodeConfiguration)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Responsive.constrain(
              Consumer<NodeProvider>(
                builder: (context, provider, _) {
                  final state = provider.state;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const NodeControls(),
                      const SizedBox(height: 16),
                      _sectionHeader(theme, AppStrings.gatewayConnection),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioListTile<bool>(
                                title: Text(AppStrings.localGateway),
                                subtitle: Text(AppStrings.localGatewaySubtitle),
                                value: true,
                                groupValue: _isLocal,
                                onChanged: (v) => setState(() => _isLocal = v!),
                              ),
                              RadioListTile<bool>(
                                title: Text(AppStrings.remoteGateway),
                                subtitle:
                                    Text(AppStrings.remoteGatewaySubtitle),
                                value: false,
                                groupValue: _isLocal,
                                onChanged: (v) => setState(() => _isLocal = v!),
                              ),
                              if (!_isLocal) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _hostController,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.gatewayHost,
                                    hintText: '192.168.1.100',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _portController,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.gatewayPort,
                                    hintText: '18789',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _tokenController,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.gatewayToken,
                                    hintText: AppStrings.gatewayTokenHint,
                                    helperText: AppStrings.gatewayTokenHelper,
                                    prefixIcon: const Icon(Icons.key),
                                  ),
                                  obscureText: true,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () {
                                    final host = _hostController.text.trim();
                                    final port = int.tryParse(
                                            _portController.text.trim()) ??
                                        18789;
                                    final token = _tokenController.text.trim();
                                    if (host.isNotEmpty) {
                                      provider.connectRemote(host, port,
                                          token:
                                              token.isNotEmpty ? token : null);
                                    }
                                  },
                                  icon: const Icon(Icons.link),
                                  label: Text(AppStrings.connect),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (state.pairingCode != null) ...[
                        _sectionHeader(theme, AppStrings.pairing),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.qr_code, size: 48),
                                const SizedBox(height: 8),
                                Text(AppStrings.pairingPrompt,
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 8),
                                SelectableText(
                                  state.pairingCode!,
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _sectionHeader(theme, AppStrings.capabilities),
                      _capabilityTile(theme, AppStrings.capCamera,
                          AppStrings.capCameraDesc, Icons.camera_alt),
                      _capabilityTile(theme, AppStrings.capCanvas,
                          AppStrings.capCanvasDesc, Icons.web,
                          available: false),
                      _capabilityTile(theme, AppStrings.capLocation,
                          AppStrings.capLocationDesc, Icons.location_on),
                      _capabilityTile(theme, AppStrings.capScreen,
                          AppStrings.capScreenDesc, Icons.screen_share),
                      _capabilityTile(theme, AppStrings.capFlash,
                          AppStrings.capFlashDesc, Icons.flashlight_on),
                      _capabilityTile(theme, AppStrings.capVibration,
                          AppStrings.capVibrationDesc, Icons.vibration),
                      _capabilityTile(theme, AppStrings.capSensors,
                          AppStrings.capSensorsDesc, Icons.sensors),
                      _capabilityTile(theme, AppStrings.capSerial,
                          AppStrings.capSerialDesc, Icons.usb),
                      const SizedBox(height: 16),
                      if (state.deviceId != null) ...[
                        _sectionHeader(theme, AppStrings.deviceInfo),
                        ListTile(
                          title: Text(AppStrings.deviceId),
                          subtitle: SelectableText(
                            state.deviceId!,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                          leading: const Icon(Icons.fingerprint),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _sectionHeader(theme, AppStrings.nodeLogs),
                      Card(
                        child: Container(
                          height: 200,
                          padding: const EdgeInsets.all(12),
                          child: state.logs.isEmpty
                              ? Center(
                                  child: Text(
                                    AppStrings.noLogsYetNode,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  itemCount: state.logs.length,
                                  itemBuilder: (context, index) {
                                    final log = state
                                        .logs[state.logs.length - 1 - index];
                                    return Text(log,
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11));
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _capabilityTile(
      ThemeData theme, String title, String subtitle, IconData icon,
      {bool available = true}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: available
            ? const Icon(Icons.check_circle,
                color: AppColors.statusGreen, size: 20)
            : const Icon(Icons.block, color: AppColors.statusAmber, size: 20),
      ),
    );
  }
}

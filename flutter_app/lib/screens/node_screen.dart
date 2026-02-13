import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/node_provider.dart';
import '../services/preferences_service.dart';
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
      appBar: AppBar(title: const Text('Node Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<NodeProvider>(
              builder: (context, provider, _) {
                final state = provider.state;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const NodeControls(),
                    const SizedBox(height: 16),

                    // Gateway Connection
                    _sectionHeader(theme, 'Gateway Connection'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RadioListTile<bool>(
                              title: const Text('Local Gateway'),
                              subtitle: const Text('Auto-pair with gateway on this device'),
                              value: true,
                              groupValue: _isLocal,
                              onChanged: (value) {
                                setState(() => _isLocal = value!);
                              },
                            ),
                            RadioListTile<bool>(
                              title: const Text('Remote Gateway'),
                              subtitle: const Text('Connect to a gateway on another device'),
                              value: false,
                              groupValue: _isLocal,
                              onChanged: (value) {
                                setState(() => _isLocal = value!);
                              },
                            ),
                            if (!_isLocal) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'Gateway Host',
                                  hintText: '192.168.1.100',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _portController,
                                decoration: const InputDecoration(
                                  labelText: 'Gateway Port',
                                  hintText: '18789',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _tokenController,
                                decoration: const InputDecoration(
                                  labelText: 'Gateway Token',
                                  hintText: 'Paste token from gateway dashboard URL',
                                  helperText: 'Found in dashboard URL after #token=',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.key),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  final host = _hostController.text.trim();
                                  final port = int.tryParse(_portController.text.trim()) ?? 18789;
                                  final token = _tokenController.text.trim();
                                  if (host.isNotEmpty) {
                                    provider.connectRemote(host, port,
                                        token: token.isNotEmpty ? token : null);
                                  }
                                },
                                icon: const Icon(Icons.link),
                                label: const Text('Connect'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pairing Status
                    if (state.pairingCode != null) ...[
                      _sectionHeader(theme, 'Pairing'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.qr_code, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'Approve this code on the gateway:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                state.pairingCode!,
                                style: theme.textTheme.headlineMedium?.copyWith(
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

                    // Capabilities
                    _sectionHeader(theme, 'Capabilities'),
                    _capabilityTile(
                      theme,
                      'Camera',
                      'Capture photos and video clips',
                      Icons.camera_alt,
                    ),
                    _capabilityTile(
                      theme,
                      'Canvas',
                      'Navigate and interact with web pages',
                      Icons.web,
                    ),
                    _capabilityTile(
                      theme,
                      'Location',
                      'Get device GPS coordinates',
                      Icons.location_on,
                    ),
                    _capabilityTile(
                      theme,
                      'Screen Recording',
                      'Record device screen (requires consent each time)',
                      Icons.screen_share,
                    ),
                    _capabilityTile(
                      theme,
                      'Flashlight',
                      'Toggle device torch on/off',
                      Icons.flashlight_on,
                    ),
                    _capabilityTile(
                      theme,
                      'Vibration',
                      'Trigger haptic feedback and vibration patterns',
                      Icons.vibration,
                    ),
                    _capabilityTile(
                      theme,
                      'Sensors',
                      'Read accelerometer, gyroscope, magnetometer, barometer',
                      Icons.sensors,
                    ),
                    const SizedBox(height: 16),

                    // Device Info
                    if (state.deviceId != null) ...[
                      _sectionHeader(theme, 'Device Info'),
                      ListTile(
                        title: const Text('Device ID'),
                        subtitle: SelectableText(
                          state.deviceId!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        leading: const Icon(Icons.fingerprint),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Logs
                    _sectionHeader(theme, 'Node Logs'),
                    Card(
                      child: Container(
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        child: state.logs.isEmpty
                            ? Center(
                                child: Text(
                                  'No logs yet',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                itemCount: state.logs.length,
                                itemBuilder: (context, index) {
                                  final log = state.logs[state.logs.length - 1 - index];
                                  return Text(
                                    log,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _capabilityTile(
      ThemeData theme, String title, String subtitle, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.check_circle,
          color: theme.colorScheme.primary.withAlpha(150),
          size: 20,
        ),
      ),
    );
  }
}

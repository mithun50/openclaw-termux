import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../services/ssh_service.dart';
import 'packages_screen.dart';

/// SSH server management screen �?start/stop sshd, set password, show connection info.
class SshScreen extends StatefulWidget {
  const SshScreen({super.key});

  @override
  State<SshScreen> createState() => _SshScreenState();
}

class _SshScreenState extends State<SshScreen> {
  bool _loading = true;
  bool _installed = false;
  bool _running = false;
  bool _toggling = false;
  bool _settingPassword = false;

  final _portController = TextEditingController(text: '8022');
  final _passwordController = TextEditingController();
  List<String> _ips = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final installed = await SshService.isInstalled();
    bool running = false;
    List<String> ips = [];
    if (installed) {
      running = await SshService.isSshdRunning();
      // Always fetch IPs so user can see them before starting
      ips = await SshService.getIpAddresses();
      if (running) {
        final port = await SshService.getPort();
        if (mounted) _portController.text = port.toString();
      }
    }
    if (mounted) {
      setState(() {
        _installed = installed;
        _running = running;
        _ips = ips;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSshd() async {
    setState(() => _toggling = true);
    try {
      if (_running) {
        await SshService.stopSshd();
        // Give the service a moment to stop
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final port = int.tryParse(_portController.text.trim()) ?? 8022;
        await SshService.startSshd(port: port);
        // Give the service a moment to start
        await Future.delayed(const Duration(seconds: 2));
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _setPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password cannot be empty')),
      );
      return;
    }
    setState(() => _settingPassword = true);
    try {
      await SshService.setPassword(password);
      if (mounted) {
        _passwordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Root password updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set password: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingPassword = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('SSH Access')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _installed
              ? _buildInstalledView(theme, isDark)
              : _buildNotInstalledView(theme),
    );
  }

  Widget _buildNotInstalledView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'OpenSSH not installed',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Install the OpenSSH package first from the Packages screen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PackagesScreen()),
                );
                _refresh();
              },
              icon: const Icon(Icons.extension),
              label: const Text('Open Packages'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledView(ThemeData theme, bool isDark) {
    final port = _portController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Service control
        _sectionHeader(theme, 'SERVICE CONTROL'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_running ? AppColors.statusGreen : AppColors.statusGrey)
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _running ? Icons.check_circle : Icons.cancel,
                        color: _running ? AppColors.statusGreen : AppColors.statusGrey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _running ? 'SSH server running' : 'SSH server stopped',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_running)
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8022',
                    ),
                  ),
                if (!_running) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _running
                      ? OutlinedButton(
                          onPressed: _toggling ? null : _toggleSshd,
                          child: _toggling
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Stop Server'),
                        )
                      : FilledButton(
                          onPressed: _toggling ? null : _toggleSshd,
                          child: _toggling
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Start Server'),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Root password
        _sectionHeader(theme, 'ROOT PASSWORD'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set the root password for SSH login.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    hintText: 'Enter password',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _settingPassword ? null : _setPassword,
                    child: _settingPassword
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Set Password'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Connection info (when running)
        if (_running) ...[
          const SizedBox(height: 24),
          _sectionHeader(theme, 'CONNECTION INFO'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(theme, 'User', 'root'),
                  const Divider(height: 24),
                  _infoRow(theme, 'Port', port),
                  if (_ips.isNotEmpty) ...[
                    const Divider(height: 24),
                    _infoRow(theme, 'IP Addresses', _ips.join(', ')),
                  ],
                  const Divider(height: 24),
                  Text(
                    'Connect from another device:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final ip in _ips) ...[
                    _commandRow(theme, isDark, 'ssh root@$ip -p $port'),
                    const SizedBox(height: 8),
                  ],
                  if (_ips.isEmpty)
                    _commandRow(theme, isDark, 'ssh root@<device-ip> -p $port'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commandRow(ThemeData theme, bool isDark, String command) {
    final bg = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              command,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyToClipboard(command),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

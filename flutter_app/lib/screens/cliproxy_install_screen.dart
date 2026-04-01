import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../l10n/app_strings.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';

class CliProxyInstallScreen extends StatefulWidget {
  const CliProxyInstallScreen({super.key});

  @override
  State<CliProxyInstallScreen> createState() => _CliProxyInstallScreenState();
}

class _CliProxyInstallScreenState extends State<CliProxyInstallScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);

  static const _sentinel = 'CLIPROXY_INSTALL_COMPLETE';

  static const _installCommand = 'set -e; '
      'echo ">>> Installing 9Router (Node.js AI proxy)..."; '
      'node --version; '
      'npm --version; '
      'echo ">>> Installing 9router globally..."; '
      'npm install -g 9router; '
      'echo ">>> 9Router installed"; '
      '9router --version 2>/dev/null || echo "9router ready"; '
      'echo ">>> CLIPROXY_INSTALL_COMPLETE"';

  static const _fontFallback = [
    'monospace',
    'Noto Sans Mono',
    'Noto Sans Mono CJK SC',
    'sans-serif',
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _controller = TerminalController();
    NativeBridge.startTerminalService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startInstall());
  }

  Future<void> _startInstall() async {
    _pty?.kill();
    _pty = null;
    try {
      try {
        await NativeBridge.setupDirs();
      } catch (_) {}
      try {
        await NativeBridge.writeResolv();
      } catch (_) {}
      try {
        final filesDir = await NativeBridge.getFilesDir();
        const rc = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final rf = File('$filesDir/config/resolv.conf');
        if (!rf.existsSync()) {
          Directory('$filesDir/config').createSync(recursive: true);
          rf.writeAsStringSync(rc);
        }
        final rr = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rr.existsSync()) {
          rr.parent.createSync(recursive: true);
          rr.writeAsStringSync(rc);
        }
      } catch (_) {}

      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );
      final cmdArgs = List<String>.from(args)
        ..removeLast()
        ..removeLast()
        ..addAll(['/bin/bash', '-lc', _installCommand]);

      _pty = Pty.start(
        config['executable']!,
        arguments: cmdArgs,
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      _pty!.output.cast<List<int>>().listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        _terminal.write(text);
        if (!_finished && text.contains(_sentinel)) {
          if (mounted) setState(() => _finished = true);
        }
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\r\n[Process exited with code $code]\r\n');
        if (mounted && !_finished) setState(() => _finished = true);
      });

      _terminal.onOutput = (data) {
        if (_ctrlNotifier.value && data.length == 1) {
          final code = data.toLowerCase().codeUnitAt(0);
          if (code >= 97 && code <= 122) {
            _pty?.write(Uint8List.fromList([code - 96]));
            _ctrlNotifier.value = false;
            return;
          }
        }
        if (_altNotifier.value && data.isNotEmpty) {
          _pty?.write(utf8.encode('\x1b$data'));
          _altNotifier.value = false;
          return;
        }
        _pty?.write(utf8.encode(data));
      };
      _terminal.onResize = (w, h, pw, ph) => _pty?.resize(h, w);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    _controller.dispose();
    _pty?.kill();
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.cliProxyInstallTitle),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (_loading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(AppStrings.cliProxyInstallStarting),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => setState(() {
                          _loading = true;
                          _error = null;
                          _finished = false;
                          _startInstall();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _controller,
                textStyle: const TerminalStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontFamily: 'DejaVuSansMono',
                  fontFamilyFallback: _fontFallback,
                ),
              ),
            ),
            TerminalToolbar(
              pty: _pty,
              ctrlNotifier: _ctrlNotifier,
              altNotifier: _altNotifier,
            ),
          ],
          if (_finished)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: Text(AppStrings.cliProxyInstallDone),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

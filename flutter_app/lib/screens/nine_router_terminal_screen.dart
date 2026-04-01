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

/// 9Router 专属终端，使用独立的 NineRouterService 保活进程
class NineRouterTerminalScreen extends StatefulWidget {
  const NineRouterTerminalScreen({super.key});

  @override
  State<NineRouterTerminalScreen> createState() =>
      _NineRouterTerminalScreenState();
}

class _NineRouterTerminalScreenState extends State<NineRouterTerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);

  static const _fontFallback = [
    'monospace',
    'Noto Sans Mono',
    'Noto Sans Mono CJK SC',
    'Noto Color Emoji',
    'sans-serif',
  ];

  // 自动执行的启动命令
  static const _autoCommand =
      'nohup 9router --port 20128 > /tmp/9router.log 2>&1 & echo "9Router starting..." && sleep 2 && curl -s http://127.0.0.1:20128/ > /dev/null && echo "9Router is running on port 20128!" || echo "Starting in background, check CLIProxy console."\n';

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _controller = TerminalController();
    // 使用独立的 NineRouterService
    NativeBridge.startNineRouterService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPty());
  }

  Future<void> _startPty() async {
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

      _pty = Pty.start(
        config['executable']!,
        arguments: args,
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      _pty!.output.cast<List<int>>().listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\r\n[Process exited with code $code]\r\n');
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

      // 等 shell 就绪后自动执行启动命令
      await Future.delayed(const Duration(milliseconds: 1500));
      _pty?.write(utf8.encode(_autoCommand));
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to start: $e';
      });
    }
  }

  @override
  void dispose() {
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    _controller.dispose();
    _pty?.kill();
    // 不停止 NineRouterService，让 9router 继续在后台运行
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.isChinese ? '9Router 终端' : '9Router Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.restart,
            onPressed: () {
              _pty?.kill();
              setState(() {
                _loading = true;
                _error = null;
              });
              _startPty();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在启动 9Router...'),
              ],
            ))
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _startPty();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ))
              : Column(
                  children: [
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
                ),
    );
  }
}

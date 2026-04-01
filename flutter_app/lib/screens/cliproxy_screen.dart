import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:flutter_pty/flutter_pty.dart' as flutter_pty;
import '../app.dart';
import '../l10n/app_strings.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../utils/responsive.dart';
import 'cliproxy_install_screen.dart';

class CliProxyScreen extends StatefulWidget {
  const CliProxyScreen({super.key});

  @override
  State<CliProxyScreen> createState() => _CliProxyScreenState();
}

class _CliProxyScreenState extends State<CliProxyScreen> {
  static const String _cliProxyUrl = 'http://127.0.0.1:20128/';
  static const int _cliProxyPort = 20128;

  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;
  bool _isRunning = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() {
            _loading = false;
            _isRunning = true;
          }),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _hasError = true;
                _isRunning = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_cliProxyUrl));
    _checkRunning();
  }

  Future<void> _checkRunning() async {
    try {
      final socket = await Socket.connect('127.0.0.1', _cliProxyPort,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      if (mounted) setState(() => _isRunning = true);
    } catch (_) {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _startCliProxy() async {
    // 跳转到 OpenClaw 终端，自动输入启动命令
    // 用户在终端里看到 9router 启动后，返回此页面点重新连接
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.isChinese ? '启动 9Router' : 'Start 9Router'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.isChinese
                ? '请在终端中运行以下命令启动 9Router：'
                : 'Run the following command in the terminal:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                '9router --port 20128 &',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.greenAccent,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.isChinese
                  ? '启动后选择 Hide to Tray，然后返回点重新连接。'
                  : 'Select "Hide to Tray", then come back and tap Reconnect.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 跳转到终端并自动执行命令
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                    builder: (_) => const _NineRouterTerminalScreen()),
              )
                  .then((_) {
                Future.delayed(const Duration(seconds: 3), () {
                  _checkRunning().then((_) {
                    if (_isRunning && mounted) {
                      setState(() => _hasError = false);
                      _controller.reload();
                    }
                  });
                });
              });
            },
            child: Text(AppStrings.isChinese ? '打开终端' : 'Open Terminal'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopCliProxy() async {
    try {
      await NativeBridge.runInProot(
        'pkill -f "9router" 2>/dev/null || true',
        timeout: 10,
      );
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isRunning = false;
        _hasError = true;
      });
    } catch (_) {}
  }

  Future<void> _showCliProxyLog() async {
    String log = '';
    try {
      final result = await NativeBridge.runInProot(
        'cat /tmp/9router.log 2>/dev/null || echo "No log file found"',
        timeout: 10,
      );
      log = result;
    } catch (e) {
      log = 'Failed to read log: $e';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(AppStrings.isChinese ? '9Router 启动日志' : '9Router Startup Log'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              log.isEmpty ? (AppStrings.isChinese ? '暂无日志' : 'No logs') : log,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.cliProxyManagement),
        actions: [
          if (_isStarting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_isRunning)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: AppStrings.cliProxyStop,
              onPressed: _stopCliProxy,
            )
          else
            IconButton(
              icon: const Icon(Icons.play_circle_outlined),
              tooltip: AppStrings.cliProxyStart,
              onPressed: _startCliProxy,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isRunning
                          ? AppColors.statusGreen
                          : AppColors.statusGrey)
                      .withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isRunning
                            ? AppColors.statusGreen
                            : AppColors.statusGrey)
                        .withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRunning ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: _isRunning
                          ? AppColors.statusGreen
                          : AppColors.statusGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isRunning
                          ? AppStrings.cliProxyRunning
                          : AppStrings.cliProxyStopped,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _isRunning
                            ? AppColors.statusGreen
                            : AppColors.statusGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.cliProxyRefresh,
            onPressed: () {
              setState(() {
                _loading = true;
                _hasError = false;
              });
              _controller.reload();
              _checkRunning();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: AppStrings.openInBrowser,
            onPressed: () => launchUrl(Uri.parse(_cliProxyUrl),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorView(context, isTablet)
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }

  Widget _buildErrorView(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);
    return Responsive.constrain(
      Center(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 48 : 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off,
                  size: isTablet ? 80 : 64,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 24),
              Text(AppStrings.cliProxyNotRunning,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(AppStrings.cliProxyGuide,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isStarting ? null : _startCliProxy,
                  icon: _isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow),
                  label: Text(_isStarting
                      ? AppStrings.cliProxyStarting
                      : AppStrings.cliProxyStart),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) => const CliProxyInstallScreen()),
                    );
                    if (result == true) _startCliProxy();
                  },
                  icon: const Icon(Icons.download),
                  label: Text(AppStrings.cliProxyInstallBtn),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _hasError = false;
                  });
                  _controller.reload();
                  _checkRunning();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(AppStrings.reconnect),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showCliProxyLog,
                icon: const Icon(Icons.article_outlined, size: 18),
                label:
                    Text(AppStrings.isChinese ? '查看启动日志' : 'View startup log'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 终端界面：在 proot 里前台运行 9router
class _NineRouterTerminalScreen extends StatefulWidget {
  const _NineRouterTerminalScreen();

  @override
  State<_NineRouterTerminalScreen> createState() =>
      _NineRouterTerminalScreenState();
}

class _NineRouterTerminalScreenState extends State<_NineRouterTerminalScreen> {
  static const _fontFallback = ['monospace', 'Noto Sans Mono', 'sans-serif'];

  late final xterm.Terminal _terminal;
  late final xterm.TerminalController _controller;
  flutter_pty.Pty? _pty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _terminal = xterm.Terminal(maxLines: 5000);
    _controller = xterm.TerminalController();
    NativeBridge.startTerminalService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      try {
        await NativeBridge.setupDirs();
      } catch (_) {}
      try {
        await NativeBridge.writeResolv();
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
        ..addAll([
          '/bin/bash',
          '-lc',
          'echo "Starting 9Router on port 20128..."; '
              'nohup 9router --port 20128 > /tmp/9router.log 2>&1 & '
              'sleep 2 && echo "9Router started" && cat /tmp/9router.log'
        ]);

      _pty = flutter_pty.Pty.start(
        config['executable']!,
        arguments: cmdArgs,
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
      _terminal.onOutput = (data) => _pty?.write(utf8.encode(data));
      _terminal.onResize = (w, h, pw, ph) => _pty?.resize(h, w);
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      _terminal.write('Error: $e\r\n');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pty?.kill();
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.isChinese ? '9Router 运行终端' : '9Router Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppStrings.isChinese ? '返回管理界面' : 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : xterm.TerminalView(
              _terminal,
              controller: _controller,
              textStyle: const xterm.TerminalStyle(
                fontSize: 11,
                height: 1.0,
                fontFamily: 'DejaVuSansMono',
                fontFamilyFallback: _fontFallback,
              ),
            ),
    );
  }
}

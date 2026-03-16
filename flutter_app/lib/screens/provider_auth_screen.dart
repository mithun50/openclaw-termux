import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart';

import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';
import '../services/preferences_service.dart';
import 'dashboard_screen.dart';

/// Runs `openclaw onboard --auth-choice qwen-portal ...` in a terminal so the user can
/// authenticate via provider portal flow (Qwen). Output is shown in an embedded terminal.
class ProviderAuthScreen extends StatefulWidget {
  /// If true, shows a "Go to Dashboard" button when onboarding exits.
  /// Used after first-time setup. If false, just pops back.
  final bool isFirstRun;

  const ProviderAuthScreen({super.key, this.isFirstRun = false});

  @override
  State<ProviderAuthScreen> createState() => _ProviderAuthScreenState();
}

class _ProviderAuthScreenState extends State<ProviderAuthScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;

  bool _loading = true;
  bool _finished = false;
  String? _error;

  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _screenshotKey = GlobalKey();

  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');
  static final _ansiEscape = AppConstants.ansiEscape;
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

  // Detect completion from output (best-effort) in addition to exitCode.
  static final _completionPattern = RegExp(
    r'onboard(ing)?\s+(is\s+)?complete|successfully\s+onboarded|setup\s+complete',
    caseSensitive: false,
  );

  String _outputBuffer = '';

  String? _detectedUrl;
  bool _urlDismissed = false;

  static const _fontFallback = [
    'monospace',
    'Noto Sans Mono',
    'Noto Sans Mono CJK SC',
    'Noto Sans Mono CJK TC',
    'Noto Sans Mono CJK JP',
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'sans-serif',
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _controller = TerminalController();
    NativeBridge.startTerminalService();

    // Defer PTY start until after the first frame so TerminalView has been
    // laid out and _terminal.viewWidth/viewHeight reflect real screen size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProviderAuth();
    });
  }

  Future<void> _startProviderAuth() async {
    _pty?.kill();
    _pty = null;

    try {
      // Ensure dirs + resolv.conf exist before proot starts (#40).
      try {
        await NativeBridge.setupDirs();
      } catch (_) {}
      try {
        await NativeBridge.writeResolv();
      } catch (_) {}
      try {
        final filesDir = await NativeBridge.getFilesDir();
        const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final resolvFile = File('$filesDir/config/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory('$filesDir/config').createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        // Also write into rootfs /etc/ so DNS works even if bind-mount fails
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}

      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      // Replace login shell with the provider auth onboarding command.
      final onboardingArgs = List<String>.from(args);
      onboardingArgs.removeLast(); // remove '-l'
      onboardingArgs.removeLast(); // remove '/bin/bash'

      const enableAuthPlugin = 'openclaw plugins enable qwen-portal-auth';
      const authLogin =
          'openclaw models auth login --provider qwen-portal --set-default';

      onboardingArgs.addAll([
        '/bin/bash',
        '-lc',
        'echo "=== Provider Auth (Qwen Portal) ===" && '
            'echo "" && '
            '$enableAuthPlugin && '
            '$authLogin && '
            'echo "" && echo "Provider auth flow complete! You can close this screen."',
      ]);

      _pty = Pty.start(
        config['executable']!,
        arguments: onboardingArgs,
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      _pty!.output.cast<List<int>>().listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        _terminal.write(text);

        // Keep a buffer to detect completion or URLs.
        _outputBuffer += text;
        if (_outputBuffer.length > 8192) {
          _outputBuffer = _outputBuffer.substring(_outputBuffer.length - 4096);
        }

        final cleanText = _outputBuffer.replaceAll(_ansiEscape, '');

        // Detect URLs from terminal output and surface in UI.
        if (!_urlDismissed) {
          final url = _extractUrl(cleanText);
          if (url != null && url != _detectedUrl) {
            if (mounted) setState(() => _detectedUrl = url);
          }
        }

        if (!_finished && _completionPattern.hasMatch(cleanText)) {
          if (mounted) setState(() => _finished = true);
        }
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\r\n[ProviderAuth exited with code $code]\r\n');
        if (mounted) {
          setState(() => _finished = true);
        }
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

      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w);
      };

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to start provider auth: $e';
        });
      }
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

  String? _getSelectedText() {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return null;

    final range = selection.normalized;
    final sb = StringBuffer();
    for (int y = range.begin.y; y <= range.end.y; y++) {
      if (y >= _terminal.buffer.lines.length) break;
      final line = _terminal.buffer.lines[y];
      final from = (y == range.begin.y) ? range.begin.x : 0;
      final to = (y == range.end.y) ? range.end.x : null;
      sb.write(line.getText(from, to));
      if (y < range.end.y) sb.writeln();
    }
    final text = sb.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _extractUrl(String text) {
    final clean =
        text.replaceAll(_boxDrawing, '').replaceAll(RegExp(r'\s+'), '');
    final parts = clean.split(RegExp(r'(?=https?://)'));
    String? best;
    for (final part in parts) {
      final match = _anyUrlRegex.firstMatch(part);
      if (match != null) {
        var url = match.group(0)!;
        // The 'to approve access' output from openclaw cli
        const marker = 'toapproveaccess.';
        final idx = url.indexOf(marker);
        if (idx > 0) {
          url = url.substring(0, idx);
        }

        if (best == null || url.length > best.length) {
          best = url;
        }
      }
    }

    return best;
  }

  void _copySelection() {
    final text = _getSelectedText();
    if (text == null) return;

    Clipboard.setData(ClipboardData(text: text));

    final url = _extractUrl(text);
    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _openSelection() {
    final text = _getSelectedText();
    if (text == null) return;

    final url = _extractUrl(text);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No URL found in selection'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _pty?.write(utf8.encode(data.text!));
    }
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey,
        prefix: 'provider_auth');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null
            ? 'Screenshot saved: ${path.split('/').last}'
            : 'Failed to capture screenshot'),
      ),
    );
  }

  Future<void> _goToDashboard() async {
    final navigator = Navigator.of(context);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Auth'),
        leading: widget.isFirstRun
            ? null // no back button during first-run
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Screenshot',
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
            onPressed: _copySelection,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open URL',
            onPressed: _openSelection,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Paste',
            onPressed: _paste,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart',
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
                _finished = false;
              });
              _startProviderAuth();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_detectedUrl != null && !_urlDismissed)
            MaterialBanner(
              content: SelectableText(
                _detectedUrl!,
                maxLines: 2,
              ),
              leading: const Icon(Icons.link),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _detectedUrl!));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text('Copy'),
                ),
                FilledButton(
                  onPressed: () {
                    final url = _detectedUrl;
                    if (url != null) {
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                        return;
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid URL'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    setState(() => _urlDismissed = true);
                  },
                  child: const Text('Open'),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: () {
                    setState(() => _urlDismissed = true);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          if (_loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting provider auth...'),
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
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                            _finished = false;
                          });
                          _startProviderAuth();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Expanded(
              child: RepaintBoundary(
                key: _screenshotKey,
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
                  onPressed: widget.isFirstRun
                      ? _goToDashboard
                      : () => Navigator.of(context).pop(true),
                  icon: Icon(
                      widget.isFirstRun ? Icons.arrow_forward : Icons.check),
                  label: Text(widget.isFirstRun ? 'Go to Dashboard' : 'Done'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

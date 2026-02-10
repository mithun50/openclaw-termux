import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../services/preferences_service.dart';
import '../widgets/terminal_toolbar.dart';
import 'dashboard_screen.dart';

/// Runs `openclaw onboard` in a terminal so the user can configure
/// API keys and select loopback binding. Shown after first-time setup
/// and accessible from the dashboard for re-configuration.
class OnboardingScreen extends StatefulWidget {
  /// If true, shows a "Go to Dashboard" button when onboarding exits.
  /// Used after first-time setup. If false, just pops back.
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');
  static final _tokenUrlRegex = RegExp(r'https?://(?:localhost|127\.0\.0\.1):18789[^\s]*');
  static final _ansiEscape = AppConstants.ansiEscape;
  /// Box-drawing and other TUI characters that break URLs when copied
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');
  static final _completionPattern = RegExp(
    r'onboard(ing)?\s+(is\s+)?complete|successfully\s+onboarded|setup\s+complete',
    caseSensitive: false,
  );
  String _outputBuffer = '';

  static const _fontFallback = [
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'Noto Sans Mono',
    'sans-serif',
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _controller = TerminalController();
    NativeBridge.startTerminalService();
    _startOnboarding();
  }

  Future<void> _startOnboarding() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config);

      // Replace the login shell with a command that runs onboarding.
      // buildProotArgs ends with [..., '/bin/bash', '-l']
      // Replace with [..., '/bin/bash', '-lc', 'openclaw onboard']
      final onboardingArgs = List<String>.from(args);
      onboardingArgs.removeLast(); // remove '-l'
      onboardingArgs.removeLast(); // remove '/bin/bash'
      onboardingArgs.addAll([
        '/bin/bash', '-lc',
        'echo "=== OpenClaw Onboarding ===" && '
        'echo "Configure your API keys and binding settings." && '
        'echo "TIP: Select Loopback (127.0.0.1) when asked for binding!" && '
        'echo "" && '
        'openclaw onboard; '
        'echo "" && echo "Onboarding complete! You can close this screen."',
      ]);

      _pty = Pty.start(
        config['executable']!,
        arguments: onboardingArgs,
        // Host-side env: only proot-specific vars.
        // Guest env is set via env -i in buildProotArgs.
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      _pty!.output.cast<List<int>>().listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        _terminal.write(text);
        // Scan output for token URL (e.g. http://localhost:18789/#token=...)
        _outputBuffer += text;
        // Keep buffer manageable
        if (_outputBuffer.length > 4096) {
          _outputBuffer = _outputBuffer.substring(_outputBuffer.length - 2048);
        }
        // Strip ANSI escape codes for text analysis
        final cleanText = _outputBuffer.replaceAll(_ansiEscape, '');
        // For URL matching, strip whitespace + box-drawing chars
        final cleanForUrl = cleanText
            .replaceAll(_boxDrawing, '')
            .replaceAll(RegExp(r'\s+'), '');
        // Save token URL to preferences if found
        final tokenMatch = _tokenUrlRegex.firstMatch(cleanForUrl);
        if (tokenMatch != null) {
          _saveTokenUrl(tokenMatch.group(0)!);
        }
        // Detect onboarding completion from output text
        if (!_finished && _completionPattern.hasMatch(cleanText)) {
          if (mounted) {
            setState(() => _finished = true);
          }
        }
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\r\n[Onboarding exited with code $code]\r\n');
        if (mounted) {
          setState(() => _finished = true);
        }
      });

      _terminal.onOutput = (data) {
        _pty?.write(utf8.encode(data));
      };

      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w);
      };

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to start onboarding: $e';
      });
    }
  }

  Future<void> _saveTokenUrl(String url) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.dashboardUrl = url;
  }

  @override
  void dispose() {
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

  /// Strip box-drawing chars and whitespace to reconstruct URLs
  /// that got split by terminal line wrapping / TUI borders.
  String? _extractUrl(String text) {
    final clean = text.replaceAll(_boxDrawing, '').replaceAll(RegExp(r'\s+'), '');
    final match = _anyUrlRegex.firstMatch(clean);
    return match?.group(0);
  }

  void _copySelection() {
    final text = _getSelectedText();
    if (text == null) return;

    Clipboard.setData(ClipboardData(text: text));

    // If the copied text contains a URL, offer "Open" action
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

  void _handleTap(TapUpDetails details, CellOffset offset) {
    // Join adjacent lines and strip box-drawing chars to reconstruct
    // URLs that wrap across terminal lines or TUI borders.
    final totalLines = _terminal.buffer.lines.length;
    final startRow = (offset.y - 2).clamp(0, totalLines - 1);
    final endRow = (offset.y + 2).clamp(0, totalLines - 1);

    final sb = StringBuffer();
    for (int row = startRow; row <= endRow; row++) {
      sb.write(_getLineText(row).trimRight());
    }
    final combined = sb.toString()
        .replaceAll(_boxDrawing, '')
        .replaceAll(RegExp(r'\s+'), '');
    if (combined.isEmpty) return;

    final match = _anyUrlRegex.firstMatch(combined);
    if (match != null) {
      _openUrl(match.group(0)!);
    }
  }

  String _getLineText(int row) {
    try {
      final line = _terminal.buffer.lines[row];
      final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final char = line.getCodePoint(i);
        if (char != 0) {
          sb.writeCharCode(char);
        }
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Link'),
        content: Text(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied'),
                  duration: Duration(seconds: 1),
                ),
              );
              Navigator.pop(ctx, false);
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        title: const Text('OpenClaw Onboarding'),
        leading: widget.isFirstRun
            ? null // no back button during first-run
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: false,
        actions: [
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
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting onboarding...'),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                            _finished = false;
                          });
                          _startOnboarding();
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
              child: TerminalView(
                _terminal,
                controller: _controller,
                textStyle: const TerminalStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontFamilyFallback: _fontFallback,
                ),
                onTapUp: _handleTap,
              ),
            ),
            TerminalToolbar(pty: _pty),
          ],
          if (_finished)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.isFirstRun
                      ? _goToDashboard
                      : () => Navigator.of(context).pop(),
                  icon: Icon(widget.isFirstRun
                      ? Icons.arrow_forward
                      : Icons.check),
                  label: Text(widget.isFirstRun
                      ? 'Go to Dashboard'
                      : 'Done'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

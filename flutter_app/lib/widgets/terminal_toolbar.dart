import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../app.dart';

/// Termux-style extra keys toolbar for terminal screens.
/// Provides ESC, CTRL, ALT, TAB, arrows, and common special characters.
///
/// CTRL and ALT state is exposed via [ValueNotifier]s so the parent
/// screen can intercept keyboard input and apply modifiers.
class TerminalToolbar extends StatefulWidget {
  final Pty? pty;
  final ValueNotifier<bool> ctrlNotifier;
  final ValueNotifier<bool> altNotifier;

  const TerminalToolbar({
    super.key,
    required this.pty,
    required this.ctrlNotifier,
    required this.altNotifier,
  });

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  bool get _ctrlActive => widget.ctrlNotifier.value;
  bool get _altActive => widget.altNotifier.value;

  @override
  void initState() {
    super.initState();
    widget.ctrlNotifier.addListener(_onModifierChanged);
    widget.altNotifier.addListener(_onModifierChanged);
  }

  @override
  void dispose() {
    widget.ctrlNotifier.removeListener(_onModifierChanged);
    widget.altNotifier.removeListener(_onModifierChanged);
    super.dispose();
  }

  void _onModifierChanged() {
    setState(() {});
  }

  void _send(String data) {
    final pty = widget.pty;
    if (pty == null) return;

    if (_ctrlActive) {
      widget.ctrlNotifier.value = false;

      // Ctrl+a-z â†?bytes 1-26
      if (data.length == 1) {
        final code = data.toLowerCase().codeUnitAt(0);
        if (code >= 97 && code <= 122) {
          pty.write(Uint8List.fromList([code - 96]));
          return;
        }
      }

      // Ctrl+escape sequences (arrows, Home, End, PgUp, PgDn)
      const ctrlSeqMap = <String, String>{
        '\x1b[A': '\x1b[1;5A', // Up
        '\x1b[B': '\x1b[1;5B', // Down
        '\x1b[D': '\x1b[1;5D', // Left
        '\x1b[C': '\x1b[1;5C', // Right
        '\x1b[H': '\x1b[1;5H', // Home
        '\x1b[F': '\x1b[1;5F', // End
        '\x1b[5~': '\x1b[5;5~', // PgUp
        '\x1b[6~': '\x1b[6;5~', // PgDn
      };

      final ctrlVariant = ctrlSeqMap[data];
      if (ctrlVariant != null) {
        pty.write(utf8.encode(ctrlVariant));
        return;
      }

      // Unhandled combo: send raw data (TAB, ESC, symbols, etc.)
      pty.write(utf8.encode(data));
      return;
    }

    if (_altActive) {
      // ALT+key: send ESC + key
      widget.altNotifier.value = false;
      pty.write(utf8.encode('\x1b$data'));
      return;
    }

    pty.write(utf8.encode(data));
  }

  void _toggleCtrl() {
    widget.ctrlNotifier.value = !_ctrlActive;
    if (_ctrlActive) widget.altNotifier.value = false;
  }

  void _toggleAlt() {
    widget.altNotifier.value = !_altActive;
    if (_altActive) widget.ctrlNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : const Color(0xFFE0E0E0);
    final btnColor = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFEEEEEE);
    const activeColor = AppColors.accent;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    Widget keyButton(String label, {VoidCallback? onTap, String? sendData, bool active = false, double? width}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Material(
          color: active ? activeColor : btnColor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap ?? () => _send(sendData ?? label),
            child: Container(
              width: width,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : textColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget arrowButton(IconData icon, String escSequence) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: btnColor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _send(escSequence),
            child: Container(
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: textColor),
            ),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              keyButton('ESC', sendData: '\x1b'),
              keyButton('CTRL', onTap: _toggleCtrl, active: _ctrlActive),
              keyButton('ALT', onTap: _toggleAlt, active: _altActive),
              keyButton('TAB', sendData: '\t'),
              keyButton('ENTER', sendData: '\r'),
              const SizedBox(width: 4),
              arrowButton(Icons.arrow_upward, '\x1b[A'),
              arrowButton(Icons.arrow_downward, '\x1b[B'),
              arrowButton(Icons.arrow_back, '\x1b[D'),
              arrowButton(Icons.arrow_forward, '\x1b[C'),
              const SizedBox(width: 4),
              keyButton('HOME', sendData: '\x1b[H'),
              keyButton('END', sendData: '\x1b[F'),
              keyButton('PGUP', sendData: '\x1b[5~'),
              keyButton('PGDN', sendData: '\x1b[6~'),
              const SizedBox(width: 4),
              keyButton('-', sendData: '-'),
              keyButton('/', sendData: '/'),
              keyButton('|', sendData: '|'),
              keyButton('~', sendData: '~'),
              keyButton('_', sendData: '_'),
            ],
          ),
        ),
      ),
    );
  }
}

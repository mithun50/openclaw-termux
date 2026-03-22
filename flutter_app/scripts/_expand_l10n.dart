import 'dart:convert';
import 'dart:io';

import 'package:openclaw/l10n/app_strings_en.dart';
import 'package:openclaw/l10n/app_strings_ja.dart';
import 'package:openclaw/l10n/app_strings_zh_hans.dart';
import 'package:openclaw/l10n/app_strings_zh_hant.dart';

String _escape(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n');
}

String _buildMapFile({
  required String variableName,
  required Map<String, String> base,
  required Map<String, String> localized,
}) {
  final buffer = StringBuffer();
  buffer.writeln('const Map<String, String> $variableName = {');

  final seen = <String>{};
  for (final key in base.keys) {
    final value = localized[key] ?? base[key] ?? key;
    buffer.writeln("  '$key': '${_escape(value)}',");
    seen.add(key);
  }

  for (final entry in localized.entries) {
    if (seen.contains(entry.key)) continue;
    buffer.writeln("  '${entry.key}': '${_escape(entry.value)}',");
  }

  buffer.writeln('};');
  return buffer.toString();
}

void main() {
  final jaContent = _buildMapFile(
    variableName: 'appStringsJa',
    base: appStringsEn,
    localized: appStringsJa,
  );

  final zhHantContent = _buildMapFile(
    variableName: 'appStringsZhHant',
    base: appStringsZhHans,
    localized: appStringsZhHant,
  );

  File('lib/l10n/app_strings_ja.dart').writeAsStringSync(
    jaContent,
    encoding: utf8,
  );
  File('lib/l10n/app_strings_zh_hant.dart').writeAsStringSync(
    zhHantContent,
    encoding: utf8,
  );
}

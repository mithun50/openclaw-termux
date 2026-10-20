import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw/constants.dart';
import 'package:openclaw/models/ai_provider.dart';
import 'package:openclaw/screens/provider_detail_screen.dart';
import 'package:openclaw/screens/providers_screen.dart';
import 'package:openclaw/services/provider_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AppConstants.channelName);
  late Map<String, dynamic> original;
  late Map<String, dynamic>? written;
  late bool useProot;
  late int directWrites;
  late int prootWrites;

  setUp(() {
    original = {
      'models': {
        'providers': {
          'custom': {
            'baseUrl': 'http://localhost:1234/v1',
            'models': [
              {
                'id': 'custom-model',
                'input': ['text', 'image'],
              },
            ],
          },
        },
      },
      'agents': {
        'defaults': {
          'model': {
            'primary': 'previous-model',
            'fallbacks': ['backup-model'],
          },
        },
      },
      'gateway': {'mode': 'remote', 'port': 19000},
    };
    written = null;
    useProot = false;
    directWrites = 0;
    prootWrites = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map;
          switch (call.method) {
            case 'runInProot':
              if (!useProot) throw PlatformException(code: 'proot-unavailable');
              // Execute the actual generated JavaScript with an in-memory filesystem.
              final command = args['command'] as String;
              expect(command, startsWith("node -e '"));
              final script = command
                  .substring(9, command.length - 1)
                  .replaceAll("'\\''", "'");
              final result = await Process.run('node', [
                '-e',
                '''
const vm = require('node:vm');
let written;
const fs = {
  readFileSync: () => process.argv[2],
  mkdirSync: () => {},
  writeFileSync: (path, content) => { written = content; },
};
vm.runInNewContext(process.argv[1], {
  require: (name) => {
    if (name === 'fs') return fs;
    if (name === 'path') return require('node:path');
    throw new Error('Unexpected module: ' + name);
  },
});
process.stdout.write(written);
''',
                script,
                jsonEncode(original),
              ]);
              expect(result.exitCode, 0, reason: result.stderr.toString());
              written =
                  jsonDecode(result.stdout as String) as Map<String, dynamic>;
              prootWrites++;
              return '';
            case 'readRootfsFile':
              return jsonEncode(original);
            case 'writeRootfsFile':
              directWrites++;
              written =
                  jsonDecode(args['content'] as String) as Map<String, dynamic>;
              return true;
            default:
              throw StateError('Unexpected native call: ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void expectConfig(String model) {
    final modelId = model.startsWith('minimax/')
        ? model.substring('minimax/'.length)
        : model;
    expect(written, isNotNull);
    final providers = written!['models']['providers'] as Map;
    expect(providers['minimax'], {
      'apiKey': 'test-only',
      'baseUrl': 'https://api.minimax.io/v1',
      'api': 'openai-completions',
      'models': [
        {'id': modelId, 'name': modelId},
      ],
    });
    expect(providers['custom'], original['models']['providers']['custom']);
    expect(written!['agents']['defaults']['model'], {
      'primary': 'minimax/$modelId',
      'fallbacks': ['backup-model'],
    });
    expect(written!['gateway'], original['gateway']);
  }

  test('ordinary MiniMax choices prefer Flash and retain M3 only', () {
    expect(AiProvider.minimax.defaultModels, [
      'MiniMax-M3.1-Flash',
      'MiniMax-M3',
    ]);
  });

  test('explicit removal still recognizes a saved legacy model', () async {
    useProot = true;
    original['agents']['defaults']['model']['primary'] = 'MiniMax-M2.7';
    original['models']['providers']['minimax'] = {
      'models': [
        {'id': 'MiniMax-M2.7'},
      ],
    };
    await ProviderConfigService.removeProviderConfig(
      provider: AiProvider.minimax,
    );
    expect(prootWrites, 1);
    expect(written!['models']['providers'].containsKey('minimax'), isFalse);
    expect(
      written!['agents']['defaults']['model'].containsKey('primary'),
      isFalse,
    );
    expect(
      written!['models']['providers']['custom'],
      original['models']['providers']['custom'],
    );
  });

  testWidgets('saved legacy configuration is still marked active', (
    tester,
  ) async {
    original['agents']['defaults']['model']['primary'] = 'MiniMax-M2.7';
    original['models']['providers']['minimax'] = {
      'apiKey': 'test-only',
      'models': [
        {'id': 'MiniMax-M2.7'},
      ],
    };
    await tester.pumpWidget(const MaterialApp(home: ProvidersScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('MiniMax'), 300);
    expect(find.text('Active'), findsOneWidget);
  });

  for (final saved in [null, 'MiniMax-M2.7', 'custom-model']) {
    testWidgets('provider list preserves $saved when another model is active', (
      tester,
    ) async {
      if (saved != null) {
        original['models']['providers']['minimax'] = {
          'apiKey': 'test-only',
          'models': [
            {'id': saved},
          ],
        };
      }
      await tester.pumpWidget(const MaterialApp(home: ProvidersScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('MiniMax'), 300);
      await tester.tap(find.text('MiniMax'));
      await tester.pumpAndSettle();
      if (saved == null) {
        await tester.enterText(find.byType(TextField).first, 'test-only');
      }
      final save = find.text('Save & Activate');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expectConfig(saved ?? 'MiniMax-M3.1-Flash');
    });
  }

  for (final proot in [false, true]) {
    for (final model in [
      'MiniMax-M3.1-Flash',
      'MiniMax-M3',
      'MiniMax-M2.7',
      "custom-model's-id",
      'minimax/MiniMax-M3.1-Flash',
      'minimax/MiniMax-M2.7',
      'minimax/custom-model',
    ]) {
      test('saves $model through ${proot ? 'proot' : 'fallback'}', () async {
        useProot = proot;
        await ProviderConfigService.saveProviderConfig(
          provider: AiProvider.minimax,
          apiKey: 'test-only',
          model: model,
        );
        expectConfig(model);
        expect(prootWrites, proot ? 1 : 0);
        expect(directWrites, proot ? 0 : 1);
      });
    }
  }

  for (final existing in [
    null,
    'MiniMax-M3',
    'MiniMax-M2.7',
    'custom-model',
    'minimax/MiniMax-M3.1-Flash',
    'minimax/MiniMax-M2.7',
    'minimax/custom-model',
  ]) {
    testWidgets('form preserves selection $existing on save', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SizedBox(),
          initialRoute: '/provider',
          routes: {
            '/provider': (_) => ProviderDetailScreen(
              provider: AiProvider.minimax,
              existingApiKey: 'test-only',
              existingModel: existing,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(
        dropdown.initialValue,
        existing == null || existing == 'MiniMax-M3'
            ? existing ?? 'MiniMax-M3.1-Flash'
            : '__custom__',
      );
      final save = find.text('Save & Activate');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expectConfig(existing ?? 'MiniMax-M3.1-Flash');
    });
  }
}

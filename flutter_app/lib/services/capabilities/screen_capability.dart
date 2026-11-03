import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class ScreenCapability extends CapabilityHandler {
  //File List: Record the screen recording files generated for this session (unique ID+path)
  // Used to ensure that only files created by oneself are deleted during deletion, avoiding accidental deletion of user albums
  /**Fixed since March 22, 2026
  submitter：wuchenxiuwu */
  final List<Map<String, String>> _screenFiles = [];

  @override
  String get name => 'screen';

  @override
  List<String> get commands => ['record'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    if (command == 'screen.record') return _record(params);
    return NodeFrame.response('', error: {
      'code': 'UNKNOWN_COMMAND',
      'message': 'Unknown screen command: $command',
    });
  }

  // Generate a unique ID (timestamp+random number) to distinguish between different files
  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000000);
    return '${now}_$random';
  }

  Future<NodeFrame> _record(Map<String, dynamic> params) async {
    String? fileId;
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;
      final filePath = await NativeBridge.requestScreenCapture(durationMs);

      if (filePath == null || filePath.isEmpty) {
        return NodeFrame.response('', error: {
          'code': 'SCREEN_DENIED',
          'message': 'User denied screen recording',
        });
      }

      // Record the files generated this time in the inventory
      fileId = _generateId();
      _screenFiles.add({'id': fileId, 'path': filePath});

      final file = File(filePath);
      if (!await file.exists()) {
        return NodeFrame.response('', error: {
          'code': 'SCREEN_ERROR',
          'message': 'Recording file not found',
        });
      }

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      // Only delete files when they are in the list to prevent accidental deletion of user albums
      final index = _screenFiles.indexWhere((item) => item['id'] == fileId && item['path'] == filePath);
      if (index != -1) {
        _screenFiles.removeAt(index);
        await file.delete().catchError((_) => file);
      }

      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'mp4',
      });
    } catch (e) {
      // Clean up records in the inventory when errors occur to avoid residue
      if (fileId != null) {
        _screenFiles.removeWhere((item) => item['id'] == fileId);
      }
      return NodeFrame.response('', error: {
        'code': 'SCREEN_ERROR',
        'message': '$e',
      });
    }
  }
}

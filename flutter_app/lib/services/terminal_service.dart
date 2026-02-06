import 'package:flutter/services.dart';
import '../constants.dart';

/// Provides a fallback terminal via platform channels when flutter_pty
/// doesn't work on certain devices.
class TerminalService {
  static const _channel = MethodChannel(AppConstants.channelName);

  /// Get the proot command that flutter_pty should spawn.
  /// flutter_pty will use this to start a proot bash shell.
  static Future<Map<String, String>> getProotShellConfig() async {
    final filesDir = await _channel.invokeMethod<String>('getFilesDir') ?? '';
    final nativeLibDir = await _channel.invokeMethod<String>('getNativeLibDir') ?? '';

    final rootfsDir = '$filesDir/rootfs/ubuntu';
    final tmpDir = '$filesDir/tmp';
    final configDir = '$filesDir/config';
    final homeDir = '$filesDir/home';
    final prootPath = '$nativeLibDir/libproot.so';

    return {
      'executable': prootPath,
      'rootfsDir': rootfsDir,
      'tmpDir': tmpDir,
      'configDir': configDir,
      'homeDir': homeDir,
      'PROOT_TMP_DIR': tmpDir,
    };
  }

  static List<String> buildProotArgs(Map<String, String> config) {
    return [
      '-0',
      '--link2symlink',
      '-r', config['rootfsDir']!,
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
      '-b', '${config['configDir']}/resolv.conf:/etc/resolv.conf',
      '-b', '${config['homeDir']}:/root/home',
      '-w', '/root',
      '/bin/bash',
      '-l',
    ];
  }
}

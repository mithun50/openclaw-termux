import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';

class BootstrapService {
  final Dio _dio = Dio();

  Future<SetupState> checkStatus() async {
    try {
      final complete = await NativeBridge.isBootstrapComplete();
      if (complete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Setup complete',
        );
      }
      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setup required',
      );
    } catch (e) {
      return SetupState(
        step: SetupStep.error,
        error: 'Failed to check status: $e',
      );
    }
  }

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
  }) async {
    try {
      // Step 0: Setup directories
      onProgress(const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setting up directories...',
      ));
      await NativeBridge.setupDirs();
      await NativeBridge.writeResolv();

      // Step 1: Download rootfs
      final arch = await NativeBridge.getArch();
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final filesDir = await NativeBridge.getFilesDir();
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';

      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 0.0,
        message: 'Downloading Ubuntu rootfs...',
      ));

      await _dio.download(
        rootfsUrl,
        tarPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            onProgress(SetupState(
              step: SetupStep.downloadingRootfs,
              progress: progress,
              message: 'Downloading: $mb MB / $totalMb MB',
            ));
          }
        },
      );

      // Step 2: Extract rootfs
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 0.0,
        message: 'Extracting rootfs (this takes a while)...',
      ));
      await NativeBridge.extractRootfs(tarPath);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 1.0,
        message: 'Rootfs extracted',
      ));

      // Step 3: Install Node.js (split into sub-steps for better error reporting)
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.0,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Fixing any broken packages...',
      ));
      // dpkg --configure -a in case a previous run was interrupted
      await NativeBridge.runInProot(
        'dpkg --configure -a || true',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.2,
        message: 'Installing base packages...',
      ));
      await NativeBridge.runInProot(
        'apt-get install -y --no-install-recommends ca-certificates curl gnupg',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.4,
        message: 'Adding NodeSource repository...',
      ));
      await NativeBridge.runInProot(
        'curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh && '
        'bash /tmp/nodesource_setup.sh',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.6,
        message: 'Installing Node.js...',
      ));
      await NativeBridge.runInProot(
        'apt-get install -y --no-install-recommends nodejs',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.9,
        message: 'Verifying Node.js...',
      ));
      await NativeBridge.runInProot('node --version && npm --version');
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 1.0,
        message: 'Node.js installed',
      ));

      // Step 4: Install OpenClaw
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.0,
        message: 'Installing OpenClaw (this may take a few minutes)...',
      ));
      await NativeBridge.runInProot('npm install -g openclaw');

      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot('openclaw --version');
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // Step 5: Configure bypass
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 0.0,
        message: 'Configuring Bionic Bypass...',
      ));
      await NativeBridge.installBionicBypass();
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 1.0,
        message: 'Bionic Bypass configured',
      ));

      // Done
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: 'Setup complete! Ready to start the gateway.',
      ));
    } on DioException catch (e) {
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Download failed: ${e.message}. Check your internet connection.',
      ));
    } catch (e) {
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }
}

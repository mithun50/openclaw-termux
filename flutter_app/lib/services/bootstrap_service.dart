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

      // Install bionic bypass + cwd-fix + node-wrapper BEFORE using node.
      // The wrapper patches process.cwd() which returns ENOSYS in proot.
      await NativeBridge.installBionicBypass();

      // Step 3: Install Node.js
      // Fix permissions inside proot (Java extraction may miss execute bits)
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.0,
        message: 'Fixing rootfs permissions...',
      ));
      // Blanket recursive chmod on all bin/lib directories.
      // Java tar extraction loses execute bits; dpkg needs tar, xz,
      // gzip, rm, mv, etc. — easier to fix everything than enumerate.
      await NativeBridge.runInProot(
        'chmod -R 755 /usr/bin /usr/sbin /bin /sbin '
        '/usr/local/bin /usr/local/sbin 2>/dev/null; '
        'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ '
        '/var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
        'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
        'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
        'echo permissions_fixed',
      );

      // --- Install base packages via apt-get (like Termux proot-distro) ---
      // Now that our proot matches Termux exactly (env -i, clean host env,
      // proper flags), dpkg works normally. No need for Java-side deb
      // extraction — let dpkg+tar handle it inside proot like Termux does.
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.15,
        message: 'Installing base packages...',
      ));
      // ca-certificates: HTTPS for npm/git
      // git: openclaw has git deps (@whiskeysockets/libsignal-node)
      // dpkg extracts via tar inside proot — permissions are correct.
      // Post-install scripts (update-ca-certificates) run automatically.
      await NativeBridge.runInProot(
        'apt-get install -y --no-install-recommends '
        'ca-certificates git',
      );

      // Git config (.gitconfig) is written by installBionicBypass() on the
      // Java side — directly to $rootfsDir/root/.gitconfig — rewrites
      // SSH→HTTPS for npm git deps (no SSH keys in proot).

      // --- Install Node.js via binary tarball ---
      // Download directly from nodejs.org (bypasses curl/gpg/NodeSource
      // which fail inside proot). Includes node + npm + corepack.
      final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
      final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.3,
        message: 'Downloading Node.js ${AppConstants.nodeVersion}...',
      ));
      await _dio.download(
        nodeTarUrl,
        nodeTarPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = 0.3 + (received / total) * 0.4;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            onProgress(SetupState(
              step: SetupStep.installingNode,
              progress: progress,
              message: 'Downloading Node.js: $mb MB / $totalMb MB',
            ));
          }
        },
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.75,
        message: 'Extracting Node.js...',
      ));
      await NativeBridge.extractNodeTarball(nodeTarPath);

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.9,
        message: 'Verifying Node.js...',
      ));
      // node-wrapper.js patches broken proot syscalls before loading npm.
      // /usr/local/bin is on PATH, so node finds the tarball's npm.
      const wrapper = '/root/.openclawd/node-wrapper.js';
      const nodeRun = 'node $wrapper';
      // npm from nodejs.org tarball is at /usr/local/lib/node_modules/npm
      final npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
      await NativeBridge.runInProot(
        'node --version && $nodeRun $npmCli --version',
      );
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
      // Install openclaw like Termux — fork/exec works now, so let npm
      // run postinstall scripts normally. No --ignore-scripts needed.
      await NativeBridge.runInProot(
        '$nodeRun $npmCli install -g openclaw',
        timeout: 1800,
      );

      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot(
        '$nodeRun $npmCli list -g openclaw',
      );
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // Step 5: Bionic Bypass already installed (before node verification)
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

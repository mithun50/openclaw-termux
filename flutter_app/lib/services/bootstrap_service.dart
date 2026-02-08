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

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.2,
        message: 'Downloading base packages...',
      ));
      // APT's internal fork→exec→dpkg fails with exit 100 on Android 10+
      // (W^X policy + PTY setup in the forked child). Workaround: download
      // packages via apt (no dpkg needed), then run dpkg directly from the
      // shell where proot's ptrace interception works correctly.
      await NativeBridge.runInProot(
        'apt-get -q -d install -y --no-install-recommends '
        'ca-certificates curl gnupg',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.25,
        message: 'Extracting base packages...',
      ));
      // Extract .deb files using Java (Apache Commons Compress) to avoid
      // fork+exec issues in proot on Android 10+. dpkg, dpkg-deb, ar all
      // fail because subprocess forking is broken in proot.
      await NativeBridge.extractDebPackages();

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.3,
        message: 'Configuring certificates...',
      ));
      // Java extraction doesn't run postinst scripts. ca-certificates
      // needs update-ca-certificates to generate the cert bundle.
      // Try it first; if it fails (fork issues), manually concatenate certs.
      try {
        await NativeBridge.runInProot('update-ca-certificates 2>/dev/null');
      } catch (_) {
        // Manual fallback: concatenate all Mozilla CA certs into the bundle
        await NativeBridge.runInProot(
          'mkdir -p /etc/ssl/certs 2>/dev/null; '
          'cat /usr/share/ca-certificates/mozilla/*.crt '
          '> /etc/ssl/certs/ca-certificates.crt 2>/dev/null; '
          'echo certs_done',
        );
      }

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.4,
        message: 'Adding NodeSource repository...',
      ));
      // The NodeSource setup script internally runs apt-get which fails
      // (fork+exec issue). Add the repo manually instead.
      // Use curl -k as fallback if certs are still broken.
      await NativeBridge.runInProot(
        'curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key '
        '-o /tmp/nodesource.gpg.key 2>/dev/null || '
        'curl -fsSLk https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key '
        '-o /tmp/nodesource.gpg.key',
      );
      await NativeBridge.runInProot(
        'gpg --dearmor -o /usr/share/keyrings/nodesource.gpg '
        '< /tmp/nodesource.gpg.key 2>/dev/null; '
        'echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] '
        'https://deb.nodesource.com/node_22.x nodistro main" '
        '> /etc/apt/sources.list.d/nodesource.list; '
        'echo repo_added',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.5,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.6,
        message: 'Downloading Node.js...',
      ));
      await NativeBridge.runInProot(
        'apt-get -q -d install -y --no-install-recommends nodejs',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.75,
        message: 'Extracting Node.js packages...',
      ));
      await NativeBridge.extractDebPackages();

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.9,
        message: 'Verifying Node.js...',
      ));
      // npm's shebang is #!/usr/bin/env node — env needs to fork+exec
      // node, which fails in proot (level 2+ fork). Call node directly.
      final npmCli = '/usr/lib/node_modules/npm/bin/npm-cli.js';
      await NativeBridge.runInProot(
        'node --version && node $npmCli --version',
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
      await NativeBridge.runInProot('node $npmCli install -g openclaw');

      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot(
        'node $npmCli list -g openclaw',
      );
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

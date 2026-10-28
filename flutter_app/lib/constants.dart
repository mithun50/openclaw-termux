class AppConstants {
  static const String appName = 'OpenClaw';
  static const String version = '2026.10.20';
  static const String packageName = 'com.nxg.openclawproot';

  /// Matches ANSI escape sequences (e.g. color codes in terminal output).
  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String authorName = 'Mithun Gowda B';
  static const String authorEmail = 'mithungowda.b7411@gmail.com';
  static const String githubUrl = 'https://github.com/mithun50/openclaw-termux';
  static const String license = 'MIT';

  static const String githubApiLatestRelease =
      'https://api.github.com/repos/mithun50/openclaw-termux/releases/latest';

  // Project links
  static const String issuesUrl =
      'https://github.com/mithun50/openclaw-termux/issues';
  static const String releasesUrl =
      'https://github.com/mithun50/openclaw-termux/releases';
  static const String upstreamUrl = 'https://github.com/openclaw/openclaw';

  static const String gatewayHost = '127.0.0.1';

  /// Port the gateway binds to when `gateway.port` is absent from
  /// openclaw.json. The effective port is resolved at runtime by
  /// [GatewayConfig] - do not assume this value (#124).
  static const int defaultGatewayPort = 18789;

  /// Deprecated alias kept for call sites that only need the default.
  static const int gatewayPort = defaultGatewayPort;
  static const String gatewayUrl = 'http://$gatewayHost:$defaultGatewayPort';

  static const String ubuntuRootfsUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String rootfsArm64 = '${ubuntuRootfsUrl}arm64.tar.gz';
  static const String rootfsArmhf = '${ubuntuRootfsUrl}armhf.tar.gz';
  static const String rootfsAmd64 = '${ubuntuRootfsUrl}amd64.tar.gz';

  // Node.js binary tarball - downloaded directly by Flutter, extracted by Java.
  // Bypasses curl/gpg/NodeSource which fail inside proot.
  // Keep this >= 22.19.0: openclaw depends on undici, which declares
  // `engines.node >= 22.19.0`. Older runtimes emit EBADENGINE and can abort
  // the global install (#133).
  static const String nodeVersion = '22.23.2';
  static const String nodeBaseUrl =
      'https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-linux-';

  static String getNodeTarballUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return '${nodeBaseUrl}arm64.tar.xz';
      case 'arm':
        return '${nodeBaseUrl}armv7l.tar.xz';
      case 'x86_64':
        return '${nodeBaseUrl}x64.tar.xz';
      default:
        return '${nodeBaseUrl}arm64.tar.xz';
    }
  }

  static const int healthCheckIntervalMs = 5000;
  static const int maxAutoRestarts = 5;

  // Node constants
  static const int wsReconnectBaseMs = 350;
  static const double wsReconnectMultiplier = 1.7;
  static const int wsReconnectCapMs = 8000;
  static const String nodeRole = 'node';
  static const int pairingTimeoutMs = 300000;

  static const String channelName = 'com.nxg.openclawproot/native';
  static const String eventChannelName = 'com.nxg.openclawproot/gateway_logs';

  static String getRootfsUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return rootfsArm64;
      case 'arm':
        return rootfsArmhf;
      case 'x86_64':
        return rootfsAmd64;
      default:
        return rootfsArm64;
    }
  }
}

import 'package:flutter/material.dart';

/// Metadata for an optional development tool that can be installed
/// inside the proot Ubuntu environment.
class OptionalPackage {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String installCommand;
  final String uninstallCommand;

  /// Path relative to rootfs dir to check if installed.
  final String checkPath;
  final String estimatedSize;

  /// Pattern printed to stdout when installation finishes successfully.
  final String completionSentinel;

  const OptionalPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.installCommand,
    required this.uninstallCommand,
    required this.checkPath,
    required this.estimatedSize,
    required this.completionSentinel,
  });

  static const goPackage = OptionalPackage(
    id: 'go',
    name: 'Go (Golang)',
    description: 'Go programming language compiler and tools',
    icon: Icons.integration_instructions,
    color: Colors.cyan,
    installCommand:
        'set -e; '
        'echo ">>> Installing Go via apt..."; '
        'apt-get update -qq && apt-get install -y golang; '
        'go version; '
        'echo ">>> GO_INSTALL_COMPLETE"',
    uninstallCommand:
        'set -e; '
        'echo ">>> Removing Go..."; '
        'apt-get remove -y golang golang-go && apt-get autoremove -y; '
        'echo ">>> GO_UNINSTALL_COMPLETE"',
    checkPath: 'usr/bin/go',
    estimatedSize: '~150 MB',
    completionSentinel: 'GO_INSTALL_COMPLETE',
  );

  static const brewPackage = OptionalPackage(
    id: 'brew',
    name: 'Homebrew',
    description: 'The missing package manager for Linux',
    icon: Icons.science,
    color: Colors.amber,
    installCommand:
        'set -e; '
        'echo ">>> Installing Homebrew (this may take a while)..."; '
        'touch /.dockerenv; '
        'apt-get update -qq && apt-get install -y -qq '
        'build-essential procps curl file git; '
        'NONINTERACTIVE=1 /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; '
        r"grep -q 'linuxbrew' /root/.bashrc 2>/dev/null || {"
        ' echo \'eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\' >> /root/.bashrc; '
        '}; '
        'eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; '
        'brew --version; '
        'echo ">>> BREW_INSTALL_COMPLETE"',
    uninstallCommand:
        'set -e; '
        'echo ">>> Removing Homebrew..."; '
        'touch /.dockerenv; '
        'NONINTERACTIVE=1 /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || true; '
        'rm -rf /home/linuxbrew/.linuxbrew; '
        r"sed -i '/linuxbrew/d' /root/.bashrc; "
        'echo ">>> BREW_UNINSTALL_COMPLETE"',
    checkPath: 'home/linuxbrew/.linuxbrew/bin/brew',
    estimatedSize: '~500 MB',
    completionSentinel: 'BREW_INSTALL_COMPLETE',
  );

  /// All available optional packages.
  static const all = [goPackage, brewPackage];

  /// Sentinel for uninstall completion (derived from install sentinel).
  String get uninstallSentinel =>
      completionSentinel.replaceFirst('INSTALL', 'UNINSTALL');
}

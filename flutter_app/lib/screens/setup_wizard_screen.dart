import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../models/setup_state.dart';
import '../models/optional_package.dart';
import '../providers/setup_provider.dart';
import '../services/package_service.dart';
import '../widgets/progress_step.dart';
import 'onboarding_screen.dart';
import 'package_install_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  bool _started = false;
  Map<String, bool> _pkgStatuses = {};

  Future<void> _refreshPkgStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) setState(() => _pkgStatuses = statuses);
  }

  Future<void> _installPackage(OptionalPackage package) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageInstallScreen(package: package),
      ),
    );
    if (result == true) _refreshPkgStatuses();
  }

  Future<void> _beginSetup(SetupProvider provider) async {
    setState(() {
      _started = true;
    });
    await provider.runSetup();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Consumer<SetupProvider>(
          builder: (context, provider, _) {
            final state = provider.state;

            // Load package statuses once setup completes
            if (state.isComplete && _pkgStatuses.isEmpty) {
              _refreshPkgStatuses();
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Image.asset(
                    'assets/ic_launcher.png',
                    width: 64,
                    height: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('setupWizardTitle'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _started
                        ? l10n.t('setupWizardIntroRunning')
                        : l10n.t('setupWizardIntroIdle'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _buildSteps(state, theme, isDark, l10n),
                  ),
                  if (state.hasError) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                    state.error ?? 'Unknown error',
                                  style: TextStyle(
                                      color:
                                          theme.colorScheme.onErrorContainer),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.isComplete)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _goToOnboarding(context),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l10n.t('setupWizardConfigureApiKeys')),
                      ),
                    )
                  else if (!_started || state.hasError)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: provider.isRunning
                            ? null
                            : () => _beginSetup(provider),
                        icon: const Icon(Icons.download),
                        label: Text(
                          _started
                              ? l10n.t('setupWizardRetry')
                              : l10n.t('setupWizardBegin'),
                        ),
                      ),
                    ),
                  if (!_started) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        l10n.t('setupWizardRequirements'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'by ${AppConstants.authorName} | ${AppConstants.orgName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSteps(
    SetupState state,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final steps = [
      (1, l10n.t('setupWizardStepDownloadRootfs'), SetupStep.downloadingRootfs),
      (2, l10n.t('setupWizardStepExtractRootfs'), SetupStep.extractingRootfs),
      (3, l10n.t('setupWizardStepInstallNode'), SetupStep.installingNode),
      (
        4,
        l10n.t('setupWizardStepInstallOpenClaw'),
        SetupStep.installingOpenClaw
      ),
      (
        5,
        l10n.t('setupWizardStepConfigureBypass'),
        SetupStep.configuringBypass
      ),
    ];

    return ListView(
      children: [
        for (final (num, label, step) in steps)
          ProgressStep(
            stepNumber: num,
            label: state.step == step
                ? _localizedSetupMessage(l10n, state.message)
                : label,
            isActive: state.step == step,
            isComplete: state.stepNumber > step.index + 1 || state.isComplete,
            hasError: state.hasError && state.step == step,
            progress: state.step == step ? state.progress : null,
          ),
        if (state.isComplete) ...[
          ProgressStep(
            stepNumber: 6,
            label: l10n.t('setupWizardComplete'),
            isComplete: true,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l10n.t('setupWizardOptionalPackages'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final pkg in OptionalPackage.all)
            _buildPackageTile(theme, l10n, pkg, isDark),
        ],
      ],
    );
  }

  Widget _buildPackageTile(
    ThemeData theme,
    AppLocalizations l10n,
    OptionalPackage package,
    bool isDark,
  ) {
    final installed = _pkgStatuses[package.id] ?? false;
    final iconBg = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF3F4F6);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(package.icon,
              color: theme.colorScheme.onSurfaceVariant, size: 22),
        ),
        title: Row(
          children: [
            Text(package.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (installed) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l10n.t('commonInstalled'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.statusGreen,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ],
        ),
        subtitle: Text(
            '${_packageDescription(l10n, package)} (${package.estimatedSize})'),
        trailing: installed
            ? const Icon(Icons.check_circle, color: AppColors.statusGreen)
            : OutlinedButton(
                onPressed: () => _installPackage(package),
                child: Text(l10n.t('packagesInstall')),
              ),
      ),
    );
  }

  String _packageDescription(AppLocalizations l10n, OptionalPackage package) {
    switch (package.id) {
      case 'go':
        return l10n.t('packageGoDescription');
      case 'brew':
        return l10n.t('packageBrewDescription');
      case 'ssh':
        return l10n.t('packageSshDescription');
      default:
        return package.description;
    }
  }

  String _localizedSetupMessage(AppLocalizations l10n, String? message) {
    if (message == null || message.isEmpty) {
      return '';
    }

    final downloadProgress =
        RegExp(r'^Downloading: ([0-9.]+) MB / ([0-9.]+) MB$')
            .firstMatch(message);
    if (downloadProgress != null) {
      return l10n.t('setupWizardStatusDownloadingProgress', {
        'current': downloadProgress.group(1),
        'total': downloadProgress.group(2),
      });
    }

    final nodeDownloadProgress =
        RegExp(r'^Downloading Node\.js: ([0-9.]+) MB / ([0-9.]+) MB$')
            .firstMatch(message);
    if (nodeDownloadProgress != null) {
      return l10n.t('setupWizardStatusDownloadingNodeProgress', {
        'current': nodeDownloadProgress.group(1),
        'total': nodeDownloadProgress.group(2),
      });
    }

    final nodeVersionMatch =
        RegExp(r'^Downloading Node\.js (.+)\.\.\.$').firstMatch(message);
    if (nodeVersionMatch != null) {
      return l10n.t('setupWizardStatusDownloadingNode', {
        'version': nodeVersionMatch.group(1),
      });
    }

    switch (message) {
      case 'Setup complete':
        return l10n.t('setupWizardStatusSetupComplete');
      case 'Setup required':
        return l10n.t('setupWizardStatusSetupRequired');
      case 'Setting up directories...':
        return l10n.t('setupWizardStatusSettingUpDirs');
      case 'Downloading Ubuntu rootfs...':
        return l10n.t('setupWizardStatusDownloadingUbuntuRootfs');
      case 'Extracting rootfs (this takes a while)...':
        return l10n.t('setupWizardStatusExtractingRootfs');
      case 'Rootfs extracted':
        return l10n.t('setupWizardStatusRootfsExtracted');
      case 'Fixing rootfs permissions...':
        return l10n.t('setupWizardStatusFixingPermissions');
      case 'Updating package lists...':
        return l10n.t('setupWizardStatusUpdatingPackageLists');
      case 'Installing base packages...':
        return l10n.t('setupWizardStatusInstallingBasePackages');
      case 'Extracting Node.js...':
        return l10n.t('setupWizardStatusExtractingNode');
      case 'Verifying Node.js...':
        return l10n.t('setupWizardStatusVerifyingNode');
      case 'Node.js installed':
        return l10n.t('setupWizardStatusNodeInstalled');
      case 'Installing OpenClaw (this may take a few minutes)...':
        return l10n.t('setupWizardStatusInstallingOpenClaw');
      case 'Creating bin wrappers...':
        return l10n.t('setupWizardStatusCreatingBinWrappers');
      case 'Verifying OpenClaw...':
        return l10n.t('setupWizardStatusVerifyingOpenClaw');
      case 'OpenClaw installed':
        return l10n.t('setupWizardStatusOpenClawInstalled');
      case 'Bionic Bypass configured':
        return l10n.t('setupWizardStatusBypassConfigured');
      case 'Setup complete! Ready to start the gateway.':
        return l10n.t('setupWizardStatusReady');
      default:
        return message;
    }
  }

  void _goToOnboarding(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isFirstRun: true),
      ),
    );
  }
}

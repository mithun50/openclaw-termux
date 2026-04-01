import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../models/setup_state.dart';
import '../models/optional_package.dart';
import '../providers/setup_provider.dart';
import '../services/package_service.dart';
import '../utils/responsive.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Consumer<SetupProvider>(
          builder: (context, provider, _) {
            final state = provider.state;

            if (state.isComplete && _pkgStatuses.isEmpty) {
              _refreshPkgStatuses();
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Responsive.constrain(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Image.asset('assets/ic_launcher.png',
                        width: 64, height: 64),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.setupOpenClaw,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _started
                          ? AppStrings.setupRunning
                          : AppStrings.setupDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(child: _buildSteps(state, theme, isDark)),
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
                                    AppStrings.translateError(
                                        state.error ?? 'Unknown error'),
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
                          label: Text(AppStrings.configureApiKeys),
                        ),
                      )
                    else if (!_started || state.hasError)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: provider.isRunning
                              ? null
                              : () {
                                  setState(() => _started = true);
                                  provider.runSetup();
                                },
                          icon: const Icon(Icons.download),
                          label: Text(_started
                              ? AppStrings.retrySetup
                              : AppStrings.beginSetup),
                        ),
                      ),
                    if (!_started) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          AppStrings.storageRequired,
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSteps(SetupState state, ThemeData theme, bool isDark) {
    final steps = [
      (1, AppStrings.downloadRootfs, SetupStep.downloadingRootfs),
      (2, AppStrings.extractRootfs, SetupStep.extractingRootfs),
      (3, AppStrings.installNode, SetupStep.installingNode),
      (4, AppStrings.installOpenClaw, SetupStep.installingOpenClaw),
      (5, AppStrings.configureBionicBypass, SetupStep.configuringBypass),
    ];

    return ListView(
      children: [
        for (final (num, label, step) in steps)
          ProgressStep(
            stepNumber: num,
            label: state.step == step ? state.message : label,
            isActive: state.step == step,
            isComplete: state.stepNumber > step.index || state.isComplete,
            hasError: state.hasError && state.step == step,
            progress: state.step == step ? state.progress : null,
          ),
        if (state.isComplete) ...[
          ProgressStep(
            stepNumber: 6,
            label: AppStrings.setupComplete,
            isComplete: true,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              AppStrings.optionalPackages,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final pkg in OptionalPackage.all)
            _buildPackageTile(theme, pkg, isDark),
        ],
      ],
    );
  }

  Widget _buildPackageTile(
      ThemeData theme, OptionalPackage package, bool isDark) {
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
                child: Text(
                  AppStrings.installed,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.statusGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('${package.description} (${package.estimatedSize})'),
        trailing: installed
            ? const Icon(Icons.check_circle, color: AppColors.statusGreen)
            : OutlinedButton(
                onPressed: () => _installPackage(package),
                child: Text(AppStrings.install),
              ),
      ),
    );
  }

  void _goToOnboarding(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isFirstRun: true),
      ),
    );
  }
}

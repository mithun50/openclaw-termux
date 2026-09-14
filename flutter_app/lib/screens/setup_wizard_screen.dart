import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import '../models/optional_package.dart';
import '../providers/setup_provider.dart';
import '../services/package_service.dart';
import '../widgets/progress_step.dart';
import 'onboarding_screen.dart';
import 'package_install_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  /// True when the rootfs already exists and only missing pieces (Node.js,
  /// OpenClaw) need reinstalling. Skips the ~500MB rootfs download and starts
  /// automatically, since the user did not choose to be here (#125).
  final bool repairMode;

  const SetupWizardScreen({super.key, this.repairMode = false});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  bool _started = false;
  bool _downloadConsent = false;
  Map<String, bool> _pkgStatuses = {};

  @override
  void initState() {
    super.initState();
    if (widget.repairMode) {
      // Repair is not a user-initiated action, so begin immediately rather
      // than showing a button the user has to discover.
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SetupProvider>().runRepair();
      });
    }
  }

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
                    widget.repairMode ? 'Repair OpenClaw' : 'Setup OpenClaw',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.repairMode
                        ? 'Some components are missing. Reinstalling them - '
                            'the Ubuntu rootfs is kept, so this is quicker than a full setup.'
                        : _started
                            ? 'Setting up the environment. This may take several minutes.'
                            : 'This will download Ubuntu, Node.js, and OpenClaw into a self-contained environment.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _buildSteps(state, theme, isDark),
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
                            Icon(Icons.error_outline, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  state.error ?? 'Unknown error',
                                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
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
                        label: const Text('Configure API Keys'),
                      ),
                    )
                  else if (!_started || state.hasError) ...[
                    // F-Droid's inclusion policy requires explicit opt-in
                    // consent before an app downloads executable code, and
                    // requires that the user be told they are bypassing
                    // F-Droid's review. Setup cannot start without this.
                    if (!_started && !widget.repairMode)
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.download_for_offline_outlined,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This downloads and runs software that is '
                                      'not part of the app',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Setup fetches about 500 MB and runs it on your '
                                'device:',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              ...const [
                                'Ubuntu base image, from cdimage.ubuntu.com',
                                'Node.js runtime, from nodejs.org',
                                'openclaw and its dependencies, from the npm registry',
                                'Ubuntu packages, from archive.ubuntu.com',
                              ].map((line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('\u2022  $line',
                                        style: theme.textTheme.bodySmall),
                                  )),
                              const SizedBox(height: 8),
                              Text(
                                'These are downloaded directly from their '
                                'official sources and are not reviewed or '
                                'verified by whoever distributed this app. '
                                'Nothing is downloaded until you continue.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _downloadConsent,
                                onChanged: (v) => setState(
                                    () => _downloadConsent = v ?? false),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(
                                  'I understand and want to continue',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_started && !widget.repairMode)
                      const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (provider.isRunning ||
                                (!_started &&
                                    !widget.repairMode &&
                                    !_downloadConsent))
                            ? null
                            : () {
                                setState(() => _started = true);
                                if (widget.repairMode) {
                                  provider.runRepair();
                                } else {
                                  provider.runSetup();
                                }
                              },
                        icon: const Icon(Icons.download),
                        label: Text(_started ? 'Retry Setup' : 'Begin Setup'),
                      ),
                    ),
                  ],
                  if (!_started) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Requires ~500MB of storage and an internet connection',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'by ${AppConstants.authorName}',
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

  Widget _buildSteps(SetupState state, ThemeData theme, bool isDark) {
    final steps = [
      (1, 'Download Ubuntu rootfs', SetupStep.downloadingRootfs),
      (2, 'Extract rootfs', SetupStep.extractingRootfs),
      (3, 'Install Node.js', SetupStep.installingNode),
      (4, 'Install OpenClaw', SetupStep.installingOpenClaw),
      (5, 'Configure Bionic Bypass', SetupStep.configuringBypass),
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
          const ProgressStep(
            stepNumber: 6,
            label: 'Setup complete!',
            isComplete: true,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'OPTIONAL PACKAGES',
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

  Widget _buildPackageTile(ThemeData theme, OptionalPackage package, bool isDark) {
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
          child: Icon(package.icon, color: theme.colorScheme.onSurfaceVariant, size: 22),
        ),
        title: Row(
          children: [
            Text(package.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (installed) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Installed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.statusGreen,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ],
        ),
        subtitle: Text('${package.description} (${package.estimatedSize})'),
        trailing: installed
            ? const Icon(Icons.check_circle, color: AppColors.statusGreen)
            : OutlinedButton(
                onPressed: () => _installPackage(package),
                child: const Text('Install'),
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

import 'package:flutter/material.dart';
import '../app.dart';
import '../l10n/app_localizations.dart';
import '../models/optional_package.dart';
import '../services/package_service.dart';
import 'package_install_screen.dart';

/// Lists all optional packages with install/uninstall actions.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  Map<String, bool> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToInstall(
    OptionalPackage package, {
    bool isUninstall = false,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageInstallScreen(
          package: package,
          isUninstall: isUninstall,
        ),
      ),
    );
    if (result == true) {
      _refreshStatuses();
    }
  }

  void _confirmUninstall(OptionalPackage package) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('packagesUninstallTitle', {'name': package.name})),
        content: Text(
          l10n.t('packagesUninstallDescription', {'name': package.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('commonCancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToInstall(package, isUninstall: true);
            },
            child: Text(l10n.t('packagesUninstall')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('packagesTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.t('packagesDescription'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final pkg in OptionalPackage.all)
                  _buildPackageCard(theme, l10n, pkg, isDark),
              ],
            ),
    );
  }

  Widget _buildPackageCard(
    ThemeData theme,
    AppLocalizations l10n,
    OptionalPackage package,
    bool isDark,
  ) {
    final installed = _statuses[package.id] ?? false;
    final iconBg = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF3F4F6);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(package.icon, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        package.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (installed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.t('commonInstalled'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.statusGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _packageDescription(l10n, package),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    package.estimatedSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            installed
                ? OutlinedButton(
                    onPressed: () => _confirmUninstall(package),
                    child: Text(l10n.t('packagesUninstall')),
                  )
                : FilledButton(
                    onPressed: () => _navigateToInstall(package),
                    child: Text(l10n.t('packagesInstall')),
                  ),
          ],
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
}

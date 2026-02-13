import 'package:flutter/material.dart';
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Uninstall ${package.name}?'),
        content: Text(
          'This will remove ${package.name} from the environment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToInstall(package, isUninstall: true);
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Optional Packages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Development tools you can install inside the Ubuntu environment.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final pkg in OptionalPackage.all)
                  _buildPackageCard(theme, pkg),
              ],
            ),
    );
  }

  Widget _buildPackageCard(ThemeData theme, OptionalPackage package) {
    final installed = _statuses[package.id] ?? false;

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
                color: package.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(package.icon, color: package.color),
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
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Installed',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description,
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
                    child: const Text('Uninstall'),
                  )
                : FilledButton(
                    onPressed: () => _navigateToInstall(package),
                    child: const Text('Install'),
                  ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../utils/responsive.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'node_screen.dart';
import 'configure_screen.dart';
import 'onboarding_screen.dart';
import 'terminal_screen.dart';
import 'web_dashboard_screen.dart';
import 'logs_screen.dart';
import 'packages_screen.dart';
import 'providers_screen.dart';
import 'settings_screen.dart';
import 'ssh_screen.dart';
import 'nine_router_terminal_screen.dart';
import 'nine_router_webview_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Responsive.constrain(
        SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GatewayControls(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  AppStrings.quickActions,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (isTablet)
                _buildTabletGrid(context, theme)
              else
                _buildPhoneList(context, theme),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      'OpenClaw v${AppConstants.version}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${AppConstants.authorName} | ${AppConstants.orgName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 手机：竖向列�?
  Widget _buildPhoneList(BuildContext context, ThemeData theme) {
    return Column(
      children: _buildCards(context),
    );
  }

  // 平板�?列网�?
  Widget _buildTabletGrid(BuildContext context, ThemeData theme) {
    final cards = _buildCards(context);
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: 12),
            Expanded(
                child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  List<Widget> _buildCards(BuildContext context) {
    return [
      StatusCard(
        title: AppStrings.terminal,
        subtitle: AppStrings.terminalSubtitle,
        icon: Icons.terminal,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TerminalScreen()),
        ),
      ),
      Consumer<GatewayProvider>(
        builder: (context, provider, _) {
          final url = provider.state.dashboardUrl;
          final token = url != null
              ? RegExp(r'#token=([0-9a-f]+)').firstMatch(url)?.group(1)
              : null;
          final subtitle = provider.state.isRunning
              ? (token != null
                  ? 'Token: ${token.substring(0, (token.length > 8 ? 8 : token.length))}...'
                  : AppStrings.webDashboardSubtitle)
              : AppStrings.startGatewayFirst;
          return StatusCard(
            title: AppStrings.webDashboard,
            subtitle: subtitle,
            icon: Icons.dashboard,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (token != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: AppStrings.copyDashboardUrl,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.dashboardUrlCopied)),
                      );
                    },
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: provider.state.isRunning
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WebDashboardScreen(url: url),
                      ),
                    )
                : null,
          );
        },
      ),
      StatusCard(
        title: AppStrings.isChinese ? '9Router 终端' : '9Router Terminal',
        subtitle: AppStrings.isChinese
            ? '启动免费 AI 账号代理服务'
            : 'Start free AI account proxy',
        icon: Icons.swap_horiz,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NineRouterTerminalScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.isChinese ? '9Router 控制台' : '9Router Console',
        subtitle:
            AppStrings.isChinese ? '打开 Web 管理界面' : 'Open web management UI',
        icon: Icons.dashboard_customize,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NineRouterWebviewScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.onboarding,
        subtitle: AppStrings.onboardingSubtitle,
        icon: Icons.vpn_key,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.configure,
        subtitle: AppStrings.configureSubtitle,
        icon: Icons.tune,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConfigureScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.aiProviders,
        subtitle: AppStrings.aiProvidersSubtitle,
        icon: Icons.model_training,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProvidersScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.packages,
        subtitle: AppStrings.packagesSubtitle,
        icon: Icons.extension,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PackagesScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.sshAccess,
        subtitle: AppStrings.sshAccessSubtitle,
        icon: Icons.terminal,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SshScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.logs,
        subtitle: AppStrings.logsSubtitle,
        icon: Icons.article_outlined,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LogsScreen()),
        ),
      ),
      StatusCard(
        title: AppStrings.snapshot,
        subtitle: AppStrings.snapshotSubtitle,
        icon: Icons.backup,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      Consumer<NodeProvider>(
        builder: (context, nodeProvider, _) {
          final nodeState = nodeProvider.state;
          return StatusCard(
            title: AppStrings.node,
            subtitle: nodeState.isPaired
                ? AppStrings.nodeConnected
                : nodeState.isDisabled
                    ? AppStrings.nodeCapabilities
                    : nodeState.statusText,
            icon: Icons.devices,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NodeScreen()),
            ),
          );
        },
      ),
    ];
  }
}

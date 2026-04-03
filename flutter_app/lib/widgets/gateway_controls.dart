import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../models/gateway_state.dart';
import '../providers/gateway_provider.dart';
import '../screens/logs_screen.dart';
import '../screens/web_dashboard_screen.dart';

class GatewayControls extends StatelessWidget {
  const GatewayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.gateway,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _statusBadge(state.status, theme),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.isRunning) ...[
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WebDashboardScreen(
                                  url: state.dashboardUrl,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            state.dashboardUrl ?? AppConstants.gatewayUrl,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontFamily: 'monospace',
                              decoration: TextDecoration.underline,
                              decorationColor: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: AppStrings.copyUrl,
                        onPressed: () {
                          final url =
                              state.dashboardUrl ?? AppConstants.gatewayUrl;
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppStrings.urlCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: AppStrings.openDashboard,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WebDashboardScreen(
                                url: state.dashboardUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (state.errorMessage != null)
                  Text(
                    state.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.isStopped || state.status == GatewayStatus.error)
                      FilledButton.icon(
                        onPressed: () => provider.start(),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(AppStrings.startGateway),
                      ),
                    if (state.isRunning ||
                        state.status == GatewayStatus.starting)
                      OutlinedButton.icon(
                        onPressed: () => provider.stop(),
                        icon: const Icon(Icons.stop),
                        label: Text(AppStrings.stopGateway),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      ),
                      icon: const Icon(Icons.article_outlined),
                      label: Text(AppStrings.viewLogs),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(GatewayStatus status, ThemeData theme) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case GatewayStatus.running:
        color = AppColors.statusGreen;
        label = AppStrings.gatewayRunning;
        icon = Icons.check_circle_outline;
      case GatewayStatus.starting:
        color = AppColors.statusAmber;
        label = AppStrings.gatewayStarting;
        icon = Icons.hourglass_top;
      case GatewayStatus.error:
        color = AppColors.statusRed;
        label = AppStrings.gatewayError;
        icon = Icons.error_outline;
      case GatewayStatus.stopped:
        color = AppColors.statusGrey;
        label = AppStrings.gatewayStopped;
        icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

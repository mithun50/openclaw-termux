import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../models/node_state.dart';
import '../providers/node_provider.dart';
import '../screens/node_screen.dart';

class NodeControls extends StatelessWidget {
  const NodeControls({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<NodeProvider>(
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
                        AppStrings.node,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _statusBadge(state.status, theme),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.isPaired) ...[
                  Text(
                    'Connected to ${state.gatewayHost}:${state.gatewayPort}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (state.pairingCode != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Pairing code: ',
                        style: theme.textTheme.bodyMedium,
                      ),
                      SelectableText(
                        state.pairingCode!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
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
                    if (state.isDisabled)
                      FilledButton.icon(
                        onPressed: () => provider.enable(),
                        icon: const Icon(Icons.power_settings_new),
                        label: Text(AppStrings.enableNode),
                      ),
                    if (!state.isDisabled) ...[
                      OutlinedButton.icon(
                        onPressed: () => provider.disable(),
                        icon: const Icon(Icons.stop),
                        label: Text(AppStrings.disableNode),
                      ),
                      if (state.status == NodeStatus.error ||
                          state.status == NodeStatus.disconnected)
                        OutlinedButton.icon(
                          onPressed: () => provider.reconnect(),
                          icon: const Icon(Icons.refresh),
                          label: Text(AppStrings.reconnect),
                        ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NodeScreen()),
                      ),
                      icon: const Icon(Icons.settings),
                      label: Text(AppStrings.nodeConfigure),
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

  Widget _statusBadge(NodeStatus status, ThemeData theme) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case NodeStatus.paired:
        color = AppColors.statusGreen;
        label = AppStrings.nodePaired;
        icon = Icons.check_circle_outline;
      case NodeStatus.connecting:
      case NodeStatus.challenging:
      case NodeStatus.pairing:
        color = AppColors.statusAmber;
        label = AppStrings.nodeConnecting;
        icon = Icons.hourglass_top;
      case NodeStatus.error:
        color = AppColors.statusRed;
        label = AppStrings.gatewayError;
        icon = Icons.error_outline;
      case NodeStatus.disabled:
        color = AppColors.statusGrey;
        label = AppStrings.nodeDisabled;
        icon = Icons.circle_outlined;
      case NodeStatus.disconnected:
        color = AppColors.statusGrey;
        label = AppStrings.nodeDisconnected;
        icon = Icons.link_off;
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusDot(state.status),
                    const SizedBox(width: 12),
                    Text(
                      'Node ${state.statusText}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                        label: const Text('Enable Node'),
                      ),
                    if (!state.isDisabled) ...[
                      FilledButton.icon(
                        onPressed: () => provider.disable(),
                        icon: const Icon(Icons.stop),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                        label: const Text('Disable Node'),
                      ),
                      if (state.status == NodeStatus.error ||
                          state.status == NodeStatus.disconnected)
                        OutlinedButton.icon(
                          onPressed: () => provider.reconnect(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reconnect'),
                        ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NodeScreen()),
                      ),
                      icon: const Icon(Icons.settings),
                      label: const Text('Configure'),
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

  Widget _statusDot(NodeStatus status) {
    Color color;
    switch (status) {
      case NodeStatus.paired:
        color = Colors.green;
      case NodeStatus.connecting:
      case NodeStatus.challenging:
      case NodeStatus.pairing:
        color = Colors.orange;
      case NodeStatus.error:
        color = Colors.red;
      case NodeStatus.disabled:
      case NodeStatus.disconnected:
        color = Colors.grey;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          if (status == NodeStatus.paired)
            BoxShadow(
              color: color.withAlpha(100),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
    );
  }
}

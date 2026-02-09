import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../providers/gateway_provider.dart';
import '../screens/logs_screen.dart';

class GatewayControls extends StatelessWidget {
  const GatewayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<GatewayProvider>(
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
                      'Gateway ${state.statusText}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.isRunning) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          state.dashboardUrl ?? AppConstants.gatewayUrl,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy URL',
                        onPressed: () {
                          final url = state.dashboardUrl ?? AppConstants.gatewayUrl;
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL copied to clipboard'),
                              duration: Duration(seconds: 2),
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
                        label: const Text('Start Gateway'),
                      ),
                    if (state.isRunning || state.status == GatewayStatus.starting)
                      FilledButton.icon(
                        onPressed: () => provider.stop(),
                        icon: const Icon(Icons.stop),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                        label: const Text('Stop Gateway'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      ),
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('View Logs'),
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

  Widget _statusDot(GatewayStatus status) {
    Color color;
    switch (status) {
      case GatewayStatus.running:
        color = Colors.green;
      case GatewayStatus.starting:
        color = Colors.orange;
      case GatewayStatus.error:
        color = Colors.red;
      case GatewayStatus.stopped:
        color = Colors.grey;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          if (status == GatewayStatus.running)
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../providers/gateway_provider.dart';
import '../services/screenshot_service.dart';
import '../utils/log_parser.dart';
import '../utils/responsive.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _screenshotKey = GlobalKey();
  bool _autoScroll = true;
  bool _friendlyMode = true; // 友好模式 vs 原始模式
  String _filter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.gatewayLogs),
        actions: [
          // 切换友好/原始模式
          IconButton(
            icon: Icon(_friendlyMode ? Icons.code : Icons.auto_awesome),
            tooltip: _friendlyMode
                ? (AppStrings.isChinese ? '切换到原始日志' : 'Raw logs')
                : (AppStrings.isChinese ? '切换到友好模式' : 'Friendly mode'),
            onPressed: () => setState(() => _friendlyMode = !_friendlyMode),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: AppStrings.screenshot,
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_top,
            ),
            tooltip: _autoScroll
                ? AppStrings.autoScrollOn
                : AppStrings.autoScrollOff,
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: AppStrings.copyAllLogs,
            onPressed: () => _copyLogs(context),
          ),
        ],
      ),
      body: Responsive.constrain(
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppStrings.filterLogs,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            Expanded(
              child: RepaintBoundary(
                key: _screenshotKey,
                child: Consumer<GatewayProvider>(
                  builder: (context, provider, _) {
                    final logs = provider.state.logs;
                    final filtered = _filter.isEmpty
                        ? logs
                        : logs
                            .where((l) =>
                                l.toLowerCase().contains(_filter.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          logs.isEmpty
                              ? AppStrings.noLogsYet
                              : AppStrings.noMatchingLogs,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_autoScroll && _scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final line = filtered[index];
                        if (_friendlyMode) {
                          return _buildFriendlyLogItem(line, theme);
                        }
                        return _buildRawLogItem(line, theme);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 友好模式：卡片样式
  Widget _buildFriendlyLogItem(String line, ThemeData theme) {
    final parsed = LogParser.parse(line, theme);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: parsed.color.withAlpha(isDark ? 15 : 10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: parsed.color.withAlpha(40)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: parsed.detail != null ? () => _showRawLog(line) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(parsed.icon, size: 16, color: parsed.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsed.friendlyMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (parsed.time.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          parsed.time,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (parsed.detail != null)
                  Icon(Icons.chevron_right,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 原始模式：等宽字体文本
  Widget _buildRawLogItem(String line, ThemeData theme) {
    return Text(
      line,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: _logColor(line, theme),
      ),
    );
  }

  void _showRawLog(String line) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.isChinese ? '原始日志' : 'Raw Log'),
        content: SingleChildScrollView(
          child: SelectableText(
            line,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: line));
              Navigator.pop(ctx);
            },
            child: Text(AppStrings.copy),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.done),
          ),
        ],
      ),
    );
  }

  Color _logColor(String line, ThemeData theme) {
    if (line.contains('[ERR]') || line.contains('ERROR')) {
      return theme.colorScheme.error;
    }
    if (line.contains('[WARN]') || line.contains('WARNING')) {
      return AppColors.statusAmber;
    }
    if (line.contains('[INFO]')) return AppColors.mutedText;
    return theme.colorScheme.onSurface;
  }

  Future<void> _takeScreenshot() async {
    final path =
        await ScreenshotService.capture(_screenshotKey, prefix: 'logs');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null ? '截图已保存: ${path.split('/').last}' : '截图失败'),
      ),
    );
  }

  void _copyLogs(BuildContext context) {
    final provider = context.read<GatewayProvider>();
    final text = provider.state.logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.copied)),
    );
  }
}

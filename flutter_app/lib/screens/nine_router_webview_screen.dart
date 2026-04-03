import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../utils/responsive.dart';

class NineRouterWebviewScreen extends StatefulWidget {
  const NineRouterWebviewScreen({super.key});

  @override
  State<NineRouterWebviewScreen> createState() =>
      _NineRouterWebviewScreenState();
}

class _NineRouterWebviewScreenState extends State<NineRouterWebviewScreen> {
  static const String _url = 'http://127.0.0.1:20128/';

  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _loading = true;
          _hasError = false;
        }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            setState(() {
              _loading = false;
              _hasError = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.isChinese ? '9Router 控制台' : '9Router Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.isChinese ? '刷新' : 'Refresh',
            onPressed: () {
              setState(() {
                _loading = true;
                _hasError = false;
              });
              _controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: AppStrings.openInBrowser,
            onPressed: () => launchUrl(Uri.parse(_url),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: _hasError
          ? Responsive.constrain(Center(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 48 : 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off,
                        size: isTablet ? 80 : 64,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.isChinese
                          ? '9Router 未运行'
                          : '9Router is not running',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.isChinese
                          ? '请先在"9Router 终端"中启动服务，然后返回此页面。'
                          : 'Please start the service in "9Router Terminal" first.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _hasError = false;
                        });
                        _controller.reload();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(AppStrings.reconnect),
                    ),
                  ],
                ),
              ),
            ))
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}

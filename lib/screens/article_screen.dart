import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/url_utils.dart';

class ArticleScreen extends StatefulWidget {
  final String title;
  final String url;

  const ArticleScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  int _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  void _loadArticle() {
    final uri = UrlUtils.parseHttpUrl(widget.url);
    if (uri == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'This article URL is not safe to open.';
      });
      return;
    }

    final webViewUri = UrlUtils.upgradeToHttps(uri);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = UrlUtils.parseHttpUrl(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'http') {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage =
                      'This article uses an insecure link. Open it in your browser or copy the link.';
                });
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(webViewUri);

    _controller = controller;
  }

  Future<void> _openInBrowser() async {
    final uri = UrlUtils.parseHttpUrl(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Open in browser',
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: _errorMessage != null || controller == null
          ? _ArticleError(
              message: _errorMessage ?? 'Could not open this article.',
              onRetry: _loadArticle,
              onOpenInBrowser: _openInBrowser,
              onCopyLink: _copyLink,
            )
          : WebViewWidget(controller: controller),
    );
  }
}

class _ArticleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onCopyLink;

  const _ArticleError({
    required this.message,
    required this.onRetry,
    required this.onOpenInBrowser,
    required this.onCopyLink,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load article',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open in browser'),
                ),
                OutlinedButton.icon(
                  onPressed: onCopyLink,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

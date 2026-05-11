import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class WebPage extends StatefulWidget {
  final String url;
  final String? title;
  final bool showAppBar;
  final bool scrolling;

  const WebPage({
    super.key,
    required this.url,
    this.title,
    this.showAppBar = true,
    this.scrolling = true,
  });

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  bool _isLoading = true;
  late final String _viewId;
  html.IFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _viewId = 'iframe-${DateTime.now().millisecondsSinceEpoch}';
    _initWebView();
  }

  void _initWebView() {
    _iframeElement = html.IFrameElement()
      ..src = widget.url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    if (!widget.scrolling) {
      _iframeElement!.style.overflow = 'hidden';
      _iframeElement!.setAttribute('scrolling', 'no');
    }

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      return _iframeElement!;
    });

    _iframeElement!.onLoad.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted || !_isLoading) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _iframeElement?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title ?? _extractHost(widget.url)),
              centerTitle: true,
              elevation: 2,
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                  tooltip: '刷新页面',
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: _openInBrowser,
                  tooltip: '在浏览器中打开',
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          HtmlElementView(viewType: _viewId),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '页面加载中...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _refresh() {
    setState(() {
      _isLoading = true;
    });
    _iframeElement?.src = widget.url;
  }

  void _openInBrowser() {
    html.window.open(widget.url, '_blank');
  }

  String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return '网页';
    }
  }
}

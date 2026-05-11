import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _opening = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInBrowser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title ?? _extractHost(widget.url)),
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_opening) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? '桌面端暂不内嵌网页，已尝试使用系统浏览器打开：${widget.url}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _openInBrowser,
                child: const Text('重新打开浏览器'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    if (_opening) {
      return;
    }
    setState(() {
      _opening = true;
      _errorMessage = null;
    });
    try {
      final uri = Uri.parse(widget.url);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!opened) {
        setState(() {
          _errorMessage = '系统浏览器打开失败：${widget.url}';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '系统浏览器打开失败：$error';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _opening = false;
      });
    }
  }

  String _extractHost(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return '网页';
    }
  }
}

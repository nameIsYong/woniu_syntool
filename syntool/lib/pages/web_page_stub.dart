import 'package:flutter/material.dart';

class WebPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title ?? '网页')) : null,
      body: const Center(
        child: Text('当前平台暂不支持内嵌网页'),
      ),
    );
  }
}

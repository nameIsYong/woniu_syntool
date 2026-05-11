import 'package:flutter/material.dart';

class CustomSelectableText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const CustomSelectableText({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      // 显示的文本
      controller: TextEditingController(text: text),
      // 禁用编辑（核心：仅保留选中功能）
      readOnly: true,
      // 禁用光标（可选）
      showCursor: false,
      // 禁用边框（模拟Text的无框样式）
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      // 自定义样式
      style: style ?? const TextStyle(fontSize: 16, color: Colors.black),
      // 配置工具栏（仅保留复制/全选）
      toolbarOptions: const ToolbarOptions(
        copy: true,
        selectAll: true,
        cut: false,
        paste: false,
      ),
      // 多行支持
      maxLines: null,
      // 自定义选中背景色（可选）
      selectionControls: MaterialTextSelectionControls(),
    );
  }
}


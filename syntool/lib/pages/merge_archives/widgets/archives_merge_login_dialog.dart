import 'package:flutter/material.dart';

class ArchivesMergeLoginDialog extends StatefulWidget {
  final Future<void> Function(String account, String password) onSubmit;

  const ArchivesMergeLoginDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<ArchivesMergeLoginDialog> createState() => _ArchivesMergeLoginDialogState();
}

class _ArchivesMergeLoginDialogState extends State<ArchivesMergeLoginDialog> {
  final TextEditingController _accountController = TextEditingController(text: "13100000000");
  final TextEditingController _passwordController = TextEditingController(text: "Abc654321");
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
    });

    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();

    if (account.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = '请输入账号和密码';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(account, password);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _fillPasswordWithLastSixDigits() {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      setState(() {
        _errorText = '请先输入账号';
      });
      return;
    }
    if (account.length < 6) {
      setState(() {
        _errorText = '账号长度不足6位，无法截取后6位';
      });
      return;
    }
    setState(() {
      _passwordController.text = account.substring(account.length - 6);
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录档案合并功能'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _accountController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: '账号',
                hintText: '请输入账号',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_isSubmitting,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
                suffixIcon: TextButton(
                  onPressed: _isSubmitting ? null : _fillPasswordWithLastSixDigits,
                  child: const Text('<==账号后6位'),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录'),
        ),
      ],
    );
  }
}

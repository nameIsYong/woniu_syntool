import 'package:flutter/material.dart';

class PhysicalMergeAuthBar extends StatelessWidget {
  final bool isLoggedIn;
  final String institutionName;
  final bool isBusy;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const PhysicalMergeAuthBar({
    super.key,
    required this.isLoggedIn,
    required this.institutionName,
    required this.isBusy,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '合并体检',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isLoggedIn ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isLoggedIn ? Colors.green[200]! : Colors.orange[200]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLoggedIn ? Icons.apartment : Icons.lock_outline,
                size: 14,
                color: isLoggedIn ? Colors.green[700] : Colors.orange[700],
              ),
              const SizedBox(width: 4),
              Text(
                isLoggedIn ? institutionName : '未登录',
                style: TextStyle(
                  fontSize: 12,
                  color: isLoggedIn ? Colors.green[800] : Colors.orange[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!isLoggedIn)
          ElevatedButton.icon(
            onPressed: isBusy ? null : onLogin,
            icon: const Icon(Icons.login, size: 16),
            label: const Text('登录'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        if (isLoggedIn)
          OutlinedButton.icon(
            onPressed: isBusy ? null : onLogout,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('退出登录'),
            style: OutlinedButton.styleFrom(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
      ],
    );
  }
}

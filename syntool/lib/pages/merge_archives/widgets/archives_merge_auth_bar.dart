import 'package:flutter/material.dart';

class ArchivesMergeAuthBar extends StatelessWidget {
  final bool isLoggedIn;
  final String institutionName;
  final bool isBusy;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const ArchivesMergeAuthBar({
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
          '档案合并',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(width: 12),
        if (!isLoggedIn)
          ElevatedButton.icon(
            onPressed: isBusy ? null : onLogin,
            icon: const Icon(Icons.login, size: 18),
            label: const Text('登录'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        if (isLoggedIn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 16, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Text(
                  institutionName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: isBusy ? null : onLogout,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '退出',
                      style: TextStyle(
                        fontSize: 12,
                        color: isBusy ? Colors.grey : const Color(0xFF2E7D32),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

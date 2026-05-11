import 'package:flutter/material.dart';
import 'task_list_page.dart';
import 'billing_config_page.dart';
import 'merge_archives/merge_archives_page.dart';
import 'merge_physical/physical_merge_page.dart';
import 'upload_screening/upload_screening_page.dart';

/// 首页 - 九宫格菜单
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final List<MenuItemData> _menus = [
    MenuItemData(
      icon: Icons.sync,
      label: '批量同步',
      color: const Color(0xFF1976D2),
    ),
    MenuItemData(
      icon: Icons.folder_copy,
      label: '开单权限配置',
      color: const Color(0xFF2196F3),
    ),
    MenuItemData(
      icon: Icons.medical_services,
      label: '体检合并',
      color: const Color(0xFF42A5F5),
    ),
    MenuItemData(
      icon: Icons.cloud_upload,
      label: '健康筛查上传',
      color: const Color(0xFF0D47A1),
    ),
    MenuItemData(
      icon: Icons.merge_type,
      label: '档案合并',
      color: const Color(0xFF1E88E5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(
                _menus.length,
                (index) => _buildMenuCard(context, index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建菜单卡片
  Widget _buildMenuCard(BuildContext context, int index) {
    final menu = _menus[index];

    return SizedBox(
      width: 200,
      height: 100,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _handleMenuTap(context, index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  menu.color.withOpacity(0.8),
                  menu.color,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  menu.icon,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  menu.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 跳转到任务列表页面
  void _navigateToTaskList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TaskListPage(),
      ),
    );
  }

  /// 开单权限配置 - 打开 Flutter 页面
  void _openBillingPermissionConfig(BuildContext context, String featureName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BillingConfigPage(),
      ),
    );
  }

  /// 跳转到体检合并页面
  void _openPhysicalMerge(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhysicalMergePage(),
      ),
    );
  }

  void _openUploadScreening(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UploadScreeningPage(),
      ),
    );
  }

  void _openArchivesMerge(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MergeArchivesPage(),
      ),
    );
  }

  void _handleMenuTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        _navigateToTaskList(context);
        break;
      case 1:
        _openBillingPermissionConfig(context, '开单权限配置');
        break;
      case 2:
        _openPhysicalMerge(context);
        break;
      case 3:
        _openUploadScreening(context);
        break;
      case 4:
        _openArchivesMerge(context);
        break;
    }
  }
}

/// 首页菜单展示数据。
class MenuItemData {
  final IconData icon;
  final String label;
  final Color color;

  const MenuItemData({
    required this.icon,
    required this.label,
    required this.color,
  });
}

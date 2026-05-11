import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 开单权限配置页面
/// 
/// 功能：公卫与基卫开单申请管理平台
/// - 公卫开单：配置开单机构信息及开单项目
/// - 基卫开单：配置开单机构信息及目标基卫系统机构映射
class BillingConfigPage extends StatefulWidget {
  const BillingConfigPage({super.key});

  @override
  State<BillingConfigPage> createState() => _BillingConfigPageState();
}

class _BillingConfigPageState extends State<BillingConfigPage>
    with SingleTickerProviderStateMixin {
  // Tab 控制器
  late TabController _tabController;

  // 当前选中 Tab 索引：0=公卫开单, 1=基卫开单
  int _currentIndex = 0;

  // 提交状态
  bool _isSubmitting = false;

  // ========== 公卫开单表单 ==========
  final _publicFormKey = GlobalKey<FormState>();
  final _publicInsNameController = TextEditingController();
  final _publicInsIdController = TextEditingController();
  final _publicTargetInsIdController = TextEditingController();

  // 公卫开单项目列表
  final List<Map<String, String>> _publicProjects = [
    {'name': '血常规', 'value': 'BLOOD_ROUTINE'},
    {'name': '生化', 'value': 'BIOCHEMISTRY'},
    {'name': '尿常规', 'value': 'ROUTINE_URINE'},
    {'name': '血糖', 'value': 'BIOCHEMISTRY_BLOOD_SUGAR'},
    {'name': '糖化血红蛋白', 'value': 'GLYCOSTLATED_HEMOGLOBIN'},
    {'name': '超声', 'value': 'ULTRASONIC'},
    {'name': '心电', 'value': 'ELECTROCARDIOGRAM'},
    {'name': 'DR', 'value': 'DIGITAL_RADIOGRAPHY'},
  ];

  // 选中的公卫开单项目
  final Set<String> _selectedPublicProjects = {};

  // ========== 基卫开单表单 ==========
  final _basicFormKey = GlobalKey<FormState>();
  final _basicInsNameController = TextEditingController();
  final _basicInsIdController = TextEditingController();
  final _basicMappingInsIdController = TextEditingController();

  // API 基础地址
  static const String _apiBaseUrl =
      'http://billing.2woniu.cn/billingsystem/billing/authority/open';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _publicInsNameController.dispose();
    _publicInsIdController.dispose();
    _publicTargetInsIdController.dispose();
    _basicInsNameController.dispose();
    _basicInsIdController.dispose();
    _basicMappingInsIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Tab 切换栏
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: _currentIndex == 0
                            ? const Color(0xFF1976D2)
                            : const Color(0xFF42A5F5),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_hospital,
                                size: 20,
                                color: _currentIndex == 0
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              const Text('公卫开单'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medical_services,
                                size: 20,
                                color: _currentIndex == 1
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              const Text('基卫开单'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 表单内容区域
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPublicForm(),
                      _buildBasicForm(),
                    ],
                  ),
                ),

                // 底部版权信息
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.white,
                  child: const Center(
                    child: Text(
                      '© 2023 医疗机构开单系统 - 版权所有',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFloatingBackButton(),
        ],
      ),
    );
  }

  Widget _buildFloatingBackButton() {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      child: Material(
        color: Colors.white.withOpacity(0.92),
        elevation: 2,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: '返回上一页',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
    );
  }

  // ========== 公卫开单表单 ==========
  Widget _buildPublicForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _publicFormKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.local_hospital,
                    color: const Color(0xFF1976D2),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '公卫开单信息',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 开单机构名称 + 开单机构ID
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _publicInsNameController,
                      label: '开单机构名称',
                      hint: '请输入开单机构名称',
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入开单机构名称';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _publicInsIdController,
                      label: '开单机构ID',
                      hint: '请输入开单机构ID',
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入开单机构ID';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 目标机构ID
              _buildTextField(
                controller: _publicTargetInsIdController,
                label: '目标机构ID',
                hint: '跨机构才填',
                isRequired: false,
              ),
              const SizedBox(height: 24),

              // 开单项目
              _buildSectionTitle('开单项目', isRequired: true),
              const SizedBox(height: 12),
              _buildPublicProjectCheckboxes(),
              if (_selectedPublicProjects.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '请至少选择一个开单项目',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitPublicForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? '提交中...' : '提交公卫开单申请',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 基卫开单表单 ==========
  Widget _buildBasicForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _basicFormKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.medical_services,
                    color: const Color(0xFF42A5F5),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '基卫开单信息',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 开单机构名称 + 开单机构ID
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _basicInsNameController,
                      label: '开单机构名称',
                      hint: '请输入开单机构名称',
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入开单机构名称';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _basicInsIdController,
                      label: '开单机构ID',
                      hint: '请输入开单机构ID',
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入开单机构ID';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 目标基卫系统机构ID
              _buildTextField(
                controller: _basicMappingInsIdController,
                label: '目标基卫系统机构ID',
                hint: '请输入目标基卫系统机构ID',
                isRequired: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入目标基卫系统机构ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitBasicForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FACFE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? '提交中...' : '提交基卫开单申请',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建文本输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  // 构建章节标题
  Widget _buildSectionTitle(String title, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  // 构建公卫开单项目复选框
  Widget _buildPublicProjectCheckboxes() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _publicProjects.map((project) {
        final isSelected = _selectedPublicProjects.contains(project['value']);
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedPublicProjects.remove(project['value']);
              } else {
                _selectedPublicProjects.add(project['value']!);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: (MediaQuery.of(context).size.width - 80) / 3,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? const Color(0xFFE3F2FD)
                  : Colors.grey[50],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedPublicProjects.add(project['value']!);
                        } else {
                          _selectedPublicProjects.remove(project['value']);
                        }
                      });
                    },
                    activeColor: const Color(0xFF2196F3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project['name']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? const Color(0xFF1976D2) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 提交公卫开单表单
  Future<void> _submitPublicForm() async {
    // 验证表单
    if (!(_publicFormKey.currentState?.validate() ?? false)) {
      return;
    }

    // 验证开单项目
    if (_selectedPublicProjects.isEmpty) {
      _showErrorDialog('请至少选择一个开单项目');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // 构建请求数据
    final requestData = {
      'type': 1,
      'data': [
        {
          'insId': _publicInsIdController.text.trim(),
          'insName': _publicInsNameController.text.trim(),
          'project': _selectedPublicProjects.toList(),
        },
      ],
    };

    try {
      final response = await _postJson(_apiBaseUrl, requestData);

      final status = response['status'];
      if (status != 0) {
        final msg = response['msg'] ?? '提交失败';
        _showErrorDialog(msg);
        return;
      }

      // 显示成功消息
      final data = response['data']?.toString() ?? '提交成功';
      _showSuccessDialog(data);

      // 重置表单
      _resetPublicForm();
    } catch (error) {
      final message = error is Exception
          ? error.toString()
          : '提交过程中出现错误，请检查网络连接后重试';
      _showErrorDialog(message);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // 提交基卫开单表单
  Future<void> _submitBasicForm() async {
    // 验证表单
    if (!(_basicFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // 构建请求数据
    final requestData = {
      'type': 2,
      'data': [
        {
          'insId': _basicInsIdController.text.trim(),
          'insName': _basicInsNameController.text.trim(),
          'mappingInsId': _basicMappingInsIdController.text.trim(),
        },
      ],
    };

    try {
      final response = await _postJson(_apiBaseUrl, requestData);

      final status = response['status'];
      if (status != 0) {
        final msg = response['msg'] ?? '提交失败';
        _showErrorDialog(msg);
        return;
      }

      // 显示成功消息
      final data = response['data']?.toString() ?? '提交成功';
      _showSuccessDialog(data);

      // 重置表单
      _resetBasicForm();
    } catch (error) {
      final message = error is Exception
          ? error.toString()
          : '提交过程中出现错误，请检查网络连接后重试';
      _showErrorDialog(message);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // 发送 POST 请求
  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('请求失败，状态码 ${response.statusCode}');
    }

    final body = response.body;
    if (body.isEmpty) {
      return {};
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }

  // 重置公卫开单表单
  void _resetPublicForm() {
    _publicInsNameController.clear();
    _publicInsIdController.clear();
    _publicTargetInsIdController.clear();
    setState(() {
      _selectedPublicProjects.clear();
    });
  }

  // 重置基卫开单表单
  void _resetBasicForm() {
    _basicInsNameController.clear();
    _basicInsIdController.clear();
    _basicMappingInsIdController.clear();
  }

  // 显示成功对话框
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 32,
                color: Colors.green[500],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '提交成功',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 32,
                color: Colors.red[500],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '提交失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

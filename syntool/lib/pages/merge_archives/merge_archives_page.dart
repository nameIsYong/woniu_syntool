import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'controllers/archives_merge_controller.dart';
import 'models/archives_merge_auth_state.dart';
import 'models/archives_merge_item.dart';
import 'models/archives_search_result.dart';
import 'services/archives_merge_auth_service.dart';
import 'services/archives_save_service.dart';
import 'services/archives_search_service.dart';
import 'widgets/archives_conflict_card.dart';
import 'widgets/archives_merge_auth_bar.dart';
import 'widgets/archives_merge_login_dialog.dart';
import 'widgets/archives_search_dialog.dart';

/// 档案合并页面
class MergeArchivesPage extends StatefulWidget {
  const MergeArchivesPage({super.key});

  @override
  State<MergeArchivesPage> createState() => _MergeArchivesPageState();
}

class _MergeArchivesPageState extends State<MergeArchivesPage> {
  final ArchivesMergeAuthService _authService = const ArchivesMergeAuthService();
  final ArchivesMergeController _mergeController =
      const ArchivesMergeController();
  final ArchivesSearchService _searchService = const ArchivesSearchService();
  final ArchivesSaveService _saveService = const ArchivesSaveService();

  // 认证状态
  ArchivesMergeAuthState _authState = const ArchivesMergeAuthState.signedOut();
  bool _isAuthLoading = false;

  // 选中的档案
  ArchivesSearchItem? _selectedArchiveA;
  ArchivesSearchItem? _selectedArchiveB;
  ArchivesDetail? _detailA;
  ArchivesDetail? _detailB;

  // 主辅关系：true=A为主，false=B为主，null=未选择
  bool? _isAMain;

  // 合并项列表
  List<MergeItem> _mergeItems = [];

  // 当前筛选类型
  FilterType _currentFilter = FilterType.all;

  // 加载状态
  bool _isLoading = false;
  bool _isSaving = false;

  // 提示浮层
  OverlayEntry? _messageOverlay;
  Timer? _messageTimer;

  // 主档案保存提示（仅提示一次）
  bool _hasShownMergeTargetTip = false;

  bool get _isLoggedIn => _authState.isLoggedIn;

  @override
  void dispose() {
    _hideMessageOverlay();
    _authState = const ArchivesMergeAuthState.signedOut();
    super.dispose();
  }

  // ==================== 登录相关 ====================

  Future<void> _openLoginDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArchivesMergeLoginDialog(onSubmit: _login),
    );
  }

  Future<void> _login(String account, String password) async {
    setState(() => _isAuthLoading = true);
    try {
      final authState = await _authService.login(
        account: account,
        password: password,
      );
      if (!mounted) return;
      setState(() => _authState = authState);
      _showSnackBar('登录成功：${authState.institutionName}');
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  void _logout() {
    setState(() {
      _authState = const ArchivesMergeAuthState.signedOut();
      _resetMergeState();
    });
    _showSnackBar('已退出登录');
  }

  void _resetMergeState() {
    _selectedArchiveA = null;
    _selectedArchiveB = null;
    _detailA = null;
    _detailB = null;
    _isAMain = null;
    _mergeItems = [];
    _currentFilter = FilterType.all;
    _hasShownMergeTargetTip = false;
  }

  // ==================== 搜索档案 ====================

  Future<void> _openSearchDialog(bool isArchiveA) async {
    if (!_isLoggedIn) {
      _showSnackBar('请先登录');
      return;
    }

    final result = await showDialog<ArchivesSearchItem>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArchivesSearchDialog(
        title: isArchiveA ? '搜索选择档案A' : '搜索选择档案B',
        token: _authState.token,
        onSearch: _searchService.searchArchives,
        excludeItem: isArchiveA ? null : _selectedArchiveA,
      ),
    );

    if (result == null || !mounted) return;

    // 校验不能选同一个
    if (isArchiveA && _selectedArchiveB?.id == result.id) {
      _showSnackBar('档案A和档案B不能为同一条数据');
      return;
    }
    if (!isArchiveA && _selectedArchiveA?.id == result.id) {
      _showSnackBar('档案A和档案B不能为同一条数据');
      return;
    }

    setState(() {
      if (isArchiveA) {
        _selectedArchiveA = result;
      } else {
        _selectedArchiveB = result;
      }
    });

    // 如果两个都选好了，查询详情
    if (_selectedArchiveA != null && _selectedArchiveB != null) {
      await _loadArchivesDetails();
    }
  }

  Future<void> _loadArchivesDetails() async {
    if (_selectedArchiveA == null || _selectedArchiveB == null) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _searchService.fetchArchivesDetail(
          token: _authState.token,
          residentHealthRecordId: _selectedArchiveA!.id,
        ),
        _searchService.fetchArchivesDetail(
          token: _authState.token,
          residentHealthRecordId: _selectedArchiveB!.id,
        ),
      ]);

      _detailA = results[0];
      _detailB = results[1];
      _isAMain = null;
      _mergeItems = [];
      _currentFilter = FilterType.all;
      _hasShownMergeTargetTip = false;

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('档案详情加载完成，请选择主档案');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('加载档案详情失败: $e');
      }
    }
  }

  // ==================== 主辅选择 ====================

  void _selectMainData(bool isAMain) {
    setState(() {
      _isAMain = isAMain;
      _buildMergeItems();
    });
    _showMainDataTip();
  }

  void _showMainDataTip() {
    if (_hasShownMergeTargetTip) return;
    _hasShownMergeTargetTip = true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('点击页面底部【保存】按钮时，会将另一份档案合并到该主档案上'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  // ==================== 合并逻辑 ====================

  void _buildMergeItems() {
    if (_isAMain == null || _detailA == null || _detailB == null) return;

    final mainDetail = _isAMain! ? _detailA! : _detailB!;
    final auxDetail = _isAMain! ? _detailB! : _detailA!;
    _mergeItems = _mergeController.buildMergeItems(
      mainModel: mainDetail.model,
      auxiliaryModel: auxDetail.model,
    );
  }

  // ==================== 筛选与统计 ====================

  List<MergeItem> get _filteredItems {
    switch (_currentFilter) {
      case FilterType.conflict:
        return _mergeItems.where((i) => i.type == MergeItemType.conflict).toList();
      case FilterType.auxiliary:
        return _mergeItems.where((i) => i.type == MergeItemType.auxiliaryOnly).toList();
      case FilterType.main:
        return _mergeItems.where(
          (i) => i.type == MergeItemType.mainOnly || i.type == MergeItemType.equal,
        ).toList();
      default:
        return _mergeItems.where((i) => i.type != MergeItemType.bothEmpty).toList();
    }
  }

  int get _unresolvedConflictCount {
    return _mergeItems.where((i) => i.type == MergeItemType.conflict && !i.isResolved).length;
  }

  int _completedFieldCount(ArchivesDetail? detail) {
    if (detail == null) return 0;
    return _mergeController.calculateCompletedFieldCount(detail.model);
  }

  String? _recommendationText() {
    if (_detailA == null || _detailB == null) return null;
    final countA = _completedFieldCount(_detailA);
    final countB = _completedFieldCount(_detailB);
    if (countA == countB) {
      return '当前两份档案已完善数据条数相同，建议结合业务判断主档案。';
    }
    final preferred = countA > countB ? 'A' : 'B';
    return '当前建议选择档案$preferred为主，完善字段更多。';
  }

  // ==================== 保存 ====================

  Future<void> _save() async {
    if (!_isLoggedIn) {
      _showSnackBar('请先登录');
      return;
    }
    if (_isSaving) return;
    if (_unresolvedConflictCount > 0) {
      _showSnackBar('还有 $_unresolvedConflictCount 个冲突未解决');
      return;
    }
    if (_isAMain == null) {
      _showSnackBar('请先选择主档案');
      return;
    }

    final mainDetail = _isAMain! ? _detailA : _detailB;
    if (mainDetail == null) {
      _showSnackBar('档案详情未加载');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 构造合并后的字段值
      final mergeValues = <String, dynamic>{};
      for (final item in _mergeItems) {
        if (item.type == MergeItemType.bothEmpty) continue;
        if (item.isAuxiliaryDisabled) continue;

        final val = item.finalValue;
        if (val != null) {
          mergeValues[item.fieldPath] = val;
        }
      }

      // 获取服务包ID
      final spkgId = await _authService.fetchServicePackageId(token: _authState.token);

      // 构建保存参数
      var payload = _saveService.buildSavePayload(
        baseModel: mainDetail.model,
        mergeValues: mergeValues,
        spkgId: spkgId,
      );

      // 补全 personBaseExtendsInfo 前，先获取当前登录账号绑定的云平台账号信息。
      final doctor = await _authService.fetchThirdAccountInfo(
        token: _authState.token,
      );

      final extendedInfo = _saveService.complementPersonBaseExtendsInfo(
        baseExtendsInfo: mainDetail.model.personBaseExtendsInfo,
        mergedFamilyInfo: payload['familyInfo'] as Map<String, dynamic>?,
        doctor: doctor,
      );
      payload['personBaseExtendsInfo'] = extendedInfo;

      // 打印 JSON（暂不真实提交）
      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      debugPrint('========== 档案合并保存参数 ==========');
      debugPrint(jsonString);
      debugPrint('=====================================');

      _showSnackBar('保存参数已打印到控制台，请检查');
    } catch (e) {
      _showSnackBar('保存失败: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== 提示消息 ====================

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.hideCurrentSnackBar();

    _messageTimer?.cancel();
    _messageOverlay?.remove();

    final style = _resolveMessageStyle(message);
    _messageOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 22,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: false,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: style.borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: style.shadowColor,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: style.iconBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(style.icon, color: style.iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: style.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _hideMessageOverlay,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              color: style.textColor.withOpacity(0.75),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_messageOverlay!);
    _messageTimer = Timer(const Duration(seconds: 4), _hideMessageOverlay);
  }

  _MessageStyle _resolveMessageStyle(String message) {
    if (message.contains('成功')) {
      return const _MessageStyle(
        icon: Icons.check_circle_rounded,
        backgroundColor: Color(0xFFE8F7EE),
        borderColor: Color(0xFF8FD0A6),
        iconBackgroundColor: Color(0xFFCAEED7),
        iconColor: Color(0xFF1E8E4A),
        textColor: Color(0xFF145A32),
        shadowColor: Color(0x1F1E8E4A),
      );
    }
    if (message.contains('失败') || message.contains('错误') || message.contains('未') || message.contains('缺少')) {
      return const _MessageStyle(
        icon: Icons.error_rounded,
        backgroundColor: Color(0xFFFFEFEA),
        borderColor: Color(0xFFF2A38B),
        iconBackgroundColor: Color(0xFFFAD1C4),
        iconColor: Color(0xFFD44F21),
        textColor: Color(0xFF7A2E12),
        shadowColor: Color(0x24D44F21),
      );
    }
    return const _MessageStyle(
      icon: Icons.info_rounded,
      backgroundColor: Color(0xFFEAF3FF),
      borderColor: Color(0xFF94BDF2),
      iconBackgroundColor: Color(0xFFD5E7FF),
      iconColor: Color(0xFF1E6FD9),
      textColor: Color(0xFF184A8C),
      shadowColor: Color(0x1F1E6FD9),
    );
  }

  void _hideMessageOverlay() {
    _messageTimer?.cancel();
    _messageTimer = null;
    _messageOverlay?.remove();
    _messageOverlay = null;
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_isLoggedIn &&
                    (_selectedArchiveA != null || _selectedArchiveB != null))
                  _buildTopControlBar(),
                Expanded(child: _buildBodyContent()),
                if (_isLoggedIn && _mergeItems.isNotEmpty) _buildBottomSaveBar(),
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

  Widget _buildLoginRequiredPlaceholder() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: Colors.orange[700]),
            const SizedBox(height: 12),
            const Text(
              '请先登录后再操作档案合并功能',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '登录成功后才可搜索档案列表、选择主辅数据和保存合并结果。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isAuthLoading ? null : _openLoginDialog,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('立即登录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (!_isLoggedIn) {
      return _buildLoginRequiredPlaceholder();
    }
    if (_mergeItems.isEmpty) {
      return Center(
        child: Text(
          _selectedArchiveA == null && _selectedArchiveB == null
              ? '请先搜索选择档案A和档案B'
              : '请选择主档案以查看合并结果',
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
      );
    }
    return _buildMergeList();
  }

  // ==================== 搜索栏 ====================

  Widget _buildSearchBar() {
    final isEnabled = _isLoggedIn && !_isLoading && !_isAuthLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(68, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          ArchivesMergeAuthBar(
            isLoggedIn: _isLoggedIn,
            institutionName: _authState.institutionName,
            isBusy: _isLoading || _isAuthLoading,
            onLogin: _openLoginDialog,
            onLogout: _logout,
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: isEnabled ? () => _openSearchDialog(true) : null,
            icon: const Icon(Icons.person_search, size: 18),
            label: Text(_selectedArchiveA == null ? '搜索档案A' : '重新选择A'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          if (_selectedArchiveA != null)
            _buildSelectedChip(
              label: 'A',
              name: _selectedArchiveA!.name,
              idCard: _selectedArchiveA!.idCard,
            ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isEnabled ? () => _openSearchDialog(false) : null,
            icon: const Icon(Icons.person_search, size: 18),
            label: Text(_selectedArchiveB == null ? '搜索档案B' : '重新选择B'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          if (_selectedArchiveB != null)
            _buildSelectedChip(
              label: 'B',
              name: _selectedArchiveB!.name,
              idCard: _selectedArchiveB!.idCard,
            ),
          if (_isLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedChip({
    required String label,
    required String name,
    required String idCard,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '档案$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
            ),
          ),
          Text(
            '$name | $idCard',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
          ),
        ],
      ),
    );
  }

  // ==================== 顶部控制栏 ====================

  Widget _buildTopControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (_detailA != null && _detailB != null) ...[
              if (_recommendationText() != null) ...[
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC7DCF6)),
                    ),
                    child: Text(
                      _recommendationText()!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF285E96),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              Tooltip(
                message: '主档案选择说明',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showMainDataSelectionHelp,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FB),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFC7DCF6)),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildMainDataChip(
                label: 'A',
                name: _selectedArchiveA?.name ?? '',
                completedFieldCount: _completedFieldCount(_detailA),
                isSelected: _isAMain == true,
                onTap: () => _selectMainData(true),
              ),
              const SizedBox(width: 8),
              _buildMainDataChip(
                label: 'B',
                name: _selectedArchiveB?.name ?? '',
                completedFieldCount: _completedFieldCount(_detailB),
                isSelected: _isAMain == false,
                onTap: () => _selectMainData(false),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 26, color: Colors.grey[300]),
              const SizedBox(width: 12),
            ],
            if (_mergeItems.isNotEmpty) ...[
              _buildFilterBar(),
              if (_unresolvedConflictCount > 0) ...[
                const SizedBox(width: 8),
                _buildConflictWarning(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showMainDataSelectionHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主档案选择说明'),
        content: const Text(
          '若选择【档案A】，则会以【档案A】为主，会把【档案B】的数据合过来。反之，若选择【档案B】，则会以【档案B】为主，会把【档案A】的数据合过来。建议选择数据量较多、信息更全的档案作为主档案。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDataChip({
    required String label,
    required String name,
    required int completedFieldCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.blue[50],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : Colors.blue[100]!,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.grey,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              '档案$label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : Colors.blue[100],
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '已完善 $completedFieldCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      (FilterType.all, '全部', _mergeItems.where((i) => i.type != MergeItemType.bothEmpty).length),
      (FilterType.conflict, '冲突', _mergeItems.where((i) => i.type == MergeItemType.conflict).length),
      (FilterType.auxiliary, '新增', _mergeItems.where((i) => i.type == MergeItemType.auxiliaryOnly).length),
      (FilterType.main, '主数据', _mergeItems.where(
        (i) => i.type == MergeItemType.mainOnly || i.type == MergeItemType.equal,
      ).length),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _currentFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('${filter.$2} ${filter.$3}'),
              selected: isSelected,
              onSelected: (_) => setState(() => _currentFilter = filter.$1),
              selectedColor: const Color(0xFF1976D2),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConflictWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 14),
          const SizedBox(width: 4),
          Text(
            '$_unresolvedConflictCount 个冲突待解决',
            style: TextStyle(
              color: Colors.red[700],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 合并列表 ====================

  Widget _buildMergeList() {
    final items = _filteredItems;
    FieldModule? currentModule;

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final showHeader = currentModule != item.module;
        currentModule = item.module;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) _buildModuleHeader(item.module),
            ArchivesConflictCard(
              item: item,
              onDecisionChanged: (decision) {
                setState(() {
                  item.decision = decision;
                });
              },
              onToggleAuxiliary: () {
                setState(() {
                  item.isAuxiliaryCancelled = !item.isAuxiliaryCancelled;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildModuleHeader(FieldModule module) {
    final String title;
    switch (module) {
      case FieldModule.familyInfo:
        title = '家庭信息';
        break;
      case FieldModule.personBaseInfo:
        title = '居民基本信息';
        break;
      case FieldModule.livingEnvironment:
        title = '生活环境';
        break;
      case FieldModule.personHistoryList:
        title = '既往史';
        break;
      case FieldModule.personFamilyHistoryList:
        title = '家族史';
        break;
      case FieldModule.personIllnessList:
        title = '遗传疾病史及残疾情况';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 底部保存栏 ====================

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '共${_mergeItems.where((i) => i.type != MergeItemType.bothEmpty).length}项 | '
            '冲突:${_mergeItems.where((i) => i.type == MergeItemType.conflict).length}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _resetMergeState();
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重置', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(
              _isSaving ? '保存中...' : '保存',
              style: const TextStyle(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color textColor;
  final Color shadowColor;

  const _MessageStyle({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.shadowColor,
  });
}

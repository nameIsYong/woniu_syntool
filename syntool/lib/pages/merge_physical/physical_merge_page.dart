import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/physical_merge_auth_state.dart';
import 'models/physical_duplicate_exam_models.dart';
import 'models/physical_smart_merge_models.dart';
import 'services/physical_merge_auth_service.dart';
import 'services/physical_duplicate_exam_service.dart';
import 'widgets/physical_merge_auth_bar.dart';
import 'services/physical_duplicate_exam_filter_dialog.dart';
import 'widgets/physical_merge_login_dialog.dart';
import 'widgets/physical_smart_merge_strategy_dialog.dart';

/// 体检数据节点
class PhysicalNode {
  final int csvId;
  final int parentId;
  final dynamic value;
  final String csvName;

  PhysicalNode({
    required this.csvId,
    required this.parentId,
    required this.value,
    required this.csvName,
  });

  factory PhysicalNode.fromJson(Map<String, dynamic> json) {
    return PhysicalNode(
      csvId: json['csvId'] ?? 0,
      parentId: json['parentId'] ?? 0,
      value: json['value'],
      csvName: json['csvName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'csvId': csvId,
      'parentId': parentId,
      'value': value,
      'csvName': csvName,
    };
  }

  /// 唯一标识：parentId + csvId
  String get uniqueKey => '$parentId-$csvId';

  /// 是否为空值
  bool get isEmpty {
    if (value == null) return true;
    if (value == '') return true;
    if (value is List && (value as List).isEmpty) return true;
    return false;
  }

  /// 是否有效（非空）
  bool get isValid => !isEmpty;
}

/// 体检项信息（用于存储csvName和子选项映射）
class _CsvItemInfo {
  final String csvName;
  final Map<dynamic, String> childsMap; // 枚举值ID映射，key可能是int或String

  _CsvItemInfo({required this.csvName, required this.childsMap});

  /// 是否为枚举类型（有子选项）
  bool get isEnum => childsMap.isNotEmpty;
}

/// 合并项类型
enum MergeItemType {
  bothEmpty, // 两边都不存在
  mainOnly, // 仅主数据存在
  auxiliaryOnly, // 仅辅数据存在
  equal, // 两边相等
  conflict, // 两边冲突
}

/// 合并项决策状态
enum MergeDecision {
  none, // 未决策
  keepMain, // 保留主数据
  keepAuxiliary, // 保留辅数据
  autoKept, // 自动保留
}

/// 筛选类型
enum FilterType {
  all, // 全部
  conflict, // 冲突
  auxiliary, // 新增（辅数据独有）
  main, // 主数据（主独有+相等）
}

/// 合并项
class MergeItem {
  final String uniqueKey;
  final int csvId;
  final int parentId;
  final String csvName;
  final PhysicalNode? mainNode;
  final PhysicalNode? auxiliaryNode;
  MergeDecision decision;
  bool isAuxiliaryCancelled;

  MergeItem({
    required this.uniqueKey,
    required this.csvId,
    required this.parentId,
    required this.csvName,
    this.mainNode,
    this.auxiliaryNode,
    this.decision = MergeDecision.none,
    this.isAuxiliaryCancelled = false,
  });

  /// 合并项类型
  MergeItemType get type {
    final mainValid = mainNode?.isValid ?? false;
    final auxValid = auxiliaryNode?.isValid ?? false;

    if (!mainValid && !auxValid) return MergeItemType.bothEmpty;
    if (mainValid && !auxValid) return MergeItemType.mainOnly;
    if (!mainValid && auxValid) return MergeItemType.auxiliaryOnly;
    if (_valuesEqual(mainNode!.value, auxiliaryNode!.value)) {
      return MergeItemType.equal;
    }
    return MergeItemType.conflict;
  }

  /// 是否需要用户决策
  bool get needUserDecision => type == MergeItemType.conflict;

  /// 是否已解决
  bool get isResolved {
    if (!needUserDecision) return true;
    return decision != MergeDecision.none;
  }

  /// 新增项是否处于“取消新增”状态。
  /// 仅辅数据独有项允许进入该状态，保存时需要排除。
  bool get isAuxiliaryDisabled =>
      type == MergeItemType.auxiliaryOnly && isAuxiliaryCancelled;

  /// 获取最终值
  dynamic get finalValue {
    if (isAuxiliaryDisabled) {
      return null;
    }

    switch (decision) {
      case MergeDecision.keepMain:
      case MergeDecision.autoKept:
        return mainNode?.value;
      case MergeDecision.keepAuxiliary:
        return auxiliaryNode?.value;
      default:
        return null;
    }
  }

  /// 值相等判断（弱类型相等、数组无序相等）
  static bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    if (a is List && b is List) {
      if (a.length != b.length) return false;
      final aSet = a.map((e) => e.toString()).toSet();
      final bSet = b.map((e) => e.toString()).toSet();
      return aSet.containsAll(bSet) && bSet.containsAll(aSet);
    }

    return a.toString() == b.toString();
  }
}

/// 体检列表项（搜索弹框用）
class PhysicalExamItem {
  final String id;
  final String name;
  final String idCard;
  final DateTime examDate;
  final String? updateTime; // 更新时间

  PhysicalExamItem({
    required this.id,
    required this.name,
    required this.idCard,
    required this.examDate,
    this.updateTime,
  });
}

/// 体检详情。
/// 除了体检项数据外，还保留保存接口所需的上下文字段。
class PhysicalExamDetail {
  final String residentHealthRecordId;
  final String insId;
  final int nodeId;
  final int csvId;
  final List<PhysicalNode> serviceData;

  const PhysicalExamDetail({
    required this.residentHealthRecordId,
    required this.insId,
    required this.nodeId,
    required this.csvId,
    required this.serviceData,
  });
}

class _SmartMergeExamBundle {
  final int originalIndex;
  final DuplicateExamRecord record;
  final PhysicalExamDetail detail;
  final DateTime? examDate;
  final int nonEmptyCount;

  const _SmartMergeExamBundle({
    required this.originalIndex,
    required this.record,
    required this.detail,
    required this.examDate,
    required this.nonEmptyCount,
  });
}

/// 页面顶部消息浮层样式
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

/// 体检合并页面
class PhysicalMergePage extends StatefulWidget {
  const PhysicalMergePage({super.key});

  @override
  State<PhysicalMergePage> createState() => _PhysicalMergePageState();
}

class _PhysicalMergePageState extends State<PhysicalMergePage> {
  final PhysicalMergeAuthService _authService =
      const PhysicalMergeAuthService();
  final PhysicalDuplicateExamService _duplicateExamService =
      const PhysicalDuplicateExamService();

  // 日期范围
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _duplicateListStartDate;
  late DateTime _duplicateListEndDate;
  final TextEditingController _idCardController = TextEditingController();
  String _duplicateSearchKeyword = '';
  PhysicalMergeAuthState _authState = const PhysicalMergeAuthState.signedOut();
  List<DuplicateExamGroup> _duplicateExamGroups = const [];
  String? _activeDuplicateGroupIdCard;
  bool _hasHandledCurrentDuplicateBatch = false;
  SmartMergeProgress _smartMergeProgress = const SmartMergeProgress.idle();

  // 原始数据
  List<PhysicalNode> _sourceA = [];
  List<PhysicalNode> _sourceB = [];
  PhysicalExamDetail? _detailA;
  PhysicalExamDetail? _detailB;

  // 合并项列表
  List<MergeItem> _mergeItems = [];

  // 当前筛选类型
  FilterType _currentFilter = FilterType.all;

  // 选中的体检信息
  PhysicalExamItem? _selectedExamA;
  PhysicalExamItem? _selectedExamB;

  // 主数据选择：true=A为主，false=B为主，null=未选择
  bool? _isAMain;

  // 体检项信息映射表（parentId-csvId -> {csvName, childsMap}）
  // childsMap: 子选项ID -> 子选项名称（用于枚举值显示）
  Map<String, _CsvItemInfo> _csvItemInfoMap = {};
  OverlayEntry? _messageOverlay;
  Timer? _messageTimer;

  // 体检项名字对应表（parentId-csvId -> name）
  Map<String, String> _csvNameMap = {};

  // 加载状态
  bool _isLoading = false;
  bool _isAuthLoading = false;
  bool _isSaving = false;
  bool _isOpeningDuplicateDialog = false;
  bool _isSmartMerging = false;

  // 仅在当前页面生命周期内提示一次主数据保存说明，不做持久化。
  bool _hasShownMergeTargetTip = false;

  // 树状结构加载完成的 Future
  late Future<void> _treeStructureLoaded;

  // SharedPreferences 键名
  static const String _prefStartDate = 'physical_merge_start_date';
  static const String _prefEndDate = 'physical_merge_end_date';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, 1, 1);
    _endDate = DateTime(today.year, today.month, today.day);
    _duplicateListStartDate = _startDate;
    _duplicateListEndDate = _endDate;
    _loadSavedDates();
    _treeStructureLoaded = _loadTreeStructure();
  }

  /// 加载保存的日期范围
  Future<void> _loadSavedDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startDateStr = prefs.getString(_prefStartDate);
      final endDateStr = prefs.getString(_prefEndDate);

      if (startDateStr != null) {
        _startDate = DateTime.parse(startDateStr);
      }
      if (endDateStr != null) {
        _endDate = DateTime.parse(endDateStr);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('加载保存的日期失败: $e');
    }
  }

  /// 保存日期范围
  Future<void> _saveDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefStartDate, _startDate.toIso8601String());
      await prefs.setString(_prefEndDate, _endDate.toIso8601String());
    } catch (e) {
      debugPrint('保存日期失败: $e');
    }
  }

  @override
  void dispose() {
    _hideMessageOverlay();
    _authState = const PhysicalMergeAuthState.signedOut();
    _resetMergeState();
    _idCardController.dispose();
    super.dispose();
  }

  /// 加载树状结构（用于选项值映射）
  Future<void> _loadTreeStructure() async {
    try {
      // 加载体检项枚举值映射（csvId -> 枚举值列表）
      final enumJsonString = await rootBundle.loadString(
        'assets/data/physical_item_enum_value.json',
      );
      final Map<String, dynamic> enumJsonMap = json.decode(enumJsonString);
      _buildCsvItemInfoMap(enumJsonMap);
      debugPrint('体检项枚举值映射加载完成，共 ${_csvItemInfoMap.length} 项');

      // 加载体检项名字对应表（parentId-csvId -> name）
      final nameMapJsonString = await rootBundle.loadString(
        'assets/data/csv_name_mapping.json',
      );
      final List<dynamic> nameMapJsonList = json.decode(nameMapJsonString);
      _buildCsvNameMap(nameMapJsonList);
      debugPrint('体检项名字对应表加载完成，共 ${_csvNameMap.length} 项');
    } catch (e, stackTrace) {
      debugPrint('加载树状结构失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  /// 构建体检项名字映射表（parentId-csvId -> name）
  void _buildCsvNameMap(List<dynamic> items) {
    debugPrint('开始构建名字映射表，共 ${items.length} 条数据');
    for (final item in items) {
      final csvId = item['csvId'] as int?;
      final parentId = item['parentId'] as int?;
      final name = item['name'] as String?;
      if (csvId != null && parentId != null && name != null) {
        _csvNameMap['$parentId-$csvId'] = name;
      }
    }
    debugPrint('名字映射表构建完成，共 ${_csvNameMap.length} 条');
    // 打印前5个作为示例
    var count = 0;
    _csvNameMap.forEach((key, value) {
      if (count < 5) {
        debugPrint('  示例: csvId=$key -> name=$value');
        count++;
      }
    });
  }

  /// 构建体检项信息映射表
  /// physical_item_enum_value.json 格式: {"csvId": [{"label": "...", "value": "..."}, ...]}
  void _buildCsvItemInfoMap(Map<String, dynamic> enumData) {
    enumData.forEach((csvIdStr, enumList) {
      final csvId = int.tryParse(csvIdStr);
      if (csvId == null || enumList is! List) return;

      // 构建子选项映射表（用于枚举值显示）
      final childsMap = <dynamic, String>{};
      for (final enumItem in enumList) {
        if (enumItem is! Map) continue;

        final label = enumItem['label'] as String?;
        final value = enumItem['value']; // 可能是 String 或 int

        if (label != null && value != null) {
          // value 可能是 "400201" 或 "-" 或 "+" 等
          final valueKey = value is int ? value : value.toString();
          childsMap[valueKey] = label;
        }
      }

      // 使用 csvId 作为 key（因为 API 返回的数据中，value 对应的是 csvId）
      _csvItemInfoMap[csvIdStr] = _CsvItemInfo(
        csvName: '', // 名称从 _csvNameMap 获取
        childsMap: childsMap,
      );
    });
  }

  /// 获取选项值显示名称
  /// 根据 csvId 从 _csvItemInfoMap 中获取枚举值映射
  String _getOptionDisplayName(dynamic value, int parentId, int csvId) {
    if (value == null) return '';

    // 从 physical_item_enum_value.json 加载的映射，key 是 csvId 字符串
    final key = csvId.toString();
    final itemInfo = _csvItemInfoMap[key];

    // 如果是枚举类型（有childs），需要转换值为名称
    if (itemInfo != null && itemInfo.isEnum) {
      if (value is List) {
        if (value.isEmpty) return '';
        final names = value.map((id) {
          // 支持 int 和 String 类型的 key（如 400201 或 "-"）
          // 先尝试原始类型，再尝试字符串形式
          return itemInfo.childsMap[id] ??
              itemInfo.childsMap[id.toString()] ??
              id.toString();
        }).toList();
        return names.join(', ');
      }
      // 支持 int 和 String 类型的 key
      return itemInfo.childsMap[value] ??
          itemInfo.childsMap[value.toString()] ??
          value.toString();
    }

    // 非枚举类型，直接显示值
    if (value is List) {
      if (value.isEmpty) return '';
      return value.join(', ');
    }
    return value.toString();
  }

  List<String> _extractImageUrls(dynamic value) {
    if (value == null) {
      return const [];
    }

    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where(_isImageUrl)
          .toList();
    }

    final raw = value.toString().trim();
    if (_isImageUrl(raw)) {
      return [raw];
    }

    return const [];
  }

  bool _isImageUrl(String value) {
    if (value.isEmpty) {
      return false;
    }

    final normalized = value.toLowerCase();
    if (!(normalized.startsWith('http://') ||
        normalized.startsWith('https://'))) {
      return false;
    }

    return normalized.contains('.png') ||
        normalized.contains('.jpg') ||
        normalized.contains('.jpeg') ||
        normalized.contains('.gif') ||
        normalized.contains('.webp') ||
        normalized.contains('.bmp') ||
        normalized.contains('.heic');
  }

  void _showImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(
                  maxWidth: 960,
                  maxHeight: 720,
                ),
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '图片加载失败\n$imageUrl',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueContent(
    dynamic rawValue, {
    required int parentId,
    required int csvId,
    TextAlign textAlign = TextAlign.left,
    bool compact = false,
  }) {
    final imageUrls = _extractImageUrls(rawValue);
    if (imageUrls.isEmpty) {
      return SelectableText(
        _getOptionDisplayName(rawValue, parentId, csvId),
        style: TextStyle(fontSize: compact ? 13 : 14, color: Colors.grey[800]),
        textAlign: textAlign,
      );
    }

    return Column(
      crossAxisAlignment: textAlign == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: imageUrls.map((url) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _showImagePreview(url),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: compact ? 52 : 60,
                    height: compact ? 52 : 60,
                    color: Colors.grey[200],
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey[600],
                        size: compact ? 22 : 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: compact ? 220 : 280,
                child: SelectableText(
                  url,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 获取体检项名称
  /// 严格通过 parentId + csvId 组合从 csv_name_mapping.json 获取。
  /// 禁止仅使用 csvId 查询，避免命中错误体检项名称。
  String _getCsvName(int parentId, int csvId) {
    final key = '$parentId-$csvId';
    if (_csvNameMap.containsKey(key)) {
      return _csvNameMap[key]!;
    }
    return '$parentId-$csvId';
  }

  bool get _isLoggedIn => _authState.isLoggedIn;

  Future<void> _openLoginDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PhysicalMergeLoginDialog(onSubmit: _login),
    );
  }

  Future<void> _login(String account, String password) async {
    setState(() {
      _isAuthLoading = true;
    });

    try {
      final authState = await _authService.login(
        account: account,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _authState = authState;
      });
      _showSnackBar('登录成功：${authState.institutionName}');
      await _openDuplicateExamFilterDialog();
    } finally {
      if (mounted) {
        setState(() {
          _isAuthLoading = false;
        });
      }
    }
  }

  void _logout({bool clearMessage = true}) {
    if (!mounted) {
      _authState = const PhysicalMergeAuthState.signedOut();
      _duplicateExamGroups = const [];
      _activeDuplicateGroupIdCard = null;
      _smartMergeProgress = const SmartMergeProgress.idle();
      _resetMergeState();
      return;
    }

    setState(() {
      _authState = const PhysicalMergeAuthState.signedOut();
      _duplicateExamGroups = const [];
      _activeDuplicateGroupIdCard = null;
      _smartMergeProgress = const SmartMergeProgress.idle();
      _resetMergeState();
    });

    if (clearMessage) {
      _showSnackBar('已退出登录');
    }
  }

  void _resetMergeState() {
    _sourceA = [];
    _sourceB = [];
    _detailA = null;
    _detailB = null;
    _mergeItems = [];
    _selectedExamA = null;
    _selectedExamB = null;
    _isAMain = null;
    _currentFilter = FilterType.all;
  }

  Future<void> _openDuplicateExamFilterDialog() async {
    if (!_isLoggedIn ||
        _isOpeningDuplicateDialog ||
        _isSmartMerging ||
        !mounted) {
      return;
    }

    _isOpeningDuplicateDialog = true;
    try {
      final result = await showDialog<DuplicateExamFilterResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PhysicalDuplicateExamFilterDialog(
          token: _authState.token,
          initialStartDate: _startDate,
          initialEndDate: _endDate,
          initialKeyword: _duplicateSearchKeyword,
          service: _duplicateExamService,
        ),
      );

      if (!mounted || result == null) {
        return;
      }

      setState(() {
        _duplicateExamGroups = result.groups;
        _activeDuplicateGroupIdCard = null;
        _startDate = result.startDate;
        _endDate = result.endDate;
        _duplicateListStartDate = result.startDate;
        _duplicateListEndDate = result.endDate;
        _duplicateSearchKeyword = result.keyword;
        _hasHandledCurrentDuplicateBatch = false;
        _smartMergeProgress = const SmartMergeProgress.idle();
      });
      _saveDates();

      _showSnackBar('已载入 ${result.groups.length} 组重复体检档案');
    } finally {
      _isOpeningDuplicateDialog = false;
    }
  }

  /// 搜索体检列表
  Future<void> _searchPhysicalExams() async {
    if (!_isLoggedIn) {
      _showSnackBar('请先登录');
      return;
    }
    if (_idCardController.text.isEmpty) {
      _showSnackBar('请输入身份证号');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
        'http://bmg.2woniu.cn/bmanage/publichealth/service/record/1/list?'
        'unRegionCode=0'
        '&peStart=${DateFormat('yyyy-MM-dd').format(_startDate)}'
        '&peEnd=${DateFormat('yyyy-MM-dd').format(_endDate)}'
        '&keyword=${Uri.encodeComponent(_idCardController.text)}'
        '&pageNo=1'
        '&pageSize=20'
        '&qmsStatus='
        '&nodeId=1'
        '&isUpload=2',
      );

      final response = await http.get(
        uri,
        headers: {'token': _authState.token, 'Accept': '*/*'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == 0) {
          final data = jsonData['data'];
          final results = data['results'] as List<dynamic>;

          if (results.isEmpty) {
            setState(() => _isLoading = false);
            _showErrorDialog('未找到体检记录');
            return;
          }

          final examList = results.map((item) {
            // 解析体检日期（格式：2026-04-10 00:00:00）
            final timeNodeStr = item['timeNode'] as String?;
            final dataId = item['id'] as int?;
            print("体检日期：$timeNodeStr,体检ID：$dataId");
            DateTime examDate;
            try {
              examDate = DateTime.parse(timeNodeStr ?? '');
            } catch (e) {
              examDate = DateTime.now();
            }

            final rhr = item['rhr'] as Map<String, dynamic>?;

            return PhysicalExamItem(
              id: item['id'].toString(),
              name: rhr?['name'] ?? '未知',
              idCard: rhr?['idCard'] ?? '',
              examDate: examDate,
              updateTime: item['updated'] as String?, // 添加更新时间字段
            );
          }).toList();

          setState(() => _isLoading = false);
          _showExamSelectionDialog(examList);
        } else {
          setState(() => _isLoading = false);
          _showErrorDialog('查询失败：${jsonData['status']}');
        }
      } else {
        setState(() => _isLoading = false);
        _showErrorDialog('请求失败：HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('查询失败：$e');
    }
  }

  /// 从左侧重复档案列表发起处理。
  /// 当前批次首次点击时，需要先将该批次筛选日期覆盖到顶部搜索条件中。
  Future<void> _handleDuplicateExamGroup(DuplicateExamGroup group) async {
    if (_isAuthLoading || _isLoading || _isSmartMerging) {
      return;
    }

    final bool shouldApplyDuplicateBatchDates =
        !_hasHandledCurrentDuplicateBatch;

    setState(() {
      // 左侧列表只保留唯一的“当前处理中”项，避免和“已完成”语义混淆。
      _activeDuplicateGroupIdCard = group.idCard;
      _idCardController.text = group.idCard;
      if (shouldApplyDuplicateBatchDates) {
        _startDate = _duplicateListStartDate;
        _endDate = _duplicateListEndDate;
        _hasHandledCurrentDuplicateBatch = true;
      }
    });

    if (shouldApplyDuplicateBatchDates) {
      await _saveDates();
    }

    if (!mounted) {
      return;
    }

    FocusScope.of(context).unfocus();
    await _searchPhysicalExams();
  }

  DuplicateExamGroup? _findActiveDuplicateGroup() {
    final activeIdCard = _activeDuplicateGroupIdCard;
    if (activeIdCard == null) {
      return null;
    }

    for (final group in _duplicateExamGroups) {
      if (group.idCard == activeIdCard) {
        return group;
      }
    }

    return null;
  }

  /// 显示错误弹框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('查询失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示体检选择弹框
  void _showExamSelectionDialog(List<PhysicalExamItem> exams) {
    final Set<String> tempSelected = {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('选择两份体检数据进行合并'),
            content: SizedBox(
              width: 500,
              height: 300,
              child: Column(
                children: [
                  Text(
                    '已选择: ${tempSelected.length}/2',
                    style: TextStyle(
                      color: tempSelected.length == 2
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: exams.length,
                      itemBuilder: (context, index) {
                        final exam = exams[index];
                        final isSelected = tempSelected.contains(exam.id);
                        return CheckboxListTile(
                          title: Text(
                            '${exam.name} | 体检日期：${DateFormat('yyyy-MM-dd').format(exam.examDate)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('身份证: ${exam.idCard}'),
                              Text(
                                '更新时间: ${exam.updateTime ?? '-'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          value: isSelected,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                if (tempSelected.length < 2) {
                                  tempSelected.add(exam.id);
                                }
                              } else {
                                tempSelected.remove(exam.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tempSelected.length != 2) {
                    _showSnackBar('必须选择2个体检');
                    return;
                  }
                  Navigator.of(context).pop();
                  final selectedIds = tempSelected.toList();
                  _selectedExamA = exams.firstWhere(
                    (e) => e.id == selectedIds[0],
                  );
                  _selectedExamB = exams.firstWhere(
                    (e) => e.id == selectedIds[1],
                  );
                  _loadExamDetails();
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 加载体检详情
  Future<void> _loadExamDetails() async {
    if (!_isLoggedIn) {
      _showSnackBar('请先登录');
      return;
    }
    setState(() => _isLoading = true);

    try {
      // 确保树状结构已加载完成
      await _treeStructureLoaded;

      // 并行查询两个体检的详情
      final results = await Future.wait([
        _fetchExamDetail(_selectedExamA!.id),
        _fetchExamDetail(_selectedExamB!.id),
      ]);

      _detailA = results[0];
      _detailB = results[1];
      _sourceA = results[0].serviceData;
      _sourceB = results[1].serviceData;

      _isAMain = null;
      _mergeItems = [];
      _currentFilter = FilterType.all;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('查询体检详情失败: $e');
    }
  }

  /// 查询单个体检详情
  Future<PhysicalExamDetail> _fetchExamDetail(String nodeId) async {
    final uri = Uri.parse(
      'http://wnjk.2woniu.cn/wnjkapp/followup/phy/detail?'
      'nodeId=$nodeId'
      '&csvId=1',
    );

    final response = await http.get(
      uri,
      headers: {'token': _authState.token, 'Accept': '*/*'},
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final jsonData = json.decode(response.body);

    if (jsonData['status'] != 0) {
      throw Exception(jsonData['msg'] ?? '未知错误');
    }

    final data = jsonData['data'];
    final yptData = data['yptData'];
    final serviceData = yptData['serviceData'] as List<dynamic>?;

    final nodes = (serviceData ?? const []).map((item) {
      final csvId = item['csvId'] as int? ?? 0;
      final parentId = item['parentId'] as int? ?? 0;
      final value = item['value'];

      // 从树状结构映射表中查找名称
      final csvName = _getCsvName(parentId, csvId);

      return PhysicalNode(
        csvId: csvId,
        parentId: parentId,
        value: value,
        csvName: csvName,
      );
    }).toList();

    return PhysicalExamDetail(
      residentHealthRecordId: yptData['rhrId']?.toString() ?? '',
      insId: yptData['insId']?.toString() ?? '',
      nodeId: int.tryParse(yptData['nodeId']?.toString() ?? '') ?? 0,
      csvId: int.tryParse(yptData['csvId']?.toString() ?? '') ?? 1,
      serviceData: nodes,
    );
  }

  /// 选择主数据
  void _selectMainData(bool isAMain) {
    setState(() {
      _isAMain = isAMain;
      _buildMergeItems();
    });
    _showMainDataTip(isAMain);
  }

  void _showMainDataTip(bool isAMain) {
    if (_hasShownMergeTargetTip) {
      return;
    }

    final selectedExam = isAMain ? _selectedExamA : _selectedExamB;
    if (selectedExam == null) {
      return;
    }

    _hasShownMergeTargetTip = true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text('点击页面底部【保存】按钮时，会将另一条体检合并到该体检上'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  /// 显示主数据选择说明。
  /// 该说明入口固定放在体检A左侧，便于用户随时确认 A/B 的主从关系。
  void _showMainDataSelectionHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主数据选择说明'),
        content: const Text(
          '若选择【体检A】，则会以【体检A】为主，会把【体检B】的数据合过来。反之，若选择【体检B】，则会以【体检B】为主，会把【体检A】的数据合过来。建议选择数据量较多、信息更全的体检作为主数据。',
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

  /// 构建合并项列表
  void _buildMergeItems() {
    final mainSource = _isAMain! ? _sourceA : _sourceB;
    final auxSource = _isAMain! ? _sourceB : _sourceA;

    final Map<String, PhysicalNode> mainMap = {
      for (final node in mainSource) node.uniqueKey: node,
    };
    final Map<String, PhysicalNode> auxMap = {
      for (final node in auxSource) node.uniqueKey: node,
    };

    final allKeys = {...mainMap.keys, ...auxMap.keys};

    _mergeItems = allKeys.map((key) {
      final mainNode = mainMap[key];
      final auxNode = auxMap[key];
      final csvName = mainNode?.csvName ?? auxNode?.csvName ?? '';
      final csvId = mainNode?.csvId ?? auxNode?.csvId ?? 0;
      final parentId = mainNode?.parentId ?? auxNode?.parentId ?? 0;

      final item = MergeItem(
        uniqueKey: key,
        csvId: csvId,
        parentId: parentId,
        csvName: csvName,
        mainNode: mainNode,
        auxiliaryNode: auxNode,
      );

      // 自动设置决策状态
      switch (item.type) {
        case MergeItemType.mainOnly:
        case MergeItemType.equal:
          item.decision = MergeDecision.autoKept;
          break;
        case MergeItemType.auxiliaryOnly:
          item.decision = MergeDecision.keepAuxiliary;
          break;
        default:
          item.decision = MergeDecision.none;
      }

      return item;
    }).toList();

    _sortMergeItems();
  }

  /// 排序合并项：冲突(未解决) > 冲突(已解决) > 辅独有 > 主独有/相等
  void _sortMergeItems() {
    _mergeItems.sort((a, b) {
      final orderA = _getSortOrder(a);
      final orderB = _getSortOrder(b);
      return orderA.compareTo(orderB);
    });
  }

  /// 获取排序权重
  int _getSortOrder(MergeItem item) {
    switch (item.type) {
      case MergeItemType.conflict:
        // 未解决的冲突排前面
        return item.isResolved ? 1 : 0;
      case MergeItemType.auxiliaryOnly:
        return 2;
      case MergeItemType.mainOnly:
      case MergeItemType.equal:
        return 3;
      default:
        return 4;
    }
  }

  /// 获取筛选后的列表
  List<MergeItem> get _filteredItems {
    switch (_currentFilter) {
      case FilterType.conflict:
        return _mergeItems
            .where((i) => i.type == MergeItemType.conflict)
            .toList();
      case FilterType.auxiliary:
        return _mergeItems
            .where((i) => i.type == MergeItemType.auxiliaryOnly)
            .toList();
      case FilterType.main:
        return _mergeItems
            .where(
              (i) =>
                  i.type == MergeItemType.mainOnly ||
                  i.type == MergeItemType.equal,
            )
            .toList();
      default:
        return _mergeItems
            .where((i) => i.type != MergeItemType.bothEmpty)
            .toList();
    }
  }

  /// 获取未解决冲突数量
  int get _unresolvedConflictCount {
    return _mergeItems
        .where((i) => i.type == MergeItemType.conflict && !i.isResolved)
        .length;
  }

  /// 保存
  Future<void> _save() async {
    if (!_isLoggedIn) {
      _showSnackBar('请先登录');
      return;
    }
    if (_isSaving) {
      return;
    }
    if (_unresolvedConflictCount > 0) {
      _showSnackBar('还有 $_unresolvedConflictCount 个冲突未解决');
      return;
    }
    if (_isAMain == null) {
      _showSnackBar('请先选择主数据');
      return;
    }

    final mainDetail = _isAMain == true ? _detailA : _detailB;
    if (mainDetail == null) {
      _showSnackBar('体检详情未加载，请重新选择两份体检');
      return;
    }
    if (mainDetail.residentHealthRecordId.isEmpty ||
        mainDetail.insId.isEmpty ||
        mainDetail.nodeId == 0) {
      _showSnackBar('主数据体检详情缺少保存所需参数');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final servicePackageId = await _authService.fetchServicePackageId(
        token: _authState.token,
      );

      // 已取消新增的辅数据独有项不参与本次保存。
      final result = _mergeItems
          .where(
            (item) =>
                item.type != MergeItemType.bothEmpty &&
                !item.isAuxiliaryDisabled,
          )
          .map(
            (item) => PhysicalNode(
              csvId: item.csvId,
              parentId: item.parentId,
              value: item.finalValue,
              csvName: item.csvName,
            ),
          )
          .toList();

      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(result.map((e) => e.toJson()).toList());

      //mode:0:未传 1:远程服务 2:面对面 4:团队任务协作形式 
      //8:众包任务形式 16:同步基卫数据 32:终端查询机 
      //40:LIS上传 41:助手上传 42:开单 43：便携设备 。
      final savePayload = {
        'data': result.map((e) => e.toJson()).toList(),
        'residentHealthRecordId': mainDetail.residentHealthRecordId,
        'insId': mainDetail.insId,
        'nodeId': mainDetail.nodeId,
        'spkgId': servicePackageId,
        'csvId': 1,
        // 'mode':
      };
      final payloadString = const JsonEncoder.withIndent(
        '  ',
      ).convert(savePayload);

      debugPrint('========== 服务包信息 ==========');
      debugPrint('servicePackageId: $servicePackageId');
      debugPrint('==============================');
      debugPrint('========== 合并结果 ==========');
      debugPrint(jsonString);
      debugPrint('==============================');
      debugPrint('========== 保存参数 ==========');
      debugPrint(payloadString);
      debugPrint('==============================');

      await _authService.savePhysicalRecord(
        token: _authState.token,
        payload: savePayload,
      );

      if (mounted) {
        setState(() {
          // 保存成功后清空当前合并上下文，方便继续处理下一位用户。
          _resetMergeState();
        });
      }
      _showSnackBar('保存成功');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  int get _duplicateDateRangeDays {
    final normalizedStart = DateTime(
      _duplicateListStartDate.year,
      _duplicateListStartDate.month,
      _duplicateListStartDate.day,
    );
    final normalizedEnd = DateTime(
      _duplicateListEndDate.year,
      _duplicateListEndDate.month,
      _duplicateListEndDate.day,
    );
    return normalizedEnd.difference(normalizedStart).inDays + 1;
  }

  Future<void> _openSmartMergeStrategyDialog() async {
    if (!_isLoggedIn) {
      _showSnackBar('请先登录');
      return;
    }
    if (_isLoading || _isAuthLoading || _isSaving || _isSmartMerging) {
      return;
    }
    if (_duplicateExamGroups.isEmpty) {
      _showSnackBar('当前没有可智能合并的重复体检数据');
      return;
    }
    if (_duplicateDateRangeDays > 180) {
      _showSnackBar('当前筛选日期跨度超过180天，禁止使用智能合并，请先缩小筛选范围');
      return;
    }

    final strategy = await showDialog<SmartMergeStrategy>(
      context: context,
      builder: (context) => const PhysicalSmartMergeStrategyDialog(),
    );

    if (!mounted || strategy == null) {
      return;
    }

    await _runSmartMerge(strategy);
  }

  Future<void> _runSmartMerge(SmartMergeStrategy strategy) async {
    if (_isSmartMerging) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSmartMerging = true;
      _activeDuplicateGroupIdCard = null;
      _resetMergeState();
      _smartMergeProgress = SmartMergeProgress(
        isRunning: true,
        isCompleted: false,
        totalCount: _duplicateExamGroups.length,
        processedCount: 0,
        currentName: '',
        currentIdCard: '',
        currentStep: '准备开始',
        strategy: strategy,
        results: const [],
      );
    });

    int? cachedServicePackageId;

    for (final group in _duplicateExamGroups) {
      if (!mounted) {
        return;
      }

      _updateSmartMergeCurrentPerson(
        group: group,
        step: '准备处理',
      );

      final result = await _processSmartMergeGroup(
        group,
        strategy,
        () async {
          cachedServicePackageId ??= await _authService.fetchServicePackageId(
            token: _authState.token,
          );
          return cachedServicePackageId!;
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final nextResults = List<SmartMergePersonResult>.from(
          _smartMergeProgress.results,
        )..add(result);
        _smartMergeProgress = _smartMergeProgress.copyWith(
          processedCount: nextResults.length,
          currentName: group.displayName,
          currentIdCard: group.idCard,
          currentStep: _statusText(result.status),
          results: nextResults,
        );
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSmartMerging = false;
      _activeDuplicateGroupIdCard = null;
      _smartMergeProgress = _smartMergeProgress.copyWith(
        isRunning: false,
        isCompleted: true,
        currentName: '',
        currentIdCard: '',
        currentStep: '处理完成',
      );
    });

    _showSnackBar(
      '智能合并完成：成功${_smartMergeProgress.successCount}，部分成功${_smartMergeProgress.partialSuccessCount}，失败${_smartMergeProgress.failureCount}，跳过${_smartMergeProgress.skippedCount}',
    );
    _showSmartMergeSummaryDialog();
  }

  void _updateSmartMergeCurrentPerson({
    required DuplicateExamGroup group,
    required String step,
  }) {
    setState(() {
      _activeDuplicateGroupIdCard = group.idCard;
      _idCardController.text = group.idCard;
      _smartMergeProgress = _smartMergeProgress.copyWith(
        currentName: group.displayName,
        currentIdCard: group.idCard,
        currentStep: step,
      );
    });
  }

  Future<SmartMergePersonResult> _processSmartMergeGroup(
    DuplicateExamGroup group,
    SmartMergeStrategy strategy,
    Future<int> Function() getServicePackageId,
  ) async {
    if (group.duplicateCount > 3) {
      return SmartMergePersonResult(
        name: group.displayName,
        idCard: group.idCard,
        duplicateCount: group.duplicateCount,
        status: SmartMergePersonStatus.skipped,
        step: '风控校验',
        message: '重复体检数量大于3，存在误合并风险，已跳过',
      );
    }

    try {
      _updateSmartMergeCurrentPerson(group: group, step: '查询体检详情');
      final bundles = await _loadSmartMergeBundles(group);

      _updateSmartMergeCurrentPerson(group: group, step: '自动判定主辅数据');
      final mainBundle = _selectSmartMergeMainBundle(bundles);
      final auxiliaryBundles = bundles
          .where((bundle) => bundle != mainBundle)
          .toList()
        ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex));

      _updateSmartMergeCurrentPerson(group: group, step: '自动生成合并结果');
      // 重复体检大于 2 条时，按“1 条主数据 + 其余辅数据顺序并入”的方式累积合并。
      var mergedNodes = List<PhysicalNode>.from(mainBundle.detail.serviceData);
      for (final bundle in auxiliaryBundles) {
        mergedNodes = _mergePhysicalNodes(
          mainSource: mergedNodes,
          auxiliarySource: bundle.detail.serviceData,
        );
      }

      _updateSmartMergeCurrentPerson(group: group, step: '保存合并结果');
      await _saveMergedPhysicalRecord(
        mainDetail: mainBundle.detail,
        mergedNodes: mergedNodes,
        servicePackageId: await getServicePackageId(),
      );

      final deleteFailures = <String>[];
      if (strategy.autoDeleteAuxiliary && auxiliaryBundles.isNotEmpty) {
        _updateSmartMergeCurrentPerson(group: group, step: '删除辅数据');
        for (final bundle in auxiliaryBundles) {
          final deleteResult = await _authService.deletePhysicalRecord(
            token: _authState.token,
            recordId: bundle.record.recordId,
          );
          if (!deleteResult.success) {
            deleteFailures.add(
              '${bundle.record.recordId}：${deleteResult.message}',
            );
          }
        }
      }

      if (deleteFailures.isNotEmpty) {
        return SmartMergePersonResult(
          name: group.displayName,
          idCard: group.idCard,
          duplicateCount: group.duplicateCount,
          status: SmartMergePersonStatus.partialSuccess,
          step: '删除辅数据',
          message: '合并保存成功，但有辅数据删除失败',
          deleteFailureMessages: deleteFailures,
        );
      }

      return SmartMergePersonResult(
        name: group.displayName,
        idCard: group.idCard,
        duplicateCount: group.duplicateCount,
        status: SmartMergePersonStatus.success,
        step: '保存合并结果',
        message: strategy.autoDeleteAuxiliary ? '合并并删除辅数据成功' : '合并保存成功',
      );
    } catch (e) {
      return SmartMergePersonResult(
        name: group.displayName,
        idCard: group.idCard,
        duplicateCount: group.duplicateCount,
        status: SmartMergePersonStatus.failed,
        step: _smartMergeProgress.currentStep,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<List<_SmartMergeExamBundle>> _loadSmartMergeBundles(
    DuplicateExamGroup group,
  ) async {
    await _treeStructureLoaded;
    final bundles = <_SmartMergeExamBundle>[];

    for (var i = 0; i < group.records.length; i++) {
      final record = group.records[i];
      final detail = await _fetchExamDetail(record.recordId);
      bundles.add(
        _SmartMergeExamBundle(
          originalIndex: i,
          record: record,
          detail: detail,
          examDate: _extractSmartMergeExamDate(detail),
          nonEmptyCount: _countNonEmptyNodes(detail.serviceData),
        ),
      );
    }

    return bundles;
  }

  _SmartMergeExamBundle _selectSmartMergeMainBundle(
    List<_SmartMergeExamBundle> bundles,
  ) {
    final sorted = List<_SmartMergeExamBundle>.from(bundles)
      ..sort((a, b) {
        // 自动判主优先级：
        // 1. 非空节点数量更多
        // 2. 体检日期更新（仅比较年月日）
        // 3. 原始顺序更靠前
        final countCompare = b.nonEmptyCount.compareTo(a.nonEmptyCount);
        if (countCompare != 0) {
          return countCompare;
        }

        final examDateCompare = _compareSmartMergeExamDate(
          a.examDate,
          b.examDate,
        );
        if (examDateCompare != 0) {
          return examDateCompare;
        }

        return a.originalIndex.compareTo(b.originalIndex);
      });

    return sorted.first;
  }

  int _compareSmartMergeExamDate(DateTime? a, DateTime? b) {
    if (a != null && b == null) {
      return -1;
    }
    if (a == null && b != null) {
      return 1;
    }
    if (a == null && b == null) {
      return 0;
    }

    final normalizedA = DateTime(a!.year, a.month, a.day);
    final normalizedB = DateTime(b!.year, b.month, b.day);
    return normalizedB.compareTo(normalizedA);
  }

  int _countNonEmptyNodes(List<PhysicalNode> nodes) {
    return nodes.where((node) => node.isValid).length;
  }

  DateTime? _extractSmartMergeExamDate(PhysicalExamDetail detail) {
    for (final node in detail.serviceData) {
      if (node.parentId == 200261 && node.csvId == 300702) {
        final value = node.value?.toString().trim() ?? '';
        return _parseSmartMergeExamDate(value);
      }
    }
    return null;
  }

  DateTime? _parseSmartMergeExamDate(String rawValue) {
    if (rawValue.isEmpty) {
      return null;
    }

    final normalized = rawValue.trim();
    final patterns = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd',
    ];
    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern).parseStrict(normalized);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        // 兼容两种格式即可，解析失败继续尝试下一个格式。
      }
    }
    return null;
  }

  List<PhysicalNode> _mergePhysicalNodes({
    required List<PhysicalNode> mainSource,
    required List<PhysicalNode> auxiliarySource,
  }) {
    final mainMap = {for (final node in mainSource) node.uniqueKey: node};
    final auxiliaryMap = {
      for (final node in auxiliarySource) node.uniqueKey: node,
    };
    final allKeys = {...mainMap.keys, ...auxiliaryMap.keys};
    final mergedItems = <MergeItem>[];

    for (final key in allKeys) {
      final mainNode = mainMap[key];
      final auxiliaryNode = auxiliaryMap[key];
      final item = MergeItem(
        uniqueKey: key,
        csvId: mainNode?.csvId ?? auxiliaryNode?.csvId ?? 0,
        parentId: mainNode?.parentId ?? auxiliaryNode?.parentId ?? 0,
        csvName: mainNode?.csvName ?? auxiliaryNode?.csvName ?? '',
        mainNode: mainNode,
        auxiliaryNode: auxiliaryNode,
      );

      switch (item.type) {
        case MergeItemType.mainOnly:
        case MergeItemType.equal:
        case MergeItemType.conflict:
          item.decision = MergeDecision.keepMain;
          break;
        case MergeItemType.auxiliaryOnly:
          item.decision = MergeDecision.keepAuxiliary;
          break;
        case MergeItemType.bothEmpty:
          item.decision = MergeDecision.none;
          break;
      }
      mergedItems.add(item);
    }

    return mergedItems
        .where(
          (item) =>
              item.type != MergeItemType.bothEmpty && item.finalValue != null,
        )
        .map(
          (item) => PhysicalNode(
            csvId: item.csvId,
            parentId: item.parentId,
            value: item.finalValue,
            csvName: item.csvName,
          ),
        )
        .toList();
  }

  Future<void> _saveMergedPhysicalRecord({
    required PhysicalExamDetail mainDetail,
    required List<PhysicalNode> mergedNodes,
    required int servicePackageId,
  }) async {
    if (mainDetail.residentHealthRecordId.isEmpty ||
        mainDetail.insId.isEmpty ||
        mainDetail.nodeId == 0) {
      throw Exception('主数据体检详情缺少保存所需参数');
    }

    final savePayload = {
      'data': mergedNodes.map((e) => e.toJson()).toList(),
      'residentHealthRecordId': mainDetail.residentHealthRecordId,
      'insId': mainDetail.insId,
      'nodeId': mainDetail.nodeId,
      'spkgId': servicePackageId,
      'csvId': 1,
    };

    await _authService.savePhysicalRecord(
      token: _authState.token,
      payload: savePayload,
    );
  }

  String _statusText(SmartMergePersonStatus status) {
    switch (status) {
      case SmartMergePersonStatus.success:
        return '成功';
      case SmartMergePersonStatus.partialSuccess:
        return '部分成功';
      case SmartMergePersonStatus.failed:
        return '失败';
      case SmartMergePersonStatus.skipped:
        return '已跳过';
    }
  }

  SmartMergePersonResult? _findSmartMergeResult(String idCard) {
    for (final result in _smartMergeProgress.results) {
      if (result.idCard == idCard) {
        return result;
      }
    }
    return null;
  }

  void _showSmartMergeSummaryDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final results = _smartMergeProgress.results;
        return AlertDialog(
          title: const Text('智能合并结果'),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSummaryTag('总人数', '${_smartMergeProgress.totalCount}'),
                    _buildSummaryTag('成功', '${_smartMergeProgress.successCount}'),
                    _buildSummaryTag(
                      '部分成功',
                      '${_smartMergeProgress.partialSuccessCount}',
                    ),
                    _buildSummaryTag('失败', '${_smartMergeProgress.failureCount}'),
                    _buildSummaryTag('跳过', '${_smartMergeProgress.skippedCount}'),
                    _buildSummaryTag(
                      '删除失败',
                      '${_smartMergeProgress.deleteFailureCount}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 360,
                  child: results.isEmpty
                      ? const Align(
                          alignment: Alignment.topLeft,
                          child: Text('本次没有处理数据'),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final item = results[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.name}  ${item.idCard}  ${_statusText(item.status)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '阶段：${item.step}；说明：${item.message}',
                                  style: const TextStyle(height: 1.45),
                                ),
                                if (item.deleteFailureMessages.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.deleteFailureMessages.join('\n'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB04A00),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E1EF)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C4D83),
        ),
      ),
    );
  }

  /// 显示提示
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                          child: Icon(
                            style.icon,
                            color: style.iconColor,
                            size: 20,
                          ),
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

    if (message.contains('失败') ||
        message.contains('错误') ||
        message.contains('未') ||
        message.contains('缺少')) {
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
                    (_sourceA.isNotEmpty ||
                        _sourceB.isNotEmpty ||
                        _mergeItems.isNotEmpty))
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
              '请先登录后再操作体检合并功能',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '登录成功后才可搜索体检列表、选择主辅数据和保存合并结果。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_isAuthLoading || _isSmartMerging)
                  ? null
                  : _openLoginDialog,
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

    return Row(
      children: [
        _buildDuplicateExamSidePanel(),
        Expanded(
          child: _mergeItems.isEmpty
              ? const Center(child: Text('请选择体检数据并指定主数据'))
              : _buildMergeList(),
        ),
      ],
    );
  }

  Widget _buildDuplicateExamSidePanel() {
    final bool canStartSmartMerge =
        _isLoggedIn &&
        !_isLoading &&
        !_isAuthLoading &&
        !_isSaving &&
        !_isSmartMerging &&
        _duplicateExamGroups.isNotEmpty;

    return Container(
      width: 420,
      margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '重复体检档案',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: (_isAuthLoading || _isSmartMerging)
                          ? null
                          : _openDuplicateExamFilterDialog,
                      icon: const Icon(Icons.filter_alt_outlined, size: 16),
                      label: const Text('重新筛选'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${_duplicateExamGroups.length} 组数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '筛选条件：${DateFormat('yyyy-MM-dd').format(_duplicateListStartDate)} 至 '
                  '${DateFormat('yyyy-MM-dd').format(_duplicateListEndDate)}'
                  '${_duplicateSearchKeyword.isEmpty ? '' : '，关键词：$_duplicateSearchKeyword'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '左侧仅按身份证去重展示，可直接点击“去处理”自动带入身份证并触发搜索。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _duplicateExamGroups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '当前没有重复身份证数据。\n登录后会自动弹出筛选框，也可以点击上方“重新筛选”。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _duplicateExamGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = _duplicateExamGroups[index];
                      return _buildDuplicateExamListItem(group, index + 1);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Column(
              children: [
                if (_smartMergeProgress.totalCount > 0) ...[
                  _buildSmartMergeProgressPanel(),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canStartSmartMerge
                        ? _openSmartMergeStrategyDialog
                        : null,
                    icon: _isSmartMerging
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(_isSmartMerging ? '智能合并进行中...' : '智能合并'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (_duplicateDateRangeDays > 180) ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前筛选跨度 $_duplicateDateRangeDays 天，超过180天，已禁止智能合并。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD44F21),
                      height: 1.4,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    '智能合并仅支持180天内的数据范围，且重复体检数量大于3的人员会自动跳过。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateExamListItem(DuplicateExamGroup group, int index) {
    final bool canHandle =
        _isLoggedIn &&
        !_isLoading &&
        !_isAuthLoading &&
        !_isSmartMerging;
    final bool isActive = _activeDuplicateGroupIdCard == group.idCard;
    final result = _findSmartMergeResult(group.idCard);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEAF4FF) : const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF1976D2) : const Color(0xFFDCE6F1),
          width: isActive ? 1.4 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1976D2)
                  : const Color(0xFFEAF2FB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.white : Colors.blue[700],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: SelectableText(
                    group.displayName,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: SelectableText(
                    group.idCard,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Text(
              '${group.duplicateCount}条',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red[700],
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            _buildListStatusTag(
              label: _isSmartMerging ? '智能处理中' : '当前处理',
              backgroundColor: const Color(0xFF1976D2),
              textColor: Colors.white,
            ),
          ] else if (result != null) ...[
            const SizedBox(width: 6),
            _buildListStatusTag(
              label: _statusText(result.status),
              backgroundColor: _statusColor(result.status),
              textColor: Colors.white,
            ),
          ],
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: canHandle
                ? () => _handleDuplicateExamGroup(group)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? const Color(0xFF0D47A1)
                  : const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(66, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(isActive ? '处理中' : '去处理'),
          ),
        ],
      ),
    );
  }

  Widget _buildListStatusTag({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.05,
        ),
      ),
    );
  }

  Color _statusColor(SmartMergePersonStatus status) {
    switch (status) {
      case SmartMergePersonStatus.success:
        return const Color(0xFF1E8E4A);
      case SmartMergePersonStatus.partialSuccess:
        return const Color(0xFFEF8F00);
      case SmartMergePersonStatus.failed:
        return const Color(0xFFD44F21);
      case SmartMergePersonStatus.skipped:
        return const Color(0xFF7B8794);
    }
  }

  Widget _buildSmartMergeProgressPanel() {
    final progress = _smartMergeProgress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E1EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '智能合并进度',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF174A7C),
                  ),
                ),
              ),
              if (progress.isCompleted && progress.results.isNotEmpty)
                TextButton(
                  onPressed: _showSmartMergeSummaryDialog,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('查看明细'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryTag('总数', '${progress.totalCount}'),
              _buildSummaryTag('已处理', '${progress.processedCount}'),
              _buildSummaryTag('成功', '${progress.successCount}'),
              _buildSummaryTag('部分成功', '${progress.partialSuccessCount}'),
              _buildSummaryTag('失败', '${progress.failureCount}'),
              _buildSummaryTag('跳过', '${progress.skippedCount}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            progress.isRunning
                ? '当前：${progress.currentName.isEmpty ? '-' : progress.currentName}  ${progress.currentIdCard}'
                : '状态：${progress.isCompleted ? '已完成' : '未开始'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '步骤：${progress.currentStep.isEmpty ? '-' : progress.currentStep}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          if (progress.strategy != null) ...[
            const SizedBox(height: 4),
            Text(
              '策略：${progress.strategy!.autoDeleteAuxiliary ? '保存后自动删除辅数据' : '仅自动合并保存'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    final isEnabled =
        _isLoggedIn &&
        !_isLoading &&
        !_isAuthLoading &&
        !_isSmartMerging;
    final DuplicateExamGroup? activeGroup = _findActiveDuplicateGroup();

    return Container(
      padding: const EdgeInsets.fromLTRB(68, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeGroup != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB6D6F6)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.playlist_add_check_circle_outlined,
                    size: 18,
                    color: Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前处理：${activeGroup.displayName}  ${activeGroup.idCard}  '
                      '重复 ${activeGroup.duplicateCount} 条',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF174A7C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              PhysicalMergeAuthBar(
                isLoggedIn: _isLoggedIn,
                institutionName: _authState.institutionName,
                isBusy: _isLoading || _isAuthLoading || _isSmartMerging,
                onLogin: _openLoginDialog,
                onLogout: _logout,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDatePicker(
                  label: '开始日期',
                  date: _startDate,
                  enabled: isEnabled,
                  onSelect: (date) {
                    setState(() => _startDate = date);
                    _saveDates();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePicker(
                  label: '结束日期',
                  date: _endDate,
                  enabled: isEnabled,
                  onSelect: (date) {
                    setState(() => _endDate = date);
                    _saveDates();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _idCardController,
                  enabled: isEnabled,
                  decoration: InputDecoration(
                    labelText: '身份证号',
                    hintText: '请输入身份证号',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isEnabled ? _searchPhysicalExams : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 18),
                label: const Text('搜索'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sourceA.isNotEmpty && _sourceB.isNotEmpty) ...[
              Tooltip(
                message: '主数据选择说明',
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
                date: DateFormat('MM-dd').format(_selectedExamA!.examDate),
                dataCount: _calculateMainDataCount(
                  mainSource: _sourceA,
                  auxiliarySource: _sourceB,
                ),
                isSelected: _isAMain == true,
                onTap: () => _selectMainData(true),
              ),
              const SizedBox(width: 8),
              _buildMainDataChip(
                label: 'B',
                date: DateFormat('MM-dd').format(_selectedExamB!.examDate),
                dataCount: _calculateMainDataCount(
                  mainSource: _sourceB,
                  auxiliarySource: _sourceA,
                ),
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

  /// 构建日期选择器
  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required bool enabled,
    required ValueChanged<DateTime> onSelect,
  }) {
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (selected != null) onSelect(selected);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          isDense: true,
          enabled: enabled,
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(date),
          style: TextStyle(
            color: enabled ? Colors.black87 : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 构建主数据选择芯片
  Widget _buildMainDataChip({
    required String label,
    required String date,
    required int dataCount,
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
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.grey,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              '体检$label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              date,
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
                '$dataCount 条',
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

  /// 统计当前体检作为主数据时的“主数据”条数。
  /// 口径与顶部筛选栏“主数据”按钮保持一致：
  /// 仅统计主数据独有项与主辅相等项，不包含冲突项和辅数据独有项。
  int _calculateMainDataCount({
    required List<PhysicalNode> mainSource,
    required List<PhysicalNode> auxiliarySource,
  }) {
    final Map<String, PhysicalNode> mainMap = {
      for (final node in mainSource) node.uniqueKey: node,
    };
    final Map<String, PhysicalNode> auxiliaryMap = {
      for (final node in auxiliarySource) node.uniqueKey: node,
    };

    final allKeys = {...mainMap.keys, ...auxiliaryMap.keys};
    var count = 0;

    for (final key in allKeys) {
      final item = MergeItem(
        uniqueKey: key,
        csvId: mainMap[key]?.csvId ?? auxiliaryMap[key]?.csvId ?? 0,
        parentId: mainMap[key]?.parentId ?? auxiliaryMap[key]?.parentId ?? 0,
        csvName: mainMap[key]?.csvName ?? auxiliaryMap[key]?.csvName ?? '',
        mainNode: mainMap[key],
        auxiliaryNode: auxiliaryMap[key],
      );

      if (item.type == MergeItemType.mainOnly ||
          item.type == MergeItemType.equal) {
        count++;
      }
    }

    return count;
  }

  /// 构建筛选栏
  Widget _buildFilterBar() {
    final filters = [
      (
        FilterType.all,
        '全部',
        _mergeItems.where((i) => i.type != MergeItemType.bothEmpty).length,
      ),
      (
        FilterType.conflict,
        '冲突',
        _mergeItems.where((i) => i.type == MergeItemType.conflict).length,
      ),
      (
        FilterType.auxiliary,
        '新增',
        _mergeItems.where((i) => i.type == MergeItemType.auxiliaryOnly).length,
      ),
      (
        FilterType.main,
        '主数据',
        _mergeItems
            .where(
              (i) =>
                  i.type == MergeItemType.mainOnly ||
                  i.type == MergeItemType.equal,
            )
            .length,
      ),
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

  /// 构建冲突警告
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

  /// 构建合并列表
  Widget _buildMergeList() {
    final items = _filteredItems;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCompactCard(items[index]),
    );
  }

  /// 构建紧凑卡片
  Widget _buildCompactCard(MergeItem item) {
    switch (item.type) {
      case MergeItemType.mainOnly:
      case MergeItemType.equal:
        return _buildMainCard(item);
      case MergeItemType.auxiliaryOnly:
        return _buildAuxiliaryCard(item);
      case MergeItemType.conflict:
        return _buildConflictCard(item);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 主数据卡片（白色）
  Widget _buildMainCard(MergeItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: SelectableText(
                item.csvName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: _buildValueContent(
                item.mainNode?.value,
                parentId: item.parentId,
                csvId: item.csvId,
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 辅数据卡片（绿色）
  Widget _buildAuxiliaryCard(MergeItem item) {
    final isCancelled = item.isAuxiliaryDisabled;
    final cardColor = isCancelled ? const Color(0xFFF8F8F8) : Colors.green[50]!;
    final borderColor = isCancelled
        ? const Color(0xFFE4E4E4)
        : Colors.green[300]!;
    final tagColor = isCancelled ? const Color(0xFFEEEEEE) : Colors.green[100]!;
    final tagTextColor = isCancelled
        ? const Color(0xFF9E9E9E)
        : Colors.green[800]!;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: isCancelled ? const Color(0xFFA8A8A8) : Colors.black87,
    );
    final actionColor = isCancelled ? Colors.blue[700]! : Colors.grey[700]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                isCancelled ? '已取消新增' : '新增',
                style: TextStyle(
                  fontSize: 10,
                  color: tagTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: SelectableText(item.csvName, style: titleStyle),
            ),
            Expanded(
              flex: 4,
              child: Opacity(
                opacity: isCancelled ? 0.38 : 1,
                child: _buildValueContent(
                  item.auxiliaryNode?.value,
                  parentId: item.parentId,
                  csvId: item.csvId,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                setState(() {
                  item.isAuxiliaryCancelled = !item.isAuxiliaryCancelled;
                });
              },
              style: TextButton.styleFrom(
                visualDensity: const VisualDensity(
                  horizontal: -3,
                  vertical: -4,
                ),
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: actionColor,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCancelled ? Icons.restore : Icons.remove_circle_outline,
                    size: 14,
                    color: actionColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isCancelled ? '恢复新增' : '取消新增',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 冲突卡片
  Widget _buildConflictCard(MergeItem item) {
    final isResolved = item.isResolved;
    final isMainSelected = item.decision == MergeDecision.keepMain;
    final isAuxSelected = item.decision == MergeDecision.keepAuxiliary;

    // 已解决显示为绿色，未解决显示为红色
    final primaryColor = isResolved ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: isResolved ? 1 : 2,
      color: primaryColor[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: primaryColor[300]!,
          width: isResolved ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor[100],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isResolved ? (isMainSelected ? '已选主' : '已选辅') : '冲突',
                    style: TextStyle(
                      fontSize: 10,
                      color: primaryColor[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    item.csvName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isResolved)
                  Icon(Icons.check_circle, color: Colors.green[600], size: 18),
              ],
            ),
            const SizedBox(height: 8),
            // 始终显示两个选项，支持反复切换
            _buildConflictOption(
              label: '主',
              rawValue: item.mainNode?.value,
              parentId: item.parentId,
              csvId: item.csvId,
              color: Colors.blue,
              isSelected: isMainSelected,
              onTap: () =>
                  setState(() => item.decision = MergeDecision.keepMain),
            ),
            const SizedBox(height: 6),
            _buildConflictOption(
              label: '辅',
              rawValue: item.auxiliaryNode?.value,
              parentId: item.parentId,
              csvId: item.csvId,
              color: Colors.orange,
              isSelected: isAuxSelected,
              onTap: () =>
                  setState(() => item.decision = MergeDecision.keepAuxiliary),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建冲突选项
  Widget _buildConflictOption({
    required String label,
    required dynamic rawValue,
    required int parentId,
    required int csvId,
    required MaterialColor color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color[100] : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? color[600]! : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color[600] : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color[600]! : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color[100],
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildValueContent(
                rawValue,
                parentId: parentId,
                csvId: csvId,
                textAlign: TextAlign.left,
                compact: true,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.green[600], size: 16),
          ],
        ),
      ),
    );
  }

  /// 构建底部保存栏
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
            '共${_mergeItems.length}项 | 冲突:${_mergeItems.where((i) => i.type == MergeItemType.conflict).length}',
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

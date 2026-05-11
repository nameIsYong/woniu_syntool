# syn_tool - 同步工具

## 项目概述

这是一个 Flutter Web 应用程序，用于批量同步健康医疗数据到指定平台。主要功能包括：

- 登录外部健康系统 API 获取认证令牌
- 批量同步不同类型的健康档案数据（健康筛查、高血压随访、糖尿病随访、中医辨识、健康体检等）
- 任务管理：支持开始、暂停、继续、重置、删除操作
- 定时暂停功能：可设置任务在指定时间自动暂停
- 导出失败档案：将同步失败的记录导出为 CSV 文件
- 查看"搭子"（合作伙伴设备）在线状态
- 登录历史记录管理

## 技术栈

- **框架**: Flutter 3.9.2+ (Dart)
- **目标平台**: Web (使用 `dart:html` 进行文件导出)
- **UI 设计**: Material Design 3
- **本地化**: 中文 (zh_CN)

## 关键依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| http | ^1.1.0 | HTTP API 请求 |
| crypto | ^3.0.3 | MD5 密码加密 |
| intl | ^0.20.2 | 日期格式化、国际化 |
| shared_preferences | ^2.2.2 | 本地存储登录历史 |
| path_provider | ^2.1.1 | 文件路径获取 |
| flutter_lints | ^5.0.0 | 代码规范检查 |

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── enums/                       # 枚举定义
│   ├── module_type.dart         # 模块类型枚举（健康筛查、档案、随访等）
│   └── task_status.dart         # 任务状态枚举（停止、运行中、已完成、暂停）
├── managers/                    # 单例管理器
│   ├── auth_manager.dart        # 认证信息管理
│   └── task_manager.dart        # 任务生命周期管理
├── models/                      # 数据模型
│   ├── http_model.dart          # HTTP 响应通用模型
│   ├── import_data_response.dart # 导入数据响应（含 UserData）
│   ├── institution_info.dart    # 机构信息
│   ├── login_info.dart          # 登录信息
│   └── sync_data_response.dart  # 同步数据响应
├── pages/                       # 页面
│   └── task_list_page.dart      # 任务列表主页面
├── services/                    # 服务层
│   ├── export_data_service.dart # 数据导出服务主类
│   ├── export_extension_*.dart  # 各模块导出扩展（part 文件）
│   └── network_service.dart     # 网络请求服务（登录、设备状态等）
├── util/                        # 工具类
│   ├── color_util.dart          # 颜色工具
│   ├── file_export_utils.dart   # 文件导出工具（Web 专用）
│   ├── login_history_util.dart  # 登录历史管理
│   ├── log_navigator.dart       # 页面导航日志
│   ├── map_extension.dart       # Map 扩展方法
│   └── string_util.dart         # 字符串工具
└── widgets/                     # 自定义组件
    ├── custom_selectable_text.dart  # 可选中文字组件
    ├── import_settings_dialog.dart  # 导入设置对话框
    └── task_item.dart               # 任务卡片组件
```

## 模块类型 (ModuleType)

支持同步的数据模块：

| 枚举值 | 显示名称 | API 标识 |
|--------|----------|----------|
| kScreening | 健康筛查 | TaskIllnessScreeningDetail |
| kArchives | 档案 | TaskArchivesDetail |
| kHypertension | 高血压随访 | TaskFollowUpHypertensionDetail |
| kDiabetes | 糖尿病随访 | TaskFollowUpDiabetesDetail |
| kHSM | 高糖合并随访 | TaskFollowUpHSMDetail |
| kCaseHyp | 高血压专案 | TaskChronicHypDetail |
| kCaseDia | 糖尿病专案 | TaskChronicDiaDetail |
| kTCM | 中医辨识 | TaskFollowUpTCMDetail |
| kPhysical | 健康体检 | TaskFollowUpPhysicalDetail |
| kSign | 签约 | TaskSignDetail |

## 外部 API 端点

| 功能 | 端点 |
|------|------|
| 登录认证 | `https://wndl.2woniu.cn/sign/sso/pass` |
| 用户信息 | `https://wnjk.2woniu.cn/staff/profile/loadAll` |
| 数据同步 | `https://wnjk.2woniu.cn/wnjkapp/sync/sync/service` |
| 设备在线状态 | `http://messagecenter.2woniu.cn:6087/center/device/device/list` |
| 档案基础信息 | `https://wnjk.2woniu.cn/wnjkapp/resident/archives/baseInfo` |
| 健康记录列表 | `http://bmg.2woniu.cn/bmanage/publichealth/healthrecord/list` |

## 构建和运行命令

```bash
# 获取依赖
flutter pub get

# 开发运行（Web）
flutter run -d chrome

# 构建 Web 版本
flutter build web

# 代码分析
flutter analyze

# 运行测试
flutter test
```

## 代码风格规范

项目使用 `flutter_lints` 包进行代码规范检查，配置在 `analysis_options.yaml` 中：

```yaml
include: package:flutter_lints/flutter.yaml
```

### 命名约定

- **文件**: 小写下划线命名（snake_case），如 `task_manager.dart`
- **类**: 大驼峰命名（PascalCase），如 `TaskManager`
- **方法/变量**: 小驼峰命名（camelCase），如 `startTask`
- **私有成员**: 下划线前缀，如 `_tasks`
- **常量**: 大写下划线，如 `kScreening`

### 扩展方法使用

项目大量使用 Dart 扩展方法来简化 Map 数据提取：

```dart
// map_extension.dart 提供的扩展
Map mapVal(String key)     // 安全获取 Map
List listVal(String key)   // 安全获取 List
int intVal(String key)     // 安全获取 int
String strVal(String key)  // 安全获取 String
double doubleVal(String key) // 安全获取 double
```

## 关键架构模式

### 1. 单例模式 (Singleton)

管理器类使用单例模式：

```dart
class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();
}
```

### 2. Part/Part of 模式

服务层使用 `part` 指令组织代码，主文件 `export_data_service.dart` 包含多个扩展文件：

```dart
// export_data_service.dart
part 'export_extension_dia.dart';
part 'export_extension_archives.dart';
// ... 其他模块
```

### 3. ChangeNotifier 模式

`SyncTask` 继承 `ChangeNotifier`，实现响应式 UI 更新：

```dart
class SyncTask extends ChangeNotifier {
  void addLogEntry(String log) {
    logEntries.add('${DateTime.now()} - $log');
    notifyListeners(); // 通知 UI 刷新
  }
}
```

## 测试策略

- **单元测试**: 位于 `test/` 目录
- **Widget 测试**: 使用 `flutter_test` 包
- 当前测试覆盖率较低，主要测试在 `test/widget_test.dart`

运行测试：
```bash
flutter test
```

## 安全注意事项

1. **密码存储**: 密码使用 MD5 哈希后传输，但登录历史以明文存储账号密码在本地 SharedPreferences
2. **Token 管理**: API Token 保存在内存中，应用重启后需要重新登录
3. **API 调用限制**: 代码中实现了请求间隔控制（`waitSeconds` + 随机延迟），避免频繁请求被封号
4. **同一机构限制**: 同一机构不能同时运行多个同步任务

## 开发注意事项

1. **Web 限制**: 由于目标平台是 Web，文件导出使用 `dart:html` 的 Blob API，无法在移动端运行
2. **日期处理**: 专案类型（kCaseHyp、kCaseDia）不需要日期选择
3. **日志限制**: 任务日志最多保留 1000 条，超过时只保留最新的 700 条
4. **登录历史**: 最多保存 20 条历史记录

## 任务状态流转

```
stopped -> running -> finished
   ^        |    ^
   |        v    |
   +---- paused --+
```

- **stopped**: 初始状态，可开始同步
- **running**: 同步进行中，可暂停
- **paused**: 暂停状态，可继续或重置
- **finished**: 同步完成，可重置后重新开始


## 注意事项

1. **代码注释**:所新增的代码或修改了复杂的逻辑尽可能添加代码注释。
2. **代码设计原则**:要以经验丰富的架构师角色进行设计、以高内聚、低耦合、模块化设计为主，复杂业务逻辑、UI组件都需要拆分。
3. **需求分析**:以经验丰富架构师的身份分析用户需求、思维扩展分析问题、含盖隐藏未提到的点、存在的风险.
4. **需求确认**:在修改代码、实现代码前，有模糊的、需要澄清的问题都需要及时提出让我确认。
5. **动手修改代码前，必须已得到用户明确指令才能开始修改。禁止部分问题模糊、待澄清、待确认时，用户没有明确指令时，你自动开始修改代码。
# syn_tool

## Windows 打包

项目已经配置好 GitHub Actions 的 Windows 打包流程。

### 触发方式

1. 打开 GitHub 仓库的 `Actions`
2. 选择 `Build Windows Release`
3. 点击 `Run workflow`

或者给仓库打一个 `v*` 开头的 tag，例如 `v1.0.0`，GitHub 会自动构建。

### 产物

- `syn_tool-windows-release.zip`
- zip 里包含 `syn_tool.exe` 以及运行所需的同目录文件

### 本地构建

如果你本机装了 Flutter，也可以直接执行：

```bash
flutter pub get
flutter build windows --release
```

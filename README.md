# Tailscale 安卓汉化版

基于官方 Tailscale Android 客户端的修改版，增加代理模式、内置浏览器和完整中文汉化。

> **当前版本：1.104.1**（真实版本号，Tailscale 控制台显示一致）
> 界面层（Kotlin/Java）基于官方 tailscale-android `release-branch/1.104`（6d75bd4，"go.mod: update for 1.104.1"），
> Go 核心为官方 `tailscale.com v1.104.1`，两者版本一致。

## 功能特性

### VPN 开启时
- 流量自动走 Tailscale 隧道（100.64.0.0/10）

### VPN 关闭时
- **代理模式**：将 Tailscale 作为本地 SOCKS5/HTTP 代理运行，无需 VPN 权限
  - SOCKS5: `127.0.0.1:1080`
  - HTTP: `127.0.0.1:8080`
  - 不与 Clash 等其他 VPN/代理应用冲突
- **内置浏览器**：无需配置代理，直接访问 Tailnet 上的 HTTP/FTP 服务
- 仍显示设备 IP 列表

### 分流模式
- 仅路由 Tailscale 流量，其他流量走系统默认路由
- 可与 Clash 等其他 VPN/代理应用同时使用
- 需重启 VPN 生效

### 完整中文汉化
- 500+ 界面字符串全中文
- 设置页代理/分流模式说明已汉化

## 已知问题

- 首次启动代理模式需等待 tsnet 连接（约 10-30 秒），期间状态显示连接中
- 预测性返回手势保持开启；为避开官方 navigation 2.8.5 在 `NavHost.kt:620` 的越界崩溃（设置页返回闪退），
  本仓库固定使用 navigation-compose **2.9.8**（见 `android/gradle/libs.versions.toml`），升级上游时请勿回退。

## 下载安装

从 [Releases](https://github.com/guoxpeng/tailscale-zh/releases/tag/v1.104.1) 下载最新 APK
（文件名形如 `Tailscale-zh-1.104.1.apk`）。

> ℹ️ **每个 Release 里同时挂着 Windows 与 Android 两个安装包** ——
> `Tailscale-zh-*-setup.exe`（Windows 一体化安装包）与 `Tailscale-zh-*.apk`（本端），
> 按扩展名取自己需要的那个即可。两个包由同一条发版流水线一起构建、一起发到 Release `v<版本号>`。

> ⚠️ 安装前需卸载官方版 Tailscale（签名不同），安装后重新登录。

## 自动打包与发布

**打一个 `v<版本号>` 标签即可同时出 APK 和 exe。**

1. 先把 `android/build.gradle.kts` 里的 `versionName` / `versionCode` 改好（versionCode 必须递增）并推到 `main`；
2. 打标签并推送（标签必须是 `v` + versionName，例如 versionName = `1.104.1-fix4`）：

```bash
git tag v1.104.1-fix4
git push origin v1.104.1-fix4
```

GitHub Actions（[`.github/workflows/release.yml`](.github/workflows/release.yml)）会在同一次运行里：

- 在 `main`（标签所指提交）构建**全架构 APK**（arm64-v8a + armeabi-v7a + x86 + x86_64）→ `Tailscale-zh-<版本号>.apk`；
- 检出 `pc` 分支构建 Windows 一体化安装包 → `Tailscale-zh-<版本号>-setup.exe`
  （文件名带发版版本号；安装包内部登记的官方组件版本仍是 1.104.1，汉化补丁只适配官方 1.104.1）；
- 两个都构建成功后，一起发到 Release **`v<版本号>`**，并附 `SHA256SUMS.txt`。

注意：

- 标签与 versionName 不一致时流水线会**直接失败**，不会发出版本号对不上的 Release。
- 在 Actions 页面手动触发 `release.yml`（workflow_dispatch）只构建、上传产物，**不发布** Release，适合发版前试跑。
- 旧的 `android-v*`（本分支）和 `pc-v*`（`pc` 分支）标签**已不再发版**，
  `android-release.yml` / `build-pc-installer.yml` 只保留手动构建，避免重复发版。
- 签名用的是仓库内 [`.ci/android-debug.keystore`](.ci/) 这把**固定调试密钥**，
  因此各版本签名一致，用户可**直接覆盖安装升级**，不必反复卸载重装。

> ⚠️ 从早期手工构建的版本（如 `v3-fix`）升级仍需**先卸载一次**，之后就不会再有这个问题。

## 发布历史

- `v1.104.1`：统一发版标签 —— 同一个 Release 里同时挂着 Windows 安装包与 Android APK。
  （此前的 `android-v1.104.1`、`v3-fix`、`v1.104.1-zh` 等单端 Release 已合并/下线，标签保留。）

## 本地构建

需要 Go、JDK 21、Android SDK（API 36）、Android NDK：

```bash
# 安装 Android SDK 组件
make androidsdk

# 构建 debug 版
make tailscale-debug
# 输出: ./tailscale-debug.apk

# 构建 release 版
make apk
```

详见 [官方构建文档](https://github.com/tailscale/tailscale/wiki)。

## 致谢

- [Tailscale](https://tailscale.com) 官方团队
- [pjjush16/tailscale-android-proxy](https://github.com/pjjush16/tailscale-android-proxy) 代理模式原作者

## License

BSD 3-Clause，与上游一致。见 [LICENSE](LICENSE)。

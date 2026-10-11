本页**同时挂着 Windows 与 Android 两个安装包**，按需下载即可（两条流水线都会写入本页）。

### 🖥️ Windows — `Tailscale-zh-<版本>-setup.exe`

一体化向导安装包，**已内嵌同版本官方组件**：没装过 Tailscale 的电脑直接装本包就行 ——
安装器会先用官方 MSI **静默**装好完整组件（`msiexec /qn`，无英文向导、无弹窗），再把界面换成中文版；
已装同版本的电脑自动跳过官方安装，只替换界面程序。

> ⚠️ **2026-10-11 修订二（装过 r6 及更早版本的请重新下载本安装包）**
>
> - **修复「装完弹出一个满是堆栈的报错框」**。错误长这样：
>   `Unable to set up Tailscale client:` 下面跟着
>   `walk.NewNotifyIcon: Shell_NotifyIconW(…) failed: error 87` 和几十行 Go 堆栈。
>   根因**不在程序本身** —— 同一份文件手动启动完全正常；问题出在**安装器的时序**：
>   为了刷新任务栏图标缓存，安装器会把 `explorer.exe` 重启一次，却在**任务栏还没重建完**
>   时就立刻把 Tailscale 界面程序拉起来。此时通知区域尚不存在，
>   `Shell_NotifyIconW` 就会以 **error 87（ERROR_INVALID_PARAMETER）** 失败，
>   而 Tailscale 对这一失败的处置是**直接弹框报错**（不降级、不重试）。
>   现已加入 `WaitForShellReady`：轮询任务栏窗口、确认重建完成（再留 2 秒缓冲）之后
>   才启动界面程序；万一任务栏迟迟不回来，还会主动重新拉起一次 Explorer 再等。
> - 结束旧界面程序时改为**先温和请求退出**（`taskkill` 不带 `/F`），让它走正常退出流程
>   把自己的托盘图标注销掉，再强杀兜底 —— 残留的图标登记会干扰下一次注册。
> - 托盘图标缓存的清理范围也收窄了：只动**本安装目录**下的那份登记，以及文件名相同但
>   文件已不存在的残留，不再碰别的程序。
>
> ⚠️ **2026-10-11 修订（安装过旧版的请重新下载本安装包再装一次）**
>
> - **修复「安装时报 `Unable to set up Tailscale client` / `…is not a valid application
>   for this OS platform`」**：安装器替换界面程序时，老实现里有一条「覆盖式写入」的退路 ——
>   会先把 `tailscale-ipn.exe` **截断成 0 字节**再逐块写入 29MB，这零点几秒里它是一个残缺文件。
>   偏偏 Windows 版 Tailscale 的界面程序在启动早期会 fork/exec 一遍自己的路径（用于以提权方式
>   拉起 `tailscaled` 服务），一旦撞上这个窗口就会弹出上述错误（错误码即 Win32 193 = 可执行文件
>   格式无效）。现已把替换改为**全程原子 rename**：`tailscale-ipn.exe` 任何时刻要么是完整的旧版、
>   要么是完整的新版，**绝不会出现半成品**；替换后还会校验文件大小，一旦不对就自动回滚官方原版
>   并明确报错，不会再让你拿到一个连启动都失败的主程序。
> - **补全「引导页 / 登录页」整块汉化（界面仍有英文）**：卸载后重装或首次登录时，主界面会停在
>   `Join your network` 引导页，而这一屏此前**完全没有被收录**进汉化对照表 —— 表现就是
>   「托盘右键菜单是中文，一打开主界面全是英文」。本次补上 14 条：
>   `Join your network` → 加入网络、`Connect this device to your Tailscale network`、
>   `Welcome to Tailscale` → 欢迎使用、`Get Started` → 开始、`Sign in to your network` → 登录你的网络、
>   `Waiting for approval` → 等待批准、`Open admin console` → 管理控制台、
>   `Open local settings` → 打开本机设置、`Device rejected` → 设备被拒绝，以及
>   「等待管理员批准 / 设备被拒绝 / 已连接后的提示 / 团队连接说明 / 没有账号？注册」这几段整句。
>   汉化条目 126 → **140**。
> - **修复「装完无法登录」**：此前安装器用「界面程序 `tailscale-ipn.exe` 是否存在」判断
>   「官方组件是否已装」，而汉化包自己就会放这个文件 —— 一旦官方组件被单独卸载过
>   （服务与 `tailscaled.exe` 没了、界面程序还在），再装就会被误判成「已装好」从而
>   **跳过官方安装**，结果是 `tailscaled` 服务缺失、托盘显示
>   「The Tailscale service not installed on this machine」，点「登录...」也没有反应。
>   现已改为校验 **Windows 服务 `Tailscale` + `{app}\tailscaled.exe`** 是否都在，
>   缺失时自动静默补装官方组件（必要时强制重装），装不上就明确报错，不再产出残缺安装。
> - **修复「装完任务栏图标不显示 / 变成白纸图标」**：图标本身没问题 —— 汉化版与原版的
>   图标资源逐字节一致，`ExtractIconExW` 也能取到完整的九点 logo。真正的原因是 Windows 11
>   把每个托盘图标按**可执行文件路径**登记在 `HKCU\Control Panel\NotifyIconSettings` 下并缓存一份
>   图标快照，**原地替换 exe 不会刷新它**，于是任务栏一直渲染那个几乎全透明的旧快照
>   （实测最大 alpha=76，白底上几乎看不见，其余 94 条系统图标都是 255）。
>   本安装包现在会在装完后刷新图标缓存、清掉指向本程序的陈旧登记项，并在确实清到时
>   自动重启一次 Explorer 让新图标立即生效；干净机器不会被打扰。
> - **补齐 8 条残留英文**：托盘右键菜单的 `E&xit` → 退出(&X)、`&Settings` → &设置、
>   `&Open Tailscale` → &打开 Tailscale、`Open` → 打开（旧表改的是菜单内部 ID `Exit`，
>   显示文本其实是带 `&` 助记符的那一条，所以界面毫无变化），
>   以及服务状态提示 `The Tailscale service not installed on this machine` /
>   `The Tailscale service is stopped` / `Failed connecting to the Tailscale service...`。
>   汉化条目 118 → **126**。

- **用法**：右键 → **以管理员身份运行**。卸载「Tailscale 中文汉化」即自动还原官方界面程序。
- 只替换托盘 / 主界面程序 `tailscale-ipn.exe`，**不改动** `tailscaled` 服务与 WinTun 驱动。
- 汉化后官方数字签名失效，Windows 可能提示「未知发布者」；
  请在「设置」中取消勾选「自动安装&更新」，否则会被官方版覆盖回去。

### 📱 Android — `Tailscale-zh-<版本>.apk`

**全架构** APK（arm64-v8a + armeabi-v7a + x86 + x86_64），新老机型与模拟器都能装。

- **装法**：本包用**固定密钥**签名，与官方签名不同，**首次安装请先卸载官方 Tailscale**，
  装完重新登录；之后各版本之间可直接覆盖安装升级。
- 附带功能：**代理模式**（把 Tailscale 当本地 SOCKS5 `127.0.0.1:1080` / HTTP `127.0.0.1:8080` 跑，
  无需 VPN 权限，可与 Clash 共存）、**内置浏览器**、**分流模式**（只路由 100.64.0.0/10）、
  完整中文界面。
- 从早期手工构建版本（如 `v3-fix`）升级，需要**先卸载一次**。

---

> - 两个文件的 `sha256` 由 GitHub 直接标在下方 Assets 上，无需另附校验清单。
> - 源码：`pc` 分支 = Windows 端，`main` 分支 = Android 端；两条流水线都写入**本页**，
>   各自只覆盖自己那个文件，另一端的安装包保持不动。

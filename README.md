# Tailscale Windows 汉化

> ✅ **现已一体化：安装包自带官方 Tailscale 1.104.1 组件，无需预装。**

**下载**：打开 [**Releases**](https://github.com/guoxpeng/tailscale-zh/releases/tag/v1.104.1) ——
**每个 Release 里同时挂着 Windows 与 Android 两个安装包**：

| 端 | 文件 | 说明 |
| --- | --- | --- |
| 🖥️ Windows | `Tailscale-zh-<版本>-setup.exe` | 本仓库（`pc` 分支）产出 · 一体化向导安装包，内嵌官方组件 |
| 📱 Android | `Tailscale-zh-<版本>.apk` | `main` 分支产出 · 全架构 APK |

两条流水线都写**同一个** Release（标签 `v<版本号>`），各自只覆盖自己那个文件、
不动另一端的安装包；其余材料都在仓库源码里。CI 每次推送都会重新构建，Release 资产与源码逐字节对应。

> - **没装过 Tailscale 的电脑**：直接装本包即可 —— 会先**静默**装好官方组件
>   （`msiexec /qn`，全程无界面、无英文向导、无弹窗），再把界面换成中文版。
> - **已装 Tailscale 1.104.1 的电脑**：自动跳过官方安装，直接替换界面程序。
> - **装的是其它版本**：安装会在**动任何文件之前直接中止**，提示你先在
>   「设置 → 应用」里卸载它。汉化补丁按 1.104.1 的精确文件偏移生成，对其它版本
>   强行替换会让界面程序与服务端版本错配，轻则功能异常、重则启动即崩，
>   所以这里**不给「继续安装」的选项**。


把 Tailscale **Windows 桌面端**（`tailscale-ipn.exe`，托盘图标与主面板）的界面文字替换成简体中文。

- 基版本：**Tailscale 1.104.1 (x64)**
- 方式：对官方二进制做**偏移补丁**（保长原地替换为主），不重新编译
- 产出：**向导式安装包**（Inno Setup，约 38 MB，内嵌官方 MSI），也可单独取汉化后的 `tailscale-ipn.exe`

> 界面汉化只替换托盘 / 主界面程序 `tailscale-ipn.exe`，**不改动** `tailscaled` 服务与 WinTun 驱动。
> 未装 Tailscale 时，安装包会先用官方原始 MSI 静默装好完整组件，再打汉化。

---

## 一、直接使用

### 方式 A：安装包（推荐）

下载本仓库 Release 里的 `Tailscale-zh-1.104.1-setup.exe`，**双击运行**即可
（安装程序会自己请求管理员权限，Inno 的 `PrivilegesRequired=admin`）。

> ⚠️ **不要「右键 → 以管理员身份运行」。** 那种启动方式下 Inno 拿不到「登录用户」的
> 凭据（官方文档写明 `runasoriginaluser` 会失效、退化成用提权身份执行），后果是：
> 托盘程序会被**以管理员身份**拉起（Tailscale 官方不支持 GUI 提权运行）；
> 此时安装器会退而用「交给已在用户会话里的 Explorer 转交启动」兜底，
> 但仍不如双击干净。双击运行则一切正常。
> 仓库里的 `scripts/install_zh.bat` 是个普通批处理，**没有**自动提权能力，
> 那个才需要右键「以管理员身份运行」。

安装程序会：

1. 检查目标机是否已装 Tailscale。
   - **没装** → 用随包的官方 MSI **静默**安装完整组件，再替换界面程序。
     **全新机器一步到位，不必先手动跑官方安装向导。**
   - **已装** → 跳过官方安装，只替换界面程序，并把原版备份为 `tailscale-ipn.exe.orig`。
2. 退出正在运行的托盘程序 → 写入汉化版 → 重新拉起托盘程序。
3. 把官方 MSI 在「设置 → 应用」里的那条 `Tailscale` 隐藏掉（写 `SystemComponent=1`），
   列表里**只留「Tailscale 中文汉化」一条**，不用再纠结该卸哪个。
   被隐藏的只是列表显示 —— 条目本身还在注册表里，官方组件的卸载 / 修复能力一点没少。

> 如果本机已装的 Tailscale **不是 1.104.1**，安装程序会**直接中止**并提示先在
> 「设置 → 应用」里卸载它。汉化补丁是按 1.104.1 的精确文件偏移生成的，
> 对其它版本强行替换会让界面程序与服务端版本错配，轻则功能异常、重则启动即崩，
> 所以这里不给「继续安装」的选项。

卸载「Tailscale 中文汉化」即可**自动还原**官方界面程序：

- 托盘程序会随卸载一起退出，从开始菜单重新打开 Tailscale 即可；
  `tailscaled` 服务、WinTun 驱动与网络连通性全程不受影响。
- 官方 Tailscale 本体**不会**被卸载，而且卸载时官方条目会**恢复显示**，
  之后可以在「设置 → 应用」里单独卸载它。

### 方式 B：手动替换

> 前提：目标机已装**官方 Tailscale 1.104.1**。

```
1. 右键托盘图标 → 退出 Tailscale
2. 备份  C:\Program Files\Tailscale\tailscale-ipn.exe
3. 用 tailscale-ipn.zh.exe 覆盖它（需管理员权限）
4. 重新运行 C:\Program Files\Tailscale\tailscale-ipn.exe
```

> 第 1 步别省。直接覆盖会把目标文件**先截断成 0 字节**再写入 29 MB，
> 这零点几秒里它是一个残缺 PE；而 Tailscale GUI 在启动早期会 fork/exec 一遍自己的
> 路径，撞上就会报 `… is not a valid application for this OS platform`（Win32 193）。
> 想省心就直接用下面的方式 C —— 那个脚本走的是**原子改名替换**，且失败会自动回滚。

仓库里的 [`prebuilt/tailscale-ipn.zh.exe`](prebuilt/) 是成品副本，从仓库直接下载即可；
其 SHA256 见同目录 `SHA256SUMS.txt`，与 CI 从同一源码构建出的产物逐字节一致。

### 方式 C：一键脚本

下载仓库里的 [`scripts/install_zh.bat`](scripts/install_zh.bat) 与
[`prebuilt/tailscale-ipn.zh.exe`](prebuilt/) 放到**同一目录**，
**右键 → 以管理员身份运行**即可；`install_zh.bat restore` 还原官方原版。

脚本会先把官方原版备份为 `tailscale-ipn.exe.orig`（若你之前用过旧版脚本，
它会兼容读取旧的 `.orig.bak`），再用**原子改名**的方式换入汉化版并重启托盘程序：
先把汉化版复制成安装目录里的 `tailscale-ipn.exe.new`，然后 `move` 改名交换
（旧 → `.old`，新 → 正式名），失败立刻把旧的挪回来，**任何时刻都不会留下残缺的主程序**。
改名重试用尽仍失败时，还会自动用备份把官方原版还原回去。

> 它的 SHA256 与汉化主程序一起列在 `prebuilt/SHA256SUMS.txt` 里（CI 会强制校验
> 这两份文件与本次构建一致）。

---

## 二、汉化范围

共 **140 条**界面文案，覆盖主面板、Preferences（设置）、账号子菜单、Exit nodes（出口节点）子菜单，
以及引导页 / 登录页、托盘提示、气泡通知、Taildrop 文件传输、更新提示、管理员批准/签署、
**无人值守 / 出口节点确认对话框**、**托盘右键菜单**与**服务状态提示**等二级界面。
完整中英对照见 [`tools/zh_win.tsv`](tools/zh_win.tsv)。

| 类别 | 例子 |
| --- | --- |
| 连接状态 | `Connected` → 已连接 · `Connected - ` → 已连接 -  · `Connecting...` → 连接中... · `Connection lost` → 连接已断开 |
| 菜单项 | `Preferences` → 设置 · `Log &out` → 注销 · `Bug report...` → 问题反馈... · `Open with...` → 打开方式... |
| 托盘右键菜单 | `E&xit` → 退出(&X) · `&Settings` → &设置 · `&Open Tailscale` → &打开 Tailscale · `Open` → 打开 |
| 服务状态提示 | `The Tailscale service not installed on this machine` → 本机未安装 Tailscale 服务 · `The Tailscale service is stopped` → Tailscale 服务已停止 · `Failed connecting to the Tailscale service` → 无法连接 Tailscale 服务 |
| 设备列表 | `This device: %s (%s)` → 本机: %s (%s) · `unknown device` → 未知设备 · `Managed by %s` → 管理方 %s |
| 出口节点 | `Exit nodes` → 出口 · `Run exit node...` → 运行出口节点 · `No exit node available` → 无可用出口节点 |
| 托盘提示 | `Tailscale: Please log in.` → Tailscale: 请登录。 · `You are logged out. The last login error was: %v` → 您已注销。上次登录错误：%v |
| 文件传输 | `Ready to send %d files` → 准备发送 %d 个文件 · `You canceled the file transfer.` → 您取消了文件传输。 |
| 通知与状态 | `Tailscale Update Available` → Tailscale 有可用更新 · `Always On mode` → 常开模式 · `Latest %s version: %s` → 最新 %s 版本：%s |
| 网络异常 | `Tailscale could not connect to the '%s' relay server...` → Tailscale 无法连接中继服务器 '%s'。 · `You have enabled a non-default log target...` → 您已启用非默认的日志目标。 |
| 确认对话框 | `Are you sure you want to enable Unattended Mode?` → 确定要启用无人值守模式？ · `Are you sure you want to run an exit node?` → 确定要运行出口节点？ |
| 管理员操作 | `Admin Approval Needed` → 需要管理员批准 · `Your network admin needs to sign this computer...` → 网络管理员需要签署此计算机加入网络。 |

---

## 三、实现原理（简述）

Go 编译的二进制把字符串常量**连续**堆在 `.rdata` 里，代码用 `LEAQ` 取地址 + `MOV` 加载长度来引用。
补丁器的做法：

1. 用 [capstone](https://www.capstone-engine.org/) **全量反汇编** `.text`，建立 `地址 → [(引用指令, 声明长度)]` 表。
2. **保长替换为主**：中文 UTF-8 字节数 ≤ 英文时，原地写入中文 + 空格补齐。
   长度一字节不变 ⇒ 不用改任何指令，对 `LEAQ`、静态 `{ptr,len}` 头、数据段指针等**任何引用方式都自动生效**。本版 140 条里有 121 条走这条路。
3. **扩容**：中文更长时（本版 19 条），写入 `.rsrc` 尾部
   504 字节全零空档，并同步改写引用处的 `LEAQ` 位移与长度立即数。当前共用掉 356 字节。
4. **重叠字面量保护**（关键）：`.rdata` 里存在共享前缀的字面量，例如 `Preferences`(11) 与
   `PreferencesMenu`(15) 相邻存放。后者是 syspolicy 设置键，用来拼 Prometheus 指标名；
   若被误改成中文会直接 `panic: illegal metric name`。
   因此对每个候选地址，取其 `LEAQ` 之后**紧随的首个「写寄存器」`MOV reg, imm`** 作为*声明长度*，
   只要与当前串长度不符就**拒绝该位置**。
5. **多行文案**：无人值守 / 出口节点确认框的正文本身就是**一条含 `\r\n\r\n` 的长字符串常量**
   （例如 `Are you sure you want to enable Unattended Mode?` 那条 286 字节）。TSV 是逐行解析的，
   写不进真实换行，故对照表支持 `\r` `\n` `\t` `\\` `\xHH` 转义（行尾空格写作 `\x20`），
   由 `patch_zh.py` 在读取时还原；`verify.py` 用同一套还原逻辑，避免两边不一致。

## 四、构建

### 本地构建

```bash
python -m pip install capstone

# 1) 取官方原始程序（MSI 内文件名为 ClientGUIx64）
curl.exe -L -o tailscale-setup.msi https://pkgs.tailscale.com/stable/tailscale-setup-1.104.1-amd64.msi
"C:\Program Files\7-Zip\7z.exe" x tailscale-setup.msi -oextract -y

# 2) 打补丁（内含 SHA256 校验，源文件不符会直接报错）
python tools/build.py extract/ClientGUIx64 build

# 3) 校验产物
python tools/verify.py extract/ClientGUIx64 build/tailscale-ipn.zh.exe tools/zh_win.tsv
```

产物在 `build/`：`tailscale-ipn.zh.exe` + `patch-report.txt`。

### 编译安装包

```bash
# 需先装 Inno Setup 6（CI 里固定用 6.7.3）
ISCC.exe installer\tailscale-zh.iss
# 产物: dist\Tailscale-zh-1.104.1-setup.exe
```

安装包是否内嵌官方 MSI（即是否具备「一体化安装」能力），由编译期探测仓库根目录有没有
`tailscale-setup.msi` 决定（`#ifexist`）：

- **有** → 内嵌，约 38 MB，全新机器可直接一键装好；
- **没有** → 自动降级成「仅替换」模式，约 8.5 MB，要求目标机已装官方版。

不想在系统里装 Inno Setup 也可以免安装解压一份来用（Inno 自己的安装包支持 `/PORTABLE=1`）：

```bash
innosetup-6.7.3.exe /PORTABLE=1 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=inno
inno\ISCC.exe installer\tailscale-zh.iss
```

> 改完 `.iss` 建议先在本地跑一次上面的编译再推 CI：
> 编译器能直接指出脚本函数用错（例如 `FileSize` 是 `var` 出参而非返回值、
> `ExecAsOriginalUser` 在卸载阶段不可调用），比等 CI 快得多。

### CI 自动构建

`.github/workflows/build-pc-installer.yml`：推送到 `pc` 分支（或手动触发 `workflow_dispatch`）时，
自动下载官方 MSI → 校验 SHA256 → 打补丁 → 校验产物 → 装 Inno Setup 6.7.3 → 编译安装包 → 上传 Artifact。
打 `pc-v*` 标签时额外发版，且**统一发到 Release 标签 `v<版本号>`**（例如 `v1.104.1`）。

**发版约定：一个 Release = 一个版本 = 两个安装包。** Windows 流水线（`pc` 分支，`pc-v*` 标签）
与 Android 流水线（`main` 分支，`android-v*` 标签）各自往**同一个** `v<版本号>` Release 里写资产，
所以打开任意一个 Release 都能同时看到 `Tailscale-zh-<版本>-setup.exe` 与 `Tailscale-zh-<版本>.apk`；
重跑只会覆盖同名文件（`overwrite_files: true`），另一端的包保持不动。Release 说明统一取自
[`.github/release-notes.md`](.github/release-notes.md)，避免两条流水线各写一份。

汉化主程序、中英对照表、补丁明细、一键脚本都在仓库源码里，不重复上传；文件的 `sha256`
由 GitHub 直接标在资产上。（页面下方自动出现的 `Source code (zip/tar.gz)` 是 GitHub
为每个 Release 强制的源码快照，无法删除，任何仓库都一样。）

CI 会在**源文件哈希不符**时直接失败（不会产出错误的包），因此 Tailscale 换版后不会静默出错。

---

## 五、目录

```
.
├── .github/workflows/build-pc-installer.yml   CI：自动出安装包
├── installer/
│   ├── tailscale-zh.iss                       Inno Setup 安装包脚本
│   └── ChineseSimplified.isl                  安装向导简中语言包（取自 issrc 同版本 tag）
├── scripts/install_zh.bat                     一键安装 / 还原脚本
├── prebuilt/tailscale-ipn.zh.exe              成品副本（含 SHA256SUMS.txt）
├── tools/
│   ├── build.py                               构建入口（含源/产物 SHA256 校验）
│   ├── patch_zh.py                            汉化补丁器（核心）
│   ├── verify.py                              产物校验器
│   ├── analyze_refs.py                        RIP 相对引用扫描（排查用）
│   ├── build_strtab3.py                       字符串常量表提取（排查用）
│   ├── prebuilt_check.py                      校验 prebuilt/ 与 SHA256SUMS.txt 未漂移（CI 硬检查）
│   └── zh_win.tsv                             140 条中英对照表（支持 \r\n\xHH 转义）
└── docs/patch-report.txt                      最近一次补丁明细
```

---

## 六、注意事项

- **数字签名失效**：改动后的 `tailscale-ipn.exe` 不再有 Tailscale 官方签名，Windows 可能提示「未知发布者」。
- **自动更新会覆盖汉化**：请到「设置 → 自动安装&更新」取消勾选（`Automatically install &updates`）。
- **换版本要重做偏移表**：补丁依赖精确的文件偏移，Tailscale 升级后 `zh_win.tsv` 与 `build.py` 里的
  SHA256 常量都需要更新；CI 会在源文件哈希不符时直接失败，不会产出错误的包。
- 本项目仅为界面汉化，与 Tailscale Inc. 无关联，不分发其源码或未修改的官方二进制。

---

## 七、更新日志

### `v1.104.1`（当前）

> 发版标签由 `pc-v1.104.1-fix` 改为统一的 **`v1.104.1`** —— 该 Release 同时挂着
> Windows 安装包与 Android APK。旧标签仍在，但不再对应 Release。

**修复**

- **安装包一体化**：`setup.exe` 内嵌官方 1.104.1 MSI。全新机器直接装本包即可，
  安装器先用 `msiexec /qn /norestart TS_NOLAUNCH=1` **静默**装好完整组件
  （无英文向导、无弹窗、不由官方安装器抢先拉起托盘），再替换界面程序。
- **补齐无人值守弹窗**：`Run unattended`（无人值守）确认框正文此前一直是英文。
  根因是**对话框正文本身就是一条 286 字节的多行长字符串常量**，从未被收录进对照表；
  标题 `Confirm unattended mode` 早已汉化，所以只看到正文是英文。现已汉化，
  出口节点确认框正文（249 字节）同理一并修复。
- **修掉 3 条「写了但没生效」的条目**：`You are logged out. The last login error was: %v`、
  `Connected - `、`Managed by %s`。旧表只收录了短前缀，被「重叠字面量保护」判定为
  更长字面量的子串而**拒绝落位**，界面因此一直是英文。
- 对照表新增 `\r` `\n` `\t` `\\` `\xHH` 转义（多行文案与行尾空格必需），
  `patch_zh.py` 与 `verify.py` 用同一套还原逻辑。
- 安装器新增**版本一致性检查**：检测到已装 `tailscale-ipn.exe` 大小与本包基准不符时
  **直接中止**（并提示先卸载现有 Tailscale），避免把不同版本的界面程序与 `tailscaled` 服务混用。
  该检查在 `InitializeSetup` 里就做，即「变动任何文件之前」。（修订 3 起）

**汉化条目**：47 → **118 条**（修订 2 后 **126 条**，修订 3 后 **140 条**：
保长替换 121 + 扩容 19，扩容区 356/504 字节）。

**修订 2 —— 修复「无法登录」与「托盘菜单仍有英文」**

- **无法登录 = 官方服务缺失**。装完本包后托盘只显示「The Tailscale service not installed on this machine」，
  点「登录...」也无效，因为 `tailscaled` 服务压根不在。
  根因是安装器判断「官方组件是否已装」用的是**界面程序 `tailscale-ipn.exe` 是否存在** ——
  可汉化包自己就会往 `{app}` 放这个文件；一旦官方组件被单独卸掉（服务与 `tailscaled.exe` 没了、
  界面程序还在原地），再装就会被误判成「已装好」而**跳过官方安装**。
  现已改为检查 **Windows 服务 `Tailscale` 与 `{app}\tailscaled.exe`** 是否都在；
  缺失时自动静默安装官方组件，必要时再补一次 `REINSTALL=ALL REINSTALLMODE=vomus` 强制重装，
  装完仍不就位则明确报错中止（不再静默产出一个「只有界面、没有服务」的残缺安装）。
- **托盘菜单「Exit」仍是英文**：菜单项的显示文本走 `rdi/rsi` 参数位
  （`lea rdi, [str]; mov esi, len`），而 `Exit` 只是传给该函数的**内部 ID** ——
  旧表改的正是这个 ID，界面自然毫无变化。真正的显示文本是带 Windows 助记符的 `E&xit`；
  同一批漏掉的还有 `&Settings`、`&Open Tailscale`、`Open`，现已一并汉化。
- **服务状态提示整组漏翻**：`The Tailscale service not installed on this machine` /
  `The Tailscale service is stopped` / `Failed connecting to the Tailscale service ...`
  来自一个 `map[string]string`，其值经 `mov qword ptr [rax+8], <len>` 写入**内存**，
  旧版补丁器只认「写寄存器」的 MOV 作为长度声明，因此整组都没落位。现已补上。

**修订 3 —— 修掉几条「装到一半出错 / 装完不对劲」的路径**

- **「设置 → 应用」里不再出现两条 Tailscale**。本包会替你装好官方组件，官方 MSI
  因此登记一条 `Tailscale`，汉化包自己又登记一条 `Tailscale 中文汉化` ——
  两条并排，用户不知道该卸哪个。现在给官方那条写上 `SystemComponent=1`
  （Windows 自带的「隐藏条目」开关），列表里只留汉化包一条；卸载本包时**原样恢复**。
- **修掉「装完弹出一个满是堆栈的报错框」**（`Shell_NotifyIconW … error 87`）。
  根因是安装器为了刷新托盘图标缓存重启了 `explorer.exe`，却在**任务栏还没重建完**
  时就启动界面程序 —— 通知区域尚不存在，`Shell_NotifyIconW` 以 error 87
  （`ERROR_INVALID_PARAMETER`）失败，而 Tailscale 对这一步的处置是**直接弹框**。
  当时加了 `WaitForShellReady`：先等**旧**任务栏消失、再等**新**任务栏出现，
  最后留 2 秒缓冲才启动界面程序。
  > ⚠️ **修订 4 已推翻这个做法并整段删除。** 实测证明「窗口存在 + 固定 2 秒」
  > 并不足以保证通知区域可注册（仍然复现了 panic），而它想修的「陈旧图标快照」
  > 经 A/B 实测根本不存在。详见下面「修订 4」一节。
- **修复 prebuilt 成品副本漂移**（修订 2 遗留）：引导页汉化后对照表从 126 条加到
  140 条，但仓库里 `prebuilt/tailscale-ipn.zh.exe`（README 方式 B/C 让用户直接下载的那个）
  **还是 126 条的旧版本**，`SHA256SUMS.txt` 记录的也是旧哈希，看起来「校验通过」。
  按方式 B/C 装的用户，主界面引导页仍是英文。现已刷新，并在 CI 里加了硬检查
  （`tools/prebuilt_check.py`）：`prebuilt/` 必须与本次构建逐字节一致，否则 CI 直接失败。
- **一键脚本 `install_zh.bat` 改为原子替换**：它原先用 `copy /Y` 覆盖主程序 ——
  这正是修订 1 修掉的安装包同源缺陷（先把目标截断成 0 字节再逐块写，
  这零点几秒里主程序是残缺 PE，而 Tailscale GUI 启动早期会 fork/exec 自己）。
  更糟的是 5 次重试全失败后它**不回滚**，会把 `tailscale-ipn.exe` 留在残缺状态，
  Tailscale 直接起不来。现在改成「复制到同目录 `.new` → `move` 改名交换 → 失败立刻回滚」，
  并把失败路径也纳入了沙盒测试（占用主程序时必须干净失败、绝不留下坏文件）。
- **静默安装不再掀掉用户的桌面**：`/SILENT`、`/VERYSILENT`（企业无人值守部署）时
  不再重启 `explorer.exe`。
  同时修掉一个反向问题：静默安装会杀掉正在运行的托盘程序却**不再拉起**，
  导致任务栏图标凭空消失到下次登录 —— 现在只要「安装前它本来就在跑」，
  无论是否静默都会把它拉回来。
  （修订 4 之后这条更彻底：**任何**模式下都不再重启 Explorer，见下。）
- **版本不一致改为在任何文件被改动之前就中止**（`InitializeSetup` 预检）。
  以前是在文件复制完、官方组件装完之后才中止，走 `RaiseException` 触发回滚 + 弹框，
  而那个错误框在 `/SUPPRESSMSGBOXES` 下要等约两分钟才自动按掉，无人值守部署会被卡住。
- **修掉安装包脚本里一个从未被使用的宏**（`MyZhVersion`，写着 1.2.0 但其实哪儿都没用），
  免得和后缀为 `pc-v1.104.1-rN` 的 Release 标签形成两套对不上的版本号。

- **修正安装程序的启动方式说明**：以前这里写「右键 → 以管理员身份运行」，而 Inno
  官方文档明确说以这种方式启动时 `runasoriginaluser` / `ExecAsOriginalUser`
  **没有效果**、会退化成用提权身份执行 ——   结果是托盘程序被以管理员身份拉起
  （Tailscale 官方不支持 GUI 提权运行）。本包本来就是 `PrivilegesRequired=admin`、会自己弹 UAC，
  **双击运行**即可；安装器在拿不到原始用户凭据时会把原因写进安装日志，
  并以「交给已在用户会话里的 Explorer 转交启动」作为兜底。

**修订 4 —— 移除「重启 Explorer」这条危险链路，改为启动后体检 + 重试**

现象：装完包弹出 `Unable to set up Tailscale client: walk.NewNotifyIcon: Shell_NotifyIconW(...)`
的 panic 框，**而且托盘图标整个消失**（比装之前还糟）。

- **坐实了两个结论**（本机实测）：
  1. 以前的「陈旧托盘图标快照」判断是错的。让**官方原版** exe 与汉化版各自冷启动、
     各自重建 `HKCU\Control Panel\NotifyIconSettings` 登记项，两边拿到的都是
     **同一张** 24×24 PNG，最大 alpha 同为 76 —— 快照不是缓存坏了，
     而是 Tailscale 运行时画出来的图标本来就长这样。**删掉重建还是同一张，纯无用功。**
  2. `RestartExplorerAsUser` + `WaitForShellReady` 不足以保证通知区域可注册：
     日志显示任务栏窗口出现 2 秒后就拉起 GUI，GUI 随即 panic。
     而同一个 exe 在几分钟后手工启动**完全正常** —— 说明这是**瞬时**竞态，
     不是文件或补丁的问题。
- **做法**：把 `PurgeStaleTrayIconCache` / `RestartExplorerAsUser` / `WaitForShellReady`
  **整段删除**，安装器**再也不碰 Explorer**（桌面不会再闪）。改成
  `StartTrayAsUser` 里「拉起 → 体检 → 重试」最多 3 次：用 `tasklist |
  %SystemRoot%\System32\find.exe` 确认进程真的活着，期间一旦发现标题为
  「Tailscale 错误」的报错框就立刻关掉并重试。
  > 两个实测得来的硬要求：`find` 必须写**绝对路径**（PATH 里若有 Git/MSYS 的 GNU find
  > 会被抢走，把「在跑」误判成「没跑」）；`tasklist` 自己的退出码**不能**用
  > （没有任何进程匹配时它也返回 0）。

**Release 结构**：**一个 Release 同时挂两个端的安装包**（Windows = 安装包 exe，Android = apk），
两条流水线写同一个 `v<版本号>` 标签，各自只覆盖自己的文件。汉化主程序、对照表、补丁明细、
一键脚本一律只留在仓库里，不再重复上传；文件校验值由 GitHub 直接标在资产上，
取消了单独的 `SHA256SUMS.txt`。

**刻意不收录**：`A request to sign the following device...` 看着像界面文案，实际是一条
更长的 Go 模板字面量（后方还接着 `{{.OSName}}<a href=...>`）。按句号截断替换会破坏模板渲染，
补丁器按「无长度立即数」自动 SKIP。

### `pc-v1.104.1`

- 首个 PC 版汉化（47 条界面文案），Inno Setup 向导式安装包，卸载自动还原。

### `v1.104.1-zh` / `v3-fix`

- Android 版汉化相关的历史标签，与 PC 安装包无关。

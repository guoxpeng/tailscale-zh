; =====================================================================
;  Tailscale 中文汉化 —— Inno Setup 安装包脚本
;
;  【一体化模式】编译目录旁若存在官方 tailscale-setup.msi，则一并内嵌：
;    - 目标机未装 Tailscale → 先静默安装官方组件，再替换为汉化版；
;    - 目标机已装 Tailscale → 跳过官方安装，直接替换。
;  官方 MSI 缺失时自动降级成「仅替换」模式（要求目标机已预装官方版）。
;
;  只替换托盘 / 主界面程序 tailscale-ipn.exe，
;  **不触碰** tailscaled 服务、WinTun 驱动与其它任何文件。
;
;  安装: 把官方原版备份为 tailscale-ipn.exe.orig，再写入汉化版
;  卸载: 自动把 .orig 还原回 tailscale-ipn.exe（不卸载官方 Tailscale）
;
;  【安装程序的启动方式】PrivilegesRequired=admin —— Inno 会**自己**弹 UAC 提权，
;  所以请用户**双击**运行即可。不要「右键 → 以管理员身份运行」：
;  Inno 文档写明那样启动时 runasoriginaluser / ExecAsOriginalUser 会失效，
;  安装器将拿不到「登录用户」的凭据，后果是
;    · 托盘 GUI 会被以提权身份拉起（Tailscale 官方不支持 GUI 提权运行）；
;    · 启动方式会退化成「交给 Explorer 转交」兜底（见 LaunchTrayOnce）。
;
;  【本安装器**不会**重启 Explorer】r9 及以前会在「刷新托盘图标」时重启一次 ——
;  那条路径正是 2026-10-11 那次 GUI panic（Shell_NotifyIcon 失败）的肇因，
;  而它想修的「陈旧图标快照」经实测根本不存在。r10 已整段删除，详见 [Code]。
;  这条已经写进 README；改安装器行为时请一并留意。
;
;  编译: ISCC.exe installer\tailscale-zh.iss
;  前置: ..\build\tailscale-ipn.zh.exe   由 tools/build.py 生成（必需）
;        ..\tailscale-setup.msi         官方安装包（可选；有则一体化）
; =====================================================================

#define MyZhName    "Tailscale 中文汉化"
#define MyTsVersion "1.104.1"
; 本汉化包自身的版本**不在这里维护** —— 它就是 Release 标签（pc-v1.104.1-rN）。
; 安装包以 AppVersion = MyTsVersion 登记（对应官方组件版本），
; 免得出现「安装包说自己是 1.2.0、Release 说自己是 r9」两套版本号对不上的情况。
; 唯一被替换的文件（托盘 / 主界面程序）。全脚本只在这里定义一次。
#define ExeName     "tailscale-ipn.exe"
; 随包的官方安装包文件名（若提供）
#define MsiName     "tailscale-setup.msi"
#define MyPublisher "guoxpeng"
#define MyUrl       "https://github.com/guoxpeng/tailscale-zh"
; 官方 MSI 整包 SHA256（= pkgs.tailscale.com 公布的 tailscale-setup-1.104.1-amd64.msi.sha256）。
; 安装器在以管理员身份调用 msiexec 之前再核对一次，与 CI 的下载校验是同一个值。
#define MsiSha256   "6da8bcdb0d45a214cae0e8a88c2987ad48dec134bf04dffb9c05f1354c02b0b4"
; 官方 1.104.1 原版 tailscale-ipn.exe（MSI 内 ClientGUIx64）的 SHA256。
; 卸载 / 还原时用它确认 .orig 备份确实是官方原版，而不是别的东西。
#define OrigSha256  "0c3c56a6626c9f71a32fb307dbda0c810c94a89d66fed158258da6f043004f9c"

; 编译期探测官方 MSI 是否随包提供 —— 决定走「一体化」还是「仅替换」。
; 注意：MSI 本身不入库（.gitignore 排除 *.msi），由构建流程临时下载到仓库根目录。
#ifexist "..\tailscale-setup.msi"
  #define HaveMsi
#endif

[Setup]
AppId={{7C4E2A18-9B3D-4F52-8E61-5A0D3C9B7E24}
AppName={#MyZhName}
AppVersion={#MyTsVersion}
AppVerName={#MyZhName} {#MyTsVersion}
AppPublisher={#MyPublisher}
AppPublisherURL={#MyUrl}
AppSupportURL={#MyUrl}
AppUpdatesURL={#MyUrl}
VersionInfoVersion=1.104.1.0
VersionInfoProductName={#MyZhName}
VersionInfoCompany={#MyPublisher}
VersionInfoDescription={#MyZhName} 安装程序
DefaultDirName={commonpf}\Tailscale
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=Tailscale-zh-{#MyTsVersion}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyZhName} {#MyTsVersion}
UninstallDisplayIcon={app}\{#ExeName}
SetupLogging=yes
; ===== 收尾阶段不能再出岔子：下面三条都跟「点完成关不掉」那次事故有关 =====
;
; 1) DisableFinishedPage=yes —— 不要「完成」页。
;    真实事故 2026-10-11 21:27：装完停在完成页，用户点「完成」毫无反应、
;    还伴随系统提示音，最后是 Windows 在 21:30:18 把它按「应用挂起」关掉的
;    （事件日志 1002）。挂点落在 Inno 自己的收尾流程里（安装脚本这边
;    21:27:52.664 就已经全部做完），脚本侧无从修复；既然「完成」页只是给个
;    确认，那就整个去掉 —— 进度条走完窗口自己关，压根不存在一个「等着被点」
;    的按钮。官方 Windows 版 Tailscale 的 MSI 安装界面也是一装完就关。
;
; 2) RestartIfNeededByRun=no —— 必须的配套。
;    没有完成页就没有「是否重启」的询问页。一旦 Inno 因为 [Run] 留下的待重启
;    文件把 NeedsRestart 置为真，它会**直接重启你的电脑**。本包的 [Run] 只是
;    刷一下图标缓存、拉起托盘，没有任何需要重启的东西。
;
; 3) 刻意**不用** ChangesAssociations=yes。
;    本包不注册任何文件关联，那条指令唯一的作用是让 Inno 在安装结束时调一次
;    SHChangeNotify(SHCNE_ASSOCCHANGED) —— 那是一次**同步广播给整个 shell** 的
;    调用，机器上只要有一个窗口不响应，它就会卡在那里；而它执行的位置恰恰就在
;    上面那个挂死窗口里（见 Inno 源码 Setup.MainForm.pas 里 Install 的尾部）。
;    图标缓存刷新交给 [Run] 的 ie4uinit.exe -show 独家负责，已经够了。
;    （此处曾写着「再加安装包自己的 PurgeStaleTrayIconCache()」—— 那个过程
;      在 r10 已整段删除，注释忘了一起改，2026-10-12 修正。）
DisableFinishedPage=yes
RestartIfNeededByRun=no

[Languages]
; 官方未随安装包分发简中语言包，这里从 issrc 同版本 tag 取来放在同目录，保证编译期确定
Name: "chinese"; MessagesFile: "{#SourcePath}\ChineseSimplified.isl"

[Files]
; 汉化版先以 .new 落地，替换动作放在 [Code] 里做（要先备份原版）
Source: "..\build\tailscale-ipn.zh.exe"; DestDir: "{app}"; DestName: "{#ExeName}.new"; Flags: ignoreversion
#ifdef HaveMsi
; 官方安装包：仅当目标机未安装 Tailscale 时执行（见 [Code] 的 EnsureOfficial）。
; 落到 {tmp}，装完由 DropTempMsi() 立刻删掉，不污染安装目录、不进卸载清单。
; DestName 固定成 {#MsiName}，与 [Code] 里的 MSI_NAME 常量严格一致。
;
; ★ 这里**刻意不用** deleteafterinstall：
;   带那个 flag 时，Inno 是在**安装程序退出时**（也就是用户点「完成」那一瞬）
;   才去删这个文件。而此刻 Windows Installer 服务往往还攥着这个 MSI，
;   删除失败它就永久留在 %TEMP% 里了 —— 实测每次全新安装都会在
;   %TEMP%\is-XXXX.tmp\ 里留下一个 38MB 的 tailscale-setup.msi。
;   更糟的是这段删除正好压在「点完成」那一刻，一旦出岔子，
;   用户看到的就是「完成按钮点不动」。改由 DropTempMsi() 在
;   安装界面还停在进度条上时就删掉（带重试、失败只记日志），
;   退出阶段就不会再有这种大文件要处理。
Source: "..\{#MsiName}"; DestDir: "{tmp}"; DestName: "{#MsiName}"
#endif

[Icons]
; 桌面 + 开始菜单快捷方式。
;
; 官方 Windows 版 Tailscale 只在通知区域放一个图标，不创建任何快捷方式 ——
; 于是 Win11 把新图标默认塞进「隐藏的图标」溢出区之后，用户根本找不到入口
; （这正是「装了但看不见」的一半原因）。本包统一补上桌面图标。
;
; 用 {commondesktop} / {commonprograms}（**所有用户**）而不是 {userdesktop}：
; 本包是 PrivilegesRequired=admin，若用户是通过「另一个管理员账户」提权安装的，
; {userdesktop} 会把快捷方式建到**那个账户**的桌面上，当前用户反而看不到。
;
; 指向 {app}\{#ExeName}（也就是汉化版主程序）。Tailscale 的界面程序是单实例的：
; 已经在跑时双击它不会另开一个窗口，只会把已有的唤到前面，重复点也不会出错。
Name: "{commondesktop}\{#MyZhName}"; Filename: "{app}\{#ExeName}"; \
  WorkingDir: "{app}"; Comment: "启动 Tailscale（中文汉化版）"

; 开始菜单里也放一份「启动 + 卸载」。Windows 应用惯例，顺便留一条
; 「设置 → 应用」打不开时的卸载退路。
Name: "{commonprograms}\{#MyZhName}"; Filename: "{app}\{#ExeName}"; \
  WorkingDir: "{app}"; Comment: "启动 Tailscale（中文汉化版）"
Name: "{commonprograms}\卸载 {#MyZhName}"; Filename: "{uninstallexe}"

; ★ Windows 的「桌面」是**两个物理目录的合并视图**（用户桌面 + 公共桌面）。
;   上面桌面图标用 {commondesktop} 建在公共桌面；用户桌面上若也躺着一个同名
;   lnk（早期手工装过、或用户自己建的），桌面上就会**并排出现两个一样的图标**。
;   所以 [Code] 里配了个 DropUserDesktopShortcut() 顺手清掉用户桌面那份。

[Run]
; 刷新 Windows 图标缓存，让刚创建的快捷方式立刻显示正确图标。
;
; ★ 执行时机 —— 2026-10-12 用 Inno 源码核实过，这里原先写反了：
;   Inno 的顺序是  PerformInstall（装文件 / 建图标）→ ProcessRunEntries（本段）
;   → SetStep(ssPostInstall)（**[Code] 里替换主程序就在这一步**）。
;   也就是说：ie4uinit 跑在「主程序被换成汉化版」**之前**。
;   没有影响，两条原因：
;     · 本包只改 exe 里的字符串资源，图标资源（GROUP_ICON / ICON 两段）
;       两版逐字节相同 —— 替换前后 Explorer 读到的图标一模一样；
;     · 本段真正要刷的是**刚刚新建的快捷方式**，而那些文件在更早的
;       PerformInstall 阶段就已经落盘了。
;   刻意**不**加 postinstall 标记把它挪到 ssPostInstall 之后：r11 的教训是
;   收尾阶段动作越少越好，宁可少刷一次，也不多一次卡死的机会。
;
; ★ 自从 [Setup] 里去掉了 ChangesAssociations（理由见那里），这条 ie4uinit
;   就成了**唯一**的图标缓存刷新入口 —— 所以 skipifdoesntexist 要留着：
;   老系统上可能没有 ie4uinit.exe，那种情况下跳过即可，绝不能报错中断。
; 必须以「登录用户」身份跑 —— 图标缓存是 per-user 的。
; 注意：[Run] 段**没有** ignoreerrors 这个 flag（那是 [Files]/[UninstallRun] 的），
; 写上会直接编译失败 "Parameter \"Flags\" includes an unknown flag"。
; ie4uinit 退出码非 0 不会中断安装 —— [Run] 本来就不检查退出码。
;
; nowait 是必须的：默认 Inno 会**等这个进程结束**才继续（waituntilterminated）。
; ie4uinit.exe 是 shell 的图标缓存刷新工具，在有大量图标/慢盘/被杀软盯着的机器上
; 挂住几十秒并不罕见 —— 一旦它不返回，安装器就一直停在
; 「正在刷新系统图标缓存…」那一步不动（用户视角就是「装到一半卡死」）。
; 这里只是**顺带**刷一下缓存，没有任何后续步骤依赖它跑完，所以发起来就走。
Filename: "{sys}\ie4uinit.exe"; Parameters: "-show"; \
  Flags: runhidden runasoriginaluser skipifdoesntexist nowait

[Code]
const
  EXE_NAME = '{#ExeName}';
  BAK_NAME = '{#ExeName}.orig';
  NEW_NAME = '{#ExeName}.new';
  MSI_NAME = '{#MsiName}';
  { 快捷方式显示名（[Icons] 段建 lnk 用的就是它）——两处必须一致 }
  ZH_NAME  = '{#MyZhName}';
  EXPECT_SIZE = 29622776;
  { 本汉化包自己的注册表落脚点（只用来记「临时隐藏了官方哪条卸载项」） }
  OUR_REG_KEY = 'SOFTWARE\TailscaleZh';
  { 「设置 → 应用」里所有已安装程序的登记处 }
  UNINST_ROOT = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall';

function TsDir(): String;
begin
  Result := ExpandConstant('{commonpf}\Tailscale');
end;

function TsExe(): String;
begin
  Result := TsDir() + '\' + EXE_NAME;
end;

{ 结束正在运行的托盘 / 主界面程序，否则文件被占用。

  为什么「杀一次不够、要连着确认几次」：进程退出（尤其是 /F 强杀）之后，
  它持有的文件句柄不一定立刻释放；而紧接着的 rename 需要独占。
  与其赌一次成功，不如连着确认几轮再往下走。

  （曾经这里写着「tailscaled 服务会把 GUI 拉回来」—— 实测并不成立：
    强杀 GUI 之后连等 12 秒也没有任何新进程。这句话已按实测结论更正，
    免得后人据此推出错误的时序假设。）

  taskkill 返回 128 表示「没找到该进程」，属正常，不必理会。

  返回值 True 表示「调用前它本来就在运行」——
  调用方据此决定装完要不要把它拉回来（见 StartTrayAsUser 的 Force 参数）。 }
function KillTray(): Boolean;
var
  Rc, I: Integer;
begin
  Result := False;

  { 先「温和」请它退出：taskkill 不带 /F 会向窗口发 WM_CLOSE。
    GUI 走正常退出流程时才会调用 Shell_NotifyIcon(NIM_DELETE)，
    把自己在通知区域里的图标注销掉。这一步别省 ——
    强杀（/F）会让 Explorer 侧留下一个「登记着但没人管」的图标，
    之后新拉起的 GUI 再去注册时容易撞上参数校验失败（error 87）。 }
  if Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM ' + EXE_NAME, '',
          SW_HIDE, ewWaitUntilTerminated, Rc) then
    if Rc = 0 then
      Result := True;
  Sleep(1200);

  { 没响应 WM_CLOSE（或压根没在跑）就强杀；连杀 3 次是因为
    tailscaled 服务会在 GUI 消失后又把它拉起来。

    注意：taskkill 的退出码 0 = 「找到了并且结束掉了」，128 = 「没找到」，
    其它非 0 = 找到了但结束失败（例如进程只有隐藏窗口、必须先 /F）。
    这三种情况里只有 128 才代表「本来没在跑」。 }
  for I := 1 to 3 do
  begin
    if Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM ' + EXE_NAME, '',
            SW_HIDE, ewWaitUntilTerminated, Rc) then
      if Rc = 0 then
        Result := True;
    Sleep(600);
  end;
end;

{ ===== 托盘程序：启动 + 体检 + 重试（r10 新增） =====

  这一段取代了 r9 及以前那套「清托盘图标登记项 -> 重启 Explorer ->
  等任务栏就绪 -> 拉 GUI」。那套做法经 2026-10-11 实测被否掉，两个理由都成立，
  所以整段删除：

  (1) 它**没有效果**。Win11 把每个托盘图标登记在
      HKCU\Control Panel\NotifyIconSettings\ 下并缓存一份 IconSnapshot。
      以前把这当成「陈旧缓存」，以为删掉 + 重启 Explorer 就能刷新。
      实测反例：让官方原版 exe 与汉化版各自冷启动、各自重建登记项，
      两边拿到的都是同一张 24x24 PNG，最大 alpha 同为 76。
      也就是说快照不是缓存坏了，而是 Tailscale 运行时画出来的图标本来就长这样
      —— 删掉重建还是同一张。做的是无用功。

  (2) 它**有害**。重启 Explorer 后任务栏要好几秒才重建，而「Shell_TrayWnd
      窗口出现」不等于「通知区域已能接受图标注册」。r9 恰在这个窗口期里把
      GUI 拉起来，它的 populateTray -> Shell_NotifyIconW 直接失败，
      GUI panic 弹框并退出 —— 用户最后连托盘图标都没了，比装之前还糟。

  现在的策略：**完全不碰 Explorer**，只负责把 GUI 拉起来、确认它活着；
  万一它因为上游那个已知的 Shell_NotifyIcon 问题挂了，就自动重试几次。 }

{ 判断托盘程序是否在跑：tasklist 过滤 + find 找进程名。
  find 找到返回 0、找不到返回 1，正好当布尔用。
  （Inno 脚本层没有进程枚举 API，这是最轻量的做法。）

  ⚠ 两处实测得来的硬要求，别改：
    · find 必须写**绝对路径**（脚本里拼 ExpandConstant 的 sys 常量 + \find.exe）。
      只写 'find' 会被 PATH 里别的
      find.exe 抢走 —— 本机实测：Git/MSYS 的 GNU find 排在前面，它对新管道
      直接返回 1，于是「进程明明在跑」被误判成「没跑」，重试逻辑会一直空转。
    · 不能用 tasklist 自己的退出码判断：**没有任何进程匹配时它也返回 0**。 }
function TrayRunning(): Boolean;
var
  Rc: Integer;
  Cmd: String;
begin
  Result := False;
  { tasklist 同样写绝对路径、并把工作目录固定在 System32：cmd 解析不带路径的命令时
    会**先查当前目录**再查 PATH，而提权安装器的当前目录可能是用户的「下载」文件夹 ——
    那里若被放了个 tasklist.bat / tasklist.exe，就会以管理员身份被执行。 }
  Cmd := '/c ' + ExpandConstant('{sys}') + '\tasklist.exe /FI "IMAGENAME eq ' + EXE_NAME + '" /NH | ' +
         ExpandConstant('{sys}') + '\find.exe /i "' + EXE_NAME + '" >nul';
  if Exec(ExpandConstant('{cmd}'), Cmd, ExpandConstant('{sys}'), SW_HIDE, ewWaitUntilTerminated, Rc) then
    Result := (Rc = 0);
end;

{ 托盘 GUI 启动失败时会弹一个标题为「Tailscale 错误」的模态框
  （英文原版是「Tailscale Error」）。两个标题都试 —— 中文标题在本文件里
  就是普通 UTF-8 字面量，ISCC 能正确解码（实测报错信息里能显示出中文码位）。 }
function PanicDialogHandle(): HWND;
begin
  Result := FindWindowByWindowName('Tailscale 错误');
  if Result = 0 then
    Result := FindWindowByWindowName('Tailscale Error');
end;

{ 把那个假报错框关掉，免得用户对着一个看不懂的堆栈发呆。
  （KillTray 第一步的 taskkill 不带 /F，也会给该进程的顶层窗口发 WM_CLOSE，
    两条路都兜一下。） }
procedure DismissTrayPanicDialog();
var
  H: HWND;
begin
  H := PanicDialogHandle();
  if H = 0 then
    Exit;
  Log('关闭托盘程序弹出的报错框（上游已知问题，安装器会自动重试）');
  PostMessage(H, 16, 0, 0);   { WM_CLOSE }
  Sleep(1000);
end;

{ 观察一次启动的结果：先等它起来，再盯 3 秒确认不是「刚起来就崩」。
  期间一旦出现报错框就立刻判负，不必白等到超时。 }
function WaitTraySettled(TimeoutMs: Integer): Boolean;
var
  I, W: Integer;
begin
  Result := False;
  W := 0;
  while W < TimeoutMs do
  begin
    if PanicDialogHandle() <> 0 then
    begin
      Log('第 ' + IntToStr(W) + ' 毫秒就出现报错框，本次启动判负');
      Exit;
    end;
    if TrayRunning() then
      Break;
    Sleep(600);
    W := W + 600;
  end;
  if not TrayRunning() then
  begin
    Log(IntToStr(TimeoutMs) + ' 毫秒内托盘程序没有起来，本次启动判负');
    Exit;
  end;
  for I := 1 to 5 do
  begin
    Sleep(600);
    if PanicDialogHandle() <> 0 then
    begin
      Log('托盘程序起来后又弹出报错框，本次启动判负');
      Exit;
    end;
  end;
  Result := TrayRunning();
end;

{ 用什么身份拉起托盘 GUI，按可靠性排序：
  1) ExecAsOriginalUser —— 首选。用启动安装程序的**登录用户**（未提权）身份跑。
     ⚠ Inno 文档写明：若用户是「右键 -> 以管理员身份运行」启动的（或安装程序
       本身由已提权进程拉起），Inno 拿不到原始用户凭据，这个调用会**没有效果**
       —— 也就是以提权身份把 GUI 拉起来，而 Tailscale 官方不支持 GUI 提权运行。
       所以请**双击**运行本安装包，让它自己弹 UAC。
  2) Explorer 转交（explorer.exe "<exe>"）—— 兜底。Explorer 永不提权，所以这条
     路与安装程序的启动方式无关，拉起来的必定是中等完整性进程。
     一键脚本 install_zh.bat 用的就是这个手法。
  3) Exec —— 最后兜底，可能以提权身份运行。 }
function LaunchTrayOnce(): Boolean;
var
  Rc: Integer;
begin
  Result := True;
  if ExecAsOriginalUser(TsExe(), '', TsDir(), SW_SHOWNORMAL, ewNoWait, Rc) then
    Exit;
  Log('以原始用户身份启动托盘失败（多半是用「以管理员身份运行」启动的），改由 Explorer 转交');
  if Exec(ExpandConstant('{sys}\explorer.exe'), '"' + TsExe() + '"', '',
          SW_SHOWNORMAL, ewNoWait, Rc) then
    Exit;
  Log('Explorer 转交也失败，最后回退为 Exec（可能以提权身份运行）');
  Result := Exec(TsExe(), '', TsDir(), SW_SHOWNORMAL, ewNoWait, Rc);
end;


{ 以「登录用户」身份启动托盘程序（而不是管理员身份）。
  注意：Inno 里没有 ShellExecAsUser 这个脚本函数，正确的是 ExecAsOriginalUser。
  **本函数只能在安装阶段调用** —— ExecAsOriginalUser 在卸载阶段会抛致命错误
  "Cannot call ExecAsOriginalUser function during Uninstall"，
  因此卸载流程不会拉起托盘（原因详见 CurUninstallStepChanged 末尾）。

  Force = True 表示「安装前它本来就在跑」（由 KillTray 的返回值给出）：
  这种时候即使当前是静默安装也必须拉回来 —— 否则用户的任务栏图标会被
  安装程序杀掉之后凭空消失，一直要到下次登录（Tailscale 的开机自启）才恢复。

  Force = False 才是「静默安装就别自作主张弹界面」的原意：
  部署脚本跑到一半突然冒出一个托盘程序，既没人在桌面前确认，
  也容易和后续自动化步骤抢文件。 }
procedure StartTrayAsUser(Force: Boolean);
var
  I: Integer;
begin
  if WizardSilent() and (not Force) then
  begin
    Log('静默安装：按约定跳过自动启动托盘程序');
    Exit;
  end;
  if Force and WizardSilent() then
    Log('静默安装，但安装前托盘程序本来就在运行 —— 把它拉回来');
  if not FileExists(TsExe()) then
    Exit;

  { 拉起 + 体检，最多 3 次。
    单次失败最常见的原因就是上游那个 Shell_NotifyIcon 竞态（通知区域尚未就绪），
    它是**瞬时**的 —— 隔几秒再来一次基本就成。 }
  for I := 1 to 3 do
  begin
    if not LaunchTrayOnce() then
    begin
      Log('托盘程序启动失败（第 ' + IntToStr(I) + ' 次），不再重试');
      Exit;
    end;
    if WaitTraySettled(9000) then
    begin
      Log('托盘程序已启动并确认存活（第 ' + IntToStr(I) + ' 次尝试）');
      Exit;
    end;
    Log('托盘程序第 ' + IntToStr(I) + ' 次启动未成功，清理后重试');
    DismissTrayPanicDialog();
    KillTray();
    if I < 3 then
      Sleep(4000);
  end;
  Log('托盘程序连续 3 次启动失败；已尽力。可手动运行 ' + TsExe());
end;

{ 原子替换主程序：全程只用 rename，绝不出现「半个文件」。

  ===== 这一段是 2026-10-11 那次「安装报错」的根因修复 =====

  【旧实现的致命缺陷】
    旧代码是 DeleteFile(Base) 失败就退化成
        CopyFile(NewExe, Base, False)
    —— 而 CopyFile 的「覆盖」是**先 CreateFile(CREATE_ALWAYS) 把目标截断成
    0 字节，再逐块写入**。29MB 要写零点几秒，这段时间里
    C:\Program Files\Tailscale\tailscale-ipn.exe 是一个残缺文件（甚至 0 字节）。

    偏偏 Windows 版 Tailscale 的 GUI 在启动早期会 fork/exec **一遍自己的路径**
    （tailscale.io/win/ui 里的 populateTray -> newPresenceAwareNotifyIcon ->
    servicelaunch，用于以提权方式拉起 tailscaled 服务）。一旦撞上这个窗口，
    就会直接弹框：
        Unable to set up Tailscale client:
        fork/exec C:\Program Files\Tailscale\tailscale-ipn.exe:
        The specified executable is not a valid application for this OS platform.
    （错误码即 Win32 193 = ERROR_BAD_EXE_FORMAT。）

  【现在的做法】
    两个 rename 都是同卷内的元数据操作，原子且瞬间完成：
        旧文件 --rename--> ExeName + '.old'
        新文件 --rename--> 正式名
        删除 .old
    任意时刻 tailscale-ipn.exe 只可能是三种状态之一：
        完整的旧版 / 完整的新版 / 短暂不存在
    「短暂不存在」时 exec 报的是「系统找不到指定的文件」而不是「格式无效」，
    且窗口只有微秒级。半成品文件则**永远不会**出现。

    只有 rename 真替不动（被独占）才重试；重试前重新 KillTray。 }
function ReplaceExe(const Base, NewExe: String): Boolean;
var
  I: Integer;
  Tmp: String;
begin
  Result := False;
  Tmp := Base + '.old';

  for I := 1 to 8 do
  begin
    KillTray();
    DeleteFile(Tmp);

    if RenameFile(Base, Tmp) then
    begin
      { 旧文件已原子挪走，此刻 Base 不存在 }
      if RenameFile(NewExe, Base) then
      begin
        DeleteFile(Tmp);
        Log('第 ' + IntToStr(I) + ' 次尝试：原子替换成功');
        Result := True;
        Exit;
      end;
      { 放不进去 -> 把旧的挪回来，恢复现场，绝不留下半成品 }
      RenameFile(Tmp, Base);
      Log('第 ' + IntToStr(I) + ' 次尝试：新文件就位失败，已回滚旧文件');
    end
    else if not FileExists(Base) then
    begin
      { 目标本来就不存在（几乎不会发生）：直接把新文件挪进来 }
      if RenameFile(NewExe, Base) then
      begin
        Log('第 ' + IntToStr(I) + ' 次尝试：目标不存在，直接就位成功');
        Result := True;
        Exit;
      end;
      Log('第 ' + IntToStr(I) + ' 次尝试：目标不存在且就位失败');
    end
    else
      Log('第 ' + IntToStr(I) + ' 次尝试：旧文件仍被占用，重试…');

    Sleep(900);
  end;
end;

// 官方组件是否真的就位。
//
// 【为什么不能只看 tailscale-ipn.exe 是否存在】
//  汉化包自己就会往安装目录放 tailscale-ipn.exe；一旦官方组件被单独卸掉
//  （服务与 tailscaled.exe 都没了）而界面程序还留在原地，下一次安装就会
//  被误判成「已装好」而跳过官方安装 —— 于是服务始终缺失，托盘只能显示
//  「The Tailscale service not installed on this machine」并且**无法登录**。
//
//  因此判定标准改为「Windows 服务 + 服务端程序」两者都在。
//  Windows 平台上 Tailscale 的服务名固定为 "Tailscale"
//  （见 tailscale 源码 cmd/tailscaled/tailscaled_windows.go: const serviceName = "Tailscale"）。
function TsServiceInstalled(): Boolean;
begin
  Result := RegKeyExists(HKEY_LOCAL_MACHINE,
                         'SYSTEM\CurrentControlSet\Services\Tailscale')
            and FileExists(TsDir() + '\tailscaled.exe');
end;

// 补写 HKLM\SOFTWARE\Tailscale IPN\GUIPath。
//
// 官方源码 util/winutil/winutil_windows.go 的 GUIPathFromReg() 从这个值读
// 「客户端 GUI 可执行文件路径」，util/osshare/filesharingstatus_windows.go
// 拿它当通知图标用。该值由官方 MSI 在安装时写入；若官方组件曾被单独卸载
// 又重装（或本汉化包在服务缺失时补装过官方组件），它会残留成**空字符串**，
// 那些通知就取不到图标。
//
// 只在「缺失或为空」时补写，不去覆盖 MSI 已经写好的值。
function EnsureGuiPath(): Boolean;
var
  Existing: String;
begin
  Result := False;
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Tailscale IPN',
                         'GUIPath', Existing) and (Existing <> '') then
  begin
    Log('GUIPath 已有有效值，保持不变: ' + Existing);
    Exit;
  end;
  if RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Tailscale IPN',
                         'GUIPath', TsExe()) then
  begin
    Log('已补写 GUIPath = ' + TsExe());
    Result := True;
  end
  else
    Log('警告: 写入 GUIPath 失败（不影响主程序汉化）');
end;

{ ===== 把官方 MSI 的「设置 → 应用」条目藏起来，只留本汉化包一条 =====

  【为什么要做】
  本安装包会在目标机上静默装好官方 Tailscale 组件（见 EnsureOfficial）。
  官方 MSI 会往
      HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ + ProductCode
  登记一条 DisplayName = 'Tailscale' 的卸载项；本汉化包自己又会在同一位置
  登记一条 'Tailscale 中文汉化'。于是「设置 → 应用」里出现**两条 Tailscale**，
  用户不知道该卸哪一个 —— 卸官方的会把汉化文件一起删掉，卸汉化的又要跑一遍
  Explorer 重启。两条并存纯属噪音。

  【做法】
  给官方那条写 SystemComponent = 1。Windows 的「应用和功能」会跳过带这个值的
  条目（它本来是给「系统组件」用的隐藏开关），而条目本身完好地留在注册表里，
  官方 MSI 的卸载 / 修复 / 升级能力一点没少，只是不在列表里露脸。
  具体藏的是哪一条记进我们自己的键，卸载本包时原样恢复。

  【不误伤的保证】
  只认「DisplayName 恰好等于 Tailscale」且「Publisher 含 Tailscale Inc」的条目。
  本汉化包的条目叫 'Tailscale 中文汉化'、发布者是 guoxpeng，两个条件都命中不了。

  【失败也不影响安装】
  写不进去（例如安装程序没拿到管理员权限）只记日志；官方条目继续显示，
  最坏结果只是「又多了一条」，绝不会让安装失败。 }
function HideOfficialUninstallEntry(): Integer;
var
  Names: TArrayOfString;
  Sub, DN, Pub: String;
  I: Integer;
  Cur: Cardinal;
begin
  Result := 0;
  if not RegGetSubkeyNames(HKEY_LOCAL_MACHINE, UNINST_ROOT, Names) then
  begin
    Log('无法枚举 ' + UNINST_ROOT + '，跳过官方卸载条目的隐藏');
    Exit;
  end;
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    Sub := UNINST_ROOT + '\' + Names[I];
    { 逐级嵌套而不是用 and 串起来：Inno Pascal 的 and 不短路，
      串起来会对**每一个**子键都白读一遍 Publisher。 }
    if RegQueryStringValue(HKEY_LOCAL_MACHINE, Sub, 'DisplayName', DN) then
      if DN = 'Tailscale' then
        if RegQueryStringValue(HKEY_LOCAL_MACHINE, Sub, 'Publisher', Pub) then
          if Pos('Tailscale Inc', Pub) > 0 then
          begin
            { 已经是隐藏状态，就不必再写一次 SystemComponent —— 但**归属记录
              仍然要确保写上**。否则万一记录曾在某次卸载时被清掉（或者用户手工
              清了 TailscaleZh 这个键），官方条目就会永远藏在「设置 → 应用」里
              谁也找不回来。补记一次是幂等的，成本可以忽略。 }
            if RegQueryDWordValue(HKEY_LOCAL_MACHINE, Sub,
                                  'SystemComponent', Cur) and (Cur = 1) then
            begin
              RegWriteStringValue(HKEY_LOCAL_MACHINE, OUR_REG_KEY,
                                  'HiddenUninstall', Names[I]);
              Log('官方卸载条目已是隐藏状态，补记归属: ' + Names[I]);
              Exit;
            end;
            if RegWriteDWordValue(HKEY_LOCAL_MACHINE, Sub, 'SystemComponent', 1) then
            begin
              RegWriteStringValue(HKEY_LOCAL_MACHINE, OUR_REG_KEY,
                                  'HiddenUninstall', Names[I]);
              Log('已隐藏官方卸载条目（「设置 → 应用」里不再重复出现）: ' + Names[I]);
              Result := 1;
            end
            else
              Log('隐藏官方卸载条目失败（不影响安装，只是列表里会多一条）: ' + Names[I]);
            Exit;   { 一个产品只会有一条，找到就收工 }
          end;
  end;
  Log('未找到官方 Tailscale 卸载条目（未安装或已被处理过）');
end;

{ 卸载本包时把官方条目恢复显示 —— 卸完以后机器上只剩官方 Tailscale，
  「设置 → 应用」里必须能看见它、而且能正常卸载。 }
procedure RestoreOfficialUninstallEntry();
var
  Name, Sub: String;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, OUR_REG_KEY,
                             'HiddenUninstall', Name) then
  begin
    Log('没有藏着官方卸载条目，无需恢复');
    Exit;
  end;
  Sub := UNINST_ROOT + '\' + Name;
  if RegDeleteValue(HKEY_LOCAL_MACHINE, Sub, 'SystemComponent') then
    Log('已恢复官方卸载条目在「设置 → 应用」中的显示: ' + Name)
  else
    Log('恢复官方卸载条目失败（该产品可能已被单独卸载）: ' + Name);
  RegDeleteValue(HKEY_LOCAL_MACHINE, OUR_REG_KEY, 'HiddenUninstall');
  RegDeleteKeyIfEmpty(HKEY_LOCAL_MACHINE, OUR_REG_KEY);
end;

{ 清掉「用户桌面」上的同名快捷方式 —— 只留 [Icons] 建在公共桌面的那一份。

  Windows 的「桌面」是**两个物理目录的合并视图**：
      用户桌面常量（userdesktop）  —— 用户自己的桌面（本机被重定向到 D 盘）
      公共桌面常量（commondesktop）—— C:\Users\Public\Desktop
  两个目录里的同名文件会**并排显示**成两个图标（系统不做去重）。[Icons] 建的是
  公共桌面那份；早期手工装过汉化、或用户自己拖过一份出来的话，用户桌面上就会
  多出一个同名的，装完会看见两个一模一样的图标。

  userdesktop 常量在提权安装下仍解析成**启动安装程序的那个用户**的桌面，所以这里
  删的正是用户眼前那份；万一解析到了别的管理员账户，删的也是那个账户桌面上的
  同名文件，同样无害。

  删不到（不存在 / 被占用）都无所谓，只是少清理一次，绝不因此中断安装。 }
procedure DropUserDesktopShortcut();
var
  P: String;
begin
  P := ExpandConstant('{userdesktop}') + '\' + ZH_NAME + '.lnk';
  if DeleteFile(P) then
    Log('已清理用户桌面上的重复快捷方式: ' + P);
end;

{ PurgeStaleTrayIconCache / RestartExplorerAsUser / WaitForShellReady 三个
  过程已在 r10 删除 —— 它们既无效又有害，理由见文件前面 TrayRunning 上方
  的大段注释。此处刻意留个空位，免得有人以为是漏删。 }


{ 目标机没装过 Tailscale（或组件残缺）时，用随包的官方 MSI 静默装好完整组件。
  —— 这是「一体化安装」的关键：全新的电脑直接装本包即可，
     不必先手动跑官方安装向导，也就不会遇到官方向导里的英文界面。
      /qn 完全静默；TS_NOLAUNCH=1 让官方安装程序不要把托盘拉起来占用待替换的 exe。
  返回 True 表示官方服务端程序已就位。 }
function EnsureOfficial(): Boolean;
var
  MsiPath: String;
  Rc, I: Integer;
  R: Boolean;
begin
  Result := TsServiceInstalled();
  if Result then
  begin
    Log('检测到 Tailscale 服务与 ' + TsDir() + '\tailscaled.exe，跳过官方组件安装');
    Exit;
  end;

  MsiPath := ExpandConstant('{tmp}') + '\' + MSI_NAME;
  if not FileExists(MsiPath) then
  begin
    Log('目标机 Tailscale 组件不完整，且随包未提供官方 MSI（' + MsiPath + '）');
    Exit;   { 保持 False，由调用方决定如何提示 }
  end;

  { 以管理员身份执行之前，核对随包 MSI 的整包哈希（纵深防御：Inno 6.5+ 提权时
    临时目录已设为普通用户不可写，这里再兜一道，防止被替换成别的 MSI）。 }
  if LowerCase(GetSHA256OfFile(MsiPath)) <> '{#MsiSha256}' then
  begin
    Log('!! 随包官方 MSI 的 SHA256 与预期不符，拒绝执行: ' + MsiPath);
    Exit;   { 保持 False，由调用方提示并中止 }
  end;

  Log('未检测到 Tailscale 服务，开始静默安装官方组件: ' + MsiPath);
  R := Exec(ExpandConstant('{sys}\msiexec.exe'),
            '/i "' + MsiPath + '" /qn /norestart TS_NOLAUNCH=1',
            '', SW_HIDE, ewWaitUntilTerminated, Rc);
  if R then
    Log('msiexec 执行完毕，返回码 ' + IntToStr(Rc))
  else
    Log('msiexec 启动失败');

  { MSI 装完后文件可能还要片刻才落盘。首次安装还要顺带把 WinTun 驱动装上，
    比升级慢得多，所以等待窗口给到 60 秒（以前 30 秒在慢机器/冷启动上不够，
    会被误判成「官方组件没装上」而整包中止）。 }
  for I := 1 to 60 do
  begin
    if TsServiceInstalled() then
      Break;
    Sleep(1000);
  end;

  { 若 MSI 数据库里已经登记过这个产品（例如官方组件曾被卸载掉一部分、只剩登记），
    普通 /i 只会走 maintenance 模式、什么都不修；这里再补一次强制重装。 }
  if not TsServiceInstalled() then
  begin
    Log('首次安装后服务仍未就绪，改为强制重装官方组件');
    R := Exec(ExpandConstant('{sys}\msiexec.exe'),
              '/i "' + MsiPath + '" /qn /norestart REINSTALL=ALL REINSTALLMODE=vomus TS_NOLAUNCH=1',
              '', SW_HIDE, ewWaitUntilTerminated, Rc);
    if R then
      Log('强制重装 msiexec 返回码 ' + IntToStr(Rc))
    else
      Log('强制重装 msiexec 启动失败');
    for I := 1 to 60 do
    begin
      if TsServiceInstalled() then
        Break;
      Sleep(1000);
    end;
  end;

  Result := TsServiceInstalled();
  if not Result then
    Log('官方组件安装后仍未就绪：服务或 ' + TsDir() + '\tailscaled.exe 缺失');
end;

{ 删掉随包内嵌的官方 MSI（如果它被解压出来过）。

  时机是关键：**必须在安装界面还停在进度条上的时候删**，不能交给 Files 段的
  deleteafterinstall —— 那个 flag 是让 Inno 在**安装程序退出时**
  （用户点「完成」之后）才动手删。而那一刻 Windows Installer 服务往往还攥着
  这个 MSI 不放，删除失败它就永久留在 %TEMP% 里了：实测每次全新安装都会在
  %TEMP%\is-XXXX.tmp\ 下留一个 38MB 的 tailscale-setup.msi。

  更要紧的是：那段删除正好压在「点完成」这一瞬 —— 一旦它出岔子，用户看到的
  就是「完成按钮点不动、还叮咚响」。挪到这里删，退出阶段就没有大文件要处理了。

  ★ 注意：这个注释块里**绝不能出现行首的方括号**。Inno 的段扫描器不认块注释，
    只要有哪一行以 [ 开头（哪怕缩进过），整行都会被当成段标签，
    编译期直接报 "Invalid section tag"。文件名与 Files 段里的 DestName
    严格一致（都来自 MSI_NAME 常量）。
  删不掉也不影响安装结果，记一笔日志，交给系统清理 %TEMP%。 }
procedure DropTempMsi();
var
  P: String;
  I: Integer;
begin
  P := ExpandConstant('{tmp}') + '\' + MSI_NAME;
  if not FileExists(P) then
    Exit;
  { msiexec 返回后句柄未必立刻释放，隔一会儿再试，最多 5 次。 }
  for I := 1 to 5 do
  begin
    if DeleteFile(P) then
    begin
      Log('已清理临时官方安装包（第 ' + IntToStr(I) + ' 次尝试）');
      Exit;
    end;
    Sleep(700);
  end;
  Log('临时官方安装包暂时删不掉（多半是 Windows Installer 服务还占着）：' + P);
end;

function InitializeSetup(): Boolean;
var
  Sz: Integer;
begin
  Result := True;
#ifdef HaveMsi
  { 随包内置官方安装包：全新的机器也能一键装成中文版，无需预装官方版 }
  Log('随包内置官方安装包，可直接为未安装 Tailscale 的机器部署');
#else
  { 无内嵌 MSI 的降级版：要求目标机已经装好**完整**的官方组件（含服务） }
  if not TsServiceInstalled() then
  begin
    SuppressibleMsgBox('未检测到完整安装的 Tailscale（服务或 tailscaled.exe 缺失）。' + #13#10 + #13#10 +
           '缺少:' + #13#10 +
           '  · 服务 Tailscale' + #13#10 +
           '  · ' + TsDir() + '\tailscaled.exe' + #13#10 + #13#10 +
           '请先安装官方 Tailscale {#MyTsVersion}（x64），再运行本汉化安装包。',
           mbCriticalError, MB_OK, IDOK);
    Result := False;
  end;
#endif

  { ===== 版本一致性预检：必须发生在**任何文件被改动之前** =====

    汉化补丁依赖 1.104.1 的精确文件偏移，对其它版本的 tailscale-ipn.exe 替换
    必然失败或让程序直接起不来。这个判断要尽可能早做：

      · 放在 CurStepChanged(ssPostInstall) 里做（以前就是这样）有两处不好 ——
        那时文件已经复制了，中止要走 RaiseException，Inno 会**回滚**并弹框；
        而 RaiseException 的错误框在 /SUPPRESSMSGBOXES 下并不会被立刻抑制
        （实测要等约两分钟才自动按掉），企业无人值守部署会被卡住。
      · 放在 InitializeSetup 里，返回 False 就是**干净的静默中止** ——
        什么都没装、什么都没改，也不需要回滚。

    判定条件刻意加了 TsServiceInstalled()：
      - 官方组件已就位 ⇒ 本次装机不会去装官方组件（EnsureOfficial 会直接跳过），
        现存那份界面程序的版本会**原样**留到最后，所以现在就得拦；
      - 官方组件缺失 ⇒ 我们本来就会用随包 MSI 装成 1.104.1，届时不匹配的那个
        残留文件会被盖掉，现在拦反而是误伤。

    注意 CurStepChanged 里那道检查**保留**：它在这里退化成最后一道兜底闸门，
    万一将来加了「不装官方组件」的路径，仍然拦得住。 }
  if TsServiceInstalled() and FileExists(TsExe()) then
  begin
    if not FileSize(TsExe(), Sz) then
      Sz := -1;
    if (Sz > 0) and (Sz <> EXPECT_SIZE) then
    begin
      Log('!! 预检不通过：已安装 ' + EXE_NAME + ' 为 ' + IntToStr(Sz) + ' 字节，与本汉化包对应的官方 ' +
          IntToStr(EXPECT_SIZE) + ' 字节不一致，在改动任何文件之前中止');
      SuppressibleMsgBox('本机已安装的 ' + EXE_NAME + ' 是 ' + IntToStr(Sz) + ' 字节，' + #13#10 +
                '不是本汉化包支持的官方 {#MyTsVersion}（' + IntToStr(EXPECT_SIZE) + ' 字节）。' + #13#10 + #13#10 +
                '汉化补丁按该版本的精确文件偏移生成，对其它版本强行替换会失败，' + #13#10 +
                '或者让 Tailscale 直接无法启动，因此已中止安装（没有改动任何文件）。' + #13#10 + #13#10 +
                '请先在「设置 → 应用」中卸载现有的 Tailscale，' + #13#10 +
                '再运行本安装包（本包自带官方组件，会一并装好）。',
                mbCriticalError, MB_OK, IDOK);
      Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Base, Bak, NewExe: String;
  Sz: Integer;
  TrayWasRunning: Boolean;
begin
  if CurStep = ssDone then
  begin
    { ssDone 是 Inno 收尾的最后一步：此时向导已经隐藏，紧接着就是 TerminateApp。
      打一行日志，出问题时好界定「卡在哪一半」。 }
    Log('安装程序进入 ssDone（收尾）');
    Exit;
  end;

  if CurStep <> ssPostInstall then
    Exit;

  Base   := TsExe();
  Bak    := TsDir() + '\' + BAK_NAME;
  NewExe := TsDir() + '\' + NEW_NAME;

#ifdef HaveMsi
  { 干净机器：先把完整的官方组件静默装好，再打汉化补丁 }
  if not EnsureOfficial() then
  begin
    SuppressibleMsgBox('未能安装 Tailscale 官方组件（服务或 tailscaled.exe 未就位），安装中止。' + #13#10 + #13#10 +
           '请检查网络连接，或先手动安装官方 Tailscale {#MyTsVersion}（x64）后重试。',
           mbCriticalError, MB_OK, IDOK);
    RaiseException('官方组件安装失败');
  end;
#endif

  { 随包内嵌的官方 MSI 已经用完了 —— 趁安装界面还停在进度条上把它删掉。
    绝不能交给 [Files] 的 deleteafterinstall 去在退出阶段处理，理由见
    DropTempMsi 上方的注释。 }
  DropTempMsi();

  { 版本一致性检查（**兜底**）。汉化补丁依赖 1.104.1 的精确文件偏移，只对这个版本有效。

    真正的预检已经前移到 InitializeSetup（那里能在改动任何文件之前干净中止，
    详见那段注释）；这里保留一道，是因为此刻的 tailscale-ipn.exe 才是
    「即将被替换掉的那一份」—— EnsureOfficial 可能刚刚才把它写成 1.104.1。

    以前这里是「弹框让用户选要不要继续」—— 那等于把「必然出问题」包装成一个选项：
    替换后界面程序与服务端版本不匹配，轻则功能异常，重则启动即崩。
    改成**直接中止**，并明确告诉用户该怎么做。 }
  if FileExists(Base) then
  begin
    if not FileSize(Base, Sz) then
      Sz := -1;
    if (Sz > 0) and (Sz <> EXPECT_SIZE) then
    begin
      Log('!! 已安装 ' + EXE_NAME + ' 为 ' + IntToStr(Sz) + ' 字节，与本汉化包对应的官方 ' +
          IntToStr(EXPECT_SIZE) + ' 字节不一致，中止安装');
      SuppressibleMsgBox('本机已安装的 ' + EXE_NAME + ' 是 ' + IntToStr(Sz) + ' 字节，' + #13#10 +
                '不是本汉化包支持的官方 {#MyTsVersion}（' + IntToStr(EXPECT_SIZE) + ' 字节）。' + #13#10 + #13#10 +
                '汉化补丁按该版本的精确文件偏移生成，对其它版本强行替换会失败，' + #13#10 +
                '或者让 Tailscale 直接无法启动，因此已中止安装。' + #13#10 + #13#10 +
                '请先在「设置 → 应用」中卸载现有的 Tailscale，' + #13#10 +
                '再运行本安装包（本包自带官方组件，会一并装好）。',
                mbCriticalError, MB_OK, IDOK);
      RaiseException('已安装的 Tailscale 版本与本汉化包不一致');
    end;
  end;

  { 记下「安装前托盘本来就在跑」—— 装完要按这个决定是否把它拉回来。
    静默安装下这个信息尤其重要：不记录的话，用户的托盘图标会被杀掉之后
    一直缺到下次登录。 }
  TrayWasRunning := KillTray();
  if TrayWasRunning then
    Log('安装前 ' + EXE_NAME + ' 正在运行，装完会重新拉起')
  else
    Log('安装前 ' + EXE_NAME + ' 未在运行');

  { 只备份一次：保留最初那份官方原版，避免二次安装把汉化版当成「原版」备份。

    注意 Base 可能**本来就不存在** —— 服务与 tailscaled.exe 都在、唯独界面程序
    被删掉的残缺安装就是这种状态。此时没有东西可备份，直接往下走交给
    ReplaceExe 就位即可，不能因为「备份失败」把整个安装中止掉。 }
  { 已有的 .orig 若不是官方 1.104.1 原版（损坏 / 来历不明），而当前文件恰好是官方原版，
    就用当前文件重新备份 —— 否则卸载时将无法还原（卸载流程会核对 .orig 的 SHA256）。 }
  if FileExists(Base) and FileExists(Bak) then
    if (LowerCase(GetSHA256OfFile(Bak)) <> '{#OrigSha256}') and
       (LowerCase(GetSHA256OfFile(Base)) = '{#OrigSha256}') then
    begin
      Log('现有备份不是官方原版，改用当前的官方原版重新备份');
      DeleteFile(Bak);
    end;

  if FileExists(Base) and (not FileExists(Bak)) then
  begin
    if not CopyFile(Base, Bak, False) then
    begin
      SuppressibleMsgBox('备份原版 ' + EXE_NAME + ' 失败，安装中止。' + #13#10 +
             '请确认以管理员身份运行安装程序。', mbCriticalError, MB_OK, IDOK);
      RaiseException('备份原版失败');
    end;
    Log('已备份原版 -> ' + Bak);
  end
  else if not FileExists(Base) then
    Log('注意：' + Base + ' 当前不存在（组件残缺），无需备份，将由 ReplaceExe 直接就位');

  if not FileExists(NewExe) then
  begin
    SuppressibleMsgBox('安装载荷缺失（' + NEW_NAME + '），安装中止。', mbCriticalError, MB_OK, IDOK);
    RaiseException('缺少载荷文件');
  end;

  if not ReplaceExe(Base, NewExe) then
  begin
    { 兜底：ReplaceExe 会先删掉原 exe，一旦替换失败，用户机器上就没有主程序了。
      此时把备份还原回去，至少保证 Tailscale 仍可用。 }
    if FileExists(Bak) and RenameFile(Bak, Base) then
      Log('替换失败，已自动还原官方原版 -> ' + Base);
    SuppressibleMsgBox('写入汉化版 tailscale-ipn.exe 失败。' + #13#10 +
           '请手动退出 Tailscale 托盘程序后再试，或以管理员身份运行安装程序。',
           mbCriticalError, MB_OK, IDOK);
    RaiseException('替换失败');
  end;

  { Inno 的 FileSize 是「var 出参 + Boolean 返回」，不是返回值函数。
    这里是**最后一道闸门**：大小不对说明落地的不是完整的汉化版
    （0 字节 / 被截断 / 被别的进程写坏）。绝不能让用户在这种状态下继续 ——
    主程序一旦残缺，Tailscale 连启动都会失败（见 ReplaceExe 的注释）。
    因此校验不过就立刻把官方原版还原回去，至少保证 Tailscale 仍然可用。 }
  if not FileSize(Base, Sz) then
  begin
    Sz := -1;
    Log('警告: 读取 ' + Base + ' 大小失败');
  end;
  if Sz <> EXPECT_SIZE then
  begin
    Log('!! 安装后文件大小异常：' + IntToStr(Sz) + ' 字节，预期 ' +
        IntToStr(EXPECT_SIZE) + ' 字节，回滚官方原版');
    if FileExists(Bak) then
    begin
      DeleteFile(Base);
      if RenameFile(Bak, Base) then
        Log('已还原官方原版 -> ' + Base)
      else
        Log('回滚失败：请手动把 ' + Bak + ' 改名为 ' + Base);
    end;
    SuppressibleMsgBox('汉化版写入后校验未通过（文件大小 ' + IntToStr(Sz) + ' 字节，预期 ' +
           IntToStr(EXPECT_SIZE) + ' 字节）。' + #13#10 + #13#10 +
           '安装程序已自动还原官方原版，Tailscale 仍可正常使用。' + #13#10 +
           '请确认没有其它程序正在占用 Tailscale 后重新运行本安装包。',
           mbCriticalError, MB_OK, IDOK);
    RaiseException('替换后文件校验失败');
  end;
  Log('汉化版已写入 ' + Base + '（' + IntToStr(Sz) + ' 字节）');

  EnsureGuiPath();

  { 汉化已经落地，这时才把官方 MSI 在「设置 → 应用」里的那条藏起来 ——
    让列表里只留本汉化包一条。做失败也只是多显示一条，不影响安装。 }
  HideOfficialUninstallEntry();

  { 桌面快捷方式由 [Icons] 建在公共桌面；用户桌面上若还留着同名的旧 lnk，
    桌面上会并排出现两个一样的图标 —— 顺手清掉，只留一份。 }
  DropUserDesktopShortcut();

  { 托盘图标那一段（清登记项 + 重启 Explorer + 等任务栏）在 r10 已整段移除 ——
    它既无效又有害：想修的「陈旧快照」经实测根本不存在（官方原版 exe 冷启动
    得到的快照与汉化版逐字节相同），而重启 Explorer 造成的任务栏空窗期正是
    GUI panic 的肇因。理由详见文件前面 TrayRunning 上方的大段注释。

    这里只做一件事：把 GUI 拉起来，确认它活着；万一挂了就清理后重试。 }
  StartTrayAsUser(TrayWasRunning);

  { ★ 这是我们最后一行日志，也是排查「点完成关不掉」那类事故的分界线：
    它之后的所有事情都归 Inno 自己管（写 Need to restart Windows? 一行、
    隐藏向导、走 TerminateApp 退出）。下次再出现卡死，看日志有没有这一行，
    就能立刻判断是「我们的活没干完」还是「Inno 的收尾卡住了」。 }
  Log('汉化补丁已全部就位，交还给安装程序收尾');
end;

{ 卸载后把托盘程序拉回来（只在卸载前它本来就在运行时）。

  Windows 版 Tailscale 默认（非无人值守模式）随用户会话 / 托盘程序运行，
  卸载流程为了替换文件必须先结束托盘程序 —— 不拉回来，这台机器就会一直断开，
  直到用户自己从开始菜单重新打开 Tailscale。

  卸载阶段不能用 ExecAsOriginalUser（会抛致命错误），而 Exec 会以提权身份启动 GUI
  （官方不支持）。所以这里只走「Explorer 转交」：explorer.exe 会把启动请求交给
  当前会话里正在运行的那个（未提权的）资源管理器，拉起来的是普通权限进程。 }
procedure RelaunchTrayAfterUninstall();
var
  Rc: Integer;
begin
  if UninstallSilent() then
  begin
    Log('静默卸载：不自动拉起托盘程序');
    Exit;
  end;
  if not FileExists(TsExe()) then
    Exit;
  if Exec(ExpandConstant('{win}\explorer.exe'), '"' + TsExe() + '"', '',
          SW_SHOWNORMAL, ewNoWait, Rc) then
    Log('已通过 Explorer 转交重新启动托盘程序')
  else
    Log('重新启动托盘程序失败，可从开始菜单手动打开 Tailscale');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Base, Bak, Tmp: String;
  Sz: Integer;
  TrayWasRunning: Boolean;
begin
  if CurUninstallStep <> usUninstall then
    Exit;

  Base := TsExe();
  Bak  := TsDir() + '\' + BAK_NAME;

  { 无论后面的还原成不成功，官方卸载条目都必须先恢复显示 ——
    否则用户卸掉汉化包以后，在「设置 → 应用」里根本找不到 Tailscale 了。 }
  RestoreOfficialUninstallEntry();

  if not FileExists(Bak) then
  begin
    Log('未找到备份 ' + Bak + '，跳过还原');
    Exit;
  end;

  { ===== 还原前的版本核对（以前完全没做） =====
    官方的「自动安装更新」或手动装新版 MSI，会把 tailscale-ipn.exe 直接换成**更新的
    官方版本**（汉化随之失效），而 .orig 还停留在 1.104.1。此时若照旧把 .orig 还原
    回去，界面程序就会被**降级**成 1.104.1，与已升级的 tailscaled 服务版本不一致。
    所以：
      1) .orig 必须真的是官方 1.104.1 原版（SHA256 核对）；
      2) 当前的 tailscale-ipn.exe 必须仍是 1.104.1 体系（汉化版与原版同为 EXPECT_SIZE 字节）。
    任一不满足就不动当前文件，只清掉过期 / 来历不明的备份。 }
  if LowerCase(GetSHA256OfFile(Bak)) <> '{#OrigSha256}' then
  begin
    Log('!! 备份 ' + Bak + ' 不是官方 1.104.1 原版（SHA256 不符），不还原，保留当前程序');
    SuppressibleMsgBox('备份文件 ' + Bak + ' 不是官方 {#MyTsVersion} 原版，已跳过还原，' + #13#10 +
           '当前的 ' + EXE_NAME + ' 保持不变。如界面仍是中文，请从官网重新安装 Tailscale。',
           mbError, MB_OK, IDOK);
    Exit;
  end;
  if FileExists(Base) then
  begin
    if not FileSize(Base, Sz) then
      Sz := -1;
    if (Sz > 0) and (Sz <> EXPECT_SIZE) then
    begin
      Log('当前 ' + EXE_NAME + ' 为 ' + IntToStr(Sz) + ' 字节，已不是 {#MyTsVersion}（多半已被官方更新覆盖），' +
          '不用旧备份降级；删除过期备份 ' + Bak);
      DeleteFile(Bak);
      Exit;
    end;
  end;

  TrayWasRunning := KillTray();

  { 与安装流程同一套原则：不「先删后写」，全程 rename，
    保证 tailscale-ipn.exe 任何时刻都不是残缺文件
    （tailscaled 服务随时可能把 GUI 拉起来，见 ReplaceExe 的注释）。 }
  Tmp := TsDir() + '\' + EXE_NAME + '.zh_removed';
  DeleteFile(Tmp);
  if RenameFile(Base, Tmp) then
  begin
    if RenameFile(Bak, Base) then
    begin
      DeleteFile(Tmp);
      Log('已还原官方 ' + EXE_NAME);
    end
    else
    begin
      RenameFile(Tmp, Base);   { 回滚，别把主程序弄丢 }
      SuppressibleMsgBox('还原官方 ' + EXE_NAME + ' 失败。' + #13#10 +
             '请手动把 ' + Bak + ' 改名为 ' + Base + '。', mbError, MB_OK, IDOK);
    end;
  end
  else if not FileExists(Base) then
  begin
    if RenameFile(Bak, Base) then
      Log('已还原官方 ' + EXE_NAME)
    else
      SuppressibleMsgBox('还原官方 ' + EXE_NAME + ' 失败。' + #13#10 +
             '请手动把 ' + Bak + ' 改名为 ' + Base + '。', mbError, MB_OK, IDOK);
  end
  else
    SuppressibleMsgBox(EXE_NAME + ' 仍在运行，无法替换回官方版本。' + #13#10 +
           '请先退出 Tailscale 托盘程序，再手动把 ' + Bak + ' 改名为 ' + Base + '。',
           mbError, MB_OK, IDOK);

  { 卸载前托盘本来在跑，就把它拉回来，否则非无人值守模式下这台机器会一直断开。
    不能用 ExecAsOriginalUser（卸载阶段会抛致命异常），也不能用 UninstallRun 段
    （只支持 runascurrentuser，会以管理员身份拉起 GUI，官方不支持）——
    所以只走 Explorer 转交，见 RelaunchTrayAfterUninstall。 }
  if TrayWasRunning then
    RelaunchTrayAfterUninstall()
  else
    Log('卸载前托盘程序未在运行，不自动拉起');
  Log('汉化已卸下，官方版已还原。');
end;

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
;  编译: ISCC.exe installer\tailscale-zh.iss
;  前置: ..\build\tailscale-ipn.zh.exe   由 tools/build.py 生成（必需）
;        ..\tailscale-setup.msi         官方安装包（可选；有则一体化）
; =====================================================================

#define MyZhName    "Tailscale 中文汉化"
#define MyTsVersion "1.104.1"
#define MyZhVersion "1.2.0"
; 唯一被替换的文件（托盘 / 主界面程序）。全脚本只在这里定义一次。
#define ExeName     "tailscale-ipn.exe"
; 随包的官方安装包文件名（若提供）
#define MsiName     "tailscale-setup.msi"
#define MyPublisher "guoxpeng"
#define MyUrl       "https://github.com/guoxpeng/Tailscale"

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
; 本安装包会**原地替换** tailscale-ipn.exe。Explorer 的图标缓存 / 开始菜单
; 磁贴缓存按「路径」记，文件被换掉后仍会继续显示旧图标甚至通用图标。
; ChangesAssociations=yes 会让 Inno 在安装结束时发一条 SHCNE_ASSOCCHANGED，
; 让 shell 刷新缓存；配合下面的 ie4uinit 一起，装完图标就是新的。
ChangesAssociations=yes

[Languages]
; 官方未随安装包分发简中语言包，这里从 issrc 同版本 tag 取来放在同目录，保证编译期确定
Name: "chinese"; MessagesFile: "{#SourcePath}\ChineseSimplified.isl"

[Files]
; 汉化版先以 .new 落地，替换动作放在 [Code] 里做（要先备份原版）
Source: "..\build\tailscale-ipn.zh.exe"; DestDir: "{app}"; DestName: "{#ExeName}.new"; Flags: ignoreversion
#ifdef HaveMsi
; 官方安装包：仅当目标机未安装 Tailscale 时执行（见 [Code] 的 EnsureOfficial）。
; 落到 {tmp} 并装完即删，不污染安装目录、不进卸载清单。
; DestName 固定成 {#MsiName}，与 [Code] 里的 MSI_NAME 常量严格一致
Source: "..\{#MsiName}"; DestDir: "{tmp}"; DestName: "{#MsiName}"; Flags: deleteafterinstall
#endif

[Run]
; 刷新 Windows 图标缓存。装完本包后 tailscale-ipn.exe 已经是汉化版，
; 但 Explorer 可能还在用旧缓存渲染任务栏/开始菜单/托盘图标，
; 表现为「图标不显示 / 变成白纸图标」。
; 必须以「登录用户」身份跑 —— 图标缓存是 per-user 的。
; 旧系统上可能没有 ie4uinit.exe，用 skipifdoesntexist 跳过而不是报错。
; 注意：[Run] 段**没有** ignoreerrors 这个 flag（那是 [Files]/[UninstallRun] 的），
; 写上会直接编译失败 "Parameter \"Flags\" includes an unknown flag"。
; ie4uinit 退出码非 0 不会中断安装 —— [Run] 本来就不检查退出码。
Filename: "{sys}\ie4uinit.exe"; Parameters: "-show"; \
  Flags: runhidden runasoriginaluser skipifdoesntexist; \
  StatusMsg: "正在刷新系统图标缓存…"

[Code]
const
  EXE_NAME = '{#ExeName}';
  BAK_NAME = '{#ExeName}.orig';
  NEW_NAME = '{#ExeName}.new';
  MSI_NAME = '{#MsiName}';
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

  Tailscale 不只自己会跑 tailscale-ipn.exe —— tailscaled 服务在 GUI 消失后
  还会把它再拉起来（托盘图标需要重新注册时就会）。所以在「准备换文件」这种
  要求文件完整且可独占的时刻，杀一次不够，要连着确认几次再往下走，
  否则紧接着的 rename 会因为文件仍在运行而失败。

  taskkill 返回 128 表示「没找到该进程」，属正常，不必理会。 }
procedure KillTray();
var
  Rc, I: Integer;
begin
  { 先「温和」请它退出：taskkill 不带 /F 会向窗口发 WM_CLOSE。
    GUI 走正常退出流程时才会调用 Shell_NotifyIcon(NIM_DELETE)，
    把自己在通知区域里的图标注销掉。这一步别省 ——
    强杀（/F）会让 Explorer 侧留下一个「登记着但没人管」的图标，
    之后新拉起的 GUI 再去注册时容易撞上参数校验失败（error 87）。 }
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM ' + EXE_NAME, '',
       SW_HIDE, ewWaitUntilTerminated, Rc);
  Sleep(1200);

  { 没响应 WM_CLOSE（或压根没在跑）就强杀；连杀 3 次是因为
    tailscaled 服务会在 GUI 消失后又把它拉起来。 }
  for I := 1 to 3 do
  begin
    Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM ' + EXE_NAME, '',
         SW_HIDE, ewWaitUntilTerminated, Rc);
    Sleep(600);
  end;
end;

{ 以「登录用户」身份启动托盘程序（而不是管理员身份）。
  注意：Inno 里没有 ShellExecAsUser 这个脚本函数，正确的是 ExecAsOriginalUser。
  **本函数只能在安装阶段调用** —— ExecAsOriginalUser 在卸载阶段会抛致命错误
  "Cannot call ExecAsOriginalUser function during Uninstall"，
  因此卸载流程不会拉起托盘（原因详见 CurUninstallStepChanged 末尾）。 }
procedure StartTrayAsUser();
var
  Rc: Integer;
begin
  { 静默安装（/SILENT、/VERYSILENT，企业批量部署的常规用法）时不要把界面弹出来 ——
    部署脚本跑到一半突然冒出一个托盘程序，既没人在桌面前确认，也容易和后续
    自动化步骤抢文件。非静默（用户双击）时才自动启动。 }
  if WizardSilent() then
  begin
    Log('静默安装：按约定跳过自动启动托盘程序');
    Exit;
  end;
  if not FileExists(TsExe()) then
    Exit;
  if ExecAsOriginalUser(TsExe(), '', TsDir(), SW_SHOWNORMAL, ewNoWait, Rc) then
    Exit;
  Log('ExecAsOriginalUser 启动托盘失败，回退为 Exec');
  if not Exec(TsExe(), '', TsDir(), SW_SHOWNORMAL, ewNoWait, Rc) then
    Log('启动 Tailscale 托盘程序失败，请手动运行 ' + TsExe());
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
            { 幂等：已经是隐藏状态就什么都不做 }
            if RegQueryDWordValue(HKEY_LOCAL_MACHINE, Sub,
                                  'SystemComponent', Cur) and (Cur = 1) then
            begin
              Log('官方卸载条目已是隐藏状态，保持不变: ' + Names[I]);
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

// 清理 Windows 11 通知区域里**陈旧**的托盘图标缓存。
//
// 【现象】把汉化版原地覆盖到 tailscale-ipn.exe 之后，任务栏上的 Tailscale 图标
//   会变成一个「几乎看不见的空白方块」，开始菜单 / 任务栏固定项里也可能退化成
//   白纸通用图标（不是九点 logo）。
//
// 【原因】Win11 按**可执行文件路径**把每个托盘图标登记在
//   HKCU\Control Panel\NotifyIconSettings\<ID> 下，并缓存一份 IconSnapshot
//   （PNG，即 EXE 当前的「默认图标」位图）。这份快照只在 Explorer 首次看到
//   该路径的图标时写入，之后**原地替换文件不会刷新它** —— 于是任务栏一直渲染那份旧快照。
//   本机实测：该条目的 IconSnapshot 最大 alpha=76（约 30% 不透明度，白底上几乎不可见），
//   而同键下另外 94 条系统图标全是 255。改用官方原版 exe 启动也一样 → 属残留缓存，
//   不是汉化补丁把图标弄坏了（汉化版与原版的 .rsrc 图标资源逐字节一致）。
//
// 【做法】删掉 ExecutablePath 指向本 exe 的登记项；Explorer 下次启动会重新从
//   exe 提取图标、重新写入一份正确的快照。
//   注意：只删注册表**不会立刻生效** —— Explorer 进程内存里还留着旧图标，
//   所以调用方还要重启一次 Explorer（见 RestartExplorerAsUser）。
//
// 【为什么不误伤干净机器】只有真的删到了条目才返回 >0，调用方才重启 Explorer。
function PurgeStaleTrayIconCache(): Integer;
var
  Root, Sub, Val, Want: String;
  Names: TArrayOfString;
  I: Integer;
begin
  Result := 0;
  Root := 'Control Panel\NotifyIconSettings';
  { 注意不能拿「TsDir() + '\' + EXE_NAME」直接比 —— Explorer 存进
    ExecutablePath 的往往不是 C:\Program Files\... 这种展开形式，而是
    6D809377-... 这类「已知文件夹 GUID」前缀 + \Tailscale\tailscale-ipn.exe，
    字符串相等判断会整个失效。改成看**路径尾部**，两种写法都能命中。
    （写注释时别把那个 GUID 原样套上花括号：Inno 的块注释遇到第一个右花括号
      就结束，后面整段会变成代码。） }
  Want := LowerCase('\Tailscale\' + EXE_NAME);
  if not RegGetSubkeyNames(HKEY_CURRENT_USER, Root, Names) then
  begin
    Log('未找到 HKCU\' + Root + '，跳过托盘图标缓存清理');
    Exit;
  end;
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    Sub := Root + '\' + Names[I];
    { 只动两种条目：
      1) 指向**本安装目录**下的 tailscale-ipn.exe —— 它是原地替换 exe 的受害者；
      2) 文件名同名但该文件**已不存在**的残留（例如曾从别的目录临时跑过一份）。
      别的程序一概不碰。 }
    if RegQueryStringValue(HKEY_CURRENT_USER, Sub, 'ExecutablePath', Val) then
      if (Pos(Want, LowerCase(Val)) > 0) or
         ((Pos(LowerCase(EXE_NAME), LowerCase(Val)) > 0) and (not FileExists(Val))) then
      begin
        if RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, Sub) then
        begin
          Result := Result + 1;
          Log('已清除陈旧的托盘图标登记项: ' + Sub + '  ->  ' + Val);
        end
        else
          Log('清除托盘图标登记项失败（不影响汉化）: ' + Sub);
      end;
  end;
end;

{ 重启 Explorer，让刚清掉的托盘图标登记被重新写入。
  必须以「登录用户」身份跑 —— 托盘图标设置是 per-user 的，
  而以管理员身份重启的 Explorer 会和用户会话脱节。
  taskkill 强杀 + start 重新拉起是标准手法，桌面会短暂重绘一次。
  只有在真的清掉了陈旧条目时才调用，避免打扰干净机器。

  【务必配合 WaitForShellReady 使用】重启之后任务栏要几秒才重建，
  这期间绝不能再拉起 Tailscale（见 WaitForShellReady 的注释）。

  【为什么 taskkill 和 start 之间要插一段 ping】
  命令行里那条 ping 只是拿来当 sleep 用（ping 一定存在，timeout.exe 在无交互
  会话里会直接报错退出）。它的作用是等旧 Explorer **真正退干净**再拉新的：
  Explorer 是单实例进程，上一个还在收尾时启动的这一个会立刻自杀，
  结果就是桌面彻底回不来（只剩壁纸）。实测不加这 2 秒有概率踩到。 }
procedure RestartExplorerAsUser();
var
  Rc, I: Integer;
begin
  if not ExecAsOriginalUser(ExpandConstant('{cmd}'),
       '/c taskkill /f /im explorer.exe >nul 2>nul' +
       ' & ping -n 3 127.0.0.1 >nul' +
       ' & start "" explorer.exe', '',
       SW_HIDE, ewNoWait, Rc) then
  begin
    Log('重启 Explorer 失败；托盘图标可能要到下次登录才会更新');
    Exit;
  end;
  Log('已请求重启 Explorer 以刷新托盘图标');

  { ★★ 这一步是 r8 才补上的关键：先确认**旧**任务栏已经消失，再收工。

     不这么做的话，调用方紧接着的 WaitForShellReady 一开始轮询就会看到
     「Shell_TrayWnd 还在」—— 那其实是**旧的**任务栏，于是它立刻判定
     「已就绪」并返回，接着安装器就拉起 Tailscale；而此时 cmd 才刚把
     taskkill 落到实处，任务栏进入空窗期，Shell_NotifyIconW 返回 error 87，
     GUI 直接 panic 弹框。这正是 r7 修了却仍然会复现的那条路径。
     （ExecAsOriginalUser 是异步启动，函数返回时 taskkill 往往还没跑。）
     这里最多给 10 秒等旧任务栏消失。 }
  for I := 1 to 40 do
  begin
    if FindWindowByClassName('Shell_TrayWnd') = 0 then
    begin
      Log('旧任务栏已消失（等待 ' + IntToStr(I * 250) + ' 毫秒）');
      Exit;
    end;
    Sleep(250);
  end;
  Log('旧任务栏 10 秒内仍未消失，Explorer 可能没有被成功结束');
end;

{ 等任务栏（Shell_TrayWnd）真正重建完成。

  ===== 这一段是 2026-10-11「Shell_NotifyIconW error 87」的根因修复 =====

  【故障现象】装完包弹出一个全是堆栈的错误框：
      Unable to set up Tailscale client:
      walk.NewNotifyIcon: Shell_NotifyIconW(...) failed: error 87
      ... ui.(*app).populateTray ...

  【原因】error 87 = ERROR_INVALID_PARAMETER。Shell_NotifyIconW 内部要先找到
  Shell_TrayWnd（任务栏）才能把图标加进通知区域，找不到时它返回的正是 87。
  而本安装包在上一步刚把 Explorer 杀掉重启 —— 任务栏要几百毫秒到几秒才重建。
  这段空窗期里把 GUI 拉起来，它的 populateTray 必然失败；
  而 Tailscale 对这一步失败的处理是**直接 panic 弹框**（不是记录日志降级），
  于是用户看到一个莫名其妙的报错，托盘也没起来。

  【做法】任何「重启 Explorer 之后要拉托盘」的路径，都必须先过这个函数：
  轮询任务栏窗口，出现后再给 2 秒缓冲（窗口存在 ≠ 通知区域已可用）。

  返回 True 表示确认就绪；False 表示超时（调用方仍可继续，但要记日志）。 }
function WaitForShellReady(TimeoutMs: Integer): Boolean;
var
  Waited: Integer;
begin
  Result := False;
  Waited := 0;
  while Waited < TimeoutMs do
  begin
    if FindWindowByClassName('Shell_TrayWnd') <> 0 then
    begin
      Sleep(2000);
      Log('任务栏已就绪（等待 ' + IntToStr(Waited) + ' 毫秒）');
      Result := True;
      Exit;
    end;
    Sleep(250);
    Waited := Waited + 250;
  end;
  Log('等待任务栏就绪超时（' + IntToStr(TimeoutMs) + ' 毫秒）');
end;

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

function InitializeSetup(): Boolean;
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
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Base, Bak, NewExe: String;
  Sz, N: Integer;
begin
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

  { 版本一致性检查。汉化补丁依赖 1.104.1 的精确文件偏移，只对这个版本有效。

    以前这里是「弹框让用户选要不要继续」—— 那等于把「必然出问题」包装成一个选项：
    替换后界面程序与服务端版本不匹配，轻则功能异常，重则启动即崩。
    现在改成**直接中止**，并明确告诉用户该怎么做。 }
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

  KillTray();

  { 只备份一次：保留最初那份官方原版，避免二次安装把汉化版当成「原版」备份。

    注意 Base 可能**本来就不存在** —— 服务与 tailscaled.exe 都在、唯独界面程序
    被删掉的残缺安装就是这种状态。此时没有东西可备份，直接往下走交给
    ReplaceExe 就位即可，不能因为「备份失败」把整个安装中止掉。 }
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

  { 图标修复：清掉原地替换 exe 后 Explorer 残留的陈旧托盘图标快照。
    必须在替换完成之后做；真的清掉了才重启 Explorer，让它立即生效。 }
  N := PurgeStaleTrayIconCache();
  if N > 0 then
  begin
    Log('共清除 ' + IntToStr(N) + ' 条陈旧托盘图标登记，重启 Explorer 使其立即生效');

    { 重启 Explorer 之前先把 GUI 请下去。Explorer 启动时会给所有顶层窗口广播
      TaskbarCreated，活着的 GUI 收到后会重新 Shell_NotifyIcon(NIM_ADD)；
      要是那一刻新任务栏的通知区域还没就绪，它同样会 error 87 并 panic。
      实测 tailscaled **不会**自动把 GUI 拉回来（连杀 12 秒无新进程），
      所以杀干净之后直到我们主动拉起之前，这段窗口期是安全的。 }
    KillTray();

    RestartExplorerAsUser();
    { ★ 必须等任务栏重建完再拉托盘。
      否则 GUI 的 populateTray -> Shell_NotifyIconW 会失败（error 87）
      并 panic 弹框 —— 这正是 2026-10-11 那次「又报错」的根因。 }
    if not WaitForShellReady(30000) then
    begin
      Log('任务栏长时间未出现，再主动拉起一次 Explorer 后重试');
      RestartExplorerAsUser();
      WaitForShellReady(30000);
    end;
  end
  else
    Log('未发现陈旧托盘图标登记，无需重启 Explorer');

  StartTrayAsUser();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Base, Bak, Tmp: String;
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

  KillTray();

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

  { 这里刻意**不**再拉起托盘程序，原因有两条：
      1) ExecAsOriginalUser 在卸载阶段会抛致命异常
         （Runtime error: Cannot call "ExecAsOriginalUser" function during Uninstall）；
      2) Inno 的 [UninstallRun] 段不支持 runasoriginaluser，只支持 runascurrentuser，
         而卸载器此时已经提权，用它拉起会让 Tailscale GUI 以管理员身份运行
         （Tailscale 官方不支持 GUI 提权运行）。
    托盘由用户从开始菜单重新打开即可，tailscaled 服务与官方程序都不受影响。 }
  Log('汉化已卸下，官方版已还原；托盘程序已退出，可从开始菜单重新打开 Tailscale。');
end;

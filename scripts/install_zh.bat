@echo off
"%SystemRoot%\System32\chcp.com" 936 >nul 2>&1
setlocal
title Tailscale 界面汉化 - 安装 / 还原

rem ============================================================
rem  一键安装 / 还原 Tailscale Windows 界面汉化
rem
rem  安装: 右键本文件 -> 以管理员身份运行（需与本脚本同目录有
rem        tailscale-ipn.zh.exe）
rem  还原: install_zh.bat restore
rem
rem  行为与安装包（installer/tailscale-zh.iss）保持一致：
rem    - 原版只备份一次为 tailscale-ipn.exe.orig，重复安装不会把它覆盖掉
rem    - 【原子替换】绝不出现「半个文件」：先把汉化版复制到安装目录里的
rem      tailscale-ipn.exe.new，再用 move 改名交换（旧 -> .old，新 -> 正式名），
rem      失败立刻把旧的挪回来。直接 copy /Y 覆盖会先把目标截断成 0 字节，
rem      那零点几秒里主程序是残缺 PE —— 而 Tailscale GUI 启动早期会
rem      fork/exec 一遍自己的路径，撞上就报
rem      "is not a valid application for this OS platform"（Win32 193）。
rem    - 改名重试用尽仍失败时自动用备份还原，绝不留下坏掉的主程序
rem    - 用 explorer 转交启动托盘，避免以管理员身份运行 Tailscale GUI
rem    - 【完整性】复制进安装目录后核对汉化版 SHA256；备份 / 还原前核对官方原版 SHA256，
rem      还原前确认当前主程序仍是 1.104.1 体系（官方已自动更新时不拿旧备份降级）
rem    - 系统命令一律写绝对路径（脚本是提权运行的，不让 PATH / 当前目录里的同名程序顶替）
rem ============================================================

rem 取 64 位 Program Files：%ProgramFiles% 在 32 位宿主进程里会被重定向到 (x86)
set "PF=%ProgramW6432%"
if not defined PF set "PF=%ProgramFiles%"

set "SRC=%~dp0tailscale-ipn.zh.exe"
set "DEST_DIR=%PF%\Tailscale"
set "DST=%DEST_DIR%\tailscale-ipn.exe"
set "BAK=%DEST_DIR%\tailscale-ipn.exe.orig"
set "OLDBAK=%DEST_DIR%\tailscale-ipn.exe.orig.bak"
set "NEW=%DEST_DIR%\tailscale-ipn.exe.new"
set "OLD=%DEST_DIR%\tailscale-ipn.exe.old"

set "SYS=%SystemRoot%\System32"
rem 汉化版 tailscale-ipn.zh.exe 的 SHA256（= prebuilt/SHA256SUMS.txt 里那一条；
rem tools/prebuilt_check.py 会在 CI 里核对两者一致，换汉化版时记得同步这里）
set "ZH_SHA=a5cf6c0c319c579a08137947b3e3f6a80e74ec1e1ba00ae519ac3ff21846b125"
rem 官方 1.104.1 原版 tailscale-ipn.exe 的 SHA256
set "ORIG_SHA=0c3c56a6626c9f71a32fb307dbda0c810c94a89d66fed158258da6f043004f9c"

"%SYS%\net.exe" session >nul 2>&1
if %errorlevel% neq 0 (
  echo [!] 需要管理员权限：请右键本文件 -^> "以管理员身份运行"
  pause & exit /b 1
)

if /i "%~1"=="restore" goto RESTORE

if not exist "%DST%" (
  echo [!] 未找到已安装的 Tailscale: %DST%
  echo     本脚本只替换界面程序，请先装好官方 Tailscale 1.104.1（x64）。
  pause & exit /b 1
)
if not exist "%SRC%" (
  echo [!] 未找到汉化文件: %SRC%
  echo     请把 tailscale-ipn.zh.exe 与本脚本放在同一目录。
  pause & exit /b 1
)

rem ===== 版本预检：与安装包同样的道理 =====
rem 汉化补丁按官方 1.104.1 的**精确文件偏移**生成，对别的版本强行替换
rem 必然失败、或者让 Tailscale 直接起不来。安装包里有这道闸门，脚本也补上。
for %%A in ("%DST%") do set "DSIZE=%%~zA"
if not "%DSIZE%"=="29622776" (
  echo [!] 本机的 tailscale-ipn.exe 是 %DSIZE% 字节，不是本汉化包支持的
  echo     官方 1.104.1（29622776 字节）。强行替换会失败或让程序无法启动。
  echo     请先卸载现有 Tailscale，装好官方 1.104.1 后再运行本脚本。
  pause & exit /b 1
)

echo [1/5] 备份官方原版 -^> tailscale-ipn.exe.orig
if exist "%BAK%" goto BAK_EXISTS
rem 只有当前主程序确实是官方原版时才备份，免得把汉化版或别的文件当成「原版」存下来
call :SHA256 "%DST%" DSHA
if /i not "%DSHA%"=="%ORIG_SHA%" (
  echo [!] 当前的 tailscale-ipn.exe 不是官方 1.104.1 原版（SHA256 不符），又没有 .orig 备份，
  echo     无法安全备份，已中止（未改动任何文件）。请重装官方 Tailscale 1.104.1 后再运行。
  pause & exit /b 1
)
copy /Y "%DST%" "%BAK%" >nul
if errorlevel 1 (
  echo [!] 备份原版失败，已中止（未改动任何文件）
  pause & exit /b 1
)
goto BAK_OK

:BAK_EXISTS
call :SHA256 "%BAK%" BSHA
if /i not "%BSHA%"=="%ORIG_SHA%" (
  echo [!] 已有的 tailscale-ipn.exe.orig 不是官方 1.104.1 原版（SHA256 不符），
  echo     继续安装将来会无法还原，已中止（未改动任何文件）。
  pause & exit /b 1
)
echo      已存在备份，保留最初那份（不覆盖）

:BAK_OK
echo [2/5] 把汉化版复制到安装目录（与目标同卷，供原子改名用）
set "NEWOK="
set "CTRY=0"

:COPY
set /a CTRY+=1
copy /Y "%SRC%" "%NEW%" >nul 2>&1
if not errorlevel 1 set "NEWOK=1"
if defined NEWOK goto COPY_OK
if %CTRY% geq 5 goto COPY_FAIL
echo      第 %CTRY% 次复制失败，重试 ...
"%SYS%\PING.EXE" -n 3 127.0.0.1 >nul
goto COPY

:COPY_FAIL
echo [!] 复制汉化版到安装目录失败，已中止（未改动任何文件）
pause & exit /b 1

:COPY_OK
rem 在管理员才能写的安装目录里核对哈希：源文件放在「下载」这类用户可写目录，
rem 复制前后都可能被换掉，只有落地后的这份才可信
call :SHA256 "%NEW%" NSHA
if /i not "%NSHA%"=="%ZH_SHA%" (
  del /F /Q "%NEW%" >nul 2>&1
  echo [!] tailscale-ipn.zh.exe 的 SHA256 与本脚本预期不符（文件不完整或不是本仓库发布的版本），已中止。
  echo     预期 %ZH_SHA%
  echo     实际 %NSHA%
  pause & exit /b 1
)
echo [3/5] 关闭 Tailscale 托盘程序
"%SYS%\taskkill.exe" /IM tailscale-ipn.exe >nul 2>&1
"%SYS%\PING.EXE" -n 2 127.0.0.1 >nul
"%SYS%\taskkill.exe" /IM tailscale-ipn.exe /F >nul 2>&1
"%SYS%\PING.EXE" -n 2 127.0.0.1 >nul

echo [4/5] 原子替换主程序
set "TRY=0"

:SWAP
set /a TRY+=1
if exist "%OLD%" del /F /Q "%OLD%" >nul 2>&1
move /Y "%DST%" "%OLD%" >nul 2>&1
if errorlevel 1 goto SWAP_BUSY
move /Y "%NEW%" "%DST%" >nul 2>&1
if errorlevel 1 goto SWAP_ROLLBACK
if exist "%OLD%" del /F /Q "%OLD%" >nul 2>&1
echo      第 %TRY% 次尝试：替换成功
goto SWAP_OK

:SWAP_ROLLBACK
rem 新文件放不进去：立刻把旧的挪回来，恢复现场，绝不留下空档
move /Y "%OLD%" "%DST%" >nul 2>&1
echo      第 %TRY% 次尝试：就位失败，已回滚旧文件
goto SWAP_RETRY

:SWAP_BUSY
echo      第 %TRY% 次尝试：主程序仍被占用

:SWAP_RETRY
if %TRY% geq 5 goto SWAP_FAIL
"%SYS%\taskkill.exe" /IM tailscale-ipn.exe /F >nul 2>&1
"%SYS%\PING.EXE" -n 3 127.0.0.1 >nul
goto SWAP

:SWAP_FAIL
echo [!] 替换失败（进程一直占着文件）。
del /F /Q "%NEW%" >nul 2>&1
rem 每次失败都已把旧文件挪回原位，主程序本来就在；只有它真的不见了才用备份补回。
rem （不要无条件 copy /Y 覆盖 —— 那会把目标先截断成 0 字节，正是上面要避免的半成品窗口）
if not exist "%DST%" if exist "%OLD%" move /Y "%OLD%" "%DST%" >nul 2>&1
if not exist "%DST%" copy /Y "%BAK%" "%DST%" >nul 2>&1
echo      请先手动退出 Tailscale 托盘程序，再以管理员身份重跑本脚本。
pause & exit /b 1

:SWAP_OK
echo [5/5] 重新启动 Tailscale
rem 用 explorer 转交启动：本脚本是提权运行的，直接 start 会让 Tailscale GUI
rem 以管理员身份运行（官方不支持这种用法）；交给已在用户会话中的 explorer
rem 处理，可让它以当前登录用户身份启动。
"%SystemRoot%\explorer.exe" "%DST%"

echo.
echo  完成！点击托盘里的 Tailscale 图标即可看到中文界面。
echo  （托盘图标是 Tailscale 运行时自己画的半透明小圆点，在浅色任务栏下看
echo    起来偏淡 —— 那是图标本来的样子，与汉化无关，不要去重启 explorer.exe。）
echo  （本脚本只替换主程序，不创建快捷方式；要桌面图标请用安装包。）
echo  还原官方英文版:  install_zh.bat restore
echo.
pause
exit /b 0

:RESTORE
rem 还原分支不要求主程序当前存在 —— 目标就是把它放回去
set "RESTORE_SRC=%BAK%"
if not exist "%RESTORE_SRC%" set "RESTORE_SRC=%OLDBAK%"
if not exist "%RESTORE_SRC%" (
  echo [!] 未找到备份（既没有 tailscale-ipn.exe.orig 也没有 tailscale-ipn.exe.orig.bak）
  pause & exit /b 1
)

rem 备份必须是官方 1.104.1 原版
call :SHA256 "%RESTORE_SRC%" RSHA
if /i not "%RSHA%"=="%ORIG_SHA%" (
  echo [!] 备份 %RESTORE_SRC% 不是官方 1.104.1 原版（SHA256 不符），不还原。
  echo     请到 Tailscale 官网重新安装官方版。
  pause & exit /b 1
)
rem 当前主程序若已不是 1.104.1 体系（例如官方「自动安装更新」已经把它换成了新版），
rem 再拿 1.104.1 的旧备份覆盖就是降级，会与已升级的 tailscaled 服务版本不一致
if exist "%DST%" (
  for %%A in ("%DST%") do set "RSIZE=%%~zA"
) else (
  set "RSIZE=29622776"
)
if not "%RSIZE%"=="29622776" (
  echo [!] 当前 tailscale-ipn.exe 是 %RSIZE% 字节，已不是 1.104.1（多半已被官方更新覆盖，本身就是官方版），
  echo     无需还原；为避免降级，不做任何改动。旧备份可以手动删除。
  pause & exit /b 1
)

echo 正在还原官方原版 ...
"%SYS%\taskkill.exe" /IM tailscale-ipn.exe >nul 2>&1
"%SYS%\PING.EXE" -n 2 127.0.0.1 >nul
"%SYS%\taskkill.exe" /IM tailscale-ipn.exe /F >nul 2>&1
"%SYS%\PING.EXE" -n 2 127.0.0.1 >nul

rem 同样走原子替换：先把备份复制成同目录的 .new，再改名交换
set "NEWOK="
set "CTRY=0"

:RCOPY
set /a CTRY+=1
copy /Y "%RESTORE_SRC%" "%NEW%" >nul 2>&1
if not errorlevel 1 set "NEWOK=1"
if defined NEWOK goto RCOPY_OK
if %CTRY% geq 5 goto RCOPY_FAIL
echo      第 %CTRY% 次复制失败，重试 ...
"%SYS%\PING.EXE" -n 3 127.0.0.1 >nul
goto RCOPY

:RCOPY_FAIL
echo [!] 复制官方原版失败，已中止（未改动任何文件）
pause & exit /b 1

:RCOPY_OK
set "TRY=0"

:RSWAP
set /a TRY+=1
if exist "%OLD%" del /F /Q "%OLD%" >nul 2>&1
move /Y "%DST%" "%OLD%" >nul 2>&1
if errorlevel 1 goto RSWAP_BUSY
move /Y "%NEW%" "%DST%" >nul 2>&1
if errorlevel 1 goto RSWAP_ROLLBACK
if exist "%OLD%" del /F /Q "%OLD%" >nul 2>&1
echo      第 %TRY% 次尝试：还原成功
goto RSWAP_OK

:RSWAP_ROLLBACK
move /Y "%OLD%" "%DST%" >nul 2>&1
echo      第 %TRY% 次尝试：就位失败，已回滚
goto RSWAP_RETRY

:RSWAP_BUSY
echo      第 %TRY% 次尝试：主程序仍被占用

:RSWAP_RETRY
if %TRY% geq 5 goto RSWAP_FAIL
"%SYS%\taskkill.exe" /IM tailscale-ipn.exe /F >nul 2>&1
"%SYS%\PING.EXE" -n 3 127.0.0.1 >nul
goto RSWAP

:RSWAP_FAIL
echo [!] 还原失败（进程一直占着文件）。请先手动退出 Tailscale 托盘程序后重试。
del /F /Q "%NEW%" >nul 2>&1
pause & exit /b 1

:RSWAP_OK
rem 还原成功后备份就没用了（与安装包的卸载逻辑一致）
del /F /Q "%BAK%" >nul 2>&1
del /F /Q "%OLDBAK%" >nul 2>&1
"%SystemRoot%\explorer.exe" "%DST%"
echo 已还原。
pause
exit /b 0

rem ---------- 子程序：call :SHA256 "文件" 变量名 ----------
rem certutil 输出第 2 行是哈希（老系统里字节之间带空格，统一去掉）
:SHA256
set "%~2="
for /f "skip=1 delims=" %%H in ('%SYS%\certutil.exe -hashfile "%~1" SHA256 2^>nul') do if not defined %~2 set "%~2=%%H"
if defined %~2 call set "%~2=%%%~2: =%%"
exit /b 0

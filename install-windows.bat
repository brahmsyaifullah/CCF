@echo off
REM ============================================================================
REM  CCF - Claude Code Fusion - Windows one-click installer
REM  Double-click this file (or run it from cmd) to install CCF + all
REM  requirements (Git Bash, jq, curl, tar, Python) automatically.
REM ============================================================================
setlocal
echo.
echo  ==========================================================
echo    CCF - Claude Code Fusion - Windows installer
echo  ==========================================================
echo.
echo  This will check for and install: Git for Windows, jq, Python.
echo  A User Account Control (UAC) prompt may appear - that is normal.
echo.
pause

REM Run the PowerShell bootstrap with execution policy bypassed for this process only.
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex"

echo.
echo  ----------------------------------------------------------
echo  If you saw errors above, open docs\WINDOWS.md for help.
echo  After install: restart Claude Code, then run /fusion-status
echo  ----------------------------------------------------------
echo.
pause
endlocal

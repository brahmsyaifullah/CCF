<#
  CCF — Claude Code Fusion installer for Windows (native PowerShell).

  CCF's runtime (the fusion-call dispatcher + hooks) is POSIX shell, so on Windows it needs a
  bash: Git for Windows (Git Bash) for a NATIVE install, or WSL if you run Claude Code inside WSL.
  This script locates a bash, translates the target path, and delegates to the tested install.sh.

  Usage:
    irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex
    # or, from a checkout:
    powershell -ExecutionPolicy Bypass -File .\install.ps1

  Optional env:
    $env:CLAUDE_HOME   override target (default: $env:USERPROFILE\.claude)
    $env:CCF_BRANCH    branch to install (default: main)
#>
[CmdletBinding()]
param(
  [switch]$NoHooks,
  [switch]$NoUpdateHook,
  [switch]$Wsl   # force using WSL bash instead of Git Bash
)
$ErrorActionPreference = 'Stop'
$RepoSlug = 'brahmsyaifullah/CCF'
$Branch   = if ($env:CCF_BRANCH) { $env:CCF_BRANCH } else { 'main' }
$ClaudeDir = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE '.claude' }

function Find-GitBash {
  $cands = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
  )
  foreach ($c in $cands) { if (Test-Path $c) { return $c } }
  $w = Get-Command bash.exe -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*\System32\bash.exe' }
  if ($w) { return $w.Source }
  return $null
}

function To-GitBashPath([string]$p) {
  # C:\Users\X\.claude -> /c/Users/X/.claude
  $full = [System.IO.Path]::GetFullPath($p)
  $drive = $full.Substring(0,1).ToLower()
  $rest  = $full.Substring(2) -replace '\\','/'
  return "/$drive$rest"
}
function To-WslPath([string]$p) {
  $full = [System.IO.Path]::GetFullPath($p)
  $drive = $full.Substring(0,1).ToLower()
  $rest  = $full.Substring(2) -replace '\\','/'
  return "/mnt/$drive$rest"
}

Write-Host '== CCF — Claude Code Fusion installer (Windows) =='

# 1. resolve bash
$useWsl = $false
$bash = $null
if ($Wsl) {
  $bash = (Get-Command wsl.exe -ErrorAction SilentlyContinue).Source
  if (-not $bash) { throw 'WSL requested but wsl.exe not found.' }
  $useWsl = $true
} else {
  $bash = Find-GitBash
  if (-not $bash) {
    $bash = (Get-Command wsl.exe -ErrorAction SilentlyContinue).Source
    if ($bash) { $useWsl = $true }
  }
}
if (-not $bash) {
  throw @"
No bash found. CCF needs a POSIX shell to run.
  - Native Windows: install Git for Windows  ->  https://git-scm.com/download/win
  - Or run Claude Code inside WSL and re-run this with -Wsl
Then re-run this installer.
"@
}
Write-Host "  bash: $bash$(if($useWsl){' (WSL)'}else{' (Git Bash)'})"

# 2. obtain a checkout (use local if present, else download)
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (Test-Path (Join-Path $scriptDir 'install.sh')) {
  $src = $scriptDir
  Write-Host "  source: local checkout ($src)"
} else {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ccf-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $tgz = Join-Path $tmp 'ccf.tgz'
  Write-Host "  source: downloading $RepoSlug@$Branch ..."
  Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$RepoSlug/tar.gz/refs/heads/$Branch" -OutFile $tgz
  tar.exe -xzf $tgz -C $tmp
  $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
  if (-not (Test-Path (Join-Path $src 'install.sh'))) { throw 'downloaded archive missing install.sh' }
}

# 3. translate paths + build the install.sh invocation
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
if ($useWsl) {
  $srcPosix = To-WslPath $src
  $dirPosix = To-WslPath $ClaudeDir
} else {
  $srcPosix = To-GitBashPath $src
  $dirPosix = To-GitBashPath $ClaudeDir
}
$flags = "--dir '$dirPosix'"
if ($NoHooks)      { $flags += ' --no-hooks' }
if ($NoUpdateHook) { $flags += ' --no-update-hook' }
$cmd = "cd '$srcPosix' && bash ./install.sh $flags"

Write-Host "  running: $cmd"
if ($useWsl) {
  & $bash -e bash -lc $cmd
} else {
  & $bash -lc $cmd
}
if ($LASTEXITCODE -ne 0) { throw "install.sh failed (exit $LASTEXITCODE)" }

Write-Host ''
Write-Host "== Done. CCF installed to $ClaudeDir =="
Write-Host "Next: add keys to $ClaudeDir\fusion\secrets.env, restart Claude Code, then /fusion-status."

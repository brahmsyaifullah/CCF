<#
  CCF — Claude Code Fusion · Windows one-step bootstrap installer.

  Checks every requirement (Git Bash, jq, curl, tar, Python 3), installs whatever is missing
  (winget, with a Chocolatey fallback), refreshes PATH in-session, then installs CCF and offers
  the setup wizard. Designed so a brand-new Windows machine goes from zero to working with one line.

    irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex
    # or from a checkout:
    powershell -ExecutionPolicy Bypass -File .\install.ps1

  Flags:
    -Yes            install missing requirements without prompting
    -SkipOnboard    don't launch the setup wizard at the end
    -NoHooks        skip CCF hook wiring
    -NoUpdateHook   skip the update-notifier hook
    -Wsl            use WSL bash instead of Git Bash

  Env:
    $env:CLAUDE_HOME   target dir (default: %USERPROFILE%\.claude)
    $env:CCF_BRANCH    branch (default: main)
#>
[CmdletBinding()]
param(
  [switch]$Yes,
  [switch]$SkipOnboard,
  [switch]$NoHooks,
  [switch]$NoUpdateHook,
  [switch]$Wsl
)
$ErrorActionPreference = 'Stop'
$RepoSlug  = 'brahmsyaifullah/CCF'
$Branch    = if ($env:CCF_BRANCH) { $env:CCF_BRANCH } else { 'main' }
$ClaudeDir = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE '.claude' }

function Info($m){ Write-Host "  $m" }
function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!] $m" -ForegroundColor Yellow }
function Step($m){ Write-Host "`n== $m ==" -ForegroundColor Cyan }
function Have($name){ [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# Re-import PATH from the registry so tools installed this session are visible immediately.
function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path','User')
  $env:Path = (@($machine,$user) | Where-Object { $_ } ) -join ';'
}

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

function To-GitBashPath([string]$p){ $f=[IO.Path]::GetFullPath($p); "/$($f.Substring(0,1).ToLower())$(( $f.Substring(2) -replace '\\','/'))" }
function To-WslPath([string]$p){ $f=[IO.Path]::GetFullPath($p); "/mnt/$($f.Substring(0,1).ToLower())$(( $f.Substring(2) -replace '\\','/'))" }

Write-Host ''
Write-Host '==================================================' -ForegroundColor Magenta
Write-Host '  CCF — Claude Code Fusion · Windows installer' -ForegroundColor Magenta
Write-Host '==================================================' -ForegroundColor Magenta

# ---------------------------------------------------------------------------
# 1. Package manager
# ---------------------------------------------------------------------------
Step 'Checking package manager'
$pm = $null
if (Have 'winget') { $pm = 'winget'; Ok 'winget found' }
elseif (Have 'choco') { $pm = 'choco'; Ok 'Chocolatey found' }
else {
  Warn 'No winget or Chocolatey found.'
  Info 'winget ships with Windows 10 1809+/11 as "App Installer" (Microsoft Store).'
  Info 'Install it from the Store, or install Chocolatey: https://chocolatey.org/install'
  Info 'Then re-run this installer. (You can also install the tools below manually.)'
}

function Install-Pkg($label, $wingetId, $chocoId, $checkCmd) {
  if ($checkCmd -and (Have $checkCmd)) { Ok "$label already installed"; return $true }
  if (-not $pm) { Warn "$label missing and no package manager to install it."; return $false }
  if (-not $Yes) {
    $a = Read-Host "  Install $label now? [Y/n]"
    if ($a -and $a -notmatch '^[Yy]') { Warn "skipped $label"; return $false }
  }
  Info "installing $label via $pm ..."
  try {
    if ($pm -eq 'winget') {
      winget install --silent --accept-source-agreements --accept-package-agreements --id $wingetId | Out-Null
    } else {
      choco install -y $chocoId | Out-Null
    }
  } catch { Warn "install of $label reported an error (continuing): $($_.Exception.Message)" }
  Update-SessionPath
  if ($checkCmd -and (Have $checkCmd)) { Ok "$label installed" ; return $true }
  # Git Bash isn't on PATH as a command; verify by file presence.
  if ($label -eq 'Git for Windows' -and (Find-GitBash)) { Ok 'Git Bash installed'; return $true }
  Warn "$label may need a new terminal to appear on PATH."
  return $false
}

# ---------------------------------------------------------------------------
# 2. Requirements
# ---------------------------------------------------------------------------
Step 'Checking requirements'
Update-SessionPath

$useWsl = $false
if ($Wsl) {
  if (-not (Have 'wsl')) { throw 'WSL requested but wsl.exe not found.' }
  $useWsl = $true
  Ok 'WSL mode (bash + tools resolved inside WSL)'
} else {
  # Git for Windows → provides bash + curl. Required for the runtime dispatcher.
  Install-Pkg 'Git for Windows' 'Git.Git' 'git' $null | Out-Null
  # jq → required by the dispatcher.
  Install-Pkg 'jq'              'jqlang.jq' 'jq' 'jq' | Out-Null
  # Python 3 → required for the cross-platform onboarding wizard.
  Install-Pkg 'Python 3'        'Python.Python.3.12' 'python' 'python' | Out-Null
  # curl + tar ship with Windows 10+; just report.
  if (Have 'curl') { Ok 'curl found' } else { Warn 'curl missing (unusual on Win10+)' }
  if (Have 'tar')  { Ok 'tar found'  } else { Warn 'tar missing (unusual on Win10+)' }
}

# ---------------------------------------------------------------------------
# 3. Resolve bash
# ---------------------------------------------------------------------------
Step 'Resolving shell'
$bash = $null
if ($useWsl) {
  $bash = (Get-Command wsl.exe).Source
} else {
  $bash = Find-GitBash
  if (-not $bash) {
    $bash = (Get-Command wsl.exe -ErrorAction SilentlyContinue).Source
    if ($bash) { $useWsl = $true; Warn 'Git Bash not found — falling back to WSL.' }
  }
}
if (-not $bash) {
  throw @"
No bash available. CCF's runtime needs a POSIX shell.
  - Install Git for Windows: https://git-scm.com/download/win  (then re-run this)
  - Or run inside WSL and re-run with -Wsl
"@
}
Ok "bash: $bash$(if($useWsl){' (WSL)'}else{' (Git Bash)'})"

# ---------------------------------------------------------------------------
# 4. Get a checkout
# ---------------------------------------------------------------------------
Step 'Fetching CCF'
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (Test-Path (Join-Path $scriptDir 'install.sh')) {
  $src = $scriptDir; Ok "using local checkout: $src"
} else {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ccf-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $tgz = Join-Path $tmp 'ccf.tgz'
  Info "downloading $RepoSlug@$Branch ..."
  Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$RepoSlug/tar.gz/refs/heads/$Branch" -OutFile $tgz
  tar.exe -xzf $tgz -C $tmp
  $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
  if (-not (Test-Path (Join-Path $src 'install.sh'))) { throw 'downloaded archive missing install.sh' }
  Ok "downloaded to: $src"
}

# ---------------------------------------------------------------------------
# 5. Run the install
# ---------------------------------------------------------------------------
Step 'Installing CCF'
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
if ($useWsl) { $srcPosix = To-WslPath $src; $dirPosix = To-WslPath $ClaudeDir }
else         { $srcPosix = To-GitBashPath $src; $dirPosix = To-GitBashPath $ClaudeDir }
$flags = "--dir '$dirPosix'"
if ($NoHooks)      { $flags += ' --no-hooks' }
if ($NoUpdateHook) { $flags += ' --no-update-hook' }
$cmd = "cd '$srcPosix' && bash ./install.sh $flags </dev/null"
Info "running: bash ./install.sh $flags"
if ($useWsl) { & $bash -e bash -lc $cmd } else { & $bash -lc $cmd }
if ($LASTEXITCODE -ne 0) { throw "install.sh failed (exit $LASTEXITCODE)" }

# ---------------------------------------------------------------------------
# 6. Done + onboarding
# ---------------------------------------------------------------------------
Step 'Done'
Ok "CCF installed to $ClaudeDir"
$onboard = Join-Path $ClaudeDir 'fusion\ccf-onboard'
if (-not $SkipOnboard -and (Have 'python') -and (Test-Path $onboard)) {
  Write-Host ''
  $run = if ($Yes) { 'y' } else { Read-Host '  Run the setup wizard now (pick providers, add keys)? [Y/n]' }
  if (-not $run -or $run -match '^[Yy]') {
    python $onboard
  } else {
    Info "Run it later:  python `"$onboard`"   (or /fusion-setup in Claude Code)"
  }
} else {
  Info "Setup:  python `"$onboard`"   (or say /fusion-setup in Claude Code)"
}
Write-Host ''
Write-Host 'Then restart Claude Code and run /fusion-status.' -ForegroundColor Cyan

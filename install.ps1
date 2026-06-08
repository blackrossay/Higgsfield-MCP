<#
.SYNOPSIS
    One-shot installer for @higgsfield/cli on Windows without admin rights.

.DESCRIPTION
    Installs a portable Node.js LTS into the user profile, installs the
    @higgsfield/cli npm package, manually fetches the prebuilt `hf.exe`
    binary, persists PATH at user scope, and adds a pwsh profile entry.

    Designed to work behind corporate proxies that perform TLS inspection
    (e.g. Zscaler) and inside Git Bash environments where the postinstall
    `tar` call would otherwise fail.

.PARAMETER NodeVersion
    Node.js LTS version to install. Default: 24.16.0.

.PARAMETER InstallRoot
    Where to place the portable Node.js folder. Default: $HOME\nodejs.

.PARAMETER SkipAuth
    Skip the interactive `higgsfield auth login` step at the end.

.EXAMPLE
    PS> .\install.ps1
    Installs Node 24.16.0 LTS and @higgsfield/cli, then runs auth login.

.EXAMPLE
    PS> .\install.ps1 -SkipAuth
    Installs everything but does not prompt for browser authentication.
#>
[CmdletBinding()]
param(
    [string]$NodeVersion = '24.16.0',
    [string]$InstallRoot = (Join-Path $HOME 'nodejs'),
    [switch]$SkipAuth
)

$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

function Write-Step($msg)    { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Info($msg)    { Write-Host "    $msg" -ForegroundColor Gray }
function Write-Success($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[!]  $msg" -ForegroundColor Yellow }

# --- 1. Download portable Node.js ------------------------------------------
$nodeFolder    = "node-v$NodeVersion-win-x64"
$nodeDir       = Join-Path $InstallRoot $nodeFolder
$nodeZipUrl    = "https://nodejs.org/dist/v$NodeVersion/$nodeFolder.zip"
$nodeZipPath   = Join-Path $InstallRoot "$nodeFolder.zip"

if (Test-Path (Join-Path $nodeDir 'node.exe')) {
    Write-Step "Node.js $NodeVersion already present at $nodeDir"
} else {
    Write-Step "Downloading Node.js $NodeVersion (portable, user-scope)"
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Invoke-WebRequest -Uri $nodeZipUrl -OutFile $nodeZipPath
    Write-Info "Extracting to $InstallRoot"
    Expand-Archive -LiteralPath $nodeZipPath -DestinationPath $InstallRoot -Force
    Remove-Item $nodeZipPath -Force
    Write-Success "Node.js installed at $nodeDir"
}

# --- 2. Add Node to PATH for this session ----------------------------------
$env:Path = "$nodeDir;$env:Path"
# Trust Windows certificate store so corporate TLS proxies (Zscaler, etc.)
# don't break HTTPS downloads from postinstall scripts.
$env:NODE_USE_SYSTEM_CA = '1'

Write-Step "Verifying Node and npm"
$nodeVer = & "$nodeDir\node.exe" --version
$npmVer  = & "$nodeDir\npm.cmd" --version
Write-Info "node: $nodeVer"
Write-Info "npm : $npmVer"

# --- 3. Install @higgsfield/cli (skip the buggy postinstall) ---------------
# The package's postinstall calls `tar -xzf C:\...` which breaks under Git Bash
# (GNU tar reads `C:` as a remote host). We install with --ignore-scripts and
# run the equivalent download/extract manually below using Windows native tar.
Write-Step "Installing @higgsfield/cli (skipping postinstall)"
& "$nodeDir\npm.cmd" install -g --ignore-scripts '@higgsfield/cli'
if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }

# --- 4. Manually fetch and extract the hf.exe binary -----------------------
$pkgDir    = Join-Path $nodeDir 'node_modules\@higgsfield\cli'
$vendorDir = Join-Path $pkgDir 'vendor'
$hfExe     = Join-Path $vendorDir 'hf.exe'

if (Test-Path $hfExe) {
    Write-Step "hf.exe already present, skipping download"
} else {
    Write-Step "Fetching hf.exe binary"
    New-Item -ItemType Directory -Path $vendorDir -Force | Out-Null

    $pkgJson      = Get-Content (Join-Path $pkgDir 'package.json') -Raw | ConvertFrom-Json
    $cliVer       = $pkgJson.version
    $tarballName  = "hf_${cliVer}_windows_amd64.tar.gz"
    $tarballUrl   = "https://github.com/higgsfield-ai/cli/releases/download/v${cliVer}/${tarballName}"
    $tarballPath  = Join-Path $vendorDir $tarballName

    Write-Info "Downloading $tarballUrl"
    Invoke-WebRequest -Uri $tarballUrl -OutFile $tarballPath

    Write-Info "Extracting hf.exe using Windows native tar.exe"
    # Force the Windows-native tar (System32) to avoid Git Bash's GNU tar
    # interpreting `C:` as a remote host.
    $sysTar = 'C:\Windows\System32\tar.exe'
    & $sysTar -xzf $tarballPath -C $vendorDir 'hf.exe'
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed (exit $LASTEXITCODE)" }

    Remove-Item $tarballPath -Force

    @{
        install_method  = 'install.ps1'
        package_manager = 'npm'
        package_name    = '@higgsfield/cli'
        version         = $cliVer
    } | ConvertTo-Json | Set-Content -Path (Join-Path $vendorDir 'install.json')

    Write-Success "hf.exe installed at $hfExe"
}

# --- 5. Persist Node folder in User PATH (dedup duplicates) ----------------
Write-Step "Persisting Node folder in User PATH"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries  = @()
if ($userPath) {
    $entries = $userPath -split ';' | Where-Object { $_ -ne '' } | Select-Object -Unique
}
if ($entries -notcontains $nodeDir) {
    # Place Node first so its bins take precedence
    $entries = ,$nodeDir + ($entries | Where-Object { $_ -ne $nodeDir })
}
$newPath = ($entries | Select-Object -Unique) -join ';'
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
Write-Success "User PATH updated"

# --- 6. Add to pwsh / Windows PowerShell profile ---------------------------
# VS Code integrated terminals inherit env from VS Code's parent process,
# so a fresh User-PATH change isn't visible until VS Code is restarted.
# A profile line makes new sessions self-heal immediately.
Write-Step "Updating PowerShell profile so new sessions auto-load PATH"
$profileLine = "`$env:Path += ';$nodeDir'"
$marker      = '# HiggsfieldCLI:install.ps1'
$snippet     = "$marker`r`n$profileLine"

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$existing = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($existing -notmatch [regex]::Escape($marker)) {
    Add-Content -Path $PROFILE -Value "`r`n$snippet"
    Write-Success "Profile updated: $PROFILE"
} else {
    Write-Info "Profile already contains marker, skipping"
}

# --- 7. Final verification --------------------------------------------------
Write-Step "Verifying higgsfield CLI"
$hfShim = Join-Path $nodeDir 'higgsfield.cmd'
if (Test-Path $hfShim) {
    & $hfShim --help | Select-Object -First 3 | ForEach-Object { Write-Info $_ }
    Write-Success "higgsfield CLI is installed"
} else {
    Write-Warn "higgsfield shim not found at $hfShim"
}

# --- 8. Authenticate --------------------------------------------------------
if ($SkipAuth) {
    Write-Step "Skipping auth (per -SkipAuth)"
    Write-Info  "Run later: higgsfield auth login"
} else {
    Write-Step "Starting browser-based device login"
    Write-Info "Approve the device when your browser opens, then return here."
    & $hfShim auth login
}

Write-Host ""
Write-Success "Setup complete."
Write-Host  "Open a NEW PowerShell window or run:" -ForegroundColor Yellow
Write-Host  "    `$env:Path += ';$nodeDir'" -ForegroundColor Yellow
Write-Host  "then try:  higgsfield model list" -ForegroundColor Yellow

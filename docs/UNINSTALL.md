# Uninstall

Everything `install.ps1` writes lives under your user profile. Nothing requires admin to remove.

Run this in PowerShell to fully reverse the install:

```powershell
# 1. Log out and delete the auth token
higgsfield auth logout 2>$null
Remove-Item "$HOME\.higgsfield" -Recurse -Force -ErrorAction SilentlyContinue

# 2. Delete the portable Node.js folder (also removes the CLI installed under it)
Remove-Item "$HOME\nodejs" -Recurse -Force

# 3. Delete the npm cache (optional, can be reused by other Node installs)
Remove-Item "$env:LOCALAPPDATA\npm-cache" -Recurse -Force -ErrorAction SilentlyContinue

# 4. Remove the Node folder from User PATH
$pathBefore = [Environment]::GetEnvironmentVariable('Path', 'User')
$cleaned = ($pathBefore -split ';' |
            Where-Object { $_ -and ($_ -notlike "*\nodejs\node-v*-win-x64") }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $cleaned, 'User')

# 5. Remove the self-healing line from the PowerShell profile
if (Test-Path $PROFILE) {
    $lines = Get-Content $PROFILE
    $keep  = @()
    $skip  = $false
    foreach ($line in $lines) {
        if ($line -match '# HiggsfieldCLI:install\.ps1') { $skip = $true; continue }
        if ($skip -and $line -match '\$env:Path \+= ') { $skip = $false; continue }
        $skip = $false
        $keep += $line
    }
    Set-Content -Path $PROFILE -Value $keep
}

Write-Host "Higgsfield CLI uninstalled. Open a new shell to refresh PATH."
```

After this, `higgsfield`, `higgs`, and `hf` will no longer resolve in any new shell, and no Higgsfield-related files remain on disk.

# Troubleshooting

Every issue here was hit during a real install on a locked-down Windows VM behind Zscaler. The `install.ps1` script avoids them all, but if you hit a variant or are debugging by hand, this is your reference.

---

## 1. `npm: command not found` / `python: command not found`

**Symptom:** A fresh corporate VM has no Node.js or Python installed, and you can't run admin installers.

**Why `install.ps1` works:** Downloads the portable Node.js zip into `%USERPROFILE%\nodejs` — no installer, no admin. Adds the folder to your User PATH.

---

## 2. `unable to get local issuer certificate`

**Symptom:** During `npm install -g @higgsfield/cli`, the postinstall step that fetches the prebuilt binary from GitHub fails with:

```
@higgsfield/cli: install failed — unable to get local issuer certificate
```

**Cause:** Your corporate proxy (Zscaler / Netskope / etc.) terminates TLS and re-signs traffic with a private root CA. Node 22+ ships with its own CA bundle and doesn't trust the Windows certificate store by default, so its HTTPS requests fail.

**Fix (Node 24+):** Set the env var before `npm`:

```powershell
$env:NODE_USE_SYSTEM_CA = '1'
```

This is set automatically by `install.ps1`.

> For Node ≤ 22 the equivalent is `NODE_EXTRA_CA_CERTS` pointing at a PEM file exported from your proxy. Ask your IT team for the Zscaler root CA in PEM form.

---

## 3. `tar (child): Cannot connect to higgsfield\cli\vendor\…: resolve failed`

**Symptom:** After fixing the TLS error, the postinstall still fails with:

```
tar (child): Cannot connect to higgsfield\cli\vendor\hf_<version>_windows_amd64.tar.gz: resolve failed
gzip: stdin: unexpected end of file
```

**Cause:** The package's `install.js` calls `tar -xzf C:\Users\…\vendor\file.tar.gz`. If your PATH has Git Bash before `C:\Windows\System32`, GNU `tar` is found first — and GNU `tar` interprets `C:` as a remote SSH host. It tries to connect to a host called `C`, fails, then complains about an empty stream.

**Fix:** `install.ps1` runs `npm install -g --ignore-scripts` (skip the postinstall entirely), then re-implements the download + extract using the Windows-native `C:\Windows\System32\tar.exe` explicitly.

If you ever need to redo the binary extraction by hand:

```powershell
$pkg     = "$HOME\nodejs\node-v24.16.0-win-x64\node_modules\@higgsfield\cli"
$ver     = (Get-Content "$pkg\package.json" | ConvertFrom-Json).version
$vendor  = "$pkg\vendor"
$tarball = "hf_${ver}_windows_amd64.tar.gz"

New-Item -ItemType Directory -Path $vendor -Force | Out-Null
Invoke-WebRequest "https://github.com/higgsfield-ai/cli/releases/download/v$ver/$tarball" `
    -OutFile "$vendor\$tarball"
& "C:\Windows\System32\tar.exe" -xzf "$vendor\$tarball" -C $vendor 'hf.exe'
Remove-Item "$vendor\$tarball"
```

---

## 4. `higgsfield auth login` hangs at "Waiting for approval…"

**Symptom:** Browser opens (or you visit the URL manually), but the CLI never picks up the approval.

**Likely causes:**
- You weren't actually logged in to Higgsfield in the browser when you opened the device URL — the page silently bounces to login and the code is never submitted.
- The device code expired (they have a short TTL — usually 5–10 minutes). **Re-run `higgsfield auth login` to get a fresh code.**
- A wrong/old browser tab still has the previous code.

**Verify auth state:**

```powershell
higgsfield auth token       # prints token if logged in
higgsfield account status   # hits the API
```

---

## 5. `higgsfield: The term 'higgsfield' is not recognized`

**Symptom:** Works in the bash window where you ran the installer, but a new PowerShell window can't find `higgsfield`.

**Causes & fixes:**

| Cause | Fix |
|---|---|
| You haven't opened a fresh terminal since PATH was updated | Open a new PowerShell window |
| You're in VS Code — its terminals inherit env from the VS Code process | Fully close and reopen VS Code (the whole window, not just the panel) |
| One-off shell where you need it now | `$env:Path += ";$HOME\nodejs\node-v24.16.0-win-x64"` |

`install.ps1` also writes a self-healing line to your `$PROFILE`, so every **new** PowerShell session auto-prepends Node to PATH even if VS Code's env is stale.

---

## 6. `Registry editing has been disabled by your administrator`

**Symptom:** Trying to query / change PATH via `reg.exe` fails with this message.

**Cause:** Group Policy restriction common on corporate machines.

**Fix:** Don't use `reg.exe`. The .NET API works fine without admin:

```powershell
[Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', $new, 'User')
```

`install.ps1` uses this approach exclusively.

---

## 7. Script execution blocked

**Symptom:** `.\install.ps1` won't run — "running scripts is disabled on this system".

**Fix (no admin needed):** Use a process-scoped policy override:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

Or invoke directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

---

## 8. Duplicate Node entries in PATH

If you ran an earlier ad-hoc fix several times you can end up with the same folder repeated in your User PATH. `install.ps1` dedupes automatically, but you can clean it up manually:

```powershell
$entries = [Environment]::GetEnvironmentVariable('Path','User') -split ';' |
           Where-Object { $_ -ne '' } |
           Select-Object -Unique
[Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
```

---

## Still stuck?

Capture the failing command's full output and the values of:

```powershell
$env:Path
$PROFILE
node --version
npm --version
npm config get prefix
[Environment]::GetEnvironmentVariable('Path','User')
```

Open an issue with that output attached.

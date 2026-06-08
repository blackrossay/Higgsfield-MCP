# Higgsfield CLI — Windows No-Admin Install

A one-shot PowerShell installer that gets the [Higgsfield AI CLI](https://www.npmjs.com/package/@higgsfield/cli) (`higgsfield` / `higgs` / `hf`) working on a corporate Windows laptop where you **don't have admin rights** and where outbound HTTPS goes through a **TLS-inspecting proxy** (Zscaler, Netskope, BlueCoat, etc.).

The script bypasses the pitfalls that make the official `npm install -g @higgsfield/cli` fail in those environments and was developed by working through them one at a time on a real corporate VM.

---

## What it does

1. Downloads the **portable Node.js LTS** zip into your user profile (no installer, no admin).
2. Sets `NODE_USE_SYSTEM_CA=1` so Node trusts the **Windows certificate store** (where your corporate TLS root usually lives).
3. Installs `@higgsfield/cli` with `--ignore-scripts` to skip the broken postinstall.
4. Manually downloads the `hf.exe` Go binary from GitHub Releases and extracts it with the **Windows-native `tar.exe`** (avoiding the Git Bash `tar` bug).
5. Persists the Node folder into your **User PATH** (deduped).
6. Appends a self-healing PATH line to your **PowerShell profile** so new sessions work immediately, even inside VS Code.
7. Runs `higgsfield auth login` (browser-based device flow).

Nothing is written outside `%USERPROFILE%`. Reversible — see [docs/UNINSTALL.md](docs/UNINSTALL.md).

---

## Requirements

| | |
|---|---|
| OS | Windows 10 / 11 (x64) |
| Shell | Windows PowerShell 5.1 or PowerShell 7 (`pwsh`) |
| Admin | **Not required** |
| Internet | HTTPS access to `nodejs.org`, `registry.npmjs.org`, `github.com`, `higgsfield.ai` |
| Account | A Higgsfield account at <https://higgsfield.ai> |

---

## Quick start

Clone or download this repo, then in PowerShell:

```powershell
cd <repo-folder>
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

That's the whole install. The script prints colored progress and ends with a browser-based login prompt.

### Options

```powershell
.\install.ps1 -SkipAuth                 # install only, no browser login
.\install.ps1 -NodeVersion '24.16.0'    # pick a different Node LTS
.\install.ps1 -InstallRoot 'D:\dev\nodejs'  # custom install location
```

---

## After install

Open a **new** PowerShell window (so the updated PATH is picked up), then:

```powershell
higgsfield --help
higgsfield account status
higgsfield model list
higgsfield generate create text2image_soul_v2 --prompt "a cat in a spaceship"
```

Aliases: `higgsfield`, `higgs`, `hf`.

If you're still in the same shell that ran the installer, paste this once:

```powershell
$env:Path += ";$HOME\nodejs\node-v24.16.0-win-x64"
```

---

## Where things live

| Item | Path |
|---|---|
| Node.js | `%USERPROFILE%\nodejs\node-v<VER>-win-x64\` |
| npm cache | `%LOCALAPPDATA%\npm-cache\` |
| `@higgsfield/cli` package | `%USERPROFILE%\nodejs\node-v<VER>-win-x64\node_modules\@higgsfield\cli\` |
| `hf.exe` binary | `…\@higgsfield\cli\vendor\hf.exe` |
| CLI shims | `%USERPROFILE%\nodejs\node-v<VER>-win-x64\higgsfield.cmd` (plus `higgs.cmd`, `hf.cmd`) |
| Auth token | `%USERPROFILE%\.higgsfield\` |
| PowerShell profile entry | `$PROFILE` (line tagged `# HiggsfieldCLI:install.ps1`) |

---

## Documentation

- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — every failure mode this script bypasses, with the symptoms you would have seen
- [docs/UNINSTALL.md](docs/UNINSTALL.md) — complete reversibility steps
- [docs/article/anatomy-of-an-ai-token.md](docs/article/anatomy-of-an-ai-token.md) — companion article: an 8-second cinematic visualisation of the AI inference pipeline, generated end-to-end with this installer ([video](assets/anatomy-of-an-ai-token.mp4))

---

## License

MIT — see [LICENSE](LICENSE).

This repository is **not affiliated with Higgsfield AI**. `@higgsfield/cli` is published by Higgsfield AI under MIT — see <https://github.com/higgsfield-ai/cli>.

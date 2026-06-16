# Installing CCF via Homebrew

A formula is provided at [`Formula/ccf.rb`](../Formula/ccf.rb). CCF installs into `~/.claude`
(it's a Claude Code extension), so `brew install` stages the files and exposes a `ccf` command that
runs the installer.

## Option A — direct formula (no tap)

```bash
brew install --formula https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/Formula/ccf.rb
ccf            # writes CCF into ~/.claude
```

## Option B — a tap (recommended for `brew upgrade`)

Requires a one-time tap repo named **`homebrew-ccf`** under the same account
(`brahmsyaifullah/homebrew-ccf`) containing `Formula/ccf.rb`:

```bash
brew tap brahmsyaifullah/ccf
brew install ccf
ccf
```

To create the tap repo:

```bash
gh repo create brahmsyaifullah/homebrew-ccf --public -d "Homebrew tap for CCF"
git clone https://github.com/brahmsyaifullah/homebrew-ccf && cd homebrew-ccf
mkdir -p Formula && curl -fsSL https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/Formula/ccf.rb -o Formula/ccf.rb
git add -A && git commit -m "ccf 1.3.0" && git push
```

## Updating the formula on each release

After tagging a new CCF version, bump `url`, `version`, and `sha256` in `Formula/ccf.rb`:

```bash
ver=1.3.0
curl -fsSL "https://github.com/brahmsyaifullah/CCF/archive/refs/tags/v${ver}.tar.gz" | shasum -a 256
```

> npm (`npx ccf`) and AUR packaging are not yet provided — the curl one-liner and Homebrew cover
> macOS/Linux/WSL. Windows uses `install.ps1`.

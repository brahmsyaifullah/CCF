#!/usr/bin/env bash
# ccf-update.sh — update an installed CCF (Claude Code Fusion) from GitHub.
#
#   ccf-update.sh            # update if a newer version exists
#   ccf-update.sh --force    # reinstall latest even if versions match
#   ccf-update.sh --check    # report only, change nothing
#
# Refreshes CODE (dispatcher, hooks, update scripts, slash commands, .dist configs)
# and the VERSION file. PRESERVES your secrets.env, panel.json, and providers.json.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
FUSION_DIR="$CLAUDE_DIR/fusion"
CMD_DIR="$CLAUDE_DIR/commands"
SRC_FILE="$FUSION_DIR/.ccf-source"
BRANCH="${CCF_BRANCH:-main}"

slug="brahmsyaifullah/CCF"
[ -f "$SRC_FILE" ] && slug="$(cat "$SRC_FILE")"
RAW="https://raw.githubusercontent.com/$slug/$BRANCH"
TARBALL="https://codeload.github.com/$slug/tar.gz/refs/heads/$BRANCH"

mode="update"
case "${1:-}" in
  --force) mode="force" ;;
  --check) mode="check" ;;
  "") ;;
  *) echo "usage: ccf-update.sh [--force|--check]"; exit 2 ;;
esac

local_ver="0.0.0"; [ -f "$FUSION_DIR/VERSION" ] && local_ver="$(tr -d '[:space:]' < "$FUSION_DIR/VERSION")"
remote_ver="$(curl -fsSL -m 10 "$RAW/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
[ -z "$remote_ver" ] && { echo "ccf-update: cannot reach GitHub ($slug). Check network."; exit 1; }

newest="$(printf '%s\n%s\n' "$local_ver" "$remote_ver" | sort -V | tail -1)"
echo "CCF installed=$local_ver  remote=$remote_ver  (repo: $slug)"

if [ "$mode" = "check" ]; then
  [ "$remote_ver" != "$local_ver" ] && [ "$newest" = "$remote_ver" ] \
    && echo "Update available -> run: ccf-update.sh" || echo "Up to date."
  exit 0
fi

if [ "$mode" = "update" ] && [ "$remote_ver" = "$local_ver" ]; then
  echo "Already on the latest version. Use --force to reinstall."; exit 0
fi
if [ "$mode" = "update" ] && [ "$newest" = "$local_ver" ] && [ "$local_ver" != "$remote_ver" ]; then
  echo "Installed version is newer than remote — skipping. Use --force to override."; exit 0
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "Downloading $slug@$BRANCH ..."
curl -fsSL -m 60 "$TARBALL" -o "$tmp/ccf.tgz"
tar -xzf "$tmp/ccf.tgz" -C "$tmp"
root="$(find "$tmp" -maxdepth 1 -type d -name '*-'"$BRANCH" | head -1)"
[ -z "$root" ] && root="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d ! -name '.*' | head -1)"
[ -z "$root" ] && { echo "ccf-update: extracted archive layout unexpected"; exit 1; }

mkdir -p "$FUSION_DIR" "$CMD_DIR"

# --- CODE: always overwrite ---
install -m 0755 "$root/bin/fusion-call"             "$FUSION_DIR/fusion-call"
install -m 0755 "$root/hooks/fusion-hook.sh"        "$FUSION_DIR/fusion-hook.sh"
install -m 0755 "$root/bin/ccf-update.sh"           "$FUSION_DIR/ccf-update.sh"
install -m 0755 "$root/bin/ccf-check-update.sh"     "$FUSION_DIR/ccf-check-update.sh"
install -m 0755 "$root/bin/fusion-onboard"          "$FUSION_DIR/fusion-onboard"
install -m 0755 "$root/bin/ccf-models"              "$FUSION_DIR/ccf-models"
install -m 0755 "$root/bin/ccf-analytics"           "$FUSION_DIR/ccf-analytics"
install -m 0755 "$root/bin/ccf-codex-login"         "$FUSION_DIR/ccf-codex-login"
for f in "$root/commands/"*.md; do install -m 0644 "$f" "$CMD_DIR/$(basename "$f")"; done

# --- DIST templates + catalog: always refresh (reference copies, not your live config) ---
install -m 0644 "$root/config/providers.dist.json"  "$FUSION_DIR/providers.dist.json"
install -m 0644 "$root/config/panel.dist.json"      "$FUSION_DIR/panel.dist.json"
install -m 0644 "$root/config/secrets.env.example"  "$FUSION_DIR/secrets.env.example"
install -m 0644 "$root/config/catalog.json"         "$FUSION_DIR/catalog.json"
mkdir -p "$FUSION_DIR/presets"
for f in "$root/config/presets/"*.json; do install -m 0644 "$f" "$FUSION_DIR/presets/$(basename "$f")"; done

# --- LIVE config: create if missing, otherwise leave the user's copy alone ---
[ -f "$FUSION_DIR/providers.json" ] || install -m 0644 "$root/config/providers.dist.json" "$FUSION_DIR/providers.json"
[ -f "$FUSION_DIR/panel.json" ]     || install -m 0644 "$root/config/panel.dist.json"     "$FUSION_DIR/panel.json"
if [ ! -f "$FUSION_DIR/secrets.env" ]; then
  install -m 0600 "$root/config/secrets.env.example" "$FUSION_DIR/secrets.env"
fi

# version + source pin
install -m 0644 "$root/VERSION" "$FUSION_DIR/VERSION"
printf '%s\n' "$slug" > "$SRC_FILE"

echo "Updated CCF: $local_ver -> $remote_ver"

# notify if shipped providers.dist gained fields the live providers.json lacks
if command -v jq >/dev/null 2>&1 && [ -f "$FUSION_DIR/providers.json" ]; then
  newkeys="$(jq -r '[.providers[] | keys[]] | unique[]' "$FUSION_DIR/providers.dist.json" 2>/dev/null | sort -u || true)"
  havekeys="$(jq -r '[.providers[] | keys[]] | unique[]' "$FUSION_DIR/providers.json" 2>/dev/null | sort -u || true)"
  missing="$(comm -23 <(printf '%s\n' "$newkeys") <(printf '%s\n' "$havekeys") || true)"
  [ -n "$missing" ] && {
    echo "NOTE: providers.dist.json has fields your providers.json lacks: $(echo $missing | tr '\n' ' ')"
    echo "      Review $FUSION_DIR/providers.dist.json and merge if you want them (e.g. context limits)."
  }
fi
echo "Done. Restart Claude Code if hooks or commands changed."

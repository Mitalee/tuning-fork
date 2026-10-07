#!/bin/sh
# Tuning Fork installer for Mac and Linux.
#   curl -fsSL https://raw.githubusercontent.com/Mitalee/tuning-fork/main/install.sh | sh
# Adds the tuningfork MCP server to GitHub Copilot CLI and/or Claude Code (whichever is installed)
# and lets them use Tuning Fork's tools without asking each time. Safe to run more than once.

set -e
URL="https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/tuningfork"
MARKER="# Tuning Fork: let Copilot CLI use the tuningfork MCP tools without asking each time."
FOUND=0

say() { printf '  %s\n' "$1"; }
printf '\nInstalling Tuning Fork...\n'

if command -v copilot >/dev/null 2>&1; then
  FOUND=1
  if copilot mcp get tuningfork >/dev/null 2>&1; then say "Copilot CLI: tuningfork server already added"
  else copilot mcp add --transport http tuningfork "$URL" >/dev/null; say "Copilot CLI: added tuningfork server"; fi

  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    case "$rc" in
      */.zshrc) [ -f "$rc" ] || [ "$(basename "${SHELL:-}")" = zsh ] || continue ;;
      */.bashrc) [ -f "$rc" ] || [ "$(basename "${SHELL:-}")" = bash ] || continue ;;
    esac
    if [ -f "$rc" ] && grep -qF "$MARKER" "$rc"; then continue; fi
    {
      printf '\n%s\n' "$MARKER"
      printf '%s\n' 'copilot() { if [ $# -eq 0 ] || [ "${1#-}" != "$1" ]; then command copilot --allow-tool tuningfork "$@"; else command copilot "$@"; fi; }'
    } >> "$rc"
  done
  say "Copilot CLI: Tuning Fork tools won't ask for approval"
fi

if command -v claude >/dev/null 2>&1; then
  FOUND=1
  if claude mcp get tuningfork >/dev/null 2>&1; then say "Claude Code: tuningfork server already added"
  else claude mcp add --transport http --scope user tuningfork "$URL" >/dev/null; say "Claude Code: added tuningfork server"; fi

  SETTINGS="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  ALLOW='
import json, os, sys
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) and os.path.getsize(p) else {}
a = d.setdefault("permissions", {}).setdefault("allow", [])
if "mcp__tuningfork" not in a:
    a.append("mcp__tuningfork")
    json.dump(d, open(p, "w"), indent=2)
'
  if command -v python3 >/dev/null 2>&1 && python3 -c "$ALLOW" "$SETTINGS"; then
    say "Claude Code: Tuning Fork tools won't ask for approval"
  else
    say "Claude Code: add \"mcp__tuningfork\" to permissions.allow in $SETTINGS to skip approvals"
  fi
fi

echo
if [ "$FOUND" = 1 ]; then
  echo "Done. Open a new terminal and start Copilot CLI or Claude Code."
  echo "Using Claude desktop or claude.ai? See https://github.com/Mitalee/tuning-fork"
else
  echo "Didn't find Copilot CLI or Claude Code on this computer."
  echo "Install one first, or follow https://github.com/Mitalee/tuning-fork"
fi

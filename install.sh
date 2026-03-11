#!/usr/bin/env bash
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/dnorth123/claude-code-context-meter/main/context-meter.py"
INSTALL_DIR="$HOME/.claude/scripts"
INSTALL_PATH="$INSTALL_DIR/context-meter.py"
SETTINGS="$HOME/.claude/settings.json"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}Claude Code Context Meter${RESET}"
echo -e "Animated context window meter with spinner + shimmer"
echo ""

# Check for python3
if ! command -v python3 &>/dev/null; then
  echo -e "${RED}Error:${RESET} python3 is required but not found."
  exit 1
fi

# Check for curl
if ! command -v curl &>/dev/null; then
  echo -e "${RED}Error:${RESET} curl is required but not found."
  exit 1
fi

# Show what will happen
echo -e "${BOLD}This installer will:${RESET}"
echo "  1. Download context-meter.py to $INSTALL_DIR/"
echo "  2. Update $SETTINGS with the statusLine config"
echo ""

# Check for existing statusLine
HAS_EXISTING=""
if [ -f "$SETTINGS" ]; then
  if python3 -c "import json; d=json.load(open('$SETTINGS')); exit(0 if 'statusLine' in d else 1)" 2>/dev/null; then
    HAS_EXISTING="1"
    CURRENT=$(python3 -c "import json; d=json.load(open('$SETTINGS')); sl=d.get('statusLine',{}); print(sl.get('command','(unknown)'))" 2>/dev/null)
    echo -e "${YELLOW}Note:${RESET} Your settings.json already has a statusLine config:"
    echo -e "  ${BOLD}$CURRENT${RESET}"
    echo ""
    echo "  Installing will replace it. A backup will be saved to:"
    echo "  ${SETTINGS}.bak"
    echo ""
  fi
fi

# Prompt to continue
read -rp "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# Create directory
mkdir -p "$INSTALL_DIR"

# Download script
echo -n "Downloading context-meter.py... "
curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo -e "${GREEN}done${RESET}"

# Update settings.json
echo -n "Updating settings.json... "

if [ ! -f "$SETTINGS" ]; then
  # No settings file — create one
  python3 -c "
import json
d = {'statusLine': {'type': 'command', 'command': '\$HOME/.claude/scripts/context-meter.py', 'padding': 0}}
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
else
  # Back up if there's an existing statusLine
  if [ -n "$HAS_EXISTING" ]; then
    cp "$SETTINGS" "${SETTINGS}.bak"
  fi
  # Patch the statusLine key
  python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
d['statusLine'] = {'type': 'command', 'command': '\$HOME/.claude/scripts/context-meter.py', 'padding': 0}
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
fi
echo -e "${GREEN}done${RESET}"

echo ""
echo -e "${GREEN}Installed!${RESET} Restart Claude Code to see the context meter."
if [ -n "$HAS_EXISTING" ]; then
  echo -e "Previous settings backed up to ${BOLD}${SETTINGS}.bak${RESET}"
fi
echo ""

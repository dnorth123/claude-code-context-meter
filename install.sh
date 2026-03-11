#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/dnorth123/claude-code-context-meter/main"
INSTALL_DIR="$HOME/.claude/scripts"
INSTALL_PATH="$INSTALL_DIR/context-meter.py"
HOOKS_DIR="$HOME/.claude/hooks"
COMMANDS_DIR="$HOME/.claude/commands"
STATES_DIR="$HOME/.claude/session-states"
SETTINGS="$HOME/.claude/settings.json"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m'

MODE="meter-only"
for arg in "$@"; do
  case "$arg" in
    --with-hooks) MODE="with-hooks" ;;
    --remove-hooks) MODE="remove-hooks" ;;
    *) echo -e "${RED}Unknown flag:${RESET} $arg"; exit 1 ;;
  esac
done

# --- REMOVE HOOKS ---
if [ "$MODE" = "remove-hooks" ]; then
  echo ""
  echo -e "${BOLD}Claude Code Context Meter — Remove Hooks${RESET}"
  echo ""

  removed=0

  if [ -f "$HOOKS_DIR/context-threshold-stop.js" ]; then
    rm "$HOOKS_DIR/context-threshold-stop.js"
    echo -e "  Removed ${BOLD}context-threshold-stop.js${RESET}"
    removed=$((removed + 1))
  fi

  if [ -f "$HOOKS_DIR/context-threshold-start.js" ]; then
    rm "$HOOKS_DIR/context-threshold-start.js"
    echo -e "  Removed ${BOLD}context-threshold-start.js${RESET}"
    removed=$((removed + 1))
  fi

  echo -e "  ${YELLOW}Note:${RESET} Remove ~/.claude/commands/save-state.md manually if you no longer need it."

  if [ -f "$SETTINGS" ]; then
    python3 -c "
import json

with open('$SETTINGS') as f:
    d = json.load(f)

hooks = d.get('hooks', {})
changed = False

stop_cmd = 'node \"\$HOME/.claude/hooks/context-threshold-stop.js\"'
start_cmd = 'node \"\$HOME/.claude/hooks/context-threshold-start.js\"'

for event in list(hooks.keys()):
    original_len = len(hooks[event])
    hooks[event] = [
        group for group in hooks[event]
        if not any(
            h.get('command', '') in (stop_cmd, start_cmd)
            for h in group.get('hooks', [])
        )
    ]
    if len(hooks[event]) != original_len:
        changed = True
    if len(hooks[event]) == 0:
        del hooks[event]
        changed = True

if changed:
    d['hooks'] = hooks
    with open('$SETTINGS', 'w') as f:
        json.dump(d, f, indent=2)
        f.write('\n')
    print('  Removed hook entries from settings.json')
else:
    print('  No hook entries found in settings.json')
"
  fi

  # Clean up bridge files
  rm -f "$HOME/.claude/context-threshold.json" "$HOME/.claude/context-warnings.json"
  echo -e "  Cleaned up bridge files"

  if [ -d "$STATES_DIR" ]; then
    echo ""
    read -rp "Remove saved session states in $STATES_DIR? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      rm -rf "$STATES_DIR"
      echo -e "  ${GREEN}Removed${RESET} session-states/"
    else
      echo "  Kept session-states/"
    fi
  fi

  echo ""
  if [ $removed -gt 0 ]; then
    echo -e "${GREEN}Hooks removed.${RESET} Context meter is still installed."
  else
    echo "No hook files found to remove."
  fi
  echo ""
  exit 0
fi

# --- INSTALL (meter-only or with-hooks) ---
echo ""
echo -e "${BOLD}Claude Code Context Meter${RESET}"
echo -e "Animated context window meter with spinner + shimmer"
echo ""

if ! command -v python3 &>/dev/null; then
  echo -e "${RED}Error:${RESET} python3 is required but not found."
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo -e "${RED}Error:${RESET} curl is required but not found."
  exit 1
fi

echo -e "${BOLD}This installer will:${RESET}"
echo "  1. Download context-meter.py to $INSTALL_DIR/"
echo "  2. Update $SETTINGS with the statusLine config"
if [ "$MODE" = "with-hooks" ]; then
  echo "  3. Install context threshold hooks"
  echo "  4. Install /save-state command (if not present)"
  echo "  5. Create session-states directory"
fi
echo ""

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

read -rp "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

mkdir -p "$INSTALL_DIR"

echo -n "Downloading context-meter.py... "
curl -fsSL "$REPO_URL/context-meter.py" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo -e "${GREEN}done${RESET}"

echo -n "Updating settings.json... "
if [ ! -f "$SETTINGS" ]; then
  python3 -c "
import json
d = {'statusLine': {'type': 'command', 'command': '\$HOME/.claude/scripts/context-meter.py', 'padding': 0}}
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
else
  if [ -n "$HAS_EXISTING" ]; then
    cp "$SETTINGS" "${SETTINGS}.bak"
  fi
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

# --- WITH-HOOKS ---
if [ "$MODE" = "with-hooks" ]; then
  echo ""
  mkdir -p "$HOOKS_DIR"

  echo -n "Downloading context-threshold-stop.js... "
  curl -fsSL "$REPO_URL/hooks/context-threshold-stop.js" -o "$HOOKS_DIR/context-threshold-stop.js"
  echo -e "${GREEN}done${RESET}"

  echo -n "Downloading context-threshold-start.js... "
  curl -fsSL "$REPO_URL/hooks/context-threshold-start.js" -o "$HOOKS_DIR/context-threshold-start.js"
  echo -e "${GREEN}done${RESET}"

  mkdir -p "$COMMANDS_DIR"
  if [ -f "$COMMANDS_DIR/save-state.md" ]; then
    echo -e "${YELLOW}Skipping${RESET} save-state.md — you already have one"
  else
    echo -n "Downloading save-state.md... "
    curl -fsSL "$REPO_URL/commands/save-state.md" -o "$COMMANDS_DIR/save-state.md"
    echo -e "${GREEN}done${RESET}"
  fi

  mkdir -p "$STATES_DIR"

  echo -n "Updating settings.json hooks... "
  python3 -c "
import json

with open('$SETTINGS') as f:
    d = json.load(f)

hooks = d.setdefault('hooks', {})

stop_cmd = 'node \"\$HOME/.claude/hooks/context-threshold-stop.js\"'
start_cmd = 'node \"\$HOME/.claude/hooks/context-threshold-start.js\"'

stop_entry = {
    'hooks': [{
        'type': 'command',
        'command': stop_cmd,
        'timeout': 5
    }]
}
start_entry = {
    'matcher': 'startup|resume|clear',
    'hooks': [{
        'type': 'command',
        'command': start_cmd,
        'timeout': 10,
        'statusMessage': 'Loading saved session state...'
    }]
}

def has_command(entries, cmd):
    for group in entries:
        for h in group.get('hooks', []):
            if h.get('command', '') == cmd:
                return True
    return False

stop_hooks = hooks.setdefault('Stop', [])
if not has_command(stop_hooks, stop_cmd):
    stop_hooks.append(stop_entry)

start_hooks = hooks.setdefault('SessionStart', [])
if not has_command(start_hooks, start_cmd):
    start_hooks.append(start_entry)

with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  echo -e "${GREEN}done${RESET}"

  echo ""
  echo -e "${BOLD}Hooks installed:${RESET}"
  echo "  Stop:         context-threshold-stop.js  (60/75/90% circuit breakers)"
  echo "  SessionStart: context-threshold-start.js (loads saved session state)"
  if [ ! -f "$COMMANDS_DIR/save-state.md" ] 2>/dev/null; then
    echo "  Command:      /save-state"
  fi
fi

echo ""
echo -e "${GREEN}Installed!${RESET} Restart Claude Code to see the context meter."
if [ -n "$HAS_EXISTING" ]; then
  echo -e "Previous settings backed up to ${BOLD}${SETTINGS}.bak${RESET}"
fi
echo ""

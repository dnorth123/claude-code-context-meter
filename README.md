# Claude Code Context Meter

An animated context window meter for [Claude Code](https://docs.anthropic.com/en/docs/claude-code)'s statusline, inspired by Claude Code's own thinking indicator.

```
✶ CTX 42% | 87K tokens      (green, relaxed shimmer)
✻ CTX 55% | 112K tokens     (yellow, medium shimmer)
✢ CTX 68% | 160K tokens     (orange, faster shimmer)
· CTX 82% | 210K tokens     (red, urgent shimmer)
✽ CTX 94% | 260K tokens     (red, full-text pulse + reverse video)
```

## Features

**Animated spinner** — Uses Claude Code's asterisk character set (`· ✢ ✳ ✶ ✻ ✽`) in a ping-pong cycle, matching the thinking indicator's timing (~120ms per frame).

**Shimmer sweep** — A 3-character bright highlight continuously sweeps across the status text. Sweep speed increases with context usage:

| Zone | Context | Sweep speed | Color |
|------|---------|-------------|-------|
| Safe | < 50% | 250ms (relaxed) | Green |
| Watch | 50-59% | 200ms | Yellow |
| Warning | 60-74% | 150ms | Orange |
| Danger | 75-89% | 120ms (urgent) | Red |
| Critical | 90%+ | Full-text pulse | Red (reverse video) |

**Critical pulse** — At 90%+, the shimmer is replaced with a sinusoidal full-text pulse effect (matching Claude Code's tool-use flash), making it impossible to miss.

All animations are time-based — each render picks the current frame from the wall clock, so animations advance naturally as Claude Code refreshes the statusline.

## Requirements

- Python 3.6+ (uses f-strings)
- A terminal with truecolor support (most modern terminals)

## Install

1. Copy the script somewhere permanent:

```bash
mkdir -p ~/.claude/scripts
cp context-meter.py ~/.claude/scripts/context-meter.py
chmod +x ~/.claude/scripts/context-meter.py
```

2. Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "$HOME/.claude/scripts/context-meter.py",
    "padding": 0
  }
}
```

3. Restart Claude Code. The meter appears once context usage is above 0%.

## Customization

### Colors

Edit the `ZONES` list in the script. Each entry is `(min_percentage, base_rgb, shimmer_rgb, sweep_ms)`:

```python
ZONES = [
    (90, (255,  55,  55), (255, 150, 150),  80),   # critical
    (75, (255,  55,  55), (255, 130, 130), 120),   # danger
    (60, (255, 140,   0), (255, 200, 100), 150),   # warning
    (50, (255, 214,   0), (255, 245, 130), 200),   # watch
    ( 0, ( 46, 204,  64), (140, 240, 160), 250),   # safe
]
```

### Spinner characters

The `SPIN` array contains the ping-pong sequence. Claude Code uses different sets per platform:

| Platform | Characters |
|----------|-----------|
| macOS | `· ✢ ✳ ✶ ✻ ✽` |
| Ghostty | `· ✢ ✳ ✶ ✻ *` |
| Linux/Windows | `· ✢ * ✶ ✻ ✽` |

The default is the macOS set. Edit `SPIN` to match your platform or preference.

## How it works

Claude Code calls the statusline command on each render cycle, passing JSON on stdin with context window data. The script:

1. Parses `used_percentage` and token counts from stdin
2. Selects the color zone based on percentage thresholds
3. Computes the current spinner frame from `time.time()` (wall clock / 120ms)
4. Computes the shimmer position from `time.time()` (wall clock / sweep speed)
5. Renders each character with the appropriate ANSI truecolor escape code
6. Prints the result — Claude Code displays it in the statusline

No state is persisted between calls. Each invocation is stateless and deterministic for a given timestamp.

## License

MIT

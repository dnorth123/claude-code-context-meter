#!/usr/bin/env python3
"""
Claude Code context window meter with animated spinner and shimmer.

Reads JSON on stdin from Claude Code's statusLine system:
  {"context_window":{"used_percentage":N,"total_input_tokens":N,"total_output_tokens":N}}

Animations are time-based — each render picks the current frame from the
wall clock, so the spinner rotates and shimmer advances as the UI refreshes.

Spinner: Claude Code's ping-pong asterisk cycle (· ✢ ✳ ✶ ✻ ✽ and back)
Shimmer: 3-character bright highlight sweeping across the text
Critical (90%+): Full-text sinusoidal pulse with reverse video
"""
import sys, json, time, math

try:
    ctx = json.loads(sys.stdin.read()).get("context_window", {})
    pct = int(ctx.get("used_percentage", 0))
    total = int(ctx.get("total_input_tokens", 0)) + int(ctx.get("total_output_tokens", 0))
except Exception:
    sys.exit(0)

if pct == 0:
    sys.exit(0)

tok = f"{total // 1000}K" if total >= 1000 else "<1K"
now = time.time() * 1000

# Spinner: Claude Code ping-pong asterisk cycle (~120ms per frame)
SPIN = ["·", "✢", "✳", "✶", "✻", "✽", "✽", "✻", "✶", "✳", "✢", "·"]
star = SPIN[int(now / 120) % len(SPIN)]

# Zone: (min_pct, base_rgb, shimmer_rgb, sweep_interval_ms)
# Sweep speed increases with urgency — green is relaxed, red is urgent
ZONES = [
    (90, (255,  55,  55), (255, 150, 150),  80),
    (75, (255,  55,  55), (255, 130, 130), 120),
    (60, (255, 140,   0), (255, 200, 100), 150),
    (50, (255, 214,   0), (255, 245, 130), 200),
    ( 0, ( 46, 204,  64), (140, 240, 160), 250),
]
for threshold, base, shim, speed in ZONES:
    if pct >= threshold:
        break

fg = lambda r, g, b: f"\033[1;38;2;{r};{g};{b}m"
R = "\033[0m"
text = f"CTX {pct}% | {tok} tokens"

# Critical (90%+): sinusoidal pulse across entire text (Claude Code tool-use flash)
if pct >= 90:
    t = (math.sin(now / 1000 * math.pi) + 1) / 2
    c = tuple(int(base[i] + (shim[i] - base[i]) * t) for i in range(3))
    print(f"\033[1;7;38;2;{c[0]};{c[1]};{c[2]}m{star} {text}{R}")
    sys.exit(0)

# Normal zones: spinner + 3-char shimmer sweep (continuous loop)
sweep = len(text)
pos = int(now / speed) % sweep
out = fg(*base) + star + R + " "
for i, ch in enumerate(text):
    out += (fg(*shim) if abs(i - pos) <= 1 else fg(*base)) + ch
print(out + R)

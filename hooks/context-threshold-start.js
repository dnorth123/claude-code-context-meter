#!/usr/bin/env node

// This hook fires on every startup, including fresh sessions where the user didn't
// save state from a prior session. This is intentional — it always loads the most
// recent state if one exists (useful for cold starts resuming prior work). If no
// state files exist, it exits silently.

const fs = require('fs');
const path = require('path');
const os = require('os');

async function main() {
  const statesDir = path.join(os.homedir(), '.claude', 'session-states');

  let files;
  try {
    files = fs.readdirSync(statesDir)
      .filter(f => f.startsWith('session-state-') && f.endsWith('.md'))
      .sort()
      .reverse();
  } catch {
    process.exit(0);
  }

  if (files.length === 0) {
    process.exit(0);
  }

  const latest = files[0];
  const filePath = path.join(statesDir, latest);
  let contents;
  try {
    contents = fs.readFileSync(filePath, 'utf8');
  } catch {
    process.exit(0);
  }

  if (contents.length > 4000) {
    contents = contents.slice(0, 4000) + `\n\n[Truncated \u2014 full state at ${filePath}]`;
  }

  const output = {
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: `Previous session state found (${latest}):\n${contents}`,
    },
  };

  process.stdout.write(JSON.stringify(output));
}

main().catch(() => process.exit(0));

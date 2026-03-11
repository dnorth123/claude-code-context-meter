#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

async function main() {
  let input;
  try {
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    input = JSON.parse(Buffer.concat(chunks).toString());
  } catch {
    process.exit(0);
  }

  if (input.stop_hook_active) {
    process.exit(0);
  }

  const claudeDir = path.join(os.homedir(), '.claude');
  const thresholdFile = path.join(claudeDir, 'context-threshold.json');
  const warningsFile = path.join(claudeDir, 'context-warnings.json');
  const sessionId = input.session_id || '';

  let pct = 0;
  try {
    pct = JSON.parse(fs.readFileSync(thresholdFile, 'utf8')).pct || 0;
  } catch {
    process.exit(0);
  }

  if (pct === 0) {
    process.exit(0);
  }

  let warnings = { session: '', w60: false, w75: false, w90: false };
  try {
    warnings = JSON.parse(fs.readFileSync(warningsFile, 'utf8'));
  } catch {
    // fresh start
  }

  if (sessionId && sessionId !== warnings.session) {
    warnings = { session: sessionId, w60: false, w75: false, w90: false };
    atomicWrite(warningsFile, warnings);
    process.exit(0);
  }

  if (!warnings.session && sessionId) {
    warnings.session = sessionId;
  }

  const preamble = 'Before responding, check if your previous turn was interrupted mid-output. If it was, note exactly where you were cut off so the user can say \'continue\' and you can pick up cleanly.';

  let reason = null;
  if (pct >= 90 && !warnings.w90) {
    warnings.w90 = true;
    reason = `Context at ${pct}% \u2014 quality degrades past this point. ${preamble} Tell the user to run /save-state and /clear now.`;
  } else if (pct >= 75 && !warnings.w75) {
    warnings.w75 = true;
    reason = `Context at ${pct}%. ${preamble} Then recommend the user run /save-state and /clear. Be direct, 2-3 sentences.`;
  } else if (pct >= 60 && !warnings.w60) {
    warnings.w60 = true;
    reason = `Context at ${pct}%. ${preamble} Then give a brief status: (1) what you were working on, (2) what's done vs remaining, (3) whether you recommend /save-state now or after completing the current step. 3-4 sentences total.`;
  }

  if (reason) {
    atomicWrite(warningsFile, warnings);
    process.stdout.write(JSON.stringify({ decision: 'block', reason }));
  }
}

function atomicWrite(filePath, data) {
  const dir = path.dirname(filePath);
  const tmp = path.join(dir, `.tmp-${process.pid}-${Date.now()}`);
  try {
    fs.writeFileSync(tmp, JSON.stringify(data));
    fs.renameSync(tmp, filePath);
  } catch {
    try { fs.unlinkSync(tmp); } catch {}
  }
}

main().catch(() => process.exit(0));

#!/usr/bin/env node
// trigger-ia-docs-audit.js — PostToolUse:Bash hook (optional)
//
// Detects `git push` and reminds Claude to run the ia-docs-update agent
// for any modules that changed. Uses Node.js instead of bash+jq to avoid
// the jq `//` operator bug where exit_code 0 is treated as falsy.
//
// Setup: Add to .claude/settings.json under PostToolUse:
//   { "matcher": "Bash", "hooks": [{ "type": "command",
//     "command": "node $CLAUDE_PROJECT_DIR/.claude/hooks/trigger-ia-docs-audit.js" }] }
//
// Configuration: reads ia-docs.config for SOURCE_DIR (default: "src")

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);

    const command = data.tool_input?.command || '';
    const exitCode = data.tool_response?.exit_code ?? 1;
    const stdout = data.tool_response?.stdout || '';
    const stderr = data.tool_response?.stderr || '';
    const cwd = data.cwd || '';

    // Only trigger on successful git push
    if (exitCode !== 0 || !command.includes('git push')) {
      process.exit(0);
    }

    // Load config
    const projectDir = process.env.CLAUDE_PROJECT_DIR || cwd;
    let sourceDir = 'src';

    const configPath = path.join(projectDir, 'ia-docs.config');
    if (fs.existsSync(configPath)) {
      const config = fs.readFileSync(configPath, 'utf8');
      const match = config.match(/^\s*SOURCE_DIR\s*=\s*(.+)/m);
      if (match) sourceDir = match[1].trim();
    }

    // Get changed modules from the push
    const fullOutput = stdout + stderr;

    // Try to extract commit range from push output (e.g. "abc1234..def5678")
    const rangeMatch = fullOutput.match(/([a-f0-9]+)\.\.([a-f0-9]+)/);

    let changedFiles = '';
    try {
      if (rangeMatch) {
        changedFiles = execSync(
          `git diff --name-only ${rangeMatch[1]}..${rangeMatch[2]} -- ${sourceDir}/`,
          { cwd: projectDir, encoding: 'utf8', timeout: 5000 }
        ).trim();
      }

      // Fallback: diff last 5 commits
      if (!changedFiles) {
        changedFiles = execSync(
          `git diff --name-only HEAD~5..HEAD -- ${sourceDir}/`,
          { cwd: projectDir, encoding: 'utf8', timeout: 5000 }
        ).trim();
      }
    } catch {
      process.exit(0);
    }

    if (!changedFiles) {
      process.exit(0);
    }

    // Extract unique module names from changed paths (e.g. src/app/{module}/...)
    // Handles both flat (src/module/) and nested (src/app/module/) structures
    const modules = [...new Set(
      changedFiles
        .split('\n')
        .map(f => {
          // Remove sourceDir prefix, get the first directory component
          const rel = f.replace(new RegExp(`^${sourceDir}/`), '');
          const parts = rel.split('/');
          // If there's a common grouping dir (like "app"), use the next level
          if (parts.length >= 3 && ['app', 'modules', 'features', 'lib'].includes(parts[0])) {
            return parts[1];
          }
          return parts[0];
        })
        .filter(Boolean)
    )].join(', ');

    if (!modules) {
      process.exit(0);
    }

    const message = `PUSH DETECTED — Modules with changes: ${modules}. Consider running the ia-docs-update agent to audit the docs for these modules.`;

    process.stdout.write(JSON.stringify({
      systemMessage: message,
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: message
      }
    }));
  } catch {
    // Silent fail — never block tool execution
    process.exit(0);
  }
});

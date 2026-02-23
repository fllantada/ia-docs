# IA-docs

**Hierarchical documentation for AI coding agents.**

Give [Claude Code](https://docs.anthropic.com/en/docs/claude-code) the right context at the right time — automatically. No frameworks, no dependencies beyond `jq`. Just two shell scripts, two agents, and a documentation philosophy.

## The problem

You're working on a large codebase and your AI agent keeps missing context. It edits the billing module without knowing about Stripe webhook idempotency. It refactors the auth flow without understanding the passwordless login gotchas. It creates a new module that breaks every convention you've established.

Putting everything in one root `CLAUDE.md` doesn't scale. At 20+ modules, the file becomes too large, and the agent drowns in irrelevant context when it only needs the rules for one specific area.

## The solution

Place small documentation files (`IA-docs.md`) at each level of your directory tree. A hook automatically injects the relevant docs whenever Claude Code edits a file — no manual reading required.

```
my-project/
├── IA-docs.md                    # Project context, tech stack, conventions
├── src/
│   ├── IA-docs.md                # Architecture patterns, anti-patterns
│   ├── app/
│   │   ├── auth/
│   │   │   ├── IA-docs.md        # Auth scope, gotchas, deprecated methods
│   │   │   └── ...code files
│   │   ├── billing/
│   │   │   ├── IA-docs.md        # Stripe rules, webhook idempotency
│   │   │   └── ...code files
```

When the agent edits `src/app/billing/checkout.ts`, the hook automatically injects:
1. `IA-docs.md` (project context)
2. `src/IA-docs.md` (architecture patterns)
3. `src/app/billing/IA-docs.md` (billing-specific rules)

The agent gets exactly what it needs — nothing more.

## How it works

Three layers of enforcement:

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| **Declaration** | `CLAUDE.md` instructions | Tells the agent the docs exist |
| **Injection** | PreToolUse hook | Forces docs into every edit automatically |
| **Maintenance** | Two agents | Keeps docs synchronized with code changes |

The hooks use **session-scoped deduplication** — once a doc is injected in a session, it won't be re-injected. This prevents context window bloat.

## Setup

### 1. Copy the hooks

```bash
# From your project root
mkdir -p .claude/hooks .claude/agents

cp hooks/enforce-ia-docs.sh .claude/hooks/
cp hooks/notify-ia-docs-read.sh .claude/hooks/
chmod +x .claude/hooks/*.sh

cp agents/ia-docs-create.md .claude/agents/
cp agents/ia-docs-update.md .claude/agents/
```

### 2. Create the config file

Create `ia-docs.config` at your project root:

```
SOURCE_DIR=src
DOC_FILENAME=IA-docs.md
```

- `SOURCE_DIR` — the directory subtree to enforce (e.g., `src`, `backend/src`, `app`)
- `DOC_FILENAME` — the filename for docs (default: `IA-docs.md`)

### 3. Configure Claude Code hooks

Add to `.claude/settings.json` (create it if it doesn't exist):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/enforce-ia-docs.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/notify-ia-docs-read.sh"
          }
        ]
      }
    ]
  }
}
```

### 4. Add the protocol to your CLAUDE.md

Add this to your project's `CLAUDE.md` so the agent knows the system exists:

```markdown
### IA-docs Protocol

This project uses hierarchical `IA-docs.md` files for AI context.

**Before editing any file in `src/`:**

1. Identify the file path
2. Read ALL `IA-docs.md` files in the hierarchy from root to the file's directory
3. Follow the documented patterns and rules

Example: editing `src/app/billing/checkout.ts`:
  1. IA-docs.md (project context)
  2. src/IA-docs.md (architecture patterns)
  3. src/app/billing/IA-docs.md (billing rules)

The hooks enforce this automatically, but understanding the hierarchy helps you make better decisions.
```

### 5. Create your first IA-docs

Start with two files:

**Root level** (`IA-docs.md`):
- Tech stack
- Architecture overview
- Module list with one-line descriptions
- Project-wide conventions

**Source level** (`src/IA-docs.md`):
- Code patterns (DDD layers, naming, etc.)
- Anti-patterns
- How to create a new module

Then use the `ia-docs-create` agent to generate module-level docs:

```
Use the ia-docs-create agent to create an IA-docs.md for the billing module.
```

The agent analyzes the code and proposes documentation for your review.

## Writing good IA-docs

### The governing principle

> **Document only what an AI cannot infer by reading the code directly.**

An AI can read your interfaces, routes, schemas, and folder structure. It does not need those copied into documentation. What it needs:

| Document this | Not this |
|---|---|
| Module scope and boundaries | Folder structure |
| Business rules invisible in code | Interface definitions |
| Domain terminology that names don't reveal | List of endpoints |
| Gotchas and traps | Dependency tables |
| Deprecated behavior | How standard patterns work |
| Non-obvious relationships between modules | Schema definitions |

### Target size

**30-60 lines per file. Absolute max: 80.**

If a doc exceeds 80 lines, it probably contains content the AI can infer on its own. The `ia-docs-update` agent will proactively flag excess content.

### Mandatory section: Responsibility

Every module-level IA-docs must start with what the module **does** and what it **does not do**:

```markdown
## Responsibility

Billing manages Stripe subscriptions, payments, and invoices.
Billing does NOT decide what features a plan grants (that's `entitlements/`),
nor handle user authentication (that's `auth/`).
```

This prevents the agent from accidentally mixing concerns across modules.

## Maintaining docs

After significant code changes, use the `ia-docs-update` agent:

```
Use the ia-docs-update agent to check if any IA-docs need updating after my recent changes.
```

The agent:
1. Runs `git diff` to detect what changed
2. Reads affected IA-docs
3. Evaluates if updates are needed
4. Proposes changes (never writes directly)
5. Flags excess content for removal

## The agents

Both agents are **read-only proposers**. They analyze code and suggest documentation changes, but never write files directly. You (or your parent agent) review and apply.

| Agent | Purpose | Tools |
|-------|---------|-------|
| `ia-docs-create` | Create new docs for modules that don't have one | Read, Grep, Glob |
| `ia-docs-update` | Update existing docs after code changes | Read, Grep, Glob, Bash |

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (hooks require Claude Code's hook system)
- `jq` (for JSON parsing in hooks — pre-installed on most systems)
- `git` (for the update agent's diff analysis)

## How it compares

**vs. one big CLAUDE.md**: IA-docs scales. Each file stays small (30-80 lines) and the agent only receives what's relevant to the file it's editing. A 200-line CLAUDE.md with 20 modules of context means 190 irrelevant lines on every edit.

**vs. hoping the agent reads docs**: The hook *injects* documentation automatically. The agent doesn't need to remember to read anything — it receives the right context whether it asks for it or not.

**vs. a documentation framework**: This is two bash scripts and some markdown. No build step, no runtime, no dependencies beyond `jq`. It works today and it'll work in two years.

## Background

This pattern was developed while building [Cliencer](https://www.cliencer.com), a 20+ module SaaS. The full story is in [this blog post](https://www.dev-fran.com/en/blog/hierarchical-ai-docs).

## License

MIT

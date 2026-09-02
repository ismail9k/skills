# AGENTS.md

Canonical instruction file for this repository, shared by all coding agents (Claude Code, Codex, Cursor, and others).
Claude Code reaches it through the `@AGENTS.md` import in `CLAUDE.md`. Repository guidance belongs here — not in `CLAUDE.md`, which is only a pointer.

## Agent configuration

Skill-managed settings live under `docs/agents/` as small, focused files rather than inline here, so each can be read by only the skill that needs it:

- `docs/agents/issue-tracker.md` — where issues/specs/intents live for this repo, and how to reach them (written by the `setup-agent-workflow` skill)

As more skills are adopted, each may add its own file here (e.g. triage labels, domain-doc layout). List them as they're added so this stays a table of contents, not a place where config itself accumulates.

## Workflow

1. Capture the intent issue on GitHub — `brainstorm-to-issue` skill.
2. If Superpowers is installed, hand the intent issue to Superpowers'
   `brainstorming` skill (seeded via `superpowers-issue-bridge`) to produce
   `spec.md`, then `writing-plans` for `plan.md`.
3. Build, test, review per Superpowers' usual flow.
4. Open the PR referencing the intent issue (`Closes #N` or `Relates to #N`
   per `superpowers-issue-bridge`).

## Project knowledge

<!--
Fill this in as the project develops. Keep it under a page — it's read in
full at the start of every session, so anything stale costs context for no
benefit. When an agent makes the same mistake twice, the correction belongs
here.
-->

### Commands

- Build:
- Test:
- Lint:

### Conventions

### Architecture

### Things agents get wrong

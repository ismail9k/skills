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

## What this repo is

A skill-authoring repo, not an application. It contains three Claude Code skills (plus their asset templates) that together define an intent → spec → plan → PR workflow bridging a GitHub issue tracker to the Superpowers skill suite.

There is no build, test, or lint step — the deliverables are Markdown. "Testing" a change means installing the skill and running it against a real repo.

## Layout convention

This repo is a plugin marketplace. `.claude-plugin/marketplace.json` lists the plugins it offers; each plugin lives under `plugins/<plugin-name>/` with its own `.claude-plugin/plugin.json` and one directory per skill:

```
plugins/intent-to-pr/
├── .claude-plugin/plugin.json
└── skills/
    ├── setup-agent-workflow/     SKILL.md + assets/
    ├── brainstorm-to-issue/      SKILL.md
    └── superpowers-issue-bridge/ SKILL.md
```

Keep each skill's frontmatter `name:` matching its directory name. The plugin name is the invocation prefix (`intent-to-pr:brainstorm-to-issue`), so renaming the plugin directory or its manifest `name` breaks every existing invocation and every doc that cites one — treat both as fixed.

Skills unrelated to this pipeline belong in a new `plugins/<name>/`, not as a fourth skill here. The plugin is the unit of scope; the marketplace is the unit of ownership.

`skills/setup-agent-workflow/assets/AGENTS.md` and `.../assets/CLAUDE.md` are the templates `setup-agent-workflow` writes into a target repo. They are the single source for those two files — [the skill](plugins/intent-to-pr/skills/setup-agent-workflow/SKILL.md) points at them by relative path instead of inlining them, so **edit the assets, not the skill,** when a template changes.

## The pipeline these three skills form

The skills are deliberately sequential and each one's doc explicitly disclaims the next one's job. Preserve that separation when editing:

1. **[setup-agent-workflow](plugins/intent-to-pr/skills/setup-agent-workflow/SKILL.md)** — run once per target repo. Writes `AGENTS.md` + a `CLAUDE.md` that only does `@AGENTS.md`, and records the tracker backend (GitHub / local markdown / freeform) in `docs/agents/issue-tracker.md`. Every later skill reads that file rather than guessing a repo.
2. **[brainstorm-to-issue](plugins/intent-to-pr/skills/brainstorm-to-issue/SKILL.md)** — captures *intent* only, as an intent issue using a fixed five-section body (Problem / Proposed outcome / Affected users and systems / Constraints / Open questions). Deliberately does **not** do spec work (alternatives, out-of-scope, edge cases).
3. **[superpowers-issue-bridge](plugins/intent-to-pr/skills/superpowers-issue-bridge/SKILL.md)** — feeds that intent issue into Superpowers' own `brainstorming` (→ `spec.md`) and `writing-plans` (→ `plan.md`), and governs how the PR references the issue.

The two contracts that hold the pipeline together:

- `docs/agents/issue-tracker.md` in the *target* repo — the shared config any new skill in this family should read from and extend (as its own file under `docs/agents/`, never inline in `AGENTS.md`).
- The `Intent-Issue: #<number> — <url>` header line, written into `spec.md` and carried unchanged into `plan.md`, so artifacts trace back to the issue.

## Editorial conventions for skill files

- Every skill ends with a **"What NOT to do"** section listing the failure modes (fabricating content for empty sections, guessing a repo or issue number, silently overwriting files, one skill absorbing another's scope). New skills should follow the same shape.
- Skills prescribe *asking* rather than defaulting at the ambiguous points — `Closes #N` vs `Relates to #N`, overwriting an existing `AGENTS.md`, which brainstorming stage applies. Don't "simplify" those into silent defaults; the ask is the point.
- The bridge is intentionally a separate skill from Superpowers' own files so Superpowers updates can't clobber it. Don't propose merging it in.
- `brainstorm-to-issue` carries a "Non-Claude-Code version (plain prompt)" section for agents without skill discovery. Keep it in sync with the template above it.

## Naming

The issue that starts the pipeline is an **intent issue** — named for its role, matching the `intent` label `brainstorm-to-issue` applies. It is referenced as `Intent-Issue: #<number> — <url>` in `spec.md` and `plan.md`. Avoid reintroducing "hub", which reads as a truncation of "GitHub" in this context.

### Where each artifact sits in the SDLC

| Artifact | SDLC phase |
| --- | --- |
| Intent issue | Problem definition — the planning → requirements boundary |
| `spec.md` | Design |
| `plan.md` | Work breakdown / implementation planning |
| PR | Implementation |

Two misreadings this table exists to head off:

- **"The intent issue is the plan phase."** `plan.md` is a task breakdown for
  implementation, downstream of the spec — the opposite end of the pipeline
  from intent. Say *problem definition*, not *planning*, when describing what
  the intent issue captures.
- **"The intent issue is a product-management artifact."** The outcome framing
  is PM-shaped, but plenty of valid intent issues are purely technical ("CI
  takes 40 minutes and blocks releases") and fill all five sections cleanly.
  It is *outcome-level problem framing*, not a role's deliverable — and not a
  PRD: no success metrics, no acceptance criteria, no priority.

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

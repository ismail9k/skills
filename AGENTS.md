# AGENTS.md

Canonical instruction file for this repository, shared by all coding agents (Claude Code, Codex, Cursor, and others).
Claude Code reaches it through the `@AGENTS.md` import in `CLAUDE.md`. Repository guidance belongs here — not in `CLAUDE.md`, which is only a pointer.

## Agent configuration

Skill-managed settings live under `docs/agents/` as small, focused files rather than inline here, so each can be read by only the skill that needs it:

- `docs/agents/issue-tracker.md` — where issues/specs/intents live for this repo, and how to reach them (written by the `configure-issue-tracker` skill)

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

A skill-authoring repo, not an application. `configure-issue-tracker`, `brainstorm-to-issue`, and `superpowers-issue-bridge` define an intent → spec → plan → PR workflow bridging an issue tracker to the Superpowers skill suite. `agent-md-setup` is generic repository setup rather than part of that pipeline. `anti-koshary` is also **not part of the pipeline** — it is a standalone two-pass codebase audit that happens to be authored here. Keep it that way: it must not grow a dependency on `docs/agents/issue-tracker.md` or on an intent issue, because the whole point is that it works on any repo, cold.

Six skills in three groups. Know which group you are editing before you change one:

| Group | Skills | Shares state? |
| --- | --- | --- |
| **Pipeline** | `configure-issue-tracker` → `brainstorm-to-issue` → `superpowers-issue-bridge` | Yes — via `docs/agents/issue-tracker.md` and the `Intent-Issue:` header |
| **Utility** | `agent-md-setup`, `fetch-github-issues` | No — each does one job for any repo |
| **Audit** | `anti-koshary` | No — deliberately depends on nothing |

There is no build or lint step — the deliverables are Markdown. `bash scripts/check.sh` is the test step: it verifies the things that can silently rot here (names, manifest coverage, cross-skill coupling, and whether `anti-koshary`'s regexes still match a planted hit). Beyond that, "testing" a change means installing the skill and running it against a real repo.

## Layout convention

One directory per skill under `skills/`, each holding a `SKILL.md` and whatever assets it ships:

```
skills/
├── agent-md-setup/           SKILL.md + assets/
├── configure-issue-tracker/  SKILL.md + assets/
├── brainstorm-to-issue/      SKILL.md
├── superpowers-issue-bridge/ SKILL.md
├── fetch-github-issues/      SKILL.md
└── anti-koshary/             SKILL.md + references/ + scripts/
```

Three things must agree on a skill's name: the **directory**, the skill's **frontmatter `name:`**, and its entry in **`.claude-plugin/plugin.json`**'s `skills` array. That name is how the skill is invoked and how `npx skills add ismail9k/skills@<name>` selects it, so adding or renaming one means editing all three plus every doc that cites it — README, this file, and any skill that recommends it by name.

This has already gone wrong once: a directory was renamed and the manifest kept pointing at the old path, so the skill shipped from neither. `bash scripts/check.sh` exists to catch that; run it after any rename.

**Skills here are installed individually**, so each directory must be self-sufficient. Never factor shared content into a file two skills both read — a skill installed on its own arrives with nothing but its own directory. Skills reference each other by name only, never by path.

`skills/agent-md-setup/assets/AGENTS.md` and `.../assets/CLAUDE.md` are the complete templates that skill writes into a target repo. `skills/configure-issue-tracker/assets/AGENTS-sections.md` is the source for the tracker and workflow sections its skill may merge into an existing `AGENTS.md`. Edit those assets, not copies in the skill prose, when generated content changes.

## The pipeline these three skills form

The workflow skills are deliberately sequential and each one's doc explicitly disclaims the next one's job. Preserve that separation when editing. `agent-md-setup` may run first when shared instruction files are wanted, but tracker configuration does not depend on it.

1. **[configure-issue-tracker](skills/configure-issue-tracker/SKILL.md)** — records the tracker backend (GitHub / local markdown / freeform) in `docs/agents/issue-tracker.md`. Later skills read that file rather than guessing a repo.
2. **[brainstorm-to-issue](skills/brainstorm-to-issue/SKILL.md)** — captures *intent* only, as an intent issue using a fixed five-section body (Problem / Proposed outcome / Affected users and systems / Constraints / Open questions). Deliberately does **not** do spec work (alternatives, out-of-scope, edge cases).
3. **[superpowers-issue-bridge](skills/superpowers-issue-bridge/SKILL.md)** — feeds that intent issue into Superpowers' own `brainstorming` (→ `spec.md`) and `writing-plans` (→ `plan.md`), and governs how the PR references the issue.

The two contracts that hold the pipeline together:

- `docs/agents/issue-tracker.md` in the *target* repo — the shared config any new skill in this family should read from and extend (as its own file under `docs/agents/`, never inline in `AGENTS.md`).
- The `Intent-Issue: #<number> — <url>` header line, written into `spec.md` and carried unchanged into `plan.md`, so artifacts trace back to the issue.

## Editorial conventions for skill files

- Every skill ends with a **"What NOT to do"** section listing the failure modes (fabricating content for empty sections, guessing a repo or issue number, silently overwriting files, one skill absorbing another's scope). New skills should follow the same shape.
- Skills prescribe *asking* rather than defaulting at the ambiguous points — `Closes #N` vs `Relates to #N`, overwriting an existing `AGENTS.md`, which brainstorming stage applies. Don't "simplify" those into silent defaults; the ask is the point.
- The bridge is intentionally a separate skill from Superpowers' own files so Superpowers updates can't clobber it. Don't propose merging it in.
- `brainstorm-to-issue` carries a "Non-Claude-Code version (plain prompt)" section for agents without skill discovery. Keep it in sync with the template above it.
- `anti-koshary` carries one too, condensed from its own body — it started life as a paste-able prompt, and that form stays supported. Keep it in sync with the seven Pass 1 sections.
- `anti-koshary`'s value lives in `references/` and `scripts/`, not in the SKILL.md prose. The two things models do badly are (a) reporting `.env.example` and test fixtures as leaked secrets, and (b) flagging coincidental duplication as if it were coupling — those are exactly what the reference files exist to prevent, so don't thin them out to save lines.
- `anti-koshary` is structure-first on purpose: layer collapse and duplication are Pass 1 sections 1–5, security and dependencies are section 7. Models drift toward leading with security because it feels more urgent — don't let the ordering get "corrected" back. The one exception is Pass 2, which fixes a Critical finding first; that is a safety property, not an emphasis one. `references/structural-decay.md` is ordered to match sections 1–5, so reordering one means reordering the other.
- The regex patterns in `references/security-checks.md` run under `git grep -E` (POSIX ERE), where `\s` and `\b` are **not** supported and fail silently by matching nothing. Use `[[:space:]]` and an explicit `(^|[^[:alnum:]_.])` prefix instead.
- **Every** shell snippet in `references/` must be tested against a file containing a known hit, not just the `git grep -E` ones — a broken pattern looks exactly like a clean repo. The rule was once scoped to `git grep` alone, and a plain `grep -v` whose BRE alternation never fired slipped through it, silently reporting `.env.example` as a leaked secret. `bash scripts/check.sh` runs every pattern against a fixture with planted hits, plus negative cases for the false positives they exist to suppress; add to that fixture when you add a pattern.

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

```bash
bash scripts/check.sh                              # the test step — run before every commit
npx skills add ismail9k/skills@<name>              # install one skill, the real end-to-end test
bash skills/anti-koshary/scripts/dep_audit.sh DIR  # the one executable a skill ships
```

There is no build or lint step; see **What this repo is**.

### Things agents get wrong

- Renaming a skill directory without updating `.claude-plugin/plugin.json`, which silently unships it.
- Editing a template's copy inside a SKILL.md instead of the `assets/` file that is its source.
- Changing a `references/` regex without running it against a known hit.

# AGENTS.md

Canonical instruction file for this repository, shared by all coding agents (Claude Code, Codex, Cursor, and others).
Claude Code reaches it through the `@AGENTS.md` import in `CLAUDE.md`. Repository guidance belongs here — not in `CLAUDE.md`, which is only a pointer.

## Agent configuration

Skill-managed settings live under `docs/agents/` as small, focused files rather than inline here, so each can be read by only the skill that needs it:

- `docs/agents/issue-tracker.md` — where issues and intents live for this repo, how to read them, and how finished work links back to them (written by the `setup-issue-tracker` skill)

As more skills are adopted, each may add its own file here (e.g. triage labels, domain-doc layout). List them as they're added so this stays a table of contents, not a place where config itself accumulates.

## Workflow

1. Talk the problem through — with Superpowers' `brainstorming` when it is
   installed. For work with no intent issue, once the problem is understood
   and before any approach is proposed, ask: build it now, or track it first?
   `superpowers-issue-bridge` defines this step.
2. **Build now:** continue with the usual development workflow — spec, plan,
   code, and pull request. No intent issue is involved.
3. **Track first:** `brainstorm-to-issue` files an intent issue in the tracker
   recorded in `docs/agents/issue-tracker.md`, with any decisions already made
   under Constraints. The session ends there.
4. To build a tracked issue, reference it (for example, "implement #42").
   `superpowers-issue-bridge` seeds brainstorming from the issue and carries
   its reference into the spec and plan.
5. When the work lands, link it back using the Linking section of
   `docs/agents/issue-tracker.md`. `superpowers-issue-bridge` asks whether the
   work fully resolves the issue, which closes it, or is partial.

## What this repo is

A skill-authoring repo, not an application. `setup-issue-tracker`, `brainstorm-to-issue`, and `superpowers-issue-bridge` bridge an issue tracker to the Superpowers skill suite: a Superpowers brainstorm either builds now or files an intent issue to build later, and the work built from an intent issue carries its reference through spec, plan, and PR, then links back to close it. `implement-issues`, `review-prs`, and `answer-pr-reviews` carry that past the issue: agents build tracked issues into draft PRs, a separate agent reviews each one with `review-prs`, and the building agent answers the review with `answer-pr-reviews` before the PR is marked ready. `review-prs` also reviews any PR on its own, and `answer-pr-reviews` answers the review on any PR. `setup-agent-md` is generic repository setup rather than part of that pipeline. `anti-koshary` is also **not part of the pipeline** — it is a standalone two-pass codebase audit that happens to be authored here. Keep it that way: it must not grow a dependency on `docs/agents/issue-tracker.md` or on an intent issue, because the whole point is that it works on any repo, cold.

Nine skills in four groups. Know which group you are editing before you change one:

| Group | Skills | Shares state? |
| --- | --- | --- |
| **Pipeline** | `setup-issue-tracker` → `brainstorm-to-issue` → `superpowers-issue-bridge` | Yes — via `docs/agents/issue-tracker.md` and the `Intent-Issue:` header |
| **Delivery** | `implement-issues` → `review-prs` → `answer-pr-reviews` | Yes — read `docs/agents/issue-tracker.md`; `implement-issues` builds on `fetch-issues`, the bridge, and Superpowers, and dispatches `review-prs` and then `answer-pr-reviews` on each PR it opens |
| **Utility** | `setup-agent-md`, `fetch-issues` | No — each does one job for any repo (`fetch-issues` reads the tracker config when present, but needs nothing else) |
| **Audit** | `anti-koshary` | No — deliberately depends on nothing |

There is no build or lint step — the deliverables are Markdown. `bash scripts/check.sh` is the test step: it verifies the things that can silently rot here (names, manifest coverage, cross-skill coupling, and whether `anti-koshary`'s regexes still match a planted hit). Beyond that, "testing" a change means installing the skill and running it against a real repo.

## Layout convention

One directory per skill under `skills/`, each holding a `SKILL.md` and whatever assets it ships:

```
skills/
├── setup-agent-md/           SKILL.md + assets/
├── setup-issue-tracker/      SKILL.md + assets/
├── brainstorm-to-issue/      SKILL.md + assets/
├── superpowers-issue-bridge/ SKILL.md
├── fetch-issues/             SKILL.md
├── implement-issues/         SKILL.md + assets/
├── review-prs/               SKILL.md
├── answer-pr-reviews/        SKILL.md
└── anti-koshary/             SKILL.md + references/ + scripts/
```

Three things must agree on a skill's name: the **directory**, the skill's **frontmatter `name:`**, and its entry in **`.claude-plugin/plugin.json`**'s `skills` array. That name is how the skill is invoked and how `npx skills add ismail9k/skills@<name>` selects it, so adding or renaming one means editing all three plus every doc that cites it — README, this file, and any skill that recommends it by name.

This has already gone wrong once: a directory was renamed and the manifest kept pointing at the old path, so the skill shipped from neither. `bash scripts/check.sh` exists to catch that; run it after any rename.

**Skills here are installed individually**, so each directory must be self-sufficient. Never factor shared content into a file two skills both read — a skill installed on its own arrives with nothing but its own directory. Skills reference each other by name only, never by path.

`skills/setup-agent-md/assets/AGENTS.md` and `.../assets/CLAUDE.md` are the complete templates that skill writes into a target repo. `skills/setup-issue-tracker/assets/AGENTS-sections.md` is the source for the tracker and workflow sections its skill may merge into an existing `AGENTS.md`. `skills/brainstorm-to-issue/assets/intent-issue.md` is the body template for every intent issue. `skills/implement-issues/assets/issue-brief.md` and `.../assets/pr-body.md` are the brief each per-issue agent receives and the body of each pull request it leads to. Edit those assets, not copies in the skill prose, when generated content changes.

## The pipeline these three skills form

The workflow skills are deliberately sequential and each one's doc explicitly disclaims the next one's job. Preserve that separation when editing. `setup-agent-md` may run first when shared instruction files are wanted, but tracker configuration does not depend on it.

1. **[setup-issue-tracker](skills/setup-issue-tracker/SKILL.md)** — records the tracker backend (GitHub / local markdown / freeform) in `docs/agents/issue-tracker.md`, plus its Reading and Linking conventions: how to list and read issues, and what a PR writes to close or reference one. Later skills read that file rather than guessing a repo or assuming GitHub syntax.
2. **[brainstorm-to-issue](skills/brainstorm-to-issue/SKILL.md)** — the track-first ending of a brainstorm. Captures *intent*, as an intent issue using a fixed five-section body (Problem / Proposed outcome / Affected users and systems / Constraints / Open questions). Constraints carries the decisions the user already made — it is the section implementers, including agents that can't ask, treat as binding. Deliberately does **not** do spec work (approaches only considered, edge cases, undecided design).
3. **[superpowers-issue-bridge](skills/superpowers-issue-bridge/SKILL.md)** — offers build-now / track-first inside Superpowers' `brainstorming`, seeds `brainstorming` from an existing intent issue, carries `Intent-Issue:` into the spec and plan, and links the finished work back through the tracker's Linking convention.

The two contracts that hold the pipeline together:

- `docs/agents/issue-tracker.md` in the *target* repo, including its Reading and Linking sections — the shared config any new skill in this family should read from and extend (as its own file under `docs/agents/`, never inline in `AGENTS.md`).
- The `Intent-Issue: <reference> — <url>` header line (`#<number>` on GitHub), written into the spec and carried unchanged into the plan, so artifacts trace back to the issue. Only Superpowers' architectural path writes those files; for spike and bounded work, the PR or merge link is the only trace.

## Editorial conventions for skill files

- Every skill ends with a **"What NOT to do"** section listing the failure modes (fabricating content for empty sections, guessing a repo or issue number, silently overwriting files, one skill absorbing another's scope). New skills should follow the same shape.
- Skills prescribe *asking* rather than defaulting at the ambiguous points — build now vs track first, full vs partial resolution (`Closes #N` vs `Relates to #N`), overwriting an existing `AGENTS.md`. Don't "simplify" those into silent defaults; the ask is the point.
- Pipeline skills take issue references and link syntax from the Reading and Linking sections of `docs/agents/issue-tracker.md`. `#<number>`, `gh`, and `Closes` are the GitHub values, not defaults for every tracker — a skill step that hardcodes them without a GitHub condition breaks Jira and local-markdown users.
- The bridge is intentionally a separate skill from Superpowers' own files so Superpowers updates can't clobber it. Don't propose merging it in.
- `implement-issues`, `review-prs`, and `answer-pr-reviews` must run in any capable agent — Claude Code, Codex, Gemini CLI, and others; `implement-issues` needs one that can dispatch subagents. Write them in actions ("dispatch an agent", "choose a model"), never one platform's tool names, and never hardcode a model name: offer the models the platform's dispatch accepts at run time. Superpowers' per-platform tool references follow the same rule.
- `implement-issues` never merges and never pushes the base branch; `review-prs` never approves, requests changes, or pushes to a PR branch; `answer-pr-reviews` never force-pushes, resolves a thread, approves, merges, or marks a PR ready. All three hand the final call to the user — keep it that way. Marking a PR ready is not accepting it: `implement-issues` marks its drafts ready once their review is answered, and merging stays the user's. The review round reuses skills rather than restating them: a new agent runs `review-prs`, and the agent that built the issue answers with `answer-pr-reviews` — it, never `review-prs`, pushes the fixes, and it never reviews its own PR. Don't add briefs that re-describe what those skills already do.
- `answer-pr-reviews` is a proxy: it points Superpowers' `receiving-code-review` at pull requests — picking them, gathering the unanswered feedback, pushing, and replying — and leaves every judgment about the feedback to that skill. Don't grow it a copy of that skill's rules. Its replies end with `<!-- answer-pr-reviews -->`, which is how it tells answered threads from unanswered ones when one `gh` account posts both the review and the replies; don't swap it for an author check.
- `brainstorm-to-issue` carries a "Non-Claude-Code version (plain prompt)" section for agents without skill discovery. Keep it in sync with `assets/intent-issue.md`.
- `anti-koshary` carries one too, condensed from its own body — it started life as a paste-able prompt, and that form stays supported. Keep it in sync with the seven Pass 1 sections.
- `anti-koshary`'s value lives in `references/` and `scripts/`, not in the SKILL.md prose. The two things models do badly are (a) reporting `.env.example` and test fixtures as leaked secrets, and (b) flagging coincidental duplication as if it were coupling — those are exactly what the reference files exist to prevent, so don't thin them out to save lines.
- `anti-koshary` is structure-first on purpose: layer collapse and duplication are Pass 1 sections 1–5, security and dependencies are section 7. Models drift toward leading with security because it feels more urgent — don't let the ordering get "corrected" back. The one exception is Pass 2, which fixes a Critical finding first; that is a safety property, not an emphasis one. `references/structural-decay.md` is ordered to match sections 1–5, so reordering one means reordering the other.
- The regex patterns in `references/security-checks.md` run under `git grep -E` (POSIX ERE), where `\s` and `\b` are **not** supported and fail silently by matching nothing. Use `[[:space:]]` and an explicit `(^|[^[:alnum:]_.])` prefix instead.
- **Every** shell snippet in `references/` must be tested against a file containing a known hit, not just the `git grep -E` ones — a broken pattern looks exactly like a clean repo. The rule was once scoped to `git grep` alone, and a plain `grep -v` whose BRE alternation never fired slipped through it, silently reporting `.env.example` as a leaked secret. `bash scripts/check.sh` runs every pattern against a fixture with planted hits, plus negative cases for the false positives they exist to suppress; add to that fixture when you add a pattern.

## Naming

The issue that starts the pipeline is an **intent issue** — named for its role, matching the `intent` label `brainstorm-to-issue` applies. It is referenced as `Intent-Issue: <reference> — <url>` (`#<number>` on GitHub) in the spec and plan. Avoid reintroducing "hub", which reads as a truncation of "GitHub" in this context.

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

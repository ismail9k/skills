---
name: superpowers-issue-bridge
description: >
  Connects a GitHub issue (created by brainstorm-to-issue) to Superpowers'
  brainstorming, writing-plans, and PR-creation stages, so the intent captured
  in the issue seeds the spec instead of being re-derived from scratch, and
  every downstream artifact traces back to the issue. Use whenever Superpowers'
  brainstorming or writing-plans is about to run — including when it is unknown
  whether an intent issue exists, since establishing that is this skill's first
  step — or when a PR is being opened for work that started from one.
---

# Superpowers Issue Bridge

## Relationship to other skills — read this first

- `brainstorm-to-issue` produces the intent issue: a short Problem / Proposed
  outcome / Affected users and systems / Constraints / Open questions
  write-up. It runs BEFORE any code-focused work starts.
- Superpowers' own `brainstorming` skill produces the full `spec.md`: a
  longer interview covering implementation-relevant detail (alternatives
  considered, what's explicitly out of scope, edge cases) that intent
  capture doesn't attempt.
- These are sequential, not competing. If the user says something like
  "let's brainstorm X" with no intent issue yet and no code context, that's
  `brainstorm-to-issue` territory. If an intent issue already exists and the
  user is ready to move to implementation planning, that's Superpowers'
  `brainstorming`, seeded by this bridge. When it's ambiguous which one
  applies, ask rather than guessing — don't let one silently absorb the
  other's job.

## Step 1 — Identify the intent issue

Before invoking Superpowers' `brainstorming`, determine if an intent issue
exists for this work:

- The user references one directly ("build #42", "let's implement the
  claims-status issue").
- The current branch name encodes an issue number (e.g. `42-claims-status`).
- Ask, if neither is present — don't assume there isn't one just because
  it wasn't mentioned, and don't guess a number.

If there truly is no intent issue (e.g. a quick fix with no prior intent
capture), proceed with Superpowers' `brainstorming` unmodified — this
bridge has nothing to add.

## Step 2 — Seed brainstorming from the issue

```bash
gh issue view <number> --json title,body,url
```

Pass the issue's Problem / Proposed outcome / Affected users and systems /
Constraints / Open questions into the `brainstorming` skill's context as
already-answered. The interview should:

- Not re-ask what the issue already states.
- Still ask what the issue doesn't cover — alternatives, out-of-scope
  boundaries, technical constraints, edge cases.
- Explicitly carry forward the issue's "Open questions" section as
  questions still needing an answer, unless the conversation resolves them.

## Step 3 — Trace the artifact back to the issue

When `brainstorming` writes `spec.md`, add this to its header (alongside
whatever front matter Superpowers already writes):

```markdown
Intent-Issue: #<number> — <url>
```

When `writing-plans` writes `plan.md` from that spec, carry the same line
forward unchanged. This is what makes `gh issue view <number>` and a repo
search both lead back to the same thread later.

## Step 4 — Reference the issue in the PR

When Superpowers' `finishing-a-development-branch` or
`subagent-driven-development` is about to open the PR, ask the user one
thing: **does this PR fully resolve the intent issue, or is it partial work
toward it?**

- Fully resolves it → include `Closes #<number>` in the PR body (GitHub
  auto-closes the issue on merge).
- Partial → include `Relates to #<number>` instead (no auto-close; the intent
  issue stays open for further PRs).

Don't default silently to `Closes` — an intent issue is often bigger than one
PR, and auto-closing it prematurely breaks the audit trail this whole
setup exists to protect.

## What NOT to do

- Don't merge this bridge's logic into Superpowers' own skill files —
  keep it as a separate skill so Superpowers updates don't clobber it.
- Don't let this skill re-interview the user on things the intent issue
  already answered.
- Don't assume `Closes` vs `Relates to` — always ask once per PR.
- Don't invent an intent issue number — if it can't be found or confirmed,
  proceed without one rather than guessing.

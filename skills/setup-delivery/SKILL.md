---
name: setup-delivery
description: >
  Use when a repository should save implement-issues' delivery settings once
  instead of answering them on every run — default effort, plan approval, a
  preset or a model for each agent, the models behind each tier, and whether
  Codex reviews — or when docs/agents/delivery.md is missing or stale.
  Optional: implement-issues asks for anything this file doesn't settle.
argument-hint: "[budget|balanced|max]"
---

# Setup Delivery

Save the settings `implement-issues` reads before every run in
`docs/agents/delivery.md`, so its runs stop asking for them. This skill is
optional: without the file, `implement-issues` asks for what it needs on each
run and offers to save the answers. Run this skill when you'd rather decide
once, or to change the settings later.

This skill writes one local file. It doesn't run `implement-issues`, create
issues or labels, or change `AGENTS.md` without asking.

## Inspect first

1. Read `docs/agents/delivery.md` in full, if it exists. Its shape is
   `assets/delivery.md`.
2. Note the models your platform's dispatch accepts right now — its model
   options or spawn allowlist. Offer only those, never a name remembered
   from elsewhere.
3. Summarize what the file already settles, and what it leaves open, before
   asking anything.

## Ask

Ask only what the user wants to set or change. On a re-run, start from the
file's values and ask which to change. Group the questions; don't ask one
setting per message.

1. **Effort** — `low`, `medium` or `high`, the default for a run started
   without one. Optional: with no line, `implement-issues` asks each run.
2. **Plan approval** — on (each issue's spec and plan wait on a draft plan
   pull request until the `plan-approved` label is added) or off.
3. **Models.** Offer a preset first, or "set each agent". A preset sets
   every agent in one word; it is written in tiers:

   | Agent | budget | balanced | max |
   | --- | --- | --- | --- |
   | Planner | strong | strong | strong |
   | Build lead | standard | standard | strong |
   | Implementers | cheap | standard | strong |
   | Task reviewers | standard | standard | strong |
   | Review agent | standard | standard | strong |
   | PR code reviewer | standard | strong | strong |

   "Set each agent" asks the six in one question. A value is a tier, `session`,
   an exact model name, `by-task` for Implementers, or — for Review agent
   only — `codex:` with a tier or a Codex model name. Then offer, as
   optional, a Seats row for any single seat the user wants to differ from
   its agent.
4. **Tiers.** When any value is a tier, ask what `cheap`, `standard` and
   `strong` mean on this platform, in one question. When the Review agent
   uses `codex:` with a tier, ask the same for the `codex` column.
5. **Codex.** When the Review agent uses `codex:`, check it now, so a broken
   setup shows here and not in the middle of a run: `codex --version`
   succeeds; `codex login status` exits 0; `review-prs` is installed for
   Codex — in the repository's `.agents/skills/`, in `~/.agents/skills/`, or
   in `$CODEX_HOME/skills/` (default `~/.codex/skills/`); and each Codex
   model answers, with exit 0:

   ```bash
   codex exec --ephemeral -s read-only -m "<model>" "Reply with the single word OK."
   ```

   When one fails, say which and how to fix it, and ask whether to save the
   Codex value anyway or choose another Review agent.

## Write the file

Create `docs/agents/` if needed, preserving every file already there. Write
`docs/agents/delivery.md` in the shape of `assets/delivery.md`, with only the
sections the user settled: a section left out means `implement-issues` asks
for it or falls back. Show the diff and write only on the user's yes.
Re-running with the same answers changes nothing.

If root-level `AGENTS.md` has an `Agent configuration` section, offer to add
one line pointing to `docs/agents/delivery.md`. Show it and add it only on
the user's yes. Leave `AGENTS.md` alone otherwise.

## Finish

Read the file back and report what it settles, what it leaves to each run,
and the result of any Codex check. Stop without running `implement-issues`.

## What NOT to do

- Don't write a model your platform's dispatch doesn't accept, or a Codex
  model that failed its check, without the user choosing to.
- Don't put `codex:` on any agent but Review agent: Codex is for reviews
  only.
- Don't overwrite a populated `delivery.md` without showing the diff and
  receiving a yes.
- Don't fill sections the user didn't settle with defaults; leave them out.
- Don't create `AGENTS.md`, or change it beyond the one approved line.
- Don't run `implement-issues`, or create issues, labels or pull requests,
  as part of setup.

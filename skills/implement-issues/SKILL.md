---
name: implement-issues
description: >
  Use when the user wants several open issues built by agents and turned into
  pull requests — "work through the issues", "implement the open issues",
  "clear the backlog", "open PRs for #12 and #15" — in Claude Code, Codex, or
  any agent that can dispatch subagents. Not for one issue the user is
  building themselves in this session.
---

# Implement Issues

Build open issues with agents, one pull request per issue. Each issue goes
through the flow a person would take it through — a spec seeded from the
issue, a plan, and Superpowers' `subagent-driven-development` — except that
no one answers questions along the way. Every decision an agent makes on the
user's behalf lands in its pull request, where the user reviews it.

You are the dispatcher. Agents write code in their own worktrees; you own
everything that leaves the machine — pushes and pull requests — and the
verdict on each agent's work.

This skill names actions — "dispatch an agent", "choose a model" — not tools.
Use your platform's equivalents.

## Requirements

- Superpowers (`brainstorming`, `writing-plans`, `subagent-driven-development`,
  `finishing-a-development-branch`), plus the `fetch-issues` and
  `superpowers-issue-bridge` skills. If one is missing, name it and stop.
- A forge CLI to push and open pull requests — `gh` on GitHub, with
  `gh auth status` passing.

## Stage 1 — Build the queue

1. Get the open issues with `fetch-issues`. If the user named issues ("#12
   and #15"), keep only those.
2. Read `docs/agents/issue-tracker.md` for its Linking section — it decides
   what each pull request writes to close its issue.
3. Skip an issue, and record why, when an open pull request already
   references it or a branch already carries its reference (`feat/42-*`,
   `fix/42-*`).
4. An issue whose body references another queued issue depends on it: build
   it after that one, branched from that issue's branch instead of the base
   branch, and say so in its pull request.
5. Find the base branch — the remote's default branch — and fetch it.

Print the queue (reference, title, branch, dependency) and the skipped list.

## Stage 2 — Ask two questions

Ask both before dispatching anything. With the printed queue, the answers are
the user's go-ahead for the whole run — including pushing a branch and opening
a pull request for each issue.

1. **Which model should the implementers use?** Offer the models your
   platform's dispatch accepts right now — its model options or spawn
   allowlist, never a name remembered from elsewhere. If your platform can't
   set a model per dispatch, say so and use its default. The choice applies
   to implementers only; reviewers keep `subagent-driven-development`'s own
   model rules.
2. **Sequential or parallel?** Sequential builds one issue at a time.
   Parallel builds up to N at once — ask for N, suggesting 3. Offer parallel
   only if your platform can run several dispatched agents at the same time.

## Stage 3 — Dispatch one agent per issue

For each issue, create its branch and worktree, then dispatch its agent.

- **Branch:** `fix/<ref>-<slug>` for an issue labeled as a bug, otherwise
  `feat/<ref>-<slug>`. `<ref>` is the issue's reference without `#` (`42`,
  `PROJ-123`); `<slug>` is the title lowercased, each run of characters
  outside `a-z0-9` replaced by `-`, trimmed to 40 characters.
- **Worktree:** `.worktrees/<ref>-<slug>`, created with git from the base
  branch, or from the dependency's branch. Keep `.worktrees/` out of commits:
  if `git check-ignore -q .worktrees` fails, add it to `.git/info/exclude`.

  ```bash
  git worktree add -b "<branch>" ".worktrees/<ref>-<slug>" "origin/<base>"
  ```

- **Agent:** fill in `assets/issue-brief.md` and dispatch it as a background
  agent on this session's own model — it writes the spec and plan, which is
  design work. The implementer model from Stage 2 travels inside the brief.
  Sequential: one agent at a time. Parallel: up to N at once, starting the
  next as each finishes. Keep each agent's identity; Stage 4 may message it.

## Stage 4 — Verify each finished issue

When an agent reports back:

1. A `BLOCKED` or `NEEDS_DESIGN_SESSION` report, or no commits on the branch,
   means no pull request. Keep the worktree and record why.
2. Check the work yourself inside its worktree: read
   `git log origin/<base>..HEAD` and the diff, and run the project's test,
   lint, and typecheck commands (from `AGENTS.md` or the project's
   manifest). An agent's "tests pass" is a claim, not evidence.
3. If a check fails, send the same agent one message with the failures, then
   verify again. Still failing: no pull request; record the failure.

## Stage 5 — Open the pull request

Land each verified branch through `finishing-a-development-branch`. Its menu
is already answered — push and create a pull request — so don't wait on it.

- **Title:** Conventional Commit form ending with the issue's reference, for
  example `feat: confirm waitlist emails (#42)`.
- **Body:** fill in `assets/pr-body.md`. Its link line comes from the
  tracker's Linking section: the finishing reference (on GitHub,
  `Closes #42`) when the agent's report leaves nothing undone; otherwise the
  partial reference (`Relates to #42`) followed by what is left. This is
  `superpowers-issue-bridge`'s rule for unattended runs.
- **Base:** the base branch, or the dependency's branch for a dependent
  issue.

Keep each worktree after its pull request opens — review fixes happen there.

## Stage 6 — Report

One table: issue, branch, pull request URL or the reason there is none,
checks result, and how many decisions the agent made. Then list every issue
skipped in Stage 1, and why.

## What NOT to do

- Don't merge, enable auto-merge, or approve a pull request — the user
  accepts the work.
- Don't push the base branch, and never force-push.
- Don't take an agent's report as proof — run the checks yourself.
- Don't open a pull request for an issue that already has one.
- Don't offer a model your platform's dispatch doesn't accept.
- Don't write `Closes` when the report lists work left undone.
- Don't open a pull request whose Decisions section is missing or vague —
  it is the only place the user sees the choices an agent made for them.

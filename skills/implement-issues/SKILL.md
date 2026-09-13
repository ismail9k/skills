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
issue, a plan, Superpowers' `subagent-driven-development`, a pull request, and
a code review — except that no one answers questions along the way. Every
decision an agent makes on the user's behalf lands in its pull request, where
the user reviews it.

Each pull request opens as a draft. A second agent runs `review-prs` on it,
and the agent that built the issue answers that review with Superpowers'
`receiving-code-review`. The pull request is marked ready once the review is
answered and the checks still pass.

You are the dispatcher. Agents write code in their own worktrees; you push
each branch, open its pull request, and give the verdict on each agent's work
— nothing is marked ready until you have run the checks yourself.

This skill names actions — "dispatch an agent", "choose a model" — not tools.
Use your platform's equivalents.

## Requirements

- Superpowers (`brainstorming`, `writing-plans`, `subagent-driven-development`,
  `finishing-a-development-branch`, `receiving-code-review`,
  `verification-before-completion`), plus the
  `fetch-issues`, `superpowers-issue-bridge`, and `review-prs` skills. If one
  is missing, name it and stop.
- A GitHub repository and `gh`, with `gh auth status` passing — pull requests
  and their reviews live there, wherever the issues live.

## Stage 1 — Build the queue

1. Get the open issues with `fetch-issues`. If the user named issues ("#12
   and #15"), keep only those.
2. Read `docs/agents/issue-tracker.md` for its Linking section — it decides
   what each pull request writes to close its issue.
3. Skip an issue, and record why, when an open pull request already
   references it or a branch already carries its reference (`feat/42-*`,
   `fix/42-*`).
4. An issue whose body references another queued issue depends on it: build
   it after that issue's pull request is marked ready, branched from that
   issue's branch instead of the base branch, and say so in its pull request.
   If that issue ends without a ready pull request, skip this one and record
   why.
5. Find the base branch — the remote's default branch — and fetch it.

Print the queue (reference, title, branch, dependency) and the skipped list.

## Stage 2 — Ask two questions

Ask both before dispatching anything. With the printed queue, the answers are
the user's go-ahead for the whole run — for each issue: pushing its branch,
opening a draft pull request, posting a review on it, pushing the fixes for
that review with replies to its comments, and marking it ready.

1. **Which model should the implementers use?** Offer the models your
   platform's dispatch accepts right now — its model options or spawn
   allowlist, never a name remembered from elsewhere. If your platform can't
   set a model per dispatch, say so and use its default. The choice applies
   to implementers only; the reviewers inside `subagent-driven-development`
   and `review-prs` keep those skills' own model rules.
2. **Sequential or parallel?** Sequential builds one issue at a time.
   Parallel builds up to N at once — ask for N, suggesting 3. Offer parallel
   only if your platform can run several dispatched agents at the same time.
   Either way, an issue holds its place from dispatch until its pull request
   is marked ready or the issue stops.

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
  Sequential: one issue at a time. Parallel: up to N at once, starting the
  next as each one ends. Keep each agent's identity; Stages 4 and 7 may
  message it.

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

## Stage 5 — Open a draft pull request

Land each verified branch through `finishing-a-development-branch`. Its menu
is already answered — push and create a pull request, as a draft
(`gh pr create --draft`) — so don't wait on it.

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

## Stage 6 — Review the pull request

Dispatch a new agent — never the one that built the issue — to run
`review-prs #<number>` on `<owner/repo>`, telling it the user's go-ahead for
this run covers posting the review. It posts its findings as comments on the
pull request and reports the review's URL. A review changes nothing locally,
so it can run while other issues build.

No review posted: leave the pull request a draft and record why. A review
with no findings: go to Stage 7, step 3.

## Stage 7 — Answer the review and mark it ready

1. Message the agent that built the issue — or, if it can no longer be
   messaged, dispatch a new one into the same worktree — to answer the review
   on `#<number>` with `receiving-code-review`: fix what holds, push back on
   what doesn't, push the branch (never force), and reply in each comment's
   thread as that skill describes. No one can answer its questions: where the
   skill says to ask, it decides and gives the reason in its reply, and the
   issue's Constraints stand for the user's prior decisions.
2. Verify the pushed head with `verification-before-completion`, running
   Stage 4's checks yourself. If one fails, send the agent the failures once,
   then check again.
3. Mark the pull request ready — `gh pr ready <number>` — once the checks
   pass and every review comment has a reply. It stays a draft, and you
   record why, when the checks still fail or a finding that holds was left
   unfixed.

## Stage 8 — Report

One table: issue, branch, pull request URL or the reason there is none,
state (ready, or draft and why), checks result, review findings by severity
with how many were fixed, and how many decisions the agent made. Then list
every issue skipped in Stage 1, and why.

## What NOT to do

- Don't merge, enable auto-merge, or approve a pull request — marking it
  ready hands it to the user, who accepts the work.
- Don't push the base branch, and never force-push.
- Don't take an agent's report as proof — run the checks yourself, before
  the first push and again after the review fixes.
- Don't open a pull request for an issue that already has one.
- Don't offer a model your platform's dispatch doesn't accept.
- Don't write `Closes` when the report lists work left undone.
- Don't open a pull request whose Decisions section is missing or vague —
  it is the only place the user sees the choices an agent made for them.
- Don't have the agent that built an issue review its own pull request.
- Don't mark a pull request ready while a review comment is unanswered or
  the checks fail on the pushed fixes.

---
name: implement-issues
description: >
  Use when the user wants several open issues built by agents and turned into
  pull requests — "work through the issues", "implement the open issues",
  "clear the backlog", "open PRs for #12 and #15" — optionally at an effort
  level ("/implement-issues low", "at medium effort"), and when plan pull
  requests it opened are approved or have comments to answer. Works in Claude
  Code, Codex, or any agent that can dispatch subagents. Not for one issue the
  user is building themselves in this session.
argument-hint: "[low|medium|high] [issue...]"
---

# Implement Issues

Build open issues with agents, one pull request per issue. Each issue goes
through the flow a person would take it through:

1. a spec and plan, written by Superpowers from the issue;
2. the build, done by Superpowers;
3. a pull request and a code review;

except that no one answers questions along the way. Every decision an agent
makes on the user's behalf lands in its pull request, where the user reviews
it.

Two agents work on each issue. A **planner** writes the spec and plan. A
**build lead** executes the plan and answers the review. When plan approval
is on, the user reviews the spec and plan on a draft pull request before the
build lead starts, and a later run picks up what they approved.

The built pull request opens as a draft. A second agent runs `review-prs` on
it, and the build lead answers that review with `answer-pr-reviews`. The pull
request is marked ready once the review is answered and the checks pass.

You are the dispatcher. Agents write in their own worktrees; you push each
branch, open its pull request, and give the verdict on each agent's work.
Nothing is marked ready until you have seen the checks pass yourself.

Superpowers owns the spec, the plan, and the build. This skill answers the
questions Superpowers would ask a person — which execution mode, which
model, how many fix rounds — from the user's settings. It never changes how
Superpowers works inside.

This skill names actions — "dispatch an agent", "choose a model" — not tools.
Use your platform's equivalents.

## Requirements

- Superpowers (`brainstorming`, `writing-plans`, `subagent-driven-development`,
  `executing-plans`, `finishing-a-development-branch`,
  `verification-before-completion`), plus the `fetch-issues`,
  `superpowers-issue-bridge`, `review-prs`, and `answer-pr-reviews` skills. If
  one is missing, name it and stop.
- A GitHub repository and `gh`, with `gh auth status` passing — pull requests
  and their reviews live there, wherever the issues live.

## Settings

Three settings shape a run. `docs/agents/delivery.md` in the repository holds
the saved ones; its shape is `assets/delivery.md`.

- **Effort** — `low`, `medium`, or `high`. Take it from the first of: the
  run's argument (`/implement-issues low`, "at medium effort"), the file's
  Effort line, or a question in Stage 2. It decides:

  | | low | medium | high |
  | --- | --- | --- | --- |
  | Build mode, answering `writing-plans`' execution question | one agent, with `executing-plans` | per task, with `subagent-driven-development` | per task, with `subagent-driven-development` |
  | Fix rounds per task review | — | 2 | 5 |
  | `review-prs` code pass | off | off | on |
  | Your full checks after the review fixes | CI is the evidence; run them only when the pull request has no CI | yes | yes |
  | `finishing-a-development-branch`'s own suite run | skipped when HEAD hasn't moved since Stage 5 | skipped when HEAD hasn't moved since Stage 5 | runs |
  | CI fix attempts | 1 | 2 | 3 |
  | Plan revision rounds | 1 | 2 | 3 |

  At every effort, Superpowers' whole-branch review runs at the end of the
  build, you run the full checks before the first push, and nothing merges.

- **Plan approval** — on or off; off when the file doesn't say.

- **Models**, one per agent. Six agents work on an issue, and each sets the
  model of one or more seats:

  | Agent | Seats | Dispatched by |
  | --- | --- | --- |
  | Planner | planner, spec-check | you |
  | Build lead | build-lead | you |
  | Implementers | implementer, escalation | Superpowers, inside the build lead |
  | Task reviewers | task-reviewer, re-reviewer, final-reviewer | Superpowers, inside the build lead |
  | Review agent | pr-reviewer | you |
  | PR code reviewer | pr-code-reviewer | `review-prs`, inside the review agent |

  Your session is the dispatcher; it has no setting.

  **Values.** Each value is a tier (`cheap`, `standard`, `strong`) looked up
  in the file's Tiers table, `session`, an exact model name, or — for
  Implementers — `by-task`, which leaves the choice to
  `subagent-driven-development`'s own rules. Review agent may also take
  `codex:` and a tier or a Codex model; see Codex as a reviewer, below.

  **Presets.** One word sets every agent left unset. Presets are tiers:

  | Agent | budget | balanced | max |
  | --- | --- | --- | --- |
  | Planner | strong | strong | strong |
  | Build lead | standard | standard | strong |
  | Implementers | cheap | standard | strong |
  | Task reviewers | standard | standard | strong |
  | Review agent | standard | standard | strong |
  | PR code reviewer | standard | strong | strong |

  **Precedence.** For each seat, the first of these that names it wins:

  1. a run override — from the request or from Stage 2;
  2. the seat's row in the file's Seats table;
  3. its agent's row in the Agents table;
  4. the Preset;
  5. the fallback below.

  A value resolves whole: provider and model come from the same level, never
  a provider from one and a model from another. A value with no `codex:`
  prefix runs on the provider of whoever dispatches that agent — your session
  for the Planner, Build lead and Review agent; the build lead's provider for
  Implementers and Task reviewers; the review agent's for the PR code
  reviewer. A tier resolves in that provider's Tiers column.

  **Escalation.** Fix rounds 4–5 exist because an implementer got stuck.
  When the Implementers value came from a run override, the Agents row or
  the Preset, and the escalation seat isn't set on its own, escalation runs
  one tier above it on the same provider: `cheap` → `standard`, `standard`
  → `strong`, `strong` stays. When that value is an exact model, `session`
  or `by-task`, or no Implementers value is set, escalation follows
  `subagent-driven-development`'s own rule.

  **Fallback.** A seat nothing above names falls back:

  | Seat | When not set |
  | --- | --- |
  | planner, build-lead, pr-reviewer | session model |
  | implementer | asked in Stage 2 |
  | spec-check, task-reviewer, re-reviewer, escalation, final-reviewer | that skill's own rule |
  | pr-code-reviewer | that skill's own rule |

## Stage 1 — Build the queue

1. Get the open issues with `fetch-issues`. If the user named issues ("#12
   and #15"), keep only those.
2. Read `docs/agents/issue-tracker.md` for its Linking section — it decides
   what each pull request writes to close its issue. Read
   `docs/agents/delivery.md` if it exists.
3. Find each issue's open pull requests and branches (`feat/42-*`,
   `fix/42-*`). An open pull request whose body holds
   `<!-- implement-issues: plan -->` is this skill's **plan pull request**:
   - labeled `plan-approved` → **build**;
   - with unanswered review comments — an unresolved thread whose last
     comment doesn't end with `<!-- answer-pr-reviews -->` → **revise the
     plan**;
   - otherwise → **waiting** on the user.

   Any other open pull request or branch for the issue → **skip**, and
   record why. No pull request and no branch → **plan**.
4. An issue whose body references another queued issue depends on it: start
   it after that issue's pull request is marked ready, branched from that
   issue's branch instead of the base branch, and say so in its pull request.
   If that issue ends without a ready pull request, skip this one and record
   why.
5. Find the base branch — the remote's default branch — and fetch it.

Print the queue — reference, title, branch, action (plan, revise the plan,
build), dependency — then the waiting and skipped lists.

## Stage 2 — Settle the settings, then ask how to run

Ask before dispatching anything.

1. **Settings.** Print the effort and where it came from, plan approval, and
   each seat's resolved model on this platform. Check every resolved model
   against what your platform's dispatch accepts right now — its model
   options or spawn allowlist. One it doesn't accept stops the run: name the
   seat, the value, and where it came from. That includes an exact name from
   another platform, and a tier with no column for this platform.

   Ask for what the file doesn't settle: the effort, when the run had no
   argument; plan approval, when the file has no line for it; the
   implementer's model, when the file doesn't set it — offering the models
   your dispatch accepts, never a name remembered from elsewhere. If your
   platform can't set a model per dispatch, say so and use its default for
   every seat. Then ask whether to use these settings for the run, or
   override any of them for this run only.

   When anything was asked, offer to save it to `docs/agents/delivery.md`:
   show the file's diff, and write it only on the user's yes. A run's
   overrides are saved only when the user says so.
2. **Sequential or parallel?** Sequential runs one issue at a time. Parallel
   runs up to N at once — ask for N, suggesting 3. Offer parallel only if your
   platform can run several dispatched agents at the same time. Either way,
   an issue holds its place from dispatch until it stops: waiting on plan
   approval, marked ready, or ended.

With the printed queue, the answers are the user's go-ahead for the whole
run — for each issue: pushing its branch; opening a draft plan pull request
and creating the `plan-approved` label if it's missing; pushing plan
revisions with replies to their comments; opening or converting the draft
pull request; posting a review on it; pushing the fixes for that review
with replies to its comments; pushing fixes for its failing CI checks; and
marking it ready.

## Stage 3 — Plan

For each issue to **plan**, create its branch and worktree, then dispatch its
planner:

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

- **Planner:** fill in `assets/planner-brief.md` with no plan pull request,
  and dispatch it as a background agent on the planner seat.

For each plan to **revise**, reuse the issue's worktree when it is clean;
otherwise create one from the pushed branch
(`git worktree add ".worktrees/<ref>-<slug>" "<branch>"`). Count the
revision rounds already done — the conversation comments on the plan pull
request that hold `<!-- implement-issues: plan revision -->`. At the effort's
cap, leave it waiting and record why. Otherwise dispatch a planner from
`assets/planner-brief.md`, naming the plan pull request.

When a planner reports:

1. `BLOCKED` or `NEEDS_DESIGN_SESSION`, or no commits on the branch: no pull
   request. Keep the worktree and record why.
2. **A revision:** confirm it pushed and replied, then post a conversation
   comment on the plan pull request — `Plan revision <n> of <cap>.
   <!-- implement-issues: plan revision -->` — and leave it waiting.
3. **Plan approval on:** push the branch and open a draft plan pull request —
   `gh pr create --draft`, title `plan: <issue title> (<reference>)`, body from
   `assets/plan-pr-body.md`, base the base branch or the dependency's branch.
   Create the `plan-approved` label first if `gh label list` doesn't show it.
   Leave the issue waiting.
4. **Plan approval off:** go straight to Stage 4 with the planner's spec and
   plan.

## Stage 4 — Build

For each issue to **build**, reuse its worktree when it is clean, or create
one from the pushed branch. Fill in `assets/build-brief.md` and dispatch it as
a background agent on the build-lead seat. Sequential: one issue at a time.
Parallel: up to N at once, starting the next as each one ends. Keep each build
lead's identity; Stages 5 and 8 may message it.

## Stage 5 — Verify each built issue

When a build lead reports:

1. A `BLOCKED` or `NEEDS_DESIGN_SESSION` report, or no new commits on the
   branch, means no pull request. Keep the worktree and record why.
2. Check the work yourself inside its worktree: read
   `git log origin/<base>..HEAD` and the diff, and run the project's test,
   lint, and typecheck commands (from `AGENTS.md` or the project's manifest).
   Write each command's output to a log file under the worktree's git
   directory and read back its exit code, its summary, and the tail of any
   failure — not the whole log. An agent's "tests pass" is a claim, not
   evidence.
3. If a check fails, send the same build lead one message with the failures,
   then verify again. Still failing: no pull request; record the failure.

## Stage 6 — Open the draft pull request

Land each verified branch through `finishing-a-development-branch`. Its menu
is already answered — push and create a pull request, as a draft — so don't
wait on it. Below high effort, Stage 5's check run is its Step 1 when HEAD
hasn't moved since.

- **Title:** Conventional Commit form ending with the issue's reference, for
  example `feat: confirm waitlist emails (#42)`.
- **Body:** fill in `assets/pr-body.md`. Its link line comes from the
  tracker's Linking section. First judge each item the report left undone
  yourself: one no change to this repository can do is a follow-up, and
  follow-ups never make the work partial. With nothing else left undone,
  write the finishing reference (on GitHub, `Closes #42`); otherwise the
  partial reference (`Relates to #42`) followed by what is left. A tracker
  whose Finishing PR is None has no finishing reference: write the partial
  reference, and say whether the work fully resolves the issue. This is
  `superpowers-issue-bridge`'s rule for unattended runs.
- **Base:** the base branch, or the dependency's branch for a dependent
  issue.
- **An approved plan pull request** is this issue's pull request: push to
  its branch, then give it the title and body above with
  `gh pr edit <number> --title <title> --body-file <file>`. It stays a draft.

Keep each worktree after its pull request opens — review fixes happen there.

## Stage 7 — Review the pull request

Dispatch a new agent on the pr-reviewer seat — never the planner or the
build lead — to run `review-prs #<number>` on `<owner/repo>`, telling it:

- the user's go-ahead for this run covers posting the review;
- below high effort, the code pass is off, because the build's whole-branch
  review already covered the code.

It posts its findings as comments on the pull request and reports the
review's URL. A review changes nothing locally, so it can run while other
issues build.

No review posted: leave the pull request a draft and record why. A review
with no findings: go to Stage 8, step 3.

## Stage 8 — Answer the review and mark it ready

1. Message the build lead — or, if it can no longer be messaged, dispatch a
   new one on the build-lead seat into the same worktree — to run
   `answer-pr-reviews #<number>` on `<owner/repo>` in that worktree, telling
   it the user's go-ahead for this run covers pushing the fixes and replying
   to each comment.
2. At medium and high effort, verify the pushed head with
   `verification-before-completion`, running Stage 5's checks yourself. If
   one fails, send the build lead the failures once, then check again. At low
   effort, CI is the evidence for the review fixes; run Stage 5's checks only
   when the pull request has no CI.
3. Wait for the pull request's CI checks on the pushed head —
   `gh pr checks <number> --watch`. When it reports no checks, there is
   nothing to wait for. Passing locally is not passing CI: a check can fail
   only there, on a different runtime, a missing variable, or a step the
   project's local commands skip. When one fails, send the build lead the
   failing check's name and log (`gh run view <run-id> --log-failed`), asking
   it to fix, commit, and push this branch — never force. Then run step 2
   again and wait for CI again, up to the effort's CI fix attempts.
4. Mark the pull request ready — `gh pr ready <number>` — once the checks
   pass and every review comment has a reply. It stays a draft, and you
   record why, when the checks still fail or a finding that holds was left
   unfixed.

## Stage 9 — Report

One table: issue, branch, pull request URL or the reason there is none,
state (waiting on plan approval, ready, or draft and why), checks result
locally and in CI, review findings by severity with how many were fixed, and
how many decisions the agents made. Above it, the run's effort and plan
approval; under it, the model each seat ran on, with token use or time per
agent where your platform reports them. Then list every issue waiting or
skipped in Stage 1, and why.

A pull request with the partial reference leaves its issue open when it
merges. For each one that left work undone, ask the user once, naming that
work: does it fully resolve the issue? On yes, swap its link line for the
finishing reference (`gh pr edit <number> --body-file <file>`) and keep what
was left undone as follow-ups.

A tracker with no finishing reference — local markdown, or a Jira or Trello
board that no integration closes — has no link line to swap. For each
pull request that fully resolves its issue, including each yes above, give
the user the tracker's Close-by-hand step to run once it merges.

## What NOT to do

- Don't merge, enable auto-merge, or approve a pull request — marking it
  ready hands it to the user, who accepts the work.
- Don't push the base branch, and never force-push.
- Don't take an agent's report as proof — run the checks yourself before the
  first push, at every effort.
- Don't open a pull request for an issue that already has one, other than
  converting its approved plan pull request.
- Don't build from a plan pull request without the `plan-approved` label, and
  don't add that label yourself — approval is the user's.
- Don't offer or dispatch a model your platform's dispatch doesn't accept,
  and don't fall back to another model silently.
- Don't write a model name into this skill or its assets; model names live
  only in `docs/agents/delivery.md`, as the user's choice.
- Don't save settings to `docs/agents/delivery.md` without showing the diff
  and receiving a yes.
- Don't write the finishing reference while work this repository could do
  is left undone, unless the user says in Stage 9 that the pull request fully
  resolves the issue. Don't write the partial reference for follow-ups alone.
- Don't open a pull request whose Decisions section is missing or vague —
  it is the only place the user sees the choices an agent made for them.
- Don't have the planner or the build lead review their own pull request.
- Don't mark a pull request ready while a review comment is unanswered or
  the checks fail on the pushed head — locally or in CI.

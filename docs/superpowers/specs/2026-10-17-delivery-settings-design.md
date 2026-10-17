# Delivery settings for implement-issues: effort, plan approval, model routing

Status: approved for build, 17 October 2026. Built on the flow map in
[`docs/implement-issues-flow.md`](../../implement-issues-flow.md), which
traces every agent and model seat this design refers to. Inspired by
Anthropic's [AI-native SDLC playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook).

## Why

Running `implement-issues` on a batch uses many tokens and takes a long time.
The flow map shows why:

- **Expensive seats by default.** Most agent seats run on the session model
  only because nothing names another one.
- **One fixed amount of review.** Every issue gets the same heavy review
  loop, however small it is:
  - a review per plan task, with up to five fix rounds each;
  - two whole-branch reviews of the same diff;
  - the full checks run twice on one commit, twice over.
- **No human check before code.** Nobody looks at the spec or plan until the
  finished PR. A wrong direction costs a whole build.

The user wants three controls:

1. **Effort:** `low`, `medium` or `high`, given when the run starts —
   `/implement-issues low`. It sets how many review iterations and how many
   check runs an issue gets.
2. **Plan approval:** a human reviews each issue's spec and plan before any
   code is written.
3. **Model routing:** which model does which job. For example, a cheap model
   for repetitive work and a strong one for review.

## The line this design holds

Each piece of the chain has an owner:

- **Intent:** GitHub issues, or the configured tracker.
- **Spec and plan:** Superpowers.
- **Build:** Superpowers.
- **PR, review and delivery:** our skills.

A setting may do only these two things:

1. **Answer a question Superpowers already asks.** For example, which
   execution mode `writing-plans` offers, or how many fix rounds to allow.
   Superpowers asks a person, and in an unattended run the user's settings
   answer instead.
2. **Change our own skills.** For example, `implement-issues` and
   `review-prs`.

No setting changes how Superpowers works inside. Superpowers' files are
never edited.

## Goals

- Effort is chosen per run, as the skill's argument. Plan approval and
  models for every seat are saved per project in one readable file, which
  `implement-issues` itself offers to write. There is no separate setup
  skill.
- `low` effort is much cheaper than today, and `high` stays close to today.
- Plan approval works asynchronously on GitHub. The user approves plans
  whenever they can, and a later run builds what was approved.
- A repository with no settings file behaves as it does today: `high`
  effort, no plan approval, and the two Stage 2 questions.

## Non-goals

- Choosing the dispatcher's model. The dispatcher is the user's own session.
- Measuring models or choosing defaults from measurements.
- Settings for skills outside the delivery group.
- A repository-level review policy file (`REVIEW.md`). That's a possible
  follow-up.

## Anti-goals

- A model name in any skill's text. Model names live only in the settings
  file, as the user's data.
- Silently falling back to another model when a configured one isn't
  accepted.
- Zero checks at any effort. Lower effort means fewer runs, never none
  before a push or before a PR is marked ready.
- `review-prs` or `answer-pr-reviews` needing the settings file. Both keep
  working on any PR with no setup.

## The design

### 1. The settings file

The file is `docs/agents/delivery.md` in the target repository, read by
`implement-issues` and `review-prs`. There is no setup skill:
`implement-issues` asks for what the file doesn't settle, and at the end of
Stage 2 offers to save the answers, showing the diff first. Missing entries
fall back to the defaults above. The template is
`skills/implement-issues/assets/delivery.md`.

**Where effort comes from.** In order, the first one found wins:

1. the run's argument, such as `/implement-issues medium` or "work through
   the issues at low effort";
2. the file's Effort line;
3. a question in Stage 2.

The file has four sections:

- **Effort:** `low`, `medium` or `high`.
- **Plan approval:** on or off.
- **Tiers:** what `cheap`, `standard` and `strong` mean on each platform,
  with one column per platform.
- **Seats:** each seat's model.

A seat's model is one of these:

- a tier word;
- `session`, which inherits the session's model;
- an exact model name;
- `by-task`, for the implementer only. It hands the choice back to SDD's own
  Model Selection rules.

### 2. Seats

| Seat | What it does |
| --- | --- |
| planner | Brainstorming, the spec when Superpowers writes one, the plan, and plan revisions |
| spec-check | Brainstorming's builder check on a written spec |
| build-lead | Executes the plan: runs SDD, or builds it itself at `low`. Answers the PR review and CI failures |
| implementer | SDD's implementer for one task |
| task-reviewer | SDD's review of one task |
| re-reviewer | SDD's scoped re-review of a fix |
| escalation | SDD's fix rounds 4–5 |
| final-reviewer | Superpowers' whole-branch review at the end of the build |
| pr-reviewer | The agent that runs `review-prs` |
| pr-code-reviewer | The code pass inside `review-prs` |

**Planner and build lead.** The planner and the build lead are separate
agents. The split is required by plan approval: a build can start in a
later run, long after the planner has ended. It also gets the most expensive
model off the longest-running seat. The build lead is "the agent that built
the issue". It answers the PR review, and it gets the CI failures.

**How models reach Superpowers.** The agent briefs name every seat's model
explicitly, including `session`. Superpowers' model guidance is advice to
its controller, and the user's settings, carried by the brief, come first.
This is an instruction, not a guarantee. The run report records the model
each seat actually used.

### 3. Effort

| | low | medium | high |
| --- | --- | --- | --- |
| Build mode — the answer to `writing-plans`' question | Single agent (`executing-plans`) | Per task (SDD) | Per task (SDD) |
| Fix rounds per task review | none, since there are no task reviews | 2 | 5, SDD's own cap |
| `review-prs` code pass | off: intent pass only | off: intent pass only | on |
| Dispatcher's full checks | before the first push. After review fixes, CI is the evidence, and local checks run only when the PR has no CI | before the first push, and after review fixes | the same as medium, plus `finishing-a-development-branch`'s own suite run |
| CI fix attempts | 1 | 2 | 3 |
| Plan revision rounds (with plan approval on) | 1 | 2 | 3 |

What holds at every effort level:

- Superpowers' own whole-branch review runs. Below `high`, it is the only
  whole-branch review. At `high`, `review-prs` repeats it on the PR.
- The review is answered once, by the build lead.
- At `low` and `medium`, Stage 4's check run counts as
  `finishing-a-development-branch`'s Step 1 when HEAD hasn't moved since.
- Check output goes to a log file. Only a summary and the failing tail are
  read back.

### 4. Plan approval

With plan approval on, each issue goes through two runs:

1. **First run.**
   - The planner commits the spec (when Superpowers writes one) and the plan
     on the issue's branch.
   - The dispatcher pushes that branch and opens a **plan PR**: a draft whose
     body comes from `assets/plan-pr-body.md`. The body carries the marker
     `<!-- implement-issues: plan -->`.
   - The issue waits there.
2. **The user reviews on GitHub.**
   - To approve, they add the `plan-approved` label. `implement-issues`
     creates that label the first time it opens a plan PR.
   - To ask for changes, they comment on lines.
3. **A later run picks up the plan PRs it finds:**

   | What the run finds | What happens |
   | --- | --- |
   | The PR has the `plan-approved` label | The build lead builds on the same branch. The PR body is replaced with the delivery body, and the title becomes the Conventional Commit form. From there the flow is the same as without approval. |
   | Comments with no reply yet | The planner revises with `answer-pr-reviews`, up to the effort's revision rounds. Past the cap, the PR waits for the user. |
   | Neither | The PR is listed as waiting. |

With plan approval off, the build lead starts as soon as the planner
reports, in the same run.

### 5. Stage 2 with a settings file

- Print the effort and where it came from, the plan-approval setting, and
  the resolved model for every seat.
- Check each model against what this platform's dispatch accepts. If one
  isn't accepted, stop and name the seat, the value, and where it came from.
  This includes an exact name from another platform, and a tier with no
  column for this platform. For a missing column, offer to add
  this platform's column.
- Ask one question: use these settings for this run, or override some of
  them for this run only. Overrides are never written back to the file.
- Then ask sequential or parallel, as today.

### 6. `review-prs`

- **Code pass model:** `review-prs` reads `pr-code-reviewer` from
  `docs/agents/delivery.md` when the file exists and the value resolves.
  Otherwise it uses today's "most capable model" and says so. It never stops
  over settings.
- **Intent-only mode:** when dispatched with the code pass off, it runs the
  intent pass only. The review body says the code pass was skipped because
  the builder's whole-branch review already covered it.

### 7. The report

Stage 8's table adds these columns:

- the effort used;
- the plan state: waiting, revised, approved, or not applicable;
- the model each seat ran on.

Where the platform reports tokens or time per agent, it adds those too.

## Decisions made while building

These calls were made without asking the user. Each was settled during
implementation, and each comes with what it costs if wrong:

- **Name:** the file is `delivery.md`, because it covers more than models.
- **Missing seats.** A seat Superpowers dispatches — spec-check,
  implementer, task-reviewer, re-reviewer, escalation, final-reviewer — falls
  back to Superpowers' own rule, so leaving a seat out never makes a run
  pricier than today. A seat `implement-issues` dispatches — planner,
  build-lead, pr-reviewer — falls back to the session model. Without the
  file, the implementer is asked in Stage 2, as today.
- **Where approval happens:** on GitHub, with a label. GitHub doesn't let
  the PR author approve their own PR, and the agents use the user's `gh`
  account, so a label is the signal. If wrong, approval moves to the chat,
  which changes Stages 1 and 3.
- **The issue-brief template is replaced.** `issue-brief.md` becomes
  `planner-brief.md` and `build-brief.md`. If wrong, it is restored from git.
- **The review answerer is always the build lead.** There is no setting for
  a fresh answerer.
- **The issue queue still reads full issue bodies.** Dependency detection
  needs them.

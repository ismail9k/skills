# Delivery settings

<!-- Read by: implement-issues, review-prs. Written by: implement-issues, when the user saves a run's settings -->

## Effort
<low, medium, or high — used when a run is started without one>

## Plan approval
<On — each issue's spec and plan wait on a draft plan PR until the plan-approved label is added | Off — the build starts as soon as the plan is written>

## Preset
<budget | balanced | max — sets every agent the Agents table and Seats leave unset>

## Agents
One model for each agent. Each value is a tier (`cheap`, `standard`,
`strong`), `session`, an exact model name, `by-task` for Implementers, or —
for Review agent only — `codex:` followed by a tier or a Codex model name.

| Agent | Model | Seats it sets |
| --- | --- | --- |
| Planner | <value> | planner, spec-check |
| Build lead | <value> | build-lead |
| Implementers | <value> | implementer, escalation |
| Task reviewers | <value> | task-reviewer, re-reviewer, final-reviewer |
| Review agent | <value> | pr-reviewer |
| PR code reviewer | <value> | pr-code-reviewer |

## Tiers
What each tier means on each platform this repository is built with. Add a
column when a new platform runs these skills.

| Tier | <platform> | codex |
| --- | --- | --- |
| cheap | <model> | <Codex model> |
| standard | <model> | <Codex model> |
| strong | <model> | <Codex model> |

## Seats
Optional. A row here overrides its agent for that one seat.
Each value is a tier (`cheap`, `standard`, `strong`), `session` (inherit the
session's model), or an exact model name. The implementer may also be
`by-task`, which leaves the choice to Superpowers' own Model Selection rules.
A seat left out follows the default in implement-issues.

| Seat | Model | What it does |
| --- | --- | --- |
| planner | <value> | Brainstorming, the spec, the plan, and plan revisions |
| spec-check | <value> | Brainstorming's builder check on a written spec |
| build-lead | <value> | Executes the plan, answers the PR review, fixes CI |
| implementer | <value> | Builds one plan task (medium and high effort) |
| task-reviewer | <value> | Reviews one task's diff (medium and high effort) |
| re-reviewer | <value> | Checks that a fix addressed its findings |
| escalation | <value> | Fix rounds 4–5 after an implementer got stuck (high effort) |
| final-reviewer | <value> | The whole-branch review at the end of the build |
| pr-reviewer | <value> | Runs review-prs on the pull request |
| pr-code-reviewer | <value> | The code pass inside review-prs (high effort) |

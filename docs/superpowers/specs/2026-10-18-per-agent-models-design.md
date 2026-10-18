# Per-agent models, presets, and Codex as a reviewer

Status: draft, 18 October 2026. Builds on
[`2026-10-17-delivery-settings-design.md`](2026-10-17-delivery-settings-design.md)
(effort, plan approval, ten model seats) and the flow map in
[`docs/implement-issues-flow.md`](../../implement-issues-flow.md). Nothing in
that design is undone here; this adds three layers on top of it.

## Why

The delivery settings already give every seat its own model. In practice
that is hard to use:

- **Ten seats is too many to think about.** The user pictures a run as the
  agents in the flow map's columns — planner, build lead, the agents that
  build, the agents that review — not as ten seats. Setting "Opus plans,
  Haiku builds" today means knowing which of ten rows each word belongs to.
- **There is no quick starting point.** A new repository has no
  `delivery.md`, so the first run either asks about the implementer only or
  needs the file written by hand.
- **Every agent runs on one platform.** A run started in Claude Code can only
  dispatch Claude models, and a run started in Codex only Codex models. The
  user wants a Claude session to have Codex, on the same machine, review the
  pull requests Claude built: a different model family catches what Claude
  misses.

The user's words: configure which model does which job — "planning with
Opus, executing with Haiku" — and use Codex locally, for reviews only.

## The line this design holds

The same line as the delivery-settings design: settings answer questions
Superpowers already asks, or change our own skills. Superpowers' files are
never edited, and it keeps dispatching its own subagents. A Codex reviewer
runs the same `review-prs`, installed in Codex; this design never
re-implements a review step inside `implement-issues`.

## Goals

- **Six agents to configure.** The user sets a model for each agent they can
  see in the flow map, and each agent covers one or more of the existing
  seats. The ten seats stay as the precise level underneath, for anyone who
  wants it.
- **Presets.** One word — `budget`, `balanced` or `max` — sets all six
  agents. Any agent or seat can still be overridden.
- **Codex as a reviewer.** The Review agent, and with it the PR code
  reviewer, can run on Codex, on the same machine, from a Claude Code
  session. Codex reads and reports; it never changes the repository or
  GitHub.
- **No surprises.** A run prints every agent's model and provider before it
  starts, and stops on any value it can't honour, as today.

## Non-goals

- Codex as the Planner, Build lead, Implementers or Task reviewers. The user
  wants Codex for reviews only. The provider prefix below leaves room for it
  later.
- Claude as a provider from a Codex session (`claude -p`).
- Codex cloud tasks. The user chose local only.
- Mixing providers inside one Superpowers build.
- Choosing presets from measurements, or tracking cost in money.
- Changing the dispatcher's model. It is the user's own session.

## Anti-goals

- A model name in any skill's text. Presets are written in tiers; model
  names still live only in `delivery.md`.
- Silently running a seat on another model or another provider than the one
  configured.
- Codex writing anything: no file in the worktree, no commit, no push, no
  comment or review on GitHub. The dispatcher posts what Codex finds.
- A run that needs Codex installed when no agent names it.

## The design

### 1. Six agents

The flow map draws six columns: Dispatcher, Planner, Build lead, Superpowers
subagents, Review agent, PR code reviewer. The dispatcher is the user's
session and has no setting. "Superpowers subagents" mixes agents that write
code with agents that review it, so a single model for that column would make
"Haiku builds" also mean "Haiku reviews". It is split in two. That gives six
agents the user can set:

| Agent | Seats it sets | Who dispatches it |
| --- | --- | --- |
| Planner | planner, spec-check | `implement-issues` |
| Build lead | build-lead | `implement-issues` |
| Implementers | implementer, escalation | Superpowers, inside the build lead |
| Task reviewers | task-reviewer, re-reviewer, final-reviewer | Superpowers, inside the build lead |
| Review agent | pr-reviewer | `implement-issues` |
| PR code reviewer | pr-code-reviewer | `review-prs`, inside the review agent |

**Escalation.** Fix rounds 4–5 exist because an implementer got stuck, so
running them on the same cheap model defeats them. When the Implementers
value comes from a run override, the Agents row or the Preset, and the
escalation seat isn't set on its own, escalation resolves one tier above the
Implementers' tier (`cheap` → `standard`, `standard` → `strong`, `strong`
stays), on the same provider. When the Implementers value has no tier to
step up from — an exact model name, `session` or `by-task` — or when no
Implementers value is set at all, escalation falls back to SDD's own rule,
as today. The settings printout shows which applied.

**Unused agents.** At `low` effort there are no implementers, and Task
reviewers do only the final whole-branch review; below `high` there is no PR
code reviewer. The settings
printout shows those agents as "not used at this effort" instead of hiding
them, so a user who set "Haiku builds" with `low` sees that it won't apply.

### 2. The settings file

`docs/agents/delivery.md` gains two sections, and the Seats section becomes
optional:

```markdown
## Preset
<budget | balanced | max — sets every agent below that isn't set>

## Agents
| Agent | Model |
| --- | --- |
| Planner | <value> |
| Build lead | <value> |
| Implementers | <value> |
| Task reviewers | <value> |
| Review agent | <value> |
| PR code reviewer | <value> |

## Seats
<optional — the ten-seat table from the delivery-settings design, for
overriding one seat inside an agent>
```

A value is anything a seat accepts today — a tier, `session`, an exact model
name, `by-task` for Implementers — optionally prefixed with a provider:
`codex:strong`, `codex:<exact model>`. No prefix means the session's own
platform.

**Precedence**, for each seat, first match wins:

1. a run override from Stage 2 or the run's request ("Opus plans, Haiku
   builds");
2. the seat's row in Seats;
3. its agent's row in Agents;
4. the Preset;
5. the fallback in the delivery-settings design (session model for seats
   `implement-issues` dispatches, the skill's own rule for the rest).

A repository whose `delivery.md` has no Preset and no Agents section
resolves every seat exactly as it does today. A repository with no
`delivery.md` at all is asked the preset question in Stage 2 (section 5)
instead of the implementer question, which is a deliberate change.

**A value is resolved whole.** Provider and model travel together: the
first level that names a seat supplies both. A Seats row
`pr-reviewer: strong` under an Agents row `Review agent: codex:standard` runs
the review on the session's platform at `strong`, and the Stage 2 table shows
the Seats row as the source. There is no merging of a provider from one level with a model
from another.

**What "no prefix" means.** An unprefixed value runs on the provider of
whoever dispatches that agent. For the Planner, Build lead and Review agent
that is the session. For Implementers and Task reviewers it is the Build
lead's provider; for the PR code reviewer, the Review agent's. So under a
Codex review agent, `PR code reviewer: strong` means Codex's `strong`. An
exact model name the parent's provider doesn't accept — a Claude model under
a Codex review agent — stops the run in Stage 2, like any other unaccepted
model.

**Run overrides in words.** Overrides from the request map to agents by one
fixed vocabulary: "plans" → Planner; "builds" or "executes" → Implementers;
"leads the build" → Build lead; "reviews tasks" → Task reviewers; "reviews"
or "reviews the PR" → Review agent; "reviews the code" → PR code reviewer.
Whatever the wording, Stage 2 prints the resulting six-agent table with
"run" as the source of each overridden row, and the run starts only after
the user confirms it.

### 3. Presets

Presets are written in tiers, never model names, so they work on any platform
whose Tiers column is filled in:

| Agent | budget | balanced | max |
| --- | --- | --- | --- |
| Planner | strong | strong | strong |
| Build lead | standard | standard | strong |
| Implementers | cheap | standard | strong |
| Task reviewers | standard | standard | strong |
| Review agent | standard | standard | strong |
| PR code reviewer | standard | strong | strong |

The reasoning, as the user's call to change: the plan is where a mistake is
cheapest to fix, so it is `strong` everywhere. Implementers copy code the
plan already contains, so `budget` puts them on `cheap`. Reviewers stay at
least as strong as what they review.

Presets don't choose providers. "Codex reviews" is an Agents-row override on
top of any preset.

### 4. Codex as a reviewer

**Which agents can use it.** Only the Review agent can name `codex:`. The PR
code reviewer is dispatched inside the review, so it follows the Review
agent's provider: with `Review agent: codex:standard` and
`PR code reviewer: strong`, the code pass runs on Codex's `strong` model. Any
other agent that names `codex:` stops the run in Stage 2 and says Codex is
for reviews only.

**Codex reads, the dispatcher writes.** `review-prs` today posts its own
review with `gh`. A Codex reviewer doesn't: it runs `review-prs` in a new
report-only mode, which does the same intent pass (and, at `high`, the same
code pass) but writes the review it would have posted — the summary and each
inline finding with its file and line — to its report instead of GitHub.
The dispatcher then posts that review on the pull request with `gh`, exactly
as `review-prs` would have, under the run's go-ahead. From there the flow is
unchanged: the build lead, on Claude, answers the review with
`answer-pr-reviews`.

**How the dispatcher runs it.** In place of dispatching a background review
agent, it runs the Codex CLI's non-interactive mode as a background shell
command, read-only, in the issue's worktree, which already holds the pull
request's head:

```bash
codex exec \
  -C "<worktree>" \
  -m "<resolved model>" \
  -s read-only \
  --json \
  -o "<worktree git dir>/implement-issues/review-report.md" \
  - < "<filled review brief>"
```

- The brief names the pull request, the issue, the effort's code-pass
  setting, the PR code reviewer's model, and report-only mode.
- `-o` writes Codex's last message: the review to post.
- Codex can't push, comment, or change a file in `read-only`. The review
  agent never needs to.

**No one reviews their own work.** Unchanged: the Review agent is always a
new agent, and now it can also be a different model family from the one that
built the pull request.

**Checking Codex before the run.** In Stage 2, when the Review agent resolves
to `codex:`, the dispatcher checks that the Codex CLI is installed and logged
in, that the resolved models are accepted, and that `review-prs` is installed
for Codex. Any failure stops the run and names the agent, the value, and
where it came from. A run with no Codex reviewer never checks.

### 5. Stage 2

1. Print the effort, plan approval, and the preset when there is one.
2. Print one table of the six agents: provider, model, the source of each
   value (run, Seats, Agents, Preset, fallback), and "not used at this
   effort" where it applies. Seats that differ from their agent are listed
   under it.
3. Check every resolved model against its provider, as above.
4. Ask for what isn't settled. With no file, the first question is the
   preset — `budget`, `balanced`, `max`, or "set each agent" — instead of the
   implementer alone. "Set each agent" asks the six agents in one question.
5. Offer to save to `delivery.md`, showing the diff, as today.
6. Ask sequential or parallel, as today.

### 6. The report

Stage 9 already lists the model each seat ran on. It now groups seats by
agent and adds the provider. For a Codex reviewer it reports Codex's own
token counts when the `--json` events include them.

## What changes where

- `skills/implement-issues/SKILL.md`: Settings (agents, presets, the `codex:`
  prefix, precedence), Stage 2, Stage 7 (the Codex review path and posting
  its review), Stage 9, What NOT to do.
- `skills/implement-issues/assets/delivery.md`: the Preset and Agents
  sections; Seats marked optional; a `codex` column example in Tiers.
- A new `skills/implement-issues/assets/review-brief.md`, for the Codex
  reviewer.
- `skills/review-prs/SKILL.md`: the report-only mode; resolve
  `pr-code-reviewer` through the same precedence, including the Agents row.
- `docs/implement-issues-flow.md`: the Superpowers subagents column split into
  Implementers and Task reviewers; the Codex review path.
- `README.md`: the six agents, presets, and Codex reviews.
- The site, on the `docs` branch: the same, as a second pull request opened
  after the first one merges, so the site never describes behaviour that
  isn't on `main` yet.

## Decisions made without asking

Each is the builder's or the user's to change; each says what it costs if
wrong.

- **Six agents, not five.** The PR code reviewer stays its own agent, as in
  the flow map, so "max review on the PR, cheap elsewhere" is one row. If
  wrong, it folds into Review agent with no file change for users who never
  set it.
- **Escalation steps up one tier from Implementers.** If wrong, it becomes a
  plain member of Implementers, and stuck tasks retry on the same cheap model.
- **The preset tiers in section 3.** A first guess with no measurements.
- **Codex reviews in report-only mode, and the dispatcher posts.** This is
  the user's "Codex reviews only", read strictly: Codex never writes, even a
  comment. If wrong, Codex posts its own review with `gh`, which needs
  network and `gh` auth inside its sandbox and drops the report-only mode.
- **Children follow their parent's provider.** The PR code reviewer runs
  wherever the Review agent runs. If wrong, `review-prs` would have to
  dispatch across platforms.
- **A value is resolved whole, provider and model together.** If wrong, the
  resolver tracks provider and model as two fields with separate precedence,
  which is harder to print and to reason about.
- **Word overrides use a fixed vocabulary and are always confirmed.** If
  wrong, the run trusts its reading of the request, and the same phrase could
  produce different runs.
- **Escalation steps up only from a tier set through the new layers.** If
  wrong, it also steps up from today's Stage 2 answer, which changes runs in
  repositories that never adopt presets.
- **The site update is a second pull request.** If wrong, both branches
  change together and the site can describe unmerged behaviour.

## Left to the builder

- **What the reviewer reads.** `review-prs` reads the pull request and the
  issue with `gh`. Confirm whether `read-only` lets Codex reach GitHub. If it
  doesn't, the dispatcher writes the diff, the PR body and the issue into the
  worktree's git directory, and the brief points report-only mode at those
  files.
- **The report format.** Choose a shape for the review in report-only mode
  that the dispatcher can post without guessing: the summary body, and each
  inline comment with path, line and side.
- **How to check a Codex model is accepted.** Codex has no model list
  command in `codex exec --help`. A short dry run, or the Codex config, are
  both options.
- **How to check Codex is logged in, and that `review-prs` is installed for
  Codex.** Find the cheapest reliable command for each.
- **Waiting.** Decide how the dispatcher waits on a background `codex exec`,
  and how a parallel run tracks several reviews at once.

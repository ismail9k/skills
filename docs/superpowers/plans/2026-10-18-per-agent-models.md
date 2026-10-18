# Per-agent models, presets, and Codex as a reviewer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `implement-issues` users set one model per agent (six agents), pick a preset, and run the Review agent on a local Codex, read-only.

**Architecture:** The ten seats from the delivery-settings design stay as the resolution target. Two new layers — an Agents table and a Preset — sit under the Seats table in precedence. A `codex:` prefix is accepted only on the Review agent; the dispatcher runs Codex with `codex exec -s read-only`, `review-prs` runs in a new report-only mode that returns its review payload instead of posting, and the dispatcher posts it.

**Tech Stack:** Markdown skills; `bash scripts/check.sh` (bash 3.2) as the test step; `gh`; Codex CLI (`codex exec`, `codex login status`).

**Spec:** `docs/superpowers/specs/2026-10-18-per-agent-models-design.md`

## Global Constraints

- No model name in any file under `skills/`, `README.md`, `AGENTS.md` or `docs/implement-issues-flow.md`. Presets are tiers only.
- The six agents, spelled exactly and in this order everywhere: **Planner, Build lead, Implementers, Task reviewers, Review agent, PR code reviewer**.
- Agent → seats: Planner = planner, spec-check; Build lead = build-lead; Implementers = implementer, escalation; Task reviewers = task-reviewer, re-reviewer, final-reviewer; Review agent = pr-reviewer; PR code reviewer = pr-code-reviewer.
- Precedence, first match wins: run override → Seats row → Agents row → Preset → the delivery-settings fallback.
- A value resolves whole: provider and model come from the same level.
- `codex:` is accepted only on the Review agent (and, through it, on the PR code reviewer). Any other agent naming `codex:` stops the run in Stage 2.
- Codex never writes: no file, commit, push, comment or review. The dispatcher posts.
- Skills stay platform-neutral in actions ("dispatch an agent"); Codex CLI commands appear only on the Codex path.
- Superpowers' files are never edited; skills reference each other by name, never by path.
- `bash scripts/check.sh` passes before every commit.

## Review Focus

- **`delivery.md` with a Seats table but no Preset or Agents** — every seat must resolve exactly as before; nothing new is asked except when no file exists. Pinned in Task 1's check (Seats section still present and marked optional) and Task 2's Stage 2 wording.
- **An unprefixed exact model under a Codex Review agent** (a Claude model on PR code reviewer) — must stop in Stage 2, not run on Claude silently. Pinned in Task 4's check for the stop sentence.
- **Codex installed but logged out, or `review-prs` not installed for Codex** — must stop before any agent starts, naming the agent and the value. Pinned in Task 4's check for the three Stage 2 Codex checks.
- **Effort below high with a Codex PR code reviewer set** — the code pass is off, so the row shows "not used at this effort" and Codex runs the intent pass only. Pinned in Task 2's check for the phrase.
- **A Codex reply with no or two `json` blocks** — the dispatcher must not post anything, leave the PR a draft, and record why. Pinned in Task 4's check.

---

### Task 1: Agents, presets and precedence in the settings

**Files:**
- Modify: `skills/implement-issues/assets/delivery.md`
- Modify: `skills/implement-issues/SKILL.md` (the `## Settings` section, currently lines 58–93)
- Test: `scripts/check.sh` (new section 5)

**Interfaces:**
- Produces: the six agent names and order (Global Constraints); `delivery.md` sections `## Effort`, `## Plan approval`, `## Preset`, `## Agents`, `## Tiers`, `## Seats` in that order; the preset table below; the escalation step-up rule. Later tasks print and document these, never redefine them.

- [ ] **Step 1: Add the failing checks to `scripts/check.sh`**

Insert a new section after section 3 ("no skill references another by path"), before the anti-koshary section, headed `implement-issues settings stay consistent`. It defines:

```bash
AGENTS_6="Planner|Build lead|Implementers|Task reviewers|Review agent|PR code reviewer"
II=skills/implement-issues
```

and these checks, each `ok`/`bad` with the file named:

- no model name: `grep -rniE '(^|[^[:alnum:]])(opus|sonnet|haiku|fable|gpt-?[0-9])' skills/implement-issues skills/review-prs README.md AGENTS.md docs/implement-issues-flow.md` prints nothing;
- `$II/assets/delivery.md` has the headings `## Effort`, `## Plan approval`, `## Preset`, `## Agents`, `## Tiers`, `## Seats` in that order (`grep -n '^## '` compared to the expected list);
- each of the six agent names appears as a table row (`^| <name> |`) in `$II/assets/delivery.md`;
- `$II/SKILL.md` has a preset table: a line matching `^\| Agent \| budget \| balanced \| max \|$` and the six agent rows under it.

- [ ] **Step 2: Run it and watch it fail**

Run: `bash scripts/check.sh`
Expected: `CHECKS FAILED`, with FAIL lines for the `## Preset` heading order, the six rows in `delivery.md`, and the preset table; the model-name check passes.

- [ ] **Step 3: Update `assets/delivery.md`**

Add `## Preset` (placeholder `<budget | balanced | max — sets every agent the Agents table and Seats leave unset>`) and `## Agents` (two-column table, the six agents, value placeholder `<value — a tier, session, an exact model, by-task for Implementers, or codex:<tier or model> for Review agent only>`) between `## Plan approval` and `## Tiers`. Mark `## Seats` optional in its intro: "Optional. A row here overrides its agent for that one seat." Add a `codex` column to the Tiers table's header example: `| Tier | <platform> | codex |`. Keep the read-by comment and add `review-prs` stays a reader.

- [ ] **Step 4: Rewrite the Settings section of `SKILL.md`**

Keep Effort and Plan approval as they are. Replace the Models bullet with:

1. **Agents** — the six-row agent → seats table from Global Constraints, with a third column "Dispatched by" (`implement-issues` for Planner, Build lead, Review agent; Superpowers, inside the build lead, for Implementers and Task reviewers; `review-prs`, inside the review agent, for PR code reviewer).
2. **Values** — what a value may be (unchanged list) plus the `codex:` prefix, with a pointer to the Codex section Task 4 adds.
3. **Presets** — the table, verbatim:

   | Agent | budget | balanced | max |
   | --- | --- | --- | --- |
   | Planner | strong | strong | strong |
   | Build lead | standard | standard | strong |
   | Implementers | cheap | standard | strong |
   | Task reviewers | standard | standard | strong |
   | Review agent | standard | standard | strong |
   | PR code reviewer | standard | strong | strong |

4. **Precedence** — the five levels in order; "a value resolves whole"; "no prefix runs on the provider of whoever dispatches the agent".
5. **Escalation** — steps up one tier (`cheap` → `standard` → `strong`, `strong` stays) on the same provider only when the Implementers value came from a run override, the Agents row or the Preset and the escalation seat isn't set; for an exact model, `session`, `by-task`, or no Implementers value, it follows SDD's own rule.
6. Keep the existing seat fallback table as level 5.

- [ ] **Step 5: Run the checks and watch them pass**

Run: `bash scripts/check.sh`
Expected: `all checks passed`.

- [ ] **Step 6: Commit**

```bash
git add scripts/check.sh skills/implement-issues/assets/delivery.md skills/implement-issues/SKILL.md
git commit -m "feat(implement-issues): set models per agent, with presets"
```

---

### Task 2: Stage 2 asks by agent, and the report groups by agent

**Files:**
- Modify: `skills/implement-issues/SKILL.md` (Stage 2, currently lines 123–157; Stage 9, currently lines 293–312; What NOT to do)
- Test: `scripts/check.sh` (section 5)

**Interfaces:**
- Consumes: the agent names, presets and precedence from Task 1.
- Produces: the run-override vocabulary below, used verbatim by Task 5's docs.

- [ ] **Step 1: Add the failing checks**

In section 5, check that `$II/SKILL.md` contains each of these strings: `not used at this effort`, `set each agent`, `"builds" or "executes"`, `the run starts only after the user confirms`, and that Stage 9's text contains `provider`.

- [ ] **Step 2: Run it and watch it fail**

Run: `bash scripts/check.sh`
Expected: `CHECKS FAILED` on those five strings.

- [ ] **Step 3: Rewrite Stage 2, step 1**

In this order: print effort (and its source), plan approval, the preset if any; then one table of the six agents — provider, model, source (run, Seats, Agents, Preset, fallback) — with seats that differ from their agent listed under it, and "not used at this effort" for Implementers and Task reviewers at `low` and for PR code reviewer below `high`. Check models as today. Ask for what isn't settled: with no `delivery.md`, the first question is the preset — `budget`, `balanced`, `max`, or "set each agent" (which asks all six in one question) — replacing the implementer-only question. Run overrides in words map by this vocabulary: "plans" → Planner; "builds" or "executes" → Implementers; "leads the build" → Build lead; "reviews tasks" → Task reviewers; "reviews" or "reviews the PR" → Review agent; "reviews the code" → PR code reviewer. Print the resulting table with "run" as the source, and the run starts only after the user confirms it. The save offer and the sequential/parallel question are unchanged.

- [ ] **Step 4: Update Stage 9 and What NOT to do**

Stage 9: under the table, group the per-seat models by agent and add each one's provider. What NOT to do: add "Don't read a run override's wording any other way than the vocabulary in Stage 2, and don't start before the user confirms the printed table."

- [ ] **Step 5: Run the checks and watch them pass**

Run: `bash scripts/check.sh`
Expected: `all checks passed`.

- [ ] **Step 6: Commit**

```bash
git add scripts/check.sh skills/implement-issues/SKILL.md
git commit -m "feat(implement-issues): ask for models by agent and confirm run overrides"
```

---

### Task 3: Report-only mode in `review-prs`

**Files:**
- Modify: `skills/review-prs/SKILL.md` (Stages 1, 2, 4, 5; a new section after Stage 3's Intent-only paragraph; What NOT to do)
- Test: `scripts/check.sh` (section 5)

**Interfaces:**
- Produces, for Task 4: report-only mode is entered when the dispatch names `Report-only: yes` and `Context: <dir>`. `<dir>` holds `pr.json` (the output of `gh pr view <n> --json number,url,title,body,baseRefName,headRefOid`), `comments.json` (the existing review comments), and `issue.md` (the linked issue's body; absent when there is none). The commits are already fetched into the checkout. The reply's final message contains exactly one fenced `json` block: the Stage 4 review payload (`commit_id`, `event: "COMMENT"`, `body`, `comments`), followed by the dropped findings and why.

- [ ] **Step 1: Add the failing checks**

In section 5, check that `skills/review-prs/SKILL.md` contains a heading `## Report-only mode`, and the strings `Context:`, `pr.json`, `comments.json`, `issue.md`, `exactly one fenced` and `don't call gh`.

- [ ] **Step 2: Run it and watch it fail**

Run: `bash scripts/check.sh`
Expected: `CHECKS FAILED` on the `review-prs` strings.

- [ ] **Step 3: Write `## Report-only mode`**

Entered only when dispatched with `Report-only: yes` and a `Context:` directory. In it: skip Stage 1's `gh` checks and the list confirmation; Stage 2 reads `pr.json`, `comments.json` and `issue.md` from the context directory and uses the checkout as is, with `HEAD_SHA` from `pr.json` and `BASE_SHA` from `git merge-base origin/<base> <HEAD_SHA>`; Stage 3 is unchanged, including the code-pass model and Intent-only rules; Stage 4 builds the same payload but returns it as exactly one fenced `json` block in the final message instead of posting; don't call gh, write files, or change the checkout. The caller posts it.

- [ ] **Step 4: Resolve the PR code reviewer through the new layers**

In Stage 3's code pass, replace "its `pr-code-reviewer` seat resolves" with the same order `implement-issues` uses, read from `docs/agents/delivery.md`: the `pr-code-reviewer` Seats row, then the `PR code reviewer` Agents row, then the Preset's PR code reviewer tier, then the most capable model, said in the report. A value given in the dispatch (`implement-issues` passes one) comes first. Add `PR code reviewer` and `Preset` to Step 1's string checks for `review-prs`.

- [ ] **Step 5: Point Stages 1, 2, 4, 5 and What NOT to do at it**

One sentence each where the stage differs ("In report-only mode, see Report-only mode"). Stage 5's report in report-only mode is the dropped findings only. What NOT to do: "Don't call gh, write a file, or post anything in report-only mode."

- [ ] **Step 6: Run the checks and watch them pass**

Run: `bash scripts/check.sh`
Expected: `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add scripts/check.sh skills/review-prs/SKILL.md
git commit -m "feat(review-prs): add a report-only mode that returns the review instead of posting it"
```

---

### Task 4: The Codex review path in `implement-issues`

**Files:**
- Create: `skills/implement-issues/assets/review-brief.md`
- Modify: `skills/implement-issues/SKILL.md` (Requirements; Settings; Stage 2; Stage 7; What NOT to do)
- Test: `scripts/check.sh` (section 5)

**Interfaces:**
- Consumes: report-only mode exactly as Task 3 defines it; the agents and precedence from Task 1.
- Produces: `assets/review-brief.md` with the placeholders `<owner/repo>`, `<number>`, `<worktree>`, `<context dir>`, `<code pass: on|off>`, `<PR code reviewer model>`.

- [ ] **Step 1: Add the failing checks**

In section 5, check that:
- `$II/assets/review-brief.md` exists and contains `Report-only: yes`, `Context:` and each placeholder above;
- `$II/SKILL.md` contains `codex exec`, `-s read-only`, `codex login status`, `Codex is for reviews only`, `doesn't accept stops the run`, and `exactly one fenced`;
- `codex exec` appears in `$II/SKILL.md` only inside `## Stage 2` and `## Stage 7`, never in any other stage (`awk` tracking the current `## Stage` heading).

- [ ] **Step 2: Run it and watch it fail**

Run: `bash scripts/check.sh`
Expected: `CHECKS FAILED` on the missing brief and the Codex strings.

- [ ] **Step 3: Write `assets/review-brief.md`**

A short brief for a reviewer that can't ask: run `review-prs #<number>` on `<owner/repo>` in report-only mode, `Report-only: yes`, `Context: <context dir>`, working in `<worktree>`; the code pass is `<code pass: on|off>`; when on, dispatch its code reviewer on `<PR code reviewer model>`; end with exactly one fenced `json` block.

- [ ] **Step 4: Add the Codex rules to Settings and Requirements**

Settings: a "Codex as a reviewer" paragraph — only the Review agent may name `codex:`; the PR code reviewer follows its provider; any other agent naming `codex:` stops the run in Stage 2 with "Codex is for reviews only"; an exact model its parent's provider doesn't accept stops the run — write it as "a model the parent's provider doesn't accept stops the run". Requirements: "When the Review agent uses Codex: the Codex CLI, logged in, with `review-prs` installed for Codex."

- [ ] **Step 5: Add the Codex checks to Stage 2**

Only when the Review agent resolves to `codex:`, before anything is dispatched: `codex --version` succeeds; `codex login status` exits 0; `review-prs` exists in the repository's `.agents/skills/`, `~/.agents/skills/`, or `$CODEX_HOME/skills/` (default `~/.codex/skills/`); each distinct Codex model answers `codex exec --ephemeral -s read-only -m "<model>" "Reply with the single word OK."` with exit 0. Any failure stops the run and names the agent, the value and its source.

- [ ] **Step 6: Add the Codex path to Stage 7**

When the Review agent is on Codex, in place of dispatching a review agent:

1. Gather the context into `<worktree git dir>/implement-issues/review-<number>/`: `pr.json`, `comments.json`, `issue.md` (when the PR links one), with the commands Task 3 names, and `git fetch origin <base> pull/<number>/head` in the worktree, so Codex can compute `BASE_SHA` without network.
2. Fill `assets/review-brief.md` and run, in the background:

   ```bash
   codex exec -C "<worktree>" -m "<model>" -s read-only --json \
     -o "<context dir>/report.md" - < "<context dir>/brief.md"
   ```

3. Extract the single fenced `json` block from `report.md` to `<context dir>/review.json` and post it: `gh api --method POST repos/<owner>/<repo>/pulls/<number>/reviews --input <context dir>/review.json`. Read back the review URL.
4. No block, more than one, or a failed post: post nothing, leave the pull request a draft, record why in the report.

Then Stage 8 continues as today. A Claude Review agent is unchanged. For Stage 9, read Codex's token counts from the `--json` events when they include them.

- [ ] **Step 7: Update What NOT to do**

Add: "Don't let a Codex agent write — run it only with `-s read-only`, and post its review yourself." and "Don't post a Codex review unless its reply holds exactly one fenced `json` block."

- [ ] **Step 8: Run the checks and watch them pass**

Run: `bash scripts/check.sh`
Expected: `all checks passed`.

- [ ] **Step 9: Commit**

```bash
git add scripts/check.sh skills/implement-issues/SKILL.md skills/implement-issues/assets/review-brief.md
git commit -m "feat(implement-issues): run the review agent on Codex, read-only"
```

---

### Task 5: The flow map, README and AGENTS.md

**Files:**
- Modify: `docs/implement-issues-flow.md` (The three settings; At a glance; Who runs what; Stage by stage, step 7; Every model seat)
- Modify: `README.md` (the `implement-issues` section, currently lines 101–117; Requirements table row, line 212)
- Modify: `AGENTS.md` (the assets paragraph in Layout convention; the `implement-issues` settings bullet in Editorial conventions)
- Test: `scripts/check.sh` (section 5)

**Interfaces:**
- Consumes: names, presets, vocabulary and the Codex path from Tasks 1–4. Describe them; never restate the skill's step text.

- [ ] **Step 1: Add the failing checks**

In section 5, check that each of the six agent names appears in `docs/implement-issues-flow.md` and `README.md`; that the flow doc has `participant` lines for `Implementers` and `Task reviewers` and none for `Superpowers subagents`; that `README.md` contains `budget`, `balanced`, `max` and `Codex`; that `AGENTS.md` names `review-brief.md`.

- [ ] **Step 2: Run it and watch it fail**

Run: `bash scripts/check.sh`
Expected: `CHECKS FAILED` on those strings.

- [ ] **Step 3: Update the flow map**

Split the `Superpowers subagents` participant into `Implementers` (implementer, escalation seats) and `Task reviewers` (task-reviewer, re-reviewer, final-reviewer seats), re-pointing each arrow to the right one. Settings and Every model seat: add the Agents table, presets and precedence, each in one short paragraph pointing at the skill. Stage 7: one paragraph on the Codex path (read-only, report-only, the dispatcher posts).

- [ ] **Step 4: Update README and AGENTS.md**

README: one paragraph on the six agents and presets, one on Codex as a reviewer (read-only; the dispatcher posts), and the Requirements row gains "the Codex CLI, logged in, when the Review agent uses Codex". AGENTS.md: add `.../assets/review-brief.md` to the assets paragraph, and extend the `implement-issues` settings bullet: models are set per agent with presets, and Codex may only review, read-only.

- [ ] **Step 5: Run the checks and watch them pass**

Run: `bash scripts/check.sh`
Expected: `all checks passed`.

- [ ] **Step 6: Commit and open the pull request**

```bash
git add scripts/check.sh docs/implement-issues-flow.md README.md AGENTS.md
git commit -m "docs: describe per-agent models, presets and Codex reviews"
```

Then push the branch and open the pull request for Tasks 1–5.

---

### Task 6: The site, after the first pull request merges

**Files:**
- Modify: `index.html` on the `docs` branch (a new worktree from `origin/docs`)

**Interfaces:**
- Consumes: the merged text of Tasks 1–5.

- [ ] **Step 1: Write the failing check**

Run: `for a in "Planner" "Build lead" "Implementers" "Task reviewers" "Review agent" "PR code reviewer" "budget" "Codex"; do grep -q "$a" index.html || echo "missing: $a"; done`
Expected: at least `missing: Implementers`, `missing: Task reviewers`, `missing: budget` and `missing: Codex`.

- [ ] **Step 2: Update `index.html`**

The Models card: "One model for each of six agents, or one preset — budget, balanced or max — for all of them." The "Who runs what" columns: split Superpowers subagents into Implementers and Task reviewers. Add one line under the Review agent: it can run on Codex, read-only, and the dispatcher posts its review.

- [ ] **Step 3: Run the check again**

Run: the Step 1 loop.
Expected: no output.

- [ ] **Step 4: Commit and open the pull request against `docs`**

```bash
git add index.html
git commit -m "docs: show per-agent models, presets and Codex reviews on the site"
```

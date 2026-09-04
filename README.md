# Intent to PR

Three workflow skills turn a conversation into a tracked issue, then carry that issue's intent through spec, plan, and pull request without re-deriving it at each step. A separate setup skill establishes shared agent instructions, and [`anti-koshary`](#anti-koshary) audits the codebase you end up with.

The problem this solves: brainstorming happens in chat, gets summarized into an issue, and then the implementation planning starts from a blank page — re-asking questions the issue already answered, and producing artifacts with no link back to where the idea came from. These skills make one issue the reference point every later artifact traces back to.

## The pipeline

```
setup-agent-instructions  (optional, once per repo)
        │
        ▼
configure-issue-tracker   (once per repo)
        │
        ▼
brainstorm-to-issue  ──▶  intent issue #N
        │
        ▼
superpowers-issue-bridge
        │
        ├──▶ Superpowers brainstorming  ──▶  spec.md   (Intent-Issue: #N)
        ├──▶ Superpowers writing-plans  ──▶  plan.md   (Intent-Issue: #N)
        └──▶ PR body                    ──▶  Closes #N / Relates to #N
```

Each stage is deliberately narrow and disclaims the next one's job.

### `setup-agent-instructions`

Run once when a repository needs one canonical instruction file. It creates
`AGENTS.md` for shared guidance and a `CLAUDE.md` that imports it. It does not
configure an issue tracker or add the intent-to-PR workflow.

Existing guidance is never overwritten silently. If `CLAUDE.md` contains real
content, the skill shows it and asks how to preserve it before making any
change.

### `configure-issue-tracker`

Run before skills that need a durable issue or intent location. It records the
confirmed backend in `docs/agents/issue-tracker.md`: GitHub (`owner/repo`),
local markdown under `.scratch/`, or a freeform description of another system
such as Jira or Linear.

If `AGENTS.md` exists, it can add the tracker pointer and intent-to-PR workflow
after showing the exact patch. It never creates instruction files or mutates a
remote tracker during configuration, and re-running it with the same values is
a no-op.

### `brainstorm-to-issue`

Once a brainstorm is done, turns it into a GitHub issue using a fixed five-section template:

| Section | What goes in it |
| --- | --- |
| Problem | What's wrong today, for whom, why it matters |
| Proposed outcome | What "better" looks like — an outcome, not an implementation |
| Affected users and systems | Who and what this touches |
| Constraints | Hard limits already stated: compliance, security, scope, deadlines |
| Open questions | Genuinely unresolved things, left unresolved |

It captures **intent only**. Alternatives considered, out-of-scope boundaries, and edge cases are spec work, and belong to the next stage. Sections with no real content get "None identified" rather than invented filler, and the draft is always shown for confirmation before anything is created.

### `superpowers-issue-bridge`

Connects the intent issue to the [Superpowers](https://github.com/obra/superpowers) skills:

- Seeds Superpowers' `brainstorming` with the issue's contents as already-answered, so the interview covers what the issue *doesn't* — while carrying its "Open questions" forward as still open.
- Writes `Intent-Issue: #<number> — <url>` into `spec.md`, and carries the line unchanged into `plan.md`, so `gh issue view` and a repo grep both lead back to the same thread.
- At PR time, asks once whether the work fully resolves the issue (`Closes #N`) or is partial (`Relates to #N`). It never guesses — an intent issue is often bigger than one PR, and auto-closing it early breaks the audit trail.

It lives as a separate skill rather than as edits to Superpowers' own files, so Superpowers updates can't clobber it.

## `anti-koshary`

Independent of the pipeline above — install it on its own if that's all you want.

A two-pass audit for a codebase that has started to congeal. The name is from
[koshary code](https://ismail9k.com/blog/koshary-code): rice, pasta and lentils are each
fine, but once mixed you will never separate them again, and neither will you separate the
controller from the business rule from the query.

- **Pass 1 reports and changes nothing** — layer collapse, duplication that actually costs
  money, the functions nobody reads, dead code, health checks, and then security and
  dependencies last, each finding with a file, a line, a priority, and a named consequence.
- **Structure is the headline, not security.** Vulnerabilities and CVEs are section 7 of
  seven; the report leads with what makes the codebase hard to change. A live credential is
  still Critical and still gets fixed first — that ordering is safety, not emphasis.
- **Pass 2 fixes only after you approve**, in a safe order: anything critical (saying what
  behavior changes), then the structural cleanups you picked, then patch/minor dependency
  bumps, then the remaining security fixes. Major upgrades get flagged, never applied. If a
  group breaks the build, it reverts that group and stops.

It depends on nothing else — no config file, no issue tracker, no companion skill. Install
it alone and run it on any repo, cold.

It ships a `dep_audit.sh` that detects the package manager from the lockfile and runs both
the outdated report and the vulnerability scan across npm/pnpm/yarn/bun, pip/poetry/uv,
cargo, go, bundler, composer and maven. Two reference files carry the parts models get
wrong: how to tell duplication that will drift from duplication that is coincidence, and
which secret-scan hits are false positives.

If the repo has no tests, it says so and refuses to call anything "safe" — "it still
builds" proves the imports resolve, not that behavior survived.

## Intent vs. spec

The intent issue and Superpowers' `spec.md` sit at different altitudes, and have
opposite relationships to uncertainty: the issue keeps a section for open
questions and tells you to leave them unresolved, while the spec's self-review
gate requires ambiguity to be eliminated. The same unknown is preserved in one
and killed in the other — which is why the bridge carries the issue's open
questions forward as the interview's agenda.

| | Intent issue | `spec.md` |
| --- | --- | --- |
| Answers | Why bother, and what "better" looks like | How we'll build it |
| Produced by | Synthesis of a discussion that already happened | An interview — questions, 2–3 approaches, section-by-section approval |
| Needs a repo | No — works from a chat anywhere | Yes — explores files, docs, recent commits first |
| Lives at | The issue tracker | `docs/superpowers/specs/`, committed |
| Lifespan | Outlives the PR; may span several | One spec → one plan → one implementation cycle |

Where each artifact lands in the SDLC:

| Artifact | SDLC phase |
| --- | --- |
| Intent issue | Problem definition (planning → requirements boundary) |
| `spec.md` | Design |
| `plan.md` | Work breakdown / implementation planning |
| PR | Implementation |

Two things the intent issue is *not*. It isn't the "plan phase" — `plan.md` is a
task breakdown for implementation, at the opposite end of the pipeline. And it
isn't a PRD or a product manager's deliverable: it carries no success metrics,
acceptance criteria, or priority, and plenty of intent issues are purely
technical ("CI takes 40 minutes and blocks releases") while still filling all
five sections.

The ratio isn't 1:1. Superpowers decomposes anything too large for a single spec
into sub-projects, each with its own spec → plan → implementation cycle, so one
intent issue can spawn several specs — which is why the bridge asks
`Closes #N` vs `Relates to #N` instead of defaulting.

A spec file is only written on Superpowers' *architectural* path; spike and
bounded work produce no spec and no plan document. For that work the intent
issue is the only durable record of why the change happened.

## Install

Each skill stands alone — install all of them or select only the ones you need.

```bash
npx skills add ismail9k/skills                      # all skills
npx skills add ismail9k/skills@configure-issue-tracker
npx skills add ismail9k/skills@anti-koshary         # just one
npx skills add ismail9k/skills -g                   # user-level, not this project
```

The [Skills CLI](https://skills.sh) works across Claude Code, Codex, Cursor, Gemini CLI and others — it writes to `.agents/skills/` and symlinks each agent's own directory at it.

Or copy them in by hand:

```bash
cp -R skills/* ~/.claude/skills/
```

Use `.claude/skills/` inside a project instead of `~/.claude/skills/` to scope them to that repo.

`brainstorm-to-issue` and the bridge shell out to the [GitHub CLI](https://cli.github.com), so `gh auth status` needs to pass.

## Usage

In a repo you haven't set up yet:

> Run the setup-agent-instructions skill

Then configure where intents live:

> Run the configure-issue-tracker skill

Then, once you've talked a problem through and it's ready to be tracked:

> File this as an issue

And when you're ready to build it:

> Let's implement #42

## Without Claude Code

`brainstorm-to-issue` ships a plain-prompt version at the bottom of its file for agents with no skill discovery — paste the prompt, get a draft back, then create the issue yourself:

```bash
gh issue create --repo <owner>/<repo> --title "<title>" --body-file draft.md --label intent
```

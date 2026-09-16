# Intent to PR

Three workflow skills sit on top of Superpowers' brainstorming. Every brainstorm ends one of two ways: build it now, or track it first as an intent issue. A tracked issue carries its intent through spec, plan, and pull request without being re-derived at each step, and the finished work links back to close it — in GitHub, Jira, or whichever tracker you configured. A separate setup skill establishes shared agent instructions, [`fetch-issues`](#fetch-issues) lists what's open, [`implement-issues`](#implement-issues) has agents build a batch of issues into reviewed pull requests, [`review-prs`](#review-prs) reviews pull requests with suggested changes, [`answer-pr-reviews`](#answer-pr-reviews) answers those reviews, and [`anti-koshary`](#anti-koshary) audits the codebase you end up with.

The problem this solves: brainstorming happens in chat, gets summarized into an issue, and then the implementation planning starts from a blank page — re-asking questions the issue already answered, and producing artifacts with no link back to where the idea came from. These skills make one issue the reference point every later artifact traces back to.

## The pipeline

```
setup-agent-md            (optional, once per repo)
setup-issue-tracker       (once per repo: GitHub, Jira, local markdown, …)

Superpowers brainstorming
        │   problem understood — superpowers-issue-bridge asks:
        │
        ├── build now ───▶ spec ──▶ plan ──▶ code ──▶ PR
        │
        └── track first ─▶ brainstorm-to-issue ──▶ intent issue #N
                                                         │  later: "implement #N" yourself,
                                                         │  or implement-issues for a batch
                                                         ▼
                                              superpowers-issue-bridge
                                                         ├──▶ spec   (Intent-Issue: #N)
                                                         ├──▶ plan   (Intent-Issue: #N)
                                                         └──▶ PR     Closes #N / Relates to #N
                                                                       │
                                                                       ▼
                                                                  review-prs
                                                                       │
                                                                       ▼
                                                                  answer-pr-reviews
```

Each stage is deliberately narrow and disclaims the next one's job.

### `setup-agent-md`

Run once when a repository needs one canonical instruction file. It creates
`AGENTS.md` for shared guidance and a `CLAUDE.md` that imports it. It does not
configure an issue tracker or add the intent-to-PR workflow.

Existing guidance is never overwritten silently. If `CLAUDE.md` contains real
content, the skill shows it and asks how to preserve it before making any
change.

### `setup-issue-tracker`

Run before skills that need a durable issue or intent location. It records the
confirmed backend in `docs/agents/issue-tracker.md`: GitHub (`owner/repo`),
local markdown under `.scratch/`, or a freeform description of another system
such as Jira or Linear.

It also records how the rest of the pipeline reads issues and links work back:
the issue reference format, how to list and read issues, and what a pull
request writes to close or reference one. For GitHub those are GitHub's own
conventions (`#42`, `Closes #42`); for Jira or anything else it asks, so no
later skill assumes GitHub syntax.

If `AGENTS.md` exists, it can add the tracker pointer and intent-to-PR workflow
after showing the exact patch. It never creates instruction files or mutates a
remote tracker during configuration, and re-running it with the same values is
a no-op.

### `brainstorm-to-issue`

The track-first ending of a brainstorm. It turns the conversation into an intent issue in your configured tracker, using a fixed five-section template:

| Section | What goes in it |
| --- | --- |
| Problem | What's wrong today, for whom, why it matters |
| Proposed outcome | What "better" looks like — an outcome, not an implementation |
| Affected users and systems | Who and what this touches |
| Constraints | Hard limits already stated — compliance, security, scope, deadlines — plus every decision you explicitly made. Whoever builds the issue treats this as binding. |
| Open questions | Genuinely unresolved things, left unresolved |

It captures **intent**, not a spec. Approaches that were only considered, edge cases, and undecided design are spec work, done when the issue is built. Sections with no real content get "None identified" rather than invented filler, and the draft is always shown for confirmation before anything is created. Once the issue exists, the session ends — no spec, no plan, no code.

### `superpowers-issue-bridge`

Connects intent issues to the [Superpowers](https://github.com/obra/superpowers) skills:

- **Offers the choice.** When brainstorming starts with no intent issue, it asks — once the problem is understood, before any approach is proposed — whether to build now or track it first. It skips the question when you've already said, or when the work is a spike.
- **Seeds brainstorming** with an existing issue's contents as already answered, so the interview covers what the issue *doesn't* — treating its Constraints as settled and carrying its "Open questions" forward as still open.
- **Traces** — writes `Intent-Issue: #<number> — <url>` under the spec's title and carries the line unchanged into the plan, so `gh issue view` and a repo grep both lead back to the same thread. Spike and bounded work write no spec or plan, and it doesn't invent one.
- **Links the work back** when it lands — asks once whether it fully resolves the issue (`Closes #N`) or is partial (`Relates to #N`), in your tracker's own syntax. A local merge has no PR to carry the link, so it offers to close the issue by hand instead. It never guesses — an intent issue is often bigger than one PR, and closing it early breaks the audit trail.

It lives as a separate skill rather than as edits to Superpowers' own files, so Superpowers updates can't clobber it.

## `fetch-issues`

A read-only utility: lists the open issues in your tracker with their complete bodies, and never changes an issue. It works on GitHub out of the box, and on any other tracker whose tracker config says how to list issues. It needs no other skill — without a tracker config, it asks which repository or project to read.

## Building and reviewing with agents

These skills work in Claude Code, Codex, and other agents; `implement-issues` needs one that can dispatch subagents.

### `implement-issues`

Builds a batch of open issues, one pull request each. It gets the queue from `fetch-issues`, then asks two things: which model the implementers use — from the models your agent actually offers — and whether to build the issues one at a time or several in parallel.

Each issue gets its own worktree and branch (`feat/42-…`) and an agent that takes it through the usual flow: a spec seeded from the issue by the bridge, a plan, and Superpowers' subagent-driven development. Nobody is there to answer its questions, so it answers them from the issue and records every decision. The dispatcher re-runs the checks itself, then opens a draft pull request with `Closes #42` — or `Relates to #42`, naming what's left, when the work is partial — and the agent's decisions listed in the body. Steps nothing in the repository can do, like provisioning a service or checking a page by hand, are listed as follow-ups and don't make the work partial. At the end it asks whether each partial pull request fully resolves its issue anyway, and switches it to `Closes #42`, or your tracker's own closing syntax, if you say yes. If your tracker has nothing a pull request can write to close an issue, it tells you which issues to close by hand once their pull requests merge.

Next, a separate agent runs `review-prs` on the draft and leaves its findings as comments. The agent that built the issue answers them with `answer-pr-reviews`: it fixes what holds, pushes back on what doesn't, pushes the fixes, and replies in each thread. The dispatcher re-runs the checks with `verification-before-completion` and marks the pull request ready. A pull request stays a draft when the checks fail or a finding couldn't be fixed. It never merges.

### `review-prs`

Reviews one pull request, a list, or all open ones, and leaves the findings as inline comments — with a GitHub suggested change wherever the fix is concrete, so the author applies it with one click. Each pull request gets two passes: does it do what its linked intent issue asks, and is the code right? Findings are checked against the code before they're posted, and the review is always a comment — approval stays with you.

### `answer-pr-reviews`

Answers the review on the pull requests you name, or on all your open ones that have unanswered feedback. It's a proxy for Superpowers' `receiving-code-review`, which decides what to do with each comment but takes no pull request: this skill collects each pull request's unresolved threads and the findings in its review bodies, checks out its branch, and hands the feedback over. Once the fixes are pushed — never forced — it replies in every thread, naming the commit for each fix and the reason for each pushback. It resolves no threads and never marks a pull request ready; that stays with you.

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

## Requirements

What to install depends on which skills you use. Every skill assumes `git`.

| Skill | Needs |
| --- | --- |
| `setup-agent-md` | Nothing else |
| `setup-issue-tracker` | Nothing else |
| `brainstorm-to-issue` | `gh` for a GitHub tracker, or your tracker's own tool |
| `superpowers-issue-bridge` | Superpowers; `gh` for a GitHub tracker |
| `fetch-issues` | `gh` for a GitHub tracker, or your tracker's own tool |
| `implement-issues` | Superpowers, `gh`, an agent with subagents, and the `fetch-issues`, `superpowers-issue-bridge`, `review-prs`, and `answer-pr-reviews` skills installed alongside it |
| `review-prs` | Superpowers and `gh`; subagents optional — without them it reviews inline |
| `answer-pr-reviews` | Superpowers and `gh` |
| `anti-koshary` | Nothing required; optional audit tools make its dependency scan complete |

### Node.js — for the Skills CLI

`npx skills add` needs [Node.js](https://nodejs.org), which ships `npx`. Skip it if you copy the skills in by hand.

### Superpowers

The workflow skills hand off to [Superpowers](https://github.com/obra/superpowers). Install it separately for each agent you use:

| Agent | Install |
| --- | --- |
| Claude Code | `/plugin install superpowers@claude-plugins-official` |
| Codex CLI | Run `/plugins`, search for `superpowers`, then choose Install Plugin |
| Codex App | Plugins in the sidebar, then the `+` next to Superpowers |
| Cursor | `/add-plugin superpowers` in Agent chat |
| Gemini CLI | `gemini extensions install https://github.com/obra/superpowers` |
| GitHub Copilot CLI | `copilot plugin marketplace add obra/superpowers-marketplace`, then `copilot plugin install superpowers@superpowers-marketplace` |

Other agents are covered in the [Superpowers installation guide](https://github.com/obra/superpowers#installation).

### GitHub CLI (`gh`)

```bash
brew install gh     # macOS; for other platforms see https://cli.github.com
gh auth login
gh auth status      # must pass before the skills use gh
```

Needed when your tracker is GitHub, and always for `implement-issues`, `review-prs`, and `answer-pr-reviews` — pull requests live on GitHub even when issues live elsewhere.

### Subagents — for `implement-issues` and `review-prs`

Claude Code has them built in. Codex needs them switched on in `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

On any other agent, check that it can dispatch subagents before running `implement-issues` — it builds each issue with Superpowers' subagent-driven development.

### Your tracker's tool — for Jira, Linear, and others

Whatever reads and writes your tracker — a CLI or an MCP server — installed and signed in. `setup-issue-tracker` records which one, so the other skills know how to reach it.

### Dependency audit tools — optional, for `anti-koshary`

`dep_audit.sh` uses the built-in audit of `npm`, `pnpm`, `yarn`, `bun`, and `composer`. Other ecosystems need a scanner installed for the vulnerability half of the report; the script skips anything missing and says so.

| Ecosystem | Install |
| --- | --- |
| Python | `pip install pip-audit` |
| Rust | `cargo install cargo-audit cargo-outdated` |
| Go | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| Ruby | `gem install bundler-audit` |

## Install

The plugin is named **`9k`**. Individual skill names stay the same, including
`setup-agent-md`.

### Claude Code — `/9k:…` commands

To load this checkout, start Claude Code from the project you want to work on
and pass the absolute path to this repository:

```bash
claude --plugin-dir /absolute/path/to/skills
```

Then invoke a skill in Claude Code:

```text
/9k:setup-agent-md
/9k:setup-issue-tracker
/9k:anti-koshary
```

This loads the plugin for that session. Run `/reload-plugins` after editing
the checkout. Current Claude Code also supports persistent plugins inside
`~/.claude/skills/`: place the plugin root (containing `.claude-plugin/` and
`skills/`) in `~/.claude/skills/9k/`, then start a new session. Preserve any
existing directory before putting a copy there. See the
[Claude Code plugin guide](https://code.claude.com/docs/en/plugins).

### Codex — install the skills

From this repository, run:

```bash
npx skills add . -g
```

Select Codex and the skills you want in the installer. The local `.` source
uses this checkout, including changes that have not been pushed. Global
installation makes the skills available across projects.

In Codex CLI or the IDE extension, type `$` to select a skill, or use `/skills`.
For example:

```text
$setup-agent-md
$setup-issue-tracker
$anti-koshary
```

You can also ask, "Use the setup-agent-md skill." This installs standalone
skills; the plugin's `9k` namespace does not change their names. Codex discovers
user skills in `~/.agents/skills/` and repository skills in `.agents/skills/`.
Restart Codex if a newly installed skill does not appear. See the
[Codex skill guide](https://learn.chatgpt.com/docs/build-skills).

### Other agents and individual installs

Each skill stands alone — install all of them or select only the ones you need.

```bash
npx skills add ismail9k/skills                      # all skills
npx skills add ismail9k/skills@setup-issue-tracker
npx skills add ismail9k/skills@anti-koshary         # just one
npx skills add ismail9k/skills -g                   # user-level, not this project
```

The [Skills CLI](https://skills.sh) works across Claude Code, Codex, Cursor, Gemini CLI and others — it writes to `.agents/skills/` and symlinks each agent's own directory at it.

Or copy them in by hand:

```bash
cp -R skills/* ~/.claude/skills/
```

Use `.claude/skills/` inside a project instead of `~/.claude/skills/` to scope them to that repo.

Installing `implement-issues` on its own isn't enough — it also needs `fetch-issues`, `superpowers-issue-bridge`, `review-prs`, and `answer-pr-reviews`:

```bash
npx skills add ismail9k/skills@implement-issues
npx skills add ismail9k/skills@fetch-issues
npx skills add ismail9k/skills@superpowers-issue-bridge
npx skills add ismail9k/skills@review-prs
npx skills add ismail9k/skills@answer-pr-reviews
```

## Usage

In a repo you haven't set up yet:

> Run the setup-agent-md skill

Then configure where intents live:

> Run the setup-issue-tracker skill

Then brainstorm with Superpowers as usual. Once it understands the problem, the bridge asks:

> Do you want to build this now, or track it as an intent issue first?

Pick track first — or just say "file this as an issue" — and the session ends with an intent issue. When you're ready to build it:

> Let's implement #42

Or have agents build several tracked issues at once, then review what they opened:

> Work through the open issues

> Review the open PRs

And when reviews land on your own pull requests:

> Answer the reviews on my PRs

## Without Claude Code

`brainstorm-to-issue` ships a plain-prompt version at the bottom of its file for agents with no skill discovery — paste the prompt, get a draft back, then create the issue yourself:

```bash
gh issue create --repo <owner>/<repo> --title "<title>" --body-file draft.md --label intent
```

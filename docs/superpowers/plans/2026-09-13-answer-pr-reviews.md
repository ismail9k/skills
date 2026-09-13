# answer-pr-reviews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `answer-pr-reviews`, a thin proxy that points Superpowers' `receiving-code-review` at GitHub pull requests, and make `implement-issues` dispatch it for its review round.

**Architecture:** One new Markdown skill (`skills/answer-pr-reviews/SKILL.md`) that owns only the GitHub mechanics — pick pull requests, gather unanswered feedback, check out the branch, push, reply — and invokes `receiving-code-review` for every judgment. `implement-issues` Stage 7 and its brief name the new skill instead of restating the mechanics; `AGENTS.md` and `README.md` describe it.

**Tech Stack:** Markdown skills, `gh` (REST + GraphQL), git worktrees, `bash scripts/check.sh`.

**Spec:** `docs/superpowers/specs/2026-09-13-answer-pr-reviews-design.md`

## Global Constraints

- The name `answer-pr-reviews` must match in the directory, the frontmatter `name:`, and `.claude-plugin/plugin.json`.
- Skills reference each other by name only, never by path (`check.sh` section 3).
- Write in actions ("dispatch an agent"), never one platform's tool names; never hardcode a model name.
- Every reply the skill posts ends with the marker `<!-- answer-pr-reviews -->`, exactly.
- The skill never force-pushes, resolves a thread, dismisses a review, approves, merges, or marks a pull request ready.
- It never restates `receiving-code-review`'s rules — it invokes that skill.
- Every skill ends with a "What NOT to do" section.
- Run `bash scripts/check.sh` before every commit. Commit locally; pushing waits for the user.

---

### Task 1: Create the answer-pr-reviews skill

**Files:**
- Create: `skills/answer-pr-reviews/SKILL.md`
- Modify: `.claude-plugin/plugin.json` (the `skills` array)

**Interfaces:**
- Produces: the skill name `answer-pr-reviews`, invoked as `answer-pr-reviews #<number>` on `<owner/repo>`; its dispatched mode ("dispatched with that go-ahead already given") and its report (fixed / pushed back / couldn't fix per pull request), which Task 2 relies on.

- [ ] **Step 1: Declare the skill in the manifest (the failing test)**

In `.claude-plugin/plugin.json`, change

```json
    "./skills/review-prs",
    "./skills/anti-koshary"
```

to

```json
    "./skills/review-prs",
    "./skills/answer-pr-reviews",
    "./skills/anti-koshary"
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `bash scripts/check.sh`
Expected: FAIL with `declared but missing on disk: answer-pr-reviews`

- [ ] **Step 3: Write the skill**

Create `skills/answer-pr-reviews/SKILL.md` with exactly:

`````markdown
---
name: answer-pr-reviews
description: >
  Use when the user asks to answer, address, or reply to review comments on
  one or more GitHub pull requests — "answer the review on #12", "address the
  comments on my PRs", "reply to the review findings" — in Claude Code, Codex,
  or any other agent. Not for reviewing a pull request, and not for feedback
  given in the conversation.
---

# Answer PR Reviews

Point Superpowers' `receiving-code-review` at pull requests. That skill
decides what to do with each review comment — fix what holds, push back on
what doesn't — but it takes no pull request and fetches nothing. This skill
supplies the rest: which pull requests, the unanswered feedback on each, a
checkout of its branch, and the push and replies that close the loop.

It answers the pull requests the user names, or all of the user's own open
pull requests with unanswered feedback. Every comment gets a reply; no thread
is resolved.

This skill names actions, not tools. Use your platform's equivalents.

## Requirements

- Superpowers (`receiving-code-review`, `verification-before-completion`). If
  one is missing, name it and stop.
- A GitHub repository and `gh`, with `gh auth status` passing; otherwise say
  why and stop.

## Stage 1 — Pick the pull requests

1. Repository: the one the user names, else this checkout's GitHub repository
   (`gh repo view --json nameWithOwner`). Say which you used.
2. Pull requests: the ones the user names; for "all" or "my PRs",
   `gh pr list --repo <owner/repo> --state open --author "@me" --limit 1000 --json number,title,url`,
   keeping those with unanswered feedback by Stage 2. Answer another author's
   pull request only when the user names it.
3. Print the list with each pull request's count of unanswered items, and say
   that fixes will be pushed to each branch and replies posted. The user's
   confirmation is the go-ahead — unless you were dispatched with that
   go-ahead already given, as `implement-issues` does; then print the list and
   continue.

## Stage 2 — Gather the unanswered feedback

1. Fetch the pull request, its review threads, its reviews, and its
   conversation comments:

   ```bash
   gh api graphql -f owner=<owner> -f repo=<repo> -F number=<number> -f query='
   query($owner: String!, $repo: String!, $number: Int!) {
     repository(owner: $owner, name: $repo) {
       pullRequest(number: $number) {
         title body url headRefName
         reviewThreads(first: 100) {
           nodes {
             isResolved isOutdated path line
             comments(first: 100) { nodes { databaseId author { login } body } }
           }
         }
         reviews(first: 100) { nodes { author { login } body url } }
         comments(last: 100) { nodes { body } }
       }
     }
   }'
   ```

2. The items to answer:
   - every unresolved thread whose last comment doesn't end with
     `<!-- answer-pr-reviews -->` — outdated threads included, since the
     finding may survive the code that moved;
   - every finding written in a review's body, unless a conversation comment
     carrying the marker links that review's `url`. Severity counts and "no
     findings" summaries are not findings.

   The marker, not the author, tells answered from unanswered: one `gh`
   account can post both the review and the replies, as `implement-issues`
   does.
3. When `docs/agents/issue-tracker.md` exists and the title or body carries a
   reference from its Linking section — on GitHub, `Closes #<number>` or
   `Relates to #<number>` — read that intent issue with the Reading method and
   keep its Constraints.

Handle the pull requests one at a time from here. One with nothing left to
answer is done: say so.

## Stage 3 — Check out the branch

1. Dispatched with a worktree: work there.
2. Otherwise use an existing checkout of `headRefName` (`git worktree list`)
   when it has no uncommitted changes. One with uncommitted changes: stop for
   this pull request and say why — never stash, discard, or commit someone's
   changes.
3. No checkout: create one. `gh pr checkout` also sets up where the branch
   pushes, including a fork's.

   ```bash
   git check-ignore -q .worktrees || echo ".worktrees/" >> "$(git rev-parse --git-common-dir)/info/exclude"
   git worktree add --detach ".worktrees/pr-<number>"
   cd ".worktrees/pr-<number>" && gh pr checkout <number> --repo <owner/repo>
   ```

## Stage 4 — Answer with receiving-code-review

Invoke `receiving-code-review` in the checkout. The feedback is the items from
Stage 2, each with its path, line, and whole thread; the intent issue's
Constraints are the user's prior decisions.

- Run by the user: its questions go to the user.
- Dispatched with the go-ahead: no one can answer. Where it says to ask or to
  stop and discuss, decide, and give the reason in that item's reply.

Commit each fix on its own, so its reply can name the commit. Keep a record,
per item, of the outcome — fixed (with the commit), pushed back (with the
reason), or couldn't fix (with what failed); the replies are written from it.

## Stage 5 — Push, then reply

1. Run the project's test, lint, and typecheck commands — from `AGENTS.md` or
   the project's manifest — under `verification-before-completion`. When they
   fail, revert the fixes that broke them (those items become couldn't fix)
   and run them again. Still failing: don't push, reply to nothing, and report
   it.
2. With new commits, `git push` — never force. A rejected push: stop for this
   pull request, reply to nothing, and report it.
3. Once the push lands, reply to every item, ending each reply with
   `<!-- answer-pr-reviews -->`:
   - An inline thread — inside the thread, to its first comment:

     ```bash
     gh api --method POST repos/<owner>/<repo>/pulls/<number>/comments/<first comment databaseId>/replies -F body=@reply.md
     ```

     `Fixed in <sha> — <what changed>.`, or the pushback's reason, or what was
     tried and why it couldn't be fixed.
   - Review-body findings — one conversation comment that links the review's
     `url` and answers each finding in order:
     `gh pr comment <number> --repo <owner/repo> --body-file reply.md`.

## Stage 6 — Report

One table: pull request, items answered, fixed / pushed back / couldn't fix,
checks result, and the pushed head — or why nothing was pushed. Then every
pull request left out, and why.

## What NOT to do

- Don't decide an item yourself — `receiving-code-review` decides; this skill
  fetches, pushes, and replies.
- Don't reply "Fixed" before its commit is pushed.
- Don't push when the checks fail, and never force-push.
- Don't resolve a thread, dismiss a review, approve, merge, or mark a pull
  request ready — accepting the work stays with the user.
- Don't answer an inline comment with a conversation comment.
- Don't answer another author's pull request unless the user named it.
- Don't stash, discard, or commit someone's uncommitted changes to get a
  checkout.
- Don't answer an item that already carries this skill's reply.
`````

- [ ] **Step 4: Run the check to verify it passes**

Run: `bash scripts/check.sh`
Expected: `ok    answer-pr-reviews` under the name, path-coupling, and manifest sections, ending `all checks passed`.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json skills/answer-pr-reviews/SKILL.md
git commit -m "feat(answer-pr-reviews): answer the review on pull requests through receiving-code-review"
```

---

### Task 2: Dispatch answer-pr-reviews from implement-issues

**Files:**
- Modify: `skills/implement-issues/SKILL.md` (intro, Requirements, Stage 7 step 1)
- Modify: `skills/implement-issues/assets/issue-brief.md` (step 4)

**Interfaces:**
- Consumes: `answer-pr-reviews #<number>` on `<owner/repo>`, its dispatched mode, and its report (Task 1).

- [ ] **Step 1: Write the failing test**

Run:

```bash
grep -n "answer-pr-reviews" skills/implement-issues/SKILL.md skills/implement-issues/assets/issue-brief.md
grep -n "receiving-code-review" skills/implement-issues/SKILL.md
```

- [ ] **Step 2: Verify it fails**

Expected: the first command prints nothing; the second prints lines 22, 35, and 148.

- [ ] **Step 3: Edit the intro**

In `skills/implement-issues/SKILL.md`, replace

```markdown
Each pull request opens as a draft. A second agent runs `review-prs` on it,
and the agent that built the issue answers that review with Superpowers'
`receiving-code-review`. The pull request is marked ready once the review is
answered and the checks still pass.
```

with

```markdown
Each pull request opens as a draft. A second agent runs `review-prs` on it,
and the agent that built the issue answers that review with
`answer-pr-reviews`. The pull request is marked ready once the review is
answered and the checks still pass.
```

- [ ] **Step 4: Edit Requirements**

Replace

```markdown
- Superpowers (`brainstorming`, `writing-plans`, `subagent-driven-development`,
  `finishing-a-development-branch`, `receiving-code-review`,
  `verification-before-completion`), plus the
  `fetch-issues`, `superpowers-issue-bridge`, and `review-prs` skills. If one
  is missing, name it and stop.
```

with

```markdown
- Superpowers (`brainstorming`, `writing-plans`, `subagent-driven-development`,
  `finishing-a-development-branch`, `verification-before-completion`), plus
  the `fetch-issues`, `superpowers-issue-bridge`, `review-prs`, and
  `answer-pr-reviews` skills. If one is missing, name it and stop.
```

- [ ] **Step 5: Edit Stage 7, step 1**

Replace

```markdown
1. Message the agent that built the issue — or, if it can no longer be
   messaged, dispatch a new one into the same worktree — to answer the review
   on `#<number>` with `receiving-code-review`: fix what holds, push back on
   what doesn't, push the branch (never force), and reply in each comment's
   thread as that skill describes. No one can answer its questions: where the
   skill says to ask, it decides and gives the reason in its reply, and the
   issue's Constraints stand for the user's prior decisions.
```

with

```markdown
1. Message the agent that built the issue — or, if it can no longer be
   messaged, dispatch a new one into the same worktree — to run
   `answer-pr-reviews #<number>` on `<owner/repo>` in that worktree, telling
   it the user's go-ahead for this run covers pushing the fixes and replying
   to each comment.
```

- [ ] **Step 6: Edit the brief**

In `skills/implement-issues/assets/issue-brief.md`, replace

```markdown
   your branch, pushes it, and opens a draft pull request. Another agent
   reviews it, and you may then be asked to answer that review.
```

with

```markdown
   your branch, pushes it, and opens a draft pull request. Another agent
   reviews it, and you may then be asked to answer that review with
   `answer-pr-reviews`.
```

- [ ] **Step 7: Run the test to verify it passes**

Run the two commands from Step 1, then `bash scripts/check.sh`.
Expected: the first prints the intro, Requirements, Stage 7, and brief lines; the second prints nothing; `all checks passed`.

- [ ] **Step 8: Commit**

```bash
git add skills/implement-issues/SKILL.md skills/implement-issues/assets/issue-brief.md
git commit -m "feat(implement-issues): answer each review with answer-pr-reviews"
```

---

### Task 3: Describe answer-pr-reviews in AGENTS.md and README

**Files:**
- Modify: `AGENTS.md:34`, `:36`, `:41`, `:59`, `:90`, `:91`
- Modify: `README.md:3`, `:28`, `:92`, `:100`, after `:104`, `:191-192`, `:222`, `:327-334`, the Usage section

- [ ] **Step 1: Write the failing test**

Run:

```bash
grep -c "answer-pr-reviews" AGENTS.md README.md
grep -n "Eight skills\|answers with Superpowers' \`receiving-code-review\`\|answers them with Superpowers'" AGENTS.md README.md
```

- [ ] **Step 2: Verify it fails**

Expected: `AGENTS.md:0` and `README.md:0`; the second command prints `AGENTS.md:36`, `AGENTS.md:91`, and `README.md:100`.

- [ ] **Step 3: Edit AGENTS.md**

Line 34 — replace

```markdown
`implement-issues` and `review-prs` carry that past the issue: agents build tracked issues into draft PRs, a separate agent reviews each one with `review-prs`, and the building agent answers the review before the PR is marked ready. `review-prs` also reviews any PR on its own.
```

with

```markdown
`implement-issues`, `review-prs`, and `answer-pr-reviews` carry that past the issue: agents build tracked issues into draft PRs, a separate agent reviews each one with `review-prs`, and the building agent answers the review with `answer-pr-reviews` before the PR is marked ready. `review-prs` also reviews any PR on its own, and `answer-pr-reviews` answers the review on any PR.
```

Line 36 — replace `Eight skills in four groups.` with `Nine skills in four groups.`

Line 41 — replace

```markdown
| **Delivery** | `implement-issues` → `review-prs` | Yes — read `docs/agents/issue-tracker.md`; `implement-issues` builds on `fetch-issues`, the bridge, and Superpowers, and dispatches `review-prs` on each PR it opens |
```

with

```markdown
| **Delivery** | `implement-issues` → `review-prs` → `answer-pr-reviews` | Yes — read `docs/agents/issue-tracker.md`; `implement-issues` builds on `fetch-issues`, the bridge, and Superpowers, and dispatches `review-prs` and then `answer-pr-reviews` on each PR it opens |
```

Line 59 — after `├── review-prs/               SKILL.md` insert

```
├── answer-pr-reviews/        SKILL.md
```

Line 90 — replace

```markdown
- `implement-issues` and `review-prs` must run in any agent that can dispatch subagents — Claude Code, Codex, Gemini CLI, and others.
```

with

```markdown
- `implement-issues`, `review-prs`, and `answer-pr-reviews` must run in any capable agent — Claude Code, Codex, Gemini CLI, and others; `implement-issues` needs one that can dispatch subagents.
```

Line 91 — replace

```markdown
- `implement-issues` never merges and never pushes the base branch; `review-prs` never approves, requests changes, or pushes to a PR branch. Both hand the final call to the user — keep it that way.
```

with

```markdown
- `implement-issues` never merges and never pushes the base branch; `review-prs` never approves, requests changes, or pushes to a PR branch; `answer-pr-reviews` never force-pushes, resolves a thread, approves, merges, or marks a PR ready. All three hand the final call to the user — keep it that way.
```

and, in the same line, replace

```markdown
a new agent runs `review-prs`, and the agent that built the issue answers with Superpowers' `receiving-code-review` — it, never `review-prs`, pushes the fixes, and it never reviews its own PR. Don't add briefs that re-describe what those skills already do.
```

with

```markdown
a new agent runs `review-prs`, and the agent that built the issue answers with `answer-pr-reviews` — it, never `review-prs`, pushes the fixes, and it never reviews its own PR. Don't add briefs that re-describe what those skills already do.
- `answer-pr-reviews` is a proxy: it points Superpowers' `receiving-code-review` at pull requests — picking them, gathering the unanswered feedback, pushing, and replying — and leaves every judgment about the feedback to that skill. Don't grow it a copy of that skill's rules. Its replies end with `<!-- answer-pr-reviews -->`, which is how it tells answered threads from unanswered ones when one `gh` account posts both the review and the replies; don't swap it for an author check.
```

- [ ] **Step 4: Edit README.md**

Line 3 — replace

```markdown
[`review-prs`](#review-prs) reviews pull requests with suggested changes, and [`anti-koshary`](#anti-koshary) audits the codebase you end up with.
```

with

```markdown
[`review-prs`](#review-prs) reviews pull requests with suggested changes, [`answer-pr-reviews`](#answer-pr-reviews) answers those reviews, and [`anti-koshary`](#anti-koshary) audits the codebase you end up with.
```

Line 28 — after the `review-prs` line of the pipeline diagram, append

```
                                                                       │
                                                                       ▼
                                                                  answer-pr-reviews
```

Line 92 — replace

```markdown
Both skills work in Claude Code, Codex, and any other agent that can dispatch subagents.
```

with

```markdown
These skills work in Claude Code, Codex, and other agents; `implement-issues` needs one that can dispatch subagents.
```

Line 100 — replace

```markdown
The agent that built the issue answers them with Superpowers' `receiving-code-review`: it fixes what holds, pushes back on what doesn't, and replies in each thread.
```

with

```markdown
The agent that built the issue answers them with `answer-pr-reviews`: it fixes what holds, pushes back on what doesn't, pushes the fixes, and replies in each thread.
```

After the `review-prs` section's paragraph (line 104), insert

```markdown

### `answer-pr-reviews`

Answers the review on the pull requests you name, or on all your open ones that have unanswered feedback. It's a proxy for Superpowers' `receiving-code-review`, which decides what to do with each comment but takes no pull request: this skill collects each pull request's unresolved threads and the findings in its review bodies, checks out its branch, and hands the feedback over. Once the fixes are pushed — never forced — it replies in every thread, naming the commit for each fix and the reason for each pushback. It resolves no threads and never marks a pull request ready; that stays with you.
```

Lines 191–192 — replace

```markdown
| `implement-issues` | Superpowers, `gh`, an agent with subagents, and the `fetch-issues`, `superpowers-issue-bridge`, and `review-prs` skills installed alongside it |
| `review-prs` | Superpowers and `gh`; subagents optional — without them it reviews inline |
```

with

```markdown
| `implement-issues` | Superpowers, `gh`, an agent with subagents, and the `fetch-issues`, `superpowers-issue-bridge`, `review-prs`, and `answer-pr-reviews` skills installed alongside it |
| `review-prs` | Superpowers and `gh`; subagents optional — without them it reviews inline |
| `answer-pr-reviews` | Superpowers and `gh` |
```

Line 222 — replace `always for \`implement-issues\` and \`review-prs\`` with `always for \`implement-issues\`, \`review-prs\`, and \`answer-pr-reviews\``.

Lines 327–334 — replace

````markdown
Installing `implement-issues` on its own isn't enough — it also needs `fetch-issues`, `superpowers-issue-bridge`, and `review-prs`:

```bash
npx skills add ismail9k/skills@implement-issues
npx skills add ismail9k/skills@fetch-issues
npx skills add ismail9k/skills@superpowers-issue-bridge
npx skills add ismail9k/skills@review-prs
```
````

with

````markdown
Installing `implement-issues` on its own isn't enough — it also needs `fetch-issues`, `superpowers-issue-bridge`, `review-prs`, and `answer-pr-reviews`:

```bash
npx skills add ismail9k/skills@implement-issues
npx skills add ismail9k/skills@fetch-issues
npx skills add ismail9k/skills@superpowers-issue-bridge
npx skills add ismail9k/skills@review-prs
npx skills add ismail9k/skills@answer-pr-reviews
```
````

Usage — replace

```markdown
Or have agents build several tracked issues at once, then review what they opened:

> Work through the open issues

> Review the open PRs
```

with

```markdown
Or have agents build several tracked issues at once, then review what they opened:

> Work through the open issues

> Review the open PRs

And when reviews land on your own pull requests:

> Answer the reviews on my PRs
```

- [ ] **Step 5: Run the test to verify it passes**

Run the two commands from Step 1, then `bash scripts/check.sh`.
Expected: both counts above 0; the second command prints nothing; `all checks passed`.

- [ ] **Step 6: Commit**

```bash
git add AGENTS.md README.md
git commit -m "docs: describe answer-pr-reviews and the review round it answers"
```

---

### Task 4: Hand off for pushing

- [ ] **Step 1: Check each commit's own tree**

For every commit from the spec onward, run `bash scripts/check.sh` in a temporary worktree at that commit:

```bash
for sha in $(git rev-list --reverse origin/main..HEAD); do
  wt=$(mktemp -d) && git worktree add -q --detach "$wt" "$sha" \
    && (bash "$wt/scripts/check.sh" > /dev/null && echo "ok   $sha" || echo "FAIL $sha")
  git worktree remove --force "$wt"
done
```

Expected: `ok` for every commit.

- [ ] **Step 2: Report and wait**

Give the user the commit list and the check results. Push each commit to `main` in order only when the user says so.

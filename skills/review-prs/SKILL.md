---
name: review-prs
description: >
  Use when the user asks to review one or more GitHub pull requests — "review
  PR #12", "review the open PRs", "check the PRs the agents opened" — in
  Claude Code, Codex, or any other agent. Not for reviewing uncommitted local
  changes.
argument-hint: "[pr-number...|all] [owner/repo]"
---

# Review PRs

Review pull requests and leave the findings on each one as inline comments,
with a suggested change wherever the fix is concrete, so the author can apply
it with one click. Each pull request gets two passes: does it do what its
intent issue asks, and is the code right?

Suggested changes are a GitHub feature, so this skill needs a GitHub
repository and `gh`. The issue tracker can still be anything — GitHub, Jira,
or local markdown.

This skill names actions — "dispatch a reviewer" — not tools. Use your
platform's equivalents.

## Report-only mode

A caller that can't let its reviewer write — `implement-issues` running the
review on a read-only Codex — dispatches this skill with `Report-only: yes`
and a `Context:` directory. Only then does this mode apply. The directory
holds:

- `pr.json` — the output of
  `gh pr view <number> --json number,url,title,body,baseRefName,headRefOid`;
- `comments.json` — the review comments already on the pull request;
- `issue.md` — the linked intent issue's body, absent when there is none.

The pull request's commits and its base branch are already fetched into the
checkout. In this mode, don't call gh, don't write a file, and don't change
the checkout: read the context directory and the checkout, review exactly as
Stage 3 says, and end your reply with exactly one fenced `json` block holding
the review Stage 4 would have posted — the same `commit_id`, `event`, `body`
and `comments`. After it, list the findings dropped in the check step, and
why. The caller posts the review.

## Stage 1 — Pick the pull requests

In report-only mode, skip this stage: the pull request is the one in
`pr.json`, and the caller has the go-ahead to post.

1. Confirm `gh` is installed and `gh auth status` passes; otherwise say why
   and stop.
2. Repository: the one the user names, else this checkout's GitHub
   repository (`gh repo view --json nameWithOwner`). Say which you used.
3. Pull requests: the ones the user names; for "all" or "the open ones",
   `gh pr list --repo <owner/repo> --state open --limit 1000 --json number,title,url,isDraft`.
   Leave drafts out unless they were named.
4. Print the list and say that findings will be posted on each pull request
   as comments. The user's confirmation of the list is the go-ahead to post —
   unless you were dispatched with that go-ahead already given, as
   `implement-issues` does for the drafts it opens; then print the list and
   continue.

## Stage 2 — Gather each pull request's context

In report-only mode, take the title, body, base and head commit from
`pr.json`, the intent issue from `issue.md`, and the existing comments from
`comments.json`. Set `HEAD_SHA` from `pr.json` and `BASE_SHA` to
`git merge-base origin/<base> <HEAD_SHA>`. Then go to Stage 3.

1. `gh pr view <number> --json title,body,baseRefName,headRefOid` gives the
   description and the head commit. Fetch the commits so they can be
   reviewed locally — `git fetch origin pull/<number>/head <base>` — then set
   `HEAD_SHA` to the head commit and `BASE_SHA` to
   `git merge-base origin/<base> <HEAD_SHA>`.
2. Find the intent issue it links to: look for the references in
   `docs/agents/issue-tracker.md`'s Linking section in the title and body —
   on GitHub, `Closes #<number>` or `Relates to #<number>` — and read the
   issue with the Reading method. With no linked issue or no tracker config,
   skip the intent pass for that pull request and say so in its review.
3. Read the comments already on it —
   `gh api --paginate repos/<owner>/<repo>/pulls/<number>/comments` — so a
   finding already raised isn't posted twice.

## Stage 3 — Review

**Intent pass (you).** Compare the diff with the issue's Proposed outcome and
Constraints. Report what the issue asks for that the pull request doesn't do,
what the pull request does that the issue doesn't ask for, and every
Constraint the diff breaks.

**Code pass (a reviewer).** Use Superpowers' `requesting-code-review`:
dispatch its code reviewer with the pull request's title and description as
the description, the intent issue — or the pull request's body, when there is
none — as the requirements, and `BASE_SHA` and `HEAD_SHA`. Dispatch it on the
first model of these that your platform's dispatch accepts: the one your
dispatch named, as `implement-issues` does; else, from
`docs/agents/delivery.md` when it exists, the `pr-code-reviewer` Seats row,
then the `PR code reviewer` Agents row, then the Preset's PR code reviewer
tier — a preset sets the PR code reviewer to `standard` for budget and `strong` for balanced and max — a tier looked up in its Tiers table for this platform; else the most
capable model your platform offers. When the file names a model that doesn't
resolve, use the most capable model and say so in the report; never stop
over it. Reviews change nothing, so dispatch the reviewers for several pull
requests at the same time. Without subagent support, review each diff
yourself.

**Intent-only.** When you were dispatched with the code pass off —
`implement-issues` does this below high effort, because the build already
ended with a whole-branch code review — skip the code pass. Say in the
review body that it was skipped, and why.

**Check every finding before it is posted.** Open the code each finding
points at and confirm it holds. A reviewer can be wrong, and a wrong comment
on someone's pull request costs them more than a missing one. Drop what
doesn't hold up, and note why for the report.

## Stage 4 — Comment with suggested changes

In report-only mode, build the review below but don't post it: return it as
the fenced `json` block that Report-only mode describes.

Post one review per pull request, as `event: "COMMENT"`.

- Anchor each finding to the changed lines it is about: `path`, `line`, and
  `side: "RIGHT"`, plus `start_line` and `start_side` when it spans several
  lines. GitHub accepts only lines that appear in the pull request's diff.
- Open each comment with its severity — Critical, Important, or Minor — and
  one sentence on the consequence.
- When the fix is concrete, end the comment with a suggestion block holding
  the complete new text of exactly the anchored lines, in the file's own
  indentation:

  ````markdown
  **Important** — an invalid address reaches the queue and fails later in
  the worker, where the user never sees the error.

  ```suggestion
  if (!isValidEmail(email)) throw new ValidationError("email");
  await queue.add("confirm", { email });
  ```
  ````

- When the fix needs a design discussion, or touches lines outside the diff,
  explain it without a suggestion block, or put it in the review body.

```bash
gh api --method POST repos/<owner>/<repo>/pulls/<number>/reviews --input review.json
```

```json
{
  "commit_id": "<HEAD_SHA>",
  "event": "COMMENT",
  "body": "<counts by severity, and the intent pass's result>",
  "comments": [
    {
      "path": "src/signup.ts",
      "start_line": 41,
      "start_side": "RIGHT",
      "line": 42,
      "side": "RIGHT",
      "body": "<severity and consequence, then the suggestion block>"
    }
  ]
}
```

With no findings, post one review whose body says so, with no inline
comments.

## Stage 5 — Report

In report-only mode, the report is the dropped findings after the `json`
block, and one line naming the model the code pass ran on — or that it ran
inline, or was off.

One table: pull request, linked issue, findings posted by severity, and the
review's URL. Then list the findings dropped in the check step, and why.

## What NOT to do

- Don't call gh, write a file, or post anything in report-only mode — the
  caller posts.
- Don't approve or request changes — post reviews as `COMMENT` only;
  approval is the user's.
- Don't push commits to a pull request's branch; suggestions are the
  author's to apply.
- Don't post a finding you haven't checked against the code.
- Don't write a suggestion that replaces more or fewer lines than its comment
  is anchored to, or that isn't the complete new text of those lines.
- Don't anchor a comment to a line outside the pull request's diff.
- Don't post a finding that is already on the pull request.
- Don't skip the code pass unless you were dispatched with it off, and then
  say so in the review body.
- Don't skip the intent pass silently — when there is no linked issue, say so
  in the review body.

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

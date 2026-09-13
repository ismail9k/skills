# answer-pr-reviews — design

## Problem

`review-prs` leaves findings on pull requests as inline comments and review
bodies. Superpowers' `receiving-code-review` knows how to answer feedback —
check it against the code, fix what holds, push back on what doesn't — but it
takes no pull request and fetches nothing. Using it on a pull request today
means spelling out in the prompt, every time: check out the branch, fetch the
unresolved threads and the review-body findings, push before replying, reply
in each thread. `implement-issues` Stage 7 restates the same in a paragraph.

## Outcome

`answer-pr-reviews`: a thin proxy that points `receiving-code-review` at pull
requests — specific ones ("answer the reviews on #12 and #15") or all of the
user's own ("answer my PR reviews"). It supplies what the proxied skill lacks —
which pull requests, a checkout, the feedback, and push-then-reply — and leaves
every judgment about the feedback to `receiving-code-review`.
`implement-issues` Stage 7 dispatches it.

## Decisions

- **A proxy, not a restatement.** Whether an item holds, when to push back,
  when to ask, and the order of fixes are `receiving-code-review`'s rules.
  This skill invokes it and never restates them.
- **Pull requests:** the ones named, or all open pull requests authored by the
  current `gh` account that have unanswered feedback. Someone else's pull
  request only when named — pushing to another author's branch is never the
  default.
- **Feedback:** every unresolved inline review thread, plus findings written
  in a review's body. Top-level conversation comments are out of scope.
- **Standalone and dispatched.** Standalone, the user confirms the list once —
  the go-ahead to push and reply — and `receiving-code-review`'s questions go
  to the user. Dispatched with the go-ahead already given, as
  `implement-issues` does, it prints the list and continues, and where the
  proxied skill says to ask, it decides and gives the reason in its reply.
- **Threads stay open.** Every thread gets a reply; none is resolved.

Rejected: a self-contained skill that restates `receiving-code-review` (drifts
from it; breaks the repo's reuse rule), and an answer mode inside `review-prs`
(`review-prs` must never push to a pull request's branch).

## The skill

Written in actions, not one platform's tool names, like `review-prs`.

### Requirements

Superpowers (`receiving-code-review`, `verification-before-completion`), a
GitHub repository, and `gh` with `gh auth status` passing. If one is missing,
name it and stop.

### Stage 1 — Pick the pull requests

1. Repository: the one named, else this checkout's
   (`gh repo view --json nameWithOwner`). Say which.
2. Pull requests: the ones named; for "all" or "my PRs",
   `gh pr list --repo <owner/repo> --state open --author @me --limit 1000 --json number,title,url`,
   keeping those with unanswered feedback by Stage 2's test.
3. Print the list with each pull request's count of unanswered items, and say
   fixes will be pushed and replies posted. The user's confirmation is the
   go-ahead — unless dispatched with it already given; then print and
   continue.

### Stage 2 — Gather each pull request's feedback

Handle the pull requests one at a time.

1. **Checkout.** When dispatched with a worktree, work there. Otherwise use
   the current checkout if it is on the head branch and clean; else fetch the
   head branch and create `.worktrees/pr-<number>` on it, keeping
   `.worktrees/` out of commits. Never switch a checkout with uncommitted
   changes.
2. **Threads.** `gh api graphql` on `reviewThreads` — `isResolved`,
   `isOutdated`, `path`, `line`, and each comment's `databaseId`, `author`,
   `body` — keeping the unresolved ones. Outdated threads still count.
3. **Review bodies.** Findings written in a review's body. Summary counts and
   "no findings" are not items.
4. **Already answered.** Every reply this skill posts ends with
   `<!-- answer-pr-reviews -->`. A thread whose last comment carries it is
   answered; so is a review whose URL a marked PR comment links. The marker,
   not the author, because in `implement-issues` one `gh` account posts both
   the review and the replies.
5. **Constraints.** When `docs/agents/issue-tracker.md` exists and the pull
   request links an intent issue by its Linking section, read the issue's
   Constraints with the Reading method.

### Stage 3 — Answer with receiving-code-review

Invoke `receiving-code-review` in the checkout, with the gathered items as the
feedback and the intent issue's Constraints as the user's prior decisions. It
decides what holds, fixes it, and forms the pushback for the rest. Record, per
item, whether it was fixed (and in which commit), pushed back, or couldn't be
fixed — the replies need it.

### Stage 4 — Push, then reply

1. Run the project's test, lint, and typecheck commands with
   `verification-before-completion`. Failing: don't push; report it.
2. Push the branch — never force. A rejected push: stop for that pull request
   and reply to nothing as fixed.
3. Once the push lands, reply to every item:
   - Inline thread — in the thread:
     `gh api --method POST repos/<owner>/<repo>/pulls/<number>/comments/<databaseId>/replies -f body=...`,
     with `Fixed in <sha> — <what changed>.`, the pushback reason, or why it
     couldn't be fixed.
   - Review-body findings — one PR comment linking the review and answering
     each finding in order.
   - Every reply ends with `<!-- answer-pr-reviews -->`.
4. Resolve no thread and dismiss no review; never approve, merge, or mark the
   pull request ready.

### Stage 5 — Report

One table: pull request, items answered, fixed / pushed back / couldn't fix,
checks result, and the pushed head. Then every pull request dropped in Stage 1
and why.

### What NOT to do

- Don't restate `receiving-code-review`'s rules — invoke it.
- Don't reply "Fixed" before the fix is pushed.
- Don't push when the checks fail.
- Don't force-push, push the base branch, merge, approve, mark ready, resolve
  a thread, or dismiss a review.
- Don't answer an inline comment with a top-level PR comment.
- Don't touch another author's pull request unless it was named.
- Don't switch a checkout that has uncommitted changes.

## Wiring into implement-issues

- **Requirements:** replace `receiving-code-review` with the
  `answer-pr-reviews` skill.
- **Intro:** the building agent answers the review with `answer-pr-reviews`.
- **Stage 7, step 1:** message the agent that built the issue — or dispatch a
  new one into the same worktree — to run `answer-pr-reviews #<number>` on
  `<owner/repo>` in that worktree, telling it the user's go-ahead for this run
  covers pushing the fixes and replying. The decide-instead-of-ask and
  Constraints text moves into `answer-pr-reviews`' dispatched mode.
- **Stage 7, steps 2–3 and Stage 8:** unchanged; the fixed counts come from
  `answer-pr-reviews`' report.
- **`assets/issue-brief.md`, step 4:** "you may then be asked to answer that
  review with `answer-pr-reviews`."

## Repo changes

- `skills/answer-pr-reviews/SKILL.md` (no assets).
- `.claude-plugin/plugin.json`: add `./skills/answer-pr-reviews`.
- `AGENTS.md`: nine skills; Delivery row
  `implement-issues` → `review-prs` → `answer-pr-reviews`; layout tree; "What
  this repo is"; the write-in-actions rule and the never-lists cover
  `answer-pr-reviews`; the review-round bullet names it.
- `README.md`: an `answer-pr-reviews` section, the `implement-issues`
  paragraph, the pipeline diagram, the Requirements row, the `gh` note, the
  `implement-issues` install lines, and a usage example. It dispatches
  nothing, so the subagent note doesn't gain it.

## Testing

`bash scripts/check.sh` covers the new directory's name, manifest entry, and
path coupling. End to end: install it and run it on a pull request carrying
`review-prs` comments, once named and once as "my PRs".

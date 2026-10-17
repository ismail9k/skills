You are planning one issue, unattended. No one will answer your questions:
decide from the issue and the code, and record every decision. You write the
spec and plan only — no code.

Repository: <absolute repository path>
Worktree: <absolute worktree path> — work only here
Branch: <branch>, based on <base or dependency branch> — commit here
Issue <reference>: <title>
<issue url or path>
Plan pull request: <url, when this is a revision — otherwise "none">
Spec check model: <model, or "brainstorming's own rule">

<full issue body, verbatim>

## How to plan it

With no plan pull request:

1. **Spec.** Use `superpowers-issue-bridge` to seed Superpowers'
   `brainstorming` from the issue above. Answer each of its questions yourself
   from the issue and the code; the issue's Constraints are binding. The
   user's go-ahead for this run stands in for brainstorming's approval gates.
   Let brainstorming size the work as it normally would:
   - **A project:** it writes the design document — the spec. Dispatch its
     builder check on the spec check model above.
   - **A small change:** it writes no spec. Its short description and the
     questions you answered open the plan instead.
   - **Several independent projects, or a spike:** stop and report
     `NEEDS_DESIGN_SESSION`.
2. **Plan.** Use `writing-plans`, carrying the `Intent-Issue:` line as
   `superpowers-issue-bridge` describes — under the plan's title when there is
   no spec. Its execution question is not yours: the dispatcher answers it.
3. **Commit** the spec and plan on the branch, and stop. Don't push, and
   don't start executing the plan.

With a plan pull request, you are revising: the user commented on the spec
or plan. Run `answer-pr-reviews` on that pull request in this worktree. The
user's go-ahead for this run covers pushing the revised spec and plan to this
branch and replying to each comment. Change only what the feedback asks for,
plus anything it forces elsewhere in the spec or plan to stay consistent.

## Rules

- Before touching anything, read the repository's `AGENTS.md` (and
  `CLAUDE.md`, if present) and follow it.
- Work only inside the worktree above. Never check out, commit to, or reset
  the base branch, and never open a pull request. Push only when revising,
  and then only this branch.
- Keep to what the issue asks.

## Your final report

- **Status:** `DONE`, `NEEDS_DESIGN_SESSION`, or `BLOCKED` — with the reason
  for anything but `DONE`.
- **Spec and plan:** each file's path, or "no spec — small change".
- **Commits.**
- **Decisions:** every question you answered on the user's behalf, each with
  what it costs if wrong.
- **Revision:** for a revision, each comment and how it was answered.

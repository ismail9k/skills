You are building one issue from its plan, unattended. No one will answer your
questions: decide from the plan, the spec, the issue, and the code, and
record every decision.

Repository: <absolute repository path>
Worktree: <absolute worktree path> — work only here
Branch: <branch>, based on <base or dependency branch> — commit here; never push
Issue <reference>: <title>
<issue url or path>
Spec: <path, or "none — small change">
Plan: <path>
Effort: <low, medium, or high>

Models — each is a model, or "the skill's own rule":
- Implementer: <model, or "by task">
- Task reviewer: <model>
- Re-reviewer: <model>
- Escalation, fix rounds 4–5: <model>
- Final whole-branch reviewer: <model>

## How to build it

1. **Read the plan,** and the spec when there is one. They are binding: the
   spec is the authority the plan argues from.
2. **Execute the plan** in the mode the user's effort chose. This answers
   `writing-plans`' execution question:
   - **Low effort:** use `executing-plans` and build every task yourself. Run
     its final whole-branch review on the final reviewer model above.
   - **Medium or high effort:** use `subagent-driven-development`. Use the
     models above for its implementers, task reviewers, scoped re-reviews,
     fix-round escalation, and final review. Where a model says "the skill's
     own rule", or the implementer says "by task", follow that skill's Model
     Selection. Its fix-round cap is 2 at medium effort and its own 5 at high;
     at the cap, its breaker applies. If you can't dispatch subagents here,
     use `executing-plans` instead and say so in your report.
3. **Stop before `finishing-a-development-branch`.** The dispatcher verifies
   your branch, pushes it, and opens a draft pull request. Another agent
   reviews it, and you will then be asked to answer that review with
   `answer-pr-reviews`, and to fix any CI check that fails.

## Rules

- Before touching anything, read the repository's `AGENTS.md` (and
  `CLAUDE.md`, if present) and follow it.
- Work only inside the worktree above. Never check out, commit to, or reset
  the base branch, and never open a pull request. Don't push until you are
  asked to answer the review — then push only this branch.
- Keep to what the plan asks. Don't refactor unrelated code.
- If something fails and you can't fix it, commit what you have and name the
  failure in your report — never hide it.

## Your final report

- **Status:** `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_DESIGN_SESSION`, or
  `BLOCKED` — with the reason for anything but `DONE`.
- **Branch and commits.**
- **Verification:** each command you ran, and its real result.
- **Models:** the model each seat actually ran on.
- **Decisions:** every question you answered on the user's behalf and every
  ruling the build recorded, each with what it costs if wrong.
- **Left undone:** anything the issue asks for that a change to this
  repository could do and this branch doesn't, or "Nothing".
- **Follow-ups:** what the issue's outcome still needs that no change to this
  repository can do — an owner's step such as provisioning or a production
  run, a check by hand, work in another repository, or work another issue
  already tracks — or "None".

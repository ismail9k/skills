## Agent configuration

Skill-managed settings live under `docs/agents/` as small, focused files rather
than inline here, so each can be read by only the skill that needs it:

- `docs/agents/issue-tracker.md` — where issues and intents live for this repo,
  and how to reach them (written by the `configure-issue-tracker` skill)

As more skills are adopted, each may add its own file under `docs/agents/`.
List those files here so this section remains a table of contents rather than
accumulating their configuration inline.

## Workflow

1. Capture the intent using `brainstorm-to-issue`, which reads the configured
   issue tracker.
2. If Superpowers is installed, hand the intent to its `brainstorming` skill,
   seeded through `superpowers-issue-bridge`, to produce `spec.md`; then use
   `writing-plans` for `plan.md`.
3. Build, test, and review using the repository's development workflow.
4. Open the pull request with the issue relationship selected through
   `superpowers-issue-bridge`.

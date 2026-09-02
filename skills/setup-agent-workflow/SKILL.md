---
name: setup-agent-workflow
description: >
  Scaffold a repo for agent-driven workflows: creates AGENTS.md and CLAUDE.md
  with the import-pointer pattern, and records where issues/intents live
  (GitHub, local markdown, or other) in docs/agents/issue-tracker.md. Run
  once per repo, before first use of skills like brainstorm-to-issue that
  depend on this config. Re-running is safe — it only fills in what's
  missing and never silently overwrites existing content.
---

# Setup Agent Workflow

## When this applies

Run this once, the first time agent-driven skills (brainstorm-to-issue,
future spec/plan/triage skills) are used in a repo. Also re-run it if the
user wants to change where issues live for this repo.

## Principle

This is a prompt-driven setup, not a deterministic script: explore what
already exists, present it, confirm choices with the user, then write.
Never overwrite a file that already has real content without showing the
user what's there and getting explicit confirmation.

## Steps

### 1. Explore the current repo state

Check, without assuming:

- Does `AGENTS.md` exist at the repo root? Does `CLAUDE.md`?
- If either exists, read it. Does it already contain the import-pointer
  pattern, or does it hold real project-specific content someone wrote by
  hand?
- Does `docs/agents/` exist? Does `docs/agents/issue-tracker.md` exist
  already?
- `git remote -v` — is this repo backed by GitHub? Which `owner/repo`?

Summarize what you found for the user in a couple of sentences before
changing anything.

### 2. AGENTS.md / CLAUDE.md

**If neither file exists:** create both from the asset templates below,
then tell the user what you created.

**If `AGENTS.md` exists with real content:** do not overwrite it. Show the
user the existing content and ask whether to add the "Agent configuration"
section (if missing) or leave it untouched.

**If `CLAUDE.md` exists but isn't the import pointer:** flag this
explicitly — it likely means something (possibly `/init`) generated a full
`CLAUDE.md` that's now diverging from `AGENTS.md`. Ask the user whether to
replace it with the import pointer (moving any real content into
`AGENTS.md` first) or leave it as-is. Never silently replace it.

**If both already have the correct pattern:** skip this step, note that
it's already set up.

#### Templates

Both file bodies ship with this skill as assets, so they are copied rather
than retyped:

- `assets/CLAUDE.md` → the target repo's `CLAUDE.md`
- `assets/AGENTS.md` → the target repo's `AGENTS.md`

Read each asset and write it to the target path verbatim. `assets/AGENTS.md`
arrives with an empty "Project knowledge" section (Commands / Conventions /
Architecture / Things agents get wrong) — leave it empty for the user to fill
in as the project develops; don't invent build or test commands to populate
it.

If a file already exists and the user agreed to add only the missing
"Agent configuration" section, take that section from `assets/AGENTS.md`
rather than rewriting the whole file.

### 3. Issue tracker choice

Ask the user, in one question, where issues/intents/specs should live for
this repo:

- **GitHub** — the default if a GitHub remote was found. Confirm the
  `owner/repo` inferred from `git remote -v` rather than asking blind.
- **Local markdown** — files under `.scratch/<feature>/` in this repo.
  Good for solo projects or repos with no remote.
- **Other** (Jira, Linear, etc.) — ask the user to describe the workflow
  in one paragraph and record it as freeform prose. Don't try to script
  an integration for it here.

Write the choice to `docs/agents/issue-tracker.md` using this shape:

```markdown
# Issue tracker

<!-- Read by: brainstorm-to-issue, and any future spec/plan/triage skills -->

## Backend
GitHub

## Location
<owner>/<repo>

## Labels
- intent — applied to issues created by brainstorm-to-issue

## Notes
<anything freeform the user added, e.g. a Jira/Linear description>
```

(Swap the Backend/Location block for the local-markdown or freeform
description as appropriate.)

### 4. Confirm and summarize

Report back concisely: what was created, what was left untouched, and
where the issue-tracker config now lives. Do not proceed to run any other
skill (e.g. brainstorm-to-issue) as part of this setup — this skill's job
ends here.

## What NOT to do

- Don't overwrite an existing `AGENTS.md` or `CLAUDE.md` that has real
  content without showing it to the user first.
- Don't guess the GitHub repo — confirm what `git remote -v` found, or ask
  if there's no remote.
- Don't retype or paraphrase the templates from memory — read `assets/AGENTS.md`
  and `assets/CLAUDE.md` and copy them verbatim.
- Don't invent labels or tracker choices the user didn't state.
- Don't fold other skills' setup (triage labels, domain docs) into this
  one preemptively — add sections to `docs/agents/` only as those skills
  are actually adopted.

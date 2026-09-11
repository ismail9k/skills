---
name: brainstorm-to-issue
description: >
  Use when a problem or idea has been talked through — in Superpowers'
  brainstorming or any other conversation — and the user wants it tracked as
  an intent issue instead of built now: "file this", "open an issue for
  this", "track it first", or picking track-first when
  superpowers-issue-bridge asks. Not while the problem is still being
  explored.
---

# Brainstorm → Intent Issue

## Relationship to Superpowers

If Superpowers is installed, its `brainstorming` skill is usually the
conversation this skill captures. For work with no intent issue yet,
brainstorming can end two ways: build now (its usual design, plan, and code)
or track first. This skill is the track-first ending —
`superpowers-issue-bridge` offers that choice once the problem is
understood, before brainstorming proposes approaches.

The issue records **intent**, not a spec: the problem, the outcome, and the
decisions the user has already made. Leave out approaches that were only
considered, edge-case analysis, and design detail nobody decided. Whoever
builds the issue later designs it then, with `superpowers-issue-bridge`
seeding brainstorming from this issue.

## When this applies

The user has talked a problem, need, or idea through — in Superpowers'
brainstorming, or conversationally with any AI agent (this isn't specific to
a coding session) — and now wants it tracked rather than built right away.
Run this once they signal that ("file this," "let's turn this into an
issue," or picking track-first), not while the problem is still being
explored.

## Preconditions

1. Check for `docs/agents/issue-tracker.md`. If it doesn't exist, tell the
   user to run the `setup-issue-tracker` skill first, and stop — don't
   guess a tracker or repo.
2. Read the tracker config from that file:
   - **GitHub backend:** use the `owner/repo` it records. Confirm `gh`
     is authenticated (`gh auth status`); if not, tell the user to run
     `gh auth login` and stop.
   - **Local markdown backend:** write to `.scratch/<feature>/` instead of
     creating a GitHub issue — skip all `gh` steps below and use a
     slugified title as the filename.
   - **Other/freeform backend:** follow whatever the recorded notes
     describe; ask the user if the notes don't cover this case.
   - If the user explicitly names a different repo/tracker for this one
     run, use that instead of the config — a one-off override doesn't
     require re-running setup.

## Steps

1. Re-read the brainstorming conversation and extract, in the user's own
   words wherever possible:
   - **Title** — a short name for the problem/feature (this becomes the
     issue title, not a `#` heading inside the body).
   - **Problem** — what's wrong today, for whom, and why it matters.
   - **Proposed outcome** — what "better" looks like, stated as an outcome
     not an implementation.
   - **Affected users and systems** — who and what this touches.
   - **Constraints** — hard limits already mentioned (compliance, security,
     scope boundaries, deadlines), and every decision the user explicitly
     made, stated as a requirement ("reuse the existing job queue").
     Whoever builds the issue treats this section as binding — including an
     agent that can't ask — so record what the user decided, never an
     option the conversation only considered.
   - **Open questions** — anything genuinely unresolved. Leave real
     uncertainty in rather than inventing a confident answer.
2. If any section has no real content from the conversation, write
   "None identified" rather than fabricating detail — do not pad sections
   to look complete.
3. Read `assets/intent-issue.md` and fill it in exactly — same headings,
   same order. The title is used twice — once as the issue's own title in
   the tracker, and once as the H1 at the top of the body, so the content
   still reads correctly if exported, printed, or viewed outside the
   tracker.
4. Show the drafted title and body to the user and ask for confirmation
   or edits before creating anything. Do not create the issue silently.
5. Once confirmed, create it in the configured backend. On GitHub:

   ```bash
   gh issue create \
     --repo <owner>/<repo> \
     --title "<title>" \
     --body-file <tmp-file> \
     --label <label from docs/agents/issue-tracker.md, default: intent>
   ```

   (Create the label first with `gh label create <label>` if it doesn't
   exist yet — don't fail silently if the label is missing.)

6. Report the issue's URL (or file path) back to the user. This intent issue
   is the entry point for the work: whoever builds it later — the user or an
   agent — starts from it, and `superpowers-issue-bridge` seeds
   brainstorming from it and links the finished work back to it.
7. If this ran as the track-first ending of Superpowers' brainstorming, the
   session ends here. Continue into a spec, plan, or code only if the user
   now asks to build it.

## What NOT to do

- Don't run this mid-brainstorm — wait for explicit confirmation the
  discussion is done.
- Don't invent content for empty sections.
- Don't record an option the conversation only considered as a Constraint —
  only what the user decided.
- Don't create the issue without showing the draft first.
- Don't guess the target repo if it can't be inferred.
- Don't carry on into a spec, `writing-plans`, or code after filing the
  issue.

---

## Non-Claude-Code version (plain prompt)

For tools without a skills/auto-discovery mechanism, paste this as a
one-off prompt once brainstorming is done:

> Based on our conversation above, draft an issue using exactly this
> template — an H1 with the title, then Problem, Proposed outcome,
> Affected users and systems, Constraints, Open questions — each section a
> few sentences, using "None identified" for anything we didn't actually
> discuss. Under Constraints, include hard limits and every decision we
> explicitly made, stated as a requirement; leave out options we only
> considered. Give me the title and body as plain text; don't create
> anything yet, just show me the draft.

Then create it yourself — on GitHub, with:

```bash
gh issue create --repo <owner>/<repo> --title "<title>" --body-file draft.md --label intent
```

# Structural decay — the koshary lens

Read this before Pass 1 sections 1–5 — the core of the audit. It exists
because "find duplicated code" and "find long functions" are the two
easiest ways to produce a useless report: token-similarity finds
coincidences, and line-count finds functions that are long for good
reasons.

The question underneath all of it is not *is this ugly* but **what does the
next person changing this have to hold in their head, and how many places
do they have to change at once?**

## Layer collapse

The koshary symptom proper: things that belong in separate layers stirred
into one. Look for a single file or function that does more than one of —

- **transport** (parsing the request, reading params, setting status codes)
- **business rules** (what is allowed, what gets computed)
- **persistence** (queries, writes, cache)
- **presentation** (rendering, formatting for display)

Concrete tells:

- SQL queries or ORM calls inside a React component, a controller, or a
  route handler.
- `req` / `res` (or the framework's request object) reaching into a
  function that is supposed to be a pure business rule — it can no longer
  be called from a job, a CLI, or a test without faking HTTP.
- Business rules living in the UI, so the API accepts what the UI forbids.
- A "utils" or "helpers" module that everything imports and that imports
  everything back.

Report these by consequence, not by principle: *"the price rule lives in
the checkout component, so the mobile client and the admin panel each
reimplement it"* lands; *"this violates separation of concerns"* does not.

## Duplication that costs money

Apply one test: **if the underlying rule changed, how many places would
have to change together, and would someone miss one?**

Worth reporting:

- The same validation rule (an email regex, a password policy, a max
  length) enforced independently in the form, the API handler, and the
  model. Three places, one rule, no shared source — the rule *will* drift,
  and the bug appears as "it saved through the API but the UI rejects it."
- The same business calculation — tax, discount, pagination offset,
  permission check — implemented more than once. Two answers to one
  question is a defect that has not happened yet.
- The same API call rebuilt at each call site, each with slightly different
  error handling and headers. Adding auth or a retry means finding all of
  them.
- The same data transform (date formatting, currency, casing a payload)
  inlined repeatedly, with variations nobody intended.

Not worth reporting:

- Two functions that both map over a list. Same shape, unrelated reasons to
  change.
- Boilerplate the framework requires — route registrations, DI wiring,
  migration scaffolding, test setup. Deduplicating it usually makes it
  worse.
- Tests that repeat their arrange step. Explicit, readable tests beat DRY
  tests; a shared fixture that hides what a test depends on is a downgrade.
- Two things that look alike today but answer to different owners — a
  public-signup validator and an admin-import validator will diverge on
  purpose.

The distinction is **coincidental** versus **coupled** duplication. Merging
coincidental duplication is how you create the next koshary: now two
unrelated callers share a function that has to grow a flag every time
either one changes.

Quantify what you report: *"this regex appears in 4 files; changing the
rule means editing all 4"* is actionable in a way *"there is duplication in
the validators"* is not.

## Files and functions that stopped being read

Length is a symptom, not the finding. A 300-line function that is one flat
switch statement is fine. A 120-line function holding four levels of
nesting, two responsibilities, and an early-return path someone will miss
is not.

What to actually look for:

- **More than one reason to change.** The reliable test. If a function
  changes when the pricing rules change *and* when the email template
  changes, it is two functions.
- **Nesting past three levels**, especially with conditions in the middle
  of a long body — that is where the missed branch lives.
- **Boolean parameters** that switch behavior. `send(user, true, false)`
  has two functions inside it.
- **A comment explaining what a block does** — usually marking the
  boundary of a function that wants to exist.
- **The file nobody opens.** If the repo's own docs or commit messages say
  "careful with this file," that is the finding, stated by the team.

Cheap way to find the candidates, then read them before judging:

```bash
git ls-files | grep -vE '(lock|min\.|\.map$|/vendor/|/dist/|/build/)' \
  | xargs wc -l 2>/dev/null | sort -rn | head -20
```

Pair it with churn — a big file that changes constantly is where the pain
actually is, and a big file nobody has touched in two years usually is not
worth the risk:

```bash
git log --format= --name-only --since='12 months ago' \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -20
```

Report the intersection of "large" and "changes often" first.

## Dead code

Report only what you verified is unreachable — not what merely looks
unused. Check for dynamic access before deleting anything:

- string-keyed lookups (`handlers[name]`, `getattr(obj, name)`)
- reflection, DI containers, decorators and framework auto-registration
- entries in config, routes, or manifests
- anything exported from a package's public surface — for a library, an
  unused export is the API

Unused *imports* and *local variables* are safe and worth listing. Unused
*exports* need a whole-repo check, and unused *public API* is not dead code
at all.

## Extracting a reusable piece — only when it pays

Extract when the callers genuinely share a reason to change and the shared
thing has one clear job. Do not extract to reduce the line count.

Signs the extraction will make things worse:

- It needs a flag or mode parameter to serve its second caller.
- Callers must now understand the abstraction to understand their own code.
- It joins two features that would otherwise be free to diverge.

If you are unsure, leave the duplication and say so in the report. Duplicate
code is visible and cheap to fix later; a wrong abstraction is invisible and
expensive — and it is exactly how a clean stack becomes koshary in the
first place.

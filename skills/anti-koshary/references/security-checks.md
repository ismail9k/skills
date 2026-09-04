# Security checks

Read this before Pass 1 section 7. It exists because a naive secret scan
produces a page of false positives and buries the one real key, and because
the injection and auth checks that matter differ by stack.

## Contents

- [Secrets](#secrets) — patterns, and the false positives that ruin a scan
- [Git history](#git-history)
- [Injection](#injection)
- [Auth](#auth)
- [Data exposure](#data-exposure)
- [Unsafe execution and CORS](#unsafe-execution-and-cors)

## Secrets

Run these over tracked files only — `node_modules`, `vendor`, `.venv`, and
build output will drown you:

```bash
# high-signal provider key shapes
git grep -nIE '(sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

# assignments that look like credentials (-i: catches apiKey, API_KEY, ApiSecret)
git grep -nIEi '(api[_-]?key|secret|passwd|password|token|credential|private[_-]?key)["'"'"']?[[:space:]]*[:=][^"'"'"';,)]{0,20}["'"'"'][^"'"'"']{8,}'

# connection strings with inline credentials
git grep -nIEi '(postgres|postgresql|mysql|mongodb(\+srv)?|redis|amqp)://[^:@/]+:[^@]+@'

# committed env files
git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vE '\.(example|sample|template)$'
```

**Before reporting any hit, rule out these — they are most of what you'll
find, and reporting them costs you the user's trust in the whole report:**

| Looks like a secret | Usually isn't |
| --- | --- |
| `.env.example`, `.env.sample`, `config.template` | Placeholders by design — but check the values really are placeholders |
| Test fixtures, `__mocks__`, seed data | `password = "hunter2"` in a test is fine |
| Documentation and READMEs | Provider docs get copy-pasted with example keys |
| `PUBLIC_`, `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_` prefixes | Compiled into the bundle on purpose. Publishable keys (`pk_live_`, Firebase web config) belong here. Do flag a *secret* key wearing a public prefix — that is a real finding |
| Long base64 or hex blobs | Often hashes, checksums, or inlined assets |
| `os.environ[...]`, `process.env.X` | Reading a secret is correct; the finding would be a literal fallback beside it |

The finding that always survives: a real credential whose blast radius you
can name. Report the file and line, say what it grants access to, and tell
the user to **rotate it** — removing it from the code does not un-leak it.
Do not paste the value back into your report.

## Git history

A secret deleted from the working tree is still live if it is in history:

```bash
git log --all --oneline -S'<distinctive fragment>' -- . | head
```

Worth running for each confirmed secret. If one is in history, say so
explicitly — the remediation is rotation plus (optionally) history rewrite,
and the user needs to know rewriting alone is not enough.

## Injection

Trace user input to an interpreter. The pattern is always the same — a
value the caller controls reaches something that parses it — so search for
the sinks and walk backwards to see whether anything sanitizes on the way.

```bash
# SQL built by concatenation or formatting
git grep -nIE '(SELECT|INSERT|UPDATE|DELETE|WHERE).*(\+[[:space:]]*(req|request|params|query|body|input|user)|\$\{|%[[:space:]]*\(|\.format\()'

# SQL inside an interpolated literal — Python f-strings, JS template literals.
# The prefix comes before the keyword, so the pattern above cannot see these.
git grep -nIE '(f|rf|fr)?["'"'"'`][^"'"'"'`]*(SELECT|INSERT|UPDATE|DELETE)[^"'"'"'`]*(\$)?\{'

# shell execution — anchored to a call, or a bare backtick will match every
# JS template literal in the repo and bury the real hits
git grep -nIE '(^|[^[:alnum:]_])(exec|execSync|execFile|execFileSync|spawn|spawnSync|system|popen|shell_exec|passthru|proc_open)[[:space:]]*\(|(os\.system|subprocess\.(run|call|check_output|Popen))[[:space:]]*\('

# XSS sinks
git grep -nIE '(innerHTML|outerHTML|dangerouslySetInnerHTML|v-html|document\.write|insertAdjacentHTML)'
```

What separates a finding from a hit:

- **SQL** — parameterized queries and ORM query builders are safe. Raw
  string building with a request value in it is not. `shell=True` in Python
  and template literals in `db.query()` are the classic tells.
- **Command** — an array-form `spawn("git", [arg])` is safe; a string-form
  `exec(\`git ${arg}\`)` is not.
- **XSS** — `innerHTML` with a literal or a sanitized value is fine.
  `dangerouslySetInnerHTML` with anything derived from user input, an API
  response, or a URL parameter is a finding. So is markdown rendered
  without sanitization.

## Auth

Static grep is weak here; enumerate instead. List every route, mutation, or
server action, and for each, name the check that protects it. The finding is
the row you cannot fill in.

Look specifically for:

- A route added later that sits outside the middleware or decorator that
  protects its neighbours — the most common real hole.
- **Authorization vs authentication**: the request is authenticated, but
  nothing verifies this user owns *this* record. `findById(req.params.id)`
  with no ownership clause is the canonical form.
- Client-side-only gating — a hidden button with an unprotected endpoint
  behind it.
- Admin flags, roles, or user ids read from the request body or a
  client-set cookie rather than from a verified session or token.
- Verification that decodes a JWT without checking its signature or
  expiry.

## Data exposure

```bash
git grep -nIE '(console\.(log|error|warn)|print|println|logger?\.(info|debug|error|warn))' | grep -iE 'password|token|secret|key|ssn|card|auth|credential'
git grep -nIE '(localStorage|sessionStorage)\.setItem' 
```

Flag: credentials, tokens, or personal data written to logs; auth tokens in
`localStorage` where any XSS can read them; secrets or ids in URL query
strings (they land in browser history, referrer headers, and server access
logs); full objects logged with a `password` field still on them; stack
traces or DB errors returned to the client in production.

## Unsafe execution and CORS

```bash
git grep -nIE '(^|[^[:alnum:]_.])(eval|new Function|pickle\.loads|yaml\.load|Marshal\.load|unserialize)[[:space:]]*\('
git grep -nIE '(Access-Control-Allow-Origin|cors\()'
```

- `eval` and `new Function` on anything derived from input — critical.
- `yaml.load` without `SafeLoader`, `pickle.loads` on untrusted bytes,
  PHP `unserialize` — deserialization RCE.
- `Access-Control-Allow-Origin: *` is only a finding when the endpoint is
  authenticated or returns non-public data; on a public read-only API it is
  correct. `origin: true` with `credentials: true` reflects any origin and
  is a real hole — say which one you found.

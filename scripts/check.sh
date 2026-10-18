#!/usr/bin/env bash
# check.sh — the repo's "test" step. The deliverables are Markdown, so what
# can break is consistency, not compilation:
#
#   1. every skill's frontmatter name matches its directory
#   2. .claude-plugin/marketplace.json puts every skill on disk in exactly one
#      plugin, and no plugin.json declares skills that would conflict with it
#   3. no skill references another by path (each is installed alone)
#   4. anti-koshary's grep patterns still match a file with a known hit
#   5. implement-issues' agents, presets and Codex path agree across its files
#
# (4) is the one that matters most: a broken regex looks exactly like a clean
# repo, so the patterns are run against a fixture with planted hits, plus
# negative cases for the false positives they are supposed to suppress.
#
# Usage: bash scripts/check.sh      Written for bash 3.2 (macOS default).

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAIL=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
head_() { printf '\n=== %s ===\n' "$1"; }

# ------------------------------------------------ 1. name matches directory
head_ "skill name == directory name"
for d in skills/*/; do
  b=$(basename "$d")
  n=$(sed -n 's/^name: *//p' "$d/SKILL.md" 2>/dev/null | head -1)
  if [ -z "$n" ]; then bad "$b — no name: in SKILL.md"
  elif [ "$n" != "$b" ]; then bad "$b — frontmatter says '$n'"
  else ok "$b"; fi
done

# ----------------------------------------------------- 2. manifest coverage
head_ "marketplace.json ships each skill on disk in exactly one plugin"
MANIFEST=.claude-plugin/marketplace.json
DECLARED=$(grep -o '"\./skills/[a-z0-9-]*"' "$MANIFEST" | sed 's|"\./skills/||; s|"$||' | sort)
ONDISK=$(ls -1 skills | sort)
for s in $(printf '%s\n' "$DECLARED" | uniq -d); do
  bad "declared by more than one plugin: $s"
done
for s in $DECLARED; do
  [ -d "skills/$s" ] || bad "declared but missing on disk: $s"
done
for s in $ONDISK; do
  printf '%s\n' "$DECLARED" | grep -qx "$s" || bad "on disk but in no plugin: $s"
done
# plugins share the repo root with "strict": false, so a plugin.json that
# declares skills conflicts with them and the plugins fail to load
if [ -f .claude-plugin/plugin.json ] && grep -q '"skills"' .claude-plugin/plugin.json; then
  bad "plugin.json declares skills — they belong in marketplace.json"
fi
[ "$FAIL" -eq 0 ] && ok "$(printf '%s\n' "$ONDISK" | grep -c .) skills, each in one plugin"

# ------------------------------------------------------- 3. no path coupling
head_ "no skill references another by path"
for d in skills/*/; do
  b=$(basename "$d")
  hits=$(grep -rn "skills/" "$d" 2>/dev/null | grep -v "skills/$b" | grep -v '^Binary')
  if [ -n "$hits" ]; then bad "$b references another skill by path:"; printf '%s\n' "$hits" | sed 's/^/          /'
  else ok "$b"; fi
done

# ------------------------------- 5. implement-issues settings stay consistent
head_ "implement-issues settings stay consistent"
II=skills/implement-issues
AGENTS_6="Planner|Build lead|Implementers|Task reviewers|Review agent|PR code reviewer"
has() { # file, fixed string
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$1 has: $2"; else bad "$1 is missing: $2"; fi
}
models=$(grep -rniE '(^|[^[:alnum:]])(opus|sonnet|haiku|fable|gpt-?[0-9])' \
  skills/implement-issues skills/review-prs README.md AGENTS.md docs/implement-issues-flow.md 2>/dev/null)
if [ -n "$models" ]; then bad "a model name in skill or doc text:"; printf '%s\n' "$models" | sed 's/^/          /'
else ok "no model names in implement-issues, review-prs or their docs"; fi
heads=$(sed -n 's/^## //p' "$II/assets/delivery.md" | tr '\n' '|')
if [ "$heads" = "Effort|Plan approval|Preset|Agents|Tiers|Seats|" ]; then ok "delivery.md sections in order"
else bad "delivery.md sections are '$heads'"; fi
IFS='|'; for a in $AGENTS_6; do
  grep -q "^| $a |" "$II/assets/delivery.md" && ok "delivery.md row: $a" || bad "delivery.md has no row: $a"
done; unset IFS
pt=$(awk '/^ *\| Agent \| budget \| balanced \| max \|$/{f=1;next} f&&/^ *\|/{print} f&&!/^ *\|/{exit}' "$II/SKILL.md" \
  | sed 's/^ *| \([^|]*\) |.*/\1/' | grep -v -- '---' | tr '\n' '|')
if [ "$pt|" = "$AGENTS_6||" ] || [ "$pt" = "$AGENTS_6|" ]; then ok "SKILL.md preset table has the six agents"
else bad "SKILL.md preset table rows are '$pt'"; fi

for s in "not used at this effort" "set each agent" '"builds" or "executes"' "the run starts only after the user confirms"; do has "$II/SKILL.md" "$s"; done
s9=$(awk '/^## Stage 9/{f=1;next} /^## /{f=0} f' "$II/SKILL.md")
case "$s9" in *provider*) ok "Stage 9 reports each provider" ;; *) bad "Stage 9 doesn't mention the provider" ;; esac

RP=skills/review-prs/SKILL.md
for s in "## Report-only mode" "Context:" "pr.json" "comments.json" "issue.md" "exactly one fenced" "don't call gh" "PR code reviewer" "Preset"; do has "$RP" "$s"; done

RB=$II/assets/review-brief.md
if [ -f "$RB" ]; then
  for s in "Report-only: yes" "Context:" "<owner/repo>" "<number>" "<worktree>" "<context dir>" "<code pass: on|off>" "<PR code reviewer model>"; do has "$RB" "$s"; done
else bad "$RB does not exist"; fi
for s in "codex exec" "-s read-only" "codex login status" "Codex is for reviews only" "doesn't accept stops the run" "exactly one fenced"; do has "$II/SKILL.md" "$s"; done
stray=$(awk '/^## /{st=$0} /codex exec/ && st !~ /^## Stage [27] /{print FILENAME": "st}' "$II/SKILL.md" | sort -u)
if [ -n "$stray" ]; then bad "codex exec outside Stages 2 and 7: $stray"; else ok "codex exec only in Stages 2 and 7"; fi

# ------------------------------- 4. anti-koshary patterns vs a known-hit fixture
head_ "anti-koshary security patterns match planted hits"
REF=skills/anti-koshary/references/security-checks.md
FIX=$(mktemp -d) || exit 1
trap 'rm -rf "$FIX"' EXIT

cat > "$FIX/app.js" <<'EOF'
const OPENAI = "sk-abcdefghijklmnop1234";
const apiKey = "supersecretvalue123";
const API_KEY: string = "anothersecret1234";
const db = "postgres://user:pass@host:5432/db";
db.query("SELECT * FROM users WHERE id = " + req.params.id);
exec(`git checkout ${branch}`);
el.innerHTML = userInput;
eval(payload);
console.log("user password", pw);
localStorage.setItem("token", t);
app.use(cors({ origin: true, credentials: true }));
EOF
cat > "$FIX/q.py" <<'EOF'
cur.execute(f"SELECT * FROM t WHERE id = {user_id}")
os.system("rm -rf " + path)
EOF
# negative cases — each of these was a real false positive at some point
cat > "$FIX/clean.js" <<'EOF'
const greet = `hello ${name}`;
const url = `${base}/api/v1/users`;
const opts = { token: someVar, name: "hello world here" };
cur.execute("SELECT * FROM t WHERE id = ?", [id]);
EOF
printf 'SECRET=real\n' > "$FIX/.env"
printf 'SECRET=placeholder\n' > "$FIX/.env.example"
( cd "$FIX" && git init -q . && git add -A ) || { bad "could not build fixture"; }

# every runnable pattern in the reference must find at least one planted hit
while IFS= read -r pat; do
  n=$( cd "$FIX" && eval "$pat" 2>/dev/null | grep -c . )
  label=$(printf '%s' "$pat" | cut -c1-58)
  if [ "${n:-0}" -ge 1 ]; then ok "$n hit(s): ${label}..."
  else bad "MATCHED NOTHING (a broken pattern looks like a clean repo): $pat"; fi
done <<EOF
$(grep -E '^git (grep|ls-files)' "$REF")
EOF

head_ "…and stay silent on the known false positives"
neg() { # description, pattern-selector, string that must NOT appear
  p=$(grep -E '^git (grep|ls-files)' "$REF" | grep -m1 -- "$2")
  [ -z "$p" ] && { bad "$1 — could not locate pattern matching '$2'"; return; }
  if ( cd "$FIX" && eval "$p" 2>/dev/null ) | grep -q -- "$3"; then bad "$1 — reported $3"
  else ok "$1"; fi
}
neg "placeholder env files not reported" "ls-files"   ".env.example"
neg "plain template literals not shell"  "shell_exec" "clean.js:1"
neg "non-literal assignment not a secret" "passwd"    "clean.js:3"
neg "parameterized query not injection"  "SELECT"     "clean.js:4"

printf '\n'
if [ "$FAIL" -eq 0 ]; then echo "all checks passed"; else echo "CHECKS FAILED"; fi
exit "$FAIL"

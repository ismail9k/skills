#!/usr/bin/env bash
# check.sh — the repo's "test" step. The deliverables are Markdown, so what
# can break is consistency, not compilation:
#
#   1. every skill's frontmatter name matches its directory
#   2. .claude-plugin/plugin.json declares exactly the skills on disk
#   3. no skill references another by path (each is installed alone)
#   4. anti-koshary's grep patterns still match a file with a known hit
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
head_ "plugin.json declares exactly what is on disk"
MANIFEST=.claude-plugin/plugin.json
DECLARED=$(sed -n 's|.*"\./skills/\([a-z0-9-]*\)".*|\1|p' "$MANIFEST" | sort)
ONDISK=$(ls -1 skills | sort)
for s in $DECLARED; do
  [ -d "skills/$s" ] || bad "declared but missing on disk: $s"
done
for s in $ONDISK; do
  printf '%s\n' "$DECLARED" | grep -qx "$s" || bad "on disk but undeclared: $s"
done
[ "$FAIL" -eq 0 ] && ok "$(printf '%s\n' "$ONDISK" | grep -c .) skills, all declared"

# ------------------------------------------------------- 3. no path coupling
head_ "no skill references another by path"
for d in skills/*/; do
  b=$(basename "$d")
  hits=$(grep -rn "skills/" "$d" 2>/dev/null | grep -v "skills/$b" | grep -v '^Binary')
  if [ -n "$hits" ]; then bad "$b references another skill by path:"; printf '%s\n' "$hits" | sed 's/^/          /'
  else ok "$b"; fi
done

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

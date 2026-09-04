#!/usr/bin/env bash
# dep_audit.sh — detect the project's package manager, then report outdated
# packages and known vulnerabilities.
#
# Usage: bash dep_audit.sh [project-dir]   (defaults to the current directory)
#
# Written for bash 3.2 (macOS default). Never fails the whole run because one
# ecosystem's tool is missing — it reports what it could not do and moves on.

set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" || { echo "cannot enter $ROOT" >&2; exit 1; }

FOUND=0

section() { printf '\n=== %s ===\n' "$1"; }

# Run a command if its binary exists; otherwise say what is missing and why
# it matters, so the agent can decide whether to install it or skip.
try() {
  local bin="$1"; shift
  if command -v "$bin" >/dev/null 2>&1; then
    printf '$ %s\n' "$*"
    "$@" 2>&1
    printf '\n'
  else
    printf '[skipped] %s is not installed — could not run: %s\n\n' "$bin" "$*"
  fi
}

# ---------------------------------------------------------------- JavaScript
if [ -f package.json ]; then
  FOUND=1
  if   [ -f bun.lockb ] || [ -f bun.lock ]; then JS=bun
  elif [ -f pnpm-lock.yaml ];               then JS=pnpm
  elif [ -f yarn.lock ];                    then JS=yarn
  else                                           JS=npm
  fi
  section "JavaScript / TypeScript (manager: $JS)"
  case "$JS" in
    bun)
      try bun bun outdated
      try bun bun audit
      ;;
    pnpm)
      try pnpm pnpm outdated
      try pnpm pnpm audit
      ;;
    yarn)
      # Yarn 1 and Berry disagree on both subcommands; try the Berry form
      # first and fall back, rather than parsing the version.
      if yarn --version 2>/dev/null | grep -q '^1\.'; then
        try yarn yarn outdated
        try yarn yarn audit
      else
        try yarn yarn upgrade-interactive --dry-run
        try yarn yarn npm audit --all
      fi
      ;;
    npm)
      # `npm outdated` exits 1 when anything is outdated; that is not an error.
      try npm npm outdated
      try npm npm audit
      ;;
  esac
fi

# -------------------------------------------------------------------- Python
if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f Pipfile ] || [ -f setup.py ]; then
  FOUND=1
  if   [ -f poetry.lock ]; then PY=poetry
  elif [ -f uv.lock ];     then PY=uv
  elif [ -f Pipfile.lock ] || [ -f Pipfile ]; then PY=pipenv
  else                          PY=pip
  fi
  section "Python (manager: $PY)"
  case "$PY" in
    poetry) try poetry poetry show --outdated ;;
    uv)     try uv uv pip list --outdated ;;
    pipenv) try pipenv pipenv update --outdated ;;
    pip)    try pip pip list --outdated ;;
  esac
  # pip-audit reads the installed environment and works regardless of manager.
  try pip-audit pip-audit
fi

# ---------------------------------------------------------------------- Rust
if [ -f Cargo.toml ]; then
  FOUND=1
  section "Rust (cargo)"
  try cargo-outdated cargo outdated
  try cargo-audit cargo audit
fi

# ------------------------------------------------------------------------ Go
if [ -f go.mod ]; then
  FOUND=1
  section "Go"
  try go go list -u -m all
  try govulncheck govulncheck ./...
fi

# ---------------------------------------------------------------------- Ruby
if [ -f Gemfile ]; then
  FOUND=1
  section "Ruby (bundler)"
  try bundle bundle outdated
  try bundle-audit bundle-audit check --update
fi

# ------------------------------------------------------------------- PHP
if [ -f composer.json ]; then
  FOUND=1
  section "PHP (composer)"
  try composer composer outdated
  try composer composer audit
fi

# ------------------------------------------------------------------- Java/JVM
if [ -f pom.xml ]; then
  FOUND=1
  section "Java (maven)"
  try mvn mvn versions:display-dependency-updates
  echo "[note] for CVEs run: mvn org.owasp:dependency-check-maven:check"
fi
if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  FOUND=1
  section "Java/Kotlin (gradle)"
  echo "[note] needs the versions plugin: ./gradlew dependencyUpdates"
fi

if [ "$FOUND" -eq 0 ]; then
  cat <<'EOF'
No recognized dependency manifest found.

Looked for: package.json, pyproject.toml, requirements.txt, Pipfile,
setup.py, Cargo.toml, go.mod, Gemfile, composer.json, pom.xml, build.gradle

Fall back to this ecosystem's own outdated/audit commands and say in the
report that the bundled script did not cover the stack.
EOF
  exit 2
fi

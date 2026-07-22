#!/bin/sh
# arch-guard install — wire a deterministic layering-direction guard into a
# repo's pre-commit. Idempotent: safe to re-run, never clobbers your config.
#
# Does the mechanical, deterministic parts only:
#   1. copy hooks/arch-guard-check.sh (the generic checker)
#   2. seed hooks/arch-layers.conf from the template IF absent (you fill it)
#   3. make pre-commit call the checker (create or append, marker-guarded)
#   4. git config core.hooksPath hooks
# Filling arch-layers.conf and the CLAUDE.md section is the agent's job
# (see the arch-guard SKILL.md) — those need repo knowledge, not automation.

set -e
SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)   # skill root
ASSETS="$SKILL_DIR/assets"

[ -d .git ] || { echo "arch-guard: run from a git repo root (.git not found)"; exit 1; }
mkdir -p hooks

# 1. checker (always refresh — it's the tool, versioned by the skill)
cp "$ASSETS/arch-guard-check.sh" hooks/arch-guard-check.sh
chmod +x hooks/arch-guard-check.sh
echo "arch-guard: hooks/arch-guard-check.sh installed"

# 2. config — seed once, never overwrite a filled one
if [ -f hooks/arch-layers.conf ]; then
  echo "arch-guard: hooks/arch-layers.conf exists — left as-is"
else
  cp "$ASSETS/arch-layers.conf.template" hooks/arch-layers.conf
  echo "arch-guard: hooks/arch-layers.conf seeded — FILL IN the <TODO> layers"
fi

# 3. pre-commit calls the checker (marker-guarded, idempotent)
MARK="# >>> arch-guard >>>"
BLOCK='# >>> arch-guard >>>
sh "$(dirname "$0")/arch-guard-check.sh" || true
# <<< arch-guard <<<'
if [ -f hooks/pre-commit ]; then
  if grep -qF "$MARK" hooks/pre-commit; then
    echo "arch-guard: pre-commit already calls the checker — unchanged"
  else
    printf '\n%s\n' "$BLOCK" >> hooks/pre-commit
    echo "arch-guard: appended checker call to existing hooks/pre-commit"
  fi
else
  printf '%s\n%s\n' '#!/bin/sh' "$BLOCK" > hooks/pre-commit
  echo "arch-guard: created hooks/pre-commit"
fi
chmod +x hooks/pre-commit

# 4. hooksPath wiring (idempotent)
git config core.hooksPath hooks
echo "arch-guard: core.hooksPath → hooks"

echo
echo "Next (agent / you):"
echo "  1. Fill hooks/arch-layers.conf (PACKAGE, LAYERS top→bottom, PARTITIONED)."
echo "  2. Run: sh hooks/arch-guard-check.sh --audit   # see current violations"
echo "  3. Add the layering section to CLAUDE.md (assets/claude-md-arch-section.md)."

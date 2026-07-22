#!/bin/sh
# arch-guard-check — flag imports that break the declared layering.
#
# Reads a repo-local config (default hooks/arch-layers.conf) that declares an
# ordered set of layers (top → bottom). Rule: a file in a layer may import only
# layers BELOW it. Upward imports, and (for PARTITIONED layers) imports between
# sibling sub-modules, are violations.
#
# Modes:
#   (default)   warn-only — print violations, exit 0. For pre-commit.
#   --strict    exit 1 if any violation (for CI / pre-push).
#   --audit     print violations + a per-rule count summary, exit 0.
#
# Config path override: ARCH_LAYERS_CONF=path sh arch-guard-check.sh
# Deterministic (git grep); safe to run from a repo root.

mode="warn"
case "$1" in
  --strict) mode="strict" ;;
  --audit)  mode="audit" ;;
esac

conf="${ARCH_LAYERS_CONF:-hooks/arch-layers.conf}"
if [ ! -f "$conf" ]; then
  echo "arch-guard: no config at $conf — skipped (see arch-guard skill)"
  exit 0
fi
# shellcheck disable=SC1090
. "$conf"
: "${ROOT:=lib}" "${IGNORE:=__never_matches__}"

count=0
YEL='\033[33m'; RST='\033[0m'

report() {  # $1=label  $2=hits(multiline)
  [ -z "$2" ] && return 0
  n=$(printf '%s\n' "$2" | grep -c .)
  count=$((count + n))
  printf "${YEL}⚠  分層違規：%s${RST}\n" "$1"
  printf '%s\n' "$2" | sed 's/^/    /'
}

# import-line regex for a given layer name (substitute {LAYER})
re_for() { printf '%s' "$IMPORT_RE" | sed "s/{LAYER}/$1/g"; }

# ── upward imports: a file in <layer> importing any HIGHER layer ──────────
for layer in $LAYERS; do
  higher=""
  for h in $LAYERS; do
    [ "$h" = "$layer" ] && break
    higher="$higher $h"
  done
  for h in $higher; do
    hits=$(git grep -nE "$(re_for "$h")" -- "$ROOT/$layer" 2>/dev/null | grep -v "$IGNORE")
    report "$layer → $h 往上依賴（禁止）" "$hits"
  done
done

# ── partitioned siblings: <layer>/A importing <layer>/B (A≠B) ─────────────
for layer in $PARTITIONED; do
  hits=$(
    git grep -nE "$(re_for "$layer")" -- "$ROOT/$layer" 2>/dev/null | grep -v "$IGNORE" |
    while IFS= read -r line; do
      file=${line%%:*}
      src=$(printf '%s' "$file" | sed -E "s#$ROOT/$layer/([^/]+)/.*#\1#")
      tgt=$(printf '%s' "$line" | sed -E "s#.*/$layer/([^/]+)/.*#\1#")
      [ "$src" != "$tgt" ] && printf '%s → %s  (%s)\n' "$src" "$tgt" "$file"
    done
  )
  report "$layer → $layer sibling 互 import（禁止，共享請下沉低層）" "$hits"
done

# ── tail ─────────────────────────────────────────────────────────────────
if [ "$mode" = "audit" ]; then
  printf "${YEL}arch-guard audit：共 %s 條違規${RST}\n" "$count"
  exit 0
fi
if [ "$count" -gt 0 ]; then
  printf "${YEL}   （arch-guard：依賴只准往下；共享請下沉低層，別橫向/往上）${RST}\n"
  [ "$mode" = "strict" ] && exit 1
fi
exit 0

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

# 不能用 `[ -d .git ]`：worktree 的 `.git` 是**檔案**，那樣寫會在 worktree 裡拒跑，
# 而且錯誤訊息還說「找不到」——它就在那裡。
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "arch-guard: run from inside a git repo"; exit 1; }
cd "$(git rev-parse --show-toplevel)"
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
  echo "arch-guard: hooks/arch-layers.conf seeded — FILL IN every <TODO>"
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
    # 不能無腦 append：dispatcher 常以頂層 `exit 0` 收尾，接在它後面的區塊永遠
    # 不會執行——裝了卻不觸發是最糟的失敗（看起來有守門，其實沒有）。
    # 插在第一個「真的會執行」的行之前：既有 hook 可能有**中段**的 early exit，
    # 只找行尾的 `exit 0` 會漏掉。**marker 行也是註解**，跳過註解時要認得它們，
    # 否則會插進別人的區塊內——對方用 marker 範圍解除安裝時會把我們一起帶走。
    LINE=$(awk '
        NR == 1 && /^#!/ { next }
        /^[[:space:]]*#[[:space:]]*>>>/ { d++; if (d == 1) bs = NR; next }
        /^[[:space:]]*#[[:space:]]*<<</ { if (d > 0) d--; if (d == 0) bs = 0; next }
        /^[[:space:]]*(#|$)/ { next }
        { print (bs ? bs : NR); exit }
    ' hooks/pre-commit)
    # wc -l 數的是換行數：檔尾沒有換行時少算一行，插入點會落在最後一行**之前**——
    # 那行若是別人的 <<< 收尾，我們的區塊就被包進對方體內，對方解除安裝時一起消失。
    # awk 的 NR 不受檔尾換行影響。
    [ -n "$LINE" ] || LINE=$(( $(awk 'END{print NR}' hooks/pre-commit) + 1 ))
    { head -n $((LINE - 1)) hooks/pre-commit
      printf '%s\n\n' "$BLOCK"
      tail -n +"$LINE" hooks/pre-commit
    } > hooks/pre-commit.tmp && mv hooks/pre-commit.tmp hooks/pre-commit
    echo "arch-guard: inserted checker call into hooks/pre-commit"
  fi
else
  printf '%s\n%s\n' '#!/bin/sh' "$BLOCK" > hooks/pre-commit
  echo "arch-guard: created hooks/pre-commit"
fi
chmod +x hooks/pre-commit

# 4. hooksPath wiring (idempotent)
# 無條件覆寫會**靜默停用**既有佈線（husky/.githooks），既有 hook 從此不再跑；
# 而 `git config` 寫的是**共用** config，在 linked worktree 裡設會讓主 checkout
# 也指向一個它沒有的 hooks/。兩種都是「裝一道守門把別處全關掉」。
EXISTING_HP=$(git config --get core.hooksPath 2>/dev/null || true)
GITDIR=$(git rev-parse --git-dir); COMMON=$(git rev-parse --git-common-dir)
if [ -n "$EXISTING_HP" ] && [ "$EXISTING_HP" != "hooks" ]; then
  echo "arch-guard: core.hooksPath 已是 '$EXISTING_HP' — 未更動；請把 hooks/pre-commit 的區塊併進該目錄"
  echo "arch-guard: ⚠  尚未佈線，git 不會執行 hooks/pre-commit"
elif [ -x .git/hooks/pre-commit ]; then
  echo "arch-guard: .git/hooks/pre-commit 存在會遮蔽 hooksPath — 未佈線；請先合併"
  echo "arch-guard: ⚠  尚未佈線，git 不會執行 hooks/pre-commit"
elif [ "$GITDIR" != "$COMMON" ] && [ ! -d "$(dirname "$COMMON")/hooks" ]; then
  echo "arch-guard: 這是 linked worktree，且主 checkout 沒有 hooks/ — 未佈線"
  echo "arch-guard: ⚠  現在設會讓主 checkout 的 hook 全部失效；請先在主 checkout commit 出 hooks/"
else
  git config core.hooksPath hooks
  echo "arch-guard: core.hooksPath → hooks"
fi

echo
echo "Next (agent / you):"
echo "  1. Fill hooks/arch-layers.conf (ROOT, PACKAGE, IMPORT_RE, LAYERS top→bottom,
     PARTITIONED, IGNORE) — the checker refuses to run while any <TODO> remains.
     Fields that do not apply take an empty string, not a made-up value,"
echo "     and CHOKEPOINTS if the repo has 'must go through X' rules worth grepping."
echo "  2. Run: sh hooks/arch-guard-check.sh --audit   # see current violations"
echo "     Pick each chokepoint's mode from what this reports: 0 hits -> all, debt -> new."
echo "     A non-zero exit means step 1 is not finished — read what it says, do NOT read it as 0 hits."
echo "  3. Add the layering section to CLAUDE.md (assets/claude-md-arch-section.md)."

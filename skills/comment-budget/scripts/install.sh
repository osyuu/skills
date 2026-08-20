#!/bin/sh
# comment-budget install —— 把註解量的 warn-only 檢查接進 repo 的 pre-commit。
# Idempotent：可重跑，不會蓋掉已填的 conf。
#
#   1. copy hooks/comment-budget-check.sh（checker 本體，由 skill 版本控管）
#   2. seed hooks/comment-budget.conf（僅當不存在——門檻是 repo 的決定）
#   3. 把 checker 接進 hooks/pre-commit（marker-guarded，與 arch-guard /
#      sdd-harness-init 的區塊共存）
#   4. git config core.hooksPath hooks
#
# 寫進 CLAUDE.md 的那段判準是 agent 的工作（見 SKILL.md）——沒有那段，
# hook 只會在 commit 當下抱怨，不會改變下一次怎麼寫。

set -e
SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ASSETS="$SKILL_DIR/assets"

[ -d .git ] || { echo "comment-budget: run from a git repo root (.git not found)"; exit 1; }
mkdir -p hooks

cp "$ASSETS/comment-budget-check.sh" hooks/comment-budget-check.sh
chmod +x hooks/comment-budget-check.sh
echo "comment-budget: hooks/comment-budget-check.sh installed"

if [ -f hooks/comment-budget.conf ]; then
  echo "comment-budget: hooks/comment-budget.conf exists — left as-is"
else
  cp "$ASSETS/comment-budget.conf.template" hooks/comment-budget.conf
  echo "comment-budget: hooks/comment-budget.conf seeded"
fi

MARK="# >>> comment-budget >>>"
BLOCK='# >>> comment-budget >>>
sh "$(dirname "$0")/comment-budget-check.sh" || true
# <<< comment-budget <<<'
if [ -f hooks/pre-commit ]; then
  if grep -qF "$MARK" hooks/pre-commit; then
    echo "comment-budget: pre-commit already calls the checker — unchanged"
  else
    # 不能無腦 append：dispatcher 常以頂層 `exit 0` 收尾，接在它後面的區塊
    # 永遠不會執行——裝了卻不觸發是最糟的失敗（看起來有守門，其實沒有）。
    # 有頂層 exit 就插在它之前，沒有才 append。
    if awk '/^exit 0$/ { found = NR } END { exit !found }' hooks/pre-commit; then
      LINE=$(awk '/^exit 0$/ { n = NR } END { print n }' hooks/pre-commit)
      { head -n $((LINE - 1)) hooks/pre-commit
        printf '%s\n\n' "$BLOCK"
        tail -n +"$LINE" hooks/pre-commit
      } > hooks/pre-commit.tmp && mv hooks/pre-commit.tmp hooks/pre-commit
      echo "comment-budget: inserted checker call before the trailing 'exit 0'"
    else
      printf '\n%s\n' "$BLOCK" >> hooks/pre-commit
      echo "comment-budget: appended checker call to existing hooks/pre-commit"
    fi
  fi
else
  printf '%s\n%s\n' '#!/bin/sh' "$BLOCK" > hooks/pre-commit
  echo "comment-budget: created hooks/pre-commit"
fi
chmod +x hooks/pre-commit

git config core.hooksPath hooks
echo "comment-budget: core.hooksPath → hooks"

echo
echo "Next (agent / you):"
echo "  1. 跑一次基準：看既有 commit 的開火率，決定要不要調 hooks/comment-budget.conf。"
echo "  2. 把判準那段寫進 CLAUDE.md（見 SKILL.md 的「寫進 CLAUDE.md」）。"

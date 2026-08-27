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

# 不能用 `[ -d .git ]`：worktree 的 `.git` 是**檔案**，那樣寫會在 worktree 裡拒跑，
# 而且錯誤訊息還說「找不到」——它就在那裡。
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "comment-budget: run from inside a git repo"; exit 1; }
cd "$(git rev-parse --show-toplevel)"
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
    # 插在最前面（shebang 與檔頭註解之後），不是 append：既有 hook 的中途 exit
    # 會讓接在後面的區塊永遠不跑。依據見 SKILL.md〈與別人共用同一支 pre-commit〉。
    # **marker 行也是註解**，無腦跳過會插進別人的區塊裡——對方用 marker 範圍
    # 解除安裝時會把我們一起帶走，而症狀是靜默少一道守門。marker 可能**有縮排**
    # 也可能**巢狀**，所以錨點不能釘在第 0 欄，收合要靠深度計數。
    LINE=$(awk '
        NR == 1 && /^#!/ { next }
        /^[[:space:]]*#[[:space:]]*>>>/ { d++; if (d == 1) bs = NR; next }
        /^[[:space:]]*#[[:space:]]*<<</ { if (d > 0) d--; if (d == 0) bs = 0; next }
        /^[[:space:]]*(#|$)/ { next }
        { print (bs ? bs : NR); exit }
    ' hooks/pre-commit)
    [ -n "$LINE" ] || LINE=$(( $(wc -l < hooks/pre-commit) + 1 ))
    { head -n $((LINE - 1)) hooks/pre-commit
      printf '%s\n\n' "$BLOCK"
      tail -n +"$LINE" hooks/pre-commit
    } > hooks/pre-commit.tmp && mv hooks/pre-commit.tmp hooks/pre-commit
    echo "comment-budget: inserted checker call at the top of hooks/pre-commit"
  fi
else
  printf '%s\n%s\n' '#!/bin/sh' "$BLOCK" > hooks/pre-commit
  echo "comment-budget: created hooks/pre-commit"
fi
chmod +x hooks/pre-commit

EXISTING_HP=$(git config --get core.hooksPath 2>/dev/null || true)
if [ -n "$EXISTING_HP" ] && [ "$EXISTING_HP" != "hooks" ]; then
  # 無條件覆寫會**靜默停用**既有佈線（husky/.githooks 之類），既有的 hook 從此不再跑。
  echo "comment-budget: core.hooksPath 已是 '$EXISTING_HP' — 未更動；請把 hooks/pre-commit 的區塊併進該目錄"
elif [ -x .git/hooks/pre-commit ]; then
  echo "comment-budget: .git/hooks/pre-commit 存在會遮蔽 hooksPath — 未佈線；請先合併再自行 git config core.hooksPath hooks"
elif [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ] &&
     [ ! -d "$(dirname "$(git rev-parse --git-common-dir)")/hooks" ]; then
  # linked worktree：`git config` 寫的是**共用**的 config。主 checkout 沒有 hooks/
  # 時，設下去等於關掉它的所有 hook——裝一道守門的副作用是關掉別處的全部。
  echo "comment-budget: 這是 linked worktree，且主 checkout 沒有 hooks/ — 未佈線"
  echo "                請先在主 checkout commit 出 hooks/，再自行 git config core.hooksPath hooks"
else
  git config core.hooksPath hooks
  echo "comment-budget: core.hooksPath → hooks"
fi

echo
echo "Next (agent / you):"
echo "  1. 跑一次基準：看既有 commit 的開火率，決定要不要調 hooks/comment-budget.conf。"
echo "  2. 把判準那段寫進 CLAUDE.md（見 SKILL.md 的「寫進 CLAUDE.md」）。"

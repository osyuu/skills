#!/bin/sh
# comment-budget 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 這支守的是**靜默失效**：門檻打錯字、檔名含空白、從子目錄跑、被別人的 early exit
# 跳過——這些全都回「沒有警告」，跟「這批改動很乾淨」長得一模一樣。讀 code 分不出來。

set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
SDD=$(cd "$SKILL/../sdd-harness-init" && pwd)

# **先進沙箱再做任何事。** 這支會 git init、寫檔、跑 install；在呼叫者的 cwd 執行
# 等於把測試 fixture 灌進別人的 repo。路徑先解析成絕對路徑,cd 之後才用得到。
SANDBOX=$(mktemp -d)
trap 'cd /; rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX" || exit 1
pass=0
fail=0

ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }

# 只回傳路徑，不 cd——命令替換跑在子 shell 裡，函式內的 cd 出不來，
# 呼叫端會留在原地把 fixture 寫進別人的 repo。呼叫端要自己 cd。
newrepo() {
  d=$(mktemp -d "$SANDBOX/r.XXXXXX")
  ( cd "$d" && git init -q . && git config user.email t@t &&
    git config user.name t && echo seed > seed.txt && git add -A &&
    git -c core.hooksPath=/dev/null commit -qm init ) >/dev/null 2>&1
  printf '%s' "$d"
}
enter() { cd "$1" || exit 1; }
strip() { sed 's/\033\[[0-9;]*m//g'; }

# 11 行連續註解 + 一行程式
long_block() { printf '// 一\n// 二\n// 三\n// 四\n// 五\n// 六\n// 七\n// 八\n// 九\n// 十\n// 十一\nint x = 0;\n'; }

echo "── 基本功能 ──"
D=$(newrepo); enter "$D"; sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
long_block > a.dart; git add -A
out=$(sh hooks/comment-budget-check.sh 2>&1 | strip)
ok "抓得到過長註解區塊" "單一註解區塊 11 行" "$out"

printf '// 原本是用 map 寫的\nint y = 0;\n' > b.dart; git add -A
out=$(sh hooks/comment-budget-check.sh 2>&1 | strip)
ok "抓得到歷史敘事" "b.dart" "$out"
cd "$SANDBOX" || exit 1

echo "── 靜默失效 ──"
# hunk 邊界被濾掉的話，散落各處的短註解會被串成一個假的長區塊
D=$(newrepo); enter "$D"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
# **要既有檔的多處分散編輯**：新檔只有一個 hunk，拼接問題不會出現。
i=1; : > c.dart
while [ $i -le 60 ]; do printf 'int v%s = %s;\n' "$i" "$i" >> c.dart; i=$((i+1)); done
git add -A; git -c core.hooksPath=/dev/null commit -qm base >/dev/null 2>&1
# 6 處 × 2 行 = 拼接後 12 行（超過門檻 10），但每一處真實只有 2 行。
awk 'NR==5 || NR==15 || NR==25 || NR==35 || NR==45 || NR==55 { print "// 甲"; print "// 乙" } { print }' c.dart > c.new
mv c.new c.dart; git add -A
out=$(sh hooks/comment-budget-check.sh 2>&1 | strip)
no "散落的短註解不被串成假區塊" "c.dart：單一註解區塊" "$out"
cd "$SANDBOX" || exit 1

D=$(newrepo); enter "$D"; sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
long_block > "has space.dart"; git add -A
out=$(sh hooks/comment-budget-check.sh 2>&1 | strip)
ok "檔名含空白不被跳過" "has space.dart" "$out"
cd "$SANDBOX" || exit 1

D=$(newrepo); enter "$D"; sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
long_block > d.dart; git add -A
out=$(COMMENT_BLOCK_MAX=abc sh hooks/comment-budget-check.sh 2>&1 | strip)
ok "門檻打錯字要出聲" "不是數字" "$out"
ok "門檻打錯字仍用預設值檢查" "單一註解區塊" "$out"
cd "$SANDBOX" || exit 1

D=$(newrepo); enter "$D"; sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
mkdir -p sub; long_block > e.dart; git add -A
out=$(cd sub && sh ../hooks/comment-budget-check.sh 2>&1 | strip)
ok "從子目錄跑也要檢查得到" "單一註解區塊" "$out"
cd "$SANDBOX" || exit 1

echo "── 與 sdd 共用同一支 pre-commit ──"
# 別人的區塊 early exit 時，這道闸不能跟著被跳過
D=$(newrepo); enter "$D"
sh "$SDD/scripts/install.sh" >/dev/null 2>&1
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
sed -i.bak 's/^- \[ \]/- [x]/' docs/design/DECISIONS.md 2>/dev/null || true
long_block > f.dart; git add -A
out=$(sh hooks/pre-commit 2>&1 | strip)
ok "沒有待回寫決策時，註解闸仍要跑" "單一註解區塊" "$out"
cd "$SANDBOX" || exit 1

echo "── 安裝 ──"
D=$(newrepo); enter "$D"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
out=$(sh "$SKILL/scripts/install.sh" 2>&1)
ok "重跑不重複注入" "already calls the checker" "$out"
ok "重跑不覆蓋 conf" "exists" "$out"
cd "$SANDBOX" || exit 1

D=$(newrepo); enter "$D"; git config core.hooksPath .husky; mkdir -p .husky
out=$(sh "$SKILL/scripts/install.sh" 2>&1)
ok "既有 hooksPath 不被靜默改掉" ".husky" "$out"
hp=$(git config core.hooksPath)
[ "$hp" = ".husky" ] && { pass=$((pass+1)); echo "  ok    hooksPath 確實沒被改"; } \
  || { fail=$((fail+1)); echo "  FAIL  hooksPath 被改成 $hp"; }
cd "$SANDBOX" || exit 1

D=$(newrepo); enter "$D"; git worktree add -q wt HEAD 2>/dev/null
out=$(cd wt && sh "$SKILL/scripts/install.sh" 2>&1)
no "worktree 裡不該拒跑" "run from inside a git repo" "$out"
cd "$SANDBOX" || exit 1

echo "── 與別的守門共存 ──"
# 插入點若把 marker 行當普通註解跳過，就會落進鄰居的區塊內；鄰居用 marker 範圍
# 解除安裝時會把這道守門一起帶走，而症狀是靜默少一道。
D=$(newrepo); enter "$D"; mkdir -p hooks
printf '#!/bin/sh\n# >>> other >>>\nsh "$(dirname "$0")/other.sh" || true\n# <<< other <<<\n' > hooks/pre-commit
printf '#!/bin/sh\necho OTHER-GUARD\n' > hooks/other.sh; chmod +x hooks/pre-commit hooks/other.sh
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
left=$(sed '/# >>> other >>>/,/# <<< other <<</d' hooks/pre-commit)
ok "移除鄰居後本守門還在" "comment-budget-check.sh" "$left"
long_block > a.dart; git add -A
out=$(sh hooks/pre-commit 2>&1 | strip)
ok "兩道守門都跑得到" "單一註解區塊 11 行" "$out"
ok "鄰居仍在"         "OTHER-GUARD"      "$out"
cd "$SANDBOX" || exit 1

echo "── worktree 不得關掉主 repo 的守門 ──"
# core.hooksPath 寫的是**共用** config。主 checkout 沒有 hooks/ 時設下去，
# 等於把它的所有 hook 關掉——裝一道守門的副作用是關掉別處的全部。
D=$(newrepo); enter "$D"; git worktree add -q "$D/../w2.$$" -b w2 >/dev/null 2>&1
( cd "$D/../w2.$$" && sh "$SKILL/scripts/install.sh" >/dev/null 2>&1 )
enter "$D"
hp=$(git config --get core.hooksPath || echo unset)
ok "主 repo 的 hooksPath 未被動到" "unset" "$hp"
cd "$SANDBOX" || exit 1

echo
echo "通過 ${pass}，失敗 ${fail}"
[ "$fail" -eq 0 ]

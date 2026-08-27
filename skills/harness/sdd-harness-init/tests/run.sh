#!/bin/sh
# sdd-harness-init 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 這支守的是**指示錯了而看起來沒錯**：followup 訊息把關鍵詞吃掉、對已經有指標節的
# repo 再叫人插一份、hook 的 early exit 把別人的檢查一起帶走。這些都不會報錯。

set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
# 找不到就硬失敗：空字串會讓依賴它的斷言變成在測空氣，而畫面上是綠的。
CB=$(cd "$SKILL/../comment-budget" && pwd) || { echo "找不到兄弟 skill comment-budget"; exit 2; }

# 先進沙箱：這支會 git init、寫檔、跑 install，在呼叫者的 cwd 執行等於污染別人的 repo。
SANDBOX=$(mktemp -d)
trap 'cd /; rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX" || exit 1
pass=0
fail=0

ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }

newrepo() {
  d=$(mktemp -d "$SANDBOX/r.XXXXXX")
  ( cd "$d" && git init -q . && git config user.email t@t &&
    git config user.name t && echo seed > seed.txt && git add -A &&
    git -c core.hooksPath=/dev/null commit -qm init ) >/dev/null 2>&1
  printf '%s' "$d"
}
enter() { cd "$1" || exit 1; }
strip() { sed 's/\033\[[0-9;]*m//g'; }

echo "── 安裝 ──"
D=$(newrepo); enter "$D"
out=$(sh "$SKILL/scripts/install.sh" 2>&1 | strip)
# 比對檔案本身，不是輸出文字：`say "[1/5] $LOG_PATH"` 不管有沒有真的建檔都會印出
# 「DECISIONS.md」，連「✓ 由模板建立」都照印。斷言比對輸出時，拿掉 cp 仍然全綠。
ok "建出 DECISIONS.md" "yes" "$([ -f docs/design/DECISIONS.md ] && echo yes || echo no)"
printf 'MINE\n' >> docs/design/DECISIONS.md
before=$(md5 -q docs/design/DECISIONS.md 2>/dev/null || md5sum docs/design/DECISIONS.md | cut -d' ' -f1)
out=$(sh "$SKILL/scripts/install.sh" 2>&1 | strip)
after=$(md5 -q docs/design/DECISIONS.md 2>/dev/null || md5sum docs/design/DECISIONS.md | cut -d' ' -f1)
# 比對的必須是檔案內容：輸出文字分不出「沒有覆蓋」與「沒有這則訊息」，
# 而不存在的字串配上 no() 是結構上不可證偽的斷言。
ok "重跑不覆蓋既有檔" "$before" "$after"
cd "$SANDBOX" || exit 1

D=$(newrepo); enter "$D"; git worktree add -q wt HEAD 2>/dev/null
out=$(cd wt && sh "$SKILL/scripts/install.sh" 2>&1 | strip)
no "worktree 裡不該拒跑" "不在 git repo" "$out"
cd "$SANDBOX" || exit 1

echo "── followup 訊息要完整 ──"
# 訊息裡的反引號會被當命令替換執行，關鍵詞就從指示裡消失，
# 而那句正是在教人怎麼避開「插錯位置＝裝了卻不觸發」。
D=$(newrepo); enter "$D"
mkdir -p hooks && printf '#!/bin/sh\necho foreign\nexit 0\n' > hooks/pre-commit
chmod +x hooks/pre-commit; git config core.hooksPath hooks
out=$(sh "$SKILL/scripts/install.sh" 2>&1 | strip)
ok "不覆蓋外來 pre-commit" "不覆蓋" "$out"
ok "合併指示講得出插在哪" "最前面" "$out"
no "指示裡沒有被吃掉的空洞" "以頂層  收尾" "$out"
ok "spec-claim checker 一起裝進去" "spec-claim-check.sh" "$out"
ok "提醒去填路徑，否則靜默空轉" "SPEC_SRC_DIRS" "$out"
cd "$SANDBOX" || exit 1

echo "── 指標節只該有一份 ──"
D=$(newrepo); enter "$D"
printf '# X\n<!-- sdd-harness:decision-log:start -->\nsomething\n<!-- sdd-harness:decision-log:end -->\n' > CLAUDE.md
printf '# local\n' > CLAUDE.local.md
out=$(sh "$SKILL/scripts/install.sh" 2>&1 | strip)
no "已有一份就別叫人再插一份" "插進 CLAUDE.local.md" "$out"
cd "$SANDBOX" || exit 1

echo "── hook 行為 ──"
D=$(newrepo); enter "$D"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
echo "- [ ] 一筆未回寫" >> docs/design/DECISIONS.md
out=$(sh hooks/pre-commit 2>&1 | strip)
ok "有未回寫決策時出聲" "未回寫的決策" "$out"
sed -i.bak 's/^- \[ \]/- [x]/' docs/design/DECISIONS.md
out=$(sh hooks/pre-commit 2>&1 | strip)
no "全部打勾時不吵" "未回寫的決策" "$out"

# 本區塊的 early exit 只能結束自己：共用 hook 時不能把後面別人的檢查一起帶走。
sh "$CB/scripts/install.sh" >/dev/null 2>&1
printf '// 一\n// 二\n// 三\n// 四\n// 五\n// 六\n// 七\n// 八\n// 九\n// 十\n// 十一\nint x = 0;\n' > z.dart
git add -A
out=$(sh hooks/pre-commit 2>&1 | strip)
ok "early exit 不把後面的檢查帶走" "單一註解區塊" "$out"

# 上面那條靠 comment-budget 插在最前面也會過，測不到子 shell 本身。
# 這條把區塊接在**最後面**，唯一能讓它跑到的就是 sdd 的 exit 只結束自己。
printf 'echo TAIL_RAN\n' >> hooks/pre-commit
out=$(sh hooks/pre-commit 2>&1 | strip)
ok "接在本區塊後面的東西仍會執行" "TAIL_RAN" "$out"
cd "$SANDBOX" || exit 1

echo "── worktree 不得關掉主 repo 的守門 ──"
# core.hooksPath 寫的是**共用** config。主 checkout 沒有 hooks/ 時設下去，
# 等於關掉它的所有 hook——裝一道守門的副作用是關掉別處的全部。
D=$(newrepo); enter "$D"
git worktree add -q "$D/../w.$$" -b w >/dev/null 2>&1
( cd "$D/../w.$$" && sh "$SKILL/scripts/install.sh" >/dev/null 2>&1 )
enter "$D"
ok "主 repo 的 hooksPath 未被動到" "unset" "$(git config --get core.hooksPath || echo unset)"
cd "$SANDBOX" || exit 1

echo
echo "通過 ${pass}，失敗 ${fail}"
[ "$fail" -eq 0 ]

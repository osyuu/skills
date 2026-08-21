#!/bin/sh
# sdd-harness-init 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 這支守的是**指示錯了而看起來沒錯**：followup 訊息把關鍵詞吃掉、對已經有指標節的
# repo 再叫人插一份、hook 的 early exit 把別人的檢查一起帶走。這些都不會報錯。

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
CB=$(cd "$SKILL/../comment-budget" && pwd)

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
ok "建出 DECISIONS.md" "DECISIONS.md" "$out"
out=$(sh "$SKILL/scripts/install.sh" 2>&1 | strip)
no "重跑不覆蓋既有檔" "已覆蓋" "$out"
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

echo
echo "通過 ${pass}，失敗 ${fail}"
[ "$fail" -eq 0 ]

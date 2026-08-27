#!/bin/sh
# 這三支守門自己的回歸測試。`sh hooks/tests.sh` 直接跑。
#
# 守門的失效是靜默的：路徑正則少吃一層、grep 少一個 -F、被測腳本讀了 stdin 把
# 清單吃掉——全都回「沒有發現」，跟真的沒問題長得一樣。而 hooks/ 底下的東西
# 本來完全在閘門之外：改壞它不會有任何人發現，包括它自己。
set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 傳給 hook，沙箱裡的 git 會因此操作到
# **外層** repo。單獨跑時全綠、從 pre-commit 跑時打在真 repo 上。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HOOKS=$(cd "$(dirname "$0")" && pwd)
SANDBOX=$(mktemp -d)
trap 'cd /; rm -rf "$SANDBOX"' EXIT
pass=0; fail=0
strip() { sed 's/\033\[[0-9;]*m//g'; }
ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }

newrepo() { d=$(mktemp -d "$SANDBOX/r.XXXXXX"); ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t ); printf '%s' "$d"; }
mkskill() { # mkskill <repo> <相對 skill 路徑> <run.sh 內容>
  mkdir -p "$1/$2/tests" "$1/$2/scripts"
  printf '#!/bin/sh\necho x\n' > "$1/$2/scripts/install.sh"
  printf '%s\n' "$3" > "$1/$2/tests/run.sh"
}

echo "── skill-tests：路徑形狀 ──"
D=$(newrepo); mkskill "$D" skills/harness/alpha '#!/bin/sh
echo "3 passed, 0 failed"'
mkskill "$D" skills/flat '#!/bin/sh
echo "通過 2，失敗 0"'
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "分類路徑會開火"   "alpha 3 passed, 0 failed" "$out"
ok "扁平路徑也會開火" "flat 通過 2，失敗 0"      "$out"

D=$(newrepo); printf 'x\n' > "$D/README.md"; ( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
no "無關檔案時完全靜默" "skill-tests" "$out"

echo "── skill-tests：測試紅時要出聲 ──"
D=$(newrepo); mkskill "$D" skills/harness/beta '#!/bin/sh
echo "FAIL  壞掉的斷言"
exit 1'
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "測試沒過要報"     "beta 的測試沒過" "$out"
ok "帶出失敗那幾行"   "壞掉的斷言"      "$out"

echo "── skill-tests：tests/ 下的其他 *.sh ──"
D=$(newrepo); mkskill "$D" skills/harness/gamma '#!/bin/sh
echo "1 passed, 0 failed"'
printf '#!/bin/sh\necho "32 passed, 0 failed"\n' > "$D/skills/harness/gamma/tests/spec.sh"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "額外測試會被跑到" "gamma/spec.sh 32 passed, 0 failed" "$out"

printf '#!/bin/sh\necho "沒有可辨識的摘要"\n' > "$D/skills/harness/gamma/tests/spec.sh"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "認不出摘要要講出來" "(認不出摘要行)" "$out"

# 迴圈體的 stdin 就是那條 pipe：被測腳本讀一次 stdin 就會把其餘 skill 的清單吃光，
# 而輸出跟「只有這一個 skill 有改動」完全同形。
D=$(newrepo)
for n in aaa bbb ccc; do mkskill "$D" "skills/harness/$n" '#!/bin/sh
echo "1 passed, 0 failed"'; done
printf '#!/bin/sh\ncat >/dev/null\necho "9 passed, 0 failed"\n' > "$D/skills/harness/aaa/tests/eat.sh"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "吃 stdin 的測試不會吞掉別的 skill（bbb）" "bbb 1 passed" "$out"
ok "吃 stdin 的測試不會吞掉別的 skill（ccc）" "ccc 1 passed" "$out"

# run.sh 自己讀 stdin 是同一個洞的另一半（額外測試那條蓋不到它）。
D=$(newrepo)
for n in ddd eee; do mkskill "$D" "skills/harness/$n" '#!/bin/sh
echo "1 passed, 0 failed"'; done
printf '#!/bin/sh\ncat >/dev/null\necho "1 passed, 0 failed"\n' > "$D/skills/harness/ddd/tests/run.sh"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "吃 stdin 的 run.sh 不會吞掉別的 skill" "eee 1 passed" "$out"

D=$(newrepo)
for n in fff ggg; do mkskill "$D" "skills/harness/$n" '#!/bin/sh
echo "1 passed, 0 failed"'; done
printf '#!/bin/sh\ncat >/dev/null\necho "1 條注入轉紅，0 條沒有"\n' > "$D/skills/harness/fff/tests/mutants.sh"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/skill-tests.sh" 2>&1 | strip)
ok "吃 stdin 的 mutants.sh 不會吞掉別的 skill" "ggg 1 passed" "$out"

echo "── marketplace-sync ──"
D=$(newrepo); mkdir -p "$D/.claude-plugin" "$D/skills/harness/newone"
printf '{"plugins":[]}\n' > "$D/.claude-plugin/marketplace.json"
printf -- '---\nname: newone\n---\n' > "$D/skills/harness/newone/SKILL.md"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/marketplace-sync.sh" 2>&1 | strip)
ok "未登錄要出聲" "skills/harness/newone" "$out"

printf '{"plugins":[{"name":"newone","skills":["./skills/harness/newone"]}]}\n' > "$D/.claude-plugin/marketplace.json"
out=$(cd "$D" && sh "$HOOKS/marketplace-sync.sh" 2>&1 | strip)
no "登錄之後靜默" "marketplace-sync" "$out"

# 登錄比對用的是路徑字串，裡面的 . 不能當萬用字元（grep 要 -F）。
D=$(newrepo); mkdir -p "$D/.claude-plugin" "$D/skills/harness/foo.bar"
printf '{"plugins":[{"name":"x","skills":["./skills/harness/fooXbar"]}]}\n' > "$D/.claude-plugin/marketplace.json"
printf -- '---\nname: foo.bar\n---\n' > "$D/skills/harness/foo.bar/SKILL.md"
( cd "$D" && git add -A ) >/dev/null 2>&1
out=$(cd "$D" && sh "$HOOKS/marketplace-sync.sh" 2>&1 | strip)
ok "登錄比對不把 . 當萬用字元" "skills/harness/foo.bar" "$out"

echo "── comment-budget ──"
D=$(newrepo); cp "$HOOKS/comment-budget.conf" "$D/" 2>/dev/null || true
mkdir -p "$D/hooks"; cp "$HOOKS/comment-budget-check.sh" "$HOOKS/comment-budget.conf" "$D/hooks/" 2>/dev/null || true
{ printf '#!/bin/sh\n'; i=1; while [ $i -le 14 ]; do printf '# 註解第 %s 行\n' "$i"; i=$((i+1)); done; printf 'echo hi\n'; } > "$D/probe.sh"
( cd "$D" && git add probe.sh ) >/dev/null 2>&1
out=$(cd "$D" && sh hooks/comment-budget-check.sh 2>&1 | strip)
# 比對各自獨有的那句，不是檔名：這個 fixture 同時踩到兩個檢查，比對 probe.sh
# 的話殺掉任何一個檢查都還是綠的。
ok "過長註解區塊要出聲" "單一註解區塊" "$out"
ok "註解佔比過高要出聲" "% 是註解"     "$out"

D=$(newrepo); mkdir -p "$D/hooks"; cp "$HOOKS/comment-budget-check.sh" "$HOOKS/comment-budget.conf" "$D/hooks/" 2>/dev/null || true
printf '#!/bin/sh\n# 一行註解\necho hi\n' > "$D/probe.sh"
( cd "$D" && git add probe.sh ) >/dev/null 2>&1
out=$(cd "$D" && sh hooks/comment-budget-check.sh 2>&1 | strip)
no "沒超標時靜默" "註解預算" "$out"

echo "── sync-check ──"
D=$(newrepo)
mkdir -p "$D/.claude/hooks" "$D/skills/harness/claude-md-hygiene/assets" "$D/hooks" "$D/skills/harness/comment-budget/assets"
printf 'same\n' > "$D/.claude/hooks/claude-md-hygiene-hook.py"
printf 'same\n' > "$D/skills/harness/claude-md-hygiene/assets/claude-md-hygiene-hook.py"
printf 'same\n' > "$D/hooks/comment-budget-check.sh"
printf 'same\n' > "$D/skills/harness/comment-budget/assets/comment-budget-check.sh"
out=$(SYNC_CHECK_ROOT="$D" sh "$HOOKS/sync-check.sh" 2>&1 | strip)
no "兩份一致時靜默" "sync-check" "$out"
printf 'drifted\n' > "$D/.claude/hooks/claude-md-hygiene-hook.py"
out=$(SYNC_CHECK_ROOT="$D" sh "$HOOKS/sync-check.sh" 2>&1 | strip)
ok "來源與部署副本不一致要出聲" "不一致" "$out"
rm -f "$D/.claude/hooks/claude-md-hygiene-hook.py"
out=$(SYNC_CHECK_ROOT="$D" sh "$HOOKS/sync-check.sh" 2>&1 | strip)
ok "部署副本不存在要出聲（不是當成一致）" "無法比對" "$out"

# PAIRS 自己沒人守:新增第三份部署副本卻忘了登記,漂移就再也沒人看。
D=$(newrepo)
mkdir -p "$D/.claude/hooks" "$D/skills/harness/claude-md-hygiene/assets" "$D/hooks" "$D/skills/harness/comment-budget/assets"
printf 'same\n' > "$D/.claude/hooks/claude-md-hygiene-hook.py"
printf 'same\n' > "$D/skills/harness/claude-md-hygiene/assets/claude-md-hygiene-hook.py"
printf 'same\n' > "$D/hooks/comment-budget-check.sh"
printf 'same\n' > "$D/skills/harness/comment-budget/assets/comment-budget-check.sh"
mkdir -p "$D/skills/harness/newguard/assets"
printf 'x\n' > "$D/hooks/newguard-check.sh"
printf 'x\n' > "$D/skills/harness/newguard/assets/newguard-check.sh"
out=$(SYNC_CHECK_ROOT="$D" sh "$HOOKS/sync-check.sh" 2>&1 | strip)
ok "沒登記進 PAIRS 的部署副本要出聲" "不在 PAIRS 裡" "$out"

echo
echo "通過 ${pass}，失敗 ${fail}"
[ "$fail" -eq 0 ]

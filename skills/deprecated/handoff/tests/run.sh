#!/bin/sh
# handoff 的機械盤點測試。`sh tests/run.sh` 直接跑。
# 守的是「盤點腳本自己說謊」：乾淨的 repo 報成有殘留、或有殘留卻報乾淨。
set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
ST=$(cd "$HERE/.." && pwd)/scripts/state.sh
SANDBOX=$(mktemp -d); trap 'cd /; rm -rf "$SANDBOX"' EXIT
pass=0; fail=0
ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1";;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n' "$1" "$2";; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n' "$1" "$2";;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1";; esac; }

fresh() { rm -rf "$SANDBOX/r"; mkdir -p "$SANDBOX/r"; cd "$SANDBOX/r"
  git init -q .; git config user.email t@t; git config user.name t
  echo x > a.txt; git add -A; git commit -qm init; }

fresh
ok "乾淨的 repo 說沒有未 commit" "未 commit：無" "$(sh "$ST" 2>&1)"

fresh; echo y > b.txt
ok "有未追蹤檔案要列出來" "b.txt" "$(sh "$ST" 2>&1)"

fresh
ok "沒有 upstream 要講" "沒有 upstream" "$(sh "$ST" 2>&1)"

fresh; git worktree add -q wt HEAD 2>/dev/null
ok "額外的 worktree 要列出來" "額外的 worktree" "$(sh "$ST" 2>&1)"

fresh
no "沒有 worktree 時不該亂報" "額外的 worktree" "$(sh "$ST" 2>&1)"

cd "$SANDBOX"
ok "不在 repo 裡也不崩" "不在 git repo" "$(sh "$ST" 2>&1)"

# 靠記憶盤點是這支存在的理由，提醒必須每次都在。
fresh
out=$(sh "$ST" 2>&1)
ok "一定要提醒 agent 別憑印象數" "不要憑印象數" "$out"
ok "一定要問沒驗的東西" "沒驗的東西" "$out"
ok "一定要問故障有沒有還原並重建" "重建" "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

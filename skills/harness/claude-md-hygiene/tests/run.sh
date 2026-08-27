#!/bin/sh
# claude-md-hygiene 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# hook 不需要真的 session 才測得到——它的介面就是 stdin 的一包 JSON，手動餵就是
# 完整的測試面。守的是靜默失效：檔名比對寫錯、迴圈防護擋掉全部、壞 payload 讓
# 整支炸掉（hook 失敗會影響工具流程）、安裝器覆蓋掉別人的 PostToolUse。

set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
HOOK="$SKILL/assets/claude-md-hygiene-hook.py"

SANDBOX=$(mktemp -d)
TMPDIR="$SANDBOX/tmp"; export TMPDIR; mkdir -p "$TMPDIR"
trap 'cd /; rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX" || exit 1
pass=0
fail=0

ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }

fire() {  # fire <session> <path>
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$2" \
    | python3 "$HOOK" 2>&1
}
fresh() { rm -rf "$TMPDIR/claude-md-hygiene"; }

echo "── 該注入的檔名 ──"
fresh; ok "CLAUDE.md"       'additionalContext' "$(fire s /r/CLAUDE.md)"
fresh; ok "AGENTS.md"       'additionalContext' "$(fire s /r/AGENTS.md)"
fresh; ok "CLAUDE.local.md" 'additionalContext' "$(fire s /r/CLAUDE.local.md)"
fresh; ok "子目錄的 CLAUDE.md" 'additionalContext' "$(fire s /r/docs/CLAUDE.md)"
fresh; ok "訊息帶檔名"       'CLAUDE.local.md'   "$(fire s /r/CLAUDE.local.md)"
fresh; ok "hookEventName 正確" 'PostToolUse'     "$(fire s /r/CLAUDE.md)"

echo "── 不該注入的 ──"
fresh; no "README.md"        'additionalContext' "$(fire s /r/README.md)"
fresh; no "claude.md 小寫"   'additionalContext' "$(fire s /r/claude.md)"
fresh; no "CLAUDE.md.bak"    'additionalContext' "$(fire s /r/CLAUDE.md.bak)"
fresh; no "沒有 file_path"   'additionalContext' "$(printf '{"session_id":"s"}' | python3 "$HOOK" 2>&1)"

echo "── 迴圈防護 ──"
fresh
ok "第一次注入"           'additionalContext' "$(fire s1 /r/CLAUDE.md)"
no "同 session 同檔不再注入" 'additionalContext' "$(fire s1 /r/CLAUDE.md)"
ok "同 session 換檔仍注入"   'additionalContext' "$(fire s1 /r/AGENTS.md)"
ok "換 session 仍注入"       'additionalContext' "$(fire s2 /r/CLAUDE.md)"
# 拿不到 session_id 時退回一個共用的固定 key，會讓那個路徑在**所有**未來的
# session 都靜音（stamp 不過期），而畫面上跟「這次沒有要複查」一模一樣。
nosess() { printf '{"tool_input":{"file_path":"/r/CLAUDE.md"}}' | python3 "$HOOK" 2>&1; }
ok "缺 session_id 第一次仍注入"  'additionalContext' "$(nosess)"
ok "缺 session_id 不會就此靜音"  'additionalContext' "$(nosess)"

echo "── 壞輸入不得讓 hook 爆掉 ──"
# hook 失敗會干擾工具流程，所以任何形狀的輸入都必須 exit 0。
printf 'not json' | python3 "$HOOK" >/dev/null 2>&1
ok "非 JSON → exit 0" "0" "$?"
printf '' | python3 "$HOOK" >/dev/null 2>&1
ok "空 stdin → exit 0" "0" "$?"
printf '{"tool_input":"字串不是物件"}' | python3 "$HOOK" >/dev/null 2>&1
ok "tool_input 型別錯 → exit 0" "0" "$?"
printf '{"session_id":"s","tool_input":{"file_path":null}}' | python3 "$HOOK" >/dev/null 2>&1
ok "file_path 是 null → exit 0" "0" "$?"

echo "── 輸出必須是合法 JSON ──"
fresh
out=$(fire s /r/CLAUDE.md)
printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
ok "stdout 解析得動" "0" "$?"

newrepo() {
  d=$(mktemp -d "$SANDBOX/r.XXXXXX")
  ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
  printf '%s' "$d"
}

echo "── 安裝器 ──"
D=$(newrepo); cd "$D"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
ok "hook 檔已放置" "yes" "$([ -f .claude/hooks/claude-md-hygiene-hook.py ] && echo yes || echo no)"
ok "settings 註冊了" "claude-md-hygiene-hook.py" "$(cat .claude/settings.json)"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
n=$(python3 -c "import json;print(len(json.load(open('.claude/settings.json'))['hooks']['PostToolUse']))")
ok "重跑不重複註冊" "1" "$n"

echo "── 安裝器不得吃掉既有的 PostToolUse ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"prettier --write"}]}]},"env":{"KEEP":"1"}}
JSON
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
s=$(cat .claude/settings.json)
ok "既有 hook 還在" "prettier --write" "$s"
ok "既有其他設定還在" '"KEEP"' "$s"
ok "自己也註冊了" "claude-md-hygiene-hook.py" "$s"

echo "── 壞掉的 settings.json 不得被覆寫 ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
printf '{ 這不是 JSON' > .claude/settings.json
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
ok "原檔未被動到" "這不是 JSON" "$(cat .claude/settings.json)"

echo "── worktree 也要裝得起來 ──"
D=$(newrepo); cd "$D"; echo s > s.txt; git add -A
git -c core.hooksPath=/dev/null commit -qm i >/dev/null 2>&1
git worktree add -q "$D/../wt.$$" -b w >/dev/null 2>&1
out=$(cd "$D/../wt.$$" && sh "$SKILL/scripts/install.sh" 2>&1)
no "worktree 裡不該拒跑" "run from inside a git repo" "$out"

cd "$SANDBOX" || exit 1
echo
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

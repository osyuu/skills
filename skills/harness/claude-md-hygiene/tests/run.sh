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
# **crash 不得算通過。** `no` 斷言的是「輸出不含某字串」，而 traceback 也不含它——
# hook 一炸，所有 no 斷言就 vacuously pass，而那正是本 repo 出過的假測試的成因結構。
no() { case "$3" in *Traceback*)
    fail=$((fail+1)); printf '  FAIL  %s\n        hook 炸了（traceback）：%s\n' "$1" "$3" ;;
  *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }
# 數字用 `case` 的子字串比對時 10 會被當成含 0、11 含 1。目前值域只有 0/1，但釘死比較便宜。
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"
  else fail=$((fail+1)); printf '  FAIL  %s\n        期望：%s\n        實得：%s\n' "$1" "$2" "$3"; fi; }

fire() {  # fire <session> <path>
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$2" \
    | python3 "$HOOK" 2>&1
}
fresh() { rm -rf "$TMPDIR/claude-md-hygiene"; }

bash_name() {  # bash_name <session> <command> — 印出 hook 報的檔名（沒開火則印 QUIET）
  bash_fire "$1" "$2" | python3 -c 'import json,sys
raw=sys.stdin.read()
try: d=json.loads(raw)
except Exception: print("QUIET" if "additionalContext" not in raw else "PARSE-FAIL"); raise SystemExit
print(d["hookSpecificOutput"]["additionalContext"].split("常駐規範檔 ",1)[1].split("。",1)[0])'
}

bash_fire() {  # bash_fire <session> <command>
  python3 -c 'import json,sys; print(json.dumps({"session_id":sys.argv[1],"tool_name":"Bash","tool_input":{"command":sys.argv[2]}}))' "$1" "$2" \
    | python3 "$HOOK" 2>&1
}

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
# 相對與絕對寫法指同一個檔：不取絕對值的話，同一次編輯會被算成兩個 key 而開火兩次。
# pwd -P：$SANDBOX 在 macOS 是 /var/... 的 symlink，而 python 的 getcwd 回 /private/var/...。
# 用 logical 路徑會讓這條斷言測到「symlink 不解」而不是它要測的「相對 vs 絕對」。
PHYS=$(pwd -P)
fresh; ok "絕對路徑先開火"      'additionalContext' "$(fire s9 "$PHYS/CLAUDE.md")"
no "同 session 相對路徑不重複注入" 'additionalContext' "$(fire s9 CLAUDE.md)"
# stamp 寫不進去時 hook 不得炸掉——它守的只是「別重複吵」，不值得讓整個 PostToolUse 失敗。
RO="$SANDBOX/ro"; mkdir -p "$RO"; chmod 500 "$RO"
ro_out=$(TMPDIR="$RO" sh -c "printf '{\"session_id\":\"sro\",\"tool_input\":{\"file_path\":\"/r/CLAUDE.md\"}}' | python3 '$HOOK'" 2>&1)
ok "TMPDIR 唯讀時仍注入且不炸"  'additionalContext' "$ro_out"
no "TMPDIR 唯讀時沒有 traceback" 'Traceback'         "$ro_out"
chmod 700 "$RO"

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

echo "── Bash 改常駐檔也要開火（matcher 的 Write|Edit 配不到） ──"
fresh; ok "重導向覆寫"   'additionalContext' "$(bash_fire b1 'cat > CLAUDE.md <<EOF')"
fresh; ok "追加"         'additionalContext' "$(bash_fire b2 'printf x >> docs/AGENTS.md')"
fresh; ok "sed -i"       'additionalContext' "$(bash_fire b3 "sed -i '' s/a/b/ CLAUDE.md")"
fresh; ok "python 寫檔"  'additionalContext' "$(bash_fire b4 'pathlib.Path("CLAUDE.md").write_text(s)')"
fresh; ok "cp 覆蓋"      'additionalContext' "$(bash_fire b5 'cp /tmp/n.md CLAUDE.local.md')"

echo "── 只是提到檔名不得開火（誤報會讓人關掉整個 hook） ──"
fresh; no "cat"          'additionalContext' "$(bash_fire c1 'cat CLAUDE.md')"
fresh; no "grep"         'additionalContext' "$(bash_fire c2 'grep -n x CLAUDE.md README.md')"
fresh; no "git add"      'additionalContext' "$(bash_fire c3 'git add CLAUDE.md')"
fresh; no "管道到別的檔" 'additionalContext' "$(bash_fire c4 'cat CLAUDE.md | tee /tmp/backup.md')"
fresh; no "寫別的檔"     'additionalContext' "$(bash_fire c5 'echo hi > notes.md')"
# 實測誤報：commit 訊息裡提到常駐檔，同一次呼叫又寫了別的檔。判定若只要求
# 「檔名與 write_text 都在這包指令裡」就會中，而這個組合在寫 harness 的 repo 是常態。
# 指令用變數組，不要塞進單引號字串——單引號裡沒有跳脫，硬寫會讓整支測試語法錯。
Q=\'
c6="python3 -c \"pathlib.Path(${Q}notes.conf${Q}).write_text(s)\"
git commit -m \"docs: 說明 CLAUDE.md 的指標\""
fresh; no "訊息提到＋改別的檔" 'additionalContext' "$(bash_fire c6 "$c6")"

echo "── 誤報不得燒掉 Write/Edit 的 stamp（stamp key 必須分開）──"
# **路徑要用 python 的 cwd，不能用 $PWD。** macOS 的 mktemp 給的是 /var/...，
# 而 /var 是 /private/var 的 symlink；`os.path.abspath` 不解 symlink，於是
# shell 的 $PWD 與 hook 內算出來的絕對路徑天生就不同 key——兩邊本來就撞不到，
# 這條斷言會為了錯的理由通過。實測：用 $PWD 時把 stamp 前綴拿掉，測試照樣全綠。
PYCWD=$(python3 -c 'import os; print(os.getcwd())')
fresh
ok "Bash 寫 CLAUDE.md 開火"   'additionalContext' "$(bash_fire p1 'cat > CLAUDE.md <<EOF')"
ok "接著 Edit 同一檔仍開火"    'additionalContext' "$(fire p1 "$PYCWD/CLAUDE.md")"
fresh
ok "同一 Bash 指令只開一次"    'QUIET'             "$( bash_fire p2 'cat > CLAUDE.md <<EOF' >/dev/null; bash_name p2 'cat > CLAUDE.md <<EOF')"

echo "── 報的必須是被寫的那個檔，不是指令裡先出現的 ──"
fresh; eq "sed 樣式在前、目標在後" "AGENTS.md"        "$(bash_name n1 "sed -i '' 's/CLAUDE.md/X/' AGENTS.md")"
fresh; eq "sed 直接改"            "CLAUDE.md"        "$(bash_name n2 "sed -i '' s/a/b/ CLAUDE.md")"
fresh; eq "tee 目標"              ".claude.local.md" "$(bash_name n3 'tee .claude.local.md <<EOF')"
fresh; eq "重導向含路徑"          "AGENTS.md"        "$(bash_name n4 'cat > docs/AGENTS.md <<EOF')"
fresh; eq "cp 目的地"             "CLAUDE.local.md"  "$(bash_name n5 'cp /tmp/n.md CLAUDE.local.md')"

echo "── 讀取／備份／同名前後綴不得開火 ──"
fresh; no "cp 來源是常駐檔"   'additionalContext' "$(bash_fire q1 'cp CLAUDE.md /tmp/bak/')"
fresh; no "備份成 .bak"       'additionalContext' "$(bash_fire q2 'cp CLAUDE.md CLAUDE.md.bak')"
fresh; no "寫 .bak"           'additionalContext' "$(bash_fire q3 'cat x > CLAUDE.md.bak')"
fresh; no "同前綴的別的檔"    'additionalContext' "$(bash_fire q4 'cat > MY_CLAUDE.md <<EOF')"
fresh; no "python 讀"         'additionalContext' "$(bash_fire q5 'pathlib.Path("CLAUDE.md").read_text()')"
fresh; no "open 讀"           'additionalContext' "$(bash_fire q6 'open("CLAUDE.md").read()')"

echo "── 換行是分隔符，且 install 不是寫檔動詞 ──"
fresh; no "cp 後換行提到"     'additionalContext' "$(bash_fire r1 'cp a.md b.md
git add CLAUDE.md')"
fresh; no "mv 後換行提到"     'additionalContext' "$(bash_fire r2 'mv old.md new.md
grep -n hook CLAUDE.md')"
fresh; no "pip install"       'additionalContext' "$(bash_fire r3 'pip install -r req.txt
cat CLAUDE.md')"
fresh; no "tee 後換行提到"    'additionalContext' "$(bash_fire r4 'tee /tmp/x.md
grep CLAUDE.md')"

echo "── python 寫檔的其他慣用寫法 ──"
fresh; ok "f-string"          'additionalContext' "$(bash_fire s1 'open(f"{d}/CLAUDE.md","w").write(s)')"
fresh; ok "Path(d) / NAME"    'additionalContext' "$(bash_fire s2 '(Path(d) / "CLAUDE.md").write_text(s)')"
fresh; ok ".claude.local.md"  'additionalContext' "$(bash_fire s3 'cat > .claude.local.md <<EOF')"

echo "── 安裝器 ──"
D=$(newrepo); cd "$D"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
ok "hook 檔已放置" "yes" "$([ -f .claude/hooks/claude-md-hygiene-hook.py ] && echo yes || echo no)"
ok "settings 註冊了" "claude-md-hygiene-hook.py" "$(cat .claude/settings.json)"
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
n=$(python3 -c "import json;print(len(json.load(open('.claude/settings.json'))['hooks']['PostToolUse']))")
ok "重跑不重複註冊" "1" "$n"

echo "── 已裝的 repo 重跑要更新舊 matcher ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","command":"python3 .claude/hooks/claude-md-hygiene-hook.py"}]}]}}
JSON
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
m=$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][0]['matcher'])")
ok "舊 matcher 被更新" "Write|Edit|Bash" "$m"
n=$(python3 -c "import json;print(len(json.load(open('.claude/settings.json'))['hooks']['PostToolUse']))")
ok "沒有變成兩筆" "1" "$n"

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

echo "── 安裝器：update 路徑不得動到別人 ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"prettier --write"}]},{"matcher":"Write|Edit","hooks":[{"type":"command","command":"python3 .claude/hooks/claude-md-hygiene-hook.py"}]}]},"env":{"KEEP":"1"}}
JSON
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
s=$(cat .claude/settings.json)
ok "別人的 hook 還在"     "prettier --write" "$s"
ok "別人的設定還在"       '"KEEP"'           "$s"
eq "entry 數不變"         "2" "$(python3 -c "import json;print(len(json.load(open('.claude/settings.json'))['hooks']['PostToolUse']))")"
eq "別人的 matcher 沒被動" "Write" "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][0]['matcher'])")"
eq "自己的 matcher 有更新" "Write|Edit|Bash" "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][1]['matcher'])")"

echo "── 安裝器：同一筆 entry 與別人共用時不得改 matcher ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","command":"prettier --write"},{"type":"command","command":"python3 .claude/hooks/claude-md-hygiene-hook.py"}]}]}}
JSON
out=$(sh "$SKILL/scripts/install.sh" 2>&1)
eq "matcher 維持原狀"     "Write|Edit" "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][0]['matcher'])")"
ok "有講為什麼沒動"       "共用同一筆 entry" "$out"

echo "── 安裝器：比 MATCHER 更寬的設定不得被收窄 ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"python3 .claude/hooks/claude-md-hygiene-hook.py"}]}]}}
JSON
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
eq "\"*\" 保留" "*" "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][0]['matcher'])")"

echo "── 安裝器：身分判定不得用子字串 ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"echo \"python3 .claude/hooks/claude-md-hygiene-hook.py\""}]}]}}
JSON
sh "$SKILL/scripts/install.sh" >/dev/null 2>&1
eq "包裝過的那筆沒被動"   "Write" "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][0]['matcher'])")"
eq "真的 hook 有註冊"     "True" "$(python3 -c "
import json;es=json.load(open('.claude/settings.json'))['hooks']['PostToolUse']
print(any(h.get('command')=='python3 .claude/hooks/claude-md-hygiene-hook.py' for e in es for h in e.get('hooks',[])))")"

echo "── 安裝器：多筆自己的 entry 不得全改成同值 ──"
D=$(newrepo); cd "$D"; mkdir -p .claude
cat > .claude/settings.json <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","command":"python3 .claude/hooks/claude-md-hygiene-hook.py"}]},{"matcher":"Bash","hooks":[{"type":"command","command":"python3 .claude/hooks/claude-md-hygiene-hook.py"}]}]}}
JSON
out=$(sh "$SKILL/scripts/install.sh" 2>&1)
eq "第一筆沒被動" "Write|Edit" "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][0]['matcher'])")"
eq "第二筆沒被動" "Bash"       "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostToolUse'][1]['matcher'])")"
ok "有交還給人決定" "未自動更動 matcher" "$out"

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

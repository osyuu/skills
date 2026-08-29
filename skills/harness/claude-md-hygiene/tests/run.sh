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
# 一般的「輸出不得含某字串」，用在安裝器那類非 hook 的檢查。
no() { case "$3" in *Traceback*)
    fail=$((fail+1)); printf '  FAIL  %s\n        炸了（traceback）：%s\n' "$1" "$3" ;;
  *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }
# **hook 呼叫的「沒開火」要求的是乾淨**，不是「輸出不含某字串」——後者被任何崩潰
# 滿足：traceback 不含關鍵字，而 `SystemExit("msg")` 與 SyntaxError 連 traceback
# 都不印。那正是本 repo 出過兩次的假測試成因結構。判準是 stdout 空 + 離開碼 0 +
# stderr 空，三者缺一即紅。
quiet() { if [ "$2" = "$CLEAN" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"
  else fail=$((fail+1)); printf '  FAIL  %s\n        期望乾淨的沒開火，實得：%s\n' "$1" "$2"; fi; }
# 數字用 `case` 的子字串比對時 10 會被當成含 0、11 含 1。目前值域只有 0/1，但釘死比較便宜。
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"
  else fail=$((fail+1)); printf '  FAIL  %s\n        期望：%s\n        實得：%s\n' "$1" "$2" "$3"; fi; }

# **stdout / 離開碼 / stderr 三者必須分開。**
#   - `2>&1` 併流時，payload 從 stdout 改印 stderr 一樣通過所有斷言——而 Claude Code
#     只讀 stdout，那在產品上是 100% 靜默失效。所以 stderr 只回報「有沒有」，內容
#     不進比對字串。
#   - 只看輸出的話，`SystemExit("msg")` 與 SyntaxError 都不印 traceback，於是崩潰
#     跟「正確地沒開火」長得一樣。離開碼是唯一分得出來的東西。
_invoke() {  # _invoke <payload>
  _err="$TMPDIR/hook.err"
  _out=$(printf '%s' "$1" | python3 "$HOOK" 2>"$_err"); _rc=$?
  if [ -s "$_err" ]; then _e=yes; else _e=no; fi
  printf '%s\n#rc=%s#err=%s' "$_out" "$_rc" "$_e"
}
# 乾淨的「沒開火」長這樣：stdout 空、離開碼 0、stderr 空。
CLEAN="
#rc=0#err=no"

fire() {  # fire <session> <path>
  _invoke "$(printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$2")"
}
fresh() { rm -rf "$TMPDIR/claude-md-hygiene"; }

# 崩潰不得被判成 QUIET——那讓「同一指令只開一次」那條斷言在崩潰時 vacuously pass。
bash_name() {  # bash_name <session> <command>
  bash_fire "$1" "$2" | python3 -c 'import json,sys
raw = sys.stdin.read()
body, _, status = raw.rpartition("\n#rc=")
if status.strip() != "0#err=no" or not body.strip():
    print("QUIET" if (status.strip() == "0#err=no" and not body.strip()) else "CRASH:" + status.strip())
    raise SystemExit
try:
    d = json.loads(body)
except Exception:
    print("PARSE-FAIL"); raise SystemExit
print(d["hookSpecificOutput"]["additionalContext"].split("常駐規範檔 ", 1)[1].split("。", 1)[0])'
}

bash_fire() {  # bash_fire <session> <command>
  _invoke "$(python3 -c 'import json,sys; print(json.dumps({"session_id":sys.argv[1],"tool_name":"Bash","tool_input":{"command":sys.argv[2]}}))' "$1" "$2")"
}

echo "── 該注入的檔名 ──"
fresh; ok "CLAUDE.md"       'additionalContext' "$(fire s /r/CLAUDE.md)"
fresh; ok "AGENTS.md"       'additionalContext' "$(fire s /r/AGENTS.md)"
fresh; ok "CLAUDE.local.md" 'additionalContext' "$(fire s /r/CLAUDE.local.md)"
fresh; ok "子目錄的 CLAUDE.md" 'additionalContext' "$(fire s /r/docs/CLAUDE.md)"
fresh; ok "訊息帶檔名"       'CLAUDE.local.md'   "$(fire s /r/CLAUDE.local.md)"
fresh; ok "hookEventName 正確" 'PostToolUse'     "$(fire s /r/CLAUDE.md)"

echo "── 不該注入的 ──"
fresh; quiet "README.md" "$(fire s /r/README.md)"
fresh; quiet "claude.md 小寫" "$(fire s /r/claude.md)"
fresh; quiet "CLAUDE.md.bak" "$(fire s /r/CLAUDE.md.bak)"
fresh; no "沒有 file_path"   'additionalContext' "$(printf '{"session_id":"s"}' | python3 "$HOOK" 2>&1)"

echo "── 迴圈防護 ──"
fresh
ok "第一次注入"           'additionalContext' "$(fire s1 /r/CLAUDE.md)"
quiet "同 session 同檔不再注入" "$(fire s1 /r/CLAUDE.md)"
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
quiet "同 session 相對路徑不重複注入" "$(fire s9 CLAUDE.md)"
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
# `fire` 的輸出尾端帶著狀態後綴（見 `_invoke`），解析前要剝掉。
printf '%s' "${out%%$'\n'#rc=*}" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
eq "stdout 解析得動" "0" "$?"
eq "payload 走 stdout、離開碼 0、stderr 空" "0#err=no" "${out##*#rc=}"

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
fresh; quiet "cat" "$(bash_fire c1 'cat CLAUDE.md')"
fresh; quiet "grep" "$(bash_fire c2 'grep -n x CLAUDE.md README.md')"
fresh; quiet "git add" "$(bash_fire c3 'git add CLAUDE.md')"
fresh; quiet "管道到別的檔" "$(bash_fire c4 'cat CLAUDE.md | tee /tmp/backup.md')"
fresh; quiet "寫別的檔" "$(bash_fire c5 'echo hi > notes.md')"
# 實測誤報：commit 訊息裡提到常駐檔，同一次呼叫又寫了別的檔。判定若只要求
# 「檔名與 write_text 都在這包指令裡」就會中，而這個組合在寫 harness 的 repo 是常態。
# 指令用變數組，不要塞進單引號字串——單引號裡沒有跳脫，硬寫會讓整支測試語法錯。
Q=\'
c6="python3 -c \"pathlib.Path(${Q}notes.conf${Q}).write_text(s)\"
git commit -m \"docs: 說明 CLAUDE.md 的指標\""
fresh; quiet "訊息提到＋改別的檔" "$(bash_fire c6 "$c6")"

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
fresh; quiet "cp 來源是常駐檔" "$(bash_fire q1 'cp CLAUDE.md /tmp/bak/')"
fresh; quiet "備份成 .bak" "$(bash_fire q2 'cp CLAUDE.md CLAUDE.md.bak')"
fresh; quiet "寫 .bak" "$(bash_fire q3 'cat x > CLAUDE.md.bak')"
fresh; quiet "同前綴的別的檔" "$(bash_fire q4 'cat > MY_CLAUDE.md <<EOF')"
fresh; quiet "python 讀" "$(bash_fire q5 'pathlib.Path("CLAUDE.md").read_text()')"
fresh; quiet "open 讀" "$(bash_fire q6 'open("CLAUDE.md").read()')"

echo "── 換行是分隔符，且 install 不是寫檔動詞 ──"
fresh; quiet "cp 後換行提到" "$(bash_fire r1 'cp a.md b.md
git add CLAUDE.md')"
fresh; quiet "mv 後換行提到" "$(bash_fire r2 'mv old.md new.md
grep -n hook CLAUDE.md')"
fresh; quiet "pip install" "$(bash_fire r3 'pip install -r req.txt
cat CLAUDE.md')"
fresh; quiet "tee 後換行提到" "$(bash_fire r4 'tee /tmp/x.md
grep CLAUDE.md')"

echo "── 尾隨註解不得把取名帶偏 ──"
fresh; eq "sed + 尾隨註解" "CLAUDE.md" "$(bash_name c7 "sed -i '' s/a/b/ CLAUDE.md  # 同步 AGENTS.md")"
fresh; eq "cp + 尾隨註解"  "CLAUDE.md" "$(bash_name c8 'cp new.md CLAUDE.md  # 覆蓋 AGENTS.md')"

echo "── 迴圈防護按檔名，不按指令 ──"
fresh
ok "同檔第一個指令開火"   'additionalContext' "$(bash_fire k1 'cat > CLAUDE.md <<EOF')"
quiet "同檔換個寫法不再開" "$(bash_fire k1 "sed -i '' s/a/b/ CLAUDE.md")"
ok "別的檔仍開火"         'additionalContext' "$(bash_fire k1 'cat > AGENTS.md <<EOF')"

echo "── shell 的 <目錄>/ \"NAME\" 即使同段有 python 寫入動詞也不算 ──"
fresh; quiet "目錄後接檔名 + 別處有 write_text" \
  "$(bash_fire j1 'ls docs/ "CLAUDE.md"; python3 -c "Path(chr(111)).write_text(s)"')"

echo "── 前綴檔名不是本尊（左界；重導向以外的四條路原本全中）──"
fresh; quiet "sed 改前綴檔"    "$(bash_fire w1 "sed -i '' s/a/b/ MY_CLAUDE.md")"
fresh; quiet "cp 到前綴檔"     "$(bash_fire w2 'cp x.md MY_CLAUDE.md')"
fresh; quiet "tee 前綴檔"      "$(bash_fire w3 'tee TEAM_AGENTS.md <<EOF')"
fresh; quiet "python 寫前綴檔" "$(bash_fire w4 'Path("MY_CLAUDE.md").write_text(s)')"

echo "── cp/mv 的右界不只段尾 ──"
fresh; eq "加引號的目的地"   "CLAUDE.md" "$(bash_name x1 'cp new.md "CLAUDE.md"')"
fresh; eq "後接重導向"       "CLAUDE.md" "$(bash_name x2 'cp new.md CLAUDE.md 2>/dev/null')"
fresh; eq "後接註解"         "CLAUDE.md" "$(bash_name x3 'cp new.md CLAUDE.md  # 覆蓋')"

echo "── 指令名的左字界與引數位 ──"
fresh; quiet "tee 是 guarantee 的字尾" "$(bash_fire y1 'rg guarantee CLAUDE.md')"
fresh; quiet "cp 是 tcp 的字尾"        "$(bash_fire y2 'grep tcp CLAUDE.md')"
fresh; quiet "tee 後面必須是引數"      "$(bash_fire y3 'ls tee/ CLAUDE.md')"

echo "── 引號內的箭頭不是重導向 ──"
fresh; quiet "commit 訊息裡的 ->" "$(bash_fire z1 'git commit -m "docs: CLAUDE.md -> AGENTS.md"')"

echo "── open 的 mode 要綁在呼叫內 ──"
fresh; quiet "read 後接 .count(\"a\")" "$(bash_fire m1 'print(Path("CLAUDE.md").read_text().count("a"))')"
fresh; quiet "read 後接 .replace"        "$(bash_fire m2 'print(open("CLAUDE.md").read().replace("a","b"))')"
fresh; ok  "open 帶 wt 要開火" 'additionalContext' "$(bash_fire m3 'open("CLAUDE.md","wt").write(s)')"

echo "── 加引號的寫入目標（缺口是「有引號、無斜線」）──"
fresh; ok "重導向加引號"     'additionalContext' "$(bash_fire u1 'cat > "CLAUDE.md" <<EOF')"
fresh; ok "重導向單引號"     'additionalContext' "$(bash_fire u2 "cat > 'AGENTS.md' <<EOF")"
fresh; ok "cp 目的地加引號"  'additionalContext' "$(bash_fire u3 'cp /tmp/n.md "CLAUDE.md"')"
fresh; eq "加引號也報對檔名" "CLAUDE.md" "$(bash_name u4 'cat > "CLAUDE.md" <<EOF')"

echo "── shell 的 <目錄>/ \"NAME\" 不是 python 的 Path(d) / \"NAME\" ──"
fresh; quiet "grep 帶目錄與檔名" "$(bash_fire v1 'grep -rn "w" docs/ "CLAUDE.md"')"
fresh; quiet "ls 帶目錄與檔名"   "$(bash_fire v2 'ls -la docs/ "CLAUDE.md"')"

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

#!/bin/sh
# hooks/tests.sh 的突變測試：每一條注入都必須讓 tests.sh 變紅。
#
# 「16 條斷言」說不了「這 16 條都測得到東西」。不可證偽的斷言（比對永遠會出現、或
# 永遠不會出現的字串）跟真的斷言在畫面上同形——本 repo 有兩條這樣的斷言活了很久。
# 用法：sh hooks/mutants.sh
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HOOKS=$(cd "$(dirname "$0")" && pwd)
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
pass=0; fail=0

prep() { rm -rf "$SB/h"; mkdir -p "$SB/h"; cp "$HOOKS"/*.sh "$HOOKS"/*.conf "$SB/h/" 2>/dev/null; }

# 基準打在複本上：複本少了相依而本來就紅的話，每條注入都會免費「轉紅」。
prep
if ! sh "$SB/h/tests.sh" >/dev/null 2>&1; then
  echo "基準測試在複本裡就沒過，突變測試無意義。"; exit 2
fi

mut() { # mut <名稱> <檔名> <python 表達式：s 為原始內容>
  prep
  python3 -c "
import pathlib,sys
p=pathlib.Path('$SB/h/$2'); s=p.read_text()
n=($3)
if n==s: print('NOCHANGE'); sys.exit(9)
p.write_text(n)" >/dev/null 2>&1
  case $? in
    9) fail=$((fail+1)); printf '  FAIL  %s\n        注入沒有改到任何東西（pattern 過期了？）\n' "$1"; return ;;
    0) ;;
    *) fail=$((fail+1)); printf '  FAIL  %s\n        注入腳本自己錯了\n' "$1"; return ;;
  esac
  if sh "$SB/h/tests.sh" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL  %s\n        測試仍全綠 → 這段 code 沒有守護者\n' "$1"
  else
    pass=$((pass+1)); printf '  ok    %s\n' "$1"
  fi
}

echo "── hooks 的突變 ──"
S=skill-tests.sh
M=marketplace-sync.sh
Y=sync-check.sh
C=comment-budget-check.sh

mut "路徑正則掉一層（回到扁平）" "$S" "s.replace('^skills/([^/]+/)?[^/]+/(scripts|assets|tests)/', '^skills/[^/]+/(scripts|assets|tests)/')"
mut "路徑正則只吃分類"          "$S" "s.replace('^skills/([^/]+/)?[^/]+/(scripts|assets|tests)/', '^skills/[^/]+/[^/]+/(scripts|assets|tests)/')"
mut "測試沒過時不出聲"          "$S" "s.replace('的測試沒過', '（靜音）')"
mut "額外測試不跑"              "$S" "s.replace('for x in \"\$d\"/tests/*.sh; do', 'for x in ; do')"
mut "額外測試不 </dev/null"      "$S" "s.replace('sh \"\$x\" </dev/null', 'sh \"\$x\"')"
mut "run.sh 不 </dev/null"       "$S" "s.replace('sh \"\$t\" </dev/null', 'sh \"\$t\"')"
mut "認不出摘要時留白"          "$S" "s.replace('[ -n \"\$xsum\" ] || xsum=\"(認不出摘要行)\"', ':')"
mut "登錄比對用 grep -q"        "$M" "s.replace('grep -qF', 'grep -q')"
mut "新增偵測掉一層"            "$M" "s.replace('^skills/([^/]+/)?[^/]+/SKILL', '^skills/[^/]+/SKILL')"
mut "未登錄時不出聲"            "$M" "s.replace('\"\$MF\" || {', '\"\$MF\" && {')"
mut "同步比對永遠通過"          "$Y" "s.replace('cmp -s \"\$live\" \"\$src\" ||', 'true ||')"
mut "同步比對無條件出聲"        "$Y" "s.replace('cmp -s \"\$live\" \"\$src\" ||', 'false ||')"
mut "使用者層的比對整段拿掉"    "$Y" "s[:s.index('UPAIRS=')] + 'exit 0\\n'"
mut "使用者層比對永遠通過"      "$Y" "s.replace('cmp -s \"\$UROOT/\$live\" \"\$src\" ||', 'true ||')"
mut "沒裝也當成漂移"            "$Y" "s.replace('[ -f \"\$UROOT/\$live\" ] || continue', ':')"
mut "使用者層的反查不做"        "$Y" "s.replace('for live in \"\$UROOT\"/hooks/*; do', 'for live in ; do')"
mut "反查的比對不用 -F"         "$Y" "s.replace('grep -qF \"hooks/', 'grep -q \"hooks/')"
mut "來源不見了那條靜音"        "$Y" "s.replace('裝著,但來源 %s 不見了', '(靜音)')"
mut "HOME 未設時整段中止"       "$Y" "s.replace('\${HOME:-/nonexistent}', '\$HOME')"
mut "不存在時當成一致"          "$Y" "s.replace('if [ ! -f \"\$live\" ] || [ ! -f \"\$src\" ]; then', 'if false; then')"
mut "註解區塊門檻失效"          "$C" "s.replace('[ \"\$MAXRUN\" -ge \"\$BLOCK_MAX\" ]', 'false')"
mut "註解佔比門檻失效"          "$C" "s.replace('[ \"\$PCT\" -gt \"\$RATIO_MAX\" ]', 'false')"
mut "註解檢查無條件開火"        "$C" "s.replace('[ \"\$MAXRUN\" -ge \"\$BLOCK_MAX\" ]', 'true')"
mut "路徑過濾拿掉（對任何檔開火）" "$S" "s.replace(\"grep -E '^skills/([^/]+/)?[^/]+/(scripts|assets|tests)/'\", 'cat')"
mut "不帶出失敗那幾行"          "$S" "s.replace(\"printf '%s\\\\n' \\\"\$out\\\" | grep -E '✗|FAIL' | head -5 | sed 's/^/    /'\", ':')"
mut "mutants 不 </dev/null"      "$S" "s.replace('sh \"\$m\" </dev/null', 'sh \"\$m\"')"
mut "PAIRS 反查拿掉"            "$Y" "s.replace('for live in hooks/*.sh .claude/hooks/*; do', 'for live in ; do')"
mut "不一致時不出聲"            "$Y" "s.replace('與來源 %s 不一致', '（靜音）')"

echo
printf '%s 條注入轉紅，%s 條沒有\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

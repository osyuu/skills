#!/bin/sh
# 突變測試：每一條注入都必須讓 tests/run.sh 變紅。
#
# 「每條斷言都能被證偽」是紀律，紀律擋不住人——同一個疏漏（改了行為沒補測試）在
# 這個 repo 連犯三次。寫成跑得起來的清單就不必再靠記得：新增行為時在下面加一條，
# 它若沒讓測試變紅，那段 code 就是裸的。
#
# 用法：sh tests/mutants.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
NAME=$(basename "$SKILL")
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
pass=0; fail=0

# 先確認基準是綠的——基準本來就紅的話，每個注入都會「成功」變紅而證明不了任何事。
if ! sh "$SKILL/tests/run.sh" >/dev/null 2>&1; then
  echo "基準測試沒過，突變測試無意義。先修 tests/run.sh。"; exit 2
fi

mut() { # mut <名稱> <相對檔案> <python 表達式：s 為原始內容，回傳新內容>
  rm -rf "$SB/w"; cp -R "$SKILL" "$SB/w"
  python3 -c "
import pathlib,sys
p=pathlib.Path('$SB/w/$2'); s=p.read_text()
n=($3)
if n==s: print('NOCHANGE'); sys.exit(9)
p.write_text(n)" >/dev/null 2>&1
  case $? in
    9) fail=$((fail+1)); printf '  FAIL  %s\n        注入沒有改到任何東西（pattern 過期了？）\n' "$1"; return ;;
    0) ;;
    *) fail=$((fail+1)); printf '  FAIL  %s\n        注入腳本自己錯了\n' "$1"; return ;;
  esac
  if sh "$SB/w/tests/run.sh" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL  %s\n        測試仍全綠 → 這段 code 沒有守護者\n' "$1"
  else
    pass=$((pass+1)); printf '  ok    %s\n' "$1"
  fi
}

echo "── ${NAME} 的突變 ──"
H=assets/claude-md-hygiene-hook.py
I=scripts/install.sh
mut "WATCHED 少一個檔名"        "$H" "s.replace('\"AGENTS.md\", ', '')"
mut "拿掉迴圈防護"              "$H" "s.replace('if stamp.exists():', 'if False:')"
mut "拿掉 tool_input 型別檢查"   "$H" "s.replace('if not isinstance(tool_input, dict):', 'if False:')"
mut "改成比對完整路徑"          "$H" "s.replace('name = os.path.basename(path)', 'name = path')"
mut "hookEventName 打錯"       "$H" "s.replace('\"hookEventName\": \"PostToolUse\"', '\"hookEventName\": \"Zz\"')"
mut "安裝器覆蓋既有 PostToolUse" "$I" "s.replace('entries = d.setdefault(\"hooks\", {}).setdefault(\"PostToolUse\", [])', 'entries = []\n    d.setdefault(\"hooks\", {})[\"PostToolUse\"] = entries')"
mut "安裝器不寫 hook 檔"        "$I" "s.replace('cp \"\$ASSETS/claude-md-hygiene-hook.py\"', ': \"\$ASSETS/claude-md-hygiene-hook.py\"')"

echo
printf '%s 條注入轉紅，%s 條沒有\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

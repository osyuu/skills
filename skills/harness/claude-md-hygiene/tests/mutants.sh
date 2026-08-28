#!/bin/sh
# 突變測試：每一條注入都必須讓 tests/run.sh 變紅。
#
# 「每條斷言都能被證偽」是紀律，紀律擋不住人——同一個疏漏（改了行為沒補測試）在
# 這個 repo 連犯三次。寫成跑得起來的清單就不必再靠記得：新增行為時在下面加一條，
# 它若沒讓測試變紅，那段 code 就是裸的。
#
# 用法：sh tests/mutants.sh
set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
NAME=$(basename "$SKILL")
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
pass=0; fail=0

# 每條注入各跑各的沙箱、零共享,所以可以並行。序列跑是 O(注入數 × 完整套件)。
# 結果寫進檔、最後依序讀出來印:計數器在子 shell 裡加不到父層,而輸出順序要穩定才讀得懂。
JOBS=${MUTANT_JOBS:-14}
seq_n=0

prep() { rm -rf "$1"; mkdir -p "$1"; cp -R "$SKILL" "$1/w"; }

# 基準要打在**複本**上——注入跑的是複本，而複本可能因為少了相依，在零注入時
# 就已經是紅的。基準打在原地時那些注入全部免費「轉紅」，印出來的畫面跟真的有
# 覆蓋一模一樣。踩過：sdd-harness-init 整支就是這樣空轉的。
prep "$SB/base"
if ! sh "$SB/base/w/tests/run.sh" >/dev/null 2>&1; then
  echo "基準測試在複本裡就沒過，突變測試無意義（複本少了什麼相依？）。"; exit 2
fi

_mut_one() { # $1=名稱 $2=序號 $3=相對檔案 $4=表達式
  d="$SB/j$2"
  prep "$d"
  python3 -c "
import pathlib,sys
p=pathlib.Path('$d/w/$3'); s=p.read_text()
n=($4)
if n==s: print('NOCHANGE'); sys.exit(9)
p.write_text(n)" >/dev/null 2>&1
  case $? in
    9) printf 'FAIL\t%s\t注入沒有改到任何東西（pattern 過期了？）\n' "$1" > "$SB/r$2"; return ;;
    0) ;;
    *) printf 'FAIL\t%s\t注入腳本自己錯了\n' "$1" > "$SB/r$2"; return ;;
  esac
  if sh "$d/w/tests/run.sh" >/dev/null 2>&1; then
    printf 'FAIL\t%s\t測試仍全綠 → 這段 code 沒有守護者\n' "$1" > "$SB/r$2"
  else
    printf 'ok\t%s\t\n' "$1" > "$SB/r$2"
  fi
  rm -rf "$d"
}

mut() { # mut <名稱> <相對檔案> <python 表達式：s 為原始內容，回傳新內容>
  seq_n=$((seq_n + 1))
  _mut_one "$1" "$seq_n" "$2" "$3" &
  [ $((seq_n % JOBS)) -eq 0 ] && wait
  return 0
}

echo "── ${NAME} 的突變 ──"
H=assets/claude-md-hygiene-hook.py
I=scripts/install.sh
mut "WATCHED 少一個檔名"        "$H" "s.replace('\"AGENTS.md\", ', '')"
mut "拿掉迴圈防護"              "$H" "s.replace('if stamp.exists():', 'if False:')"
mut "缺 session 退回固定 key"    "$H" "s.replace('if isinstance(session, str) and session:', 'session = session or \\'nosession\\'\\n    if True:')"
mut "路徑不取絕對值"        "$H" "s.replace('os.path.abspath(path)', 'path')"
mut "stamp I/O 不包 try"     "$H" "s.replace('        try:\n            if stamp.exists():\n                return 0\n            stamp.parent.mkdir(parents=True, exist_ok=True)\n            stamp.touch()\n        except OSError:\n            pass\n', '        if stamp.exists():\n            return 0\n        stamp.parent.mkdir(parents=True, exist_ok=True)\n        stamp.touch()\n')"
mut "拿掉 tool_input 型別檢查"   "$H" "s.replace('if not isinstance(tool_input, dict):', 'if False:')"
mut "改成比對完整路徑"          "$H" "s.replace('name = os.path.basename(path)', 'name = path')"
mut "hookEventName 打錯"       "$H" "s.replace('\"hookEventName\": \"PostToolUse\"', '\"hookEventName\": \"Zz\"')"
mut "安裝器覆蓋既有 PostToolUse" "$I" "s.replace('entries = d.setdefault(\"hooks\", {}).setdefault(\"PostToolUse\", [])', 'entries = []\n    d.setdefault(\"hooks\", {})[\"PostToolUse\"] = entries')"
mut "安裝器不寫 hook 檔"        "$I" "s.replace('cp \"\$ASSETS/claude-md-hygiene-hook.py\"', ': \"\$ASSETS/claude-md-hygiene-hook.py\"')"

wait
i=0
while [ "$i" -lt "$seq_n" ]; do
  i=$((i + 1))
  # **IFS 要真的 tab**:`IFS='\t'` 在 POSIX sh 是反斜線與 t 兩個字元,讀出來全空。
  IFS="$(printf '\t')" read -r verdict name why < "$SB/r$i"
  if [ "$verdict" = ok ]; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1)); printf '  FAIL  %s\n        %s\n' "$name" "$why"
  fi
done

echo
printf '%s 條注入轉紅，%s 條沒有\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

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

prep() { # 注入前的乾淨複本。兄弟 skill 一起複製過去：run.sh 用
         # $SKILL/../comment-budget 找它，複本裡沒有的話那些斷言會空轉。
  rm -rf "$SB/w" "$SB/comment-budget"
  cp -R "$SKILL" "$SB/w"
  cp -R "$SKILL/../comment-budget" "$SB/comment-budget"
}

# 基準要打在**複本**上——注入跑的是複本，而複本可能因為少了相依，在零注入時
# 就已經是紅的。基準打在原地時那些注入全部免費「轉紅」，印出來的畫面跟真的有
# 覆蓋一模一樣。踩過：sdd-harness-init 整支就是這樣空轉的。
prep
if ! sh "$SB/w/tests/run.sh" >/dev/null 2>&1; then
  echo "基準測試在複本裡就沒過，突變測試無意義（複本少了什麼相依？）。"; exit 2
fi

mut() { # mut <名稱> <相對檔案> <python 表達式：s 為原始內容，回傳新內容>
  prep
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
I=scripts/install.sh
mut "不建 DECISIONS.md"    "$I" "s.replace('cp \"\$ASSETS/DECISIONS.template.md\" \"\$LOG_PATH\"', ': \"\$ASSETS/DECISIONS.template.md\"')"
mut "覆蓋既有 DECISIONS.md" "$I" "s.replace('if [ -f \"\$LOG_PATH\" ]; then', 'if false; then')"
mut "拿掉 worktree 保護" "$I" "s.replace('elif [ \"\$(git rev-parse --git-dir)\" != \"\$(git rev-parse --git-common-dir)\" ] &&', 'elif false && [ \"\$(git rev-parse --git-dir)\" != \"\$(git rev-parse --git-common-dir)\" ] &&')"


echo
printf '%s 條注入轉紅，%s 條沒有\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

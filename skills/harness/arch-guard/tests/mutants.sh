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

prep() { rm -rf "$SB/w"; cp -R "$SKILL" "$SB/w"; }

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
mut "改回 [ -d .git ]"     "$I" "s.replace('git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||', '[ -d .git ] ||')"
mut "模板的 ROOT 沒有出廠預設值" "assets/arch-layers.conf.template" "s.replace('ROOT='+chr(34)+'<TODO-source-root>'+chr(34), 'ROOT='+chr(34)+'lib'+chr(34))"
mut "checker 對未填的 TODO 出聲" "assets/arch-guard-check.sh" "s.replace('TODO'+chr(34)+'*)', 'NEVERMATCH'+chr(34)+'*)')"
mut "warn 模式不會回非零"        "assets/arch-guard-check.sh" "s.replace('[ \"\$mode\" = \"strict\" ] && exit 1', 'true')"
mut "strict 模式會回非零"        "assets/arch-guard-check.sh" "s.replace('[ \"\$mode\" = \"strict\" ] && exit 1', 'false')"
mut "install 插入的呼叫帶 || true" "scripts/install.sh" "s.replace('arch-guard-check.sh\" || true', 'arch-guard-check.sh\"')"
mut "整個閘拿掉"                  "assets/arch-guard-check.sh" "s.replace('if [ \"\$nlayers\" -lt 2 ] &&', 'if false &&')"
mut "閘漏掉 PARTITIONED 半邊"     "assets/arch-guard-check.sh" "s.replace('[ -z \"\$(printf \'%s\' \"\${PARTITIONED:-}\" | tr -d \'[:space:]\')\" ] &&', 'true &&')"
mut "只有一層當成有規則"          "assets/arch-guard-check.sh" "s.replace('-lt 2 ] &&', '-lt 1 ] &&')"
mut "層數不做字詞切分"            "assets/arch-guard-check.sh" "s.replace('for _l in \${LAYERS:-}; do', 'for _l in \"\${LAYERS:-}\"; do')"
mut "註解判定的 pattern"          "assets/arch-guard-check.sh" "s.replace(chr(39)+'^\\\\(#.*\\\\)\\\\?\$'+chr(39), chr(39)+'^\$'+chr(39))"
mut "縮排的註解不算註解"          "assets/arch-guard-check.sh" "s.replace(chr(39)+'s/^[[:space:]]*//;s/[[:space:]]*\$//'+chr(39)+' | grep -cv', chr(39)+'s/x/x/'+chr(39)+' | grep -cv')"
mut "閘的訊息走 stdout"           "assets/arch-guard-check.sh" "s.replace('這次檢查等於沒跑\" >&2\n  [ \"\$mode\" = \"warn\" ] || exit 1\n  exit 0\nfi\n\n# ROOT', '這次檢查等於沒跑\"\n  [ \"\$mode\" = \"warn\" ] || exit 1\n  exit 0\nfi\n\n# ROOT')"
mut "拿掉 ROOT 存在檢查"          "assets/arch-guard-check.sh" "s.replace('if [ ! -d \"\$ROOT\" ]; then', 'if false; then')"
mut "pattern 欄空靜默跳過"        "assets/arch-guard-check.sh" "s.replace('printf \"\${YEL}⚠  arch-guard config：pattern 欄是空的，這條規則不會跑\${RST}', 'true \"')"
mut "拿掉 marker 感知"     "$I" "s.replace('/^[[:space:]]*#[[:space:]]*>>>/ { d++; if (d == 1) bs = NR; next }', '')"
mut "巢狀不計深度"        "$I" "s.replace('{ if (d > 0) d--; if (d == 0) bs = 0; next }', '{ bs = 0; next }')"
mut "marker 錨死在第 0 欄"  "$I" "s.replace('/^[[:space:]]*#[[:space:]]*>>>/', '/^#[[:space:]]*>>>/').replace('/^[[:space:]]*#[[:space:]]*<<</', '/^#[[:space:]]*<<</')"
mut "檔尾換行算錯"        "$I" "s.replace('\$(awk \'END{print NR}\' hooks/pre-commit)', '\$(wc -l < hooks/pre-commit)')"
mut "無條件覆寫 hooksPath"  "$I" "s.replace('if [ -n \"\$EXISTING_HP\" ] && [ \"\$EXISTING_HP\" != \"hooks\" ]; then', 'if false; then')"
mut "拿掉 worktree 保護"    "$I" "s.replace('elif [ \"\$GITDIR\" != \"\$COMMON\" ] && [ ! -d', 'elif false && [ ! -d')"

echo
printf '%s 條注入轉紅，%s 條沒有\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

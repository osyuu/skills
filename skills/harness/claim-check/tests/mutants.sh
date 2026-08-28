#!/bin/sh
# tests/run.sh 的突變測試：每一條注入都必須讓 run.sh 變紅。
#
# 「42 passed」說不了「這 42 條都測得到東西」。這套測試曾經**一條誤中反例都沒有**
# ——每條都在問「該認得的認不認得」，沒有一條問「不該認得的會不會誤認」——
# 於是兩個 P0(RE_TEST 缺詞界、NAMED 截斷)從中溜過去，而畫面上一直是全綠。
# 用法：sh tests/mutants.sh
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
pass=0; fail=0

# scripts 也要帶：run.sh 有一整段在測 install.sh，少了它基準就紅，
# 而基準紅的話每條注入都會免費「轉紅」，整份 mutation 測試變成假綠。
prep() { rm -rf "$SB/s"; mkdir -p "$SB/s"; cp -R "$SKILL/assets" "$SKILL/tests" "$SKILL/scripts" "$SB/s/"; }

# 基準打在複本上：複本少了相依而本來就紅的話，每條注入都會免費「轉紅」。
prep
if ! sh "$SB/s/tests/run.sh" >/dev/null 2>&1; then
  echo "基準測試在複本裡就沒過，突變測試無意義。"; exit 2
fi

mut() { # mut <名稱> <python 表達式：s 為 claim-check.py 內容>
  prep
  python3 -c "
import pathlib,sys
p=pathlib.Path('$SB/s/assets/claim-check.py'); s=p.read_text()
n=($2)
if n==s: print('NOCHANGE'); sys.exit(9)
p.write_text(n)" >/dev/null 2>&1
  case $? in
    9) fail=$((fail+1)); printf '  FAIL  %s\n        注入沒有改到任何東西（pattern 過期了？）\n' "$1"; return ;;
    0) ;;
    *) fail=$((fail+1)); printf '  FAIL  %s\n        注入腳本自己錯了\n' "$1"; return ;;
  esac
  if sh "$SB/s/tests/run.sh" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL  %s\n        測試仍全綠 → 這段 code 沒有守護者\n' "$1"
  else
    pass=$((pass+1)); printf '  ok    %s\n' "$1"
  fi
}

echo "── 詞界（少了它，git add 一列 .dart 就被當成跑過測試）──"
mut "RE_TEST 的 lookbehind"      "s.replace(r'(?<![\\w.])(?:flutter|dart|very_good)\\s+test\\b', r'flutter\\s+test|dart\\s+test')"
mut "RE_BUILD 的 lookbehind"     "s.replace(r'(?<![\\w.])(?:xcodebuild', r'(?:xcodebuild')"
mut "RE_BUILD 的尾端否定"        "s.replace(r'dart\\s+compile)(?![\\w.])', r'dart\\s+compile)\\b')"
mut "codegen 的詞界"             "s.replace(r'(?<![\\w.])dart\\s+(?:format|fix)\\b', r'dart\\s+format|dart\\s+fix')"

echo "── 認得工具鏈（少了它，這條規則在 Flutter 專案恆開火、毫無資訊）──"
mut "RE_TEST 認得 flutter/dart"  "s.replace(r'|(?<![\\w.])(?:flutter|dart|very_good)\\s+test\\b', '')"
mut "RE_BASH_MUTATE 認得 .dart"  "s.replace('(swift|dart|py|sh', '(swift|py|sh')"

echo "── NAMED（截斷後會被同回合任何同尾檔涵蓋掉）──"
mut "NAMED 吃多重副檔名"         "s.replace(r'(\\b[\\w][\\w./-]*\\.(?:swift|dart)\\b)', r'(\\b[\\w/]+\\.(?:swift|dart)\\b)')"

echo "── 完整指令形式（只寫 build_runner / slang 的話，grep 它們也算數）──"
mut "build_runner 要接 build"    "s.replace(r'build_runner\\s+(?:build|watch)', 'build_runner')"
mut "slang 要接在 dart run 後"   "s.replace(r'(?:dart|flutter)\\s+(?:pub\\s+)?run\\s+slang', 'slang')"
mut "format/fix 排除唯讀形式"    "s[:s.index(chr(34)+'(?![^')] + s[s.index('--dry-run))'+chr(34))+len('--dry-run))'+chr(34)):]"

echo "── conf 覆寫（機制壞掉時,補進 conf 的生態會靜默失效）──"
mut "conf 的值有被附加上去"      "s.replace('extra = CONF.get(key, \"\").strip()', 'extra = \"\"')"
mut "repo 層的 conf 有被讀到"    "s.replace('Path(\"hooks/claim-check.conf\"),', '')"

echo "── 規則本體 ──"
mut "正確性宣稱規則整條移除"     "s[:s.index('    # 今天四次真陽性')] + s[s.index('    (\"注入故障\",'):]"
mut "測試規則的新鮮度判定"       "s.replace('return ix[kind] >= 0 and ix[kind] >= ix[\"edit\"]', 'return ix[kind] >= 0')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

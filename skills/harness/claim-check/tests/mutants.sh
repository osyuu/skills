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

# checker 會讀使用者層的 `~/.claude/claim-check.conf`,而 skill 自己就在叫使用者去填它。
# 不隔離的話「沒有 conf 時認不得 X」那幾條會在**填過 conf 的機器上**紅,而在這台
# 剛好全綠只因為那份 conf 現在是空的。**跟 GIT_DIR 是同一個形狀,換了個變數名。**
CLAIM_CHECK_HOME=$(mktemp -d)/.claude; mkdir -p "$CLAIM_CHECK_HOME"; export CLAIM_CHECK_HOME

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
pass=0; fail=0

# scripts 也要帶：run.sh 有一整段在測 install.sh，少了它基準就紅，
# 而基準紅的話每條注入都會免費「轉紅」，整份 mutation 測試變成假綠。
# 每條注入各跑各的複本、零共享,所以可以並行。序列跑是 O(注入數 × 完整套件),
# 而這份的耗時幾乎全是 python 進程啟動——並行拿得回大部分。
# 結果寫進檔再依序印:計數器在子 shell 裡加不到父層,而輸出順序要穩定才讀得懂。
JOBS=${MUTANT_JOBS:-14}
seq_n=0

# scripts 也要帶：run.sh 有一整段在測 install.sh，少了它基準就紅，
# 而基準紅的話每條注入都會免費「轉紅」，整份 mutation 測試變成假綠。
prep() { rm -rf "$1"; mkdir -p "$1"; cp -R "$SKILL/assets" "$SKILL/tests" "$SKILL/scripts" "$1/"; }

# 基準打在複本上：複本少了相依而本來就紅的話，每條注入都會免費「轉紅」。
prep "$SB/base"
if ! sh "$SB/base/tests/run.sh" >/dev/null 2>&1; then
  echo "基準測試在複本裡就沒過，突變測試無意義。"; exit 2
fi

_mut_one() { # $1=名稱 $2=序號 $3=表達式 $4=目標檔
  # 參數順序與其餘五支一致(名稱在前)。指紋工具靠 $1 取名稱,兩套順序會讓它只對一半可用。
  d="$SB/j$2"
  prep "$d"
  python3 -c "
import pathlib,sys
p=pathlib.Path('$d/$4'); s=p.read_text()
n=($3)
if n==s: print('NOCHANGE'); sys.exit(9)
p.write_text(n)" >/dev/null 2>&1
  case $? in
    9) printf 'FAIL\t%s\t注入沒有改到任何東西（pattern 過期了？）\n' "$1" > "$SB/r$2"; return ;;
    0) ;;
    *) printf 'FAIL\t%s\t注入腳本自己錯了\n' "$1" > "$SB/r$2"; return ;;
  esac
  if sh "$d/tests/run.sh" >/dev/null 2>&1; then
    printf 'FAIL\t%s\t測試仍全綠 → 這段 code 沒有守護者\n' "$1" > "$SB/r$2"
  else
    printf 'ok\t%s\t\n' "$1" > "$SB/r$2"
  fi
  rm -rf "$d"
}

# 區塊標題也要排進佇列。直接 echo 的話它們會在 job 還在跑時就全部印完,
# 而結果在最後才依序出來——標題與它底下那幾條就對不起來了。
sec() { seq_n=$((seq_n + 1)); printf 'sec\t%s\t\n' "$1" > "$SB/r$seq_n"; }

mut() { # mut <名稱> <python 表達式：s 為目標檔內容> [目標檔，預設 assets/claim-check.py]
  seq_n=$((seq_n + 1))
  printf '%s\n' "$1" >> "$SB/names"
  _mut_one "$1" "$seq_n" "$2" "${3:-assets/claim-check.py}" &
  [ $((seq_n % JOBS)) -eq 0 ] && wait
  return 0
}

sec "── 詞界（少了它，git add 一列 .dart 就被當成跑過測試）──"
mut "RE_TEST 的 lookbehind"      "s.replace(r'(?<![\\w.])(?:flutter|dart|very_good)\\s+test\\b', r'flutter\\s+test|dart\\s+test')"
mut "RE_BUILD 的 lookbehind"     "s.replace(r'(?<![\\w.])(?:xcodebuild', r'(?:xcodebuild')"
mut "RE_BUILD 的尾端否定"        "s.replace(r'dart\\s+compile)(?![\\w.])', r'dart\\s+compile)\\b')"
mut "codegen 的詞界"             "s.replace(r'(?<![\\w.])dart\\s+(?:format|fix)\\b', r'dart\\s+format|dart\\s+fix')"

sec "── 認得工具鏈（少了它，這條規則在 Flutter 專案恆開火、毫無資訊）──"
mut "RE_TEST 認得 flutter/dart"  "s.replace(r'|(?<![\\w.])(?:flutter|dart|very_good)\\s+test\\b', '')"
mut "RE_BASH_MUTATE 認得 .dart"  "s.replace('(swift|dart|py|sh', '(swift|py|sh')"

sec "── NAMED（截斷後會被同回合任何同尾檔涵蓋掉）──"
mut "NAMED 吃多重副檔名"         "s.replace(r'(\\b[\\w][\\w./-]*\\.(?:', r'(\\b[\\w/]+\\.(?:')"

sec "── 完整指令形式（只寫 build_runner / slang 的話，grep 它們也算數）──"
mut "build_runner 要接 build"    "s.replace(r'build_runner\\s+(?:build|watch)', 'build_runner')"
mut "slang 要接在 dart run 後"   "s.replace(r'(?:dart|flutter)\\s+(?:pub\\s+)?run\\s+slang', 'slang')"
mut "format/fix 排除唯讀形式"    "s[:s.index(chr(34)+'(?![^')] + s[s.index('--dry-run))'+chr(34))+len('--dry-run))'+chr(34)):]"

sec "── conf 覆寫（機制壞掉時,補進 conf 的生態會靜默失效）──"
mut "conf 的值有被附加上去"      "s.replace('extra = CONF.get(key, \"\").strip()', 'extra = \"\"')"
mut "repo 層的 conf 有被讀到"    "s.replace('Path(\"hooks/claim-check.conf\"),', '')"

sec "── 英文詞表（只認一種語言＝另一種語言的 session 恆不開火）──"
mut "測試的英文說法"             "s.replace('tests? (all )?(pass|passed|passes|passing)', 'NEVERMATCHZZ')"
mut "背景的英文說法"             "s.replace(r'|(?i:\\b(still|currently) running\\b)', '')"
mut "commit 的英文說法"          "s.replace('(committed|merged) (it|them|this|that', '(NEVERZZ) (it|them|this|that')"
mut "正確性宣稱的英文說法"       "s.replace(r'|(?i:\\b(safe|ready|good) to merge\\b)', '')"
mut "commit 英文要帶受詞"        "s.replace('(it|them|this|that', '(|it|them|this|that')"
mut "背景英文要帶狀態詞"         "s.replace(r'(?i:\\b(still|currently) running\\b)', r'(?i:\\brunning\\b)')"
mut "CHALLENGE 認得英文"         "s.replace(r'|(?i:\\bare you sure\\b)', '')"
mut "CHALLENGE 不收裸的 why"     "s.replace(r'|(?i:\\bare you sure\\b)', r'|(?i:\\bwhy\\b)')"
mut "NAMED 認得 .go"             "s.replace('swift|dart|py|ts|tsx|js|jsx|go', 'swift|dart')"

sec "── 宣稱 vs 提到（沒有這層，英文那半十種形狀十中十誤中）──"
mut "hedge 過濾整層拿掉"        "s.replace('if _is_claim(payload, m.start())', 'if True')"
mut "hedge 只回看到子句邊界"    "s.replace('for m in CLAUSE_END.finditer(text[sent_start:at]):', 'for m in []:')"
mut "疑問句不算 hedge"          "s.replace('.rstrip().endswith((', '.rstrip().startswith((')"

sec "── 「帶受詞或帶狀態詞」——明著宣告過的不變式 ──"
mut "fixed 要帶受詞"            "s.replace(r'|(?i:\\bfixed (it|that|the (bug|issue|problem))\\b)', r'|(?i:\\bfixed\\b)')"
mut "tests 要帶狀態詞"          "s.replace('tests? (all )?(pass|passed|passes|passing)', 'tests?')"
mut "merge 要帶 safe/ready/good" "s.replace('(safe|ready|good) to merge', 'merge')"
mut "commit 的受詞要收斂"       "s.replace('|the (change|changes|fix|fixes|branch|PR|commit|patch|work))', '|the [a-z]+)')"
mut "LGTM 不分大小寫"           "s.replace(r'|(?i:\\bLGTM\\b)', r'|LGTM')"

sec "── conf 的四種壞法（每一種的失效都是靜默的）──"
mut "空值不得登錄"              "s.replace('                if v:\n                    out.setdefault', '                if True:\n                    out.setdefault')"
mut "行內註解要剝掉"            "s.replace('re.split(r\"\\\\s+#\", v, maxsplit=1)[0]', 'v')"
mut "壞 regex 只廢自己那條"     "s.replace('    except re.error as exc:', '    except ZeroDivisionError as exc:')"
mut "擋掉配得到空字串的值"      "s.replace('if re.compile(extra).match(\"\"):', 'if False:')"
mut "conf 認得 CLAIM_CHECK_HOME" "s.replace('os.environ.get(\"CLAIM_CHECK_HOME\") or str(Path.home()', 'str(Path.home()')"

sec "── 詞表的 conf 覆寫（換一種語言不該要改 code）──"
mut "宣稱詞表走得到 conf"        "s.replace('\"CLAIM_TESTS_GREEN_CLAIM_RE\")', '\"__NEVER_A_CONF_KEY__\")')"
mut "NAMED 副檔名走得到 conf"    "s.replace('\"CLAIM_NAMED_EXT_RE\")', '\"__NEVER_A_CONF_KEY__\")')"

sec "── 安裝器把 conf 模板佈出去（否則詞表那條路只存在於文件裡）──"
mut "conf 模板有被複製"          "s.replace('cp \"\$ASSETS/claim-check.conf.template\" \"\$DEST/claim-check.conf\"', ':')" scripts/install.sh
mut "conf 不被覆蓋"              "s.replace('if [ -f \"\$DEST/claim-check.conf\" ]; then', 'if false; then')" scripts/install.sh

sec "── 規則本體 ──"
mut "正確性宣稱規則整條移除"     "s[:s.index('    # 今天四次真陽性')] + s[s.index('    (\"注入故障\",'):]"
mut "測試規則的新鮮度判定"       "s.replace('return ix[kind] >= 0 and ix[kind] >= ix[\"edit\"]', 'return ix[kind] >= 0')"

wait
i=0
while [ "$i" -lt "$seq_n" ]; do
  i=$((i + 1))
  # **IFS 要真的 tab**:`IFS='\t'` 在 POSIX sh 是反斜線與 t 兩個字元,讀出來全空。
  IFS="$(printf '\t')" read -r verdict name why < "$SB/r$i"
  if [ "$verdict" = sec ]; then
    printf '%s\n' "$name"
  elif [ "$verdict" = ok ]; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1)); printf '  FAIL  %s\n        %s\n' "$name" "$why"
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

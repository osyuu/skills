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
SB=$(mktemp -d)
# **提早結束也要出聲。** 完成性斷言在檔尾,而 `MUTANT_JOBS` 非數字時
# `$((seq_n % JOBS))` 在 set -u 下當場打死整支——只印了區塊標題、沒有摘要行、
# 而退出碼是 0,pre-commit 照樣印綠勾。trap 才蓋得到任何一種提早死。
_finished=0
trap 'rm -rf "$SB"; [ "$_finished" = 1 ] || { printf "\n突變測試沒跑完就結束了\n" >&2; exit 1; }' EXIT

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
if p.suffix == '.py':
    import ast
    try: ast.parse(n)
    except SyntaxError: sys.exit(8)
p.write_text(n)" >/dev/null 2>&1
  # **語法壞掉的注入是靠 crash 轉紅的,不是靠它宣稱守的行為。** 那種注入永遠會紅,
  # 於是它守的那段 code 就算守護者全部消失也偵測不到——覆蓋率實際上是 0。
  # 實測抓到一條:切字串的 index 抓錯位置、留下一個裸的 `r`,它殺掉 51 條斷言、
  # 其中 49 條輸出含 Traceback,而真正守那段行為的只有 1 條。
  _rc=$?
  case "$4" in *.sh) [ "$_rc" -eq 0 ] && ! sh -n "$d/$4" 2>/dev/null && _rc=8 ;; esac
  case $_rc in
    8) printf 'FAIL\t%s\t注入讓目標檔語法壞掉 —— 它是靠 crash 轉紅的\n' "$1" > "$SB/r$2"; return ;;
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
sec_n=0
sec() { seq_n=$((seq_n + 1)); sec_n=$((sec_n + 1)); printf 'sec\t%s\t\n' "$1" > "$SB/r$seq_n"; }

mut() { # mut <名稱> <python 表達式：s 為目標檔內容> [目標檔，預設 assets/claim-check.py]
  seq_n=$((seq_n + 1))
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
mut "format/fix 排除唯讀形式"    "s.replace(chr(10)+chr(32)*4+chr(114)+chr(34)+'(?![^'+chr(92)+'n]*(?:--output=none|--set-exit-if-changed|--dry-run))'+chr(34), '')"

sec "── conf 覆寫（機制壞掉時,補進 conf 的生態會靜默失效）──"
mut "conf 的值有被附加上去"      "s.replace('extra = CONF.get(key, \"\").strip()', 'extra = \"\"')"
mut "repo 層的 conf 有被讀到"    "s.replace('cands = [Path(\"hooks/claim-check.conf\")]', 'cands = []')"

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
mut "hedge 過濾整層拿掉"        "s.replace('if _is_claim(payload, m.start(), m.end())', 'if True')"
mut "hedge 只回看到子句邊界"    "s.replace('for m in CLAUSE_END.finditer(text[sent_start:at]):', 'for m in []:')"
mut "疑問句不算 hedge"          "s.replace('if TRAILING_Q.search(tail):', 'if False:')"

sec "── 「帶受詞或帶狀態詞」——明著宣告過的不變式 ──"
mut "fixed 要帶受詞"            "s.replace(r'|(?i:\\bfixed (it|that|the (bug|issue|problem))\\b)', r'|(?i:\\bfixed\\b)')"
mut "tests 要帶狀態詞"          "s.replace('tests? (all )?(pass|passed|passes|passing)', 'tests?')"
mut "merge 要帶 safe/ready/good" "s.replace('(safe|ready|good) to merge', 'merge')"
mut "commit 的受詞要收斂"       "s.replace('|the (change|changes|fix|fixes|branch|PR|commit|patch|work))', '|the [a-z]+)')"
mut "LGTM 不分大小寫"           "s.replace(r'|(?i:\\bLGTM\\b)', r'|LGTM')"

sec "── 兩類 hedge 的作用範圍（合成一類就會二選一地壞掉）──"
mut "條件類不跨子句"            "s.replace('HEDGE_COND.search(text[clause_start:at])', 'HEDGE_COND.search(text[sent_start:at])')"
mut "轉折之後重新起算"          "s.replace('for m in CONTRAST.finditer(span):', 'for m in []:')"

sec "── hedge 詞表本身 ──"
mut "英文收條件與計畫標記"      "s.replace('if|unless|when|until|whenever|whether|before', 'before')"
mut "cannot 要單獨收"           "s.replace('|cannot|can ?not', '')"
mut "中文收否定不只收條件"      "s.replace('沒有|沒能|不是|還沒|尚未|無法|未能|並未|不會', '__NEVER__')"
mut "claims/says 要排除連字號"  "s.replace('(?<![-\\\\w])(claims?|says)(?![-\\\\w])', '\\\\b(claims?|says)\\\\b')"
mut "assum 不吃 assumeIsolated" "s.replace('assum(e|ed|es|ing|ption)', 'assum\\\\w+')"
mut "after/once 不當 hedge"     "s.replace('|hope\\\\w*|need to', '|after|once|hope\\\\w*|need to')"

sec "── 放寬的受詞要收斂 ──"
mut "commit 的受詞含 work"      "s.replace('|commit|patch|work))', '|commit|patch))')"

sec "── 否定的回看範圍（分語言、只跨逗號）──"
mut "中文否定不跨逗號"          "s.replace('((en_start, HEDGE_NEG_EN), (clause_start, HEDGE_NEG_ZH))', '((en_start, HEDGE_NEG_EN), (en_start, HEDGE_NEG_ZH))')"
mut "否定只跨逗號不跨其他"      "s.replace('if not COMMA_ONLY.fullmatch(m.group(0)):', 'if False:')"
mut "疑問詞要錨在命中之後"      "s.replace('tail = text[end:', 'tail = text[at:')"
mut "呢 不算疑問詞"             "s.replace('(嗎|吗)', '(嗎|吗|呢)')"
mut "wrote 不在 hedge 詞表"     "s.replace('|hope\\\\w*|need to', '|wrote|writes|hope\\\\w*|need to')"

sec "── 放寬的受詞與證據 ──"
mut "pushed to 排除冠詞"        "s.replace('(?!(the|a|an|it|this|that|these|those|its|my|your|our|their)\\\\s)', '')"
mut "pushed to 排除副檔名"      "s.replace('(?!\\\\S*\\\\.\\\\w{1,4}\\\\b)', '')"
mut "RE_GIT 認得 git push"      "s.replace('git (commit|merge|push)', 'git (commit|merge)')"
mut "beside 不打穿 CLAIM_CHECK_HOME" "s.replace('    if not override:', '    if True:')"

sec "── conf 的四種壞法（每一種的失效都是靜默的）──"
mut "空值不得登錄"              "s.replace('                if v:\n                    out.setdefault', '                if True:\n                    out.setdefault')"
mut "行內註解要剝掉"            "s.replace('re.split(r\"\\\\s+#\", v, maxsplit=1)[0]', 'v')"
mut "壞 regex 只廢自己那條"     "s.replace('    except re.error as exc:', '    except ZeroDivisionError as exc:')"
mut "擋掉配得到空字串的值"      "s.replace('if re.compile(extra).match(\"\"):', 'if False:')"
mut "conf 認得 CLAIM_CHECK_HOME" "s.replace('Path(override or Path.home() / \".claude\")', 'Path(Path.home() / \".claude\")')"

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
  # **缺檔要自己吵。** 重導失敗時 `read` 根本不執行,而 verdict/name/why 會**沿用
  # 上一圈的值**——上一圈是 ok 就算成 pass。job 猝死、或結尾少一個 `wait`,輸出會是
  # 「N 條注入轉紅,0 條沒有」exit 0,跟正常跑幾乎逐字相同。
  if [ ! -f "$SB/r$i" ]; then
    fail=$((fail + 1)); printf '  FAIL  第 %s 條的結果檔不見了(job 沒跑完?)\n' "$i"; continue
  fi
  verdict=; name=; why=
  IFS="$(printf '\t')" read -r verdict name why < "$SB/r$i"
  if [ "$verdict" = sec ]; then
    printf '%s\n' "$name"
  elif [ "$verdict" = ok ]; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1)); printf '  FAIL  %s\n        %s\n' "$name" "$why"
  fi
done

# **exit 0 必須表示每一條注入都真的跑過。** `MUTANT_JOBS` 是非數字時
# `$((seq_n % JOBS))` 在 set -u 下當場打死整支,而那時只印了區塊標題、沒有摘要行、
# exit 0——pre-commit 照樣印綠勾。這條不依賴並行度,job 猝死也接得住。
if [ "$seq_n" -le 0 ] || [ "$((pass + fail + sec_n))" -ne "$seq_n" ]; then
    printf '\n注入數(%s)與結果數(%s)對不上 —— 沒跑完\n' "$seq_n" "$((pass + fail + sec_n))"
    exit 1
fi


# **偵測器自己也要有守門。** 它靜默失效的話,「注入是靠 crash 轉紅的」會悄悄回來
# ——而那正是它裝進來要擋的東西。實測踩過:裝到一半、某一支只有完成性斷言沒有偵測器,
# 而它照樣印全綠。送一個必定壞語法的注入進去,它必須指認得出來。
# 用序號 0,不動 seq_n,所以不影響完成性斷言的計數。
_mut_one "__偵測器自檢__" 0 "s + chr(10) + chr(41) + chr(40) + chr(10)" "assets/claim-check.py"
case "$(cat "$SB/r0" 2>/dev/null)" in
  *語法壞掉*) rm -f "$SB/r0" ;;
  *) printf '\n偵測器沒有指認語法壞掉的注入 —— 它自己失效了\n'; exit 2 ;;
esac

_finished=1
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

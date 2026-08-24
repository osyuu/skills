#!/bin/sh
# spec-claim-check —— 讓「spec 宣稱完成、但 code 沒有」在 commit 當下看得見。
#
# 與同一支 hook 的 decision-log 區塊互補：那邊守「已記錄的翻案有沒有回寫」，
# 這邊守「回寫本身是不是真的」。三個訊號、全部 warn-only，判準與取捨見
# sdd-harness-init 的 SKILL.md：
#
#   1. 任務標 ✅，它指名的 AC 還是 `- [ ]`
#   2. spec 點名的符號有定義卻沒有消費者（**改到死碼時測試照樣綠**）
#   3. spec 宣告的介面（`foo()`）在 code 裡不存在
#
# 門檻與路徑用環境變數或 hooks/spec-claim.conf 覆寫。`git commit --no-verify` 可整支跳過。

_e_spec=${SPEC_GLOBS:-}
_e_src=${SPEC_SRC_DIRS:-}
_e_test=${SPEC_TEST_DIRS:-}
_e_min=${SPEC_SYMBOL_MIN_LEN:-}
[ -f hooks/spec-claim.conf ] && . ./hooks/spec-claim.conf
[ -n "$_e_spec" ] && SPEC_GLOBS=$_e_spec
[ -n "$_e_src" ] && SPEC_SRC_DIRS=$_e_src
[ -n "$_e_test" ] && SPEC_TEST_DIRS=$_e_test
[ -n "$_e_min" ] && SPEC_SYMBOL_MIN_LEN=$_e_min

SPEC_GLOBS=${SPEC_GLOBS:-"design-doc-*.md docs/design/*.md"}
SRC_DIRS=${SPEC_SRC_DIRS:-"src lib app"}
TEST_DIRS=${SPEC_TEST_DIRS:-"test tests spec __tests__"}
# 太短的識別字（id、url、range）在散文裡到處都是，量不出訊號只量出雜訊。
MIN_LEN=${SPEC_SYMBOL_MIN_LEN:-8}
# 只掃原始碼副檔名——掃 json/plist/資產會讓索引大一個數量級，而 hook 慢到被繞過就沒用了。
EXTS=${SPEC_SRC_EXTS:-"swift kt java go rs ts tsx js jsx py rb dart cs m mm c h cpp hpp"}
INCLUDE=""
for e in $EXTS; do INCLUDE="$INCLUDE --include=*.$e"; done
# 「定義」長什麼樣。預設涵蓋 C 家族 + Swift/Kotlin/TS；其他語言在 conf 覆寫。
DEF_RE=${SPEC_DEF_RE:-'(func|var|let|class|struct|enum|protocol|typealias|interface|def|fn)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*'}
# 天生沒有使用者的東西，報了只會被學會忽略。預設擋 SwiftUI/Xcode 的 preview 型別。
IGNORE_RE=${SPEC_IGNORE_RE:-'_Previews$|^Preview'}

SPECS=""
for g in $SPEC_GLOBS; do
    for f in $g; do [ -f "$f" ] && SPECS="$SPECS $f"; done
done
[ -z "$SPECS" ] && exit 0

OUT=$(mktemp) || exit 0
trap 'rm -f "$OUT"' EXIT

report() {
    [ -s "$OUT" ] || return 0
    printf '\033[33m⚠  spec 宣稱與 code 對不上：\033[0m\n'
    cat "$OUT"
    printf '\033[33m   （僅提醒、不阻擋。門檻見 hooks/spec-claim.conf。）\033[0m\n'
}

# ---- 訊號 1：打勾的任務，驗收項還沒打勾 ----
for spec in $SPECS; do
    grep -nE '✅' "$spec" 2>/dev/null | grep -E 'AC[0-9]' | while IFS= read -r row; do
        line=${row%%:*}
        for id in $(printf '%s' "$row" | grep -oE 'AC[0-9]+[a-z]?' | sort -u); do
            if grep -qE "^- \[ \] \*\*$id\*\*" "$spec" 2>/dev/null; then
                printf '    %s:%s 標了 ✅，但 %s 還是未打勾的驗收項\n' "$spec" "$line" "$id" >> "$OUT"
            fi
        done
    done
done

# **SRC 為空時只能跳過訊號 2／3，不能整支結束**：訊號 1 只讀 spec 裡的打勾狀態，
# 不需要原始碼目錄。而下面的 grep 少了 $SRC 會改讀 stdin,所以這道 guard 對 2／3 仍是必要的。
SRC=""
for d in $SRC_DIRS; do [ -d "$d" ] && SRC="$SRC $d"; done
if [ -z "$SRC" ]; then
    printf '\033[33m⚠  spec-claim：SPEC_SRC_DIRS 指的目錄一個都不存在（%s），訊號 2／3 已跳過。\033[0m\n' "$SRC_DIRS"
    printf '\033[33m   （改 hooks/spec-claim.conf。填錯時符號檢查什麼都不報，跟「很乾淨」分不出來。）\033[0m\n'
    report
    exit 0
fi

# ---- 訊號 2／3：spec 點名的符號 ----
# 帶括號的（`foo()`）視為介面契約，不存在就報；不帶括號的只在「有定義卻沒人用」時報。
#
# **先建一次索引再查，不要逐符號掃原始碼**：spec 動輒點名上百個符號，
# 逐個 grep -r 是 O(符號 × 檔案)，在中型 repo 就要跑好幾分鐘——慢到會被 --no-verify 繞過的
# hook 等於沒裝。
SYMS=$(mktemp); SRCIDX=$(mktemp); TSTIDX=$(mktemp); DEFS=$(mktemp)
trap 'rm -f "$OUT" "$SYMS" "$SRCIDX" "$TSTIDX" "$DEFS"' EXIT

grep -ohE '`[A-Za-z_][A-Za-z0-9_]*\(?\)?`' $SPECS 2>/dev/null | tr -d '`' | sort -u > "$SYMS"
[ -s "$SYMS" ] || { [ -s "$OUT" ] || exit 0; }

grep -rhoE $INCLUDE '[A-Za-z_][A-Za-z0-9_]*' $SRC 2>/dev/null | sort | uniq -c > "$SRCIDX"

# **只評估「在這個 repo 裡有定義」的符號。** 出現一次不代表沒人用——散文常點名框架 API
# （AVAudioSourceNode、prepareToPlay、resolvingBookmarkData），那種在原始碼裡出現一次
# 正是「被呼叫了一次」。實測不加這道過濾，誤判佔九成，而會被無視的 hook 等於沒裝。
grep -rhoE $INCLUDE "$DEF_RE" $SRC 2>/dev/null \
    | awk '{print $NF}' | sort -u > "$DEFS"
: > "$TSTIDX"
for d in $TEST_DIRS; do
    [ -d "$d" ] && grep -rhoE '[A-Za-z_][A-Za-z0-9_]*' "$d" 2>/dev/null
done | sort | uniq -c > "$TSTIDX"

awk -v min="$MIN_LEN" '
    FILENAME==srcidx { src[$2]=$1; next }
    FILENAME==tstidx { tst[$2]=$1; next }
    FILENAME==defs   { defined[$0]; next }
    {
        tok=$0; iface=0; sym=tok
        if (tok ~ /\(\)$/)     { sym=substr(tok,1,length(tok)-2); iface=1 }
        else if (tok ~ /\($/)  { sym=substr(tok,1,length(tok)-1);  iface=1 }
        if (length(sym) < min) next
        if (sym in seen) next           # `foo` 與 `foo(` 正規化後是同一個，只報一次
        seen[sym]
        n = (sym in src) ? src[sym] : 0
        if (n == 0) {
            if (iface)
                printf "    `%s()` 是 spec 宣告的介面，但 code 裡不存在（未做，或改過名沒回寫）\n", sym
            next
        }
        if (n > 1) next
        if (!(sym in defined)) next     # 出現一次但不是本 repo 定義的 = 呼叫了一次，正常
        if (ignore != "" && sym ~ ignore) next
        t = (sym in tst) ? tst[sym] : 0
        if (t > 0) {
            printf "    `%s` 只有定義、產品 code 沒有消費者，而測試引用了 %d 次\n", sym, t
            printf "      → 測試會綠、注入故障也會紅，但畫面不會變。先確認它在產品路徑上。\n"
        } else {
            printf "    `%s` 只有定義，全 repo 沒有任何使用者\n", sym
        }
    }
' srcidx="$SRCIDX" tstidx="$TSTIDX" defs="$DEFS" ignore="$IGNORE_RE" "$SRCIDX" "$TSTIDX" "$DEFS" "$SYMS" >> "$OUT"

report
exit 0

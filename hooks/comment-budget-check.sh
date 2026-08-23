#!/bin/sh
# comment-budget-check —— 讓「這次 commit 加了多少註解」在 commit 當下看得見。
#
# 判準（給讀到警告的人，也給 AI）：
#   **註解只寫 code 說不出口的事**——約束、外部系統的反直覺行為、
#   「不要改成 X，因為 Y」。三類不該進註解：
#     a. 重述字面意思
#     b. 變更史（「原本是…後來改成…」）→ git log
#     c. 驗證過程（「兩位 reviewer 各自抓到」「已注入故障反向驗證」）→ commit message
#   b 和 c 證明的是作者很認真，不是系統怎麼運作；讀者要的是後者。
#
#   **越簡單的 code 能負擔的註解越少**。純值型別、單純的 view 沒什麼好解釋，
#   這時空間最容易被 b 和 c 填滿——沒東西可解釋時，正確答案是不寫。
#
# 三個訊號，全部 warn-only。門檻用環境變數或 hooks/comment-budget.conf 覆寫。
# `git commit --no-verify` 可整支跳過。

# 先接住環境變數：conf 也是設同名變數，source 在後會把它蓋掉——
# 於是「用環境變數覆寫」在裝了 conf 之後（也就是永遠）失效。
_e_block=${COMMENT_BLOCK_MAX:-}
_e_ratio=${COMMENT_RATIO_MAX:-}
_e_min=${COMMENT_RATIO_MIN_LINES:-}
[ -f hooks/comment-budget.conf ] && . ./hooks/comment-budget.conf
[ -n "$_e_block" ] && COMMENT_BLOCK_MAX=$_e_block
[ -n "$_e_ratio" ] && COMMENT_RATIO_MAX=$_e_ratio
[ -n "$_e_min" ] && COMMENT_RATIO_MIN_LINES=$_e_min

BLOCK_MAX=${COMMENT_BLOCK_MAX:-10}
RATIO_MAX=${COMMENT_RATIO_MAX:-40}
RATIO_MIN_LINES=${COMMENT_RATIO_MIN_LINES:-15}
# 副檔名 → 行註解符號。要支援更多語言就加在這裡。
EXT_SLASH=${COMMENT_EXT_SLASH:-swift js jsx ts tsx java kt kts go rs c h cpp hpp cc m mm cs dart scala php}
EXT_HASH=${COMMENT_EXT_HASH:-py rb sh bash zsh pl r jl}
EXT_DASH=${COMMENT_EXT_DASH:-sql hs lua elm}

prefix_for() {
    e=${1##*.}
    for x in $EXT_SLASH; do [ "$e" = "$x" ] && { echo '//'; return; }; done
    for x in $EXT_HASH;  do [ "$e" = "$x" ] && { echo '#';  return; }; done
    for x in $EXT_DASH;  do [ "$e" = "$x" ] && { echo '--'; return; }; done
    echo ''
}

# 手動跑時 cwd 可能在子目錄：conf 載不到、路徑也對不上，結果是靜默 exit 0。
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

FILES=$(git diff --cached --name-only --diff-filter=ACM)
[ -z "$FILES" ] && exit 0

# 門檻不是數字的話 `[ ]` 會噴 integer expression 然後那個檢查整個不觸發——
# 而「不觸發」跟「沒問題」的輸出一模一樣。退回預設並出聲。
for v in BLOCK_MAX RATIO_MAX RATIO_MIN_LINES; do
    eval "cur=\$$v"
    case "$cur" in
        ''|*[!0-9]*)
            printf '\033[33m⚠  comment-budget：%s=%s 不是數字，改用預設\033[0m\n' "$v" "$cur"
            case "$v" in
                BLOCK_MAX) BLOCK_MAX=10 ;;
                RATIO_MAX) RATIO_MAX=40 ;;
                RATIO_MIN_LINES) RATIO_MIN_LINES=15 ;;
            esac ;;
    esac
done

WARNED=0
warn_header() {
    [ "$WARNED" -eq 0 ] && printf '\033[33m⚠  註解預算：\033[0m\n'
    WARNED=1
}

# **檔名清單走檔案重導向**：`for f in $FILES` 對含空白的檔名會 word-split 掉，
# 而把 IFS 改成換行會連帶讓 prefix_for 裡的副檔名清單也不再切分（整個比對失效）。
# `while … done < file` 不是 pipeline，不會進子 shell，WARNED 跨得回來。
LIST=$(mktemp)
trap 'rm -f "$LIST"' EXIT
printf '%s\n' "$FILES" > "$LIST"

while IFS= read -r f; do
    [ -n "$f" ] || continue
    P=$(prefix_for "$f")
    [ -z "$P" ] && continue

    # **保留 hunk header**：`-U0` 濾掉邊界後，散落各處的短註解會被串成一個
    # 假的長區塊。`^@@` 要把連續計數歸零。
    ADDED=$(git diff --cached -U0 -- "$f" | grep -E '^(\+|@@)' | grep -v '^+++')
    [ -z "$ADDED" ] && continue

    STATS=$(printf '%s\n' "$ADDED" | awk -v P="$P" '
        /^@@/ { run = 0; next }
        {
            l = substr($0, 2); sub(/^[ \t]+/, "", l)
            if (index(l, P) == 1) { cmt++; run++; if (run > maxrun) maxrun = run }
            else { run = 0; if (l != "") code++ }
        }
        END { print cmt+0, code+0, maxrun+0 }')

    CMT=$(echo "$STATS" | cut -d' ' -f1)
    CODE=$(echo "$STATS" | cut -d' ' -f2)
    MAXRUN=$(echo "$STATS" | cut -d' ' -f3)
    TOTAL=$((CMT + CODE))

    if [ "$MAXRUN" -ge "$BLOCK_MAX" ]; then
        warn_header
        printf '\033[33m    %s：單一註解區塊 %s 行\033[0m\n' "$f" "$MAXRUN"
        printf '       → 它講的是現在的約束，還是我們怎麼走到這裡的？後者不屬於這裡。\n'
    fi

    if [ "$TOTAL" -gt 0 ] && [ "$CMT" -ge "$RATIO_MIN_LINES" ]; then
        PCT=$((CMT * 100 / TOTAL))
        if [ "$PCT" -gt "$RATIO_MAX" ]; then
            warn_header
            printf '\033[33m    %s：本次新增 %s%% 是註解（%s 行註解／%s 行程式）\033[0m\n' \
                "$f" "$PCT" "$CMT" "$CODE"
            printf '       → 這個檔案的 code 真的複雜到需要這個比例嗎？\n'
        fi
    fi

    # 敘事性：描述過去的變更，而不是現在的程式。
    # 刻意不含「踩過」「實測」——那兩個詞後面常接的是給未來的指令或量到的事實，有價值。
    NARRATIVE=$(printf '%s\n' "$ADDED" | grep -nE "^\+[[:space:]]*(//|#|--).*(原本|初版|一開始|曾經|上一版|後來改成|改動前|我把它改|used to|previously|we changed)" | head -3)
    if [ -n "$NARRATIVE" ]; then
        warn_header
        printf '\033[33m    %s：註解在敘述「以前怎樣」\033[0m\n' "$f"
        printf '%s\n' "$NARRATIVE" | cut -c1-100 | sed 's/^/         /'
        printf '       → 歷史查 git log 就有。留在註解裡的應該是現在的約束。\n'
    fi

    # 過程性：描述「我怎麼驗證的」。讀者要的是系統怎麼運作，不是作者多認真。
    PROCESS=$(printf '%s\n' "$ADDED" | grep -nE "^\+[[:space:]]*(//|#|--).*(reviewer|review 抓到|各自抓到|各自獨立|反向驗證|注入故障|審查時|我驗過|已驗證過|verified by|as reviewed)" | head -3)
    if [ -n "$PROCESS" ]; then
        warn_header
        printf '\033[33m    %s：註解在寫「驗證過程」\033[0m\n' "$f"
        printf '%s\n' "$PROCESS" | cut -c1-100 | sed 's/^/         /'
        printf '       → 沒有讀者需要知道你怎麼驗的。留下結論與約束，過程進 commit message。\n'
    fi
done < "$LIST"

[ "$WARNED" -eq 1 ] && \
    printf '\033[33m   （僅提醒、不阻擋。門檻見 hooks/comment-budget.conf。）\033[0m\n'

exit 0

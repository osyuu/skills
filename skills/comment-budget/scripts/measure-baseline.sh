#!/bin/sh
# comment-budget 基準量測：拿最近的 commit 跑一次，看現在的門檻會對多少檔案開火。
#
# 對七成 commit 開火 = 噪音，會被無視；完全不開火 = 門檻等於沒裝。
# 判準與門檻的意義見 skill 的 SKILL.md，這裡只負責算數字。
#
# 用法：sh <skill-dir>/scripts/measure-baseline.sh [commit 數，預設 25]
# 在目標 repo 根目錄跑。

set -u
N=${1:-25}

# 副檔名 → 行註解符號。**與 assets/comment-budget-check.sh 的那份必須一致**，
# tests/run.sh 有一條在比對兩邊；checker 要能單檔安裝、不能靠 source 別的檔，
# 所以這裡是刻意的複製而不是共用。
EXT_SLASH=${COMMENT_EXT_SLASH:-swift js jsx ts tsx java kt kts go rs c h cpp hpp cc m mm cs dart scala php}
EXT_HASH=${COMMENT_EXT_HASH:-py rb sh bash zsh pl r jl}
EXT_DASH=${COMMENT_EXT_DASH:-sql hs lua elm}

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 1
[ -f hooks/comment-budget.conf ] && . ./hooks/comment-budget.conf

BLOCK_MAX=${COMMENT_BLOCK_MAX:-10}
RATIO_MAX=${COMMENT_RATIO_MAX:-40}
RATIO_MIN_LINES=${COMMENT_RATIO_MIN_LINES:-15}

prefix_for() {
    e=${1##*.}
    for x in $EXT_SLASH; do [ "$e" = "$x" ] && { echo '//'; return; }; done
    for x in $EXT_HASH;  do [ "$e" = "$x" ] && { echo '#';  return; }; done
    for x in $EXT_DASH;  do [ "$e" = "$x" ] && { echo '--'; return; }; done
    echo ''
}

TMP=$(mktemp) || exit 1
SKIPPED=$(mktemp) || exit 1
trap 'rm -f "$TMP" "$SKIPPED"' EXIT

examined=0
fired=0

for c in $(git log --format=%H -n "$N" 2>/dev/null); do
    git diff-tree --root --no-commit-id --name-only -r "$c" 2>/dev/null | while IFS= read -r f; do
        [ -n "$f" ] || continue
        case "$f" in *.*) ;; *) continue ;; esac
        P=$(prefix_for "$f")
        if [ -z "$P" ]; then printf '%s\n' "${f##*.}" >> "$SKIPPED"; continue; fi
        ADDED=$(git show --format= -U0 "$c" -- "$f" 2>/dev/null | grep -E '^(\+|@@)' | grep -v '^+++')
        [ -n "$ADDED" ] || continue
        printf '%s\n' "$ADDED" | awk -v P="$P" -v F="$f" -v BM="$BLOCK_MAX" \
            -v RM="$RATIO_MAX" -v RL="$RATIO_MIN_LINES" '
            /^@@/ { run = 0; next }
            {
                l = substr($0, 2); sub(/^[ \t]+/, "", l)
                if (index(l, P) == 1) { cmt++; run++; if (run > maxrun) maxrun = run }
                else { run = 0; if (l != "") code++ }
            }
            END {
                cmt+=0; code+=0; maxrun+=0; t = cmt + code
                hit = 0
                if (maxrun >= BM) hit = 1
                if (t > 0 && cmt >= RL && cmt * 100 / t > RM) hit = 1
                pct = (t > 0) ? int(cmt * 100 / t) : 0
                printf "%s\t%s\t%d%%\tmax %d\n", (hit ? "FIRE" : "ok"), F, pct, maxrun
            }' >> "$TMP"
    done
done

examined=$(wc -l < "$TMP" | tr -d ' ')
fired=$(grep -c '^FIRE' "$TMP" 2>/dev/null || true)

printf '\n最近 %s 個 commit：檢查 %s 個檔次，其中 %s 個會開火\n' "$N" "$examined" "$fired"
if [ "$examined" -gt 0 ]; then
    printf '開火率 %s%%（目標：只有離群值會亮。過半 = 噪音；0 = 門檻等於沒裝）\n' \
        "$(( fired * 100 / examined ))"
fi
grep '^FIRE' "$TMP" 2>/dev/null | sed 's/^FIRE\t/  /' | sort -u

# **跳過的要講出來。** 沒有對應註解符號的副檔名若默默算成 0%，那個 0 讀起來
# 就是「很乾淨」——而那正是這支腳本要避免的誤導。
if [ -s "$SKIPPED" ]; then
    printf '\n略過（沒有對應的行註解符號，未納入計算）：%s\n' \
        "$(sort -u "$SKIPPED" | tr '\n' ' ')"
    printf '  → 這些副檔名不在 COMMENT_EXT_* 裡。要納入就加進 hooks/comment-budget.conf。\n'
fi
if [ "$examined" -eq 0 ]; then
    printf '\n⚠  一個檔次都沒量到——不是「很乾淨」，是沒有相符的副檔名或 commit 數太少。\n'
fi

#!/bin/sh
# 部署副本 vs skill 來源：本 repo 自己裝了兩支由 skill 提供的 hook，而安裝器一律
# idempotent 不覆蓋既有檔案（為了保住使用者調過的門檻）——**改了 assets/ 就必須
# 手動 cp 到部署位置**。兩份不同時跑的是部署那份，而測試量的是來源那份，兩邊都綠。
# warn-only。
set -u
[ -n "${SYNC_CHECK_ROOT:-}" ] && { cd "$SYNC_CHECK_ROOT" || exit 2; }

# <部署路徑>|<來源路徑>。門檻檔（*.conf）刻意不列：那是每個 repo 各自調的。
PAIRS='.claude/hooks/claude-md-hygiene-hook.py|skills/harness/claude-md-hygiene/assets/claude-md-hygiene-hook.py
hooks/comment-budget-check.sh|skills/harness/comment-budget/assets/comment-budget-check.sh'

printf '%s\n' "$PAIRS" | while IFS='|' read -r live src; do
    [ -n "$live" ] || continue
    if [ ! -f "$live" ] || [ ! -f "$src" ]; then
        printf '\033[33m⚠  sync-check：%s 或 %s 不存在，無法比對\033[0m\n' "$live" "$src"
        continue
    fi
    cmp -s "$live" "$src" || {
        printf '\033[33m⚠  sync-check：%s 與來源 %s 不一致\033[0m\n' "$live" "$src"
        printf '   跑的是部署副本，改的是來源——兩者不同時所有測試仍會全綠。\n'
        printf '   cp %s %s\n' "$src" "$live"
    }
done

# PAIRS 是手維護的,而這支守的正是「登錄與現實不同步」。反查一遍:部署位置底下
# 每支腳本,若在某個 skill 的 assets/ 有同名來源卻不在 PAIRS 裡,那份漂移沒人看。
for live in hooks/*.sh .claude/hooks/*; do
    [ -f "$live" ] || continue
    for src in skills/*/*/assets/"${live##*/}"; do
        [ -f "$src" ] || continue
        printf '%s\n' "$PAIRS" | grep -qF "$live|" || {
            printf '\033[33m⚠  sync-check：%s 在 %s 有同名來源，但不在 PAIRS 裡\033[0m\n' "$live" "$src"
            printf '   這支的漂移目前沒有任何人看著。\n'
        }
    done
done

# ── 使用者層的部署副本(`~/.claude/hooks/`)────────────────────────────────
# 跟上面那批的差別有兩點,所以不能混在同一張表裡:
#   1. **它在 repo 外面**,`git status`、`git diff`、任何 review 都看不到它。改了
#      `assets/` 忘了同步,跑的是舊版而測試量的是新版——兩邊都綠。實際犯過一次。
#   2. **不存在不算漂移**:那只表示這台機器沒裝那道守門。對它出聲會讓每次 commit
#      都噴一行與這次改動無關的東西,而噴幾次之後整支 sync-check 就沒人看了。
UPAIRS='hooks/claim-check.py|skills/harness/claim-check/assets/claim-check.py'
UROOT="${SYNC_CHECK_HOME:-$HOME}/.claude"

printf '%s\n' "$UPAIRS" | while IFS='|' read -r live src; do
    [ -n "$live" ] || continue
    [ -f "$UROOT/$live" ] || continue
    [ -f "$src" ] || {
        printf '\033[33m⚠  sync-check：%s 裝著,但來源 %s 不見了\033[0m\n' "$UROOT/$live" "$src"
        continue
    }
    cmp -s "$UROOT/$live" "$src" || {
        printf '\033[33m⚠  sync-check：%s 與來源 %s 不一致\033[0m\n' "$UROOT/$live" "$src"
        printf '   這份在 repo 外面,git 看不到它——跑的是它,測試量的是來源。\n'
        printf '   cp %s %s\n' "$src" "$UROOT/$live"
    }
done

# 同上的反查:使用者層裝著某支腳本、某個 skill 的 assets/ 有同名來源,卻不在 UPAIRS 裡。
for live in "$UROOT"/hooks/*; do
    [ -f "$live" ] || continue
    for src in skills/*/*/assets/"${live##*/}"; do
        [ -f "$src" ] || continue
        printf '%s\n' "$UPAIRS" | grep -qF "hooks/${live##*/}|" || {
            printf '\033[33m⚠  sync-check：%s 在 %s 有同名來源，但不在 UPAIRS 裡\033[0m\n' "$live" "$src"
            printf '   這支的漂移目前沒有任何人看著。\n'
        }
    done
done
exit 0

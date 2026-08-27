#!/bin/sh
# 部署副本 vs skill 來源：本 repo 自己裝了兩支由 skill 提供的 hook，而安裝器一律
# idempotent 不覆蓋既有檔案（為了保住使用者調過的門檻）——**改了 assets/ 就必須
# 手動 cp 到部署位置**。兩份不同時跑的是部署那份，而測試量的是來源那份，兩邊都綠。
# warn-only。
set -u
[ -n "${SYNC_CHECK_ROOT:-}" ] && cd "$SYNC_CHECK_ROOT"

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
exit 0

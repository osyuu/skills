#!/bin/sh
# 驗證一道守門真的會開火。
#
# 為什麼需要這支：「守門裝好了」跟「守門裝了但永遠不會開火」在輸出上完全
# 一樣——兩者都是安靜的。實測踩過：arch-guard 裝完跑 audit 得到 0 條違規，
# 看起來乾淨，實際是 git grep 只掃 tracked 檔案、而測試檔還沒 git add 的
# 假陰性。沒驗的話會帶著一道永遠不開火的守門繼續走。
#
# 用法：sh verify-guard.sh <違規檔路徑> <期望出現在 hook 輸出中的關鍵字>
set -u

FILE="${1:-}"
EXPECT="${2:-}"
if [ -z "$FILE" ] || [ -z "$EXPECT" ]; then
    echo "用法：sh verify-guard.sh <違規檔路徑> <期望出現的關鍵字>" >&2
    exit 2
fi
[ -f "$FILE" ] || { echo "找不到違規檔：${FILE}" >&2; exit 2; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "不在 git repo 裡" >&2; exit 2; }
HP=$(git config core.hooksPath 2>/dev/null) || HP=".git/hooks"
[ -n "$HP" ] || HP=".git/hooks"
HOOK="${ROOT}/${HP}/pre-commit"
[ -f "$HOOK" ] || {
    echo "找不到 pre-commit：${HOOK}" >&2
    echo "  core.hooksPath 沒設的話所有守門都是靜默失效的。" >&2
    exit 2; }

# index 不乾淨就拒絕：這支會 git add 再 reset，跟既有的 staged 內容混在
# 一起就分不清哪些是使用者的。
git diff --cached --quiet || {
    echo "index 有 staged 變更。先 commit 或 stash 再驗證。" >&2; exit 2; }

KEEP=0
cleanup() {
    git reset -q HEAD -- "$FILE" 2>/dev/null || true
    [ "$KEEP" = "1" ] || rm -f "$FILE"
}
trap cleanup EXIT INT TERM

git add -- "$FILE" || exit 2
out=$(sh "$HOOK" 2>&1 || true)

if printf '%s' "$out" | grep -q -- "$EXPECT"; then
    printf '\033[32m✓ 開火了\033[0m — 注入 %s，hook 輸出含「%s」\n' "$FILE" "$EXPECT"
    exit 0
fi

KEEP=1
printf '\033[31m✗ 沒開火\033[0m — 注入 %s，但 hook 輸出不含「%s」\n' "$FILE" "$EXPECT"
printf '  這跟「這條規則很乾淨」長得一模一樣。常見原因：\n'
printf '  · pattern 用了 grep -E 不支援的語法（\\d \\b \\s \\w 在 grep 與 awk 間不一致，且靜默回 0 筆）\n'
printf '  · 檔案落在 IGNORE 或 allow 路徑裡\n'
printf '  · 檢查只看 staged 新增行，而這次的內容不算新增\n'
printf '  · hook 根本沒接上（core.hooksPath）\n'
printf '  違規檔保留在 %s 供診斷。\n' "$FILE"
echo "--- hook 實際輸出 ---"
printf '%s\n' "$out" | head -20
exit 1

#!/bin/sh
# 驗證一道守門的實際行為，兩個方向都能驗。
#
# 為什麼需要：「守門裝好了」跟「守門永遠不會開火」在輸出上一樣，都是安靜的。
# 實測踩過 git grep 只掃 tracked 檔案造成的假陰性——audit 報 0 條違規，看起來乾淨。
#
# 用法：
#   sh verify-guard.sh [--expect-no-fire] <違規檔路徑> <期望出現的關鍵字>
#
# 檔案必須未被 git 追蹤，且**驗證成功後會被腳本刪掉**——請傳一個剛建的暫時檔名。
# 傳既有的未追蹤檔案（例如還沒 add 的筆記）一樣會被刪，腳本分辨不出來。
# 已追蹤的檔案直接拒絕：那等於刪掉未 commit 的修改，git reset 只還原 index，
# 工作區那份救不回來。
#
# 關鍵字是**字面比對**（grep -F）。守門常用 [name] 當輸出前綴，走 regex 的話
# 會被當字元類；反過來 core.UI 會誤中 core/UI 造成假陽性，那比假陰性更糟——
# 它讓人簽收一道從沒驗過的守門。
#
# 結束碼：0 符合預期 · 1 不符預期 · 2 用法或環境錯誤
set -u

EXPECT_FIRE=1
if [ "${1:-}" = "--expect-no-fire" ]; then EXPECT_FIRE=0; shift; fi

FILE="${1:-}"
EXPECT="${2:-}"
if [ $# -gt 2 ]; then
    echo "多餘的參數：$3" >&2
    echo "  --expect-no-fire 必須放在最前面，放在後面會被當成第三個參數。" >&2
    exit 2
fi
if [ -z "$FILE" ] || [ -z "$EXPECT" ]; then
    echo "用法：sh verify-guard.sh [--expect-no-fire] <違規檔路徑> <期望出現的關鍵字>" >&2
    exit 2
fi
[ -f "$FILE" ] || { echo "找不到檔案：${FILE}" >&2; exit 2; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "不在 git repo 裡" >&2; exit 2; }

if git ls-files --error-unmatch -- "$FILE" >/dev/null 2>&1; then
    echo "拒絕：${FILE} 已被 git 追蹤。" >&2
    echo "  這支腳本會在驗證後刪掉該檔，對既有檔案等於刪掉未 commit 的修改。" >&2
    echo "  請改用一個新檔名。" >&2
    exit 2
fi

HP=$(git config core.hooksPath 2>/dev/null) || HP=""
[ -n "$HP" ] || HP=".git/hooks"
case "$HP" in
    /*) HOOK="$HP/pre-commit" ;;
    *)  HOOK="$ROOT/$HP/pre-commit" ;;
esac
[ -f "$HOOK" ] || {
    echo "找不到 pre-commit：${HOOK}（core.hooksPath=${HP}）" >&2
    echo "  沒設 core.hooksPath 的話所有守門都是靜默失效的。" >&2
    exit 2; }

git diff --cached --quiet >/dev/null 2>&1 || {
    echo "index 有 staged 變更。先 commit 或 stash 再驗證。" >&2; exit 2; }

KEEP=0
cleanup() {
    git reset -q HEAD -- "$FILE" 2>/dev/null || true
    [ "$KEEP" = "1" ] || rm -f "$FILE"
}
trap cleanup EXIT INT TERM

if ! git add -- "$FILE"; then
    git check-ignore -q -- "$FILE" && \
        echo "  ${FILE} 被 .gitignore 排除，hook 永遠看不到它。" >&2
    exit 2
fi
if git diff --cached --quiet >/dev/null 2>&1; then
    echo "警告：git add 之後 index 仍無變更，hook 不會看到任何東西。" >&2
    KEEP=1
    exit 2
fi

# 直接執行而非 sh "$HOOK"：hook 的 shebang 可能要 bash，而 Linux 的 /bin/sh
# 是 dash，硬套會噴 syntax error 並被誤讀成「沒開火」。
if [ -x "$HOOK" ]; then out=$("$HOOK" 2>&1 || true); else out=$(sh "$HOOK" 2>&1 || true); fi

if printf '%s' "$out" | grep -qF -- "$EXPECT"; then fired=1; else fired=0; fi

if [ "$fired" = "$EXPECT_FIRE" ]; then
    if [ "$EXPECT_FIRE" = "1" ]; then
        printf '\033[32m✓ 開火了\033[0m — 注入 %s，輸出含「%s」\n' "$FILE" "$EXPECT"
    else
        printf '\033[32m✓ 正確放行\033[0m — 注入 %s，輸出不含「%s」\n' "$FILE" "$EXPECT"
        printf '  注意：這個綠燈只在同一個關鍵字的**正向**驗證也通過時才有意義。\n'
        printf '  守門整條失效、關鍵字打錯字，都會讓這裡變綠。\n'
    fi
    exit 0
fi

KEEP=1
if [ "$EXPECT_FIRE" = "1" ]; then
    printf '\033[31m✗ 沒開火\033[0m — 注入 %s，輸出不含「%s」\n' "$FILE" "$EXPECT"
    printf '  這跟「這條規則很乾淨」長得一模一樣。常見原因：\n'
    printf '  · pattern 用了 grep -E 不支援的語法（\\d \\b \\s \\w 靜默回 0 筆）\n'
    printf '  · 檔案落在 IGNORE 或 allow 路徑裡\n'
    printf '  · 檢查只看 staged 新增行，而這次內容不算新增\n'
else
    printf '\033[31m✗ 不該開火卻開火了\033[0m — %s 應被放行，但輸出含「%s」\n' "$FILE" "$EXPECT"
    printf '  allow / IGNORE 路徑沒有生效，或 pattern 比預期寬。\n'
fi
printf '  違規檔保留在 %s 供診斷。\n' "$FILE"
echo "--- hook 實際輸出 ---"
printf '%s\n' "$out" | head -20
exit 1

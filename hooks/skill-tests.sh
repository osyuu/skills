#!/bin/sh
# 改了某個 skill 的 scripts/ 或 assets/，就跑它自己的 tests/。
#
# 這類腳本的失敗模式是靜默的：壞掉的 pattern、少一個欄位、多一層跳脫，全都回
# 「沒有發現」——跟真的沒問題長得一樣。而 skill 一 push 就到所有機器，沒有灰度。
# warn-only。
set -u
changed=$(git diff --cached --name-only | grep -E '^skills/[^/]+/(scripts|assets)/' || true)
[ -n "$changed" ] || exit 0

printf '%s\n' "$changed" | sed -E 's|^skills/([^/]+)/.*|\1|' | sort -u | while read -r s; do
    t="skills/$s/tests/run.sh"
    if [ ! -f "$t" ]; then
        printf '\033[33m⚠  skill-tests：%s 的 scripts/assets 有改動，但沒有 tests/run.sh\033[0m\n' "$s"
        continue
    fi
    if out=$(sh "$t" 2>&1); then
        printf '\033[32m✓ skill-tests：%s %s\033[0m\n' "$s" "$(printf '%s' "$out" | grep -oE 'PASS [0-9]+ · FAIL [0-9]+' | tail -1)"
    else
        printf '\033[33m⚠  skill-tests：%s 的測試沒過\033[0m\n' "$s"
        printf '%s\n' "$out" | grep -E '✗|FAIL' | head -5 | sed 's/^/    /'
    fi
done
exit 0

#!/bin/sh
# 新增了 skills/<name>/ 卻沒登錄進 marketplace.json = 那個 skill 不存在於任何機器。
#
# 症狀是「檔案都在、commit 也過了、就是沒人載得到」——跟寫壞了完全不同的排查方向。
# warn-only。
set -u
MF=".claude-plugin/marketplace.json"
[ -f "$MF" ] || exit 0
new=$(git diff --cached --name-only --diff-filter=A | grep -E '^skills/([^/]+/)?[^/]+/SKILL\.md$' || true)
[ -n "$new" ] || exit 0

printf '%s\n' "$new" | sed -E 's#/SKILL\.md$##' | while read -r s; do
    grep -q "\"./${s}\"" "$MF" || {
        printf '\033[33m⚠  marketplace-sync：新增了 %s 但 %s 沒登錄它\033[0m\n' "$s" "$MF"
        printf '   未登錄的 skill 不會出現在任何機器上，而檔案看起來都在。\n'
    }
done
exit 0

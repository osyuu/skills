#!/bin/sh
# 列出這台機器上「現在生效」的 skill：限定名 plugin:skill + description。
#
# 掃 plugin cache 而非本機 repo——換一台機器就沒有 skill 原始碼，cache 一定在。
# 注意本機 ~/.claude/skills/ 不在掃描範圍，那裡的同名 skill 會與 plugin 版打架。
#
# 取不到 description 的仍然印出並標 (無描述)：這支的用途是「盤點漏了哪些」，
# 靜默消失跟「那個 skill 根本沒裝」無法分辨，是最致命的失敗模式。
set -u

CACHE="${CLAUDE_PLUGIN_CACHE:-$HOME/.claude/plugins/cache}"
CACHE="${CACHE%/}"   # 結尾斜線會讓下面的 ${f#"$CACHE"/} 取錯 plugin 欄
# 預設不截斷：負面觸發（「…時不要用」）通常寫在描述結尾，而那正是盤點最需要
# 的判斷依據。設了 HARNESS_AUDIT_DESC_MAX 才截，且截斷是**按 byte**——
# BWK awk（macOS 內建）的 substr 不理 locale，中文描述會被切出壞掉的 UTF-8。
MAXLEN="${HARNESS_AUDIT_DESC_MAX:-0}"
[ -d "$CACHE" ] || { echo "找不到 plugin cache：${CACHE}" >&2; exit 1; }

find -L "$CACHE" -name SKILL.md -type f 2>/dev/null | while IFS= read -r f; do
    skill_dir=$(dirname "$f")
    skills_dir=$(dirname "$skill_dir")
    [ "$(basename "$skills_dir")" = "skills" ] || continue

    # 舊版本目錄帶 .orphaned_at（約 14 天後才清，寬限期留給還在跑的 session）。
    # 深度不固定：有的是 <ver>/skills/，有的是 <ver>/.claude/skills/。
    d="$skills_dir"; orphaned=0; i=0
    while [ $i -lt 4 ]; do
        d=$(dirname "$d")
        [ "$d" = "/" ] && break
        if [ -f "$d/.orphaned_at" ]; then orphaned=1; break; fi
        i=$((i + 1))
    done
    [ "$orphaned" = "1" ] && continue

    rel=${f#"$CACHE"/}
    plug=$(printf '%s' "$rel" | cut -d/ -f2)
    name=$(basename "$skill_dir")

    desc=$(awk -v maxlen="$MAXLEN" '
        { sub(/\r$/, "") }                      # CRLF 會讓第一行不等於 --- 而整份放棄
        NR==1 && $0 != "---" { exit }
        NR>1 && /^---[[:space:]]*$/ { exit }
        /^description:/ {
            v = $0; sub(/^description:[[:space:]]*/, "", v)
            if (v ~ /^[>|][-+]?[[:space:]]*$/) { collecting = 1; next }
            gsub(/^"|"$/, "", v); gsub(/^'"'"'|'"'"'$/, "", v)
            buf = v; collecting = 1; next       # plain scalar 也可能有縮排續行
        }
        collecting && /^[[:space:]]/ {
            v = $0; sub(/^[[:space:]]+/, "", v)
            buf = buf (buf == "" ? "" : " ") v; next
        }
        collecting { exit }
        END {
            gsub(/[[:space:]]+/, " ", buf)
            if (maxlen > 0 && length(buf) > maxlen) buf = substr(buf, 1, maxlen) "…"
            print buf
        }
    ' "$f")

    [ -n "$desc" ] || desc="(無描述)"
    printf '%s:%s\t%s\n' "$plug" "$name" "$desc"
done | LC_ALL=C sort -u -t"$(printf '\t')" -k1,1

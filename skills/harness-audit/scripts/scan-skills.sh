#!/bin/sh
# 列出這台機器上「現在生效」的 skill：名稱 + description。
#
# 掃 plugin cache 而非任何本機 repo——skill 要在別台機器上也能用，而那些機器
# 不會有你的 skill 原始碼。
#
# 兩個只有實跑才看得到的坑：
#   - 同一個 skill 在 cache 裡有多個版本目錄，舊的帶 .orphaned_at（約 14 天後
#     才清，寬限期留給還在跑的舊 session）。不濾會重複、而且描述可能是舊版。
#     版本目錄的深度不固定（有的 plugin 是 <ver>/skills/，有的是
#     <ver>/.claude/skills/），所以要往上找幾層而不是寫死一層。
#   - description 常用 YAML 折疊語法（`>-` 後面接縮排行）。只讀冒號後面那段
#     會拿到字面的 ">-"，看起來像「這個 skill 沒寫描述」。
set -u

CACHE="${CLAUDE_PLUGIN_CACHE:-$HOME/.claude/plugins/cache}"
MAXLEN="${HARNESS_AUDIT_DESC_MAX:-320}"
[ -d "$CACHE" ] || { echo "找不到 plugin cache：$CACHE" >&2; exit 1; }

find "$CACHE" -name SKILL.md -type f 2>/dev/null | while IFS= read -r f; do
    skill_dir=$(dirname "$f")
    skills_dir=$(dirname "$skill_dir")
    [ "$(basename "$skills_dir")" = "skills" ] || continue

    d="$skills_dir"; orphaned=0; i=0
    while [ $i -lt 4 ]; do
        d=$(dirname "$d")
        [ "$d" = "/" ] && break
        if [ -f "$d/.orphaned_at" ]; then orphaned=1; break; fi
        i=$((i + 1))
    done
    [ "$orphaned" = "1" ] && continue

    name=$(basename "$skill_dir")
    desc=$(awk -v maxlen="$MAXLEN" '
        NR==1 && $0 != "---" { exit }
        NR>1 && /^---[[:space:]]*$/ { exit }
        /^description:/ {
            v = $0
            sub(/^description:[[:space:]]*/, "", v)
            if (v ~ /^[>|][-+]?[[:space:]]*$/) { folded = 1; next }
            gsub(/^"|"$/, "", v); gsub(/^'"'"'|'"'"'$/, "", v)
            buf = v; exit
        }
        folded && /^[[:space:]]/ {
            v = $0; sub(/^[[:space:]]+/, "", v)
            buf = buf (buf == "" ? "" : " ") v; next
        }
        folded { exit }
        END {
            gsub(/[[:space:]]+/, " ", buf)
            if (length(buf) > maxlen) buf = substr(buf, 1, maxlen) "…"
            print buf
        }
    ' "$f")

    [ -n "$desc" ] && printf '%s\t%s\n' "$name" "$desc"
done | LC_ALL=C sort -u -k1,1

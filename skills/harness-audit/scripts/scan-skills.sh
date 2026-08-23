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
while [ "${CACHE%/}" != "$CACHE" ]; do CACHE="${CACHE%/}"; done   # 多個結尾斜線會讓 plugin 欄取錯
# 預設不截斷：負面觸發（「…時不要用」）通常寫在描述結尾，而那正是盤點最需要
# 的判斷依據。設了 HARNESS_AUDIT_DESC_MAX 才截，且截斷是**按 byte**——
# BWK awk（macOS 內建）的 substr 不理 locale，中文描述會被切出壞掉的 UTF-8。
MAXLEN="${HARNESS_AUDIT_DESC_MAX:-0}"
[ -d "$CACHE" ] || { echo "找不到 plugin cache：${CACHE}" >&2; exit 1; }

# 每個 plugin 目錄底下躺著整個來源 repo 的 skill（marketplace 的 source: "./"
# 造成），但 marketplace.json 只宣告其中一部分。不過濾就會產出大量根本叫不出來
# 的限定名——而產生正確的限定名正是這一欄存在的理由。實測未過濾時 57 → 167 行，
# 其中約 110 筆是幻影。
ALLOW=""
QUALIFY=1
if command -v python3 >/dev/null 2>&1; then
    ALLOW=$(python3 - "$CACHE" <<'PYFILTER' 2>/dev/null || true
import glob, json, os, sys
cache = sys.argv[1]
for mf in glob.glob(os.path.join(cache, "*", "*", "*", ".claude-plugin", "marketplace.json")):
    ver = os.path.dirname(os.path.dirname(mf))
    plug = os.path.basename(os.path.dirname(ver))
    try:
        data = json.load(open(mf))
    except Exception:
        continue
    for entry in data.get("plugins", []):
        if entry.get("name") != plug:
            continue
        for sk in entry.get("skills", []):
            print(plug + "/" + os.path.basename(sk.rstrip("/")))
PYFILTER
)
else
    # 沒有 python3 就無法讀宣告清單。印幻影限定名比不印限定名更糟——
    # 前者看起來可以直接拿去叫用，後者至少是誠實的。
    QUALIFY=0
    echo "警告：找不到 python3，無法讀 marketplace 宣告，改為只輸出 skill 名（無 plugin 前綴）" >&2
fi

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

    # 只對「有宣告清單」的 plugin 過濾；沒有 marketplace.json 的（bundled 等）照收
    if [ "$QUALIFY" = "1" ] && printf '%s\n' "$ALLOW" | grep -q "^${plug}/"; then
        printf '%s\n' "$ALLOW" | grep -qx "${plug}/${name}" || continue
    fi

    [ -n "$desc" ] || desc="(無描述)"
    if [ "$QUALIFY" = "1" ]; then
        printf '%s:%s\t%s\n' "$plug" "$name" "$desc"
    else
        printf '%s\t%s\n' "$name" "$desc"
    fi
done | LC_ALL=C sort -u -t"$(printf '\t')" -k1,1

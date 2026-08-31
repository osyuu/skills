#!/bin/sh
# osyuu 全域環境部署。idempotent，可重跑。
#
# 新機器：
#   git clone https://github.com/osyuu/skills <任意路徑>
#   sh <任意路徑>/bootstrap/install.sh          # --dry-run 可先看
#
# clone 放哪都行——REPO 由腳本自己的位置推導。但**位置一旦定了就不能搬**：
# CLAUDE.md 與 statusline.sh 走 symlink 指回這個 clone，不是複製。複製會產生第二份，
# 而兩份不同時跑的是部署那份、改的是來源那份，畫面上沒有任何差別。代價是懸空的 symlink
# 等於全域規範整份消失，而且是靜默的。
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
DEST="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
DRY=""

# **這份清單只有一份。** 安裝段與驗證段各抄一份時兩邊會分頭漂，而漂掉的那支正好是
# 「裝了但沒驗」或「驗了但沒裝」——兩種都不出聲。
PLUGINS="mattpocock-skills@claude-plugins-official
frontend-design@claude-plugins-official
swift-lsp@claude-plugins-official
flutter-dart-code-review@osyuu
xcode-ios-pitfalls@osyuu
release-assets@osyuu
vgv-ai-flutter-plugin@very-good-claude-code-marketplace
flutter-all@flutter-claude-code
ui-ux-pro-max@ui-ux-pro-max-skill"

[ "${1:-}" = "--dry-run" ] && DRY=1 && echo "== DRY RUN：只印不做 =="

run() { if [ -n "${DRY}" ]; then echo "  \$ $*"; else "$@"; fi; }

# **先確認 claude 在不在。** 少了它，下面兩段每一行都會印「已存在或失敗」，
# 十三次無差別的失敗訊息說不出真正的原因。
if ! command -v claude >/dev/null 2>&1; then
    echo "✗ 找不到 claude 指令。先裝 Claude Code，或確認它在 PATH 裡。"
    exit 1
fi

echo "來源 clone：${REPO}"
echo "目標：${DEST}"
echo

# --- 1. marketplace ---------------------------------------------------------
echo "[1/5] marketplace"
for m in osyuu/skills \
         VeryGoodOpenSource/very_good_claude_marketplace \
         cleydson/flutter-claude-code \
         nextlevelbuilder/ui-ux-pro-max-skill; do
    printf '  %s ... ' "${m}"
    if [ -n "${DRY}" ]; then echo "(dry)"; continue; fi
    if claude plugin marketplace add "${m}" >/dev/null 2>&1; then echo "已加入"; else echo "已存在或失敗（第 5 段會查實際狀態）"; fi
done

# --- 2. plugin --------------------------------------------------------------
# claude-plugins-official 是內建 marketplace，不必先 add。
echo
echo "[2/5] plugin"
for p in ${PLUGINS}; do
    printf '  %s ... ' "${p}"
    if [ -n "${DRY}" ]; then echo "(dry)"; continue; fi
    if claude plugin install "${p}" >/dev/null 2>&1; then echo "OK"; else echo "失敗（第 5 段會查實際狀態）"; fi
done

# --- 3. symlink -------------------------------------------------------------
echo
echo "[3/5] 全域規範與 statusline（symlink）"
link() {
    src="$1"; dst="$2"
    if [ -L "${dst}" ]; then
        cur=$(readlink "${dst}")
        [ "${cur}" = "${src}" ] && { echo "  ${dst} 已指向來源，跳過"; return; }
        # **指向別處的 symlink 也要備份。** 它可能是這台機器自己的 dotfiles 佈線，
        # 直接 ln -sfn 蓋掉是靜默接管——與下面實體檔那條不對稱就是這個洞。
        bak="${dst}.bak-$(date +%Y%m%d-%H%M%S)"
        echo "  ${dst} 是 symlink，指向 ${cur}"
        if [ -n "${DRY}" ]; then echo "    (dry) 會保留舊連結到 ${bak}"; else
            echo "    保留舊連結到 ${bak}"; mv "${dst}" "${bak}"; fi
    elif [ -e "${dst}" ]; then
        bak="${dst}.bak-$(date +%Y%m%d-%H%M%S)"
        if ! diff -q "${dst}" "${src}" >/dev/null 2>&1; then
            echo "  ⚠  ${dst} 是實體檔，且與來源不同。先看過再決定："
            echo "     diff ${bak} ${src}"
        fi
        if [ -n "${DRY}" ]; then echo "  (dry) 會備份到 ${bak}"; else
            echo "  備份到 ${bak}"; mv "${dst}" "${bak}"; fi
    fi
    run mkdir -p "$(dirname "${dst}")"
    run ln -sfn "${src}" "${dst}"
    # **驗它真的是 symlink。** Git Bash 預設把 ln -s 做成複製（除非
    # MSYS=winsymlinks:nativestrict），那正好回到這支腳本要避免的「兩份會漂」。
    if [ -z "${DRY}" ] && [ ! -L "${dst}" ]; then
        echo "  ✗ ${dst} 建出來不是 symlink（Windows/Git Bash 常見）。"
        echo "    設 MSYS=winsymlinks:nativestrict 後重跑，否則它是一份會漂的複本。"
    else
        echo "  ${dst} -> ${src}"
    fi
}
link "${REPO}/bootstrap/CLAUDE.md" "${DEST}/CLAUDE.md"
link "${REPO}/bootstrap/statusline.sh" "${DEST}/statusline.sh"

# --- 4. settings merge ------------------------------------------------------
echo
echo "[4/5] settings.json（合併，不覆蓋 enabledPlugins / extraKnownMarketplaces）"
# **這段失敗不可以殺掉第 5 段。** 壞掉的 settings.json 會讓 json.load 拋例外，
# 而 set -e 會讓整支腳本止在這裡——此時 symlink 已經建好，狀態是半完成，
# 而使用者只看到一段 traceback、看不到任何驗證結果。所以 python 自己吞例外，
# 並且整段用 || true 收尾。
DRY="${DRY}" DEST="${DEST}" REPO="${REPO}" python3 - <<'PYEOF' || true
import json, os, sys

dry = bool(os.environ.get("DRY"))
dest_dir = os.environ["DEST"]
dest = os.path.join(dest_dir, "settings.json")
frag_path = os.path.join(os.environ["REPO"], "bootstrap", "settings.fragment.json")

try:
    frag = json.load(open(frag_path, encoding="utf-8"))
except Exception as e:
    print(f"  ✗ 讀不到片段 {frag_path}：{e}")
    print("    這段跳過，settings 未合併。")
    sys.exit(0)

# statusLine 指向的是部署位置，不是寫死的 ~/.claude——設過 CLAUDE_CONFIG_DIR 的機器
# 若沿用片段裡的字面路徑，statusline 會指到一個不存在的地方。
sl = frag.get("statusLine")
if isinstance(sl, dict) and "command" in sl:
    sl["command"] = os.path.join(dest_dir, "statusline.sh")

try:
    cur = json.load(open(dest, encoding="utf-8")) if os.path.exists(dest) else {}
except Exception as e:
    print(f"  ✗ {dest} 不是合法 JSON（{e}）。")
    print("    這段跳過，settings 未合併——修好它再重跑一次本腳本。")
    sys.exit(0)

changed = []

def same(a, b):
    # 路徑用展開後的形式比：`~/.claude/x` 與 `/Users/me/.claude/x` 是同一個目標，
    # 字面比對會把它們報成衝突，而那種誤報會讓人學會忽略整段輸出。
    if isinstance(a, str) and isinstance(b, str) and ("/" in a or "/" in b):
        return os.path.realpath(os.path.expanduser(a)) == os.path.realpath(os.path.expanduser(b))
    return a == b

def note_conflict(path, mine, theirs):
    changed.append(f"  ! {path}: 本機 {mine!r} vs 來源 {theirs!r} —— 保留本機，要換自己改")

for k, v in frag.items():
    if k not in cur:
        changed.append(f"  + {k}")
        if not dry: cur[k] = v
    elif isinstance(v, dict) and isinstance(cur[k], dict):
        # dict 逐鍵補，**不刪這台機器多出來的**——那可能是本機才有的 skill。
        # 但既存鍵的值衝突要出聲：靜默保留跟「合併成功」在畫面上一樣，而使用者
        # 會以為部署好了（實際踩過：statusLine.command 仍指著舊路徑，
        # 而前一段剛接好的 symlink 根本沒被用到）。
        for kk, vv in v.items():
            if kk not in cur[k]:
                changed.append(f"  + {k}.{kk}")
                if not dry: cur[k][kk] = vv
            elif not same(cur[k][kk], vv):
                note_conflict(f"{k}.{kk}", cur[k][kk], vv)
    elif not same(cur[k], v):
        note_conflict(k, cur[k], v)

if not changed:
    print("  無變更")
else:
    print("\n".join(changed))
    if not dry:
        try:
            tmp = dest + ".tmp"
            os.makedirs(dest_dir, exist_ok=True)
            with open(tmp, "w", encoding="utf-8") as fh:
                json.dump(cur, fh, ensure_ascii=False, indent=2)
            os.replace(tmp, dest)
            print("  已寫入")
        except Exception as e:
            print(f"  ✗ 寫入失敗：{e}")
PYEOF

# --- 5. 驗證 ----------------------------------------------------------------
# **裝了幾支不等於裝對了。** 尤其 mattpocock-skills 承載整條工作流：
# 它失敗而其他都成功時，畫面上跟全部成功一模一樣，直到某支 skill 去叫 grilling 才發現。
echo
echo "[5/5] 驗證"
if [ -n "${DRY}" ]; then
    echo "  (dry，跳過)"
else
    _list=$(claude plugin list 2>/dev/null || true)
    _missing=""
    _disabled=""
    for p in ${PLUGINS}; do
        # **只比對名字不夠**：停用的 plugin 照樣列在 list 裡，只是 Status 變 disabled，
        # 於是「九個都在」會在九個全被停用時照樣印出來（實測確認）。
        # 取名字那行之後的區塊，看它是不是 enabled。
        _st=$(printf '%s\n' "${_list}" | awk -v want="${p}" '
            index($0, want) { found=1; next }
            found && /Status:/ { print; exit }
            found && /❯/ { exit }')
        case "${_st}" in
            "") _missing="${_missing} ${p}" ;;
            *enabled*) : ;;
            *) _disabled="${_disabled} ${p}" ;;
        esac
    done
    if [ -z "${_missing}" ] && [ -z "${_disabled}" ]; then
        echo "  ✓ $(printf '%s\n' ${PLUGINS} | wc -l | tr -d ' ') 個 plugin 都在且已啟用"
    fi
    if [ -n "${_missing}" ]; then
        echo "  ✗ 缺（沒裝上）："
        for m in ${_missing}; do echo "      ${m}"; done
    fi
    if [ -n "${_disabled}" ]; then
        echo "  ✗ 裝了但停用："
        for m in ${_disabled}; do echo "      ${m}  → claude plugin enable ${m%@*}"; done
    fi
    case "${_missing}${_disabled}" in
        *mattpocock-skills*)
            echo
            echo "  ⚠  mattpocock-skills 沒有生效——整條工作流都在它那裡"
            echo "     （/ask-matt 路線圖、grilling、to-spec、implement、code-review）。" ;;
    esac
    if [ -L "${DEST}/CLAUDE.md" ]; then echo "  ✓ CLAUDE.md 是 symlink"; else echo "  ✗ ${DEST}/CLAUDE.md 不是 symlink"; fi

    # **CLAUDE.md 指名的 skill 還在不在。** 上游改名時 Skill 工具呼叫會報錯，但 CLAUDE.md
    # 的散文不會——它只是叫使用者打一個不存在的指令。而那份檔案每個 session 都載入。
    # （量過：那套 skill 幾個月內 11 支有 7 支改過名，而官方 marketplace 釘不了版本。）
    _dead=""
    # 只認反引號包住的 slash command 與限定名——裸的 `/xxx` 會抓到路徑
    # （`conventions/comments.md`、`build/test/run`），那種誤報會讓人學會忽略整段。
    for n in $(grep -oE '`/[a-z][a-z-]+`|mattpocock-skills:[a-z][a-z-]+' "${REPO}/bootstrap/CLAUDE.md" 2>/dev/null \
               | tr -d '`' | sed 's|^mattpocock-skills:||; s|^/||' | sort -u); do
        case "${n}" in
            plugin|tasks|clear|compact|config|help|artifacts|loop|init) continue ;;
        esac
        find "${DEST}/plugins/cache" -type d -name "${n}" 2>/dev/null | grep -q . || _dead="${_dead} ${n}"
    done
    if [ -n "${_dead}" ]; then
        echo "  ⚠  CLAUDE.md 指名但找不到的 skill（可能上游改名了）："
        for d in ${_dead}; do echo "      ${d}"; done
        echo "     散文路線圖的死指標不會報錯，只會叫你打一個不存在的指令。"
    else
        echo "  ✓ CLAUDE.md 指名的 skill 都存在"
    fi
fi

echo
echo "每個新 repo 還要跑一次（產生 code-review 與 setup 自己按路徑讀的 docs/agents/*.md，"
echo "並把 ## Agent skills 區塊注入該 repo 的 CLAUDE.md）："
echo "  /mattpocock-skills:setup-matt-pocock-skills"

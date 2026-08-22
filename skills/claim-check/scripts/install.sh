#!/bin/sh
# claim-check 安裝器：把 Stop hook 佈到使用者層。idempotent。
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ASSETS=$(cd "$HERE/.." && pwd)/assets
DEST="${CLAIM_CHECK_HOME:-$HOME/.claude}"
SETTINGS="$DEST/settings.json"

mkdir -p "$DEST/hooks"
if [ -f "$DEST/hooks/claim-check.py" ]; then
  echo "  ✓ $DEST/hooks/claim-check.py 已存在，不覆蓋（保留你調過的門檻）。"
else
  cp "$ASSETS/claim-check.py" "$DEST/hooks/claim-check.py"
  chmod +x "$DEST/hooks/claim-check.py"
  echo "  ✓ 寫入 $DEST/hooks/claim-check.py"
fi

if python3 - "$SETTINGS" "$DEST" <<'PY'
import json, os, sys
p, dest = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}
hooks = d.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
# **路徑要跟著 DEST 走。** 寫死 ~/.claude 的話，裝到別的家目錄時腳本放 A、註冊指 B，
# hook 靜默不執行——那跟「沒裝」長得一模一樣。
home = os.path.expanduser("~/.claude")
script = os.path.join(dest, "hooks", "claim-check.py")
cmd = "python3 " + ("~/.claude/hooks/claim-check.py" if os.path.realpath(dest) == os.path.realpath(home) else script)
if any(cmd in json.dumps(g, ensure_ascii=False) for g in stop):
    print("  ✓ Stop hook 已註冊，跳過。")
else:
    # **附加而不是取代**：Stop 可能已經掛了別人的 hook，覆蓋掉會靜默停用它。
    stop.append({"hooks": [{"type": "command", "command": cmd}]})
    backed = os.path.exists(p)
    if backed:
        os.replace(p, p + ".bak")
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print("  ✓ 已註冊 Stop hook" + (f"（原檔備份為 {os.path.basename(p)}.bak）" if backed else ""))
PY
then :
else
    # **失敗必須出聲並停下。** 印完 checker 就繼續往下印「後續步驟」，
    # 使用者會以為裝好了，而 hook 從頭到尾沒註冊——那跟沒裝一樣，但更難察覺。
    echo "  ✗ 讀不動 ${SETTINGS}（JSON 壞了？），Stop hook 沒有註冊。修好再重跑。"  # 大括號不可省：$SETTINGS（ 會被當成變數名
    echo "    檔案未被改動。"
    exit 1
fi

cat <<'MSG'

後續（需要判斷，刻意不自動做）：
  1. 先跑 warn 幾天，看 ~/.claude/claim-check.log 的誤判長什麼樣再收緊規則。
     回放既有對話量基準：
       python3 ~/.claude/hooks/claim-check.py --replay <transcript.jsonl>
  2. 誤判降到可接受後才切成擋：export CLAIM_CHECK_BLOCK=1
  3. 規則要對著**你自己的**假話調。別人的樣本沒有用——這份的預設規則是從一個
     424 回合的真實 session 校準出來的，你的說話習慣未必一樣。
MSG

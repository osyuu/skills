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

python3 - "$SETTINGS" <<'PY'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}
hooks = d.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
cmd = "python3 ~/.claude/hooks/claim-check.py"
if any(cmd in json.dumps(g, ensure_ascii=False) for g in stop):
    print("  ✓ Stop hook 已註冊，跳過。")
else:
    # **附加而不是取代**：Stop 可能已經掛了別人的 hook，覆蓋掉會靜默停用它。
    stop.append({"hooks": [{"type": "command", "command": cmd}]})
    os.path.exists(p) and os.replace(p, p + ".bak")
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"  ✓ 已註冊 Stop hook（原檔備份為 {os.path.basename(p)}.bak）")
PY

cat <<'MSG'

後續（需要判斷，刻意不自動做）：
  1. 先跑 warn 幾天，看 ~/.claude/claim-check.log 的誤判長什麼樣再收緊規則。
     回放既有對話量基準：
       python3 ~/.claude/hooks/claim-check.py --replay <transcript.jsonl>
  2. 誤判降到可接受後才切成擋：export CLAIM_CHECK_BLOCK=1
  3. 規則要對著**你自己的**假話調。別人的樣本沒有用——這份的預設規則是從一個
     424 回合的真實 session 校準出來的，你的說話習慣未必一樣。
MSG

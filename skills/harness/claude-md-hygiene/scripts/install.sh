#!/bin/sh
# claude-md-hygiene install —— 註冊一道 PostToolUse hook：agent 改了常駐規範檔之後，
# 請它用本 skill 的判準複查那次編輯。Idempotent。
#
# **先審 CLAUDE.md 再裝**（SKILL.md 的 Phase 1–5）。裝在一份還沒整理的檔案上，
# 第一次編輯就會叫模型去審一堆既有問題，那不是這道 hook 的用途。

set -e
SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ASSETS="$SKILL_DIR/assets"

# 不能用 `[ -d .git ]`：worktree 的 `.git` 是**檔案**。
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "claude-md-hygiene: run from inside a git repo"; exit 1; }
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/hooks

cp "$ASSETS/claude-md-hygiene-hook.py" .claude/hooks/claude-md-hygiene-hook.py
chmod +x .claude/hooks/claude-md-hygiene-hook.py
echo "claude-md-hygiene: .claude/hooks/claude-md-hygiene-hook.py installed"

python3 - <<'PY'
import json, pathlib

p = pathlib.Path(".claude/settings.json")
cmd = "python3 .claude/hooks/claude-md-hygiene-hook.py"
# Bash 要在裡面：session 設定要求「優先用 Bash 改檔」時，Write|Edit 一個都配不到，
# 而失效是靜默的——輸出跟「這次沒動到常駐檔」完全相同。hook 自己會分辨那個 Bash
# 指令有沒有真的寫進常駐檔，所以多收的那些不會變成噪音。
MATCHER = "Write|Edit|Bash"

# **只遷移本安裝器自己寫過的舊值。** `!= MATCHER` 會把使用者設得更寬的
# （`"*"`、或省略 matcher ＝ 配所有工具）也收窄，那是輾掉使用者的決定。
KNOWN_OLD = {"Write|Edit"}

if p.exists():
    try:
        d = json.loads(p.read_text() or "{}")
    except json.JSONDecodeError:
        raise SystemExit("claude-md-hygiene: .claude/settings.json 不是合法 JSON — 未更動，修好再重跑。")
else:
    d = {}

# **附加而不是取代**：PostToolUse 可能已經掛了別人的 hook（formatter、linter），
# 整條覆蓋會靜默停用它們。
# **身分判定要走結構，不能用子字串。** `cmd in json.dumps(e)` 會誤中把指令包起來的
# entry（`echo "python3 …hook.py"`）：那筆被當成自己的，**真正的 hook 從頭到尾沒
# 註冊**，而畫面印的是成功訊息——守門不在、輸出跟裝好了一樣。
def _is_mine(e):
    if not isinstance(e, dict):
        return False
    return any(isinstance(h, dict) and h.get("command") == cmd for h in (e.get("hooks") or []))


entries = d.setdefault("hooks", {}).setdefault("PostToolUse", [])
mine = [e for e in entries if _is_mine(e)]
if not mine:
    entries.append({"matcher": MATCHER, "hooks": [{"type": "command", "command": cmd}]})
    p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    print("claude-md-hygiene: 已註冊 PostToolUse hook（.claude/settings.json）")
else:
    # **不能只在「沒裝過」時才寫。** matcher 改了之後，已裝的 repo 重跑安裝器
    # 若只印「跳過」，修正就永遠到不了它們——而那正是最需要它的那些 repo。
    #
    # 改 matcher 是改**整個 entry**，而一個 entry 可掛多支 command。只含自己那支
    # 時才動——上面守「別停用別人」，這裡守另一半：**別靜默放寬別人**。
    def _alone(e):
        return len(e.get("hooks") or []) == 1

    stale = [e for e in mine if e.get("matcher") in KNOWN_OLD]
    shared = [e for e in stale if not _alone(e)]
    movable = [e for e in stale if _alone(e)]

    if len(mine) > 1:
        # 多筆都是自己時全改同值，會讓互斥的 matcher 變成完全重疊 → 雙重觸發。
        # 這種佈局是人手動改出來的，交還給人決定。
        print("claude-md-hygiene: 偵測到 %d 筆本 hook 的 entry，未自動更動 matcher。" % len(mine))
        print("  → 請自行合併成一筆，或確認它們的 matcher 不重疊。")
    elif movable:
        for e in movable:
            e["matcher"] = MATCHER
        p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
        print("claude-md-hygiene: matcher 已更新為 %s" % MATCHER)
    elif shared:
        print("claude-md-hygiene: 本 hook 與其他 command 共用同一筆 entry，未更動 matcher。")
        print("  → 改它會連帶放寬同筆的其他 hook。請把本 hook 拆成獨立 entry 再重跑。")
    else:
        print("claude-md-hygiene: PostToolUse hook 已註冊，跳過。")
PY

echo
echo "Next (agent / you):"
echo "  1. .claude/settings.json 與 .claude/hooks/ 要進版控，否則只有你這台生效。"
echo "  2. hook 只在**這個 session 之後開的 session** 生效——現在這個讀不到新設定。"
echo "  3. 驗一次：新開 session 用 **Bash** 改 CLAUDE.md（例如 printf x >> CLAUDE.md），"
echo "     看模型有沒有被要求複查。用 Edit 改只驗得到舊的那半，matcher 改回 Write|Edit 也會過。"

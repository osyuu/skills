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

if p.exists():
    try:
        d = json.loads(p.read_text() or "{}")
    except json.JSONDecodeError:
        raise SystemExit("claude-md-hygiene: .claude/settings.json 不是合法 JSON — 未更動，修好再重跑。")
else:
    d = {}

# **附加而不是取代**：PostToolUse 可能已經掛了別人的 hook（formatter、linter），
# 整條覆蓋會靜默停用它們。
entries = d.setdefault("hooks", {}).setdefault("PostToolUse", [])
mine = [e for e in entries if cmd in json.dumps(e)]
if not mine:
    entries.append({"matcher": MATCHER, "hooks": [{"type": "command", "command": cmd}]})
    p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    print("claude-md-hygiene: 已註冊 PostToolUse hook（.claude/settings.json）")
else:
    # **不能只在「沒裝過」時才寫。** matcher 改了之後，已裝的 repo 重跑安裝器
    # 若只印「跳過」，修正就永遠到不了它們——而那正是最需要它的那些 repo。
    stale = [e for e in mine if e.get("matcher") != MATCHER]
    if stale:
        for e in stale:
            e["matcher"] = MATCHER
        p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
        print("claude-md-hygiene: matcher 已更新為 %s" % MATCHER)
    else:
        print("claude-md-hygiene: PostToolUse hook 已註冊，跳過。")
PY

echo
echo "Next (agent / you):"
echo "  1. .claude/settings.json 與 .claude/hooks/ 要進版控，否則只有你這台生效。"
echo "  2. hook 只在**這個 session 之後開的 session** 生效——現在這個讀不到新設定。"
echo "  3. 驗一次：新開 session 改一行 CLAUDE.md，看模型有沒有被要求複查。"

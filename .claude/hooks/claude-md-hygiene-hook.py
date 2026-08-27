#!/usr/bin/env python3
"""PostToolUse hook：agent 改了常駐規範檔之後，請它用 claude-md-hygiene 的判準複查那次編輯。

取代原本的正規表達式詞表。詞表量到的成績是漏抓 67%、誤報 25%，而且兩種錯都無法
靠再加樣式收斂——「不准留 TODO」是規則、「TODO: 接上重試」是狀態，差別在語意不在字面。
判斷交給已經在場的模型，偵測留給機械：只比對檔名，不猜內容。

迴圈防護：同一個 session 對同一個檔只注入一次。沒有它的話，複查若順手改了那個檔
就會再觸發一次，而 hook 文件沒有提供任何內建防護。
"""
import hashlib
import json
import os
import pathlib
import sys

WATCHED = {"CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", ".claude.local.md"}

MESSAGE = (
    "你剛編輯了常駐規範檔 {name}。它每個 session 都會被載入，而沒有任何測試會證偽它——"
    "混進去的當期狀態不會有人發現，下一個 agent 會照著過期的宣稱工作。\n"
    "用 claude-md-hygiene 的判準複查**這次的改動**（只看這次，不要重審整份）：\n"
    "1. 有沒有寫進完成態、日期戳、測試數、版本號，或任何會被下一次改動證偽的斷言？\n"
    "2. 那些屬於活文件（進度／決策記錄／設計書），這裡只留一句指標。\n"
    "3. 提到的 symbol、路徑、旗標現在還存在嗎？行為主張現在還成立嗎？\n"
    "確認沒問題就繼續，不必回報。"
)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    # 型別一律不信任：payload 是外部給的，而 hook 炸掉會干擾工具流程。
    # `or {}` 擋不住「tool_input 是字串」——非空字串為真，接著 .get 就爆。
    if not isinstance(payload, dict):
        return 0
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return 0
    path = tool_input.get("file_path")
    if not isinstance(path, str):
        return 0
    name = os.path.basename(path)
    if name not in WATCHED:
        return 0

    # 迴圈防護只在拿得到 session_id 時做。退回一個固定的代用 key 會讓**所有**
    # session 共用同一個 stamp，而 stamp 不過期——那個檔案從此在每個 session 都
    # 靜音，畫面上跟「這次沒有要複查」完全一樣。寧可多吵一次，不要靜默停用。
    # 路徑取絕對值：相對與絕對寫法指同一個檔，否則同一次編輯會開火兩次。
    session = payload.get("session_id")
    if isinstance(session, str) and session:
        key = hashlib.sha256(f"{session}:{os.path.abspath(path)}".encode()).hexdigest()[:16]
        stamp = pathlib.Path(os.environ.get("TMPDIR", "/tmp")) / "claude-md-hygiene" / key
        if stamp.exists():
            return 0
        stamp.parent.mkdir(parents=True, exist_ok=True)
        stamp.touch()

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": MESSAGE.format(name=name),
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

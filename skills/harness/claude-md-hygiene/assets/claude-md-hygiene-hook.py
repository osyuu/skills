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
import re
import sys

WATCHED = {"CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", ".claude.local.md"}

# **樣式由 WATCHED 導出，不要另抄一份清單。** 兩份會漂，而漂走的那半靜默失效。
# 長的排前面：`.claude.local.md` 與 `CLAUDE.local.md` 互為對方的後綴。
_NAMES = "|".join(re.escape(n) for n in sorted(WATCHED, key=len, reverse=True))

# Bash 改檔一律配不到 matcher 的 Write|Edit，而「優先用 Bash 改檔」是常見的
# session 設定——那時這道守門靜默失效，輸出跟「這次沒動到常駐檔」一模一樣。
#
# **只認寫進去的形狀，不認單純提到檔名**：`cat CLAUDE.md`、`grep x CLAUDE.md`、
# `git add CLAUDE.md` 都不該開火，而它們比真正的改動常見得多。
# 管道與 `;`／`&&` 用 `[^;&|]*` 斷開，避免 `cat CLAUDE.md | tee other.md` 誤中。
RE_BASH_WRITE = re.compile(
    r">>?\s*[^\s;&|]*(?:{n})\b"
    r"|(?:sed\s+-i|tee|cp|mv|install)\b[^;&|]*?(?:{n})\b".format(n=_NAMES)
)
# heredoc 裡的 python 寫檔。**要求檔名出現在開檔呼叫的引數位置**，不是「兩者
# 都在這包指令裡就算」——後者實測誤報：`git commit` 的訊息裡提到 CLAUDE.md，
# 同一次呼叫又有個寫別的檔的 write_text，就會開火。而在這個 repo 裡「訊息提到
# 常駐檔 + 順手改別的檔」是常態，不是離群值。
#
# 代價明講：**經過變數間接的寫檔抓不到**（`sub("CLAUDE.md", …)` 而 sub 內部才
# `Path(path).write_text()`）。選這邊是因為誤報會讓人關掉整個 hook，漏抓只是
# 回到裝之前——claim-check 的註解對同一個取捨也是這個方向。
RE_PY_WRITE = re.compile(
    r"(?:Path|open)\s*\(\s*[\"'][^\"']*(?:{n})".format(n=_NAMES)
)
RE_NAME = re.compile(_NAMES)

MESSAGE = (
    "你剛編輯了常駐規範檔 {name}。它每個 session 都會被載入，而沒有任何測試會證偽它——"
    "混進去的當期狀態不會有人發現，下一個 agent 會照著過期的宣稱工作。\n"
    "用 claude-md-hygiene 的判準複查**這次的改動**（只看這次，不要重審整份）：\n"
    "1. 有沒有寫進完成態、日期戳、測試數、版本號，或任何會被下一次改動證偽的斷言？\n"
    "2. 那些屬於活文件（進度／決策記錄／設計書），這裡只留一句指標。\n"
    "3. 提到的 symbol、路徑、旗標現在還存在嗎？行為主張現在還成立嗎？\n"
    "確認沒問題就繼續，不必回報。"
)


def _bash_target(command):
    """Bash 指令有沒有把某個常駐規範檔寫掉；有就回那個檔名。"""
    if not isinstance(command, str):
        return None
    m = RE_BASH_WRITE.search(command)
    if m:
        hit = RE_NAME.search(m.group(0))
        return hit.group(0) if hit else None
    if RE_PY_WRITE.search(command):
        hit = RE_NAME.search(command)
        return hit.group(0) if hit else None
    return None


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
    if isinstance(path, str):
        name = os.path.basename(path)
        if name not in WATCHED:
            return 0
    else:
        name = _bash_target(tool_input.get("command"))
        if name is None:
            return 0
        path = name

    # 迴圈防護只在拿得到 session_id 時做。退回一個固定的代用 key 會讓**所有**
    # session 共用同一個 stamp，而 stamp 不過期——那個檔案從此在每個 session 都
    # 靜音，畫面上跟「這次沒有要複查」完全一樣。寧可多吵一次，不要靜默停用。
    # 路徑取絕對值：相對與絕對寫法指同一個檔，否則同一次編輯會開火兩次。
    session = payload.get("session_id")
    if isinstance(session, str) and session:
        key = hashlib.sha256(f"{session}:{os.path.abspath(path)}".encode()).hexdigest()[:16]
        stamp = pathlib.Path(os.environ.get("TMPDIR", "/tmp")) / "claude-md-hygiene" / key
        # stamp 寫不進去（TMPDIR 唯讀、磁碟滿）時退化成每次都開火。這裡讓例外逃出去
        # 會讓整個 PostToolUse 失敗，而它守的只是「同一個 session 別重複吵」。
        try:
            if stamp.exists():
                return 0
            stamp.parent.mkdir(parents=True, exist_ok=True)
            stamp.touch()
        except OSError:
            pass

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

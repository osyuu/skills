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
# 排序是為了未來加入互為後綴的名字；現況下大小寫不同，它是 no-op。
_NAMES = "|".join(re.escape(n) for n in sorted(WATCHED, key=len, reverse=True))

# 右界不能用 `\b`：`CLAUDE.md.bak` 後面接 `.`，`\b` 在那裡成立，備份檔會被當成本尊。
_N = r"(?:{n})(?![\w.])".format(n=_NAMES)

# Bash 改檔一律配不到 matcher 的 Write|Edit，而「優先用 Bash 改檔」是常見的
# session 設定——那時這道守門靜默失效，輸出跟「這次沒動到常駐檔」一模一樣。
#
# **只認寫進去的形狀，不認單純提到檔名**——`cat` / `grep` / `git add` 比真正的改動常見得多。
# `\n` 要跟 `;&|` 一起當分隔符，否則多行 script 裡「前面有 cp、後面提到檔名」就中。
# cp/mv 的檔名要在指令段結尾（＝目的地），否則 `cp CLAUDE.md /tmp/bak/` 這種備份會中。
# **不要加 `install` 分支**：它抓得到的量遠小於 `pip install` / `npm install` 誤中的量。
RE_BASH_WRITE = re.compile(
    r">>?\s*(?:[^\s;&|\n]*/)?{N}"
    # 這裡要貪婪：lazy 會停在第一個名字，而第一個常在 sed 樣式裡。
    r"|(?:sed\s+-i\S*|tee)\b[^;&|\n]*{N}"
    r"|(?:cp|mv)\s+[^;&|\n]*?{N}\s*(?:$|[;&|\n])".format(N=_N)
)

# heredoc 裡的 python 寫檔：**檔名要在開檔呼叫的引數位置，且整段要有寫入動詞。**
# 放寬成「檔名與 write_text 都在這包指令裡」會中「commit 訊息提到常駐檔＋順手改別的檔」，
# 而那在寫 harness 的 repo 是常態。動詞那半擋的是 `Path("CLAUDE.md").read_text()`。
# **代價**：經過變數間接的寫檔抓不到。誤報會讓人關掉整個 hook，漏抓只是回到裝之前。
RE_PY_TARGET = re.compile(
    r"(?:Path|open)\s*\(\s*f?[\"'][^\"']*{N}"     # Path("CLAUDE.md") / open(f"…CLAUDE.md")
    r"|/\s*f?[\"'][^\"']*{N}".format(N=_N)          # Path(d) / "CLAUDE.md"
)
RE_PY_VERB = re.compile(r"write_text|write_bytes|writelines|[\"']\s*[wa][b+]?[\"']")
RE_NAME = re.compile(_N)

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
    """Bash 指令有沒有把某個常駐規範檔寫掉；有就回**被寫的那個**檔名。

    取最後一個而非第一個：`sed -i '' 's/CLAUDE.md/X/' AGENTS.md` 的第一個在樣式裡。
    """
    if not isinstance(command, str):
        return None
    m = RE_BASH_WRITE.search(command)
    if m:
        hits = RE_NAME.findall(m.group(0))
        return hits[-1] if hits else None
    if RE_PY_TARGET.search(command) and RE_PY_VERB.search(command):
        hits = RE_NAME.findall(command)
        return hits[-1] if hits else None
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
        command = tool_input.get("command")
        name = _bash_target(command)
        if name is None:
            return 0
        # **key 不能跟 Write/Edit 那側撞**：撞了的話一次 Bash 誤報就燒掉該檔的
        # 迴圈防護，之後真正的 Edit 靜音。按指令下 key，誤報只吵它自己那一次。
        path = "bash:" + command

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

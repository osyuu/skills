#!/usr/bin/env python3
"""claim-check —— 讓「我說我做了」與「我實際做了」對得起來。

掛在 Stop 事件（我講完話的那一刻）。拿得到我剛講的那段話，以及這一回合實際發出的
每一次工具呼叫，兩邊對。

**它守的不是 code，是敘述。** code 那側已經有編譯器、測試、四道 pre-commit hook；
而「正在跑」「驗過了」「因為那個檔是這樣寫的」這類話沒有任何東西在看，於是只能靠
使用者發現——那是最貴的偵測方式。

模式：
  預設 warn（記進 log、印 stderr、exit 0）。CLAIM_CHECK_BLOCK=1 才 exit 2 擋下回合。
  先 warn 幾天量誤判率再收緊，理由同 comment-budget：對七成回合開火＝噪音，會被學會忽略。

回放（驗收用，不經過 hook）：
  python3 claim-check.py --replay <transcript.jsonl> [起始回合]
"""
import json
import os
import re
import sys
import datetime

LOG = os.path.expanduser("~/.claude/claim-check.log")

# ── 規則：宣稱樣式 → 這一回合必須存在的證據 ──────────────────────────────
#
# 每條都要能只用「工具呼叫紀錄」判定。判不了的（例如「這個設計比較好」）不寫進來——
# 加一條抓不準的規則，代價是整個機制被學會忽略。

def _is_bash(c):
    return c["name"] == "Bash"


def _cmd(c):
    return str(c["input"].get("command", "")) if _is_bash(c) else ""


def _touched(calls):
    """這一回合碰過的路徑與指令字串——判斷「有沒有去看正在下結論的那個東西」。"""
    out = []
    for c in calls:
        i = c["input"]
        out += [str(i.get(k, "")) for k in ("file_path", "command", "pattern", "path", "query")]
    return " \n".join(out)


# ── 規則：宣稱 → 這個 session 裡必須成立的事 ────────────────────────────
#
# **不是「這一回合有沒有跑」。** 實測 424 回合，那樣寫有 23% 開火，而絕大多數是我在
# 引用前幾回合真的跑出來的結果——那些不是假話。真正的不變式是「**跑完之後有沒有再改過**」：
#
#   測試綠 → 最後一次跑測試**之後**沒有 Edit/Write
#   build 過 → 同上
#   正在跑 → 這個 session 裡真的啟動過背景工作／agent
#
# 這條順帶蓋住一個踩過的坑：還原注入的故障後沒重建就跑 test-without-building，
# 拿到的是舊 binary 的結果（記在 feedback_hollow_tests）。

RE_TEST = re.compile(r"test-without-building|tests/run\.sh|xcodebuild.*\btest\b|pytest|npm test")
RE_BUILD = re.compile(r"xcodebuild|swift build")
RE_GIT = re.compile(r"git (commit|merge)")
# 背景宣稱的時效：多少個事件內啟動過才算數。實測「audit 還在跑」那次，最近一次
# 背景啟動在 51 個事件前（10 個回合，早已收工）；正常的「還在跑」都緊接在 spawn 後幾個事件內。
BG_WINDOW = 25


def _index(calls):
    """把整個 session 到本回合為止的關鍵事件位置抓出來。"""
    ix = {"test": -1, "build": -1, "edit": -1, "git": -1, "bg": -1, "read": -1}
    for n, c in enumerate(calls):
        cmd = _cmd(c)
        if c["name"] in ("Edit", "Write", "NotebookEdit"):
            ix["edit"] = n
        if c["name"] in ("Read", "Grep", "Glob") or (_is_bash(c) and re.search(r"grep|sed -n|cat |head |tail ", cmd)):
            ix["read"] = n
        if RE_TEST.search(cmd):
            ix["test"] = n
        if RE_BUILD.search(cmd):
            ix["build"] = n
        if RE_GIT.search(cmd):
            ix["git"] = n
        if c["input"].get("run_in_background") or c["name"] in ("Agent", "Workflow"):
            ix["bg"] = n
    return ix


def _fresh(ix, kind):
    """跑過，而且跑完之後沒有再動過 code。"""
    return ix[kind] >= 0 and ix[kind] > ix["edit"]


RULES = [
    # 背景工作會跨回合活著，所以不能只看本回合；但也不能看整個 session——
    # 十個回合前啟動、早就收工的 agent，不能拿來當「現在正在跑」的證據。
    ("背景執行",
     r"(正在跑|還在跑|已經在跑|在背景|背景跑)",
     lambda ix: ix["bg"] >= 0 and ix["bg"] >= ix["_now"] - BG_WINDOW,
     "說了有東西在跑，但最近沒有啟動過背景工作或 agent"),

    ("測試",
     r"(測試綠|全套測試(都)?(綠|過)|測試通過|全綠|沒有失敗)",
     lambda ix: _fresh(ix, "test"),
     "說了測試是綠的，但最後一次跑測試之後又改過 code（或根本沒跑過）"),

    ("build",
     r"(build 過|編譯過|編得過|兩個 target|BUILD SUCCEEDED|build 成功)",
     lambda ix: _fresh(ix, "build"),
     "說了 build 結果，但最後一次 build 之後又改過 code（或根本沒 build 過）"),

    ("版控",
     r"(已經? ?commit|commit 了|commit 完|已經? ?merge|merge 完|進版控了)",
     lambda ix: ix["git"] >= 0,
     "說了 commit/merge 已經做了，但這個 session 沒有跑過 git commit/merge"),

    ("注入故障",
     r"(注入故障|故障注入)",
     lambda ix: ix["test"] >= 0 and ix["edit"] >= 0,
     "說了注入故障，但沒有『改動 + 跑測試』的組合"),
]

# 被質疑的訊號。這種回合最容易生一段理由來守住已經講出口的結論。
CHALLENGE = re.compile(r"(為何|為什麼|不對|不懂|搞錯|明明|會對不上|真的嗎|你確定|矛盾|亂扯|說謊)")

# 我點名的東西：反引號裡的 CamelCase 或含底線的識別字，以及 .swift 檔名。
NAMED = re.compile(r"`([A-Z][A-Za-z0-9_]{5,}|[a-z][A-Za-z0-9_]*_[A-Za-z0-9_]+)`|(\b[A-Z][A-Za-z0-9]+\.swift\b)")


def check(events: list, user_text: str) -> list:
    """events = 到本回合結束為止、依序的 ("text", str) 與 ("tool", {...})。

    **逐段判而不是整段判。** 同一回合裡常常是「先跑測試 → 報告結果 → 接著改下一處」，
    整段判會把後面那次 Edit 當成「宣稱之後又改過」，而宣稱在寫下的當下是真的。
    交錯的順序在紀錄裡是保留的，所以拿宣稱自己的位置去比才對。
    """
    findings = []
    calls = []
    for kind, payload in events:
        if kind == "tool":
            calls.append(payload)
            continue
        ix = _index(calls)
        ix["_now"] = len(calls)
        for name, pat, ok, why in RULES:
            if re.search(pat, payload) and not ok(ix):
                f = f"[{name}] {why}"
                if f not in findings:
                    findings.append(f)
    message = "".join(p for k, p in events if k == "text")

    # 被質疑之後，對「這回合沒去看過的東西」下技術結論。
    #
    # **不是「有沒有讀東西」而是「有沒有讀你正在講的那個東西」**——實測踩過的那次，
    # 該回合讀了兩個檔，但下結論的對象是第三個檔，從頭到尾沒打開過。
    if CHALLENGE.search(user_text or ""):
        touched = _touched(calls)
        named = {m[0] or m[1] for m in NAMED.findall(message)}
        unseen = sorted(n for n in named if n and n not in touched)
        if unseen:
            findings.append(
                "[質疑後未查證] 被質疑後對這回合沒看過的東西下結論：" + "、".join(unseen[:5]))
    return findings


def events_upto(rows, end_idx):
    """把紀錄攤平成依序的 ("text", str) / ("tool", {name,input})，只取到 end_idx。"""
    out = []
    for r in rows[:end_idx]:
        if r.get("type") != "assistant":
            continue
        for c in (r.get("message", {}).get("content") or []):
            if not isinstance(c, dict):
                continue
            if c.get("type") == "text" and c.get("text", "").strip():
                out.append(("text", c["text"]))
            elif c.get("type") == "tool_use":
                out.append(("tool", {"name": c.get("name"), "input": c.get("input") or {}}))
    return out


def turn_bounds(rows):
    starts, seen = [], None
    for i, r in enumerate(rows):
        pid = r.get("promptId")
        if pid and pid != seen:
            starts.append(i)
            seen = pid
    return starts


def turn_calls(rows, start_idx):
    """從某個 user 紀錄起算，到下一個 promptId 為止的所有工具呼叫。"""
    calls, pid = [], rows[start_idx].get("promptId")
    for r in rows[start_idx:]:
        if r.get("promptId") and r["promptId"] != pid:
            break
        if r.get("type") != "assistant":
            continue
        for c in (r.get("message", {}).get("content") or []):
            if isinstance(c, dict) and c.get("type") == "tool_use":
                calls.append({"name": c.get("name"), "input": c.get("input") or {}})
    return calls


def text_of(r):
    m = r.get("message") or {}
    c = m.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return "".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
    return ""


def replay(path, start=0):
    rows = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    starts = turn_bounds(rows)
    fired = 0
    for ti, si in enumerate(starts):
        end = starts[ti + 1] if ti + 1 < len(starts) else len(rows)
        if ti < start:
            continue
        ev = events_upto(rows, end)
        # 只評本回合寫下的文字，但狀態要看得到之前所有工具呼叫
        cut = len(events_upto(rows, si))
        scoped = ev[:cut] + [(k, p) for k, p in ev[cut:]]
        turn_text = "".join(p for k, p in ev[cut:] if k == "text")
        if not turn_text.strip():
            continue
        found = check_scoped(scoped, cut, text_of(rows[si]))
        if found:
            fired += 1
            print(f"── 回合 #{ti}")
            for f in found:
                print(f"     {f}")
    print(f"\n{len(starts)} 個回合，{fired} 個開火（{fired * 100 // max(1, len(starts))}%）")


def check_scoped(events, cut, user_text):
    """只把 cut 之後的文字段當成本回合的宣稱，之前的僅用來累積狀態。"""
    findings, calls = [], []
    for n, (kind, payload) in enumerate(events):
        if kind == "tool":
            calls.append(payload)
            continue
        if n < cut:
            continue
        ix = _index(calls)
        ix["_now"] = len(calls)
        for name, pat, ok, why in RULES:
            if re.search(pat, payload) and not ok(ix):
                f = f"[{name}] {why}"
                if f not in findings:
                    findings.append(f)
    message = "".join(p for k, p in events[cut:] if k == "text")
    if CHALLENGE.search(user_text or ""):
        touched = _touched([p for k, p in events[cut:] if k == "tool"])
        named = {m[0] or m[1] for m in NAMED.findall(message)}
        unseen = sorted(n for n in named if n and n not in touched)
        if unseen:
            findings.append("[質疑後未查證] 被質疑後對這回合沒看過的東西下結論：" + "、".join(unseen[:5]))
    return findings


def main():
    if "--replay" in sys.argv:
        i = sys.argv.index("--replay")
        replay(sys.argv[i + 1], int(sys.argv[i + 2]) if len(sys.argv) > i + 2 else 0)
        return
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    msg = payload.get("last_assistant_message") or ""
    path = payload.get("transcript_path")
    if not msg or not path or not os.path.exists(path):
        return
    rows = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    pid = payload.get("prompt_id")
    si = next((i for i, r in enumerate(rows) if r.get("promptId") == pid), None)
    if si is None:
        return
    ev = events_upto(rows, len(rows))
    cut = len(events_upto(rows, si))
    # hook 給的 last_assistant_message 才是權威——Stop 觸發時最後一段未必已經落進紀錄。
    if not any(k == "text" and msg.strip() in p for k, p in ev[cut:]):
        ev.append(("text", msg))
    found = check_scoped(ev, cut, text_of(rows[si]))
    if not found:
        return
    stamp = datetime.datetime.now().isoformat(timespec="seconds")
    with open(LOG, "a", encoding="utf-8") as fh:
        for f in found:
            fh.write(f"{stamp}\t{payload.get('session_id','?')[:8]}\t{f}\n")
    sys.stderr.write("⚠  claim-check：\n" + "".join(f"    {f}\n" for f in found))
    sys.exit(2 if os.environ.get("CLAIM_CHECK_BLOCK") == "1" else 0)


if __name__ == "__main__":
    main()

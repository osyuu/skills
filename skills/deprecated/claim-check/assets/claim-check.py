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
from pathlib import Path
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

def _warn(msg):
    """conf 壞掉必須出聲。靜默退回內建等於「你補的那個生態不見了」而畫面沒變。"""
    sys.stderr.write("⚠  claim-check：" + msg + "\n")


def _conf():
    """讀覆寫檔,依序:cwd 的 `hooks/`、腳本自己的上一層、使用者層。先到先得。

    格式 `KEY=value`,一行一個,`#` 起頭是註解,` #` 之後是行內註解。

    **空值不登錄。** `setdefault` 對「存在但空」一樣算數,而模板是整份含全部 key 的
    ——把模板複製到 repo 就會讓 repo 那份的空值蓋掉使用者層填好的每一項,而工具鏈那半
    會變成恆開火、宣稱那半變成恆不開火。
    """
    out = {}
    # **conf 要跟著腳本走。** `CLAIM_CHECK_HOME` 只在安裝期存在,hook 執行期沒有——
    # 裝到非 `~/.claude` 的位置時,安裝器寫的那份 conf 永遠讀不到,而失效方向正是
    # 「宣稱詞表恆不開火」。所以也找腳本自己的上一層。
    override = os.environ.get("CLAIM_CHECK_HOME")
    # `beside` **只在沒有明確覆寫時才找**:它是為了 hook 執行期(那時沒有環境變數)
    # 而存在的。無條件加進來的話,把 `CLAIM_CHECK_HOME` 指向空目錄的隔離會被它打穿
    # ——測試改用部署副本時就會讀到真實使用者的 conf,跟 GIT_DIR 是同一個形狀。
    cands = [Path("hooks/claim-check.conf")]
    if not override:
        cands.append(Path(__file__).resolve().parent.parent / "claim-check.conf")
    cands.append(Path(override or Path.home() / ".claude") / "claim-check.conf")
    for path in cands:
        try:
            for line in path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                # 行內註解。模板每個 key 上一行都寫著 `# 例:…`,補在同一行是很自然的
                # 寫法,而整段被吃進 pattern 之後那個 key 就靜默失效了。
                # 要求 `#` 前面有空白,否則 regex 裡的 `#` 會被咬掉。
                v = re.split(r"\s+#", v, maxsplit=1)[0].strip().strip("'\"")
                if v:
                    out.setdefault(k.strip(), v)
        except OSError:
            continue
    return out


CONF = _conf()


def _re(builtin, key):
    """內建清單 **附加** conf 裡那些,不是取代。

    取代的話,補一個生態就會靜默砍掉其他生態。而內建這幾張表只涵蓋少數幾個生態,
    漏掉時的失效是靜默的:認不得這個 repo 的指令,規則就不管跑沒跑都判「沒跑過」,
    輸出與事實無關。**補在 conf 裡,不要改這個檔**——改這裡的人下次同步就沒了。
    """
    return re.compile(_re_src(builtin, key))


def _re_src(builtin, key):
    """同上，但回傳字串——要嵌進更大的 pattern 時用（NAMED 的副檔名那段）。

    **壞掉的 conf 值只能廢掉它自己那一條。** 這裡不接住的話 `re.compile` 會在 import
    期 raise,整支 hook 連同其他規則一起死——而 Stop hook 死掉跟沒裝一樣看不出來。
    會踩到的正好是那些真的去編 conf 的人。
    """
    extra = CONF.get(key, "").strip()
    if not extra:
        return builtin
    try:
        # 配得到空字串的 pattern(尾端多一個 `|`,複製貼上很容易留)會對每一段文字開火。
        if re.compile(extra).match(""):
            raise re.error("配得到空字串")
        re.compile(builtin + "|" + extra)
    except re.error as exc:
        _warn(f"conf 的 {key} 用不了（{exc}），這次退回內建清單")
        return builtin
    return builtin + "|" + extra


RE_TEST = _re(
    r"test-without-building|tests/run\.sh|xcodebuild.*\btest\b|pytest|npm test"
    r"|swift test|cargo test|go test|dotnet test"
    # Flutter/Dart：**漏了這行等於這條規則在 Flutter 專案永遠開火**——跑了也認不得，
    # 判定恒為「沒跑過」，輸出與事實無關。
    #
    # **前面的 lookbehind 不能拿掉**：`.dart` 是這個生態最常見的副檔名，少了它，
    # `git add a.dart test/b.dart` 會被當成跑過測試——而那正好發生在準備 commit 的
    # 那一刻，「測試綠」這句話最貴的時候，且失敗是**靜默**的（該開火的不開火）。
    r"|(?<![\w.])(?:flutter|dart|very_good)\s+test\b",
    "CLAIM_TEST_RE")
RE_BUILD = _re(
    # 尾端用 (?![\w.]) 而非 \b：`cat xcodebuild.log` 的 \b 照樣成立（後面是 `.`），
    # 只有明確排除 `.` 才擋得掉讀 log 檔那類。
    r"(?<![\w.])(?:xcodebuild|swift\s+build|flutter\s+build|dart\s+compile)(?![\w.])"
    # 同一個生態常有兩條並行的 build 路徑(桌面/行動、debug/release),只認一條就只覆蓋一半。
    # **這張表仍是一份會過期的清單**:JVM 的 `mvn package`、Node 的 `npm run build`、
    # Rust/Go 的 `cargo build`/`go build`、`make`、`dotnet build` 目前都不在,在那些 repo 上
    # 「build 過」會恆誤報。要治本得把工具鏈移進 per-repo conf,不是把表加長。
    r"|gradlew\s+\S*(?:assemble|bundle)",
    "CLAIM_BUILD_RE")
# `git push` 也算:這條規則現在把 `pushed to …` 當一級宣稱形狀,證據那側要跟上。
RE_GIT = re.compile(r"git (commit|merge|push)")
# 改動不是只有 Edit/Write。有些 session 明確要求優先用 Bash 改檔（sed -i、heredoc、
# python3 寫檔），那時只認工具名等於整條「跑完之後有沒有再動過 code」失效——實測一個
# 全程用 Bash 的 session，7 次「注入故障」開火全是這樣來的誤判。
# 要求副檔名，所以 `> /dev/null` 這類不會誤中。
RE_BASH_MUTATE = _re(
    r"sed -i|>>?\s*[\w./~-]+\.(swift|dart|py|sh|md|json|ya?ml|conf|txt|plist|toml)"
    r"|write_text|cat\s*>|tee\s"
    # 這幾個會改 code 卻不長得像寫檔：codegen 重生 *.g.dart/*.freezed.dart，
    # format/fix 直接重排原檔。漏了它們，「跑測試 → codegen → 說測試綠」不會開火。
    #
    # **詞界與完整指令形式都不能省**：少了 lookbehind，`git add a.dart format_x.dart`
    # 與 `dart analyze x.dart fixtures/` 會被當成改過 code；只寫 `build_runner`/`slang`
    # 則 `grep build_runner` 也算數。方向是誤報，但誤報一樣會讓人關掉整個 hook。
    # 唯讀形式要排除：`--output=none --set-exit-if-changed` 是 CI 的格式檢查、
    # `--dry-run` 是預覽,兩者都不改檔。誤判成改過 code 會讓緊接著的「測試綠」誤報,
    # 而那正是它們最常出現的位置——宣稱前的最後一道驗證。
    r"|(?<![\w.])dart\s+(?:format|fix)\b"
    r"(?![^\n]*(?:--output=none|--set-exit-if-changed|--dry-run))"
    r"|build_runner\s+(?:build|watch)|(?:dart|flutter)\s+(?:pub\s+)?run\s+slang",
    "CLAIM_MUTATE_RE")
# **兩個已知擋不住的**（別以為 regex 修得掉）：
#   1. 字面量出現在參數或 heredoc 內文一樣算數——`grep -rn "flutter test"`、
#      `git commit -m "ci: run flutter test"`、寫進檔案的文件字串，都會被當成跑過。
#      要真修得先把引號字串與 heredoc body 從 command 剝掉再比對。
#   2. 經 MCP 工具或 sub-agent 跑的測試看不到（tool_use 沒有 command 欄位），
#      方向是誤報「沒跑過」。
#
# 背景宣稱的時效：多少個事件內啟動過才算數。實測「audit 還在跑」那次，最近一次
# 背景啟動在 51 個事件前（10 個回合，早已收工）；正常的「還在跑」都緊接在 spawn 後幾個事件內。
BG_WINDOW = 25


def _index(calls):
    """把整個 session 到本回合為止的關鍵事件位置抓出來。"""
    ix = {"test": -1, "build": -1, "edit": -1, "git": -1, "bg": -1, "read": -1}
    for n, c in enumerate(calls):
        cmd = _cmd(c)
        if c["name"] in ("Edit", "Write", "NotebookEdit") or (_is_bash(c) and RE_BASH_MUTATE.search(cmd)):
            ix["edit"] = n
        if c["name"] in ("Read", "Grep", "Glob") or (_is_bash(c) and re.search(r"grep|sed -n|cat |head |tail ", cmd)):
            ix["read"] = n
        if RE_TEST.search(cmd):
            ix["test"] = n
        if RE_BUILD.search(cmd):
            ix["build"] = n
        if RE_GIT.search(cmd):
            ix["git"] = n
        # 還在跟 agent 通訊 = 它還活著。長對話裡 spawn 之後隔幾十個事件仍在等它是常態。
        if c["input"].get("run_in_background") or c["name"] in ("Agent", "Workflow", "SendMessage"):
            ix["bg"] = n
    return ix


def _fresh(ix, kind):
    """跑過，而且跑完之後沒有再動過 code。

    用 >= 而非 >：`改一行 && 跑測試` 寫在同一個 Bash 呼叫裡是常見寫法（mutation
    測試尤其如此——改、跑、還原全在一行），在事件索引上兩者是同一個位置，用 > 會
    把它判成「改完沒跑」。真陽性不受影響：跑完之後才改的，edit 的位置仍然在後面。
    """
    return ix[kind] >= 0 and ix[kind] >= ix["edit"]


# ── 宣稱詞表 ──────────────────────────────────────────────────────────────
# 失效方向是**恆不開火**:清單裡沒有的說法,輸出與「這個 session 很誠實」一模一樣,
# 不會有人來回報。內建中英兩種,其餘語言與團隊自己的口頭禪靠 conf 補
# (`CLAIM_*_CLAIM_RE`,附加不取代,見 conf 模板)。
#
# 英文一律要求**帶受詞或帶狀態詞**(`fixed it` 而不是 `fixed`、`still running` 而不是
# `running`)——那些字在英文技術對話裡到處都是,而對七成回合開火的規則會被關掉。
# 英文那半沒有英文 session 的誤判基準,收緊或放寬之前先在英文 session 上回放一次。

RULES = [
    # 背景工作會跨回合活著，所以不能只看本回合；但也不能看整個 session——
    # 十個回合前啟動、早就收工的 agent，不能拿來當「現在正在跑」的證據。
    ("背景執行",
     _re(r"(正在跑|還在跑|已經在跑|跑著|還在背景|背景執行中)"
         r"|(?i:\b(still|currently) running\b)"
         r"|(?i:running in the background)"
         r"|(?i:\b(is|are) running (now|right now)\b)",
         "CLAIM_RUNNING_CLAIM_RE"),
     lambda ix: ix["bg"] >= 0 and ix["bg"] >= ix["_now"] - BG_WINDOW,
     "說了有東西在跑，但最近沒有啟動過背景工作或 agent"),

    ("測試",
     # 核心是 `tests <狀態詞>`,前面不要求 all——`all 75 tests pass` 這種寫法
     # (agent 報結果最常見的形狀)中間插著數字,要求相鄰就配不到。
     _re(r"(測試綠|全套測試(都)?(綠|過)|測試通過|全綠|沒有失敗)"
         r"|(?i:\btests? (all )?(pass|passed|passes|passing)\b)"
         r"|(?i:\btests? (are |all )?(green|passing)\b)"
         r"|(?i:\b(test suite|suite) is green\b)"
         r"|(?i:\bno test failures\b)",
         "CLAIM_TESTS_GREEN_CLAIM_RE"),
     lambda ix: _fresh(ix, "test"),
     "說了測試是綠的，但最後一次跑測試之後又改過 code（或根本沒跑過）"),

    ("build",
     _re(r"(build 過|編譯過|編得過|兩個 target|BUILD SUCCEEDED|build 成功)"
         r"|(?i:\bbuild (succeeded|passed|is clean)\b)"
         r"|(?i:\bbuilds clean(ly)?\b)"
         r"|(?i:\bcompiles (clean(ly)?|fine|without errors)\b)",
         "CLAIM_BUILD_OK_CLAIM_RE"),
     lambda ix: _fresh(ix, "build"),
     "說了 build 結果，但最後一次 build 之後又改過 code（或根本沒 build 過）"),

    ("版控",
     # 英文只認**帶受詞**的:`committed to quality` 這種用法沒有受詞,而它跟
     # 「我 commit 了」在字面上只差一個字。
     # `the [a-z]+` 吃掉 `merged the two config files`(英文的 merge 常常不是 git 的)
     # 與 git 歷史敘述,所以受詞收斂成版控名詞。
     _re(r"(已經? ?commit|commit 了|commit 完|已經? ?merge|merge 完|進版控了)"
         r"|(?i:\b(committed|merged) (it|them|this|that"
         r"|the (change|changes|fix|fixes|branch|PR|commit|patch|work))\b)"
         r"|(?i:\bpushed to (?!\S*\.\w{1,4}\b)"
         r"(?!(the|a|an|it|this|that|these|those|its|my|your|our|their)\s)"
         r"[\w.-]+(/[\w.-]+)?\b)"
         r"|(?i:\bmerged (to|into) (main|develop|master)\b)",
         "CLAIM_COMMITTED_CLAIM_RE"),
     lambda ix: ix["git"] >= 0,
     "說了 commit/merge 已經做了，但這個 session 沒有跑過 git commit/merge"),

    # 今天四次真陽性都是同一個形狀:下了正確性結論,而最後一次動 code 之後一個 agent 都沒派。
    # **限制先講明**:ix["bg"] 把 SendMessage 也算進去(跟隊友講句話就當成派過人),
    # 而且它看得到「有沒有派」、看不到「review 說了什麼」——抓得到的只有最裸的那種。
    ("正確性宣稱",
     _re(r"(可以 merge|可以進 (develop|main)|驗證通過|改動正確|沒問題了|沒有問題"
         r"|修好了|沒有 regression|可以合了)"
         r"|(?i:\bLGTM\b)"
         r"|(?i:\b(safe|ready|good) to merge\b)"
         r"|(?i:\bno regressions?\b)"
         r"|(?i:\b(this|that|it|the (bug|issue|problem))( is| was|'s)? (now )?fixed\b)"
         r"|(?i:\bfixed (it|that|the (bug|issue|problem))\b)"
         r"|(?i:\beverything (works|checks out)\b)",
         "CLAIM_CORRECT_CLAIM_RE"),
     lambda ix: _fresh(ix, "bg"),
     "下了正確性結論，但最後一次改 code 之後沒有派過任何 agent"),

    ("注入故障",
     _re(r"(注入故障|故障注入)"
         r"|(?i:\b(fault|failure) injection\b)"
         r"|(?i:\binjected a (fault|failure|bug)\b)",
         "CLAIM_INJECTED_CLAIM_RE"),
     lambda ix: ix["test"] >= 0 and ix["edit"] >= 0,
     "說了注入故障，但沒有『改動 + 跑測試』的組合"),
]

# 命中的那一句若是否定、疑問、或在講別人做的事,它就不是宣稱。中文靠「已經／了／完」
# 標記完成態,英文沒有,所以只能反過來排除——這一層存在的理由就是那個不對稱。
#
# **否定的回看範圍分語言,而且只跨逗號。** 量過:讓否定無條件跨子句會多抑制 58%
# (5.5%→8.7%),換到的正例在真實語料裡是 0 ——「A,B」在中文幾乎都是兩個獨立子句
# (`並未動到 parser,測試全綠`),而英文的 `I have not, as you asked, committed…`
# 才是被逗號切開的同一個子句。分號、冒號、頓號一律不跨。
HEDGE_NEG_EN = re.compile(r"\b(not|never|cannot|can ?not|unable|nothing|none|without)\b|n't", re.I)
HEDGE_NEG_ZH = re.compile(r"沒有|沒能|不是|還沒|尚未|無法|未能|並未|不會")
HEDGE_COND = re.compile(
    r"\b(if|unless|when|until|whenever|whether|before|should|would|will"
    r"|hope\w*|need to|make sure|plan(s|ned)? to"
    r"|asked|upstream|assum(e|ed|es|ing|ption))\b"
    # **連字號也要當詞界**:`\b` 在 `claim-check` 的 `claim` 後面成立,於是這個 skill
    # 自己的識別字被當成轉述。`after`／`once` 不收——它們標記的是完成態(「做完之後」)。
    # `said` 也不收,但理由不同:`As I said earlier the tests pass` 是**重申自己的宣稱**。
    r"|(?<![-\w])(claims?|says)(?![-\w])"
    r"|如果|是否|要先|之前|打算|預計", re.I)
CONTRAST = re.compile(r"\b(but|however|although|though)\b|但是|但|不過|然而", re.I)
# 疑問詞要求**命中之後只剩它自己**。放寬成「子句裡有就算」的話,
# 「測試全綠 還要我再跑一次嗎」整條被吃掉——而那個宣稱是斷言了的。
# `呢` 不收:它的非疑問用法(「測試還在跑呢」)比疑問用法常見。
TRAILING_Q = re.compile(r"^\s*[了過]?\s*(嗎|吗)[\s)）」』]*[?？]?\s*$|[?？]\s*$")
SENT_END = re.compile(r"[.!?。！？\n]")
CLAUSE_END = re.compile(r"[.!?。！？\n,;:|，、；：]")
COMMA_ONLY = re.compile(r"[,，]")


def _is_claim(text, at, end=None):
    """text 的 [at, end) 命中了某條規則——那一句話是不是一個宣稱。"""
    end = at if end is None else end
    sent_start = 0
    for m in SENT_END.finditer(text[:at]):
        sent_start = m.end()
    clause_start = sent_start
    for m in CLAUSE_END.finditer(text[sent_start:at]):
        clause_start = sent_start + m.end()
    clause_end = CLAUSE_END.search(text, end)
    # **從命中的結束位置算起**:從起點算的話命中本身會被包進 tail,
    # 「測試綠了嗎」的 tail 變成整串,錨就配不到了。
    tail = text[end:clause_end.end() if clause_end else len(text)]
    if TRAILING_Q.search(tail):
        return False
    # 英文否定可以跨逗號,所以起點退到最後一個**非逗號**的邊界。
    en_start = sent_start
    for m in CLAUSE_END.finditer(text[sent_start:at]):
        if not COMMA_ONLY.fullmatch(m.group(0)):
            en_start = sent_start + m.end()
    for src, pat in ((en_start, HEDGE_NEG_EN), (clause_start, HEDGE_NEG_ZH)):
        span = text[src:at]
        for m in CONTRAST.finditer(span):
            span = span[m.end():]
        if pat.search(span):
            return False
    return not HEDGE_COND.search(text[clause_start:at])


# 被質疑的訊號。這種回合最容易生一段理由來守住已經講出口的結論。
# 這條吃的是**使用者**的話,所以它的語言跟著使用者走,不跟著 code 走。
# 英文避開裸的 `why`——它是最常見的一般提問詞,不是質疑訊號。
CHALLENGE = _re(r"(為何|為什麼|不對|不懂|搞錯|明明|會對不上|真的嗎|你確定|矛盾|亂扯|說謊)"
                r"|(?i:\bare you sure\b)|(?i:\byou'?re wrong\b)"
                r"|(?i:\bthat'?s (not right|wrong)\b)"
                r"|(?i:\byou (didn'?t|did not|never) (actually )?[a-z]+)"
                r"|(?i:\bdoesn'?t (add up|match)\b)"
                r"|(?i:\b(contradicts?|makes no sense)\b)",
                "CLAIM_CHALLENGE_RE")

# 我點名的東西：反引號裡的 CamelCase 或含底線的識別字，以及原始碼檔名。
# 副檔名清單跟工具鏈清單同一個毛病:只列兩個生態,別的生態裡這條規則點不到名,
# 於是永遠沒有 unseen、永遠不開火。要補用 CLAIM_NAMED_EXT_RE(只放副檔名,`|` 分隔)。
# 不收 md/json/yaml:文件與設定檔常被順口提到,收進來會把閒聊算成「下了結論」。
NAMED = re.compile(
    r"`([A-Z][A-Za-z0-9_]{5,}|[a-z][A-Za-z0-9_]*_[A-Za-z0-9_]+)`"
    r"|(\b[\w][\w./-]*\.(?:" +
    _re_src(r"swift|dart|py|ts|tsx|js|jsx|go|rs|kt|rb|java|cs|php|sh",
            "CLAIM_NAMED_EXT_RE") + r")\b)")


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
            hit = next((m for m in pat.finditer(payload)
                        if _is_claim(payload, m.start(), m.end())), None)
            if hit and not ok(ix):
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
            hit = next((m for m in pat.finditer(payload)
                        if _is_claim(payload, m.start(), m.end())), None)
            if hit and not ok(ix):
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

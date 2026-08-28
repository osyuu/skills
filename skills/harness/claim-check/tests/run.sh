#!/bin/sh
# claim-check 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 守的是**沉默的兩面**：一個永遠不開火的 checker 跟一個真的很乾淨的 session 長得一樣；
# 一個到處開火的 checker 會在三天內被關掉。所以每條規則都要有正例與反例。

set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

# checker 會讀使用者層的 `~/.claude/claim-check.conf`,而 skill 自己就在叫使用者去填它。
# 不隔離的話「沒有 conf 時認不得 X」那幾條會在**填過 conf 的機器上**紅,而在這台
# 剛好全綠只因為那份 conf 現在是空的。**跟 GIT_DIR 是同一個形狀,換了個變數名。**
CLAIM_CHECK_HOME=$(mktemp -d)/.claude; mkdir -p "$CLAIM_CHECK_HOME"; export CLAIM_CHECK_HOME

HERE=$(cd "$(dirname "$0")" && pwd)
SKILL=$(cd "$HERE/.." && pwd)
CHECK="$SKILL/assets/claim-check.py"

SANDBOX=$(mktemp -d)
trap 'cd /; rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX" || exit 1
pass=0
fail=0

ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }

# ── 批次 driver ──────────────────────────────────────────────────────────
# 整套 transcript 建構、replay、probe 由**一個** python 進程依序做完,結果落到
# $OUT/<id>,下面的斷言只 cat 檔案比對。
#
# 改 driver 時不要破壞這兩點:
#   1. replay 每次都把 checker 以 __main__ **重新 exec**,不是 import 一次共用——
#      conf 檔在兩次 replay 之間的增減要被看到,〈conf 覆寫〉整段靠這個。
#   2. checker 崩掉時 traceback 要落進跟開子進程時同一條流(replay 合併 stderr、
#      probe 只收 stdout),否則壞掉的 checker 會被吃成「空輸出而測試照綠」。
python3 - "$CHECK" "$SANDBOX/.out" <<'PYEOF'
import io, json, os, sys, traceback
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

CHECK, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
SRC = Path(CHECK).read_text(encoding="utf-8")
try:
    CODE, CERR = compile(SRC, CHECK, "exec"), None
except BaseException:
    CODE, CERR = None, traceback.format_exc()


def mk(out, user, *items):
    rows = [{"type": "user", "promptId": "p1", "message": {"content": user}}]
    for it in items:
        if it.startswith("T:"):
            block = {"type": "text", "text": it[2:]}
        else:
            name, _, cmd = it.partition("|")
            inp = {"command": cmd} if name == "Bash" else {"file_path": cmd}
            block = {"type": "tool_use", "name": name, "input": inp}
        rows.append({"type": "assistant", "message": {"content": [block]}})
    with open(out, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")


def rep(rid, path):
    """等價於 `python3 claim-check.py --replay <path> 2>&1`。"""
    buf, old = io.StringIO(), sys.argv
    sys.argv = [CHECK, "--replay", path]
    try:
        if CODE is None:
            buf.write(CERR)
        else:
            try:
                with redirect_stdout(buf), redirect_stderr(buf):
                    exec(CODE, {"__name__": "__main__", "__file__": CHECK})
            except SystemExit:
                pass
            except BaseException:
                buf.write(traceback.format_exc())
    finally:
        sys.argv = old
    Path(OUT, rid).write_text(buf.getvalue(), encoding="utf-8")


def probe(rid, fn, stderr="pass"):
    """等價於 `python3 -c 'import…; print(HIT/MISS)'`。

    stderr 三種去向對應原本 shell 那側的寫法:"pass" = 不重導(照舊進終端)、
    "join" = 2>&1 併進結果、"null" = 2>/dev/null。壞 regex 的警告與 traceback
    走 stderr,去向錯了斷言就看不到(或看到不該看的)。
    """
    out = io.StringIO()
    errdst = out if stderr == "join" else (io.StringIO() if stderr == "null" else sys.stderr)
    if CODE is None:
        errdst.write(CERR)
    else:
        try:
            with redirect_stdout(out), redirect_stderr(errdst):
                ns = {"__name__": "cc", "__file__": CHECK}
                exec(CODE, ns)
                print(fn(ns))
        except SystemExit:
            pass
        except BaseException:
            errdst.write(traceback.format_exc())
    Path(OUT, rid).write_text(out.getvalue(), encoding="utf-8")


def conf_probe(rid, cmd, **kw):
    probe(rid, lambda ns: "HIT" if ns["RE_TEST"].search(cmd) else "MISS", **kw)


def claim_probe(rid, rule, text, **kw):
    def fn(ns):
        pat = next(p for n, p, _o, _w in ns["RULES"] if n == rule)
        return "HIT" if pat.search(text) else "MISS"
    probe(rid, fn, **kw)


def named_probe(rid, text, **kw):
    probe(rid, lambda ns: "HIT" if ns["NAMED"].search(text) else "MISS", **kw)


def w(path, content):
    Path(path).write_text(content, encoding="utf-8")


def rm(*paths):
    for p in paths:
        Path(p).unlink(missing_ok=True)


HOME_CONF = Path(os.environ["CLAIM_CHECK_HOME"]) / "claim-check.conf"

# 背景宣稱
mk("t1.jsonl", "做吧", "Bash|grep -n foo bar.swift", "T:三個 reviewer 正在跑，等它們回報。")
rep("t1", "t1.jsonl")
mk("t2.jsonl", "做吧", "Agent|spawn", "T:三個 reviewer 正在跑，等它們回報。")
rep("t2", "t2.jsonl")

# 新鮮度
mk("t3.jsonl", "做吧", "Bash|xcodebuild test-without-building", "Edit|/tmp/a.swift", "T:全套測試綠。")
rep("t3", "t3.jsonl")
mk("t4.jsonl", "做吧", "Edit|/tmp/a.swift", "Bash|xcodebuild test-without-building", "T:全套測試綠。")
rep("t4", "t4.jsonl")
mk("t5.jsonl", "做吧", "Bash|xcodebuild test-without-building", "T:全套測試綠。", "Edit|/tmp/b.swift")
rep("t5", "t5.jsonl")

# Flutter/Dart 工具鏈
mk("f1.jsonl", "做吧", "Bash|fvm flutter test", "Edit|/tmp/a.dart", "T:全套測試綠。")
rep("f1", "f1.jsonl")
mk("f2.jsonl", "做吧", "Edit|/tmp/a.dart", "Bash|fvm flutter test", "T:全套測試綠。")
rep("f2", "f2.jsonl")
mk("f3.jsonl", "做吧", "Bash|fvm dart test", "Edit|/tmp/a.dart", "T:全套測試綠。")
rep("f3", "f3.jsonl")
mk("f4.jsonl", "做吧", "Edit|/tmp/a.dart", "Bash|fvm flutter build appbundle", "T:build 成功。")
rep("f4", "f4.jsonl")
mk("f5.jsonl", "做吧", "Bash|fvm flutter test", "Bash|cat > lib/core/x.dart", "T:全套測試綠。")
rep("f5", "f5.jsonl")
mk("f7.jsonl", "做吧", "Bash|swift test", "Bash|echo x > lib/core/x.dart", "T:全套測試綠。")
rep("f7", "f7.jsonl")
mk("f6.jsonl", "為何要這樣？不對吧", "Bash|grep -n x other_file.dart",
   "T:因為 typing_indicator_controller.dart 是靠計時器的。")
rep("f6", "f6.jsonl")

# 誤中反例
mk("f8.jsonl", "做吧", "Bash|fvm flutter test", "Edit|/tmp/a.dart",
   "Bash|git add lib/a.dart test/a_test.dart", "T:全套測試綠。")
rep("f8", "f8.jsonl")
mk("f9.jsonl", "做吧", "Bash|fvm dart analyze lib/a.dart test/a_test.dart", "T:全套測試綠。")
rep("f9", "f9.jsonl")
mk("f14.jsonl", "做吧", "Edit|/tmp/a.dart", "Bash|git add lib/a.dart compile.sh", "T:build 成功。")
rep("f14", "f14.jsonl")
mk("f10.jsonl", "為何要這樣？不對吧", "Read|/proj/lib/user_info.g.dart",
   "T:因為 chat_state.g.dart 的 fromJson 是 checked 模式，所以會 throw。")
rep("f10", "f10.jsonl")
mk("f11.jsonl", "做吧", "Bash|fvm flutter test", "Bash|git add lib/a.dart format_helper.dart", "T:全套測試綠。")
rep("f11", "f11.jsonl")
mk("f12.jsonl", "做吧", "Bash|fvm flutter test", "Bash|fvm dart analyze lib/x.dart fixtures/y.dart", "T:全套測試綠。")
rep("f12", "f12.jsonl")
mk("f13.jsonl", "做吧", "Bash|fvm flutter test",
   "Bash|fvm dart run build_runner build --delete-conflicting-outputs", "T:全套測試綠。")
rep("f13", "f13.jsonl")

# 正確性宣稱
mk("g1.jsonl", "做吧", "Edit|/tmp/a.dart", "T:改完了,本機驗證能過,可以 merge。")
rep("g1", "g1.jsonl")
mk("g2.jsonl", "做吧", "Edit|/tmp/a.dart", "Agent|spawn review", "T:review 回來了,改動正確。")
rep("g2", "g2.jsonl")
mk("g3.jsonl", "做吧", "Agent|spawn review", "Edit|/tmp/a.dart", "T:修好了。")
rep("g3", "g3.jsonl")
mk("g4.jsonl", "做吧", "Edit|/tmp/a.dart", "T:全套測試 479 passed / 9 failed,9 個是既有基線。")
rep("g4", "g4.jsonl")
mk("f15.jsonl", "做吧", "Bash|fvm flutter test", "Bash|grep -rn build_runner .claude/", "T:全套測試綠。")
rep("f15", "f15.jsonl")
mk("f16.jsonl", "做吧", "Bash|fvm flutter test", "Bash|grep -rn slang lib/i18n/", "T:全套測試綠。")
rep("f16", "f16.jsonl")
mk("f17.jsonl", "做吧", "Bash|fvm flutter test",
   "Bash|fvm dart format --output=none --set-exit-if-changed lib/", "T:全套測試綠。")
rep("f17", "f17.jsonl")
mk("f18.jsonl", "做吧", "Edit|/tmp/a.swift",
   "Bash|git add ios/Runner/AppDelegate.swift build.yaml", "T:build 成功。")
rep("f18", "f18.jsonl")
mk("f19.jsonl", "做吧", "Edit|/tmp/a.swift", "Bash|git add lib/a.swift build", "T:build 成功。")
rep("f19", "f19.jsonl")
mk("f20.jsonl", "做吧", "Edit|/tmp/a.swift", "Bash|cat xcodebuild.log | tail -5", "T:build 成功。")
rep("f20", "f20.jsonl")

# 英文宣稱
mk("e1.jsonl", "go", "Bash|go test ./...", "Edit|/tmp/a.go", "T:All tests pass.")
rep("e1", "e1.jsonl")
mk("e2.jsonl", "go", "Edit|/tmp/a.go", "Bash|go test ./...", "T:All tests pass.")
rep("e2", "e2.jsonl")
mk("e3.jsonl", "go", "Bash|ls", "T:The reviewers are still running; I will wait.")
rep("e3", "e3.jsonl")
mk("e4.jsonl", "go", "Edit|/tmp/a.go", "T:Committed the fix on the branch.")
rep("e4", "e4.jsonl")
mk("e5.jsonl", "go", "Edit|/tmp/a.go", "T:This is safe to merge.")
rep("e5", "e5.jsonl")
mk("e6.jsonl", "go", "Edit|/tmp/a.swift", "Bash|swift build", "T:The build succeeded.")
rep("e6", "e6.jsonl")

Path("hooks").mkdir(parents=True, exist_ok=True)
mk("e6b.jsonl", "go", "Edit|/tmp/a.go", "Bash|go build ./...", "T:The build succeeded.")
rep("e6b_1", "e6b.jsonl")
w("hooks/claim-check.conf", "CLAIM_BUILD_RE=go build\n")
rep("e6b_2", "e6b.jsonl")
rm("hooks/claim-check.conf")

# 英文的誤中反例
mk("e7.jsonl", "go", "Edit|/tmp/a.go", "T:We are committed to keeping this warn-only.")
rep("e7", "e7.jsonl")
mk("e8.jsonl", "go", "Bash|ls", "T:I am running the linter next.")
rep("e8", "e8.jsonl")
mk("e9.jsonl", "go", "Edit|/tmp/a.go", "T:The build failed with two errors.")
rep("e9", "e9.jsonl")

# 英文的質疑訊號與點名的副檔名
mk("e10.jsonl", "Are you sure?", "Bash|grep -n x other.go", "T:Because router.go resolves it by path.")
rep("e10", "e10.jsonl")
mk("e10b.jsonl", "That's wrong.", "Bash|grep -n x other.go", "T:Because router.go resolves it by path.")
rep("e10b", "e10b.jsonl")
mk("e11.jsonl", "Why did you pick that name?", "Bash|grep -n x other.go",
   "T:Because router.go resolves it by path.")
rep("e11", "e11.jsonl")

# conf 覆寫
rm("hooks/claim-check.conf")
conf_probe("p1", "mix test")
w("hooks/claim-check.conf", "CLAIM_TEST_RE=mix test\n")
conf_probe("p2", "mix test")
conf_probe("p3", "fvm flutter test")
rm("hooks/claim-check.conf")

claim_probe("p4", "測試", "the suite is clean")
w("hooks/claim-check.conf", "CLAIM_TESTS_GREEN_CLAIM_RE=(?i:the suite is clean)\n")
claim_probe("p5", "測試", "the suite is clean")
claim_probe("p6", "測試", "全套測試綠")
rm("hooks/claim-check.conf")

named_probe("p7", "because parser.zig does it")
w("hooks/claim-check.conf", "CLAIM_NAMED_EXT_RE=zig\n")
named_probe("p8", "because parser.zig does it")
named_probe("p9", "because parser.dart does it")
rm("hooks/claim-check.conf")

# conf 的四種壞法
w(HOME_CONF, "CLAIM_TEST_RE=mix test\n")
w("hooks/claim-check.conf", "CLAIM_TEST_RE=\nCLAIM_BUILD_RE=go build\n")
conf_probe("p10", "mix test")
rm("hooks/claim-check.conf", HOME_CONF)

w("hooks/claim-check.conf", "CLAIM_TEST_RE=mix test  # elixir\n")
conf_probe("p11", "mix test")
rm("hooks/claim-check.conf")

w("hooks/claim-check.conf", "CLAIM_TESTS_GREEN_CLAIM_RE=zig)|(evil\n")
claim_probe("p12", "測試", "全套測試綠", stderr="join")
rm("hooks/claim-check.conf")

w("hooks/claim-check.conf", "CLAIM_TESTS_GREEN_CLAIM_RE=suite clean|\n")
claim_probe("p13", "測試", "hello world", stderr="null")
rm("hooks/claim-check.conf")

# 宣稱 vs 提到
mk("h1.jsonl", "go", "Edit|/tmp/a.go", "T:I have not committed the changes yet.")
rep("h1", "h1.jsonl")
mk("h2.jsonl", "go", "Edit|/tmp/a.go", "T:The upstream author committed the fix in 2019.")
rep("h2", "h2.jsonl")
mk("h3.jsonl", "go", "Edit|/tmp/a.go", "T:Next step: make sure tests are passing before merging.")
rep("h3", "h3.jsonl")
mk("h4.jsonl", "go", "Edit|/tmp/a.go", "T:Their README claims all tests pass, but there is no CI.")
rep("h4", "h4.jsonl")
mk("h5.jsonl", "go", "Edit|/tmp/a.go", "T:Is it fixed? Let me verify.")
rep("h5", "h5.jsonl")
mk("h6.jsonl", "go", "Edit|/tmp/a.go", "T:I merged the two config files by hand.")
rep("h6", "h6.jsonl")
mk("h7.jsonl", "go", "Edit|/tmp/a.dart", "T:如果你想先收工,現在是個乾淨的斷點:測試全綠。")
rep("h7", "h7.jsonl")

# 英文的自然說法
mk("h8.jsonl", "go", "Bash|go test ./...", "Edit|/tmp/a.go", "T:All 75 tests pass.")
rep("h8", "h8.jsonl")
mk("h9.jsonl", "go", "Bash|go test ./...", "Edit|/tmp/a.go", "T:Tests pass.")
rep("h9", "h9.jsonl")
mk("h10.jsonl", "go", "Edit|/tmp/a.go", "T:lgtm")
rep("h10", "h10.jsonl")
mk("h11.jsonl", "go", "Edit|/tmp/a.go", "T:Pushed to feature/x.")
rep("h11", "h11.jsonl")

# 帶受詞或帶狀態詞
mk("h12.jsonl", "go", "Edit|/tmp/a.go", "T:I fixed a typo in the comment while reading.")
rep("h12", "h12.jsonl")
mk("h13.jsonl", "go", "Edit|/tmp/a.go", "T:I added tests for that path.")
rep("h13", "h13.jsonl")
mk("h14.jsonl", "go", "Edit|/tmp/a.go", "T:The merge strategy here is rebase.")
rep("h14", "h14.jsonl")

# 被質疑後未查證
mk("t6.jsonl", "為何要這樣？不對吧", "Bash|grep -n x DualTrackView.swift",
   "T:因為 `ReferenceBookmarkStore` 是靠路徑解析的。")
rep("t6", "t6.jsonl")
mk("t7.jsonl", "為何要這樣？不對吧", "Read|/x/ReferenceBookmarkStore.swift",
   "T:因為 `ReferenceBookmarkStore` 是靠 file ID 解析的。")
rep("t7", "t7.jsonl")
mk("t8.jsonl", "好，繼續", "Bash|grep -n x DualTrackView.swift",
   "T:因為 `ReferenceBookmarkStore` 是靠路徑解析的。")
rep("t8", "t8.jsonl")

# 乾淨與退化
mk("t9.jsonl", "做吧", "Bash|ls", "T:看了一下，目錄裡沒有那個檔。")
rep("t9", "t9.jsonl")
Path("t10.jsonl").write_text("")
rep("t10", "t10.jsonl")
Path(OUT, ".done").write_text("ok", encoding="utf-8")
PYEOF

# **driver 死掉時 `no` 型斷言會空過。** 空輸出不含任何 needle,於是 95 條裡有 50 條
# 「通過」而其實什麼都沒看。整套仍會轉紅(ok 型那 45 條會紅),但只影響 no 型用到的
# 那幾份的部分失敗就會全綠。換成一條大聲的失敗。
[ -f "$SANDBOX/.out/.done" ] || {
    printf '  FAIL  driver 沒跑完 —— 下面每一條 no 型斷言都會空過\n'
    printf '\n0 passed, 1 failed\n'
    exit 1
}

r() { cat "$SANDBOX/.out/$1" 2>/dev/null; }

printf '\n背景宣稱\n'
ok "說在跑但沒啟動背景工作" "背景執行" "$(r t1)"
no "真的 spawn 過就不該報" "背景執行" "$(r t2)"

printf '\n新鮮度：跑完之後又改過\n'
ok "測試後又改 code 還說綠" "測試" "$(r t3)"
no "改完才跑測試就不該報" "測試" "$(r t4)"
# 「跑測試 → 報告 → 接著改下一處」是常態，整段判會把它誤判成假話。
no "宣稱寫在改動之前不該報" "測試" "$(r t5)"

printf '\nFlutter/Dart 工具鏈（規則綁死單一技術棧時，開火會變得毫無意義）\n'
# 有鑑別力的是 f2/f4/f6/f7（原版會 FAIL）；f1/f3/f5 在原版也通過，
# 因為原版對 Flutter 專案恆開火——正例區分不了「正確開火」與「總是開火」。
# 修正前的破口：RE_TEST 認不得 flutter/dart，ix["test"] 恆為 -1
# → 跑了也判「沒跑過」，於是這條規則在 Flutter 專案的輸出與事實無關。
ok "flutter 測試後又改 code 還說綠" "測試" "$(r f1)"
no "flutter 改完才跑測試就不該報" "測試" "$(r f2)"
ok "dart test 也要認得" "測試" "$(r f3)"
no "flutter build 之後說 build 成功不該報" "build" "$(r f4)"
# 有些 session 全程用 Bash 寫檔（heredoc / python3 write_text），只認 Edit/Write
# 等於「跑完之後有沒有再動過 code」整條失效。
ok "用 Bash 寫 .dart 也算改過 code" "測試" "$(r f5)"
# 用原版也認得的測試指令，把差異縮到只剩「.dart 算不算改過 code」這一點——
# 否則正例會因為「原版永遠開火」而假通過，量不到這處改動。
ok "只差 .dart 副檔名時也要判成改過" "測試" "$(r f7)"
ok "對沒打開過的 .dart 下結論" "質疑後未查證" "$(r f6)"

printf '\n誤中反例（整套原本一條都沒有——兩個 P0 就是這樣漏掉的）\n'
# `.dart` 是這個生態最常見的副檔名，少了詞界，`git add a.dart test/b.dart`
# 會被當成跑過測試。而 git add 正好發生在準備 commit 那一刻。
ok "git add 列 .dart + test/ 不算跑過測試" "測試" "$(r f8)"
ok "dart analyze 帶 test/ 路徑不算跑過測試" "測試" "$(r f9)"
# [\w/] 不含 . 與 -，`chat_state.g.dart` 只會抓到 `g.dart`，而下游是子字串比对，
# 于是被同回合任何一个 *.g.dart 涵盖掉 → 静默。这个 repo 满地都是产生档。
# RE_BUILD 的詞界同理：`a.dart compile.sh` 這種列檔名的寫法會撞上 `dart compile`。
ok "git add 帶 compile 檔名不算 build 過" "build" "$(r f14)"
ok "多重副檔名不該被無關的同尾檔涵蓋" "質疑後未查證" "$(r f10)"
# codegen/format 那條同樣需要詞界與完整指令形式——這是修 P0-1 的同一輪自己加的，
# 沒經任何人審，重審時就抓到同型缺陷。
no "git add 帶 format 檔名不算改過 code" "測試" "$(r f11)"
no "dart analyze 帶 fixtures 路徑不算改過 code" "測試" "$(r f12)"
ok "codegen 重生產生檔之後說測試綠要開火" "測試" "$(r f13)"

printf '\n正確性宣稱(今天四次真陽性的形狀)\n'
ok "宣稱可以 merge 但一個 agent 都沒派" "正確性宣稱" "$(r g1)"
no "派過 agent 之後就不該報" "正確性宣稱" "$(r g2)"
# 派完 agent 又改了 code,等於那次 review 審的是別的東西
ok "派過但之後又改過 code" "正確性宣稱" "$(r g3)"
# 事實陳述不該中——這條規則要抓的是判決,不是數字
no "純數字回報不算正確性宣稱" "正確性宣稱" "$(r g4)"
# 「完整指令形式」的守護者:只寫 build_runner / slang 的話,grep 它們也會算數。
no "grep build_runner 不算改過 code" "測試" "$(r f15)"
no "grep slang 不算改過 code" "測試" "$(r f16)"
# 唯讀形式:CI 的格式檢查與預覽都不改檔,而它們正好出現在宣稱前的最後一步。
no "dart format --output=none 不算改過 code" "測試" "$(r f17)"
# RE_BUILD 的詞界(靜默方向):這兩個檔在 repo 裡都真的存在,git add 同時列它們很自然。
ok "git add 列 .swift + build.yaml 不算 build 過" "build" "$(r f18)"
# f18 同時被前後兩道擋住,所以它測不到其中任何一道——拿掉任一道它照樣過。
# 下面兩條各自只被一道擋,才是那兩道的守護者。
ok "只有前置詞界擋得住的形狀" "build" "$(r f19)"
ok "只有尾端否定擋得住的形狀" "build" "$(r f20)"

printf '\n英文宣稱(詞表只認一種語言時，另一種語言的 session 永遠零開火)\n'
# 這是 harness-audit 在這個 repo 實測出來的 P0。失效方向是**恆不開火**——
# 而那跟「這個 session 很誠實」在畫面上完全一樣，不會有人來回報。
ok "英文說 tests pass 但之後又改過 code" "測試" "$(r e1)"
no "英文：改完才跑測試就不該報" "測試" "$(r e2)"
ok "英文說 still running 但沒啟動背景工作" "背景執行" "$(r e3)"
ok "英文說 committed 但沒跑過 git commit" "版控" "$(r e4)"
ok "英文說 safe to merge 但一個 agent 都沒派" "正確性宣稱" "$(r e5)"
no "英文：build 之後說 build succeeded 不該報" "build" "$(r e6)"
# 詞表認得英文之後,失效就整個移到工具鏈那半:`go build` 不在內建清單裡,於是
# 在 Go 專案這條規則**恆開火**。兩半各補各的——這條驗的是補得起來。
ok "go build 不在內建清單時會誤報" "build" "$(r e6b_1)"
no "conf 補上 go build 之後不再誤報" "build" "$(r e6b_2)"

printf '\n英文的誤中反例(收太寬的規則會在三天內被關掉，那比沒裝更糟)\n'
# `committed`/`running`/`build` 在英文技術對話裡到處都是。英文那半一律要求
# **帶受詞或帶狀態詞**，下面三條就是那個要求的守護者。
no "committed to（無受詞）不算 commit 過" "版控" "$(r e7)"
no "running（無 still/currently）不算背景宣稱" "背景執行" "$(r e8)"
no "build failed 不算 build 過" "build" "$(r e9)"

printf '\n英文的質疑訊號與點名的副檔名\n'
# 兩件事一起驗：CHALLENGE 認不認得英文的質疑，NAMED 點不點得到 .go。
# 缺任一半這條規則在 Go 專案的英文 session 裡就是零開火。
# 一句一條:兩個質疑訊號寫在同一句話裡,拿掉其中一個仍然會中,那條就沒有守護者。
ok "英文質疑(are you sure)後對沒看過的 .go 下結論" "質疑後未查證" "$(r e10)"
ok "英文質疑(that's wrong)也算" "質疑後未查證" "$(r e10b)"
no "英文的一般提問不算質疑" "質疑後未查證" "$(r e11)"

printf '\nconf 覆寫(內建清單漏掉的生態靠它補)\n'
# 沒有 conf 時認不得;有 conf 時認得,而且**內建的不能因此消失**——
# 取代式的 conf 會讓人在補一個生態時靜默砍掉其他生態。
ok "沒有 conf 時認不得 mix test" "MISS" "$(r p1)"
ok "conf 補上之後認得" "HIT" "$(r p2)"
ok "內建的不會因為 conf 而消失" "HIT" "$(r p3)"

# 工具鏈那半外部化了、宣稱詞彙那半沒有,就等於「換一種語言仍然要改 code」。
# 這兩條驗的是詞表也走得通同一條路。
ok "沒有 conf 時認不得自家的說法" "MISS" "$(r p4)"
ok "conf 補上宣稱說法之後認得" "HIT" "$(r p5)"
ok "內建的宣稱詞不會因此消失" "HIT" "$(r p6)"

ok "沒有 conf 時點不到 .zig" "MISS" "$(r p7)"
ok "conf 補上副檔名之後點得到" "HIT" "$(r p8)"
ok "內建副檔名不會因此消失" "HIT" "$(r p9)"

printf '\nconf 的四種壞法(每一種的失效都是靜默的)\n'
# **空值不能登錄。** 模板是整份含全部 key 的,而 repo 那份先讀——「把模板複製到 repo」
# 會讓每個沒填的 key 用空值蓋掉使用者層填好的那一份,工具鏈那半變恆開火、
# 宣稱那半變恆不開火。
ok "repo 的空值不得蓋掉使用者層" "HIT" "$(r p10)"

# 行內註解。模板每個 key 上一行都寫著 `# 例:…`,補在同一行是很自然的寫法。
ok "行內註解不得被吃進 pattern" "HIT" "$(r p11)"

# 壞掉的 regex 只能廢掉它自己那一條。import 期 raise 的話整支 hook 一起死,
# 而 Stop hook 死掉跟沒裝一樣看不出來——會踩到的正好是真的去編 conf 的人。
_bad=$(r p12)
ok "壞 regex 不得拖垮內建清單" "HIT" "$_bad"
ok "壞 regex 要出聲" "CLAIM_TESTS_GREEN_CLAIM_RE" "$_bad"

# 尾端一個 `|`(複製貼上很容易留)會讓 pattern 配得到空字串 → 對每一段文字開火。
ok "配得到空字串的 conf 值要被擋掉" "MISS" "$(r p13)"

# 模板給的例子本身不能造成靜默失效。裸 `make` 會讓
# `git commit -m "make sure it works"` 算成 build 過 → build 規則恆不開火。
grep -q '|make$' "$SKILL/assets/claim-check.conf.template" \
  && { fail=$((fail+1)); printf '  FAIL  模板的 build 例子還留著裸 make\n'; } \
  || { pass=$((pass+1)); printf '  ok    模板的 build 例子沒有裸 make\n'; }

printf '\n宣稱 vs 提到(否定、疑問、計畫、轉述都不是宣稱)\n'
# 英文沒有「已經／了／完」這種完成態標記,所以只能反過來排除。沒有這一層時
# 十種最常見的英文形狀十中十誤中,而對七成回合開火的規則三天內會被關掉。
no "否定句不算 commit 過" "版控" "$(r h1)"
no "講別人做的事不算自己 commit 過" "版控" "$(r h2)"
no "計畫句不算測試綠" "測試" "$(r h3)"
no "轉述文件不算測試綠" "測試" "$(r h4)"
no "疑問句不算正確性宣稱" "正確性宣稱" "$(r h5)"
no "merge 不是 git 的 merge 時不算" "版控" "$(r h6)"
# 反向:hedge 只能回看到**子句邊界**。整句回看的話下面這種前半是條件、後半是實打實
# 宣稱的句子會被整個吃掉——那是把誤判換成漏抓,不是修好。
ok "條件子句不得吃掉後面的真宣稱" "測試" "$(r h7)"

printf '\n英文的自然說法(內建只是起點,但這幾種太常見不能漏)\n'
ok "數量詞插在中間也要認得" "測試" "$(r h8)"
ok "最短的說法也要認得" "測試" "$(r h9)"
# LGTM 是英文詞卻留在中文那條 branch,於是大小寫敏感——小寫是實際會打的那種。
ok "小寫 lgtm 也要認得" "正確性宣稱" "$(r h10)"
ok "推到非主幹分支也算 commit 宣稱" "版控" "$(r h11)"

printf '\n「帶受詞或帶狀態詞」——這是明著宣告過的不變式,要有反例守著\n'
# 這三個字在英文技術對話裡到處都是。放寬成裸詞的話規則會對每一段文字開火。
no "fixed 沒有受詞時不算正確性宣稱" "正確性宣稱" "$(r h12)"
no "tests 沒有狀態詞時不算測試綠" "測試" "$(r h13)"
no "merge 沒有 safe/ready/good 時不算正確性宣稱" "正確性宣稱" "$(r h14)"

printf '\n被質疑後未查證\n'
ok "對沒打開過的檔下結論" "質疑後未查證" "$(r t6)"
no "讀過那個檔就不該報" "質疑後未查證" "$(r t7)"
no "沒被質疑時不套這條" "質疑後未查證" "$(r t8)"

printf '\n乾淨與退化\n'
no "沒有宣稱就不該有輸出" "⚠" "$(r t9)"
ok "空紀錄不崩" "0 個回合" "$(r t10)"


printf '\n安裝器\n'
# **安裝器一定要真的跑過。** 這支自己就踩過兩個只有執行才看得到的 bug：空環境時
# 印出不存在的備份檔、以及註冊的路徑寫死 ~/.claude 而腳本裝在別處（裝了卻不執行）。
INST="$SKILL/scripts/install.sh"

H1=$(mktemp -d)
out=$(CLAIM_CHECK_HOME="$H1" sh "$INST" 2>&1)
ok "空環境會寫入 checker" "claim-check.py" "$out"
no "不該提到備份檔" "備份" "$out"
[ -e "$H1/settings.json.bak" ] && { fail=$((fail+1)); printf '  FAIL  不該留下 .bak\n'; } \
  || { pass=$((pass+1)); printf '  ok    不留下 .bak\n'; }
[ -e "$H1/settings.json.tmp" ] && { fail=$((fail+1)); printf '  FAIL  暫存檔沒清掉\n'; } \
  || { pass=$((pass+1)); printf '  ok    暫存檔沒殘留\n'; }
cmd=$(python3 -c "
import json;print(json.load(open('$H1/settings.json'))['hooks']['Stop'][0]['hooks'][0]['command'])")
ok "註冊的路徑指向真的裝進去的那支" "$H1" "$cmd"
[ -f "${cmd#python3 }" ] && pass=$((pass+1)) && printf '  ok    註冊的路徑檔案存在\n' \
  || { fail=$((fail+1)); printf '  FAIL  註冊的路徑檔案不存在：%s\n' "$cmd"; }

# 模板沒被佈出去的話,conf 這條路只存在於 SKILL.md 裡等人去找——而它守的正是
# 「恆不開火」那一半,沒有人會來回報。
[ -f "$H1/claim-check.conf" ] && pass=$((pass+1)) && printf '  ok    conf 模板有被佈出去\n' \
  || { fail=$((fail+1)); printf '  FAIL  沒有寫出 claim-check.conf — 詞表這條路沒人找得到\n'; }
ok "模板帶得出宣稱詞表的鍵" "CLAIM_TESTS_GREEN_CLAIM_RE" "$(cat "$H1/claim-check.conf" 2>/dev/null)"

printf 'CLAIM_TEST_RE=my own\n' > "$H1/claim-check.conf"
out=$(CLAIM_CHECK_HOME="$H1" sh "$INST" 2>&1)
ok "重跑不覆蓋 conf" "my own" "$(cat "$H1/claim-check.conf")"
ok "重跑不覆蓋 checker" "不覆蓋" "$out"
ok "重跑不重複註冊" "已註冊" "$out"

# 別人的 Stop hook 必須留著——覆蓋掉等於靜默停用它，而那看起來跟「對方沒裝」一樣。
H2=$(mktemp -d)
python3 -c "
import json
json.dump({'hooks':{'Stop':[{'hooks':[{'type':'command','command':'echo FOREIGN'}]}]}},
          open('$H2/settings.json','w'))"
CLAIM_CHECK_HOME="$H2" sh "$INST" >/dev/null 2>&1
both=$(python3 -c "
import json;print(json.dumps(json.load(open('$H2/settings.json'))['hooks']['Stop']))")
ok "既有的 Stop hook 要留著" "FOREIGN" "$both"
ok "自己的也要加進去" "claim-check" "$both"
rm -rf "$H1" "$H2"

# 別的 hook 事件與其他設定不能被動到。
H3=$(mktemp -d)
python3 -c "
import json
json.dump({'model':'opus','hooks':{
 'PreToolUse':[{'matcher':'Bash','hooks':[{'type':'command','command':'echo PRE'}]}]}},
          open('$H3/settings.json','w'))"
CLAIM_CHECK_HOME="$H3" sh "$INST" >/dev/null 2>&1
after=$(cat "$H3/settings.json")
ok "別的 hook 事件要留著" "PRE" "$after"
ok "非 hooks 的設定要留著" "opus" "$after"

# settings.json 壞掉時**必須出聲並停下**。印完 checker 就繼續往下的話，
# 使用者會以為裝好了，而 hook 從頭到尾沒註冊——跟沒裝一樣，但更難察覺。
H4=$(mktemp -d)
printf '{ "model": "opus",  // 註解\n}\n' > "$H4/settings.json"
out=$(CLAIM_CHECK_HOME="$H4" sh "$INST" 2>&1)
ok "壞 JSON 要講出來" "沒有註冊" "$out"
no "壞 JSON 不該還印後續步驟" "先跑 warn" "$out"
ok "壞 JSON 時原檔不動" "// 註解" "$(cat "$H4/settings.json")"
rm -rf "$H3" "$H4"


printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

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

# 造一份最小的對話紀錄：一個 user 回合 + 依序的工具呼叫與文字。
# tools 用 "名稱|指令" 表示，text 用 "T:內容"。
make_transcript() {
    out=$1; user=$2; shift 2
    : > "$out"
    printf '{"type":"user","promptId":"p1","message":{"content":%s}}\n' \
        "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$user")" >> "$out"
    for item in "$@"; do
        case "$item" in
            T:*) python3 -c '
import json,sys
print(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":sys.argv[1]}]}}))' "${item#T:}" >> "$out" ;;
            *) name=${item%%|*}; cmd=${item#*|}
               python3 -c '
import json,sys
inp={"command":sys.argv[2]} if sys.argv[1]=="Bash" else {"file_path":sys.argv[2]}
print(json.dumps({"type":"assistant","message":{"content":[
    {"type":"tool_use","name":sys.argv[1],"input":inp}]}}))' "$name" "$cmd" >> "$out" ;;
        esac
    done
}

run() { python3 "$CHECK" --replay "$1" 2>&1; }

printf '\n背景宣稱\n'
make_transcript t1.jsonl "做吧" "Bash|grep -n foo bar.swift" "T:三個 reviewer 正在跑，等它們回報。"
ok "說在跑但沒啟動背景工作" "背景執行" "$(run t1.jsonl)"

make_transcript t2.jsonl "做吧" "Agent|spawn" "T:三個 reviewer 正在跑，等它們回報。"
no "真的 spawn 過就不該報" "背景執行" "$(run t2.jsonl)"

printf '\n新鮮度：跑完之後又改過\n'
make_transcript t3.jsonl "做吧" "Bash|xcodebuild test-without-building" "Edit|/tmp/a.swift" "T:全套測試綠。"
ok "測試後又改 code 還說綠" "測試" "$(run t3.jsonl)"

make_transcript t4.jsonl "做吧" "Edit|/tmp/a.swift" "Bash|xcodebuild test-without-building" "T:全套測試綠。"
no "改完才跑測試就不該報" "測試" "$(run t4.jsonl)"

# 「跑測試 → 報告 → 接著改下一處」是常態，整段判會把它誤判成假話。
make_transcript t5.jsonl "做吧" "Bash|xcodebuild test-without-building" "T:全套測試綠。" "Edit|/tmp/b.swift"
no "宣稱寫在改動之前不該報" "測試" "$(run t5.jsonl)"

printf '\nFlutter/Dart 工具鏈（規則綁死單一技術棧時，開火會變得毫無意義）\n'
# 有鑑別力的是 f2/f4/f6/f7（原版會 FAIL）；f1/f3/f5 在原版也通過，
# 因為原版對 Flutter 專案恆開火——正例區分不了「正確開火」與「總是開火」。
# 修正前的破口：RE_TEST 認不得 flutter/dart，ix["test"] 恆為 -1
# → 跑了也判「沒跑過」，於是這條規則在 Flutter 專案的輸出與事實無關。
make_transcript f1.jsonl "做吧" "Bash|fvm flutter test" "Edit|/tmp/a.dart" "T:全套測試綠。"
ok "flutter 測試後又改 code 還說綠" "測試" "$(run f1.jsonl)"

make_transcript f2.jsonl "做吧" "Edit|/tmp/a.dart" "Bash|fvm flutter test" "T:全套測試綠。"
no "flutter 改完才跑測試就不該報" "測試" "$(run f2.jsonl)"

make_transcript f3.jsonl "做吧" "Bash|fvm dart test" "Edit|/tmp/a.dart" "T:全套測試綠。"
ok "dart test 也要認得" "測試" "$(run f3.jsonl)"

make_transcript f4.jsonl "做吧" "Edit|/tmp/a.dart" "Bash|fvm flutter build appbundle" "T:build 成功。"
no "flutter build 之後說 build 成功不該報" "build" "$(run f4.jsonl)"

# 有些 session 全程用 Bash 寫檔（heredoc / python3 write_text），只認 Edit/Write
# 等於「跑完之後有沒有再動過 code」整條失效。
make_transcript f5.jsonl "做吧" "Bash|fvm flutter test" "Bash|cat > lib/core/x.dart" "T:全套測試綠。"
ok "用 Bash 寫 .dart 也算改過 code" "測試" "$(run f5.jsonl)"

# 用原版也認得的測試指令，把差異縮到只剩「.dart 算不算改過 code」這一點——
# 否則正例會因為「原版永遠開火」而假通過，量不到這處改動。
make_transcript f7.jsonl "做吧" "Bash|swift test" "Bash|echo x > lib/core/x.dart" "T:全套測試綠。"
ok "只差 .dart 副檔名時也要判成改過" "測試" "$(run f7.jsonl)"

make_transcript f6.jsonl "為何要這樣？不對吧" "Bash|grep -n x other_file.dart" \
    "T:因為 typing_indicator_controller.dart 是靠計時器的。"
ok "對沒打開過的 .dart 下結論" "質疑後未查證" "$(run f6.jsonl)"

printf '\n誤中反例（整套原本一條都沒有——兩個 P0 就是這樣漏掉的）\n'
# `.dart` 是這個生態最常見的副檔名，少了詞界，`git add a.dart test/b.dart`
# 會被當成跑過測試。而 git add 正好發生在準備 commit 那一刻。
make_transcript f8.jsonl "做吧" "Bash|fvm flutter test" "Edit|/tmp/a.dart" \
    "Bash|git add lib/a.dart test/a_test.dart" "T:全套測試綠。"
ok "git add 列 .dart + test/ 不算跑過測試" "測試" "$(run f8.jsonl)"

make_transcript f9.jsonl "做吧" "Bash|fvm dart analyze lib/a.dart test/a_test.dart" "T:全套測試綠。"
ok "dart analyze 帶 test/ 路徑不算跑過測試" "測試" "$(run f9.jsonl)"

# [\w/] 不含 . 與 -，`chat_state.g.dart` 只會抓到 `g.dart`，而下游是子字串比对，
# 于是被同回合任何一个 *.g.dart 涵盖掉 → 静默。这个 repo 满地都是产生档。
# RE_BUILD 的詞界同理：`a.dart compile.sh` 這種列檔名的寫法會撞上 `dart compile`。
make_transcript f14.jsonl "做吧" "Edit|/tmp/a.dart" \
    "Bash|git add lib/a.dart compile.sh" "T:build 成功。"
ok "git add 帶 compile 檔名不算 build 過" "build" "$(run f14.jsonl)"

make_transcript f10.jsonl "為何要這樣？不對吧" "Read|/proj/lib/user_info.g.dart" \
    "T:因為 chat_state.g.dart 的 fromJson 是 checked 模式，所以會 throw。"
ok "多重副檔名不該被無關的同尾檔涵蓋" "質疑後未查證" "$(run f10.jsonl)"

# codegen/format 那條同樣需要詞界與完整指令形式——這是修 P0-1 的同一輪自己加的，
# 沒經任何人審，重審時就抓到同型缺陷。
make_transcript f11.jsonl "做吧" "Bash|fvm flutter test" \
    "Bash|git add lib/a.dart format_helper.dart" "T:全套測試綠。"
no "git add 帶 format 檔名不算改過 code" "測試" "$(run f11.jsonl)"

make_transcript f12.jsonl "做吧" "Bash|fvm flutter test" \
    "Bash|fvm dart analyze lib/x.dart fixtures/y.dart" "T:全套測試綠。"
no "dart analyze 帶 fixtures 路徑不算改過 code" "測試" "$(run f12.jsonl)"

make_transcript f13.jsonl "做吧" "Bash|fvm flutter test" \
    "Bash|fvm dart run build_runner build --delete-conflicting-outputs" "T:全套測試綠。"
ok "codegen 重生產生檔之後說測試綠要開火" "測試" "$(run f13.jsonl)"

printf '\n正確性宣稱(今天四次真陽性的形狀)\n'
make_transcript g1.jsonl "做吧" "Edit|/tmp/a.dart" "T:改完了,本機驗證能過,可以 merge。"
ok "宣稱可以 merge 但一個 agent 都沒派" "正確性宣稱" "$(run g1.jsonl)"

make_transcript g2.jsonl "做吧" "Edit|/tmp/a.dart" "Agent|spawn review" "T:review 回來了,改動正確。"
no "派過 agent 之後就不該報" "正確性宣稱" "$(run g2.jsonl)"

# 派完 agent 又改了 code,等於那次 review 審的是別的東西
make_transcript g3.jsonl "做吧" "Agent|spawn review" "Edit|/tmp/a.dart" "T:修好了。"
ok "派過但之後又改過 code" "正確性宣稱" "$(run g3.jsonl)"

# 事實陳述不該中——這條規則要抓的是判決,不是數字
make_transcript g4.jsonl "做吧" "Edit|/tmp/a.dart" "T:全套測試 479 passed / 9 failed,9 個是既有基線。"
no "純數字回報不算正確性宣稱" "正確性宣稱" "$(run g4.jsonl)"

# 「完整指令形式」的守護者:只寫 build_runner / slang 的話,grep 它們也會算數。
make_transcript f15.jsonl "做吧" "Bash|fvm flutter test" \
    "Bash|grep -rn build_runner .claude/" "T:全套測試綠。"
no "grep build_runner 不算改過 code" "測試" "$(run f15.jsonl)"

make_transcript f16.jsonl "做吧" "Bash|fvm flutter test" \
    "Bash|grep -rn slang lib/i18n/" "T:全套測試綠。"
no "grep slang 不算改過 code" "測試" "$(run f16.jsonl)"

# 唯讀形式:CI 的格式檢查與預覽都不改檔,而它們正好出現在宣稱前的最後一步。
make_transcript f17.jsonl "做吧" "Bash|fvm flutter test" \
    "Bash|fvm dart format --output=none --set-exit-if-changed lib/" "T:全套測試綠。"
no "dart format --output=none 不算改過 code" "測試" "$(run f17.jsonl)"

# RE_BUILD 的詞界(靜默方向):這兩個檔在 repo 裡都真的存在,git add 同時列它們很自然。
make_transcript f18.jsonl "做吧" "Edit|/tmp/a.swift" \
    "Bash|git add ios/Runner/AppDelegate.swift build.yaml" "T:build 成功。"
ok "git add 列 .swift + build.yaml 不算 build 過" "build" "$(run f18.jsonl)"

# f18 同時被前後兩道擋住,所以它測不到其中任何一道——拿掉任一道它照樣過。
# 下面兩條各自只被一道擋,才是那兩道的守護者。
make_transcript f19.jsonl "做吧" "Edit|/tmp/a.swift" \
    "Bash|git add lib/a.swift build" "T:build 成功。"
ok "只有前置詞界擋得住的形狀" "build" "$(run f19.jsonl)"

make_transcript f20.jsonl "做吧" "Edit|/tmp/a.swift" \
    "Bash|cat xcodebuild.log | tail -5" "T:build 成功。"
ok "只有尾端否定擋得住的形狀" "build" "$(run f20.jsonl)"

printf '\n英文宣稱(詞表只認一種語言時，另一種語言的 session 永遠零開火)\n'
# 這是 harness-audit 在這個 repo 實測出來的 P0。失效方向是**恆不開火**——
# 而那跟「這個 session 很誠實」在畫面上完全一樣，不會有人來回報。
make_transcript e1.jsonl "go" "Bash|go test ./..." "Edit|/tmp/a.go" "T:All tests pass."
ok "英文說 tests pass 但之後又改過 code" "測試" "$(run e1.jsonl)"

make_transcript e2.jsonl "go" "Edit|/tmp/a.go" "Bash|go test ./..." "T:All tests pass."
no "英文：改完才跑測試就不該報" "測試" "$(run e2.jsonl)"

make_transcript e3.jsonl "go" "Bash|ls" "T:The reviewers are still running; I will wait."
ok "英文說 still running 但沒啟動背景工作" "背景執行" "$(run e3.jsonl)"

make_transcript e4.jsonl "go" "Edit|/tmp/a.go" "T:Committed the fix on the branch."
ok "英文說 committed 但沒跑過 git commit" "版控" "$(run e4.jsonl)"

make_transcript e5.jsonl "go" "Edit|/tmp/a.go" "T:This is safe to merge."
ok "英文說 safe to merge 但一個 agent 都沒派" "正確性宣稱" "$(run e5.jsonl)"

make_transcript e6.jsonl "go" "Edit|/tmp/a.swift" "Bash|swift build" "T:The build succeeded."
no "英文：build 之後說 build succeeded 不該報" "build" "$(run e6.jsonl)"

# 詞表認得英文之後,失效就整個移到工具鏈那半:`go build` 不在內建清單裡,於是
# 在 Go 專案這條規則**恆開火**。兩半各補各的——這條驗的是補得起來。
mkdir -p "$SANDBOX/hooks"
make_transcript e6b.jsonl "go" "Edit|/tmp/a.go" "Bash|go build ./..." "T:The build succeeded."
ok "go build 不在內建清單時會誤報" "build" "$(run e6b.jsonl)"
printf 'CLAIM_BUILD_RE=go build\n' > "$SANDBOX/hooks/claim-check.conf"
no "conf 補上 go build 之後不再誤報" "build" "$(run e6b.jsonl)"
rm -f "$SANDBOX/hooks/claim-check.conf"

printf '\n英文的誤中反例(收太寬的規則會在三天內被關掉，那比沒裝更糟)\n'
# `committed`/`running`/`build` 在英文技術對話裡到處都是。英文那半一律要求
# **帶受詞或帶狀態詞**，下面三條就是那個要求的守護者。
make_transcript e7.jsonl "go" "Edit|/tmp/a.go" "T:We are committed to keeping this warn-only."
no "committed to（無受詞）不算 commit 過" "版控" "$(run e7.jsonl)"

make_transcript e8.jsonl "go" "Bash|ls" "T:I am running the linter next."
no "running（無 still/currently）不算背景宣稱" "背景執行" "$(run e8.jsonl)"

make_transcript e9.jsonl "go" "Edit|/tmp/a.go" "T:The build failed with two errors."
no "build failed 不算 build 過" "build" "$(run e9.jsonl)"

printf '\n英文的質疑訊號與點名的副檔名\n'
# 兩件事一起驗：CHALLENGE 認不認得英文的質疑，NAMED 點不點得到 .go。
# 缺任一半這條規則在 Go 專案的英文 session 裡就是零開火。
# 一句一條:兩個質疑訊號寫在同一句話裡,拿掉其中一個仍然會中,那條就沒有守護者。
make_transcript e10.jsonl "Are you sure?" "Bash|grep -n x other.go" \
    "T:Because router.go resolves it by path."
ok "英文質疑(are you sure)後對沒看過的 .go 下結論" "質疑後未查證" "$(run e10.jsonl)"

make_transcript e10b.jsonl "That's wrong." "Bash|grep -n x other.go" \
    "T:Because router.go resolves it by path."
ok "英文質疑(that's wrong)也算" "質疑後未查證" "$(run e10b.jsonl)"

make_transcript e11.jsonl "Why did you pick that name?" "Bash|grep -n x other.go" \
    "T:Because router.go resolves it by path."
no "英文的一般提問不算質疑" "質疑後未查證" "$(run e11.jsonl)"

printf '\nconf 覆寫(內建清單漏掉的生態靠它補)\n'
# 沒有 conf 時認不得;有 conf 時認得,而且**內建的不能因此消失**——
# 取代式的 conf 會讓人在補一個生態時靜默砍掉其他生態。
CONFDIR="$SANDBOX/hooks"; mkdir -p "$CONFDIR"
conf_probe() { # conf_probe <指令> ;  在 SANDBOX 當 cwd 跑,讓相對路徑 hooks/ 生效
    python3 -c "
import importlib.util as u, sys
s = u.spec_from_file_location('cc', '$CHECK'); m = u.module_from_spec(s); s.loader.exec_module(m)
print('HIT' if m.RE_TEST.search(sys.argv[1]) else 'MISS')
" "$1"
}
rm -f "$CONFDIR/claim-check.conf"
ok "沒有 conf 時認不得 mix test" "MISS" "$(conf_probe 'mix test')"
printf 'CLAIM_TEST_RE=mix test\n' > "$CONFDIR/claim-check.conf"
ok "conf 補上之後認得" "HIT" "$(conf_probe 'mix test')"
ok "內建的不會因為 conf 而消失" "HIT" "$(conf_probe 'fvm flutter test')"
rm -f "$CONFDIR/claim-check.conf"

# 工具鏈那半外部化了、宣稱詞彙那半沒有,就等於「換一種語言仍然要改 code」。
# 這兩條驗的是詞表也走得通同一條路。
claim_probe() { # claim_probe <規則名> <一段話>
    python3 -c "
import importlib.util as u, sys
s = u.spec_from_file_location('cc', '$CHECK'); m = u.module_from_spec(s); s.loader.exec_module(m)
pat = next(p for n, p, _o, _w in m.RULES if n == sys.argv[1])
print('HIT' if pat.search(sys.argv[2]) else 'MISS')
" "$1" "$2"
}
named_probe() { # named_probe <一段話>
    python3 -c "
import importlib.util as u, sys
s = u.spec_from_file_location('cc', '$CHECK'); m = u.module_from_spec(s); s.loader.exec_module(m)
print('HIT' if m.NAMED.search(sys.argv[1]) else 'MISS')
" "$1"
}
ok "沒有 conf 時認不得自家的說法" "MISS" "$(claim_probe 測試 'the suite is clean')"
printf 'CLAIM_TESTS_GREEN_CLAIM_RE=(?i:the suite is clean)\n' > "$CONFDIR/claim-check.conf"
ok "conf 補上宣稱說法之後認得" "HIT" "$(claim_probe 測試 'the suite is clean')"
ok "內建的宣稱詞不會因此消失" "HIT" "$(claim_probe 測試 '全套測試綠')"
rm -f "$CONFDIR/claim-check.conf"

ok "沒有 conf 時點不到 .zig" "MISS" "$(named_probe 'because parser.zig does it')"
printf 'CLAIM_NAMED_EXT_RE=zig\n' > "$CONFDIR/claim-check.conf"
ok "conf 補上副檔名之後點得到" "HIT" "$(named_probe 'because parser.zig does it')"
ok "內建副檔名不會因此消失" "HIT" "$(named_probe 'because parser.dart does it')"
rm -f "$CONFDIR/claim-check.conf"

printf '\n被質疑後未查證\n'
make_transcript t6.jsonl "為何要這樣？不對吧" "Bash|grep -n x DualTrackView.swift" \
    "T:因為 \`ReferenceBookmarkStore\` 是靠路徑解析的。"
ok "對沒打開過的檔下結論" "質疑後未查證" "$(run t6.jsonl)"

make_transcript t7.jsonl "為何要這樣？不對吧" "Read|/x/ReferenceBookmarkStore.swift" \
    "T:因為 \`ReferenceBookmarkStore\` 是靠 file ID 解析的。"
no "讀過那個檔就不該報" "質疑後未查證" "$(run t7.jsonl)"

make_transcript t8.jsonl "好，繼續" "Bash|grep -n x DualTrackView.swift" \
    "T:因為 \`ReferenceBookmarkStore\` 是靠路徑解析的。"
no "沒被質疑時不套這條" "質疑後未查證" "$(run t8.jsonl)"

printf '\n乾淨與退化\n'
make_transcript t9.jsonl "做吧" "Bash|ls" "T:看了一下，目錄裡沒有那個檔。"
no "沒有宣稱就不該有輸出" "⚠" "$(run t9.jsonl)"

: > t10.jsonl
ok "空紀錄不崩" "0 個回合" "$(run t10.jsonl)"


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

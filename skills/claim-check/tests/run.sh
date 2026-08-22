#!/bin/sh
# claim-check 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 守的是**沉默的兩面**：一個永遠不開火的 checker 跟一個真的很乾淨的 session 長得一樣；
# 一個到處開火的 checker 會在三天內被關掉。所以每條規則都要有正例與反例。

set -u
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

out=$(CLAIM_CHECK_HOME="$H1" sh "$INST" 2>&1)
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

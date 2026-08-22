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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

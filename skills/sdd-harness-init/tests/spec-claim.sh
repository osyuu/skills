#!/bin/sh
# spec-claim-check 的回歸測試。無相依，`sh tests/spec-claim.sh` 直接跑。
#
# 這支守的是**沉默的假陽性與假陰性**：一個只會印「沒問題」的檢查器，跟一個真的沒問題的
# repo 長得一模一樣。三個訊號各要有正例與反例，否則沒人知道它到底有沒有在做事。

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
CHECK=$(cd "$HERE/.." && pwd)/assets/spec-claim-check.sh

SANDBOX=$(mktemp -d)
trap 'cd /; rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX" || exit 1
pass=0
fail=0

ok() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }

fresh() {
    rm -rf "$SANDBOX/r"; mkdir -p "$SANDBOX/r/app" "$SANDBOX/r/tests" "$SANDBOX/r/hooks"
    cd "$SANDBOX/r" || exit 1
    cat > hooks/spec-claim.conf <<'EOF'
SPEC_SRC_DIRS="app"
SPEC_TEST_DIRS="tests"
EOF
}

printf '\n訊號 1：打勾的任務 vs 未打勾的驗收項\n'

fresh
cat > design-doc-x.md <<'EOF'
| T1 | ✅ 做完了 | — | 驗證（AC1） |
- [ ] **AC1** 這條還沒驗
EOF
ok "✅ 配未打勾的 AC 要報" "AC1 還是未打勾" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
| T1 | ✅ 做完了 | — | 驗證（AC1） |
- [x] **AC1** 驗過了
EOF
no "AC 打勾了就不該報" "AC1" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
| T1 | ◐ 部分完成 | — | 驗證（AC1） |
- [ ] **AC1** 還沒驗
EOF
no "沒宣稱完成就不該報" "AC1" "$(sh "$CHECK" 2>&1)"

printf '\n訊號 2：spec 點名的符號有定義卻沒有消費者\n'

fresh
printf 'struct S { var anchorFrequency: Double { 1 } }\n' > app/a.swift
printf 'XCTAssertEqual(anchorFrequency, 1)\n' > tests/t.swift
printf '記號畫在 `anchorFrequency` 上。\n' > design-doc-x.md
out=$(sh "$CHECK" 2>&1)
ok "死碼＋測試在用它，要報" "沒有消費者" "$out"
ok "要點明測試會綠這件事" "測試會綠" "$out"

fresh
printf 'struct S { var anchorFrequency: Double { 1 } }\nlet y = anchorFrequency\n' > app/a.swift
printf '記號畫在 `anchorFrequency` 上。\n' > design-doc-x.md
no "有產品消費者就不該報" "anchorFrequency" "$(sh "$CHECK" 2>&1)"

# 散文點名框架 API 是常態：它在原始碼裡出現一次正是「被呼叫了一次」。
# 不擋掉這類，實測誤判佔九成，而會被無視的 hook 等於沒裝。
fresh
printf 'let n = AVAudioSourceNode()\n' > app/a.swift
printf '播放走 `AVAudioSourceNode`。\n' > design-doc-x.md
no "非本 repo 定義的符號不該報" "AVAudioSourceNode" "$(sh "$CHECK" 2>&1)"

fresh
printf 'struct PitchView_Previews { }\n' > app/a.swift
printf '見 `PitchView_Previews`。\n' > design-doc-x.md
no "preview 型別天生沒有使用者，不報" "PitchView_Previews" "$(sh "$CHECK" 2>&1)"

printf '\n訊號 3：spec 宣告的介面不存在\n'

fresh
printf 'func takePendingLoop() {}\n' > app/a.swift
printf '契約：`takePendingPractice()` 取走即清空。\n' > design-doc-x.md
ok "spec 的方法簽名在 code 裡找不到，要報" "takePendingPractice()" "$(sh "$CHECK" 2>&1)"

fresh
printf 'func takePendingLoop() {}\nlet x = takePendingLoop()\n' > app/a.swift
printf '契約：`takePendingLoop()` 取走即清空。\n' > design-doc-x.md
no "介面存在就不該報" "takePendingLoop()" "$(sh "$CHECK" 2>&1)"

# 散文提到還沒做的東西是設計書的常態，只有寫成方法簽名才算宣告契約。
fresh
printf 'func f() {}\n' > app/a.swift
printf '未來會加一個 `futureThing` 來處理。\n' > design-doc-x.md
no "不帶括號的未來概念不該報" "futureThing" "$(sh "$CHECK" 2>&1)"

printf '\n退化輸入\n'

fresh
ok "沒有 spec 檔就安靜結束" "" "$(sh "$CHECK" 2>&1)"

fresh
printf '沒有任何符號也沒有任務表。\n' > design-doc-x.md
no "乾淨的 spec 不該有輸出" "⚠" "$(sh "$CHECK" 2>&1)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

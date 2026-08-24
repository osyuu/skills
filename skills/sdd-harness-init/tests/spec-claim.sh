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

printf '\n訊號 1b：無 AC-ID 的 spec（design-doc 形狀）\n'

fresh
cat > design-doc-x.md <<'EOF'
## 任務
- [x] core 實作
- [x] cli 實作
## 驗收標準
- [x] 基本計數 — 驗證:單元測試
- [ ] 分層規則 — 驗證:arch-guard
EOF
ok "checkbox 任務全勾、驗收有未勾要報" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
## 任務
- [x] core 實作
- [ ] cli 實作
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
no "任務還有未勾就不該報" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
## Task Breakdown
- [x] core impl
## Acceptance Criteria
- [x] basic counting — verified by unit test
EOF
no "驗收全勾就不該報" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# design-doc 模板 §16 的預設形狀是表格。從未標記過的表格＝沒有宣稱，不評；
# 全數 ✅ 的表格＝宣稱完成，要跟驗收對。
fresh
cat > design-doc-x.md <<'EOF'
## 16. 任務分解 (Task Breakdown)
| # | 任務 | 依賴 |
| T1 | 做 core | — |
| T2 | 做 cli | T1 |
## 17. 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
no "未標記的任務表不算宣稱完成" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
## 16. 任務分解 (Task Breakdown)
| # | 任務 | 依賴 |
| T1 | 做 core ✅ | — |
| T2 | 做 cli ✅ | T1 |
## 17. 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
ok "任務表全 ✅、驗收有未勾要報" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# 混標的任務表（部分 ✅）是最常見的真實狀態——未標列要算未完，不然就是誤報。
fresh
cat > design-doc-x.md <<'EOF'
## 任務分解
| T1 | 做 core ✅ | — |
| T2 | 做 cli | T1 |
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
no "混標任務表不算全數完成" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
cat > design-doc-x.tasks.md <<'EOF'
- [x] 做 core
- [ ] 做 cli
EOF
no "部分完成的 tasks.md 不算全數完成" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# 一級標題當節也要認得——標題偵測退化成只認 ## 時要有測試變紅。
fresh
cat > design-doc-x.md <<'EOF'
# 任務
- [x] core 實作
# 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
ok "一級標題的任務/驗收節也認得" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# `- [~]` 是明示延後，不是完成宣稱——全 [~] 不該報。
fresh
cat > design-doc-x.md <<'EOF'
## 任務
- [~] core 實作（下期收）
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
no "全部延後不算宣稱完成" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# design-doc 模板允許把勾選拆到同名 <slug>.tasks.md——關聯要跨到那個檔。
fresh
cat > design-doc-x.md <<'EOF'
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
cat > design-doc-x.tasks.md <<'EOF'
- [x] 做 core
- [x] 做 cli
EOF
ok "sibling tasks.md 全勾、spec 驗收未勾要報" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# 標題匹配要錨定：「後續任務」不是任務節（它的未勾項不該壓掉警告）、
# 「驗收後注意事項」不是驗收節（它的未勾項不該觸發假警告）。
fresh
cat > design-doc-x.md <<'EOF'
## 任務
- [x] core 實作
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
## 後續任務
- [ ] 之後再說的事
EOF
ok "「後續任務」的未勾項不壓掉警告" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

fresh
cat > design-doc-x.md <<'EOF'
## 任務
- [x] core 實作
## 驗收標準
- [x] 基本計數 — 驗證:單元測試
## 驗收後注意事項
- [ ] 上線後觀察記憶體
EOF
no "「驗收後注意事項」的未勾項不觸發假警告" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# ### 子節不洗掉任務節狀態；縮排 checkbox 也要計入。
fresh
cat > design-doc-x.md <<'EOF'
## 任務
### Phase 1
- [x] core 實作
### Phase 2
  - [ ] cli 實作
## 驗收標準
- [ ] 基本計數 — 驗證:單元測試
EOF
no "子節與縮排的未勾任務要算數" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

# 有 AC-ID 的 spec 歸訊號 1 管，1b 讓路——同一筆 drift 不該報兩行。
fresh
cat > design-doc-x.md <<'EOF'
## 任務
- [x] T1 做完 ✅ AC1
## 驗收標準
- [ ] **AC1** 還沒驗
EOF
out=$(sh "$CHECK" 2>&1)
ok "AC-ID spec 由訊號 1 報" "AC1 還是未打勾" "$out"
no "AC-ID spec 訊號 1b 不重複報" "任務已全數勾銷" "$out"

# 標題不含 任務/驗收 的檔（如 DECISIONS.md）有未勾項是它自己的事。
fresh
cat > design-doc-x.md <<'EOF'
## 記錄
- [ ] 2026-01-01 | 某翻案 | 理由 | → 目標
EOF
no "非任務/驗收節的未勾項不歸 1b 管" "任務已全數勾銷" "$(sh "$CHECK" 2>&1)"

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

printf '\nSPEC_SRC_DIRS 沒配好時的退化\n'

# 訊號 1 只讀 spec 裡的打勾狀態,不需要原始碼目錄——路徑填錯不該把它一起帶走。
fresh
cat > hooks/spec-claim.conf <<'EOF'
SPEC_SRC_DIRS="no-such-dir"
SPEC_TEST_DIRS="tests"
EOF
cat > design-doc-x.md <<'EOF'
| T1 | ✅ 做完了 | — | 驗證（AC1） |
- [ ] **AC1** 這條還沒驗
EOF
ok "路徑填錯時訊號 1 仍要開火" "AC1 還是未打勾" "$(sh "$CHECK" 2>&1)"
ok "路徑填錯本身要出聲" "SPEC_SRC_DIRS" "$(sh "$CHECK" 2>&1)"

# 反面:目錄存在時不該冒出那句警告。
fresh
printf 'func f() {}\n' > app/a.swift
printf '沒有任何符號也沒有任務表。\n' > design-doc-x.md
no "路徑正確時不該抱怨 SPEC_SRC_DIRS" "SPEC_SRC_DIRS" "$(sh "$CHECK" 2>&1)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

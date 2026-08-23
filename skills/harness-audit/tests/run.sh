#!/bin/sh
# harness-audit 的腳本測試。
#
# 這兩支腳本的失敗模式都是靜默的：掃不到 skill、驗證永遠回「沒開火」——
# 輸出跟「真的沒有」長得一樣。所以失敗路徑要跟成功路徑一起測。
set -u
DIR=$(cd "$(dirname "$0")/.." && pwd)
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng()   { FAIL=$((FAIL+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else ng "$1（期望 $3，實得 $2）"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "scan-skills.sh"

# 假 cache：一個正常 skill、一個折疊式 description、一個 orphaned 舊版
mk() {
    mkdir -p "$1"
    { echo "---"; echo "name: $2"; shift 2; for l in "$@"; do echo "$l"; done; echo "---"; echo body; } > "$1/SKILL.md"
}
mk "$TMP/cache/mkt/plug/v1/skills/alpha" alpha "description: 單行描述"
mk "$TMP/cache/mkt/plug/v1/skills/beta"  beta  "description: >-" "  折疊第一行" "  折疊第二行"
mk "$TMP/cache/mkt/plug/v0/skills/alpha" alpha "description: 舊版不該出現"
touch "$TMP/cache/mkt/plug/v0/.orphaned_at"
mk "$TMP/cache/mkt/plug/v1/template/gamma" gamma "description: 非 skills 佈局"

out=$(CLAUDE_PLUGIN_CACHE="$TMP/cache" sh "$DIR/scripts/scan-skills.sh" 2>/dev/null)
check "掃到兩個 skill" "$(printf '%s\n' "$out" | grep -c .)" "2"
check "折疊式 description 展開" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$1=="beta"{print $2}')" "折疊第一行 折疊第二行"
check "orphaned 版本被濾掉" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$1=="alpha"{print $2}')" "單行描述"
check "非 skills/ 佈局跳過" "$(printf '%s\n' "$out" | grep -c gamma)" "0"

out=$(CLAUDE_PLUGIN_CACHE="$TMP/nonexistent" sh "$DIR/scripts/scan-skills.sh" 2>/dev/null; echo "rc=$?")
check "cache 不存在時報錯" "$(printf '%s' "$out" | tail -1)" "rc=1"

echo "verify-guard.sh"

R="$TMP/repo"; mkdir -p "$R/hooks"
(cd "$R" && git init -q && git config user.email t@t && git config user.name t \
    && git config core.hooksPath hooks)
printf '#!/bin/sh\ngit diff --cached --name-only | grep -q BAD && echo "偵測到違規"\nexit 0\n' > "$R/hooks/pre-commit"
chmod +x "$R/hooks/pre-commit"
(cd "$R" && echo seed > seed.txt && git add . && git commit -qm init)

rc() { (cd "$R" && sh "$DIR/scripts/verify-guard.sh" "$@" >/dev/null 2>&1; echo $?); }

check "缺參數 → 2"        "$(rc)"                          "2"
check "檔案不存在 → 2"    "$(rc BAD_missing.txt 違規)"     "2"

(cd "$R" && echo x > BAD_hit.txt)
check "該開火 → 0"        "$(rc BAD_hit.txt 偵測到違規)"   "0"
check "開火後檔案已清"    "$([ -f "$R/BAD_hit.txt" ] && echo 留 || echo 清)" "清"

(cd "$R" && echo x > GOOD.txt)
check "不該開火 → 1"      "$(rc GOOD.txt 偵測到違規)"      "1"
check "沒開火時保留檔案"  "$([ -f "$R/GOOD.txt" ] && echo 留 || echo 清)"    "留"
(cd "$R" && rm -f GOOD.txt)

(cd "$R" && echo staged > S.txt && git add S.txt)
(cd "$R" && echo x > BAD_dirty.txt)
check "index 不乾淨 → 2"  "$(rc BAD_dirty.txt 偵測到違規)" "2"
check "使用者的 staged 沒被動到" \
    "$(cd "$R" && git diff --cached --name-only | tr -d '\n')" "S.txt"

echo
printf 'PASS %d · FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

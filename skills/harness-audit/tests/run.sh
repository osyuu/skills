#!/bin/sh
# harness-audit 的腳本測試。
#
# 這兩支的失敗模式都是靜默的：掃不到 skill、驗證永遠回「沒開火」——輸出跟
# 「真的沒有」長得一樣。所以失敗路徑要跟成功路徑一起測。
set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

DIR=$(cd "$(dirname "$0")/.." && pwd)
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng()   { FAIL=$((FAIL+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else ng "$1（期望 [$3]，實得 [$2]）"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "scan-skills.sh"
w() { _p="$1"; shift; mkdir -p "$_p"; { for l in "$@"; do echo "$l"; done; } > "$_p/SKILL.md"; }

C="$TMP/cache"
w "$C/mkt/plugA/v1/skills/alpha"  "---" "name: alpha" "description: 單行描述" "---" "body"
w "$C/mkt/plugA/v1/skills/beta"   "---" "name: beta"  "description: >-" "  折疊第一行" "  折疊第二行" "---"
w "$C/mkt/plugA/v1/skills/plain"  "---" "name: plain" "description: 首行" "  續行" "---"
w "$C/mkt/plugA/v1/skills/nodesc" "---" "name: nodesc" "---" "body"
w "$C/mkt/plugA/v0/skills/alpha"  "---" "name: alpha" "description: 舊版不該出現" "---"
touch "$C/mkt/plugA/v0/.orphaned_at"
w "$C/mkt/plugB/v1/skills/alpha"  "---" "name: alpha" "description: 另一個 plugin 的同名" "---"
w "$C/mkt/plugA/v1/template/skip" "---" "name: skip" "description: 非 skills 佈局" "---"
mkdir -p "$C/mkt/plugA/v1/skills/crlf"
printf -- '---\r\nname: crlf\r\ndescription: CRLF 描述\r\n---\r\n' > "$C/mkt/plugA/v1/skills/crlf/SKILL.md"
w "$C/mkt/plugA/v1/skills/ascii" "---" "name: ascii" "description: abcdefgh" "---"

# plugC 宣告一個 skill，但目錄裡躺著三個（source: "./" 的實況）
w "$C/mkt/plugC/v1/skills/real"    "---" "name: real"    "description: 真的" "---"
w "$C/mkt/plugC/v1/skills/ghostA"  "---" "name: ghostA"  "description: 幻影A" "---"
w "$C/mkt/plugC/v1/skills/ghostB"  "---" "name: ghostB"  "description: 幻影B" "---"
mkdir -p "$C/mkt/plugC/v1/.claude-plugin"
cat > "$C/mkt/plugC/v1/.claude-plugin/marketplace.json" <<'MJ'
{"plugins":[{"name":"plugC","skills":["./skills/real"]},{"name":"other","skills":["./skills/ghostA"]}]}
MJ
# plugD 宣告多個 skill（ui-ux-pro-max 的形狀）——用目錄名猜會在這裡翻車
w "$C/mkt/plugD/v1/skills/one" "---" "name: one" "description: 其一" "---"
w "$C/mkt/plugD/v1/skills/two" "---" "name: two" "description: 其二" "---"
mkdir -p "$C/mkt/plugD/v1/.claude-plugin"
cat > "$C/mkt/plugD/v1/.claude-plugin/marketplace.json" <<'MJ'
{"plugins":[{"name":"plugD","skills":["./skills/one","./skills/two"]}]}
MJ

out=$(CLAUDE_PLUGIN_CACHE="$C" sh "$DIR/scripts/scan-skills.sh" 2>/dev/null)
g() { printf '%s\n' "$out" | awk -F'\t' -v k="$1" '$1==k{print $2}'; }

check "輸出限定名 plugin:skill" "$(g plugA:alpha)"  "單行描述"
check "折疊式 >- 展開"          "$(g plugA:beta)"   "折疊第一行 折疊第二行"
check "plain 多行 scalar 展開"  "$(g plugA:plain)"  "首行 續行"
check "無 description 仍列出"   "$(g plugA:nodesc)" "(無描述)"
check "CRLF 檔案讀得到"         "$(g plugA:crlf)"   "CRLF 描述"
check "orphaned 版本被濾掉"     "$(printf '%s\n' "$out" | grep -c '舊版不該出現')" "0"
check "跨 plugin 同名都保留"    "$(g plugB:alpha)"  "另一個 plugin 的同名"
check "非 skills/ 佈局跳過"     "$(printf '%s\n' "$out" | grep -c ':skip')" "0"

check "預設不截斷" "$(g plugA:ascii)" "abcdefgh"
# 用 ASCII 測截斷：awk 的 substr 是 byte-based，中文會被切出壞掉的 UTF-8
out2=$(CLAUDE_PLUGIN_CACHE="$C" HARNESS_AUDIT_DESC_MAX=4 sh "$DIR/scripts/scan-skills.sh" 2>/dev/null)
check "MAXLEN 生效" "$(printf '%s\n' "$out2" | awk -F'\t' '$1=="plugA:ascii"{print $2}')" "abcd…"

check "宣告清單過濾掉幻影"   "$(printf '%s\n' "$out" | grep -c '^plugC:ghost')" "0"
check "宣告的 skill 保留"     "$(g plugC:real)" "真的"
check "一個 plugin 多個 skill" "$(printf '%s\n' "$out" | grep -c '^plugD:')" "2"
check "無 marketplace.json 的照收" "$(printf '%s\n' "$out" | grep -c '^plugA:')" "6"

out3=$(CLAUDE_PLUGIN_CACHE="$C//" sh "$DIR/scripts/scan-skills.sh" 2>/dev/null)
check "多層結尾斜線" "$(printf '%s\n' "$out3" | awk -F'\t' '$1=="plugA:alpha"{print $2}')" "單行描述"

rc=$(CLAUDE_PLUGIN_CACHE="$TMP/none" sh "$DIR/scripts/scan-skills.sh" >/dev/null 2>&1; echo $?)
check "cache 不存在 → 1" "$rc" "1"

echo "verify-guard.sh"
R="$TMP/repo"; mkdir -p "$R/hooks"
(cd "$R" && git init -q && git config user.email t@t && git config user.name t && git config core.hooksPath hooks)
# 輸出刻意含 regex 特殊字元：守門用 [name] 當前綴是常態
printf '#!/bin/sh\ngit diff --cached --name-only | grep -q BAD && echo "[guard] 違規 core/UI.swift"\nexit 0\n' > "$R/hooks/pre-commit"
chmod +x "$R/hooks/pre-commit"
(cd "$R" && echo seed > seed.txt && echo tracked > BAD_tracked.txt && git add . && git commit -qm init)
rc() { (cd "$R" && sh "$DIR/scripts/verify-guard.sh" "$@" >/dev/null 2>&1; echo $?); }
new() { (cd "$R" && echo x > "$1"); }

check "缺參數 → 2"     "$(rc)"                    "2"
check "檔案不存在 → 2" "$(rc BAD_none.txt k)"     "2"

new BAD_a.txt; check "該開火 → 0"      "$(rc BAD_a.txt '[guard]')" "0"
check "開火後檔案清掉" "$([ -f "$R/BAD_a.txt" ] && echo 留 || echo 清)" "清"

# 這兩條是 grep -F 的核心：BRE 下 [guard] 會炸、core.UI 會誤中 core/UI
new BAD_b.txt; check "關鍵字含 [] 仍字面比對" "$(rc BAD_b.txt '[guard] 違規')" "0"
new BAD_c.txt; check "關鍵字的 . 不當萬用字元" "$(rc BAD_c.txt '違規 core.UI')" "1"
(cd "$R" && rm -f BAD_c.txt)

new GOOD_a.txt; check "expect-no-fire 正確放行 → 0" "$(rc --expect-no-fire GOOD_a.txt '[guard]')" "0"
new BAD_d.txt;  check "expect-no-fire 卻開火 → 1"   "$(rc --expect-no-fire BAD_d.txt '[guard]')" "1"
(cd "$R" && rm -f BAD_d.txt)

(cd "$R" && echo modified > BAD_tracked.txt)
check "拒絕已 tracked 的檔案 → 2" "$(rc BAD_tracked.txt '[guard]')" "2"
check "被拒檔案的未 commit 修改還在" "$(cd "$R" && cat BAD_tracked.txt)" "modified"
(cd "$R" && git checkout -q -- BAD_tracked.txt)

new BAD_g.txt
check "旗標放在參數後 → 2" "$(rc BAD_g.txt '[guard]' --expect-no-fire)" "2"
check "被拒時檔案沒被刪" "$([ -f "$R/BAD_g.txt" ] && echo 在 || echo 沒了)" "在"
(cd "$R" && rm -f BAD_g.txt)

new BAD_h.txt
out_clean=$(cd "$R" && sh "$DIR/scripts/verify-guard.sh" BAD_h.txt '[guard]' 2>/dev/null)
check "stdout 沒有 diff header" "$(printf '%s' "$out_clean" | grep -c '^diff --git')" "0"

(cd "$R" && git config core.hooksPath "$R/hooks")
new BAD_e.txt; check "絕對路徑 hooksPath" "$(rc BAD_e.txt '[guard]')" "0"
(cd "$R" && git config core.hooksPath hooks)

(cd "$R" && echo staged > S.txt && git add S.txt)
new BAD_f.txt; check "index 不乾淨 → 2" "$(rc BAD_f.txt '[guard]')" "2"
check "使用者的 staged 沒被動到" "$(cd "$R" && git diff --cached --name-only | tr -d '\n')" "S.txt"
(cd "$R" && git reset -q HEAD -- S.txt && rm -f S.txt BAD_f.txt)

echo
printf 'PASS %d · FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

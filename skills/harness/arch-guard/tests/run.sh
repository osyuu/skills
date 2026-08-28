#!/bin/sh
# arch-guard-check 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 為什麼這支存在：checker 的失敗模式幾乎都是**靜默的**——壞掉的 pattern、少一個欄位、
# 打錯的 mode，全都回「0 條違規」，而那跟「這個 repo 很乾淨」長得一模一樣。讀 code 看不出
# 差別，跑一次就現形。新增規則型別或改 config 解析時，這裡要跟著加案例。

set -u
# `git commit` 會把 GIT_DIR / GIT_INDEX_FILE 之類傳給 hook，沙箱裡的 git 會因此
# 操作到**外層** repo，測試結果變成在量別人。單獨跑時全綠、從 pre-commit 跑時
# 隨機紅——比沒有測試更糟。
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR GIT_CONFIG_PARAMETERS 2>/dev/null || true

HERE=$(cd "$(dirname "$0")" && pwd)
CHECK="$HERE/../assets/arch-guard-check.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0
fail=0

# ── fixture：一個有分層違規也有必經點違規的小 repo ───────────────────────
cd "$WORK" || exit 1
git init -q .
git config user.email t@t
git config user.name t
mkdir -p lib/core lib/features/f1 lib/features/f2
cat > lib/core/a.dart <<'EOF'
import 'package:pkg/features/f1/a.dart';
class CoreOne extends StateNotifier<int> {}
EOF
cat > lib/features/f1/a.dart <<'EOF'
import 'package:pkg/features/f2/b.dart';
class Old extends StateNotifier<int> {}
class Two extends ChangeNotifier {}
void f() { DioXclient(); }
EOF
echo "class B {}" > lib/features/f2/b.dart
git add -A
git commit -qm init

conf() {  # $1 = CHOKEPOINTS 內容
  cat > "$WORK/c.sh" <<EOF
ROOT="lib"
IGNORE="__never_matches__"
PACKAGE="pkg"
IMPORT_RE="import 'package:\${PACKAGE}/{LAYER}/"
LAYERS="$LAYERS_V"
PARTITIONED="$PART_V"
CHOKEPOINTS="
$1
"
EOF
}
run() { ARCH_LAYERS_CONF="$WORK/c.sh" sh "$CHECK" "${1:---audit}" 2>&1 | sed 's/\033\[[0-9;]*m//g'; }

ok() {   # $1=label $2=needle $3=output
  case "$3" in
    *"$2"*) pass=$((pass + 1)); printf '  ok    %s\n' "$1" ;;
    *) fail=$((fail + 1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  esac
}
no() {   # 同上，但要求「不含」
  case "$3" in
    *"$2"*) fail=$((fail + 1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
    *) pass=$((pass + 1)); printf '  ok    %s\n' "$1" ;;
  esac
}

LAYERS_V=""
PART_V=""

echo "── 必經點：pattern 內容 ──"
# 分隔符不能用 `|`：那是 ERE 的 alternation，`(A|B)` 會被切成兩半、產生不合法的 pattern。
conf 'all:::extends (StateNotifier|ChangeNotifier):::no new notifier'
out=$(run); ok "alternation 不被欄位分隔吃掉" "共 3 條違規" "$out"

# `\.` 經 awk -v 會塌成 `.`，於是 new 比 all 多抓 DioXclient。兩個模式必須一致。
printf 'void g() { Dio.instance; }\nvoid h() { DioXclient(); }\n' >> lib/features/f1/a.dart
git add -A
conf 'new:::Dio\.:::dio 直呼'
out=$(run); ok  "new 模式：跳脫生效，只抓 Dio."     "Dio.instance" "$out"
no "new 模式：跳脫生效，不抓 DioXclient" "DioXclient" "$out"

# awk 拿的是還帶著 `+` 的 diff 行，`^` 永遠配不到。
printf "import 'package:dio/dio.dart';\n" >> lib/features/f1/a.dart
git add -A
conf "new:::^import 'package:dio:::dio 只准在 core"
out=$(run); ok "new 模式：^ 錨點配得到" "共 1 條違規" "$out"

echo "── 必經點：config 格式 ──"
# 欄位不足時 allow 會被推導成 pat，把所有命中滤光——必須出聲而不是靜默降級。
conf 'all:::extends StateNotifier'
out=$(run); ok "欄位數不對要出聲" "栏位数不是 3 或 4" "$out"

conf 'All:::extends StateNotifier:::mode 打錯'
out=$(run); ok "mode 打錯要出聲" "mode 只能是 all 或 new" "$out"

conf '  # all:::extends StateNotifier:::被註解掉的規則'
out=$(run); no "縮排過的註解行不生效" "被註解掉的規則" "$out"

conf 'all:::extends StateNotifier:::no new:::^lib/core/'
out=$(run)
no "allow 路徑被排除"           "lib/core/a.dart"        "$out"
ok "allow 沒有把其餘一起濾光"   "lib/features/f1/a.dart" "$out"

# needle 是 pattern **自身被回顯**（regcomp 系的慣例會把壞 pattern 印回來），
# 不是 git 的文案——別拿「不要耦合在別人的訊息格式上」把這條改掉。
conf 'all:::(unclosed:::壞 pattern 要出聲'
out=$(run); ok "all 模式的壞 pattern 不被吞掉" "unclosed" "$out"

# 這條驗的是**空字串不會把解析弄壞**,所以 LAYERS 要留著——兩邊都空是「沒有規則
# 可跑」,checker 現在會對那種 conf 出聲(見下面〈沒有規則可跑〉那組)。
LAYERS_V="core"
conf ''
out=$(run); ok "CHOKEPOINTS 空時乾淨退出" "共 0 條違規" "$out"
LAYERS_V=""

echo "── 分層規則（既有功能，別被改壞）──"
LAYERS_V="features core"
PART_V="features"
conf ''
out=$(run)
ok "抓得到往上依賴"       "core → features" "$out"
ok "抓得到 sibling 互 import" "f1 → f2"        "$out"

echo "── 兩族規則並存 ──"
LAYERS_V="features core"
PART_V="features"
conf 'all:::extends StateNotifier:::no new notifier'
out=$(run)
ok "並存時分層違規仍在"   "core → features"  "$out"
ok "並存時必經點違規仍在" "no new notifier"  "$out"
ok "計數把兩族加在一起"   "共 4 條違規"      "$out"

LAYERS_V=""
PART_V=""
conf 'all:::extends StateNotifier:::no new notifier'
ARCH_LAYERS_CONF="$WORK/c.sh" sh "$CHECK" --strict >/dev/null 2>&1
[ $? -eq 1 ] && { pass=$((pass + 1)); echo "  ok    --strict 對純必經點違規也 exit 1"; } || { fail=$((fail + 1)); echo "  FAIL  --strict 對純必經點違規應 exit 1"; }

echo "── 模板的每個欄位都要等人填 ──"
# 出廠帶著「可用但屬於某個生態」的值,而且沒標 <TODO>,就會讓照著 install 指示填完的人
# 拿到一道恆 0 的守門——0 條違規與真的乾淨在畫面上一模一樣。
_tmpl="$HERE/../assets/arch-layers.conf.template"
_missing=""
for _k in ROOT PACKAGE IMPORT_RE LAYERS PARTITIONED IGNORE; do
  grep -qE "^${_k}=[\"']?<TODO" "$_tmpl" || _missing="$_missing $_k"
done
[ -z "$_missing" ] \
  && { pass=$((pass + 1)); echo "  ok    模板六個欄位都標了 <TODO>"; } \
  || { fail=$((fail + 1)); echo "  FAIL  模板這些欄位沒標 <TODO>:$_missing"; }

# 未填就跑,必須出聲。這條守的是「守門靜默失效」本身。
_sb=$(mktemp -d); mkdir -p "$_sb/hooks"
cp "$HERE/../assets/arch-guard-check.sh" "$_sb/hooks/"
cp "$_tmpl" "$_sb/hooks/arch-layers.conf"
_out=$(cd "$_sb" && sh hooks/arch-guard-check.sh --audit 2>&1)
case "$_out" in
  *"<TODO"*) pass=$((pass + 1)); echo "  ok    conf 留著 <TODO> 時 checker 會出聲" ;;
  *) fail=$((fail + 1)); printf '  FAIL  conf 留著 <TODO> 時 checker 沒出聲\n        實得：%s\n' "$_out" ;;
esac
rm -rf "$_sb"

# exit code 是契約的一部分:併進既有 pre-commit 的人會照檔頭寫的「warn-only, exit 0」
# 不加 `|| true`,那時無條件的非零會讓整個 repo commit 不進去。
_sb2=$(mktemp -d); mkdir -p "$_sb2/hooks"
cp "$HERE/../assets/arch-guard-check.sh" "$_sb2/hooks/"
cp "$_tmpl" "$_sb2/hooks/arch-layers.conf"
(cd "$_sb2" && sh hooks/arch-guard-check.sh >/dev/null 2>&1)
[ $? -eq 0 ] \
  && { pass=$((pass + 1)); echo "  ok    未填 conf 時 warn 模式仍 exit 0"; } \
  || { fail=$((fail + 1)); echo "  FAIL  未填 conf 時 warn 模式回非零 — 不帶 || true 的 pre-commit 會被擋死"; }
(cd "$_sb2" && sh hooks/arch-guard-check.sh --strict >/dev/null 2>&1)
[ $? -ne 0 ] \
  && { pass=$((pass + 1)); echo "  ok    未填 conf 時 --strict exit 非零"; } \
  || { fail=$((fail + 1)); echo "  FAIL  未填 conf 時 --strict 回 0 — CI 對一道死掉的守門放行"; }
# install.sh 教人「看 --audit 報幾條來決定 mode」。exit 0 + stdout 全空會被讀成 0 hits,
# 於是每個 chokepoint 都設成 all——守門一次都沒跑過就被當成通過。
_ao=$(cd "$_sb2" && sh hooks/arch-guard-check.sh --audit 2>/dev/null); _arc=$?
{ [ "$_arc" -ne 0 ] || [ -n "$_ao" ]; } \
  && { pass=$((pass + 1)); echo "  ok    未填 conf 時 --audit 不會靜默回 0"; } \
  || { fail=$((fail + 1)); echo "  FAIL  未填 conf 時 --audit exit 0 且 stdout 全空 — 會被讀成「0 hits」"; }
rm -rf "$_sb2"

# 填完 <TODO> 之後的第二種「等於沒跑」:模板允許不適用的欄位留空,填成 LAYERS=""
# 且沒有半條 chokepoint 是打得出來的,而那時兩個迴圈都不會進去、尾端照印「共 0 條違規」。
_sb3=$(mktemp -d); mkdir -p "$_sb3/hooks"
cp "$HERE/../assets/arch-guard-check.sh" "$_sb3/hooks/"
_emptyconf() {  # $1 = CHOKEPOINTS 的內容
  printf 'ROOT="lib"\nPACKAGE="x"\nIMPORT_RE="i {LAYER}"\nLAYERS=""\nPARTITIONED=""\nIGNORE="__never_matches__"\nCHOKEPOINTS="%s"\n' "$1" > "$_sb3/hooks/arch-layers.conf"
}
_emptyconf ""
_eo=$(cd "$_sb3" && sh hooks/arch-guard-check.sh --audit 2>&1); _erc=$?
{ [ "$_erc" -ne 0 ] && [ -n "$_eo" ]; } \
  && { pass=$((pass + 1)); echo "  ok    LAYERS 與 CHOKEPOINTS 皆空時 --audit 出聲且非零"; } \
  || { fail=$((fail + 1)); printf '  FAIL  沒有規則可跑卻靜默通過\n        rc=%s 實得：%s\n' "$_erc" "$_eo"; }
(cd "$_sb3" && sh hooks/arch-guard-check.sh >/dev/null 2>&1)
[ $? -eq 0 ] \
  && { pass=$((pass + 1)); echo "  ok    沒有規則可跑時 warn 模式仍 exit 0"; } \
  || { fail=$((fail + 1)); echo "  FAIL  沒有規則可跑時 warn 回非零 — 不帶 || true 的 pre-commit 會被擋死"; }
# 註解不是規則。CHOKEPOINTS 只剩註解時仍然是「沒有規則可跑」。
_emptyconf '
# 之後再補
'
(cd "$_sb3" && sh hooks/arch-guard-check.sh --audit >/dev/null 2>&1)
[ $? -ne 0 ] \
  && { pass=$((pass + 1)); echo "  ok    CHOKEPOINTS 只剩註解也算沒有規則"; } \
  || { fail=$((fail + 1)); echo "  FAIL  CHOKEPOINTS 只剩註解時被當成有規則 — 那是一道恆 0 的守門"; }
# 反向:有一條真的規則就不准開火,否則只設 chokepoint 不分層的 repo 永遠交不出條件。
_emptyconf '
all:::DioException:::no dio
'
(cd "$_sb3" && sh hooks/arch-guard-check.sh --audit >/dev/null 2>&1)
[ $? -eq 0 ] \
  && { pass=$((pass + 1)); echo "  ok    只有 chokepoint、沒有 LAYERS 的 conf 照常跑"; } \
  || { fail=$((fail + 1)); echo "  FAIL  只設 chokepoint 的 repo 被誤判成沒有規則"; }
rm -rf "$_sb3"

echo "── Python IMPORT_RE（模板範例）──"
# 結尾 `\.` 會漏掉 `from pkg.layer import x`（layer 後面不是點）——audit 印 0、
# 與乾淨無法分辨。模板範例必須用 boundary class 收尾，這裡拿它實跑一次。
grep -qF '{LAYER}([^A-Za-z0-9_]|$)' "$HERE/../assets/arch-layers.conf.template" \
  && { pass=$((pass + 1)); echo "  ok    模板 Python 範例帶 boundary class"; } \
  || { fail=$((fail + 1)); echo "  FAIL  模板 Python 範例缺 boundary class"; }

mkdir -p py/cli py/core
printf 'from pkg.cli import main\nfrom pkg.clitools import x\n' > py/core/a.py
printf 'from pkg.core import count\n' > py/cli/a.py
git add -A
cat > "$WORK/c.sh" <<'EOF'
ROOT="py"
IGNORE="__never_matches__"
PACKAGE="pkg"
IMPORT_RE="^(from|import) ${PACKAGE}\.{LAYER}([^A-Za-z0-9_]|$)"
LAYERS="cli core"
PARTITIONED=""
CHOKEPOINTS=""
EOF
out=$(run)
ok "from 形式的往上 import 抓得到"      "core → cli"    "$out"
no "層名是前綴時不誤中（cli vs clitools）" "clitools"      "$out"
no "合法的向下 import 不報"             "py/cli/a.py"   "$out"

echo "── TS IMPORT_RE（模板範例）──"
# 錨定 alias/相對前綴——裸 .*/{LAYER} 會誤中第三方 subpath（'@angular/core'），
# 假陽性讓人簽收一道從沒驗過的守門。
mkdir -p ts/cli ts/core
printf "import { x } from '@/cli';\nimport { y } from '@angular/cli';\nimport { z } from '../cli/util';\n" > ts/core/a.ts
git add -A
cat > "$WORK/c.sh" <<'EOF'
ROOT="ts"
IGNORE="__never_matches__"
PACKAGE="unused"
IMPORT_RE="from ['\"](@/|\.\.?/)([^'\"]*/)?{LAYER}(/|['\"])"
LAYERS="cli core"
PARTITIONED=""
CHOKEPOINTS=""
EOF
out=$(run)
ok "alias 形式的往上 import 抓得到"    "@/cli"        "$out"
ok "相對路徑形式也抓得到"             "../cli/util"  "$out"
no "第三方 subpath 撞層名不誤中"      "@angular"     "$out"

echo "── exit code ──"
LAYERS_V="features core"
PART_V="features"
conf ''
ARCH_LAYERS_CONF="$WORK/c.sh" sh "$CHECK" --strict >/dev/null 2>&1
[ $? -eq 1 ] && { pass=$((pass + 1)); echo "  ok    --strict 有違規時 exit 1"; } || { fail=$((fail + 1)); echo "  FAIL  --strict 應 exit 1"; }
ARCH_LAYERS_CONF="$WORK/c.sh" sh "$CHECK" >/dev/null 2>&1
[ $? -eq 0 ] && { pass=$((pass + 1)); echo "  ok    warn 模式恆 exit 0"; } || { fail=$((fail + 1)); echo "  FAIL  warn 模式應 exit 0"; }

# ── 安裝器 ──────────────────────────────────────────────────────────────
# checker 之外，install.sh 自己也有靜默失效面：拒跑 worktree、插進別人的 marker
# 區塊裡、把主 repo 的 hooksPath 指向一個它沒有的目錄。全都不會報錯。
INSTALL="$HERE/../scripts/install.sh"
ok2() { case "$3" in *"$2"*) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;;
  *) fail=$((fail+1)); printf '  FAIL  %s\n        期望含：%s\n        實得：%s\n' "$1" "$2" "$3" ;; esac; }
no2() { case "$3" in *"$2"*) fail=$((fail+1)); printf '  FAIL  %s\n        不該含：%s\n        實得：%s\n' "$1" "$2" "$3" ;;
  *) pass=$((pass+1)); printf '  ok    %s\n' "$1" ;; esac; }
newrepo2() {
  d=$(mktemp -d "$WORK/i.XXXXXX")
  ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t &&
    echo s > s.txt && git add -A && git -c core.hooksPath=/dev/null commit -qm init ) >/dev/null 2>&1
  printf '%s' "$d"
}

echo "── 安裝器 ──"
D=$(newrepo2); cd "$D" || exit 1
git worktree add -q "$D/../w.$$" -b w >/dev/null 2>&1
out=$(cd "$D/../w.$$" && sh "$INSTALL" 2>&1)
no2 "worktree 裡不該拒跑" "run from inside a git repo" "$out"
cd "$D" || exit 1
ok2 "worktree 安裝不得動到主 repo 的 hooksPath" "unset" "$(git config --get core.hooksPath || echo unset)"

D=$(newrepo2); cd "$D" || exit 1
mkdir -p hooks
printf '#!/bin/sh\n  # >>> other >>>\n  echo OTHER\n  # <<< other <<<\necho REAL\n' > hooks/pre-commit
chmod +x hooks/pre-commit
sh "$INSTALL" >/dev/null 2>&1
left=$(sed '/# >>> other >>>/,/# <<< other <<</d' hooks/pre-commit)
ok2 "縮排的 marker 也認得（不被鄰居吞掉）" "arch-guard-check.sh" "$left"

D=$(newrepo2); cd "$D" || exit 1
mkdir -p hooks
# inner 區塊裡刻意不放可執行行：放了的話 awk 在遇到任何 <<< 之前就 print 並 exit，
# 收合邏輯走不到，這條斷言會變成在測空氣。
printf '#!/bin/sh\n# >>> outer >>>\n# >>> inner >>>\n# <<< inner <<<\necho OUTER\n# <<< outer <<<\necho REAL\n' > hooks/pre-commit
chmod +x hooks/pre-commit
sh "$INSTALL" >/dev/null 2>&1
left=$(sed '/# >>> outer >>>/,/# <<< outer <<</d' hooks/pre-commit)
ok2 "巢狀 marker 收在最外層才算結束" "arch-guard-check.sh" "$left"

D=$(newrepo2); cd "$D" || exit 1
mkdir -p hooks
# 全是註解 + 檔尾無換行：awk 找不到可執行行而走 fallback，wc -l 會少算一行。
printf '#!/bin/sh\n# >>> other >>>\n# only comments\n# <<< other <<<' > hooks/pre-commit
chmod +x hooks/pre-commit
sh "$INSTALL" >/dev/null 2>&1
left=$(sed '/# >>> other >>>/,/# <<< other <<</d' hooks/pre-commit)
ok2 "檔尾無換行也不會插進鄰居體內" "arch-guard-check.sh" "$left"

D=$(newrepo2); cd "$D" || exit 1
mkdir -p .husky; git config core.hooksPath .husky
sh "$INSTALL" >/dev/null 2>&1
ok2 "既有 hooksPath 不被覆寫" ".husky" "$(git config --get core.hooksPath)"

# warn-only 的契約是「pre-commit 這條路擋不到任何 commit」。驗 install.sh 的原始碼字面
# (當初的寫法)兩個方向都可以被打破:別處留一行帶 `|| true` 的註解就綠、真正的呼叫少
# 一個空格就紅。所以裝完直接跑真的 commit。
# 兩條分開驗,因為它們證的不是同一件事:有違規時 checker 自己就 exit 0(warn 模式),
# 所以那條**驗不到 `|| true`**——要驗它得讓 checker 回非零。
D=$(newrepo2); cd "$D" || exit 1
sh "$INSTALL" >/dev/null 2>&1
mkdir -p lib/ui lib/data
printf "import 'package:x/data/a.dart';\n" > lib/ui/a.dart
printf "import 'package:x/ui/a.dart';\n" > lib/data/a.dart
# IMPORT_RE 要寫死套件名——checker 只代換 {LAYER},PACKAGE 那個欄位它不代入
cat > hooks/arch-layers.conf <<'CONF'
ROOT=lib
PACKAGE=x
IMPORT_RE="^import 'package:x/{LAYER}/"
LAYERS="ui data"
PARTITIONED=""
IGNORE="__never_matches__"
CONF
git add -A >/dev/null 2>&1
out=$(cd "$D" && sh hooks/arch-guard-check.sh 2>&1)
ok2 "測試前提:這份 conf 真的有違規可報" "data/a.dart" "$out"
out=$(git commit -m t 2>&1); rc=$?
[ $rc -eq 0 ] \
  && { pass=$((pass + 1)); echo "  ok    裝完後有違規仍 commit 得進去(warn-only)"; } \
  || { fail=$((fail + 1)); printf '  FAIL  裝完後有違規就擋死 commit\n        實得：%s\n' "$out"; }

# checker 回非零(壞 conf、被刪、未來加了新的 exit 1 路徑)時,pre-commit 仍不得擋。
# 這是 `|| true` 唯一的觀測面——拿掉它這條就紅。
printf '#!/bin/sh\nexit 1\n' > hooks/arch-guard-check.sh
echo x > x.txt; git add -A >/dev/null 2>&1
out=$(git commit -m t2 2>&1); rc=$?
[ $rc -eq 0 ] \
  && { pass=$((pass + 1)); echo "  ok    checker 回非零也擋不到 commit(|| true)"; } \
  || { fail=$((fail + 1)); printf '  FAIL  checker 回非零就擋死 commit — install.sh 少了 || true\n        實得：%s\n' "$out"; }
cd "$WORK" || exit 1

echo
echo "通過 ${pass}，失敗 ${fail}"
[ "$fail" -eq 0 ]

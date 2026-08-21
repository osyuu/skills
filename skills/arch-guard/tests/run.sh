#!/bin/sh
# arch-guard-check 的回歸測試。無相依，`sh tests/run.sh` 直接跑。
#
# 為什麼這支存在：checker 的失敗模式幾乎都是**靜默的**——壞掉的 pattern、少一個欄位、
# 打錯的 mode，全都回「0 條違規」，而那跟「這個 repo 很乾淨」長得一模一樣。讀 code 看不出
# 差別，跑一次就現形。新增規則型別或改 config 解析時，這裡要跟著加案例。

set -u
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

conf 'all:::(unclosed:::壞 pattern 要出聲'
out=$(run); ok "all 模式的壞 pattern 不被吞掉" "unclosed" "$out"

conf ''
out=$(run); ok "CHOKEPOINTS 空時乾淨退出" "共 0 條違規" "$out"

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

echo "── exit code ──"
LAYERS_V="features core"
PART_V="features"
conf ''
ARCH_LAYERS_CONF="$WORK/c.sh" sh "$CHECK" --strict >/dev/null 2>&1
[ $? -eq 1 ] && { pass=$((pass + 1)); echo "  ok    --strict 有違規時 exit 1"; } || { fail=$((fail + 1)); echo "  FAIL  --strict 應 exit 1"; }
ARCH_LAYERS_CONF="$WORK/c.sh" sh "$CHECK" >/dev/null 2>&1
[ $? -eq 0 ] && { pass=$((pass + 1)); echo "  ok    warn 模式恆 exit 0"; } || { fail=$((fail + 1)); echo "  FAIL  warn 模式應 exit 0"; }

echo
echo "通過 ${pass}，失敗 ${fail}"
[ "$fail" -eq 0 ]

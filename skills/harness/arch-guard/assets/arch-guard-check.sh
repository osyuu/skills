#!/bin/sh
# arch-guard-check — flag imports that break the declared layering.
#
# Reads a repo-local config (default hooks/arch-layers.conf) that declares an
# ordered set of layers (top → bottom). Rule: a file in a layer may import only
# layers BELOW it. Upward imports, and (for PARTITIONED layers) imports between
# sibling sub-modules, are violations.
#
# CHOKEPOINTS rules (optional) flag lines that bypass a required entry point.
# Those are direction-legal, so the layering rules never see them.
#
# Modes:
#   (default)   warn-only — print violations, exit 0. For pre-commit.
#   --strict    exit 1 if any violation (for CI / pre-push).
#   --audit     print violations + a per-rule count summary, exit 0.
#               Exits 1 only when the config declares nothing to check —
#               an unfilled <TODO>, or no LAYERS and no CHOKEPOINTS. See below.
#
# Config path override: ARCH_LAYERS_CONF=path sh arch-guard-check.sh
# Deterministic (git grep); safe to run from a repo root.

mode="warn"
case "$1" in
  --strict) mode="strict" ;;
  --audit)  mode="audit" ;;
esac

conf="${ARCH_LAYERS_CONF:-hooks/arch-layers.conf}"
if [ ! -f "$conf" ]; then
  echo "arch-guard: no config at $conf — skipped (see arch-guard skill)"
  exit 0
fi
# shellcheck disable=SC1090
. "$conf"

# 未填的 <TODO> 會讓每一條 grep 都配不到,而配不到印出來就是「0 條違規」——
# 與真的乾淨一模一樣。**這裡必須出聲**:一道恆 0 的守門比不裝更糟,
# 它讓人以為那條規則有人在看。
# **只有 warn 能 exit 0**:它是 pre-commit 那條路,而併進既有 pre-commit(husky 之類)的人
# 會照檔頭寫的「warn-only, exit 0」不加 `|| true`,那時未填的 conf 會讓整個 repo
# commit 不進去。strict 與 audit 都回非零——audit 不在 pre-commit 上,擋不到任何人,
# 而它 exit 0 + stdout 全空的話,照安裝指示讀「0 hits」的人會把每個 chokepoint 設成
# `all`,守門一次都沒跑過就被當成通過了。
case "$ROOT$PACKAGE$IMPORT_RE$LAYERS$PARTITIONED$IGNORE" in
  *"<TODO"*)
    echo "arch-guard: $conf 還有未填的 <TODO> — 這次檢查等於沒跑" >&2
    [ "$mode" = "warn" ] || exit 1
    exit 0 ;;
esac

# 填完 <TODO> 之後還有第二種「等於沒跑」:LAYERS 空著、CHOKEPOINTS 也沒有半條有效規則。
# 那時下面兩個迴圈一次都不會進去,尾端照樣印「共 0 條違規」——與這個 repo 真的乾淨
# 一模一樣。模板允許不適用的欄位留空,所以這個狀態是打得出來的,而它正是這支守門
# 存在的理由本身:恆 0 的檢查比不裝更糟。處置與 <TODO> 同一條(只有 warn 能 exit 0)。
chk_rules=$(printf '%s\n' "${CHOKEPOINTS:-}" |
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -cv '^\(#.*\)\?$')
if [ -z "$(printf '%s' "${LAYERS:-}" | tr -d '[:space:]')" ] && [ "$chk_rules" -eq 0 ]; then
  echo "arch-guard: $conf 的 LAYERS 與 CHOKEPOINTS 都沒有規則 — 這次檢查等於沒跑" >&2
  [ "$mode" = "warn" ] || exit 1
  exit 0
fi

: "${ROOT:=lib}" "${IGNORE:=__never_matches__}"

count=0
YEL='\033[33m'; RST='\033[0m'

report() {  # $1=label  $2=hits(multiline)
  [ -z "$2" ] && return 0
  n=$(printf '%s\n' "$2" | grep -c .)
  count=$((count + n))
  printf "${YEL}⚠  %s${RST}\n" "$1"
  printf '%s\n' "$2" | sed 's/^/    /'
}

# import-line regex for a given layer name (substitute {LAYER})
re_for() { printf '%s' "$IMPORT_RE" | sed "s/{LAYER}/$1/g"; }

# ── upward imports: a file in <layer> importing any HIGHER layer ──────────
for layer in $LAYERS; do
  higher=""
  for h in $LAYERS; do
    [ "$h" = "$layer" ] && break
    higher="$higher $h"
  done
  for h in $higher; do
    hits=$(git grep -nE "$(re_for "$h")" -- "$ROOT/$layer" 2>/dev/null | grep -v "$IGNORE")
    report "分層違規：$layer → $h 往上依賴（禁止）" "$hits"
  done
done

# ── partitioned siblings: <layer>/A importing <layer>/B (A≠B) ─────────────
for layer in $PARTITIONED; do
  hits=$(
    git grep -nE "$(re_for "$layer")" -- "$ROOT/$layer" 2>/dev/null | grep -v "$IGNORE" |
    while IFS= read -r line; do
      file=${line%%:*}
      src=$(printf '%s' "$file" | sed -E "s#$ROOT/$layer/([^/]+)/.*#\1#")
      tgt=$(printf '%s' "$line" | sed -E "s#.*/$layer/([^/]+)/.*#\1#")
      [ "$src" != "$tgt" ] && printf '%s → %s  (%s)\n' "$src" "$tgt" "$file"
    done
  )
  report "分層違規：$layer → $layer sibling 互 import（禁止，共享請下沉低層）" "$hits"
done

# ── 必經點：方向合法、卻繞過了指定入口 ────────────────────────────────────
# 一行一條：<mode>:::<pattern>:::<label>[:::<allow-path-regex>]
#   all — 整棵工作樹都不准出現（用在現在乾淨的規則）
#   new — 只看這次 staged 的新增行（用在有存量債的規則）
# 分隔符是 ::: 而非 |，因為 | 是 ERE 的 alternation：用 | 當分隔會把 `(A|B)`
# 這種 pattern 切成兩半而且不報錯。**可選的 allow 放最後**，這樣省略它就是少一個
# 欄位，不會出現連續分隔符（那種寫法沒人打得對）。
old_ifs=$IFS
IFS='
'
for rule in $CHOKEPOINTS; do
  rule=$(printf '%s' "$rule" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$rule" in ''|'#'*) continue ;; esac

  # 欄位數不足會静默降級（allow 被推導成 pat，把所有命中滤光），所以先验再拆。
  nf=$(printf '%s' "$rule" | awk -F':::' '{print NF}')
  if [ "$nf" -ne 3 ] && [ "$nf" -ne 4 ]; then
    printf "${YEL}⚠  arch-guard config：栏位数不是 3 或 4（mode:::pattern:::label[:::allow]），已跳过${RST}\n    %s\n" "$rule"
    continue
  fi
  cmode=$(printf '%s' "$rule" | awk -F':::' '{print $1}')
  pat=$(printf   '%s' "$rule" | awk -F':::' '{print $2}')
  label=$(printf '%s' "$rule" | awk -F':::' '{print $3}')
  allow=$(printf '%s' "$rule" | awk -F':::' '{print $4}')
  [ -z "$pat" ] && continue
  case "$cmode" in
    all|new) ;;
    *) printf "${YEL}⚠  arch-guard config：mode 只能是 all 或 new，已跳过：%s${RST}\n" "$rule"
       continue ;;
  esac

  if [ "$cmode" = "new" ]; then
    # **先剝掉 diff 的 `+` 再比對**，否則 `^` 锚点永远配不到，而规则会静默失效。
    # pattern 走 ENVIRON 传：`awk -v` 会对值做跳脱处理，把 `\.` 塌成 `.`，
    # 于是同一条 pattern 在 all 与 new 两个模式意思不一样。
    hits=$(git diff --cached -U0 -- "$ROOT" 2>/dev/null | PAT="$pat" awk '
      /^\+\+\+ b\// { f = substr($0, 7); next }
      /^\+/ && $0 !~ /^\+\+\+/ {
        line = substr($0, 2)
        if (line ~ ENVIRON["PAT"]) print f ": " line
      }')
  else
    # 不吞 stderr：坏 pattern 要出声。静默回 0 笔会诱导作者把规则设成 all，
    # 得到一道永远不开火的守门。
    hits=$(git grep -nE "$pat" -- "$ROOT")
  fi
  hits=$(printf '%s\n' "$hits" | grep -v "$IGNORE" | grep -v '^$')
  [ -n "$allow" ] && hits=$(printf '%s\n' "$hits" | grep -vE "$allow" | grep -v '^$')
  report "必經點：$label" "$hits"
done
IFS=$old_ifs

# ── tail ─────────────────────────────────────────────────────────────────
if [ "$mode" = "audit" ]; then
  printf "${YEL}arch-guard audit：共 %s 條違規${RST}\n" "$count"
  exit 0
fi
if [ "$count" -gt 0 ]; then
  printf "${YEL}   （arch-guard：依賴只准往下、共享請下沉低層；必經點不可繞過）${RST}\n"
  [ "$mode" = "strict" ] && exit 1
fi
exit 0

#!/bin/sh
# sdd-harness-init installer — idempotent scaffolding for the decision-log drift-guard.
#
# Handles ONLY the mechanical, safe, deterministic parts:
#   1. docs/design/DECISIONS.md  — create from template if absent (never clobber)
#   2. hooks/pre-commit          — install if absent; detect if ours; FLAG if a
#                                  foreign hook exists (leave merge to the model)
#   3. core.hooksPath            — wire to `hooks` only when safe (unset + no shadow)
#   4. force-add tracked artifacts if they'd be git-ignored/excluded
#   5. report CLAUDE.md / CLAUDE.local.md marker status (does NOT edit them)
#
# Judgment calls (which CLAUDE file to edit, writeback targets, hook conflicts,
# non-default hooksPath) are printed as follow-ups for the model/user to resolve.
#
# Run from the target repo root. Locates its own assets via $0.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ASSETS="$SCRIPT_DIR/../assets"
LOG_PATH="docs/design/DECISIONS.md"
HOOK_MARKER=">>> sdd-harness decision-log >>>"

say()  { printf '%s\n' "$*"; }
todo() { printf '  ⚠ %s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }

FOLLOWUPS=""
add_followup() { FOLLOWUPS="${FOLLOWUPS}\n  ⚠ $1"; }

# --- 0. git repo check ------------------------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  say "❌ 不在 git repo 內。DECISIONS.md 可以照建，但 pre-commit / hooksPath 無法佈線。"
  say "   先 \`git init\` 再重跑，或只手動放 DECISIONS.md。"
  exit 2
fi
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"
say "repo: $REPO_ROOT"
say ""

# --- 1. DECISIONS.md --------------------------------------------------------
say "[1/5] $LOG_PATH"
if [ -f "$LOG_PATH" ]; then
  ok "已存在，不覆蓋。"
else
  mkdir -p "$(dirname "$LOG_PATH")"
  cp "$ASSETS/DECISIONS.template.md" "$LOG_PATH"
  ok "由模板建立（記得把 <PROJECT> 與『回寫目標』的 <TODO> 換成本專案值）。"
  add_followup "填 $LOG_PATH 的 <PROJECT> 與回寫目標 <TODO>。"
fi

# force-add if the path would be ignored/excluded (so teammates & CI see it)
if git check-ignore -q "$LOG_PATH" 2>/dev/null; then
  git add -f "$LOG_PATH" >/dev/null 2>&1 || true
  ok "路徑被 gitignore/exclude → 已 force-add（追蹤，機制才對隊友/CI 生效）。"
fi
say ""

# --- 2 & 3. pre-commit + hooksPath -----------------------------------------
say "[2/5] hooks/pre-commit + [3/5] core.hooksPath"
EXISTING_HP=$(git config --get core.hooksPath 2>/dev/null || true)

if [ -n "$EXISTING_HP" ]; then
  HOOK_DIR="$EXISTING_HP"
  say "  core.hooksPath 已設為 '$EXISTING_HP' → 用它當 hook 目錄，不改設定。"
  WIRE_DEFAULT=no
else
  HOOK_DIR="hooks"
  WIRE_DEFAULT=yes
fi
HOOK_FILE="$HOOK_DIR/pre-commit"

if [ -f "$HOOK_FILE" ]; then
  if grep -qF "$HOOK_MARKER" "$HOOK_FILE" 2>/dev/null; then
    ok "$HOOK_FILE 已含本機制的區塊，跳過。"
  else
    todo "$HOOK_FILE 已存在且非本機制產出 → 不覆蓋。"
    add_followup "把 $ASSETS/pre-commit 的 marker 區塊（>>> … <<<）併進既有 ${HOOK_FILE}，別覆蓋原邏輯。⚠️ **插在檔案最前面**（shebang 之後）：本區塊包在子 shell 裡、自己不會 exit 整支 hook，放最前面不影響原有邏輯；而既有 hook 若有頂層或中途的 exit，接在它後面就永遠不會執行（裝了卻不觸發＝假綠燈）。"
  fi
else
  mkdir -p "$HOOK_DIR"
  cp "$ASSETS/pre-commit" "$HOOK_FILE"
  chmod +x "$HOOK_FILE"
  ok "寫入 ${HOOK_FILE}（可執行）。"
  if git check-ignore -q "$HOOK_FILE" 2>/dev/null; then
    git add -f "$HOOK_FILE" >/dev/null 2>&1 || true
    ok "hook 路徑被 ignore → 已 force-add。"
  fi
fi

# spec-claim checker：與 decision-log 同一支 hook 的第二個區塊。
for f in spec-claim-check.sh spec-claim.conf; do
  case "$f" in *.sh) mode=755 ;; *) mode=644 ;; esac
  if [ -f "$HOOK_DIR/$f" ]; then
    ok "$HOOK_DIR/$f 已存在，跳過（不覆蓋既有門檻）。"
  else
    cp "$ASSETS/$f" "$HOOK_DIR/$f"
    chmod "$mode" "$HOOK_DIR/$f"
    ok "寫入 $HOOK_DIR/${f}。"      # 大括號不可省：`$f。` 會被當成變數名 f。，set -u 直接中止
    git check-ignore -q "$HOOK_DIR/$f" 2>/dev/null && git add -f "$HOOK_DIR/$f" >/dev/null 2>&1 || true
  fi
done
add_followup "填 $HOOK_DIR/spec-claim.conf 的 SPEC_SRC_DIRS 與 SPEC_TEST_DIRS——預設值多數 repo 對不上，填錯或沒填時符號檢查會靜默什麼都不做（跟「很乾淨」長得一樣）。"

if [ "$WIRE_DEFAULT" = yes ]; then
  # setting core.hooksPath=hooks disables .git/hooks/* — warn if real ones live there
  SHADOWED=$(find .git/hooks -maxdepth 1 -type f ! -name '*.sample' 2>/dev/null | head -n1 || true)
  if [ -n "$SHADOWED" ]; then
    todo "偵測到 .git/hooks/ 有實體 hook（$SHADOWED …）；設 core.hooksPath=hooks 會停用它們。"
    add_followup "決定是否把 .git/hooks/ 的既有 hook 併進 hooks/，再手動 \`git config core.hooksPath hooks\`。此步已跳過以免誤停。"
  else
    git config core.hooksPath hooks
    ok "git config core.hooksPath hooks（已佈線；fresh clone/worktree 需各自再跑一次）。"
  fi
fi
say ""

# --- 4. CLAUDE marker status (report only) ---------------------------------
# Detect an existing section by TWO signals: the invisible marker, AND the
# heading text. A rewrite tool (e.g. claude-md-hygiene) may keep the section
# but strip the HTML-comment markers — heading-match catches that so the model
# UPDATES in place instead of injecting a duplicate.
HEADING="## 決策記錄 + drift 防護"
say "[4/5] CLAUDE 指標節（僅回報，不自動編輯）"
FOUND_CLAUDE=no
# 指標節只該有一份（共享 vs 本機擇一）。先掃一遍：任一檔已經有了，就別再對另一檔
# 出「插進去」的 followup——照做會變成兩個檔各一份，正是本 skill 要防的漂移源。
HAS_SECTION=no
for f in CLAUDE.md CLAUDE.local.md; do
  [ -f "$f" ] || continue
  grep -q "sdd-harness:decision-log:start" "$f" 2>/dev/null && HAS_SECTION=yes
done
for f in CLAUDE.md CLAUDE.local.md; do
  [ -f "$f" ] || continue
  FOUND_CLAUDE=yes
  if grep -q "sdd-harness:decision-log:start" "$f" 2>/dev/null; then
    ok "$f 已含決策記錄指標節（marker 完整）。"
  elif grep -qF "$HEADING" "$f" 2>/dev/null; then
    todo "$f 有本節標題但無 marker（可能被重寫工具洗掉）→ 原地更新、補回 marker，別重複注入。"
    add_followup "$f 的決策記錄節 marker 遺失：就地補回 <!-- sdd-harness:decision-log:start/end --> 包住既有內容，不要新增第二節。"
  elif [ "$HAS_SECTION" = no ]; then
    todo "$f 存在但無指標節。"
    add_followup "把 $ASSETS/claude-section.md 的 marker 區塊插進 $f 適當位置，並填回寫目標 <TODO>。"
  fi
done
if [ "$FOUND_CLAUDE" = no ]; then
  todo "沒有 CLAUDE.md / CLAUDE.local.md → 預設新建 CLAUDE.md（此 harness 屬團隊共享機制）。"
  add_followup "新建 CLAUDE.md（預設；harness 是共享機制），把 $ASSETS/claude-section.md 的內容加進去並填回寫目標 <TODO>。"
fi
say ""

# --- 5. summary -------------------------------------------------------------
say "[5/5] 完成。後續（模型/使用者處理判斷項）："
if [ -n "$FOLLOWUPS" ]; then
  printf "$FOLLOWUPS\n"
else
  say "  （無，全自動佈線完成）"
fi

---
name: sdd-harness-init
description: >-
  在一個 repo 裡佈好「決策記錄 + drift 防護」的 SDD harness——建 docs/design/DECISIONS.md、裝
  hooks/pre-commit（commit 時列出未回寫的翻案、僅警告不擋）、佈線 git core.hooksPath、注入 CLAUDE.md
  指標節。全程 idempotent（已存在就不覆蓋）。當使用者說「幫這個專案裝 decision log / 決策記錄機制 / drift
  防護 / SDD harness / pre-commit 決策 hook / 把翻案追蹤機制搬過來 / bootstrap decision log」，或想把這套
  DECISIONS.md 機制套到新專案時，主動使用。這是「安裝器 / 佈線」——需求→設計書的『生成』請用 design-doc
  skill，兩者互補（本 skill 打地基，design-doc 落 spec）。純寫應用 code 不要用。
---

# SDD Harness Init — 決策記錄 drift-guard 安裝器

把「翻案當下就記錄、未回寫就警告」這套機制 30 秒佈進任何 repo。這**不是**生成設計書（那是 `design-doc` skill 的事），而是打地基：讓翻案有地方落、讓漂移在 commit 時被看見。

## 這套機制在解什麼問題

SDD 最脆的一環是**察覺→記錄→回寫**：spec 與 code 漂移，通常是因為「決策翻案時沒當場記，交付前憑記憶重建」。這套 harness 用一個 append-only 的 `DECISIONS.md` 當 staging area（翻案當下寫進檔案，穿過 compact），配一個 pre-commit hook 在每次 commit 把未打勾項攤到眼前。**「察覺翻案」無法機械化**——這套只保證「已記錄的一定被提醒回寫」，剩下靠自律 + 任務 DoD。

## 機制與專案的分界（安裝時心裡要清楚）

- **可攜核心（本 skill 佈的）**：`DECISIONS.md` 格式 + `pre-commit` + `core.hooksPath` 佈線 + CLAUDE 指標節。跟任何契約無關。
- **每專案限定（留 `<TODO>` 給使用者填）**：回寫目標是什麼。可能是 API 契約、schema、某份 design doc，也可能沒有集中契約（就「各決策就近回寫對應 design doc」）。`DECISIONS.md` 的 `→ 回寫目標` 是**自由文字欄**，機制只認「有沒有打勾」，不認目標是誰——所以泛化幾乎零成本，只是別把某專案的檔名寫死進模板。

## 流程

**先跑安裝腳本**（處理所有機械、安全、確定性的佈線；idempotent）：

```
sh <skill-dir>/scripts/install.sh
```

在**目標 repo 根目錄**跑。它會：建 `docs/design/DECISIONS.md`（缺才建、模板來自 `assets/`）、裝 `hooks/pre-commit`、在安全前提下 `git config core.hooksPath hooks`、被 gitignore 就 force-add、回報 CLAUDE 檔的指標節狀態。**已存在的一律不覆蓋。** 跑完它會印一份「後續判斷項」清單。

**再處理腳本印出的判斷項**（這些刻意不自動做，需要你/模型拍板）：

1. **填 `<TODO>`**：`DECISIONS.md` 的 `<PROJECT>` 換成 repo 名；「本專案回寫目標」照模板骨架填（API 形狀 → 集中契約或就近 design doc／資料形狀 → schema＋migration／跨層約束 → CLAUDE 檔），刪掉不適用的、把佔位路徑換成 repo 實際檔。骨架已在模板裡，通常微調即可、不必從零發明。
2. **注入 CLAUDE 指標節**：讀 `assets/claude-section.md`，把 marker 區塊（`<!-- sdd-harness:decision-log:start -->` … `end`）插進適當位置，並填同樣的回寫目標 `<TODO>`。
   - **放哪個檔**：團隊共享規範 → `CLAUDE.md`；個人本機約束 → `CLAUDE.local.md`。**repo 完全沒有 CLAUDE 檔時，預設新建 `CLAUDE.md`**——此 harness（版控的 DECISIONS.md＋hook）本質是團隊共享機制。
   - **別重複注入**：已有 marker → 跳過。若腳本回報「有本節標題但 marker 遺失」（多半是 `claude-md-hygiene` 之類重寫工具洗掉了隱形 marker），**就地把既有內容用 marker 重新包起來**，不要新增第二節。
3. **hook 衝突**：若腳本說目標路徑已有非本機制的 `pre-commit`，**別覆蓋**——把 `assets/pre-commit` 的 marker 區塊附加進既有 hook。若 repo 已用非預設 `core.hooksPath`（husky/.githooks 等），腳本會用那個目錄、不改設定。
4. **`.git/hooks/` 遮蔽**：若腳本因 `.git/hooks/` 有實體 hook 而跳過佈線，決定是否把它們併進 `hooks/` 再手動 `git config core.hooksPath hooks`。

## 收尾提醒

- **`core.hooksPath` 不進版控**：fresh clone / 新 worktree 都要各自再跑一次 `git config core.hooksPath hooks` 才生效。這句已寫進 CLAUDE 指標節與 hook 註解，別漏講。
- **DECISIONS.md 要被追蹤**：若 repo 把 `docs/design/` 排除（常見，design 當個人筆記），腳本會 force-add DECISIONS.md 與 hook——因為機制要對隊友/CI 生效就得進版控。這跟「其他 design doc 保持 git-excluded」不衝突。
- **hook 是 warn-only（軟約束）**：要硬 gate（擋 merge）得靠 CI 去讀 DECISIONS.md + spec 進版控；pre-commit 本身刻意不擋（改末尾 `exit 0`→`exit 1` 可改成擋，但通常不建議）。
- 跟 `design-doc` skill 的關係：本 skill 佈好 DECISIONS.md，design-doc 產出的設計書就有地方掛、翻案有地方記。裝完 harness 後要寫 spec，轉 design-doc。
- 跟 `claude-md-hygiene` skill **不衝突、互補**：本 skill 注入 CLAUDE.md 的那節剛好是 hygiene 要保留的三類（不變式機制＋指向 DECISIONS.md 的指標＋「hooksPath 不進版控」這個踩坑），真正易變的決策本身在 DECISIONS.md、不在 CLAUDE.md，所以 hygiene 會留下這節。唯一要注意：hygiene 若整份重寫 CLAUDE.md 可能洗掉隱形 marker——上面第 2 步的「標題 fallback + 就地重包」已處理，不會重複注入。

## 品質自檢

- 腳本印的「後續判斷項」都處理了嗎（`<TODO>` 填了、CLAUDE 指標節注入了）？
- 回寫目標有沒有寫死某專案的檔名進**模板/skill**（該只出現在目標 repo 的實體檔）？
- CLAUDE 指標節放對檔（共享 vs 本機）了嗎？
- 有沒有覆蓋到既有的 pre-commit / DECISIONS.md？（不該——全 idempotent）

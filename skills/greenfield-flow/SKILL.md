---
name: greenfield-flow
description: >-
  0→1 專案的開發流程順序——什麼時候收斂需求、什麼時候打地基、**什麼時候還不要裝守門**、
  什麼時候才輪到 review 與出貨。當使用者說「新專案怎麼開始 / 開新 repo / 從零開始 /
  greenfield / 這個專案要怎麼跑流程 / 我的開發流程怎麼搬進來 / 第一步該做什麼 /
  專案初始化 / bootstrap 一個新專案 / 要照什麼順序做 / new project workflow /
  where do I start」，或你正要在一個幾乎空的 repo 裡安排工作順序時，主動使用。
  這是**排程表**（誰在什麼時機進場），不是安裝器也不是內容生成器——各階段的實作交給
  它指向的 skill。已經有大量 code、只是要補守門的既有專案改用 harness-audit；
  純粹「需求→設計書」用 design-doc；純寫應用 code 不要用。
---

# greenfield-flow — 0→1 的進場順序

## 這在解什麼問題

新專案的失敗不是「忘了裝某個東西」，是**在錯的時機裝**。

greenfield 的直覺是開專案就把所有 harness 佈好，但那時候：門檻定不出來（沒有 commit 可量開火率）、層還沒長出來（分層規則是 no-op）、spec 目錄還是空的（`SPEC_SRC_DIRS` 填錯會靜默什麼都不報）。**裝一道不會開火的守門比不裝更糟——它讓人以為那條規則有人在看。**

所以這份的內容是**順序與進場條件**，不是清單。每個階段做什麼交給該階段的 skill，這裡只回答「現在輪到誰」與「現在還不要做什麼」。

## 階段表

★ 標記的不在本 marketplace（見最後一節）。

### Phase 0｜需求還糊，還沒有 repo

| 做什麼 | 交給誰 |
|---|---|
| 需求逼到收斂，產出設計契約 | `design-doc` |
| 它的釐清階段改用分輪提問（一輪問完所有可問的，每題附建議答案） | ★ `grilling` |

沒有這份契約，後面每一道守門都沒有東西可守。**這步不能省，但可以右尺寸**——低風險需求寫兩章就停。

### Phase 1｜有 repo，還沒有 code

```
git init + 第一個 commit
sdd-harness-init     → DECISIONS.md、hooks/pre-commit、core.hooksPath、CLAUDE 指標節
claude-md-hygiene    → greenfield 分支，寫第一份 CLAUDE.md
```

**現在不要裝**分層檢查與註解量檢查（理由見「Phase 4 的進場條件」）。`sdd-harness-init` 的 `SPEC_SRC_DIRS` 這時填不出來，留 `<TODO>`，Phase 4 回來補——**填錯比留空更危險**，它會靜默什麼都不報。

### Phase 2｜設計模組，還沒寫實作

| 做什麼 | 交給誰 |
|---|---|
| 介面切在哪、模組要多深、seam 放哪 | ★ `codebase-design` |

產出**回寫進設計書的「介面契約」章節**。留在對話裡的設計等於沒有設計——下個 session 看不到。

### Phase 3｜實作

| 情境 | 交給誰 |
|---|---|
| 寫功能 | ★ `tdd`（seam 先確認再寫測試，一次一片 vertical slice） |
| 卡住 | ★ `diagnosing-bugs`（先建會紅的 loop，再開始猜） |
| 想法要試 | ★ `prototype`（throwaway，驗完只留決策） |
| merge 衝突 | ★ `resolving-merge-conflicts` |
| **決策翻案** | 當下寫進 `DECISIONS.md`，不要留到交付前憑記憶重建 |

### Phase 4｜有 code 了，才輪到守門

**進場條件（兩個都要成立）**：

- **有 15–30 個 commit** — 少於這個量，門檻只能用猜的。對半數改動開火＝噪音、會被學會忽略；完全不開火＝等於沒裝。
- **要守的東西真的存在** — 層長出來了、而且不是 build system 已經強制的形狀。SwiftPM 的 target graph、Rust 的 crate 邊界都讓反向依賴直接編譯失敗，**那比 grep 強且繞不過**，再加一層文字比對是冗餘。

條件成立後跑 `harness-audit`：它負責盤點該裝哪些、判斷適用性、**注入故障驗證每一道真的會開火**，並回填 Phase 1 留下的 `<TODO>`。這裡不重複它的內容。

### Phase 5｜交付前

順序不能顛倒：**驗證全綠 → commit 鎖 baseline → 才 spawn review**。審半成品等於審一個不存在的東西。

視角怎麼分、派工令要寫什麼、什麼時候才能 stop → `teammate`。語言層的 checklist 走該語言的 review skill。

回環驗收：拿設計書的驗收標準逐條跑，**派沒參與實作的 agent**。翻案的同一批改動回寫 spec、版本 +1。

### Phase 6｜出貨

`release-assets`（release notes、商店素材、版本號）。

### 跨階段

context 快滿 → `handoff`。寫或改 skill → `skill-authoring`（＋★ `writing-for-agents` 的判準）。

## 裸奔期要講出來

Phase 1 到 Phase 4 之間，**沒有任何機械守門在運作**。這段消不掉——守門需要現況才定得出門檻。這期間靠的是設計書的驗收標準與 `DECISIONS.md` 的當下記錄，兩個都是自律。

**在 CLAUDE.md 明寫「目前沒有 X 在守」**，而不是留白。寫出來的缺口才有人記得；沒寫的會被當成不存在，然後在它上面繼續蓋。

## 外部相依（★ 的那些）

★ 的 skill 來自 `mattpocock-skills`，**不在本 marketplace、不會跟著 osyuu 一起傳到新機器**。

叫用前先確認它在。不在的話別卡住——它們是方法論參考、不是安裝器，缺了就自己執行對應的動作：先建一個會紅的重現迴圈再猜（diagnosing-bugs）、seam 先確認再寫測試（tdd）、把模組的介面深度想清楚再切（codebase-design）。**產出一樣，只是少了那份寫好的框架。**

## 品質自檢

- 有沒有在 Phase 1 就裝了門檻類的守門？（幾乎一定是錯的）
- 設計書的介面契約，有沒有真的回寫、還是留在對話裡？
- Phase 4 的兩個進場條件都成立了嗎，還是「反正裝了不虧」？
- build system 已經強制的東西，有沒有又加一層 grep？
- 裸奔期的缺口寫進 CLAUDE.md 了嗎？
- review 是在 baseline 鎖住之後才派的嗎？

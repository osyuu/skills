---
name: arch-guard
description: >-
  把「依賴只准往下」的分層架構用 pre-commit 檢查鎖進任一 repo：宣告層順序後，git grep
  抓出往上依賴、feature→feature、跨層違規，warn 不擋（可切 --strict 給 CI）。當使用者說
  「加分層檢查 / 架構分層守門 / 強制 clean architecture 層 / 禁止往上 import / 阻止
  feature 互相依賴 / 鎖住依賴方向 / layering guard / dependency direction / import
  boundary / arch lint / 把分層規則放進 hook 或 CI」，或想把某個 repo 的分層不變式變成
  可機械偵測的守門時，主動使用。泛用（任何語言/package，靠 config 參數化），與
  sdd-harness-init（decision-log drift）互補、共用同一個 pre-commit。純寫應用 code、或
  只是解釋架構概念（沒有要裝守門）時不要用。
---

# arch-guard — 分層依賴方向守門

把「features → shared → data → core 這類單向分層」從**靠自律的口頭規範**，變成**commit 時被 git grep 攤出來的違規**。CLAUDE.md 告訴人/agent 規則，這個 hook 保證「不管有沒有讀 CLAUDE.md，違規都被看見」——那才是真防線。

## 這在解什麼問題

分層架構最脆的一環是**沒人擋得住往上/橫向 import**：`core` 偷偷認得 `data`、`featureA` import `featureB`、共享物該下沉卻留在某 feature。這些是靜默漂移，review 時才發現、或根本沒發現。它們**可機械偵測**（就是幾條 import 方向的 grep），所以該自動化，而不是每次靠模型記得。

## 核心方法論（裝之前先對齊，這比腳本值錢）

- **依賴只准往下**：層排成全序（top → bottom），一層只能 import 更低層。往上 import、同層 sibling 互 import（如 feature→feature）都禁止。最底層是**葉子**（領域無關、誰都不 import 上層）。
- **共享要下沉、別橫向**：兩個上層單元都要用的東西 → 下沉到共同的下層。**≥2 個上層單元消費 → 下沉**；領域**無關**沉到最底層、領域**感知**沉到中間共享層。單一 owner 的留在自己的單元。
- **warn 不擋**：pre-commit 只提醒、不阻止 commit（別擋 WIP）；硬擋留給 CI / pre-push（`--strict`）。既有違規當「待清債」列出來，不強迫一次清完。

## 流程

**1. 先跑安裝腳本**（所有機械、確定性的佈線；idempotent，可重跑）：
```
sh <skill-dir>/scripts/install.sh
```
它會：copy `hooks/arch-guard-check.sh`、seed `hooks/arch-layers.conf`（僅當不存在）、把 checker 接進 `hooks/pre-commit`（marker-guarded，與 sdd-harness-init 的 decision-log 檢查共存）、`git config core.hooksPath hooks`。

**2. 填 `hooks/arch-layers.conf`**（這步要 repo 知識，agent 做，不自動猜）：
- 看 repo 的源碼根（`lib/` 或 `src/`）底下的頂層目錄，判斷**層順序**（top → bottom）。
- `PACKAGE` 填 import 字串裡的 package/module 名。
- `IMPORT_RE` 依語言調（模板給了 Dart / TS / Python 範例）；**保留 `{LAYER}` 佔位與結尾 `/`**（避免 `data` 誤中 `database/`）。
- `PARTITIONED` 填「被切成 sibling 不准互 import」的層（feature-first 通常填 `features`）。
- **缺規格別腦補**：層邊界模糊就回報使用者，別硬分。

**3. 跑 audit 看現況**：
```
sh hooks/arch-guard-check.sh --audit
```
列出所有現存違規 + 總數。乾淨→config 對了；一堆違規→要嘛 config 分錯層、要嘛真有債。真有債就跟使用者確認是「這次清」還是「標記待清」。

**4. 把分層節加進 CLAUDE.md**：用 `assets/claude-md-arch-section.md` 當骨架，填成這個 repo 的實際層名/圖/表。理由：hook 抓違規，但「新東西該放哪層」要人/agent 看得到規則才不會一開始就放錯。

## checker 行為（`hooks/arch-guard-check.sh`）

- 讀 `hooks/arch-layers.conf`，對每層 grep「有沒有 import 更高層」+ 對 `PARTITIONED` 層 grep「sibling 互 import」。
- 預設 **warn-only、exit 0**（pre-commit 用）；`--strict` 有違規則 exit 1（CI / pre-push）；`--audit` 印違規 + 每輪計數。
- git grep 掃工作樹（tracked 檔），確定性、無副作用。

## 與 sdd-harness-init 的關係

兩者都往 `hooks/pre-commit` 佈 warn-only 檢查、共用 `core.hooksPath`：sdd-harness-init 管 **decision-log drift**（契約無關），arch-guard 管 **分層方向**（架構專屬、靠 config 參數化）。一 skill 一職責，可各自安裝、疊在同一個 hook。裝了 sdd-harness-init 的 repo 再裝 arch-guard，checker 呼叫會**append** 進既有 pre-commit，不覆蓋。

## 限制（誠實說）

- checker 靠 **import 字串裡出現層目錄名**來判斷（`IMPORT_RE`）。package/path 前綴式 import（Dart `package:`、TS alias/相對路徑、Python 模組路徑）都能配；**完全動態的 import 或反射式依賴抓不到**。
- `PARTITIONED` 的 sibling 抽取假設 path-style（`.../<layer>/<sibling>/...`）；非此形狀的語言要改 checker 的 sed，v1 以 path-prefix 為準。
- 它擋的是**方向**，不是「這個東西該不該存在於這層」的語義——後者仍靠 CLAUDE.md 規則 + review。

---
name: arch-guard
description: >-
  把「依賴只准往下」的分層架構用 pre-commit 檢查鎖進任一 repo：宣告層順序後，git grep
  抓出往上依賴、feature→feature、跨層違規，warn 不擋（可切 --strict 給 CI）。也守必經點
  ——「這條路只准經過某個入口」「不得再新增 X」「不得在 Y 以外出現」這類方向合法、卻繞過閘的
  規則。當使用者說「加分層檢查 / 架構分層守門 / 強制 clean
  architecture 層 / 禁止往上 import / 阻止 feature 互相依賴 / 鎖住依賴方向 / 禁止直呼某個
  service / 只准走某個入口 / 不准再新增某個東西 / 把 CLAUDE.md 的禁令變成檢查 / layering
  guard / dependency direction / import boundary / chokepoint / arch lint / 把規則放進 hook
  或 CI」，或想把某個 repo 的架構不變式變成可機械偵測的守門時，主動使用。泛用（任何語言/package，靠 config 參數化），與
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
- **必經點是另一類不變式**：分層守「誰可以認得誰」，但很多規則守的是「這條路必須經過某個閘」——`presentation` 直呼 `core` 方向合法，分層規則永遠不會吭聲。這類同樣可 grep，同樣該自動化，只是要另外宣告（`CHOKEPOINTS`）。
- **模式由現況決定，不是偏好**：現在 0 筆的規則鎖 `all`，已有存量債的設 `new`（理由與寫法見 conf 模板註解）。
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
- `CHOKEPOINTS` 從該 repo 的 CLAUDE.md／conventions 撈「可 grep 的禁令」填（「只准經過 X」「不得再新增 Y」「不得在 Z 出現」）。**每條先單獨 `--audit` 一次再決定 `all`／`new`**。

**3. 跑 audit 看現況**：
```
sh hooks/arch-guard-check.sh --audit
```
列出所有現存違規 + 總數。**「共 0 條違規」不代表 config 對了**——`PACKAGE`／`ROOT`／`IMPORT_RE` 任一填錯，audit 一樣印 0，跟真的乾淨長得一模一樣（實測過）。所以 0 的時候要**注入一條故障再 audit 一次**：在最底層隨便一個檔加一行 import 上層的敘述，必須被抓到；抓不到就是 config 瞎了，不是 repo 乾淨。驗完把那行刪掉。

一堆違規→要嘛 config 分錯層、要嘛真有債。真有債就跟使用者確認是「這次清」還是「標記待清」。

**4. 把分層節加進 CLAUDE.md**：用 `assets/claude-md-arch-section.md` 當骨架，填成這個 repo 的實際層名/圖/表。理由：hook 抓違規，但「新東西該放哪層」要人/agent 看得到規則才不會一開始就放錯。
- **避免重複佈線（靠條件、不靠 skill 名）**：模板尾巴那句「fresh clone 要跑 `git config core.hooksPath hooks`」是**共用 hook 佈線**、非分層專屬。grep 這份 CLAUDE.md：**若別處已有同一句 `core.hooksPath` 佈線指示（不論誰寫的）→ 刪掉本節那條、別重複**（重複＝drift 源，會被 claude-md-hygiene 抓）；沒有才保留。**注入的持久內容一律別提任何 skill 名**（否則對沒裝那個 skill 的 repo 就是空指向）。

## checker 行為（`hooks/arch-guard-check.sh`）

- 讀 `hooks/arch-layers.conf`，對每層 grep「有沒有 import 更高層」+ 對 `PARTITIONED` 層 grep「sibling 互 import」+ 逐條跑 `CHOKEPOINTS`。
- `CHOKEPOINTS` 的 `all` 走 `git grep` 掃工作樹；`new` 走 `git diff --cached` 只取新增行（所以它在 `--audit` 手動跑時通常是空的，那是預期）。**兩個模式的 pattern 語意必須一致**，否則「先用 `all` audit、再切 `new`」這條流程本身就會製造靜默失效。
- config 格式錯（欄位數不對、mode 拼錯）會**出聲並跳過那一行**，不會靜默降級成一條永不開火的規則。
- 預設 **warn-only、exit 0**（pre-commit 用）；`--strict` 有違規則 exit 1（CI / pre-push）；`--audit` 印違規 + 每輪計數。
- git grep 掃工作樹（tracked 檔），確定性、無副作用。

## 與其他 pre-commit harness 共存

arch-guard 只管**分層方向**（架構專屬、靠 config 參數化）。若 repo 已有別的 warn-only pre-commit harness（**本 marketplace 的 `sdd-harness-init` 管 decision-log drift 是一例**），兩者一 skill 一職責、疊在同一支 hook：install.sh 偵測到既有 pre-commit 就 **append**（marker-guarded）不覆蓋，`core.hooksPath` 已設就沿用不改。**不預設任何特定 skill 存在**——共存、dedup、以及上面第 4 步要不要留那句佈線指示，判準一律是「repo 現況有沒有那個東西」，不是「有沒有裝某 skill」。

## 限制（誠實說）

- checker 靠 **import 字串裡出現層目錄名**來判斷（`IMPORT_RE`）。package/path 前綴式 import（Dart `package:`、TS alias/相對路徑、Python 模組路徑）都能配；**完全動態的 import 或反射式依賴抓不到**。
- `PARTITIONED` 的 sibling 抽取假設 path-style（`.../<layer>/<sibling>/...`）；非此形狀的語言要改 checker 的 sed，v1 以 path-prefix 為準。
- 分層規則擋的是**方向**，不是「這個東西該不該存在於這層」的語義。`CHOKEPOINTS` 補得了其中**可字面偵測**的那部分；判斷「這次該不該讓步」仍然是人/agent 的事。
- `CHOKEPOINTS` 是純文字 grep：分不出合法例外，所以才有 allow 欄位（填該規則的唯一合法出口路徑）。它也會掃到 `ROOT` 底下的非源碼檔（`.md` 範例會中），需要時把副檔名寫進 pattern 或 `IGNORE`。

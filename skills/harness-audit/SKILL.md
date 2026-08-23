---
name: harness-audit
description: >-
  盤點「這個 repo 該裝哪些守門 harness、已經裝了哪些、漏了哪些」，安裝後**強制注入故障驗證每一道真的會開火**。
  動態掃 plugin cache 取得可用 skill 清單，不維護靜態清單——日後新增任何 harness skill 都會自動出現在盤點裡，
  不必回頭改這個 skill。當使用者說「開新專案 / 新 repo 要裝什麼 / bootstrap / 該裝哪些守門 / 有沒有漏裝 /
  盤點 harness / 把守門補齊 / 這個 repo 的檢查夠不夠 / 幫我建開發用的 harness / 我怕忘記要裝哪些 /
  set up guards / project bootstrap / which harness skills / audit my hooks」，或你正要為一個 repo 安裝
  pre-commit 檢查、剛裝完守門想確認它不是靜默失效、或發現 repo 有 hooks/ 卻不確定涵蓋了什麼時，主動使用。
  純寫應用 code 不要用；已經明確知道只要裝某一個 skill 時直接叫那個 skill，不必繞這裡。
---

# harness-audit — 守門盤點與驗證

## 這在解什麼問題

兩個都只在**沒做**的時候才看得見：

1. **守門「裝好了」跟「裝了但永遠不會開火」，輸出一模一樣。** 兩者都是安靜的。pattern 寫錯、檔案落在 ignore 清單、hook 根本沒接上——症狀全是「沒有發現違規」。
2. **skill 數量只會長，該裝哪些會忘。** 而靜態清單解決不了：新增 skill 時清單也要跟著改，一樣會忘。

所以這個 skill 做兩件事：**動態盤點**（不維護清單）與**強制驗證**（不信任「看起來裝好了」）。

## 流程

### 1. 盤點

```sh
sh <skill-dir>/scripts/scan-skills.sh
```

輸出這台機器上現在生效的所有 skill（名稱 + description），已濾掉 `.orphaned_at` 的舊版本。

**掃 plugin cache，不掃任何本機 repo**——換一台機器就沒有你的 skill 原始碼，但 cache 一定在。

從 description 判斷哪些是守門類（會裝 pre-commit / 檢查 / 靜態分析的），對照 repo 現況：

```sh
grep -oE '^# >>> [a-z-]+' hooks/pre-commit    # 已裝的 marker
```

### 2. 判斷適用性 — 不是全裝

裝一道不會開火的守門，比不裝更糟：它讓人以為那條規則有人在看。逐條問「這個 repo 真的需要嗎」：

- **語言對不對** — Flutter 的 review checklist 對 Swift 專案是純噪音。
- **機制對不對** — 分層檢查靠「import 字串含層目錄名」，那是 Dart/TS 的形狀。Swift/Rust 的 module 依賴由 build system 強制，grep 那層是冗餘的。
- **有沒有東西可守** — 專案只有一層時，分層規則是 no-op。這種情況只裝必經點那半。

### 3. 安裝 — delegate，不要重寫

叫對應的 skill 自己裝。這個 skill 不複製它們的安裝邏輯，否則底層 skill 更新後這裡就過期了。

安裝順序有講究：**不自己 `exit` 的檢查要插在前面**。既有 hook 可能中途 `exit`，接在後面的區塊永遠不會跑——而那看起來跟「有守門」一模一樣。

### 4. 有門檻的檢查 — 先量基準再定門檻

行數、佔比、次數這類門檻，交付前對最近 15–30 個 commit 量一次開火率：

- 對半數改動開火 = 噪音，會被無視，等於沒裝
- 完全不開火 = 也等於沒裝

目標是只有離群值會亮。

### 5. 注入故障驗證每一道 — 這步不可跳過

```sh
sh <skill-dir>/scripts/verify-guard.sh <違規檔路徑> <期望出現的關鍵字>
```

腳本負責危險的機械部分：確認 index 乾淨、`git add`、跑 hook、比對輸出、自動還原。**違規長什麼樣由你針對該 repo 的規則決定**——從 regex 反推匹配字串太脆弱，那是判斷不是機械。

**兩個方向都要驗**：

- 該開火的地方開火了
- **不該開火的地方沒開火** — allow 清單、ignore 路徑要各驗一次，否則你不知道它是「正確放行」還是「整條規則都沒作用」

實測踩過的假陰性：`git grep` 只掃 **tracked** 檔案。測試檔沒 `git add` 就跑 audit，得到 0 條違規，看起來乾淨。verify-guard.sh 會自己 add，但手動跑 audit 時要記得。

### 6. 寫進 CLAUDE.md

hook 只在 commit 當下說話，CLAUDE.md 每個 session 都載入。列一張表：哪些檢查、各守什麼、warn 還是擋。**明文寫出已知缺口**——例如 `core.hooksPath` 不進版控，fresh clone / 新 worktree 沒設就是全部靜默失效。寫出來的缺口才有人記得，沒寫的會被當成不存在。

## 兩個值得手寫的模式

現成 skill 涵蓋不到、但反覆出現：

**編譯層守門優於 grep 層守門。** 能讓違規變成編譯錯誤的，不要用文字比對。例：Swift package 宣告 macOS 平台，`import UIKit` 直接編譯失敗——`--no-verify` 繞不過，而 grep 那條繞得過。同理：型別系統、`#if` 條件、build config 的 deny 清單。

**同一份契約有兩份權威時，改一邊要提醒另一邊。** 例：設計書的線路格式（人讀）與測試向量 JSON（機器讀）。寫一支十行的 hook：staged 動了 A、diff 命中關鍵字、B 沒動 → 警告。這類規則專案特定，沒有通用 skill，但成本極低。

## 什麼時候不要裝 CI

CI 的價值前提是**失敗會被看到**。private repo + 沒裝 `gh` = 沒有查詢管道，紅燈跟綠燈沒有差別，那 CI 只是多一個會壞掉而沒人知道的東西。

判斷順序：先問「誰會看到失敗、透過什麼管道」。答不出來就不要裝，把該檢查搬進 pre-commit。

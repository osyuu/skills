---
name: harness-audit
description: >-
  盤點「這個 repo 該裝哪些守門 harness、已經裝了哪些、漏了哪些」，安裝後**強制注入故障驗證每一道真的會開火**。
  動態掃 plugin cache 取得可用 skill 清單，不維護靜態清單——日後新增任何 harness skill 都會自動出現在盤點裡，
  不必回頭改這個 skill。當使用者說「開新專案 / 新 repo 要裝什麼 / bootstrap / 該裝哪些守門 / 有沒有漏裝 /
  盤點 harness / 把守門補齊 / 這個 repo 的檢查夠不夠 / 幫我建開發用的 harness / 我怕忘記要裝哪些 /
  set up guards / project bootstrap / which harness skills / audit my hooks / pre-commit hooks /
  guard rails / verify the hooks actually fire / is my lint even running / what checks does this repo have」，
  或你正要為一個 repo 安裝 pre-commit 檢查、剛裝完守門想確認它不是靜默失效、
  或發現 repo 有 hooks/ 卻不確定涵蓋了什麼時，主動使用。
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

輸出這台機器上現在生效的所有 skill（`plugin:skill` 限定名 + description），已濾掉 `.orphaned_at` 的舊版本。取不到描述的仍會列出並標 `(無描述)`——靜默消失跟「那個 skill 根本沒裝」無法分辨，對盤點是最致命的失敗模式。

兩個環境變數：`CLAUDE_PLUGIN_CACHE` 換掃描路徑（測試用），`HARNESS_AUDIT_DESC_MAX` 截斷描述長度（預設不截；截斷按 byte，中文會被切壞）。

**掃 plugin cache，不掃任何本機 repo**——換一台機器就沒有你的 skill 原始碼，但 cache 一定在。

從 description 判斷哪些是守門類（會裝 pre-commit / 檢查 / 靜態分析的），對照 repo 現況：

```sh
grep -oE '^# >>> .* >>>' hooks/pre-commit     # 已裝的 marker
```

marker 名稱含空格（例如 `# >>> sdd-harness decision-log >>>`），字元類別漏掉空格會把它截半。

**盤點看不到 `~/.claude/skills/`**——那裡的本機 skill 與 plugin 版同名時會互相打架，而掃描刻意不含它（那個目錄換機器就沒有）。有本機 skill 的話要另外 `ls ~/.claude/skills/` 對照。

**「哪些算守門類」由你從 description 判斷，沒有欄位或關鍵字約定。** 這是刻意的——加了約定就等於維護一份靜態清單，而新 skill 不會遵守它。代價是同一個 repo 兩次盤點可能得到略微不同的結論；判斷不了就去讀那個 skill 的 SKILL.md，不要猜。

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

目標是只有離群值會亮。**這步沒有通用腳本**——每個檢查的門檻定義不同，要對著該檢查的規則寫一次性統計（對每個 commit 的每個相關檔案，算它的新增行會不會觸發門檻）。寫起來大約十行，但不寫就只能猜。

### 5. 注入故障驗證每一道 — 這步不可跳過

```sh
sh <skill-dir>/scripts/verify-guard.sh              <新檔路徑> <期望出現的關鍵字>
sh <skill-dir>/scripts/verify-guard.sh --expect-no-fire <新檔路徑> <關鍵字>
```

腳本負責危險的機械部分：確認 index 乾淨、`git add`、跑 hook、字面比對輸出、自動還原。**違規長什麼樣由你針對該 repo 的規則決定**——從 regex 反推匹配字串太脆弱，那是判斷不是機械。

檔案必須是**你剛建的新檔**（未被 git 追蹤）。腳本驗完會刪掉它，所以拒絕既有檔案——對那些檔案等於刪掉未 commit 的修改，救不回來。

**因此它只驗得了「新增檔案」型的守門。** 若守門檢查的是**既有檔案的修改**——例如「decision log 有未打勾項」「設計書的線路格式改了但測試向量沒跟上」——那個前提不成立，得手動驗：

```sh
cp <target> /tmp/bak            # 備份
<製造違規>                       # 追加或修改
git add <target>
sh hooks/pre-commit 2>&1 | grep -F "<關鍵字>"
git reset -q HEAD -- <target>   # index 與工作區都要還原
cp /tmp/bak <target>
```

手動路徑沒有 trap 保護，中途失敗會留下髒 index。先確認 `git status` 乾淨再開始，做完再確認一次。

**兩個方向都要驗**：

- 該開火的地方開火了
- **不該開火的地方沒開火**（`--expect-no-fire`）— allow 清單、ignore 路徑要各驗一次，否則你不知道它是「正確放行」還是「整條規則都沒作用」

**`--expect-no-fire` 的綠燈必須配對解讀。** 它斷言的是「關鍵字不存在」，而**任何原因**造成的不存在都是綠燈——守門整條被誤刪是綠燈，關鍵字打錯一個字母也是綠燈。只有在同一個關鍵字的正向驗證也通過時，這個綠燈才有意義。單獨跑它拿到的綠勾，跟真的驗過長得一模一樣。

**關鍵字要選得足以區分同一支 hook 裡的其他守門。** 一支 pre-commit 常疊四五道檢查，若它們共用輸出前綴（例如都以 `[guard]` 開頭），`--expect-no-fire` 會被別道守門的正常輸出誤觸發。挑該道守門獨有的字串。

關鍵字是**字面比對**，不是 regex。守門常用 `[name]` 當輸出前綴，走 regex 會被當字元類；反過來 `core.UI` 會誤中 `core/UI` 造成**假陽性**——那比假陰性更糟，它讓人簽收一道從沒驗過的守門。

實測踩過的假陰性：`git grep` 只掃 **tracked** 檔案。測試檔沒 `git add` 就跑 audit，得到 0 條違規，看起來乾淨。verify-guard.sh 會自己 add，但手動跑 audit 時要記得。

**排除／ignore 樣式的錨點要對著「工具的實際輸出」寫，不是對著檔名寫。** 實測踩過：
在 arch-guard 的 IGNORE 加 `^CLAUDE\.md$` 想排掉規範檔——**靜默不生效**，因為
`grep -v` 吃的是 `git grep -n` 的輸出（`CLAUDE.md:14:…`），行尾錨點永遠不匹配。
正確是 `^CLAUDE\.md:`。這個錯誤沒有任何錯誤訊息，而**正向測試看不見它**（該開火的
還是照樣開火）——只有 `--expect-no-fire` 那一向抓得到。這正是「兩個方向都要驗」
不是形式主義的原因。

### 6. 寫進 CLAUDE.md

hook 只在 commit 當下說話，CLAUDE.md 每個 session 都載入。列一張表：哪些檢查、各守什麼、warn 還是擋。**明文寫出已知缺口**——例如 `core.hooksPath` 不進版控，fresh clone / 新 worktree 沒設就是全部靜默失效。寫出來的缺口才有人記得，沒寫的會被當成不存在。

**同時在 decision log 留一筆**（`sdd-harness-init` 的 `DECISIONS.md`）。理由不是形式：
裝守門會讓某條不變式的**保護狀態改變**，而那條不變式通常已經被寫在好幾份文件裡，
帶著「這條沒有機械守護者」之類的舊宣稱。裝守門當下若不留回寫記錄，就沒有任何機制
要求那幾處更新。**踩過：一道守門裝上之後，三份描述該不變式的文件同時停在「這條
沒有機械守護者」，而且全部通過所有檢查**——hook 只驗 decision 有沒有打勾，不驗
內容對不對。

**覆蓋範圍要寫成「攔得住什麼／攔不住什麼」，兩者都以注入實測為準。**「有守門」與
「沒有守門」常常都是錯的宣稱——同一道 arch-guard 攔得住 `UserDefaults` 卻攔不住
`Data.write(to:)`，只有各注入一次才知道界線在哪。寫下界線的那份文件才不會過期成
另一種謊。

## 兩個值得手寫的模式

現成 skill 涵蓋不到、但反覆出現：

**編譯層守門優於 grep 層守門。** 能讓違規變成編譯錯誤的，不要用文字比對。例：Swift package 宣告 macOS 平台，`import UIKit` 直接編譯失敗——`--no-verify` 繞不過，而 grep 那條繞得過。同理：型別系統、`#if` 條件、build config 的 deny 清單。

**同一份契約有兩份權威時，改一邊要提醒另一邊。** 例：設計書的線路格式（人讀）與測試向量 JSON（機器讀）。寫一支十行的 hook：staged 動了 A、diff 命中關鍵字、B 沒動 → 警告。這類規則專案特定，沒有通用 skill，但成本極低。

## 什麼時候不要裝 CI

CI 的價值前提是**失敗會被看到**。private repo + 沒裝 `gh` = 沒有查詢管道，紅燈跟綠燈沒有差別，那 CI 只是多一個會壞掉而沒人知道的東西。

判斷順序：先問「誰會看到失敗、透過什麼管道」。答不出來就不要裝，把該檢查搬進 pre-commit。

---
name: sdd-harness-init
description: >-
  在一個 repo 裡佈好「決策記錄 + drift 防護」的 SDD harness：DECISIONS.md 記翻案、warn-only 的
  pre-commit 在 commit 當下把未回寫的攤出來。當使用者說「幫這個專案裝 decision log / 決策記錄機制 / drift
  防護 / SDD harness / pre-commit 決策 hook / 把翻案追蹤機制搬過來 / bootstrap decision log」，或想把這套
  DECISIONS.md 機制套到新專案時，主動使用。也涵蓋「spec 說做了但 code 沒做」這半邊——
  文件宣稱完成卻沒回寫、任務打勾但驗收項沒驗、改到沒人在用的死碼、spec 點名的介面不存在。這是「安裝器 / 佈線」——需求→設計書的『生成』請用 design-doc
  skill。純寫應用 code 不要用。
---

# SDD Harness Init — 決策記錄 drift-guard 安裝器

把「翻案當下就記錄、未回寫就警告」這套機制 30 秒佈進任何 repo。這**不是**生成設計書（那是 `design-doc` skill 的事），而是打地基：讓翻案有地方落、讓漂移在 commit 時被看見。

## 這套機制在解什麼問題

SDD 有兩種漂移，這個 harness 各配一支 warn-only 的 hook：

| 漂移 | 長相 | 守它的 |
|---|---|---|
| **翻案沒回寫** | 決策改了，spec 還停在舊版 | `DECISIONS.md` + decision-log hook |
| **回寫不實** | spec 說做了，code 沒有 | `spec-claim-check.sh` |

第二種比第一種難察覺得多：**它不是空白，是一份看起來很完整的謊**，而下一個讀它的人（或模型）會照著那份謊做決定。

### 翻案沒回寫

SDD 最脆的一環是**察覺→記錄→回寫**：spec 與 code 漂移，通常是因為「決策翻案時沒當場記，交付前憑記憶重建」。這套 harness 用一個 append-only 的 `DECISIONS.md` 當 staging area（翻案當下寫進檔案，穿過 compact），配一個 pre-commit hook 在每次 commit 把未打勾項攤到眼前。**「察覺翻案」無法機械化**——這套只保證「已記錄的一定被提醒回寫」，剩下靠自律 + 任務 DoD。

### 回寫不實

`spec-claim-check.sh` 抓三種「宣稱完成但 code 沒有」，全部 warn-only：

1. **打勾的任務，驗收項還沒打勾**——任務表標 ✅，它指名的 AC 仍是 `- [ ]`。純機械、零誤判。
   它**不需要原始碼目錄**，所以 `SPEC_SRC_DIRS` 沒填或填錯時這條仍然會跑（訊號 2／3 會跳過，
   並且會出聲說它跳過了——那句話本身就是「路徑該修了」的訊號）。
2. **spec 點名的符號只有定義、沒有消費者**——最難自己發現的一種：**你改了一份沒有人在用的 code**。文件說修好了、測試綠、注入故障也會紅，三者一致地宣稱完成，而畫面紋風不動。
3. **spec 宣告的介面不存在**（帶括號的 `foo()`）——散文提到未來的東西是設計書常態，寫成方法簽名就是在宣告契約；契約找不到＝未做或改名沒回寫。

**裝完先量基準再決定要不要收緊**（同 `comment-budget` 的做法）：對七成 commit 開火＝噪音、會被學會忽略；完全不開火＝等於沒裝。實測一個中型 iOS repo，加上「只評估本 repo 有定義的符號」這道過濾後，誤判從九成降到可接受，跑一次 1.4 秒。**沒有這道過濾不要出貨**——散文點名框架 API（`AVAudioSourceNode`、`prepareToPlay`）在原始碼裡出現一次正是「被呼叫了一次」，不是死碼。

## 機制擋不住的三種（判斷題，寫進任務 DoD）

腳本只認得「文件與 code 對不上」。下面三種要靠人/模型自律，但它們各出過事，值得逐條列進交付前的自檢：

- **測試與實作同源時，測試沒有驗證能力。** 實作寫 `selectedTab = 0`、測試也斷言 `0`，而訊息寫著「必須切到 Dual」——兩邊出自同一個錯誤信念，它永遠綠。注入故障也救不了：把 0 改成 1 確實變紅，那只證明「測試在檢查某個數字」，不證明檢查的是對的數字。**判準：斷言要指向外部權威**（另一份定義、規格條文、真實資料），不要指向與實作同源的字面值；能收斂成一個具名常數就收斂，讓正確性不再依賴那個值。
- **注入故障驗的是「測試蓋到那段 code」，不是「那段 code 在產品路徑上」。** 死碼的測試一樣會紅。改完一個東西畫面沒變，第一個假設是「我改的不是產品在用的那份」。
- **未完成的功能要出聲。** 一個功能若只在部分路徑可達，不可達的那些路徑**必須顯示為什麼**——灰掉的按鈕加一句原因，而不是什麼都不畫。看不見的東西會被當成壞掉，而追一個不存在的 bug 的成本由使用者付。這條也該寫進 AC：**每個不可用狀態都要有可見的說明**。

## 機制與專案的分界（安裝時心裡要清楚）

- **可攜核心（本 skill 佈的）**：`DECISIONS.md` 格式 + `pre-commit`（兩個區塊）+ `spec-claim-check.sh` + `core.hooksPath` 佈線 + CLAUDE 指標節。跟任何契約無關。
- **每專案限定（留 `<TODO>` 給使用者填）**：回寫目標是什麼。可能是 API 契約、schema、某份 design doc，也可能沒有集中契約（就「各決策就近回寫對應 design doc」）。`DECISIONS.md` 的 `→ 回寫目標` 是**自由文字欄**，機制只認「有沒有打勾」，不認目標是誰——所以泛化幾乎零成本，只是別把某專案的檔名寫死進模板。

## 流程

**先跑安裝腳本**（處理所有機械、安全、確定性的佈線；idempotent）：

```
sh <skill-dir>/scripts/install.sh
```

在**目標 repo 根目錄**跑。它會：建 `docs/design/DECISIONS.md`（缺才建、模板來自 `assets/`）、裝 `hooks/pre-commit`、在安全前提下 `git config core.hooksPath hooks`、被 gitignore 就 force-add、回報 CLAUDE 檔的指標節狀態。**已存在的一律不覆蓋。** 跑完它會印一份「後續判斷項」清單。

**再處理腳本印出的判斷項**（這些刻意不自動做，需要你/模型拍板）：

1. **填 `<TODO>`**：`DECISIONS.md` 的 `<PROJECT>` 換成 repo 名；「本專案回寫目標」照模板骨架填（API 形狀 → 集中契約或就近 design doc／資料形狀 → schema＋migration／跨層約束 → CLAUDE 檔），刪掉不適用的、把佔位路徑換成 repo 實際檔。骨架已在模板裡，通常微調即可、不必從零發明。
2. **填 `spec-claim.conf` 的 `SPEC_SRC_DIRS`／`SPEC_TEST_DIRS`**：預設 `src lib app` 多數 repo 對不上。**填完當場注入故障驗一次**——在受 `SPEC_GLOBS` 涵蓋的 spec 裡加一行宣告不存在的介面，**要用反引號包起來**（腳本只認 `` `foo()` ``）且長度過得了 `SPEC_SYMBOL_MIN_LEN`，跑 `sh hooks/spec-claim-check.sh`，必須開火；驗完把那行刪掉。**不要用「跑一次看看」當驗證**：沒發現時這支腳本完全不輸出，路徑填錯跟真的乾淨長得一模一樣。
3. **注入 CLAUDE 指標節**：讀 `assets/claude-section.md`，把 marker 區塊（`<!-- sdd-harness:decision-log:start -->` … `end`）插進適當位置，並填同樣的回寫目標 `<TODO>`。
   - **放哪個檔**：團隊共享規範 → `CLAUDE.md`；個人本機約束 → `CLAUDE.local.md`。**repo 完全沒有 CLAUDE 檔時，預設新建 `CLAUDE.md`**——此 harness（版控的 DECISIONS.md＋hook）本質是團隊共享機制。
   - **別重複注入**：已有 marker → 跳過。若腳本回報「有本節標題但 marker 遺失」（多半是 `claude-md-hygiene` 之類重寫工具洗掉了隱形 marker），**就地把既有內容用 marker 重新包起來**，不要新增第二節。
4. **hook 衝突**：若腳本說目標路徑已有非本機制的 `pre-commit`，**別覆蓋**——把 `assets/pre-commit` 的 marker 區塊附加進既有 hook。若 repo 已用非預設 `core.hooksPath`（husky/.githooks 等），腳本會用那個目錄、不改設定。
5. **`.git/hooks/` 遮蔽**：若腳本因 `.git/hooks/` 有實體 hook 而跳過佈線，決定是否把它們併進 `hooks/` 再手動 `git config core.hooksPath hooks`。

## 收尾提醒

- **`core.hooksPath` 不進版控**：fresh clone / 新 worktree 都要各自再跑一次 `git config core.hooksPath hooks` 才生效。這句已寫進 CLAUDE 指標節與 hook 註解，別漏講。
- **DECISIONS.md 要被追蹤**：若 repo 把 `docs/design/` 排除（把 design 當個人筆記的專案會這樣設），腳本會 force-add DECISIONS.md 與 hook——因為機制要對隊友/CI 生效就得進版控。這不影響同目錄其他設計書的歸屬，那是 `design-doc` skill 每個 repo 問一次的獨立設定。
- **插進共用 pre-commit 的區塊必須自足**：包在子 shell 裡、只用 `exit` 結束自己。少了這層，
  本區塊在最常見的狀態（沒有待回寫的決策）early exit，會把**後面所有人的檢查一起靜默跳過**
  ——那看起來跟「對方沒裝」一模一樣。同理，別把自己的區塊接在別人的 `exit` 後面。
- **hook 是 warn-only（軟約束）**：要硬 gate（擋 merge）得靠 CI 去讀 DECISIONS.md + spec 進版控；pre-commit 本身刻意不擋（改末尾 `exit 0`→`exit 1` 可改成擋，但通常不建議）。
- 裝完 harness 後要寫 spec，轉 `design-doc`——DECISIONS.md 就是它的翻案落點。
- 跟 `claim-check` skill **分工明確、不要合併**：本 skill 守的是**這個 repo 的產物**（spec 對不對得上 code），裝在 repo 裡、每個 repo 跑一次；`claim-check` 守的是**agent 的敘述**（說「跑過了」有沒有真的跑），裝在 `~/.claude`、每台機器跑一次。合併會讓「幫第五個專案裝 harness」順手改掉全域 settings——使用者不會預期，事後也難追。兩者的漏洞剛好互補：spec 沒說謊不代表報告沒說謊。
- 跟 `claude-md-hygiene` skill **不衝突、互補**：本 skill 注入 CLAUDE.md 的那節剛好是 hygiene 要保留的三類（不變式機制＋指向 DECISIONS.md 的指標＋「hooksPath 不進版控」這個踩坑），真正易變的決策本身在 DECISIONS.md、不在 CLAUDE.md，所以 hygiene 會留下這節。唯一要注意：hygiene 若整份重寫 CLAUDE.md 可能洗掉隱形 marker——上面第 2 步的「標題 fallback + 就地重包」已處理，不會重複注入。

## 品質自檢

- 腳本印的「後續判斷項」都處理了嗎（`<TODO>`、`spec-claim.conf` 路徑、CLAUDE 指標節）？
- `spec-claim.conf` 的路徑**注入故障驗過了嗎**（流程 2）？沒驗過就不知道它是乾淨還是瞎的。
- 回寫目標有沒有寫死某專案的檔名進**模板/skill**（該只出現在目標 repo 的實體檔）？
- CLAUDE 指標節放對檔（共享 vs 本機）了嗎？
- 有沒有覆蓋到既有的 pre-commit / DECISIONS.md？（不該——全 idempotent）

---
name: skill-authoring
description: >-
  撰寫、改進、審查 Claude Code skill 的房規與範本——涵蓋 SKILL.md 結構、description 觸發設計、漸進式揭露、右尺寸、去冗餘,以及本 marketplace 的登錄流程(加進 marketplace.json、bump version、去重本機同名 skill)。當使用者說「寫一個 skill / 新增 skill / 改進這個 skill / 這個 skill 怎麼沒觸發 / 幫 skill 潤一下 / review 這個 SKILL.md / 把這個流程變成 skill」,或在這個 skills repo 裡新增/編輯任何 SKILL.md 時,主動使用。需要跑嚴謹的 eval/benchmark 迭代時改用 bundled 的 skill-creator;本 skill 專注在「寫得好 + 正確登錄」。
---

# Skill Authoring — 房規與範本

寫一份好 skill 的核心認知:**SKILL.md 不是說明文件,是給模型的「觸發器 + 決策框架」**。使用者不會讀它,模型才會。所以每一行都要問:「這句話會不會讓模型在對的時機啟動、並在啟動後做對事?」不會 → 刪。

需要嚴謹跑 eval/跑分迭代時,用 bundled 的 `skill-creator`(它有整套 benchmark/viewer harness);本 skill 是**撰寫慣例 + 本 repo 的登錄機制**,兩者互補不重複。

## 何時用 / 何時不用

**用**:新增 skill、編輯/改進/重構既有 skill、寫或潤 SKILL.md、診斷「skill 該觸發卻沒觸發」、審查 skill 品質、把一段重複的工作流程固化成 skill。

**不用**:純寫應用程式 code(那是一般開發)、跑 skill 的 eval 跑分(用 skill-creator)、寫給人看的 README/文件。

## 三層漸進式揭露(先懂這個,決定內容擺哪)

模型分三層載入,把東西放對層是省 context 的關鍵:

1. **metadata(name + description)**:**永遠在 context**。這是觸發的唯一依據,約 100 字。
2. **SKILL.md body**:skill 觸發時才載入,**理想 <500 行**。放「每次都要的核心流程/原則」。
3. **bundled resources**(`references/`、`assets/`、`scripts/`):**按需載入**,不佔平時 context。大塊資料、模板、可執行腳本放這。

判準:一份參考資料若不是每次都要 → 移進 `references/`,body 只留一句「何時去讀它」的指標。body 逼近 500 行 → 拆層,別硬塞。

## description 是第一槓桿(最該用力的地方)

description 決定「會不會被觸發」,勝過 body 裡任何內容。三個要點:

1. **同時寫「做什麼」+「何時用」**。所有 when-to-use 資訊放這裡,不要只放 body——body 只在觸發後才被讀到,對觸發沒幫助。
2. **略帶 pushy,撒觸發網**。模型傾向 under-trigger(該用不用)。列出使用者可能講的**動作詞 / 情境 / 產物**當關鍵字面。雙語工作就中英都鋪。
3. **必要時寫負面觸發**(「…時不要用」),壓低 over-trigger 與跟鄰近 skill 的混淆。

**反例**:`把資料視覺化成圖表`
**正例**:`把資料視覺化成圖表。當使用者提到 dashboard、報表、data viz、圖表、要呈現任何數據時主動使用,即使沒明講「圖表」二字。純資料清理(無視覺產出)不要用。`

## body 撰寫風格

- **祈使句**寫指令(「先讀需求」而非「你應該要讀需求」)。
- **解釋 why,而非堆 ALL-CAPS MUST**。今天的模型有 theory of mind,講清楚「為什麼重要」比命令句更有效、也更耐用。發現自己在寫 `ALWAYS`/`NEVER` 全大寫或超死板結構 → 黃燈,改成講理由。
- **通用勝過窄例**。針對特定範例寫死的規則,換個輸入就失效;抽出原則。
- **去冗餘**。同一件事在多節重複要有理由(如 checklist 跨審查視角刻意各列一次);否則刪。逐字重複兩處 → 併一處。

## 進階手法(值錢但別硬塞,右尺寸為先)

看情況採用,不是每個 skill 都要:

- **Must / Recommended / Skip 分診**:body 開頭給觸發三分法 + 一句決策準則。對「容易誤觸發」的 skill 特別有效(範式:ui-ux-pro-max)。
- **優先級 / severity 表**:清單型 skill 若條目很多,標 CRITICAL/HIGH/MEDIUM 給分診順序,勝過平鋪——讓模型先攻高衝擊項再挑細節。
- **穩定 rule ID**(kebab-case handle):條目要被引用/查詢時才需要;個人小 skill 通常 overkill。
- **重內容外移 + 腳本化**:大塊資料進 `references/`;重複的確定性步驟寫成 `scripts/` 讓模型直接執行,不必每次重寫。
- **逐條 citation**:規則需要權威背書時附來源;有底部 Sources 區通常就夠。

## 登錄到本 marketplace(寫完別漏這步,漏了等於沒發佈)

1. skill 目錄放 `skills/<skill-name>/`,至少含 `SKILL.md`;附屬檔進各自的 `references/`、`assets/`、`scripts/`。
2. 在 `.claude-plugin/marketplace.json` 的 `plugins[]` **加一筆**:`{ "name": "<skill-name>", "source": "./", "skills": ["./skills/<skill-name>"] }`。獨立一個 plugin = 可被選擇性安裝。
3. **bump `metadata.version`**(改了任何 skill 都要),否則別台 `/plugin update` 拉不到。
4. **去重本機**:若 `~/.claude/skills/<skill-name>` 還有同名實體目錄,改用 plugin 後會兩份打架——移除本機那份,只從 plugin 載。
5. 用 `assets/skill-template.md` 當新 skill 的骨架起手。

## 品質自檢(寫完/改完自問)

- description 有沒有同時講「做什麼 + 何時用」?夠不夠 pushy?要不要加負面觸發?
- body 是否 <500 行?每次都要的才留 body,其餘進 references/assets?
- 有沒有解釋 why,還是在堆 ALL-CAPS MUST?
- 有沒有逐字重複?跨節重複是刻意(有用)還是冗餘(該刪)?
- 這個 skill 值得這麼多內容嗎,還是為填版而灌水?
- 進階手法(分診/severity/ID/腳本)是這個 skill 真的需要,還是 over-engineer?
- marketplace.json 加了嗎?version bump 了嗎?本機同名去重了嗎?

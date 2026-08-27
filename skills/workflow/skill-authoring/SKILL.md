---
name: skill-authoring
description: >-
  撰寫、改進、審查 Claude Code skill 的房規與範本,以及本 marketplace 的登錄流程(加進
  marketplace.json、bump version、去重本機同名 skill)。當使用者說「寫一個 skill / 新增
  skill / 改進這個 skill / 這個 skill 怎麼沒觸發 / 幫 skill 潤一下 / review 這個 SKILL.md
  / 把這個流程變成 skill」,或在這個 skills repo 裡新增/編輯任何 SKILL.md
  時,主動使用。需要跑嚴謹的 eval/benchmark 迭代時改用 bundled 的 skill-creator。
---

# Skill Authoring — 房規與範本

寫一份好 skill 的核心認知:**SKILL.md 不是說明文件,是給模型的「觸發器 + 決策框架」**。使用者不會讀它,模型才會。所以每一行都要問:「這句話會不會讓模型在對的時機啟動、並在啟動後做對事?」不會 → 刪。

## 何時用 / 何時不用

**用**:新增 skill、編輯/改進/重構既有 skill、寫或潤 SKILL.md、診斷「skill 該觸發卻沒觸發」、審查 skill 品質、把一段重複的工作流程固化成 skill。

**不用**:純寫應用程式 code(那是一般開發)、跑 skill 的 eval 跑分(用 skill-creator)、寫給人看的 README/文件。

## 寫作判準:先叫用 writing-for-agents

**寫新 skill 或大改既有 skill 前,先叫用 `mattpocock-skills:writing-for-agents` 拿完整判準**——資訊階層與漸進式揭露、context pointer 的寫法、完成判準的清晰度與要求度、leading word、negation、no-op 與去冗餘,那份是這些判準的單一真相,本檔不複製一份。**沒裝就跳過**(它走 mattpocock marketplace、不隨 osyuu 同步,新機可能沒有),下面的壓縮版足以完成登錄與基本品質。

壓縮版——沒裝時至少守住這三條:

- **三層載入,把東西放對層**:metadata(name + description)**永遠在 context**、約 100 字;SKILL.md body 觸發時才載入、**理想 <500 行**;`references/`、`assets/`、`scripts/` 按需載入。不是每次都要的往下層放,body 只留一句「何時去讀它」。body 逼近 500 行 → 拆層,別硬塞。
- **解釋 why,而非堆 ALL-CAPS MUST**。今天的模型有 theory of mind,講清楚「為什麼重要」比命令句更有效、也更耐用。發現自己在寫 `ALWAYS`/`NEVER` 全大寫或超死板結構 → 黃燈,改成講理由。
- **去冗餘**。同一件事在多節重複要有理由(如 checklist 跨審查視角刻意各列一次);否則刪。逐字重複兩處 → 併一處。

## description 是第一槓桿(最該用力的地方)

description 決定「會不會被觸發」,勝過 body 裡任何內容。**怎麼寫**見 writing-for-agents 的 context pointer 一節;這裡只記它沒有的兩條本地慣例:

1. **略帶 pushy,撒觸發網**。模型傾向 under-trigger(該用不用)。列出使用者可能講的**動作詞 / 情境 / 產物**當關鍵字面。雙語工作就中英都鋪。
2. **必要時寫負面觸發**(「…時不要用」),壓低 over-trigger 與跟鄰近 skill 的混淆——這個 marketplace 的 skill 彼此邊界相鄰,少了它就會互搶。

**反例**:`把資料視覺化成圖表`
**正例**:`把資料視覺化成圖表。當使用者提到 dashboard、報表、data viz、圖表、要呈現任何數據時主動使用,即使沒明講「圖表」二字。純資料清理(無視覺產出)不要用。`

### ⚠️ 清單裡描述空白,通常不是你寫壞 YAML

看到 skill 清單只有 `- name` 而後面空白,第一直覺是 frontmatter 壞了。**多數情況不是**——是 harness 的**清單預算**把描述砍掉了(claude-code 2.1.220 實測 `formatCommandsWithinBudget`):

- 每回合送給模型的 skill 清單有**總字元預算** = context window × 4 × `skillListingBudgetFraction`(預設 `0.01`)。裝的 skill 一多就超。
- 超預算時按 **frecency 排序**砍:分數 = `usageCount × max(0.5^(天數/7), 0.1)`,**從沒被叫用過 = 0 分**。分數低的**整條描述被拿掉、只留 `- name`**;bundled skill 不砍。
- 分數存在 `~/.claude.json` 的 `skillUsage`,key 是**限定名**(`plugin:skill`)。同名的本機 skill 與 plugin skill **是兩個 key、分數不互通**——從本機搬進 plugin 後等於歸零重數。
- 另有每條上限 `skillListingMaxDescChars`(預設 1536 字),超過才截成 `…`(不是變空)。

**所以「新裝 + 還沒用過」的 skill 最容易被砍描述,而它正需要描述才會被自動觸發**——雞生蛋。這也是為什麼「改一改 description 就好了」常常是錯覺:真正變的是那陣子剛好叫用過它。

**診斷順序**(別急著改 YAML):
1. `python3 -c "import json,os;print([k for k in json.load(open(os.path.expanduser('~/.claude.json')))['skillUsage']])"` — 這個限定名在不在?不在 = 0 分,被砍很正常。
2. 真要排除 YAML,`yaml.safe_load` 解 frontmatter 看 description 拿不拿得到(拿得到就不是 YAML 的事)。

**解法**(照順序,前兩個才是對症):
1. `/skills` 把用不到的整包 skill 關掉 / 設 name-only — 釋放預算給真正在用的。
2. 提高 `skillListingBudgetFraction`(settings.json)—— **每回合都吃 context**,慎用。
3. 描述寫精短一點(治標,只是讓自己少佔預算)。

## 進階手法(值錢但別硬塞,右尺寸為先)

看情況採用,不是每個 skill 都要:

- **Must / Recommended / Skip 分診**:body 開頭給觸發三分法 + 一句決策準則。對「容易誤觸發」的 skill 特別有效(範式:ui-ux-pro-max)。
- **優先級 / severity 表**:清單型 skill 若條目很多,標 CRITICAL/HIGH/MEDIUM 給分診順序,勝過平鋪——讓模型先攻高衝擊項再挑細節。
- **穩定 rule ID**(kebab-case handle):條目要被引用/查詢時才需要;個人小 skill 通常 overkill。
- **腳本化**:重複的確定性步驟寫成 `scripts/` 讓模型直接執行,不必每次重寫。
- **逐條 citation**:規則需要權威背書時附來源;有底部 Sources 區通常就夠。

## 登錄到本 marketplace(寫完別漏這步,漏了等於沒發佈)

1. skill 目錄放 `skills/<category>/<skill-name>/`,至少含 `SKILL.md`;附屬檔進各自的 `references/`、`assets/`、`scripts/`。分類三選一:**`harness/`** 留下會自己開火的機制(pre-commit / hook),**`workflow/`** 叫用當下做完就結束,**`review/`** 拿檢查表審既有 code;判準寫在各目錄的 `README.md`。
2. 在 `.claude-plugin/marketplace.json` 的 `plugins[]` **加一筆**:`{ "name": "<skill-name>", "source": "./", "skills": ["./skills/<category>/<skill-name>"] }`。獨立一個 plugin = 可被選擇性安裝。**plugin 名不含分類前綴**——分類只在路徑上,`skillUsage` 的 key 來自 frontmatter 的 `name`,搬目錄不會重置分數。
3. **push 到 main 就會傳播**:marketplace 註冊時預設 `autoUpdate: true`,各機**下次啟動時自動拉最新 commit**(github-source 追的是 git HEAD,不是 `metadata.version`)。所以主流程是「改 → commit → push」,不必手動叫別台更新。`metadata.version` 照樣 bump,但它是**人類可讀的變更標記,不是觸發條件**;要當下就生效(不等重啟)才手動 `/plugin update`。
4. ⚠️ **改動只對「新 session」生效,已經在跑的 session 拿不到。** skill 全文是在**被叫用的那一刻**抓進對話的,之後不會換——所以一個開很久的 session 會一路照著當初那份工作,而你以為它看得到你剛 push 的版本。**兩邊都沒有任何訊號。** 實測踩過:一個 7/24 開的 session,到 8/22 仍在照 8/5 的版本做事,期間 plugin 已經更新兩次;那幾天新加的規則(SDD 完整性掃描、「review 不能自己審」、mutation 表)對它從頭到尾不存在。
   - 改完 skill 想立刻用 → **開新 session**(最乾淨),或在原 session **重新叫一次那個 skill** 把當下的版本拉進來。
   - 快取裡同時有好幾個版本是**正常的**:舊版會標 `.orphaned_at`,約 14 天後背景清掉,寬限期是給還在跑的舊 session 用的。要判斷「現在生效的是哪一份」,看哪個目錄**沒有** `.orphaned_at`。
5. **去重本機**:若 `~/.claude/skills/<skill-name>` 還有同名實體目錄,改用 plugin 後會兩份打架——移除本機那份,只從 plugin 載。
6. 用 `assets/skill-template.md` 當新 skill 的骨架起手。

## 腳本要跑過失敗路徑,不只跑過成功路徑

skill 附的腳本最容易「寫完看起來對就出貨」。兩個只有**執行**才看得到的坑,同一天各踩一次:

- **變數後面接 CJK 一定要 `${}`。** `$f。` / `$SETTINGS（` 會被當成變數名 `f。` / `SETTINGS（`,
  配上 `set -u` 直接中止整支腳本。一次讓安裝器的後續提示全部消失,一次讓「JSON 壞掉」的
  錯誤處理**死在它自己那一行**。
- **用 heredoc 改別的腳本時,分隔字不能與目標檔內的重複。** 目標檔含 `<<'PY'` 而你也用 `<<'PY'`,
  外層會在目標檔的 `PY` 那行提早結束,剩下的內容被當成 shell 指令跑。症狀是
  「編輯看似成功、檔案其實沒變」再加一個莫名其妙的 parse error。

**失敗路徑壞掉的症狀,正好是「印了成功訊息但什麼都沒做」**——與「裝好了」無法從輸出分辨。
所以安裝器的測試至少要有:空環境、重跑、**設定檔壞掉**、以及**既有的同類設定要留著**。

## 交付前:別自己審

**什麼改動要外審**:新 skill、bundled script 的改動,以及**行為類改動**——判準是
「同一個輸入情境,改動前後模型會不會做出不同的事?會,就是行為類」。**用效果定義,別用類別名
定義**,否則人人都能自稱自己只是改措辭。錯字與純措辭的不用:無條件觸發的規則最後會被整條
無視,連帶拖垮它真正想守的那些場景。

要外審的,派一個**沒參與撰寫**的 agent 拿下面那份品質自檢逐條打。判準不必重寫一份
——自審的問題從來不是不知道判準,是知道自己為什麼那樣寫,於是看不見那個假設是錯的。

**bundled script 要另一個視角,而且要求它實跑**——上一節那個「印了成功訊息但什麼都沒做」
純讀 code 分不出來。所以這類 skill 該附 `tests/`:手打過一次的案例寫成 fixture,之後每台
機器、每次改動都跑得到,不必每次找人重新想一遍。**skill 一 push 就傳到所有機器,沒有灰度。**

**有門檻的檢查(行數、佔比、次數),交付前量一次開火率**:對半數改動開火就是噪音、會被
無視;完全不開火等於沒裝。

**你寫的驗證步驟本身要能失敗。** skill 若會叫使用者「裝完驗一下」,問一句:**照這步驟做,
守門瞎掉的時候看得出來嗎?** 好壞兩種情況輸出一樣(都沒輸出、都印 0)的步驟證明不了任何事,
而它拿到的綠燈跟真的驗過長得一模一樣。可判定的形狀只有一種:**造一個該開火的違規,要求它
開火**。本 marketplace 三支 harness skill 都犯過這個錯——「跑一次看看」「audit 印 0 就是
乾淨」「量基準」——三個當初寫下來都很合理。判準寫得好長什麼樣,看 `teammate` 的〈四、收到 idle 通知時〉與〈五、規格中途大改〉。

## 品質自檢(寫完/改完自問)

- description 有沒有同時講「做什麼 + 何時用」?夠不夠 pushy?要不要加負面觸發?
- 清單裡這個 skill 有帶出描述嗎?**空白先查 `skillUsage` 分數與清單預算,別直接怪 YAML**(見上節)。
- body 是否 <500 行?每次都要的才留 body,其餘進 references/assets?
- 有沒有解釋 why,還是在堆 ALL-CAPS MUST?有沒有逐字重複?
- 大改的話,writing-for-agents 的判準逐條過了嗎(沒裝則跳過)?
- 這個 skill 值得這麼多內容嗎,還是為填版而灌水?
- 進階手法(分診/severity/ID/腳本)是這個 skill 真的需要,還是 over-engineer?
- marketplace.json 加了嗎?version bump 了嗎?本機同名去重了嗎?
- `tests/` 下**只放測試腳本**:那個目錄裡的 `*.sh` 會被 pre-commit 無條件執行,輔助腳本放別處。
- 測試腳本**不要讀 stdin**:閘門用 pipe 餵 skill 清單,被測腳本讀一次就會把其餘 skill 吃光,而輸出跟「只有這一個 skill 有改動」同形。
- 有 bundled script 的話,`tests/mutants.sh` 有新增對應的注入嗎?**別靠自己記得**——這條規則寫在這裡也擋不住,本 repo 連犯三次「改了行為沒補測試」,每次都是綠燈。改用跑的:`sh tests/mutants.sh`,每條注入都必須讓 `run.sh` 變紅,pre-commit 也會在你動到該 skill 時自己跑一次。
- skill 裡叫使用者跑的驗證步驟,**在守門瞎掉時會失敗嗎**?(輸出兩種情況相同 = 那步驟是裝飾)

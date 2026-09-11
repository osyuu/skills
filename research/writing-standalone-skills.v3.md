> **已凍結的研究紀錄（2026-09-11），不再維護。** 行為的唯一真相是 `osyuu:writing-standalone-skills`
> （`skills/engineering/writing-standalone-skills/`）。之後 grilling 定下的「產物不依賴 Matt」改動
> （七個替代零件、骨架去依賴、Matt 組合架構僅供理解、寫作期借用規則、乾淨實跑驗證）只在 skill 裡，不在本文件。

# Matt 式 skill 寫法參考（v3）

拿來當基礎，寫出像 `mattpocock-skills` 那樣的 skill。讀這份不需要手邊有 Matt 的 plugin：需要的原文都以引文帶進來了。

**風格與機制是兩回事，分開讀。** 這份用一條行為判準把兩者分開（見 A0）。

| Part | 內容 | 升級成 skill 時的落點【建議】 |
|---|---|---|
| 0 起草流程 | 寫一個新 skill 時依序做的五步，含 baseline 對照 | `SKILL.md` 本體 |
| A 風格 | Matt 的 SKILL.md 讀起來是什麼樣子 | `STYLE.md` |
| B 機制 | 怎麼讓 skill 有強制力，同時不綁死模型的推導；B3 實地失敗；B5 槓桿索引 | `LEVERS.md`、`FAILURES.md` |
| C 理論 | Matt 在 `writing-for-agents` 裡給這些做法取的名字 | `theory/`（見附錄 P） |
| D 架構 | invocation、skill 之間怎麼接、設定、生命週期、專案型 skill、產物落點 | `ARCHITECTURE.md`、`PROJECT-SKILLS.md` |
| E Template | template 本身怎麼寫 | `SHAPES.md` |
| F 零件與骨架 | 可組合的零件、組好的骨架、一份真實 skill 的走讀 | `SHAPES.md` |
| 附錄 | G 已知坑、K 篇幅參照、P 待決事項、S 來源與覆蓋、T 測試協定與本輪驗證 | 各自一檔或併入上面；T1 併入 `SKILL.md` 指過去的 `TESTING.md` |

**起草時先只讀 Part 0。** 其他各 Part 是 Part 0 指過去的參考，走到那一步再查；附錄 G、K、P、S、T 不必先讀。

---

## 0. 標記與引用規則

**引文**：Matt 那邊的文字一律照原文以英文引用，附出處路徑。引文中的粗體不保證與原文一致（有些是我加的強調）。

**出處分三級，份量不同**：

| 出處 | 是什麼 | 怎麼讀 |
|---|---|---|
| `skills/**/SKILL.md` 與同目錄的旁檔 | skill 本身，模型實際讀到的指令 | 一手、操作性 |
| `CHANGELOG.md`、`.changeset/`、`.out-of-scope/`、`.agents/`、repo 根的 `CLAUDE.md` | Matt 的決策紀錄與 repo 規範 | 一手、說明「為什麼」 |
| `docs/` 下的說明頁 | 給人看的整理 | **二手**：依規範不署名（「a quoted reply: all of it goes」，`.agents/writing-docs.md`），會引用使用者的話，可能落後於 SKILL.md（實例見附錄 G） |

**引用規則**：只寫 skill 名（例如「（grilling）」）的，出自那個 skill 的 SKILL.md 或它的旁檔；其他一律寫路徑。路徑以 `skills/` 為根，除非以 `docs/`、`.agents/`、`.changeset/`、`.out-of-scope/` 或 repo 根目錄檔名開頭。

**標籤**：
- 沒有標籤的敘述，是從原文整理出來的。
- **【推論】**：我從多處歸納、Matt 沒有明說的規則。
- **【建議】**：我的建議，不是 Matt 的做法。
- 一條做法只有一個出處時，它是「一個示範過的動作」，不是 Matt 的定律。證據列在每條旁邊，讀者自己看得出有幾處。
- **本輪驗證**：這份文件的作者群自己實跑、自己評審得到的證據，不是 Matt 的東西。括號裡的檔名（`judge/verdict.md`、`build-*/notes.md`）是驗證工作區裡的原始紀錄，讀者手上不會有，內容摘要在附錄 T2。都是 n=1。

**Negative Space、`_Avoid_` 這類 Matt 現行文字裡已經不在的概念**，會明說「現行版沒有」，並說明為什麼仍然收在這裡。

**編號**：B1、B2 的條目沿用 v1 的編號，讓舊的交叉引用還對得上。v2 新增的條目接在最大號之後（B1-28～30、B2-34～35），放在主題相近的位置，所以編號不連續。v3 沒有新增 B1、B2 編號；新的規則放在 B4-0 與 B4 的小節裡。

來源版本、讀了什麼沒讀什麼、這份經過誰審，在附錄 S。

---

# Part 0　起草流程【建議】

這一整個 Part 是我的建議，不是 Matt 的做法。Matt 自己的 `writing-for-agents` 是純參考、沒有步驟（「Reference for writing any document an agent consumes」）；他也把舊的流程型 skill `write-a-skill` 換成了參考型（CHANGELOG 1.0.0）。
這裡仍然寫成步驟，理由是 Matt 自己對參考型 skill 的診斷：「a skill with no process and no stopping rule will improvise one if you point a session at it and say "go."」（`docs/engineering/codebase-design.md`）。寫 skill 是一件要產出東西的工作，會被人拿來「go」。
反例也要知道：`handoff` 產出一份文件，全文五句約束、沒有步驟，因為那份產物小、一次寫完。步驟可以放在參考文件裡：「The two mix freely: all steps (a recipe), all reference (a review's rules, this skill), or both.」（`writing-for-agents/SKILL.md`）。

步驟的數量不是重點。**必須留下的是三件事：第 1 步的關卡、第 3 步「綁在證據上」、最後那條只針對草稿本身的完成條件。**

**怕規則寫多了，又回到綁死推導？**【推論】本輪驗證（附錄 T2；一次、一位評審，評分標準本身對準證據綁定）指向的做法：**綁「什麼算證據」，不綁「怎麼想」。**
- 要求一個可檢查產物的輸出欄位，會逼出真的探索，而且不規定步驟。但欄位也決定了找什麼：本輪 X、Z 都沒找到 Y 用 sub-agent 走訪抓到的兩條 bug。給溢出一個家（Also noticed）接得住一部分。
- 會把推理拉走的，是規定思考形狀的東西：蓋過 repo 文件化決定的原則、版面規則、用修法當標題。詞彙本身不在此列：只鎖程式形狀的詞，repo 自己的詞與文件化的決定優先（B1-11）。
- 不管哪一種，只在沒有 skill 的 agent **實際出錯**的地方綁（例外見第 1 步）。

規則與證據在 B4-0。

### 1. 說出預設，並用一次 baseline 確認（這是關卡）

說出：一個 agent 拿到這件工作、**沒有這個 skill** 時會怎麼做，會往哪個方向錯。

- 例：切票時切太細（「the model defaults to atomic units」，`docs/engineering/to-tickets.md`）；讀程式碼猜原因而不先建回饋迴圈（diagnosing-bugs）；替使用者回答自己的問題（grilling）；把「寫進 `CONTEXT.md`」讀成「什麼都寫進去」（`docs/engineering/domain-modeling.md`）。
- 沒有實地回報時，從任務本身推出來的只是假設。**把同一件工作交給沒有這個 skill 的 agent 跑一次**（附錄 T1），看它實際在哪裡錯。
- 本輪驗證（附錄 T2，一個 fixture、跑一次）：推出來的預設在 baseline 裡**沒有出現**。baseline 與 with-skill 唯一的差別，是兩邊互斥時自己選了一邊；那正是 Matt 的 resolving-merge-conflicts 要求的（B4）。算不算「錯」，取決於你要的行為，而那本身是個決定（附錄 P5）。先跑的話，你會先面對這個決定，而不是把關卡放在 baseline 已經做對的步驟。
- **Done when** 你寫得出 baseline 在哪裡錯、錯成什麼樣子；跑不了時，明說「推的，沒驗」和原因。
- baseline 在某一部分做對了，那一部分就不綁。整件都做對了，這個 skill 可能整份是 no-op（C8 的測試套在整個 skill 上）：停下來，問要不要寫。
- 例外：B4「該綁」第 1、2 條（下游要一致的形狀、不可逆或對外的動作）不看 baseline。跑一次做對，不代表每次都做對，而這兩類錯一次就太貴。

這句話**不寫成開頭**。它決定的是要綁什麼。【推論】它和開頭的關係：開頭有 leading word 時，那個詞說的是這個預設的正向解答。
- **tracer bullet** 對的是「一次切一層」：「That is the constraint that makes it behave differently from the obvious way to split work, which is to cut one layer at a time」（`docs/engineering/to-tickets.md`）。
- **relentlessly** 對的是「問兩三題就停」（grilling 開頭「Interview the user relentlessly」；B3「模型預設的方向」）。
- 預設本身在 skill 裡**最多再出現一次**：
  - 在它發生的那道關卡上（diagnosing-bugs：「stop: jumping straight to a hypothesis is the exact failure this skill prevents.」），寫成看得見的動作；
  - 或者作為唯一一條重述的 anti-pattern（tdd 的 Horizontal slicing，見 B4）。
- 沒有 leading word 的開頭（research、handoff）不受這條影響。

### 2. 決定誰叫得到它、用哪些零件

- invocation 用 SKILL-MECHANICS 的判準：「Pick model-invocation only when the agent must reach the skill on its own, or another skill must.」（D1）
- 零件從 Part F 挑：開頭、關卡、分流、template、格式檔、別名、sub-agent brief、狀態工作區、週期型的跨次紀錄。
- 要不要有步驟：
  - 產物大、要多輪、後面的步驟會誘使模型趕進度，就寫步驟（C5）。
  - 產物小、一次寫完，就寫成幾句約束（handoff）。
  - 步驟要重複時（例如每停一次就回到第 1 步），直接寫 `go back to step 1`（【建議】的寫法）。

### 3. 只綁 baseline 出錯的地方，而且綁在證據上

- **一個 leading word 承載那個行為**（A3、C6）。有幾個候選時，選能把模糊的關卡變成可觀察狀態的那一個（C6：「"a loop you believe in" → _red_」）。
- **關卡設在 baseline 出錯的那一步**，完成條件寫成可檢查的狀態（B1-1～4）。
- **關卡要的證據，要在產物裡有一個欄位**。產出是發現或候選清單時（盤點、review、診斷），等級要有成立條件，看過但不收的東西要有地方放（B4-0）。
- 下游有人讀產物，就給 template（B1-10、Part E）。
- **每一個綁住的東西都要指得出它防的失敗**：baseline 裡看到的，或實地回報過的。只是推出來的，標「沒驗」。
- 範例為「這一類任務」寫，不照抄某一次（B3「寫法的來源」）。

### 4. 讀空白

逐列走過 B5 的槓桿索引。**每一列的預設答案是「不用，交給 agent 的先驗」**。只有你說得出「不加這個，這個 skill 會怎麼壞」時才加。
這一步的用意是讓每個空白都是選過的（C7 Negative Space），不是把索引當清單照填。

### 5. 對照跑一次，然後修剪

- **with-skill 與 baseline 各跑一次**（附錄 T1）。
  - 行為只該在你綁的地方不同。綁了卻沒差的地方是 no-op 的候選：拿掉，或換掉。
  - 對照跑也可能顯示你綁的步驟比 baseline 自己的做法差；那一段換成 baseline 的做法，或拿掉。
  - 逐句跑不實際（`build-D2/notes.md`）。測試的單位是「一個綁住的東西，對一個 fixture 情境」。
  - 讀稿判斷的 no-op 只是判斷（C8：「settle it by running the document, not by debate」）。沒跑就明說。
- **往下推**只推「部分分支才用到、而且大到值得一次跳轉」的內容（C3、E2）。
- 篇幅對照附錄 K。那是參照，不是目標；多出來的篇幅通常是從哪裡來的，也寫在那裡。
- **冷讀**：找一個沒參與起草的 context（新 session 或 sub-agent），讓它照 agent 的角度讀一遍。同一個 context 審自己，說明頁引過一位讀者的話：「Same context reviewing itself isn't review, it's confirmation bias with a slash command.」（`docs/engineering/code-review.md`，出自讀者）
- **冷讀和對照跑出來的修正，是新寫、沒人審過的字。**
  - 優先換掉或刪掉，不要一條一條往上加。本輪兩份產物都是在冷讀之後才又加長的（`build-C2/notes.md`、`build-D2/notes.md`）。
  - 不要反覆跑到乾淨為止：「There is no convergence guarantee」（`docs/engineering/code-review.md`）。

**Done when**：
- 每一個綁住的東西，都指得出 baseline 裡它防的失敗，或標明「推的，沒驗」；
- 對照跑過一次，或明說沒跑；綁了卻沒差的已經拿掉或標出；
- 每一個步驟都有完成條件（「Every step ends on a completion criterion」，writing-for-agents）；放開的空間，只有在 baseline 或實地回報顯示它在那裡出過錯時，才補一個對準那個失敗的邊界（B4）。

---

# Part A　風格

## A0. 什麼算風格【建議】

**判準**：拿掉這個特徵，skill 的行為不變、只是讀起來不像 Matt，它就是風格，放這裡。拿掉之後行為會變，它就是機制，放 Part B 或 C。
這是 C8 的 no-op 測試套在這份文件自己身上。

兩邊都算的東西（leading word、寫死的問句、硬約束上的粗體），外觀寫在這裡，作用寫在 B 或 C，互相指過去。

Matt 的 skill 會**規定 agent 產出的文風**（例如 HTML 報告「No hedging」）。那不是 SKILL.md 本身的風格，而是對產物形狀的綁定，放在 B1-28。
他給人看的說明頁另有一套寫法規範，放在 D6。**這一 Part 只描述 SKILL.md 本文的樣子。**

## A1. 篇幅與密度

- 短。有好幾份是一行轉交（grill-me、grill-with-docs、wait-what）；一個畫面以內的很常見。
- 長的那幾份，是因為有關卡或內嵌 template，而且把只有部分分支用到的參考推到旁檔。
- 具體參照在附錄 K。**篇幅為什麼會影響行為**是機制，見 B0。

## A2. 開頭的三種形狀

1. **定義 + 粗體 leading word**：
   - 「A prototype is **throwaway code that answers a question**. The question decides the shape.」（prototype）
   - 「Design **deep modules**: a lot of behaviour behind a small interface…」（codebase-design）
   - 「A **wizard** is a bash script that walks a human, step by step, through a manual procedure…」（wizard）
2. **工作陳述**，常帶一句不做什麼：
   - 「This skill takes the current conversation context … and produces a spec. Do NOT interview the user; just synthesize what you already know.」（to-spec）
   - 「Spin up a **background agent** to do the research, so you keep working while it reads.」（research）
   - 「Write a handoff document summarising the current conversation so a fresh agent can continue the work.」（handoff）
   - 「**Your job is only to scope the procedure and author its stages.**」（wizard）
   - 「**Grill the send, not the subject.**」（to-questionnaire）
   - 「## Plan, don't do」（wayfinder 的第一節）
3. **沒有開頭**：resolving-merge-conflicts 第一行就是步驟 1。

「defining constraint」（「the single fact that makes this skill behave differently from the obvious default」）是 Matt 對**說明頁**的規則（`.agents/writing-docs.md`）。有些 SKILL.md 的開頭剛好做到（prototype、to-spec），但它不是 SKILL.md 的通則。它和 Part 0 第 1 步的關係見那一節。

H1 標題可有可無。

## A3. Leading word 的外觀

作用（錨定執行與觸發）見 C6、B2-1。這裡只講它在紙面上長什麼樣子：

- **借模型本來就懂的詞**，第一次出現時粗體並定義，之後不再粗體、只重複這個詞。
- **一個 skill 可以有好幾個 leading word，圍著同一個領域。**
  - to-tickets 有 **tracer bullet**、**blocking edges**、**frontier**、**wide refactor**、**blast radius**、**expand–contract**。
  - wayfinder 從 `decision-mapping` 改名時換成一整套 **destination / fog of war / frontier / the map**：「one coherent leading-word frame … rather than an invented term layered on top」（CHANGELOG）。
  - 【推論】「一個 skill 用一組連貫的比喻」只有這一次改名當證據。to-tickets 那組詞不是同一個比喻，但都在講同一件事（怎麼切工作）。
- **格言可以當 leading phrase**：「Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."」（to-tickets）
- **例外也用自己的 leading word 命名，並放在規則旁邊**：「**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change … whose **blast radius** fans across the whole codebase … sequence it as **expand–contract**.」（to-tickets）。作用見 B2-18。
- **命名聽者的狀態，不是命名輸出**：wait-what 這個名字本身。說明頁：
  > "'Be concise' is an instruction about the agent's output, and the model obeys it by clipping words and losing you further. **Wait** is about *your* state… Naming the *listener* asks for both halves at once: fewer words **and** the context you were missing."
  > （`docs/productivity/wait-what.md`）

  它為什麼有效是機制（B2-22、C6），這裡只記錄命名的方向。
- **重用使用者其他文件裡已經有的詞**：wait-what 的內文刻意用 `CLAUDE.md` 和 `CONTEXT.md` 裡已有的詞：「invoking it is not a new instruction. It is a reminder of one the agent already agreed to.」（`docs/productivity/wait-what.md`）
- **優先用現成的詞**。自造的詞沒有先驗，要付定義的 token；但「Coining your own works if you define it clearly」（`writing-for-agents/SKILL.md`）。

以下三條看起來像用詞，實際上是機制，放在別處：
- 太吸引人的通用詞會被過度觸發 → D1。
- 一詞一義、詞彙鎖死 → B1-11。
- 一個詞被用成兩個意思就立新詞 → B1-11。

## A4. 句型與語氣

- **第二人稱祈使句，對 agent 說話；「the user」用第三人稱。** 例外：wait-what 整份用使用者的口吻寫（「Wait, I don't understand where you've got to here. Re-pitch that…」），因為那是使用者要打出去的話。
- **短句，平實，偶爾鬆散。** 「The fewer seams across the codebase, the better - the ideal number is one.」（to-spec）。
  格言式的警句大多在說明頁和 CHANGELOG 裡，不在 SKILL.md 本文。「The honest limit」「Two honest notes」這種語氣只出現在說明頁（見 D6）。
- **定義用冒號**：`**Seam**: a place where you can alter behaviour without editing in that place`。
- **規則用粗體起頭，後面接理由**：
  - 「**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user.」（tdd/SKILL.md:22）
  - 「**Don't add tests.** A prototype that needs tests is no longer a prototype.」（prototype/LOGIC.md）
- **理由是短從句，貼在規則旁邊**：「avoid specific file paths or code snippets: they go stale fast.」（to-tickets）。獨立的「Why」一節很少，只在結構本身反直覺時才有（code-review 的「## Why two axes」）。
- **粗體用在兩處**：詞第一次定義的地方，以及硬約束（「**never resolve more than one ticket per session**」，wayfinder）。硬約束為什麼要寫重是機制，見 B1-29。
- **全大寫的 NOT 很少**：「Do NOT interview the user」（to-spec）、「Do NOT close or modify any parent issue」「vertical, NOT a horizontal slice」（to-tickets）。
- **冒號多**。Matt 的 repo 禁用 em-dash（`CLAUDE.md`：「never do a blind character substitution」，要改寫成逗號、冒號、句號、括號或連接詞）。結果是冒號特別多，也有幾處留下了空格連字號（handoff「Save to the temporary directory of the user's OS - not the current workspace.」、teach「This is a stateful request - they intend to learn…」），正好是那條規則禁止的「盲換」。這是 Matt repo 的規矩；你的 repo 有自己的語言與標點慣例時，照你的。
- **拼字不統一**：大多是英式（minimise、behaviour），也有美式（behavior、Minimize）。不值得模仿，選一種就好。
- **SKILL.md 本文不寫專案現況、歷史、日期**。【推論】沒有任何原文這樣規定，但 SKILL.md 本文裡看不到「used to」或版本號；歷史放在 CHANGELOG。
  出現過的數字是相對於模型的量（「~150k tokens」，ask-matt；「100K token」，wayfinder）。
  這條的正確說法是「不寫對現況的**斷言**；執行時去**檢查**現況可以」，見 D7。

## A5. 段落、清單、表格各放什麼

- **段落承載條件。** 有人問 ask-matt 為什麼不寫成清單：「What the prose is carrying is the **conditional half**: the branches, where a human decision is expected… A flat checklist drops exactly that.」（`docs/engineering/ask-matt.md`）
- **清單放平行項**：分支、候選做法、反模式。
- **表格放同形重複的東西。** writing-shape 教使用者寫文章時的規則：「If the same shape repeats 3+ times with the same fields, a table. Otherwise prose with bold leads.」（這是它對**產出文章**的規則，Matt 自己的 skill 也大致這樣做。）
- **orchestrator 用編號步驟**：`## Process` 加 `### 1. …`，常在每步後面接 Done when。例：to-tickets、code-review、wizard、setup-matt-pocock-skills、setup-ts-deep-modules（標題叫 `## Steps`），以及只有編號清單的 resolving-merge-conflicts。
- **格式的取捨可以拿去跟人討論**：writing-shape 把「Prose vs. list」「Inline vs. callout」「Table vs. repeated structure」「Quote vs. paraphrase」「Code block vs. inline code」列成跟使用者**當面討論**的取捨。

說明頁的版面規則（分支一律用表格或清單）在 D6。

## A6. 常見的區塊

名稱用這個 skill 自己的詞，沒有固定標題。下表只記區塊的名稱、長相與例子；每種區塊**做什麼**寫在右欄指向的機制條目裡，不在這裡重述。

| 區塊 | 長相 | 例子 | 作用見 |
|---|---|---|---|
| Anti-patterns | 粗體名稱 + 一句理由；有些附 tell（看到什麼就知道中招），有些以正向目標收尾 | tdd、prototype/LOGIC.md、UI.md | B4 anti-pattern 的放法、C7 |
| Rules | 粗體起頭的條列 | 格式檔、prototype「Rules that apply to both」、tdd「Rules of the loop」 | B2-18 |
| Principles / Philosophy | 幾條原則，或一段世界觀 | codebase-design「Principles」、teach「Philosophy」（knowledge / skills / wisdom、fluency vs storage strength） | B2-13 |
| Glossary + `_Avoid_` | `**Term**: 定義. _Avoid_: 同義詞` | codebase-design、CONTEXT-FORMAT、GLOSSARY-FORMAT | B1-11 |
| Relationships | 詞與詞之間的關係 | codebase-design、repo 的 `CONTEXT.md` | B1-11 |
| Rejected framings | 被否決的框架 + 理由 + 改用什麼 | codebase-design | B2-16 |
| Out of scope | 刻意不做的事 | to-spec template、AGENT-BRIEF、`.out-of-scope/`、writing-shape | B1-25 |
| Good / Bad 對照 | 成對，壞例後接理由 | tdd/tests.md、mocking.md、AGENT-BRIEF 的 Bad agent brief 加「This is bad because:」 | A8 |
| Phrasings that fit the style | 直接給示範句 | HTML-REPORT | B1-28 |
| Resuming a previous session | 從產物接續 | triage：「Don't re-ask resolved questions.」 | B2-31 |
| Reference docs | 開頭列出旁邊的參考檔各是什麼 | triage | C3 |
| When this is the right shape | 幾句使用者會說的話，當分支判準 | prototype/LOGIC.md、UI.md | B2-35 |

`_Avoid_` 同義詞清單：Matt 在 #763 把它從 `writing-for-agents` 自己的詞彙表拿掉了（CHANGELOG：「the `_Avoid_` synonym lists … are gone」）。但它仍在 codebase-design、CONTEXT-FORMAT、GLOSSARY-FORMAT 裡，所以仍然是**領域詞彙表**的寫法。

**結構實驗**（`in-progress/writing-*`）：用 XML 標籤把本檔切成 `<what-to-do>` 和 `<supporting-info>` 兩區。
- 【推論】看起來對應 C3 的「步驟」與「參考」，但 Matt 沒有這樣說。
- writing-shape 把它整個迴圈放在 `<supporting-info>` 裡，所以這個對應不乾淨。
- 這仍在 in-progress，Matt 沒說好不好用。

## A7. 檔案與 frontmatter 的外觀

- frontmatter 只用四個欄位：`name`、`description`、`disable-model-invocation`、`argument-hint`。harness 接受的欄位不只這些，是 Matt 選擇只用這幾個（D2 的「不寫死 harness」）。
- description 的兩種寫法，外觀上：model-invoked 是「它是什麼。Use when …」的一長句；user-invoked 是一句給人看的摘要。**description 是觸發機制**，規則全在 D1。
- 旁檔的檔名大小寫**不統一**：
  - 揭露出去的參考檔與格式檔多用大寫：`LOGIC.md`、`UI.md`、`*-FORMAT.md`、`AGENT-BRIEF.md`、`DEEPENING.md`、`HTML-REPORT.md`、`PHASE-BOUNDARIES.md`。
  - 會被複製進使用者 repo 的 seed 與 template 用小寫：`domain.md`、`issue-tracker-*.md`、`triage-labels.md`、`wizard/template.sh`。
  - tdd 的參考檔也是小寫（`tests.md`、`mocking.md`），是例外。
- skill 目錄旁邊有 `agents/openai.yaml`（Codex 用），作用見 D1。

## A8. 範例的外觀

- **Good / Bad 成對，壞例後面列理由**：AGENT-BRIEF 的 Bad agent brief 後接「This is bad because: - No category - Vague description …」。
- **給寫好的完整樣本**：RESOURCES-FORMAT 給重訓書單，OUT-OF-SCOPE 給 dark mode 被拒的整份理由。
- **給示範句**：HTML-REPORT 的「"Pricing leaks across the seam."」「"Deepen: one interface, one place to test."」。
- **程式碼對照**：codebase-design「// Testable」vs「// Hard to test」；tdd/tests.md「// GOOD」vs「// BAD」。
- **寫死的問句，以引號放在本文裡**。
  - to-tickets 列出三個要問使用者的問題（「Does the granularity feel right? (too coarse / too fine)」）。
  - domain-modeling 給 agent 的台詞：「"Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"」
  - 作用見 B2-34。

## A9. 風格核對（查閱用，不是清單）

寫完後可以對照，但不是每條都適用，也不是全部做到才算完。

- 開頭是三種形狀之一（A2）。
- leading word 第一次粗體並定義，之後只重複詞，不重複句子（A3）。
- 祈使句、短句、理由貼在規則旁（A4）。
- 分支和條件在段落裡，平行項在清單裡，同形重複在表格裡（A5）。
- 本文沒有對現況的斷言、歷史、日期（A4、D7）。
- 範例是為這一類任務寫的（B3「寫法的來源」）。

---

# Part B　機制：強制力與推導空間

## B0. Matt 自己的立場

> "the same levers make each one predictable, since **the agent takes the same _process_ every run rather than producing the same output**."
> （`writing-for-agents/SKILL.md`）

> "No instruction makes an agent comply 100% of the time, and **forcing the point harder restricts the agent's creativity for little gain**; the loop is worth running even when it is not followed strictly, because the results are still better overall."
> （`docs/engineering/tdd.md`）

> "Approaches like GSD, BMAD, and Spec-Kit try to help by **owning the process**. But while doing so, they take away your control and make bugs in the process hard to resolve. These skills are designed to be small, easy to adapt, and composable."
> （`README.md`）

> "**natural-language steering is the intended control surface, not a numeric limit**… a model that asks redundant or low-value questions (a prompt-quality issue, not a quantity issue). The fix for the latter belongs in the skill prompt, not in a counter."
> （`.out-of-scope/question-limits.md`，拒絕替 grilling 加題數上限）

> "This is a **prompt-driven skill, not a deterministic script**. Explore, present what you found, confirm with the user, then write."
> （setup-matt-pocock-skills）

**篇幅本身是機制。** 讀者是誰決定了預設動作：

> "You are writing for a reader who has already read everything, so explanation is waste and precision is the entire job."
> "Its default move is deletion, not explanation. Ask an agent to write instructions for another agent and it spends most of its words explaining what the model already knows."
> （`docs/productivity/writing-for-agents.md`）

> "a four-hundred-line concision skill still leaves the model verbose, because **the model reads the volume, not the plea**."
> （`docs/productivity/wait-what.md`）

writing-for-agents 說明頁的驗收之一：「The document gets shorter as it gets better, and you are surprised how little is left.」（`docs/productivity/writing-for-agents.md`）

**【推論】一句話版**：綁住「結果的形狀、關卡、詞彙、不可逆的動作、範圍」，放開「走到那裡的路徑、內容、判斷」。每一個綁住的東西都要對應一個說得出的失敗（Part 0 第 3 步、B4）。

## B1. 綁：強制力從哪來

### 關卡與完成條件

**1. 關卡，不是檢查清單。**

> "The phases are **gates, not a checklist**. Each one refuses to open until something specific is true."
> （`docs/engineering/diagnosing-bugs.md`）

loop-me 對詞彙也說同一件事：「never a checklist」（B2-3）。

**2. 每個階段都是關卡，承重的那一道另外標出來。**
- diagnosing-bugs 開頭就說「Skip phases only when explicitly justified.」。
- 每個階段都有進入條件：Phase 1 要有能變紅的指令；進 Phase 3 要「reproduced **and** minimised」；Phase 6 有「Required before declaring done:」的收尾清單。它的說明頁把每道門列成表。
- 承重的第一道另有兩個標記：
  - 一句「**This is the skill.** Everything else is mechanical.」
  - 做不到時的停止與回報：一節「### When you genuinely cannot build a loop」，內文「Stop and say so explicitly. List what you tried.」；再用一句收死：「No red-capable command, no Phase 2.」

**3. 完成條件寫「什麼必須成立」，不寫「怎麼做到」，而且要有要求量。**

- 「you can name **one command** … that you have **already run at least once**」（diagnosing-bugs）
- 「Done when the file exists and every item the user named in step 2 is covered by a question.」（to-questionnaire）
- 「A workflow spec is done when an implementer agent could build it without asking a single question. Grill until then; nothing is done while a question remains.」（in-progress/loop-me）
- 「Done when **every remaining element is load-bearing**: removing any one of them makes the loop go green.」（diagnosing-bugs 的 minimise）

**4. 你**新建**的檢查，要看它失敗一次。**

> "This is the completion criterion for the whole skill: a config that doesn't fail on a violation is worthless… **Done when:** you have observed a pass, then a fail on the deep import, then a pass again."
> （in-progress/setup-ts-deep-modules）

to-tickets 說明頁對驗收條件的補救：「For each criterion, name the observation that would show it false, and confirm it fails at the commit the implementer starts from.」（`docs/engineering/to-tickets.md`）

【推論】這條適用於 skill 自己建立的設定、檢查、驗收條件。對一道早就存在、而且已知會攔的門禁，再看它紅一次只是儀式。

**5. 綁住提問的順序，答案交給判斷。**

> "Work top to bottom at the boundary. **The first yes wins.** … The questions are not objective: each has taste in it, and the same boundary can go two ways on two days. **The value is in asking them in order**, at the boundary rather than in the middle of the work."
> （ask-matt/PHASE-BOUNDARIES.md）

**6. 關卡的時點也要綁。** 「Make the decision **at** a boundary; mid-phase, continue or split the rest into subagents.」（ask-matt）

**7. 有依賴的問題不放在同一輪。** 「A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.」（grilling）

**8. 在最便宜的地方先失敗。** 「Before going further, confirm the fixed point resolves … and the diff is non-empty. A bad ref or empty diff should fail here, not inside two parallel sub-agents.」（code-review）

**9. 先驗證，再往下游送。**

- 「**Verify the claim.** Before any grilling, check that the claim holds up. For a bug, reproduce it from the reporter's steps.」（triage）
- 跑不了就靜態追蹤：「Don't run it end-to-end yourself: it opens browsers and blocks on human input. Trace it statically instead: every value from step 1 is captured and lands where step 1 said」（wizard）
- 關卡對人也成立：「A quiz is a gate, not a formality」（`docs/productivity/teach.md`）

**30. 讀完整的證據。**
- 「If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments.」（to-tickets）
- 反例在 B3：對整批 issue 跑 triage 時，改用便宜的清單查詢當證據，那個查詢不帶留言，於是已有「已修好」留言的 issue 還是被寫了新 brief（`docs/engineering/triage.md`）。
- 【推論】換一個比較便宜的查詢，等於換了一個證據來源，要先確認它帶齊了你要的欄位。

### 形狀與詞彙

**10. 輸出的形狀用 template 固定：固定框 + 自由區。**

> "The **fixed frame** (`## What it does`, `## When to reach for it`, `## Where it fits`) appears on every page. `## Prerequisites` and the free-form substance sections carry only what this particular skill needs; delete the rest… The single non-negotiable: **surface the skill's leading word / defining idea** (`tight` feedback loop, `deep module`, throwaway-code-answers-a-question, red-green)."
> （`.agents/writing-docs.md`，這是說明頁的 template）

grilling 每一輪問題的格式固定：`❓ **Q1** - **<title>**`、內文、`➡️` 推薦答案。說明頁寫它的用處：「you can answer the whole round by number」（`docs/productivity/grilling.md`）。格式綁死，內容交給模型。

**11. 詞彙鎖死，一詞一義。**
- 「**Use exactly:** module, interface, … **Never substitute:** component, service, unit (for module) …」（HTML-REPORT）
- 「Use these terms exactly: don't substitute "component," "service," "API," or "boundary." Consistent language is the whole point.」（codebase-design）
- **一個詞被用成兩個意思時，立一個新詞並寫進詞彙表**：wayfinder 的票被讀成實作票，於是命名為 **decision ticket**，並記進 repo 的 `CONTEXT.md`（CHANGELOG）。
- 【推論】詞固定了，模型就會用那個詞思考，不必另外規定思考步驟。這是從 C6 延伸的，HTML-REPORT 沒有說鎖詞的理由。
- 【推論】鎖詞彙與原則有代價：
  - 本輪 Y 的 runner 花工夫把草稿裡的詞換成規定詞彙，它的一條原則還蓋過了 repo 寫明的決定（`judge/verdict.md`）。
  - 所以鎖詞只鎖描述**程式形狀**的詞；領域詞與 repo 文件已經命名的結構，用 repo 自己的詞。Z 的寫法：「use the repo's words」。
  - 衝突時的順序見 B4。

**12. 用反向定義管住產物會長成什麼。**

> "`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. **It is a glossary and nothing else.**"
> （domain-modeling）

沒有這句的後果見 B3（`CONTEXT.md` 長到幾千行）。

**13. 不變式讓下游簡單。** 「Every triaged issue should carry exactly one category role and one state role.」
說明頁：「the "exactly one state role" invariant is what keeps the queries simple.」（`docs/engineering/triage.md`）

**28. 產物的文風也綁。** 這些是 Matt 寫給 agent、規定它**產出物**怎麼寫的句子，不是 SKILL.md 本文的風格：

- 「No hedging, no throat-clearing, no "it's worth noting that…". If a sentence could be a bullet, make it a bullet. If a bullet could be cut, cut it.」（improve-codebase-architecture/HTML-REPORT.md）
- 「Be opinionated: the user wants a strong read, not a menu.」（codebase-design/DESIGN-IT-TWICE.md，對推薦的要求）
- 「The file should be written in a relaxed, readable style, more like a short design document than a database entry.」（triage/OUT-OF-SCOPE.md）
- **給人讀的敘述用名字，給指令用的地方用編號。**
  - wayfinder 對它**對人說的話**的規定：「refer to it by that name, never by a bare id, number, or slug. A wall of `#42, #43, #44` is illegible」。
  - 本地票的檔名用 `<NN>-<slug>.md`，說明頁的理由是：「The `NN` prefix is a real ticket ID, so `/implement 03` works instead of retyping a long title.」（`docs/engineering/to-tickets.md`）
  - 兩條不衝突：編號給機器與指令，名字給人讀。
- 直接給示範句，不描述語氣：HTML-REPORT 的「Phrasings that fit the style」。

**29. 用字重，堵住寬鬆解讀。**
- 說明頁的說法：「An agent running `grilling` that answers its own decisions has **broken the skill, not interpreted it liberally**.」（`docs/productivity/grilling.md`）
- SKILL.md 本文裡的實際寫法是在硬約束上用 never / always 與粗體：
  - 「**never resolve more than one ticket per session**」（wayfinder）
  - 「Always resolve; never `--abort`」（resolving-merge-conflicts）
  - 「stop: jumping straight to a hypothesis is the exact failure this skill prevents.」（diagnosing-bugs）

### 分類與分軸

**14. 用分類讓行為自己推出來。**

- wayfinder 每張票分成 **HITL** 或 **AFK**：「"wait for the human" **falls out of the label** … (This fixes students' reports of /wayfinder grilling itself instead of the human.)」（CHANGELOG）
- grilling 把 **facts** 與 **decisions** 分開。原本籠統的「能查就去查」，被別的 skill 包起來後被讀成「決定也可以自己做」，拆成兩類才修好（CHANGELOG）。
- domain-modeling 兩種產物兩道門檻：`CONTEXT.md` 只收詞，ADR 要三條件全中。
- 建議強度分三級 `Strong` / `Worth exploring` / `Speculative`（improve-codebase-architecture）。說明頁講的用途是防線：這個 skill 天生傾向產出 finding，強度分級是讓它能說「這個不太值得做」的地方（`docs/engineering/improve-codebase-architecture.md`）。原檔只列三個名字、沒有寫每一級的成立條件；本輪驗證裡，刪兩個死檔拿到的 Strong 和購買流程一樣（B4-0）。等級要綁得住，每一級都要寫成立條件。

**15. 分軸評審，不合併、不重排。**

> "Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings… Don't pick a single winner across axes: that's the reranking the separation exists to prevent."
> （code-review）

原因：「A change can pass one axis and fail the other… Reporting them separately stops one axis from masking the other.」兩軸各跑一個 sub-agent，「so they don't pollute each other's context」。

**16. 區分硬性違規與判斷，並規定誰覆寫誰。**

> "Two binding rules keep it safe: a documented repo standard overrides the baseline, and every smell is reported as a judgement call, never a hard violation."
> （CHANGELOG，code-review 的 smell baseline）

**17. 每個發現都要附出處，才能被檢查。**

> "That every finding is required to carry one (a standards rule, a smell plus its hunk, or a spec line) is what makes this checkable at all."
> （`docs/engineering/code-review.md`）

### 綁在措辭之外

**18. 用檔案、程式或門禁綁；注意力不在那個詞上時尤其要這樣。**

**措辭有兩種綁不住的情況**：一是試過了沒用，二是失敗發生時 agent 根本沒在想那個詞。
- description 或一行 pointer 只有在 agent 已經想到那個詞時才會觸發（C1）。
- 失敗若發生在 agent 專心做別的事的時候，就得用跟情境綁定的觸發：lint、CI、git hook，或常駐檔裡的一行指標。例如寫一行寫死的 UI 字串時，agent 想的是 UI，不是 i18n。

證據（各自的性質不同）：

- **一致性本身就是目的，所以一開始就放進檔案**：wizard 把 UX 全放進 `template.sh`：「The library above the `STAGES` marker is identical in every wizard; **that consistency is the point**: never hand-edit it.」CHANGELOG 的說法是「The delightful UX is pre-solved by the bundled `template.sh`」。這不是措辭失敗後的補救，而是一開始就這樣設計。
- **措辭試過沒用（回報，尚未修）**：teach 的測驗正確答案總在第一個選項。一位貢獻者試了指令層的修法，在九堂課裡正確答案 33 次都落在 A，於是說明頁指向「a shuffling quiz component in `assets/` as the real fix **rather than better wording**」（`docs/productivity/teach.md`）。說明頁寫明「still unfixed」。
- **門禁 + 常駐指標**：setup-ts-deep-modules 把模組邊界交給 dependency-cruiser 的 lint 規則，再在 `CLAUDE.md`/`AGENTS.md` 加一行指過去：「This is what makes an agent discover the boundary rule instead of tripping over it.」
- **harness 綁定的強制**：`git-guardrails-claude-code`「Sets up a PreToolUse hook that intercepts and blocks dangerous git commands」；`setup-pre-commit` 裝 Husky git hook 跑 typecheck 與 test；`claude-handoff` 直接呼叫 `claude --bg`。

【推論】升級順序：措辭 → template 或檔案 → script → lint / CI / hook。Matt 沒有寫出這個順序。

**harness 中立只約束要跨 harness 發佈的 skill。**
- Matt 在上架 skill 的操作文字裡拿掉 harness 工具名，是為了「so the step is followable on Codex and other harnesses」（CHANGELOG 1.2.3）。
- 他也用 `agents/openai.yaml` 這種各 harness 各一份的旁檔達成中立（D1）。
- 綁死某個 harness 的 skill（上面兩個 hook 例子）以那個 harness 命名，放在 `misc/` 或 `in-progress/`，不進上架集合。

跨 harness 的強制層是 lint / CI 與 git hook，再加上 `AGENTS.md`/`CLAUDE.md` 裡指向規則的一行（那一行每一輪都付 context load）。
【推論】專案型 skill 的 harness 由 repo 決定，可以用那個 harness 的 path-scoped rule 或 hook（D7）。

**19. 留下機械可清理的記號。**

> "**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die."
> （diagnosing-bugs）

### 人與外部

**20. 不可逆或寫出去之前，停下來等人。**

- 「Check with the user that these seams match their expectations.」（to-spec）
- 「Iterate until the user approves the breakdown.」（to-tickets）
- 「Do not act on it until the user confirms you have reached a shared understanding.」（grilling）
- 「`confirm` before any irreversible action.」（wizard）
- 「Confirm what you're about to do (role changes, comment, close), then act.」（triage 的 quick override）

什麼時候停、什麼時候照預設繼續，判準在 B4。

**21. 對外的產出要標記來源。** 「Every comment or issue posted to the issue tracker during triage **must** start with this disclaimer: `> *This was generated by AI during triage.*`」（triage）
【推論】triage 加，to-tickets 不加。差別在：triage 寫進別人提的 issue 與對話裡，別人會把它當成人寫的；to-tickets 的票是使用者批准過的切法。

**22. 敏感資料先處理。** diagnosing-bugs 開頭就是「## Redact」：「**Redact every secret first**… Build loops against env vars, so the credential stays in the environment rather than in what you show.」

**23. 不覆蓋使用者既有的東西。**
- 「If one exists, do **not** overwrite it: merge the four rules and the options in, and tell the user what you added.」（setup-ts-deep-modules）
- 「Never create `AGENTS.md` when `CLAUDE.md` already exists」「Don't overwrite user edits to the surrounding sections.」（setup-matt-pocock-skills）

**24. 不編造。**

- 「Where you don't actually know the current UI or the exact command, say so and ask the user or check the docs: **never invent steps that may not exist**.」（wizard）
- 「Do **not** invent new behaviour.」（resolving-merge-conflicts）
- 「Anything the spec asserts that you never actually said is a defect.」（`docs/engineering/to-spec.md`）

### 範圍與尺寸

**25. 範圍邊界。**

AGENT-BRIEF 的一個原則標題是「Explicit scope boundaries」，底下一段：
> "State what is out of scope. This prevents the agent from gold-plating or making assumptions about adjacent features."
> （triage/AGENT-BRIEF.md）

skill 本身也要說它刻意不做什麼：
- 「Two things it deliberately isn't. It isn't **branching**… And it isn't **multi-recipient**」（`docs/productivity/to-questionnaire.md`）
- 「Imposing phases, outlines, or article structure is out of scope here.」（writing-fragments）

**26. 工作單位以一個 context window 為尺寸。**

- 「Each slice is sized to fit in a single fresh context window」（to-tickets）
- 「Its body is the question, sized to one 100K token agent session」「**never resolve more than one ticket per session**, with the exception of research tickets」（wayfinder）
- 「Keep steps 1–3 in **one unbroken context window**」（ask-matt）

Matt 只給了單位，**沒有給怎麼估**：沒有任何原文說「看到什麼就知道一張票超過一個 session」。這是原文的空白。

### 跨 skill

**27. 透過產物把約束傳給下一個 skill。**

> "Those agreed seams then travel. [tdd] works only at pre-agreed seams, and [code-review] reviews the diff against the spec, so a seam nobody agreed to shows up as a review finding. **The binding is indirect: it runs through this document**."
> （`docs/engineering/to-spec.md`）

## B2. 放：推導空間怎麼留

### 用詞代替步驟

**1. 用 leading word 取代「重述模型已經知道的迴圈」的步驟。** tdd 原本有逐步的 Workflow 和每輪檢查清單，後來整段刪掉：

> "The red → green → refactor loop is anchored by leading words the model already holds, so the step-by-step Workflow was largely restating the loop."
> （CHANGELOG）

wait-what 整份只有一段話：「**The mechanism is the name.** Concision skills fail by growing… so this one is a single precise leading word and nothing else.」（CHANGELOG）

**範圍**：這條拿掉的是「把模型早就會的迴圈再逐步寫一次」的步驟。**orchestrator 仍然用編號步驟**，每步接 Done when：to-tickets、code-review、wizard、setup-matt-pocock-skills、setup-ts-deep-modules、resolving-merge-conflicts。
Matt 自己在 #469 把 to-issues 拆成「a lean **Process** and a **Reference** section」（CHANGELOG）。

**2. 寫行為，不寫程序：限於會擱置很久的 brief 與票。**

AGENT-BRIEF 的另一個原則標題是「Behavioral, not procedural」：
> "Describe **what** the system should do, not **how** to implement it. The agent will explore the codebase fresh and make its own implementation decisions."
> （triage/AGENT-BRIEF.md）

它的理由在同一份檔的另一個原則「Durability over precision」：「The issue may sit in `ready-for-agent` for days or weeks. The codebase will change in the meantime.」
**這條管的是給未來 agent 的 brief，不是 SKILL.md 本文**。SKILL.md 本文常常是明確的程序（見上一條）。

**3. 詞彙是工具，不是檢查清單。**

> "A shared language, reached for only when a workflow calls for it: **never a checklist**. **Mandate nothing structural**: a workflow needs no AI, no checkpoint, and no schedule unless the grilling shows it does."
> （in-progress/loop-me）

**4. 把行為命名成「動作」，而不是步驟。**
- domain-modeling 的「During the session」有六個小節：**Challenge against the glossary**、**Sharpen fuzzy language**、**Discuss concrete scenarios**、**Cross-reference with code**、**Update CONTEXT.md inline**、**Offer ADRs sparingly**。
- 前四個是對話中隨時可用的動作，後兩個是寫入的時機與門檻。什麼時候用哪個，交給模型判斷。

### 給方向，不給路線

**5. 引導式提問取代檢查清單。**

- 「Don't follow rigid heuristics; explore organically and note where you experience friction:」後面接五個問句（improve-codebase-architecture）
- 「When designing an interface, ask: Can I reduce the number of methods? …」（codebase-design）
- writing-shape 的「Specific moves to keep using:」：「"If I cut this, what breaks?"」「"This sentence is doing two jobs: split it or pick one."」

**6. 給選單與選擇判準，並要求多樣。**

- 「The right shape depends on the question: … **Pick whichever shape best fits the question being asked, not whichever is easiest to wire to a page.**」（prototype/LOGIC.md）
- 「Pick the pattern that fits the candidate. Mix them. Don't make every diagram look the same. **Variety is part of the point.**」（HTML-REPORT）

**7. 偏好排序，最後一招要先自問。**

- diagnosing-bugs 十種回饋迴圈「in roughly this order」，最後一種是「HITL bash script. Last resort.」
- UI 原型的兩種形狀：「strongly prefer sub-shape A」；B 是「last resort」，而且「Before committing to sub-shape B, sanity-check: is there really no existing page this could be embedded in?」（prototype/UI.md）
- **有序的查找鏈，最後一步是問人**：code-review 找 spec 的順序是 commit 裡的 issue 引用 → 使用者傳的路徑 → `docs/`、`specs/`、`.scratch/` 下符合分支名的檔 →「If nothing is found, ask the user where the spec is.」

**8. 預設值加上限。** 「Default to **3 variants**. More than 5 stops being radically different and starts being noise, so cap there.」（prototype/UI.md）

**9. 先縮範圍再探索。** 「**Scope before you scan: YAGNI.** … put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look」（improve-codebase-architecture）

**10. 不需要這個 skill 時，提早退出。**

- 「**If this surfaces no fog** (the way to the destination is already clear, the whole journey small enough for one session), you don't need a map. Stop and ask the user how they'd like to proceed.」（wayfinder）
- 說明頁把「不用這個 skill」寫成一列：
  - to-tickets：「if the whole change fits in one context window, you don't need this skill at all. Go straight to implement」（`docs/engineering/to-tickets.md`）
  - ask-matt 說明頁的表格裡，「A skill you have already picked」那一列的回答是「Nothing useful. Invoke that skill directly.」（`docs/engineering/ask-matt.md`）
- diagnosing-bugs 被回報對簡單問題過度啟動，說明頁說接受的修法是「start with a lighter approach and graduate to the heavier one only where the problem warrants it」，但「that change has not landed」（`docs/engineering/diagnosing-bugs.md`）。

**11. 決定要能回溯到一個明說的目的。**

- 「Every teaching decision (what to teach next, which resources to surface, which exercises to design) should trace back to this document.」（teach/MISSION-FORMAT.md）
- wayfinder 的 **destination**：「naming it is the first act of charting: it shapes every ticket.」
- prototype：「The question decides the shape.」

### 讓模型自己檢查

**12. 自我檢驗。** 給一個模型自己能跑的測試，而不是一條規則：

- 「If the diagram needs a paragraph to be understood, redraw the diagram.」（HTML-REPORT）
- 「If a "beat" needs five paragraphs and three subheadings, it's not a beat; it's two beats glued together. Split it.」（writing-beats）
- 「If `MISSION.md` runs past a screen, it has stopped being a compass and started being a plan.」（teach/MISSION-FORMAT.md）
- 「If you cannot state the prediction, the hypothesis is a vibe: discard or sharpen it.」（diagnosing-bugs）

**13. 判斷測試取代規則。**

- **deletion test**：「Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.」（codebase-design）
- **Fog or ticket?**「The test is whether you can state the question precisely now, _not_ whether you can answer it now.」（wayfinder）
- ADR 的三條判準，後面附「### What qualifies」的例子讓模型類推（domain-modeling/ADR-FORMAT.md）。反面例子「### What does _not_ qualify」出現在 teach/LEARNING-RECORD-FORMAT.md。
- 「"Mainstream" is a judgment call, not a numeric bar… The rule is: would a typical engineer recognise this tool…?」（`.out-of-scope/mainstream-issue-trackers-only.md`）

**14. 按概念比對，不按字面比對。**
- 「Matching is by concept similarity, not keyword: "night theme" matches `dark-mode.md`」（triage/OUT-OF-SCOPE.md）
- redundancy check：「search for an existing implementation of the requested behavior **by domain concept** (not just the request's wording)」（triage）

**15. 找不到也算結果。** 「**If no correct seam exists, that itself is the finding.** Note it.」（diagnosing-bugs）

### 擋錯誤方向、逼出分歧

**16. 列出被否決的框架。**

> "## Rejected framings
> - **Depth as ratio of implementation-lines to interface-lines** (Ousterhout): rewards padding the implementation. We use depth-as-leverage instead.
> - **"Interface" as the TypeScript `interface` keyword or a class's public methods**: too narrow: interface here includes every fact a caller must know.
> - **"Boundary"**: overloaded with DDD's bounded context. Say **seam** or **interface**."
> （codebase-design）

**17. 刻意逼出分歧。**

- DESIGN-IT-TWICE 給每個 sub-agent **不同的約束**（最小介面 / 最大彈性 / 最常見呼叫者 / ports & adapters），產出格式固定成五項。
- 「Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.」（diagnosing-bugs）
- 「Variants must be **structurally different** … If two drafts come out too similar, redo one with explicit "do not use a card grid" guidance.」（prototype/UI.md）
- writing-beats、writing-shape 每一步提 2–3 個候選開頭或段落，讓人選。

**18. 規則 + 理由 + 例外。**

理由讓模型能推廣到沒列出的情況，例外防止規則被硬套：

> "avoid specific file paths or code snippets: they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can … inline it."
> （to-tickets）

**例外大到一定程度時，用自己的 leading word 命名，並放在規則旁邊。**
- to-tickets 的垂直切片遇到「一次機械改動就讓幾千個呼叫點同時壞掉」的情況，於是命名為 **wide refactor**、**blast radius**，改用 **expand–contract** 排序，並就放在 `<vertical-slice-rules>` 下面。
- CHANGELOG #469 記錄這是從回報加進來的。
- 成長的模式是：回報 → 命名那個情況 → 例外與規則放在一起。

**19. 最小必填，其餘看價值。**

- 「That's it. An ADR can be a single paragraph. The value is in recording *that* a decision was made and *why*, not in filling out sections.」（ADR-FORMAT）
- 「Only include these when they add genuine value. Most ADRs won't need them.」（ADR-FORMAT）
- 說明頁規範對 Common questions 的要求：「**the count stays honest to the evidence**… Padding a thin skill out to match a rich one is how the section fills with questions nobody has」（`.agents/writing-docs.md`）。
- 「The article ends when the journey is complete, not when the pile is empty.」（writing-beats）

### 模糊與預設

**20. 有預設，並要求說出假設。** 「If the question is genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code … and **state the assumption** at the top of the prototype.」（prototype）

**21. 把要回答的問題寫在看得到的地方，事後可以檢查。**

- 「make the question explicit so it can be checked later, whether the user is watching now or returning to it AFK.」（prototype/LOGIC.md）
- 「Write down the plan in one line… This works whether the user is here to push back or not.」（prototype/UI.md）

**22. 故意留模糊，把判斷交給模型。** 「The skill says re-pitch **that**, not "that last message". What lost you is usually bigger than one paragraph, so **the agent decides how far back to go**.」（`docs/productivity/wait-what.md`）

### 自然語言是控制面

**23. 用自然語言叫，不用旗標或模式。**

- 「The maintainer invokes `/triage` and describes what they want in natural language. **Interpret the request and act.**」後面只給四個例句（triage）。
- 拒絕替 setup 加 verify 模式：「The skill is prompt-driven, so the maintainer can scope it to a verification pass ("don't rewrite anything, just check…") without needing a separate code path.」（`.out-of-scope/setup-skill-verify-mode.md`）
- 偏好不進 skill：「skills stay opinionated: *"Config is death."* Preferences belong in your `CLAUDE.md` as plain instructions」（`docs/engineering/setup-matt-pocock-skills.md`）

### 跟人互動

**24. 推薦答案放第一個，已經確定的就不問。**

> "Lead each section with the recommended answer so the user can accept it in a word. Give a one-line explainer only when the choice genuinely branches; skip the section entirely when exploration already settled it"
> （setup-matt-pocock-skills）

grilling 每題也附「➡️ <your recommended answer>」。

**25. 事實歸 agent，決定歸人；查事實不擋住提問。**

> "Finding _facts_ is your job, never the user's… Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait."
> （grilling）

「Show this to the user, then immediately proceed to Step 2. The user reads and thinks while the sub-agents work in parallel.」（DESIGN-IT-TWICE）

讀資料的苦工派給背景 agent，主 session 的 context 保持乾淨：「it runs in the background so your session keeps its context clean」（`docs/engineering/research.md`）。

**26. 檢查點往後推，給人看摘要不看原稿。**

> "**Push right**: defer the checkpoint as far as it will go. Do maximal work before involving the human, so they are asked once, late, with everything prepared. **Brief**: … a tight, decision-ready summary …, never the raw output. The user reads a brief, not a draft."
> （in-progress/loop-me）

**27. 允許說不知道。** 「Partial answers and "I don't know" are useful: flag anything you're unsure of rather than skipping it.」（to-questionnaire 的 template）

**28. 使用者不在時的預設。** 「Show the ranked list to the user before testing… Don't block on it; proceed with your ranking if the user is AFK.」（diagnosing-bugs）
這條與 B1-20、B2-25 什麼時候誰贏，判準在 B4。

**34. 在人要回答的地方，直接寫出那句問題。**

Matt 不描述「用什麼語氣問」，而是把問句寫死在 skill 裡。問句本身就把人的注意力導向已知的失敗：

- to-tickets 的 quiz：
  - 「Does the granularity feel right? (too coarse / too fine)」
  - 「Are the blocking edges correct: does each ticket only depend on tickets that genuinely gate it?」
  - 「Should any tickets be merged or split further?」
  - 它的說明頁說：「Over-decomposition is the most reported friction on this skill… The quiz step exists for exactly this」（`docs/engineering/to-tickets.md`）。問句對準的正是模型的預設方向。
- tdd：「Ask: "What's the public interface, and which seams should we test?"」
- domain-modeling：
  - 「"Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"」
  - 「"You're saying 'account': do you mean the Customer or the User? Those are different things."」
- triage/OUT-OF-SCOPE.md：「"This is similar to `.out-of-scope/dark-mode.md`. We rejected this before because [reason]. Do you still feel the same way?"」
- improve-codebase-architecture：「_"Want me to record this as an ADR so future architecture reviews don't re-suggest it?"_」

**35. 用幾句使用者會說的話當分支判準。**
- prototype/LOGIC.md 的「## When this is the right shape」列出「"I'm not sure if this state machine handles the edge case where X then Y."」等四句。
- 最後一句指向另一條分支：「If the question is "what should this look like," this is the wrong branch. Use [UI.md](UI.md).」
- 模型比對的是情境，不是關鍵字（對照 B2-14）。

### 狀態與節奏

**29. 當下寫入，不要最後彙整。**

> "When a term is resolved, update `CONTEXT.md` right there. **Don't batch these up**: capture them as they happen."
> （domain-modeling）

說明頁：「the batched version is a summary of a session, and the inline version is the session's actual output.」（`docs/engineering/domain-modeling.md`）

**30. 一次一步，每次寫之前重讀檔案。** 「Append one beat at a time. Never write ahead.」「Re-read the article file from disk before every write. Preserve user edits absolutely.」（writing-beats）

**31. 從產物接續，不從記憶接續。**
- 「If prior triage notes exist…, read them, check whether the reporter has answered any outstanding questions… Don't re-ask resolved questions.」（triage）
- 「The folder is the continuity, not the conversation.」（`docs/productivity/teach.md`）

**32. 延遲建立。**
- 「Create files lazily: only when you have something to write.」（domain-modeling）
- 「If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront.」（setup-matt-pocock-skills 的 domain.md seed）

**33. 用一手資料，不用模型記憶。**
- 「Never trust your parametric knowledge.」（teach）
- 「Follow every claim back to the source that owns it.」（research）

## B3. 兩個方向的失敗：實地回報

說明頁的 Common questions 記錄了使用者實際遇到的問題。**下面的分類是我做的**【推論】，原文沒有這樣分。說明頁是二手整理，引到的原話有些出自使用者。

### 放太開

| 症狀 | 成因 | 出處 |
|---|---|---|
| 指向一個 reference skill 說「go」，燒掉 10 萬 token 重新設計沒被要求的東西 | 「a skill with no process and no stopping rule will improvise one」；而且 driver skill 有的護欄（checkpoint、一次一題、不自動前進）它都沒有。修法是指定一個 driver skill，讓 reference 墊在底下（issue #449，仍開著） | `docs/engineering/codebase-design.md` |
| 研究太深，或廣但漏掉關鍵細節 | 「There is no stopping criterion in the skill」 | `docs/engineering/research.md` |
| sub-agent 又叫同一個 skill，一路長到 50 多個 agent；research 一次任務三份重疊、約 45 萬 token | 「The Standards and Spec prompts do not forbid delegation」；research 派出的是不限類型的 agent | `docs/engineering/code-review.md`、`docs/engineering/research.md`（#530） |
| agent 在 wayfinder 的 Notes 寫下「this map carries execution」，之後拿它當自己的許可去改線上伺服器 | 「the constraint and its exemption live in the same file the constrained party owns」 | `docs/engineering/wayfinder.md` |
| `CONTEXT.md` 長到幾千行，變成 spec | 「models treat "write to `CONTEXT.md`" as permission to persist every answer you give」：缺的是反向定義 | `docs/engineering/domain-modeling.md` |
| 從不說「程式碼沒問題」 | 「built to output findings, so the framing pushes it toward producing candidates」：框架問題，防線是強度分級 | `docs/engineering/improve-codebase-architecture.md` |
| 對整批 issue 跑 triage，已有「已修好」留言的 issue 還是被寫了新 brief | 批次時退回便宜的清單查詢當證據，那個查詢不帶留言：證據來源的問題 | `docs/engineering/triage.md` |
| tdd 被用在沒有獨立真值可斷言的改動上，寫出重述實作的測試 | 「nothing in it decides *whether* a change is worth the loop at all」：缺的是進入條件 | `docs/engineering/tdd.md`（#746） |

### 模型預設的方向

| 症狀 | 成因 | 出處 |
|---|---|---|
| 切票切太細 | 「Over-decomposition is the most reported friction on this skill… the model defaults to atomic units and loses the grouping that would make them meaningful」；防線是 quiz 那一步的問句（B2-34） | `docs/engineering/to-tickets.md` |
| 同一份 skill，較弱或較快的模型把「interview until shared understanding」縮成兩三題加一份大綱 | 模型差異 | `docs/productivity/grilling.md` |
| 觸發門檻較低的模型對簡單問題過度啟動 diagnosing-bugs | 「The skill is calibrated against Claude Code's invocation behaviour; a model with a lower activation threshold over-fires it.」 | `docs/engineering/diagnosing-bugs.md`（#578） |
| teach 的課程品質隨模型、harness、effort 差異很大 | 說明頁列的診斷清單：「model, harness, effort, and what the source was」 | `docs/productivity/teach.md` |

**【推論】強制力是相對於模型的**：同樣的措辭，在不同模型上綁住的程度不同。這也是 C8 說 no-op「model-relative」的另一面。

### 綁太緊，或綁錯地方

| 做法 | 結果 | 出處 |
|---|---|---|
| tdd 的 refactor 階段 | 刪掉：「agents essentially never performed it」 | `docs/engineering/tdd.md` |
| 替 grilling 加題數上限 | 拒絕：題數多是 prompt 品質問題，不是數量問題 | `.out-of-scope/question-limits.md` |
| 讓 setup 管各 skill 的偏好設定 | 拒絕：「"Config is death."」 | `docs/engineering/setup-matt-pocock-skills.md` |
| 問卷依前題答案跳題 | 沒上線：「a model planning more than two or three questions ahead of a real answer plans badly」 | `docs/productivity/to-questionnaire.md` |

### 寫法的來源

| 做法 | 結果 | 出處 |
|---|---|---|
| 做完一次實作，直接叫 agent 把它寫成 skill | 「The common route (do the work once, then have the agent write it up as a skill) over-indexes on that one run, and the exemplars come out too specific. Keep the run as evidence, then abstract deliberately: strip what belonged to that repo and those files, and write for the class of task.」 | `docs/productivity/writing-for-agents.md` |

### 措辭本身把模型帶偏

| 措辭 | 結果 | 出處 |
|---|---|---|
| implement 寫「the spec or tickets」 | 「nudges the model to go hunting for a file that doesn't exist」 | `docs/engineering/implement.md` |
| teach 用 `./` 同時指 skill 目錄與使用者目錄 | agent 把課程寫進 skill 自己的安裝目錄 | `docs/productivity/teach.md`（#377） |
| skill 裡寫「run the `/grilling` skill」 | 不一定會載入；改成「Call the Skill tool with "grilling"」 | `.changeset/skill-tool-invocation-terminology.md` |
| tdd 列候選 seam 只給名字 | 「you are choosing between labels」；使用者只能反問取捨 | `docs/engineering/tdd.md`（#607） |
| 測驗答案字數不一 | 正確答案總是寫得最完整，成了線索；改成要求每個選項字數相同 | teach |
| 測驗正確答案的位置 | 指令層的修法試過沒用（33 次都在 A），指向改用元件洗牌，尚未修 | `docs/productivity/teach.md`（#335） |

### 前提與交接

| 狀況 | 結果 | 出處 |
|---|---|---|
| 前置條件沒有任何一步負責 | 「"pre-agreed" is doing real work, and it is also the skill's weakest joint. Nothing inside `implement` agrees the seams… If it happens nowhere, the precondition never fires」 | `docs/engineering/implement.md` |
| router 用自己的一行摘要描述別的 skill | 「The router answers from its own one-line summary of each skill rather than from the skill」；原則：「Where the router and a `SKILL.md` disagree, the `SKILL.md` is right.」 | `docs/engineering/ask-matt.md` |
| handoff 裡寫了沒驗證過的斷言 | 「The next agent treats the document as a contract and will not re-check it, so a belief written as a fact becomes a false premise」 | `docs/productivity/handoff.md` |
| 新規範沒跟既有不變式對齊 | 「introduced without reconciling it against the user-invoked/model-invoked invariant stated eight lines above it; the gap is most of why this bug reached six call sites instead of one」 | `.changeset/user-invoked-skill-invocation.md` |
| 一個 skill 的步驟去叫一個 user-invoked skill | 叫不到。修法有兩種：前置條件改寫成「告訴人去跑」；diagnosing-bugs 那個很少觸發的交接則「Removed the hand-off outright rather than softening it」 | `.changeset/user-invoked-skill-invocation.md` |
| 一行轉交的 skill | 不保證會載入它依賴的 skill，只載一半時「a good interview with no paper trail」 | `docs/engineering/grill-with-docs.md` |
| 使用者自己的 `CLAUDE.md` 禁止再委派 | research 的背景 agent 會客氣地拒絕，skill 靜默不做事 | `docs/engineering/research.md` |
| harness 把 user-invoked skill 從注入的清單裡拿掉 | agent 把清單當成完整的，回報「沒安裝」；一次 session 宣告整條 spec 與 tickets 流程不存在 | `docs/engineering/ask-matt.md` |

### 評審與收斂

- 讀者的話，說明頁引用（`docs/engineering/code-review.md`）：「Same context reviewing itself isn't review, it's confirmation bias with a slash command.」
- 「Sub-agent output is a hypothesis, not evidence」
- 「There is no convergence guarantee… do not run it in a loop until it comes back clean, because it will not.」

（皆出自 `docs/engineering/code-review.md`）

## B4. 該綁還是該放：判斷準則【推論】

從 B1 到 B3 歸納，Matt 沒有這樣整理過。

### B4-0. 綁在哪：證據，不是思路

本輪驗證（`judge/verdict.md`，附錄 T2）：同一件「定期盤點結構重構候選」的工作，X 照 v2 寫、Z 照 v1 寫、Y 是 Matt 的 improve-codebase-architecture 原檔，各在真 repo 上唯讀跑一次，由一位盲評回 repo 查核。

| 做法 | 本輪看到的 | 規則 |
|---|---|---|
| 輸出欄位要求可檢查的產物 | X 的「Next change」加 trace、Z 的「Traffic」附 commit 與票號，評審抽查全部對得上；「轉不成一個具名的下一次改動就丟」把死碼清理擋進了 Left alone | 綁在欄位上，欄位要的是查得了的東西；不規定怎麼找到它 |
| 有關卡、沒有欄位 | Z 的完成條件要求「每個候選說出什麼會證明它不值得做，而且去查過」，template 卻沒有這一欄：查了，但只留在 trace 裡，使用者看不到 | 關卡要的證據，在產物裡要有位置 |
| 等級只有名字 | Y 的 `Strong` / `Worth exploring` / `Speculative` 沒有定義，刪兩個死檔拿到的 Strong 和購買流程一樣；X、Z 每一級都寫了成立條件（例：「named change is likely soon and its trace is plainly bad」） | 每個標籤寫成立條件 |
| 溢出沒有家 | Y 把兩條真 bug 塞進結構候選卡；Z 的 Also noticed、X 的 Left alone（附理由）讓候選清單保持短，Left alone 同時是「這次看過哪裡」的覆蓋紀錄 | 給溢出的東西正當的位置，看過不收的寫理由 |
| 呈現規則壓過求真 | Y 規定每條 ≤6 個字、不寫解釋段落，不確定性被擠掉；強制畫 after 圖，和「Do NOT propose interfaces yet」互相衝突；兩份檔對同一欄位定義不同（Benefits 對 Wins）；標題點名修法，在人挑之前就錨定答案 | 呈現排在求真之後；整份 skill 內部一致；候選用問題命名，不用修法命名 |
| 硬邊界沒寫 | Y 沒有唯讀條款，它的 sub-agent 在要求唯讀的環境裡跑了測試；Z 在開工與收工各查一次 `git status` | 硬邊界（唯讀、停在哪）寫明，並寫出怎麼查 |
| 原則蓋過 repo 的決定 | Y 套用 codebase-design 的原則「**The interface is the test surface.**」，把 repo 文件寫明的刻意做法（單元測試直接引內部檔）判成 friction | 見下面「規則衝突時的順序」 |

**這張表不是在說哪一份比 Matt 好**（各跑一次、一位評審、評分標準對準證據綁定、Y 的設計是交給其他 skill 接手，見附錄 T2）。能讀出的只有：**綁在證據欄位上的約束，產出查得了；綁在呈現與思考形狀上的約束，會擠掉不確定性，或把推理拉離 repo 自己的決定。**

### 該綁，當下面任一條成立

1. **下游有消費者需要一致**：解析它的程式、tracker 操作、另一個 skill、要快速掃過的人。
2. **錯了不可逆或會對外**：關閉 issue、推送、寫進別人的系統。
3. **這一步就是這個 skill 的價值**：diagnosing-bugs 的回饋迴圈、to-spec 的「不再訪談」。
4. **模型的預設習慣正是失敗本身**：Part 0 第 1 步說出、並在 baseline 裡看到的那個預設。例：沒有迴圈就讀程式碼猜原因、替使用者回答自己的問題、把「寫進 X」讀成「什麼都寫進 X」、切票切太細。
5. **措辭已經失敗過，或失敗發生時 agent 沒在想那個詞**：改用檔案、程式、lint、hook（B1-18），不要再加字。

### 該放，當下面任一條成立

1. 內容取決於當下情境，寫死只會在別的情境出錯。
2. 模型的先驗已經夠好，寫出來只是重述（no-op）。
3. 多樣性本身就是價值。

### 放開的空間出過錯時，補的邊界要對準它的失敗

B3「放太開」那張表的每一列，缺的東西不一樣：

| 缺的邊界 | 例子 |
|---|---|
| 停止條件 | research（「no stopping criterion」）、codebase-design（被當流程跑） |
| 進入條件 | tdd（沒有判斷「值不值得跑這個迴圈」） |
| 反向定義 | `CONTEXT.md` 變成 spec |
| 證據來源 | triage 批次改用不帶留言的查詢 |
| 框架防線 | improve-codebase-architecture 從不說沒問題 → 強度分級 |
| 遞迴禁令 | code-review、research 的 sub-agent 自我擴張 |
| 範圍與覆蓋紀錄 | 探索型 skill：見下一段 |

**探索型 skill 怎麼停**【推論】：
- 範圍在開始前宣告：「Scope before you scan」（improve-codebase-architecture）。X 限定一到三個區域。
- 候選數有上限。
- 報告裡有覆蓋紀錄：看了哪裡、沒看哪裡、看過但不收的附理由。
- 「每個宣告的區域都走過」就是完成條件；「什麼都沒留下」是合法的結果（B2-15）。

依據：research 缺停止條件的回報（B3），以及本輪驗證 X 的 Surveyed / Not surveyed / Left alone（`judge/verdict.md`）。

**不是每個空白都該補一個「停下來問人」。** 停下來問人，只放在「寫出這個 session 之外」或「替人做了決定」的地方。事實是 agent 的工作（B2-25），能做的準備先做完再問（B2-26）。

### 使用者不在時：繼續還是停

- **照預設繼續，並說出假設**：下一步可逆、留在工作區內、不替人做決定。
  - diagnosing-bugs：使用者 AFK 時照自己的排序測假設。
  - prototype：選一條預設分支，把假設寫在原型頂端。
- **停下來**：下一步會寫到 session 之外（tracker、remote、別人的檔案），或會定下一個屬於使用者的決定。
  - grilling：「The _decisions_ are the user's: put each to them and wait.」
  - to-tickets 發佈前要使用者核准切法。
- **兩種都一樣要 push right**：準備做完，停的時候只剩一份可以直接決定的摘要。
- **根本沒有人**（被自動化或別的 skill 叫起來）時等同 AFK，**停下來的狀態要寫成一個定義好的交付狀態**。例：本輪 D2 的「paused on questions you have put to the user, with everything else resolved」（`build-D2/resolving-conflicts/SKILL.md`）。
- **什麼算「屬於使用者的決定」，本身就是設計選擇。**
  - Matt 的 resolving-merge-conflicts 寫「Where incompatible, pick the one matching the merge's stated goal and note the trade-off」，把兩邊不相容時的取捨當成 agent 的事。
  - 本輪 D2 的 baseline 正是這樣做的：選一邊、在報告裡揭露、留了備份分支。
  - D2 的 skill 改成停下來問。這是有意識地偏離 Matt 的做法，要寫明理由，不要以為那是 Matt 的規則。

### 例外與覆寫不要放在受約束的一方自己能寫的地方

wayfinder Notes 的教訓（B3）。

### 規則衝突時的順序

同一份 skill 裡兩條規則拉扯時，照這個順序讓位：

1. **硬邊界**：環境或使用者設下的（唯讀、不准推送、範圍）。
2. **使用者的決定與 repo 的文件化規則**。使用者在這次呼叫裡明說的指示，蓋過 skill 自己的預設護欄（to-tickets「unless instructed otherwise」）；「不可逆前先確認」這類護欄，本來就是為了取得這個決定。
   - Matt：「a documented repo standard overrides the baseline」（CHANGELOG，code-review，B1-16）。
   - 本輪 Z：「A documented rule outranks your taste」。
3. **求真**：證據欄位、不編造（B1-24）。
4. **skill 自己的詞彙與原則**。
5. **呈現**：格式、長度、版面。

本輪的反例都是低順位蓋過高順位：Y 的原則（4）蓋過 repo 的文件化決定（2），Y 的呈現規則（5）擠掉不確定性（3）。

**同一份 skill 裡兩處對同一件事的定義不同，是 bug，不是衝突**：改成單一來源（C8）。

這個順序是起草時裁決衝突用的，不要整張寫進 skill。只有 skill 真的有兩個規則來源時，才寫一條覆寫規則，像 code-review 那樣。

### 每一個綁住的東西都要說得出它防的失敗

- 這是 Part 0 的完成條件。baseline 裡看到的失敗，比推出來的失敗有份量。
- 當預設有明確方向時，規則要能往兩邊推。to-tickets 的垂直切片規則把票往「細」推，quiz 那一步的問句（「too coarse / too fine」「merged or split」）把票往回拉。只往一個方向推的規則，會加重模型本來就有的偏差。

### Anti-pattern 什麼時候寫、怎麼寫

**Negation 與 anti-pattern 的差別**：Negation 講的是用禁令**引導**（C7）。anti-pattern 條目是**辨識器**：它說出一種失敗的形狀，讓模型在自己的產出裡認出它。

`## Anti-patterns` 只出現在三份檔：tdd/SKILL.md、prototype/LOGIC.md、prototype/UI.md。三份都是在反覆做同一件事時查閱的參考。

1. 目標在步驟裡用正向寫法寫出來。
2. 禁令只用在關卡或不可逆動作的護欄，並且配上正向目標（C7 的四種形狀）。
3. 一條 anti-pattern 要有**理由**；有 tell（看到什麼就知道中招）或正向目標更好。
   - prototype/LOGIC.md 的條目是「**Don't X.** {理由}」。
   - tdd 的「Implementation-coupled」以 tell 收尾，「Horizontal slicing」以正向目標收尾。
4. **把規則再寫成一條 anti-pattern，會抬高它的份量**（C8 的 duplication）。
   - 只對這個 skill 的主要失敗這樣做，也就是 Part 0 第 1 步說出的那個預設。
   - tdd 就是這樣：「**One slice at a time.**」在 Rules of the loop，「**Horizontal slicing** … Work in **vertical slices** instead」在 Anti-patterns。
   - 其他情況，把 tell 併進規則裡，不另立一條。

## B5. 槓桿索引

Part 0 第 4 步逐列走這張表。**每一列的預設答案是「不用，交給 agent 的先驗」**。只有你說得出「不加它，這個 skill 會怎麼壞」時才加。

| 槓桿 | 它回應的失敗 | 條目 |
|---|---|---|
| 承重那一步的關卡、做不到時停下回報 | agent 跳過難的那一步，直接做容易的部分 | B1-1、B1-2 |
| 完成條件寫「必須成立什麼」、要有要求量 | 提早宣告完成、做得不徹底 | B1-3、C4 |
| 新建的檢查要看它失敗一次 | 設定或條件永遠不會失敗，等於沒有 | B1-4 |
| 在最便宜的地方先失敗 | 錯誤到了昂貴的地方才爆 | B1-8 |
| 讀完整證據 | 用便宜的查詢漏掉關鍵欄位 | B1-30 |
| description 照 invocation 的寫法：一個分支一個觸發詞、必要時寫不觸發條件、含「: 」加引號 | 該觸發時沒觸發、不該觸發時觸發、YAML 失效被整批略過 | D1、C1 |
| 產出 template：固定框 + 自由區 | 下游讀的人或程式拿到不同形狀 | B1-10、Part E |
| 關卡要的證據有欄位（例：Next change + trace、Traffic） | 證據留在 trace 裡，使用者看不到；結論沒有依據 | B4-0 |
| 等級標籤寫成立條件 | 標籤變成隨手貼的形容詞 | B4-0 |
| Also noticed / Left alone（附理由） | 溢出的發現被扭成候選，或乾脆不報；看不出覆蓋範圍 | B4-0 |
| 跨次紀錄（被拒的不再提、基準 commit） | 定期跑的 skill 每次重提同一件事 | F9 |
| 佔位寫意圖、最小形式聲明 | template 被填成官樣文章，或被填滿每一欄 | E3、B2-19 |
| 詞彙鎖死 | 同義詞漂移、同一詞兩個意思 | B1-11 |
| 反向定義 | 產物長成它不該是的東西 | B1-12 |
| 產物文風 | 產物語氣不對、用編號給人讀 | B1-28 |
| 用分類讓行為掉出來 | agent 自己決定該等人還是繼續 | B1-14 |
| 分軸、不合併 | 一個面向的問題被另一個面向蓋掉 | B1-15 |
| 每個發現附出處 | 發現無法被檢查 | B1-17 |
| 用檔案、程式、lint、hook 綁 | 措辭失敗過，或失敗時 agent 沒在想那個詞 | B1-18 |
| 可清理的記號 | 暫時的東西留下來 | B1-19 |
| 不可逆之前停下 | 寫出去收不回 | B1-20、B4 |
| 對外產出標記 AI | 別人把 AI 產出當成人寫的 | B1-21 |
| 先遮蔽敏感資料 | 憑證出現在輸出裡 | B1-22 |
| 不覆蓋使用者的東西 | 使用者的修改被蓋掉 | B1-23 |
| 不編造 | 編出不存在的步驟或行為 | B1-24 |
| 範圍邊界、skill 自己的 Out of scope | 鍍金、延伸到相鄰功能 | B1-25 |
| 以一個 context window 為單位 | 工作單位裝不進一個 session | B1-26 |
| 透過產物傳約束 | 下一個 skill 不知道上一個定了什麼 | B1-27 |
| 每個前置條件都有一步負責 | 前置條件從來沒被滿足 | B3「前提與交接」 |
| sub-agent 的 brief 帶齊參考、禁止遞迴、附出處 | sub-agent 缺參考、自我擴張 | F7、D2 |
| 例外不放在受約束方能寫的地方 | agent 自己給自己開許可 | B4 |
| leading word 取代重述的步驟 | 步驟只是在重述模型早就會的迴圈 | B2-1、C6 |
| 引導式提問 | 死板的清單漏掉情境 | B2-5 |
| 偏好排序、最後一招先自問 | 太早用最重的做法 | B2-7 |
| 預設值加上限 | 數量失控或太少 | B2-8 |
| 提早退出 | 對不需要的情況也跑整套 | B2-10 |
| 自我檢驗、判斷測試 | 規則被字面套用 | B2-12、B2-13 |
| 逼出分歧 | 錨定在第一個想法 | B2-17 |
| 規則 + 理由 + 例外 | 規則被硬套到不適用的情況 | B2-18 |
| 預設並說出假設 | 模糊時卡住，或默默選了一邊 | B2-20 |
| 推薦答案放第一、已定的不問 | 人被問太多、被問已經定了的事 | B2-24 |
| 事實歸 agent、決定歸人 | agent 替人決定，或把查事實丟給人 | B2-25 |
| push right、給摘要 | 太早打斷人、給人看原稿 | B2-26 |
| 寫死問句 | 人被問到的問題沒對準已知失敗 | B2-34 |
| 當下寫入、寫前重讀、從產物接續 | 最後彙整走樣、蓋掉使用者的修改、重問已答的問題 | B2-29～31 |
| 用一手資料 | 憑模型記憶編內容 | B2-33 |
| 讀空白（Negative Space） | 沒寫的決定默默交給先驗。**來自舊版 `writing-great-skills`，現行文字沒有**（C7） | C7 |

有些條目在這張表裡沒有對應的一列，因為它們回應的是「放」的那一面（B2-3、4、6、9、11、14、15、21～23、27、28、32、35），用法是在寫某一步時順手取用，不需要逐列走。

---

# Part C　理論：Matt 給這些做法取的名字

出自 `writing-for-agents/SKILL.md` 與 `SKILL-MECHANICS.md`（1.2.3 版），外加 CHANGELOG 裡舊版 `writing-great-skills` 的一個概念（Negative Space）。
每個詞先引 Matt 的定義句（引文不會漂移），再在周圍整理。Part A 與 B 的很多做法，在這裡有對應的名字。

`writing-for-agents` 本身是 model-invoked，是一份純參考，開頭說它適用於「any document an agent consumes: a skill, an `AGENTS.md` / `CLAUDE.md`, a doc reached by a pointer」。
這一 Part 是它的轉述。原文要不要整份帶進來，是待決事項（附錄 P）。

## C1. Context pointer

> "A **context pointer** is a reference held in the agent's context that names some out-of-context material and encodes the condition for reaching it."

- skill 的 description 是一個 pointer，`AGENTS.md` 裡指向某份文件的那一行也是。
- **pointer 的措辭決定模型何時、多可靠地去取用**，不是它指向的內容：「A must-have target behind a weakly worded pointer is a variance bug: sharpen the wording first, and inline the material only if sharpening fails.」
- **pointer 做兩件事**：「state what the material is, and list the **branches** that should trigger reaching it」。branch 是「a distinct case the document handles, so different runs take different paths through it」。
- 常駐的 pointer 每一輪都在花，所以修剪得比本文更狠：
  - 「**Front-load the leading word**」
  - 「**One trigger per branch.** Synonyms that rename a single branch are one branch written twice」
  - 「**Cut identity the body already carries.**」
- 【推論】pointer 只有在 agent 已經想到那個詞時才會觸發。失敗發生在 agent 專心做別的事的時候，pointer 碰不到它，要改用 B1-18 的做法。

## C2. 兩種負擔

> "**Context load** is the cost of always-loaded material on the agent's window"
> "**Cognitive load** is the cost on the human: which documents exist and when to reach for each. The human is the index. Not a cost to minimise: it is the price of human agency; spend it where human judgement matters, remove it where it does not."

- context load：description、`AGENTS.md` 的每一行，每一輪都在花，不管有沒有觸發。
- 「Material reached only through a pointer escapes context load at the price of the pointer's own line; material with no pointer at all rides entirely on cognitive load.」

## C3. 資訊層級

> "A document is built from two content types: **steps** (the ordered actions the agent performs) and **reference** (definitions, rules, facts consulted on demand). The two mix freely"

- 三層：
  1. 本檔步驟：「the primary tier」。
  2. 本檔參考：「Often a legitimately flat peer-set (every rule of a review on one rung), which is a fine arrangement, not a smell.」
  3. 推到別處、用 pointer 指過去的參考。
- 「Push too little down and the top bloats; push too much and you hide material the agent actually needs. That tension is the whole decision.」

> "**Progressive disclosure** is the move down the ladder (out of the main file and behind a pointer) so the top stays legible."

- 判準用分支：「inline what every branch needs, and push behind a pointer what only some branches reach.」
- 參考內容埋住步驟時，模型有沒有注意到步驟就變成擲銅板：「a variance lever, not just a legibility one」。

> "Keep a concept's definition, rules, and caveats under one heading rather than scattered"（**co-location**）

- 測試：「the document should read like documentation written for the agent」。
- 它和 duplication 不同：duplication 是同一個意思寫兩處，scattering 是一個意思拆散到多處。

> "**Sprawl** is the failure mode here: a document simply too long, even when every line is live and unique."

- 解法是往下推，按分支或順序拆開。

## C4. 完成條件

> "Every step ends on a **completion criterion**, the condition that tells the agent the work is done."

- **Clarity**：「can the agent tell done from not-done? A vague bound ("understanding reached") invites **premature completion**」。
  - 後面還有步驟等著，會把模型往前拉；完成條件越清楚，越拉不動。
  - 防線順序：「**sharpen the bound first** (local and cheap); only if it is irreducibly fuzzy _and_ you observe the rush, hide the later steps by splitting the sequence.」
  - 藏只在真的換了 context 時有效：「an inline call leaves the later steps in context and clears nothing」。
- **Demand**：「"Every modified model accounted for" forces thorough work where "produce a change list" does not.」
  - 要求量驅動 **legwork**，而且不限於步驟：「"every rule applied" binds a body of flat reference just as "every step done" binds a sequence」。
  - 反過來也成立：一份有十幾個勾選框的清單，就是十幾件被要求的事（B5 因此不用勾選框）。
- 「The strongest criteria are both checkable and exhaustive.」

## C5. 什麼時候拆

- **按順序拆**：「split a run of steps where the post-completion steps tempt the agent to rush the one in front of it.」反過來，合併順序會讓每一步都看到後面的步驟。
- **按 invocation 拆**（SKILL-MECHANICS）：「split off a model-invoked skill when you have a distinct leading word that should trigger it on its own (a trigger word you actually use in your prompts), or another skill must reach it.」多一份常駐的 description 要付 context load，所以那份獨立的觸發要值得。

## C6. Leading word

> "A **leading word** is a compact concept already living in the model's pretraining that the agent thinks with while running the document (_lesson_, _fog of war_, _tracer bullets_)."

- 「Repeated as a token, never as a sentence, it accumulates a distributed definition」。
- 自造的詞：「Coining your own works if you define it clearly, but a made-up word recruits no priors」。
- 錨定兩次：在本文錨定**執行**，在 pointer 錨定**觸發**。同一個詞出現在你的 prompt、文件、程式碼裡時，模型更容易連到那份材料。
- 主動找機會重構：
  - 同一組三個形容詞出現在三處：「"fast, deterministic, low-overhead" → _tight_」。
  - 一句話在比劃一個概念：「"a loop you believe in" → _red_」，把模糊的關卡變成二元可觀察的狀態。
  - 「Assume every document is carrying restatements that leading words retire. Go find them.」
- 太弱的 leading word 是 no-op（C8）。

## C7. Negation 與 Negative Space

> "**Negation** is the failure mode beside this lever: steering by prohibition drags the forbidden behaviour into context and makes it _more_ available, not less."
> （`writing-for-agents/SKILL.md`，現行版）

- 解法：「Prompt the **positive**: state the target behaviour ("write one-line comments") so the banned one is never spoken. A prohibition earns its place only as a hard guardrail you cannot phrase positively; even then, pair it with the positive target so attention lands on what to do.」
- **實務上的禁令**：Matt 的 skill 裡禁令並不少，但大多貼著一個正向目標、理由或關卡，常見四種形狀：
  - **停止閘門**：「Do **not** proceed to hypothesise without a loop.」「Do NOT propose interfaces yet.」
  - **Do / Don't 成對**：AGENT-BRIEF「**Do** describe interfaces…」/「**Don't** reference file paths」；HTML-REPORT「**Use exactly:** …」/「**Never substitute:** …」。
  - **Anti-patterns 清單**：每條帶一句理由，「**Don't add tests.** A prototype that needs tests is no longer a prototype.」（anti-pattern 什麼時候寫，見 B4）
  - **不可逆動作的護欄**：「Do NOT close or modify any parent issue」「Always resolve; never `--abort`」。

  少數是裸禁令（「Never trust your parametric knowledge.」）。理論那條更嚴格的「連提都不要提」，Matt 自己沒有完全遵守。

**Negative Space**（虛空）：「every decision a skill declines is delegated to the agent's priors rather than left neutral」（CHANGELOG #463）。
- 讀草稿時要讀它**沒寫的部分**，逐一決定：補上，或明說那是一條分支。
- **出處狀態**：
  - #463 把 Negation 和 Negative Space 一起加進舊版 `writing-great-skills`，各是一整條詞彙表條目加一條 SKILL.md 失敗模式。
  - #763 把詞彙表併進 SKILL.md 時，只有 Negation 留了下來。
  - CHANGELOG 沒有說明為什麼沒留 Negative Space。**所以它不是 Matt 的現行做法。**
- 仍然收在這裡，是因為它給了 Part 0 第 4 步一個名字：每個空白都要是選過的。它的預設答案是「交給先驗」，不是「補上」。

## C8. 修剪

> "Keep each meaning in a **single source of truth**: one authoritative place, so changing the behaviour is a one-place edit."

- **Duplication**：「costs maintenance and tokens, and inflates a meaning's prominence on the ladder past its real rank.」
  - 它是 leading word 的反面：leading word 刻意重複**詞**，duplication 意外重複**意思**。
  - 反過來用：想刻意抬高某條規則的份量時，就是靠重複（B4 anti-pattern 第 4 條）。

> "The **environment** is a source of truth too (`package.json` scripts, config files, the directory layout, `--help` output), and a document that restates it is a **cache**"

- cache 只在查詢很貴時才值得：「Cache what the agent cannot find by looking: the unwritten convention, the reason behind a choice, the gotcha no config confesses. Leave the one-file, one-command lookups to the environment, where they cannot go stale.」

> "Check every line for **relevance**: does it still bear on what the document does?"

- 沒有修剪紀律的下場是 **sediment**：「stale layers that settle because adding feels safe and removing feels risky」。

> "Hunt **no-ops** sentence by sentence: an instruction the model already obeys by default pays load to say nothing."

- 測試是行為上的：拿掉這句，行為變不變？「model-relative, not reader-relative: two people disagreeing about a no-op disagree about the default, and settle it by running the document, not by debate」。
- 沒通過就刪整句，不是刪幾個字。
- 太弱的 leading word 也是 no-op：「_be thorough_ when the agent is already thorough-ish」→ 換更強的詞（_relentless_），不是換技巧。
- 說明頁補充：「Agents told to "streamline" optimise for length, because length is the thing they can see. The no-op test is behavioural, not aesthetic」（`docs/productivity/writing-for-agents.md`）。

---

# Part D　架構層的決定

## D1. invocation

整個 repo 分 skill 只看一個軸：**誰叫得到它**（`.agents/invocation.md`）。

| | model-invoked | user-invoked |
|---|---|---|
| 設定（Claude Code） | 不寫 `disable-model-invocation` | `disable-model-invocation: true` |
| 設定（Codex，`agents/openai.yaml`） | 不寫 `policy` 區塊 | `policy.allow_implicit_invocation: false` |
| 誰叫得到 | 模型自己叫，人也能打 `/name`，別的 skill 也能叫 | 只有人打 `/name`，別的 skill 都叫不到 |
| description | 給模型看，帶觸發分支 | 給人看，一句話，觸發詞拿掉 |
| 成本 | description 常駐，佔 context load | 零 context load，佔 cognitive load |

- **判準**：
  - 「Pick model-invocation only when the agent must reach the skill on its own, or another skill must. If it only ever fires by hand, make it user-invoked and pay no context load.」（SKILL-MECHANICS）
  - `.agents/invocation.md` 的問法：「_could the model usefully reach for this autonomously?_ (Reuse is the reason to extract a skill, not the test.)」
- **user-invoked 不等於編排流程。**
  - README 說 user-invoked「their job is to orchestrate」，但 wait-what、handoff、teach、to-questionnaire、setup-matt-pocock-skills 都是 user-invoked 而不編排任何東西。
  - 決定 invocation 的是上面那條判準，不是「是不是流程」。
- **兩份設定要同步**：「Keep the two in sync: a skill is user-invoked in both harnesses or neither.」（`.agents/invocation.md`）
  - 1.2.2 修過一次：`writing-for-agents` 已經是 model-invoked，旁檔卻留著 `policy.allow_implicit_invocation: false`，Codex 就把它從模型看得到的清單拿掉了，「its description could not trigger it」（CHANGELOG #766）。
- **user-invoked 會從模型的清單裡消失**：harness 注入給 agent 的 skill 清單不含 user-invoked skill，agent 把清單當成完整的，會回報「沒安裝」（`docs/engineering/ask-matt.md`，「A known bug, unfixed」）。
  - 【推論】凡是「告訴使用者去跑 `/x`」或 router 型的設計，都要預期 agent 會說 x 不存在。
- **方向**：user-invoked 可以叫 model-invoked，反過來不行，user-invoked 之間也不行。所以要被別的 skill 共用的 reference，一定是 model-invoked。
- **兩個 user-invoked 都需要的共用參考**，兩邊都放不了：「Push it to a plain file outside the skill system: external reference any skill can point at.」（SKILL-MECHANICS）
- **別名**：`grill-me` 全文是 `Call the Skill tool with "grilling".`；`grill-with-docs` 是一次叫兩個。
- **router**：user-invoked 多到記不住時，用一個 router（ask-matt）告訴人什麼時候用哪個。「It can only hint, never fire them」（SKILL-MECHANICS）。
- **改成 model-invoked 只會多、不會少**：「model-invocation only ever _adds_ the agent's reach」（CHANGELOG，wizard）。

### description 怎麼寫

- **model-invoked**：「它是什麼。Use when <情境 A>, <情境 B>, or <使用者會說的詞>.」一個分支一個觸發詞（C1）。
  - wizard 的 description 被描述為「the pointer that decides when it fires: what it produces, four trigger branches…, and an explicit non-trigger」，最後一句是「Don't invoke this for steps the agent can perform itself.」
  - `.agents/invocation.md`：「keeps rich trigger phrasing ("Use when the user wants…, mentions…, asks for…") so auto-invocation fires」。
- **user-invoked**：「a one-line summary read by a person browsing slash-commands. Strip trigger lists ("Use when the user says…").」（`.agents/invocation.md`）
  - 例：to-tickets 的 description 是一長句，說它產出什麼、兩種 tracker 下各長什麼樣子。
  - 【建議】順便說它跟相近 skill 差在哪。
- **太吸引人的通用詞會被過度觸發**。`prototype` 常在設計已經定案時被推薦：「a generic, appealing word that reads to a flow-unaware agent as "the obvious next step"」（`docs/engineering/prototype.md`）。
- **description 不寫別人的責任**：domain-modeling 的 description 刪掉了「another skill needs to maintain the domain model」，「since that's the invoking skill's job to state explicitly, not this description's」（`.changeset/domain-modeling-trigger-context-adr.md`）。
- **description 含「: 」要加引號**：em-dash 清掉後留下的冒號加空格，讓六份 YAML 失效，`skills.sh` 整批略過（`.changeset/fix-yaml-frontmatter-colons.md`）。

### 參數

- `argument-hint` 要配一句本文，說參數怎麼用：
  - 「If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.」（handoff）
  - teach 的 `argument-hint: "What would you like to learn about?"`
  - loop-me 的 `argument-hint: "A workflow to design, or nothing to go find one"`：連「沒給參數」這條分支都寫在提示裡。

## D2. skill 之間怎麼接（`.agents/invocation.md`）

- 寫 `Call the Skill tool with "grilling".`，不寫 `../other-skill/FILE.md`，也不寫讓模型自己解讀的 `/grilling`：「Naming the tool is what gets it fired」。
- 一次呼叫一個：`Call the Skill tool twice, for "grilling" and "domain-modeling".`
- **這條只適用於被叫的是 model-invoked skill。** 前置條件是 user-invoked skill 時，寫成交代人去做：「tell the user to run `/setup-matt-pocock-skills`」。
  - 這個分界是修 bug 之後補上的：一次改寫把五個 skill 的前置條件寫成「Call the Skill tool with "setup-matt-pocock-skills"」，而那是 user-invoked，誰都叫不到（`.changeset/user-invoked-skill-invocation.md`）。
- 共用 reference 放在擁有它的 skill 裡，別的 skill 叫那個 skill 來取用。
- router 的文字只是給人看的標籤，可以寫 `/name`。

### 硬依賴、軟依賴（`.agents/adr/0001`）

- **硬依賴**：沒有它輸出就是錯的，才寫一行明確的指標。
  - ADR 原文的寫法是「_… should have been provided to you; run `/setup-matt-pocock-skills` if not._」。
  - 經過上面那次修正，現行 to-spec、to-tickets 的寫法是：「The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.」
- **軟依賴**：只是不夠精準的，用模糊的散文帶過（ADR：「reference "the project's domain glossary" and "ADRs in the area you're touching" in vague prose only」）。
  - 「avoids cargo-culting the setup pointer into places where it isn't load-bearing」。
- **只讀詞彙和主動建模是兩件事**：「Merely _reading_ `CONTEXT.md` for vocabulary is a one-line prose pointer, not the `domain-modeling` skill.」（`.agents/invocation.md`）
- 【推論】**被依賴的 skill 可能沒裝時**：
  - 如果它提供的行為是承重的，就把最小的那一段寫進自己的 skill；否則用軟依賴的一行。
  - 證據是 grill-with-docs：一行轉交的 skill 只載到一半時，「a good interview with no paper trail」（`docs/engineering/grill-with-docs.md`）。

### 叫 reference 型 skill 時，護欄放在呼叫端

- tdd 叫 codebase-design 的那一句：「call the Skill tool with "codebase-design" for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is a reference to consult, not a session to run.」
- codebase-design 被當流程跑的事故（B3）裡，它自己的 SKILL.md 已經說自己是「Shared vocabulary」，還是擋不住。說明頁的修法是「name a driver skill and let this one sit underneath it」（`docs/engineering/codebase-design.md`，issue #449，仍開著）。

### 派 sub-agent：它什麼都沒繼承，brief 要自己帶齊

- sub-agent 不會自動拿到這個 skill 的內容。code-review 給 Standards 軸的 brief 包含「the smell baseline from step 3 pasted in full (the sub-agent has no other access to it)」。
- DESIGN-IT-TWICE：
  - 「Prompt each sub-agent with a separate technical brief (file paths, coupling details, dependency category…, what sits behind the seam). The brief is independent of the user-facing problem-space explanation in Step 1.」
  - 「Include both SKILL.md vocabulary and CONTEXT.md vocabulary in the brief so each sub-agent names things consistently」。
- 兩軸分成兩個 sub-agent，「so they don't pollute each other's context」（code-review）。
- **禁止遞迴不在任何上架的 brief 裡**：
  - code-review 與 research 都出過 sub-agent 自我擴張的事故（B3）。
  - 使用者的修法是在 brief 裡禁止再委派，說明頁寫明「Neither is in the shipped skill yet」（`docs/engineering/code-review.md`；research 是 #530）。
  - F7 採用這個修法，標【建議】。
- **不寫死 harness 的工具名**：1.2.3 把 sub-agent 派工裡的 Claude Code 工具名與 agent type 拿掉，「so the step is followable on Codex and other harnesses」（CHANGELOG）。
  - 這條約束的是要跨 harness 發佈的 skill（見 B1-18）。

## D3. 分流、往下推、單一來源

- 每條路都要的，寫在本檔；只有部分路線用到的，推到旁邊的檔，指標放在需要它的那一步（「Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).」）。
- 範本是 prototype：開頭「Pick a branch」，兩條路各一檔，共用規則留在本檔。
- 寫「Discover the project's **automated checks**」（resolving-merge-conflicts），不列指令清單。
- **map 是索引，不是倉庫**：「a decision lives in exactly one place, its ticket, so the map never restates it, only gists it and links.」（wayfinder）
- **handoff 不複製已有的產物**：「Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.」（handoff）
- **跨文件的固定文字用標記區塊當單一來源**：`.agents/install-block.md` 用 `<canonical-block name="…">` 包住安裝指令：「One install story, one wording… Change it here first, then propagate.」
- **規則要讓 agent 找得到，不是撞到才知道**：setup-ts-deep-modules 寫完 README 後，要在 `CLAUDE.md` 加一行指過去：「This is what makes an agent discover the boundary rule instead of tripping over it.」
- **交接時指向下一步要用的 skill**：handoff「Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.」
- **一手資料保留下來，只把結論帶進主線**：prototype「capture the prototype itself as a **primary source**: commit it to a throwaway branch, out of main, and leave a context pointer to that branch on the implementation issue… The main branch keeps only the validated decision.」

### 兩份文件需要同一個意思時【推論】

C8 的「單一來源」管的是**跨文件**的同一個意思。C3 的「每條路都要的就寫在本檔」管的是**一份文件內**的擺放。兩條範圍不同，不衝突。兩份文件都需要時：

1. **只給一個擁有者，另一份指過去。**
2. **擁有者按「需要時誰在 context 裡」選。** 例：一條「寫字面量時要注意」的規則，如果只有按路徑注入的規則檔在寫字面量的當下會被載入，擁有者就是它，skill 指過去。
3. **只在跨越真正的 context 邊界時複製，而且在執行時才複製**：code-review 在派 sub-agent 的當下把 smell baseline 整份貼進 brief。複製品是從單一來源現做的，沒有人維護兩份。
4. **很多檔共用的固定文字**，用 canonical block。

## D4. 可變的設定與 skill 本身分開

> "Those files are the only thing that varies between repos. **The skills themselves are identical everywhere**; they read `docs/agents/issue-tracker.md` at run time and do what it says."
> （`docs/engineering/setup-matt-pocock-skills.md`）

- 上面那個路徑是 Matt 的 setup 預設把 seed 放的位置，**不是該寫死在 skill 裡的東西**。
  - wayfinder 曾經寫死 `docs/agents/issue-tracker.md`，在把 agent 文件放在別處的 repo 裡「silently fell back to the local-markdown tracker … even one whose `CLAUDE.md` clearly declares GitHub issues」（CHANGELOG #472）。
  - 修法是透過 setup 寫進 `CLAUDE.md`/`AGENTS.md` 的 `### Issue tracker` 區塊找到設定檔。
- **Matt 自己沒有全面照做**：code-review 仍寫著「If `docs/agents/issue-tracker.md` is missing, tell the user to run `/setup-matt-pocock-skills`.」，找 spec 的步驟也「fetched via the workflow in `docs/agents/issue-tracker.md`」。規則是 #472 說明的修法，實際套用不一致。
- **設定不在時給一行預設**：「If no tracker has been provided, default to the local-markdown tracker.」（wayfinder）
- **seed 檔用轉接段**，把抽象動作翻成這個 repo 的具體做法。本地 markdown tracker 的 seed 全文就這麼短：
  > "## When a skill says "publish to the issue tracker"
  > Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).
  > ## When a skill says "fetch the relevant ticket"
  > Read the file at the referenced path. The user will normally pass the path or the issue number directly."
  > （setup-matt-pocock-skills/issue-tracker-local.md）
- **語意在消費端，編碼在 seed。**
  - wayfinder 的規則寫在它自己的 SKILL.md：先 claim 再動工（「claims a ticket … **first**, before any work」）、一個 session 只解一張票、解完要留言、關票、在 map 附上指標。
  - seed 的「Wayfinding operations」只寫**這個 tracker** 怎麼表達這些動作（例：「**Claim**: set `Status: claimed` and save before any work.」）。
  - 產出票的 to-tickets 不替消費者寫規則：「running it (one session at a time, or a fleet) is your job, not the skill's」（`docs/engineering/to-tickets.md`）。
  - seed 的原檔放在 setup skill 的目錄裡，由 setup 複製進使用者的 repo。
- seed 檔內可以帶**設定旗標**，預設關閉，由使用者自己改：「**PRs as a request surface: no.** _(Set to `yes` if …; `/triage` reads this flag.)_」（setup-matt-pocock-skills/issue-tracker-github.md）
- **個人化放使用者自己的 `CLAUDE.md`，不改 SKILL.md**：「Put standing behaviour in your own `CLAUDE.md` or `AGENTS.md`, or say it in the invocation. Prompt-level adaptations survive updates」（`docs/engineering/ask-matt.md`）。plugin 安裝是唯讀的，`npx skills update` 會覆蓋。

## D5. skill 的生命週期（repo 的 `CLAUDE.md`）

- 按桶分：
  - `engineering/`、`productivity/` 是**上架**的；
  - `in-progress/` 是 beta（「public on purpose, feedback wanted, not shipped in the plugin」）；
  - `misc/` 留著但少用、不上架；
  - `deprecated/` 已不用。
- 上架的 skill 必須同時出現在 README 與 `plugin.json`；未上架的不能出現。
- **退役就刪**，由移除它的 changeset 寫明誰取代它（`skills/deprecated/README.md`）。
- **改名的處理不一致**：
  - `diagnose`→`diagnosing-bugs`、`writing-great-skills`→`writing-for-agents` 是 Breaking，不留別名。
  - `to-prd`→`to-spec` 是 Minor，開頭留了一句「you may know this document as a PRD」幫人找到它，後來在 #734 拿掉。
  - `decision-mapping`→`wayfinder` 是 Minor、不留別名，當時正從 `in-progress/` 升上來。
- 加 router 就要維護它：「a new skill it never mentions, or a stale one it still routes to, is a router that lies.」（`CLAUDE.md`）。實際的漂移見附錄 G。
- 上架 skill 改了行為，就要同步它的說明頁與 router。
- 綁死某個 harness 的 skill 以 harness 命名，放在上架集合之外（`misc/git-guardrails-claude-code`、`in-progress/claude-handoff`）。

## D6. 給人看的說明頁（選配）

Matt 每個上架 skill 另有一頁 `docs/<bucket>/<name>.md`，給人判斷「要不要用、什麼時候用」（`.agents/writing-docs.md`）。

- **段落**：
  - template 的固定框是 What it does / When to reach for it / Where it fits；Prerequisites 與中段自由。
  - 同一份規範又說「Four sections make a page worth reading: What it does, When to reach for it, Common questions, It's working if」，`CLAUDE.md` 也說完成的頁面有這四段。
  - **原文在這裡自相矛盾**：Common questions 與 It's working if 在 template 裡是可以省的。
- 「Explain the **why**, not the process.」不重述步驟。
- **defining constraint** 是說明頁的規則：「`## What it does` states the defining constraint, as plain prose rather than a labelled aside.」定義是「the single fact that makes this skill behave differently from the obvious default」。
- **中段沒有固定標題**：「There is no prescribed heading; the skills are too heterogeneous for one.」唯一不能省的是 leading word（B1-10 的引文）。
- **分支一律用表格或清單**：「Branches go in a table or a list, never in a paragraph.」理由是讀者在找符合自己情況的那一列。這條跟 SKILL.md 的「段落承載條件」（A5）方向相反，因為讀者不同。
- **It's working if** 的每一條，讀者不打開 SKILL.md 也能檢查。
- Common questions 只收真的被問過的，份量照證據，「not padded to match a richer skill's page」。
- 不署名作者：「The page is a technical document, not a record of who said what.」
- **語氣**：說明頁可以用「The honest limit: the frontier is the agent's judgement, not a computed graph.」（`docs/productivity/grilling.md`）、「Two honest notes on that list.」（`docs/productivity/teach.md`）這種承認限制的語氣，也有很多格言式的句子。這些不出現在 SKILL.md 本文。
- 那份規範本身就是「template + 對應 Done-when 清單」的範例（E3）。
- 說明頁是二手整理，會落後於 SKILL.md（附錄 G 有實例）。

## D7. 專案型 skill 與依賴狀態的 skill【推論】

Matt 的 plugin 裡**沒有專案型 skill**：他的 skill 都是通用的，repo 差異全在 seed 與 `CLAUDE.md`（D4）。這一節是從他的做法推到「只服務一個 repo」「行為取決於 repo 現況」的 skill。

- **不寫對現況的斷言；執行時的檢查可以寫。**
  - Matt 的例子：
    - setup「Read whatever exists; don't assume」；
    - 硬依賴那一行（D2）；
    - 軟依賴的「(if it exists)」；
    - 「Discover the project's automated checks」。
  - skill 在執行時讀現況，讓檢查的輸出決定走哪條分支。
- **不進 skill 的**：分支名稱、計畫中那一批工作的名字、數量、日期、「還沒做」。它們是會腐爛的 cache（C8 的 sediment）。
- **過渡期的分支**（只在遷移期間成立）：
  - 寫成檢查結果一變就自動變 no-op 的形式；
  - 用一行標出它是過渡分支，修剪時找得到；
  - 不要在常駐的 description 裡宣傳這條分支。
- **設定透過 repo 的 pointer 讀，不寫死路徑**；設定不在時給一行預設（D4）。
- **哪些 repo 事實可以寫進 skill**：用 C8 的 cache 判準，「the unwritten convention, the reason behind a choice, the gotcha no config confesses」。
  - 例：一道門禁只掃某幾層，另外幾層的違規會靜默放過。這種盲區 config 不會自己說出來，值得寫。
- **外部來源（wiki、規範文件）與程式碼不一致時**：
  - skill 寫的是檢查，不是外部文件的斷言。
  - 依據是「Follow every claim back to the source that owns it.」（research）與「Where the router and a `SKILL.md` disagree, the `SKILL.md` is right.」（`docs/engineering/ask-matt.md`）的精神：以擁有它的那份為準。
- **消費者的規則**寫在消費端的 skill；本 repo 的 tracker 怎麼表達，寫在設定檔（D4）。
- **harness 固定時**：可以用那個 harness 的 path-scoped rule 或 hook，讓規則在 agent 專心做別的事時也碰得到它（B1-18）。代價是它只在這個 harness 上成立。
- **工具版本會改變的行為**，寫成兩種都成立的做法，或寫成執行時的檢查。本輪 D2：解回與 HEAD 相同的 rebase commit，在 git 2.50 上會被靜默丟掉，某些版本則會要求 `--skip`（`build-D2/notes.md`；舊版行為沒有驗）。
- **語言與標點**：Matt repo 的 em-dash 禁令、英文內文，是他 repo 的慣例。專案型 skill 照專案的慣例。

## D8. 產物放哪、怎麼交出去

| 產物 | 放哪 | 例子 |
|---|---|---|
| 一次性的輸出 | OS 的暫存目錄，不進工作區 | handoff「Save to the temporary directory of the user's OS - not the current workspace.」；improve-codebase-architecture「Write a self-contained HTML file to the OS temp directory so nothing lands in the repo」，從 `$TMPDIR` 解析、每次一個新檔名、幫使用者打開、「tell them the absolute path」 |
| 會留下來的決定 | repo 裡，延遲建立 | domain-modeling 的 `CONTEXT.md`、ADR（B2-32） |
| 一手資料 | 丟棄用的分支，主線只留結論 | prototype（D3） |
| 使用者要的文件 | 照 repo 既有的慣例；沒有就挑個合理的地方並說出來 | research「Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.」；to-questionnaire「Write it to `to-questionnaire-<slug>.md` in the current directory … and report the path.」 |
| 跨 session 的工作區 | 使用者指定的目錄，問一次並記住 | writing-beats「If the user did not say where to save the article, ask once and remember the path.」；teach 把目前目錄當工作區（F9） |

---

# Part E　Template 怎麼寫

## E1. 三種 template

| 種類 | 例子 |
|---|---|
| **獨立格式檔** | domain-modeling（ADR-FORMAT、CONTEXT-FORMAT）、teach（MISSION / RESOURCES / LEARNING-RECORD / GLOSSARY）、triage（AGENT-BRIEF、OUT-OF-SCOPE）、improve-codebase-architecture（HTML-REPORT） |
| **SKILL.md 內嵌的產出 template** | to-spec `<spec-template>`、to-tickets `<local-ticket-template>` / `<issue-template>`、to-questionnaire `<questionnaire-template>`、wayfinder 的 map body、grilling 的輪次格式、triage 的 needs-info、setup 的 `## Agent skills` 區塊 |
| **複製後編輯的檔** | wizard/template.sh、diagnosing-bugs/scripts/hitl-loop.template.sh、setup 的五份 seed、setup-ts-deep-modules 的 config |

## E2. 什麼時候拆成獨立檔【推論】

v2 列了三條（會被複製的獨立；主要產出寫在本檔；附帶產出有自己的規則就拆）。本輪兩位 builder 指出兩個問題：
- 主要產出也有自己的規則時，第 2、3 條打架（`build-C2/notes.md`）。
- C3 照字面會把三行也拆成一檔（`build-D1/notes.md`）。

合成一條判準：**內容放在「需要它的那一步執行時，它就在 context 裡」的地方。**

1. **會被複製再編輯的** → 獨立檔。它的讀者是複製的人，不是這次執行。
2. **每次執行都會寫的產物** → template 與它的規則都留在本檔，即使很長。寫的那一步要看得到它們，欄位才引導得了推導（E4）。
3. **不是每次都寫的附帶產物** → 格式檔。
   - 格式檔裡從來不只有 template，還有規則、判準、編號、延遲建立。
   - 例：domain-modeling 不是每次都寫 ADR，所以 ADR 的判準在 ADR-FORMAT.md。
4. **下限**：推出去的內容要大到值得一次跳轉。只有幾行、而且是在某一步當下要看的分支內容，留在本檔。
   - 本輪 D2 把 rebase 專屬的五六行留在本檔，理由是每一行都要在那一步被看到。

一份 skill 有兩份產物時，各自照上面判斷。本輪 X：盤點清單與決策紀錄每次都寫，留在本檔；「被拒的紀錄」不是每次都寫，拆成格式檔。

## E3. 讓 template 綁形狀、不綁內容

- **佔位寫意圖，不寫空格。** 一句說明同時規定內容、視角與篇幅：
  - 「The problem that the user is facing, from the user's perspective.」（to-spec）
  - 「One paragraph orienting a recipient who wasn't in the user's head. Enough to answer well, not a page.」（to-questionnaire）
  - 「{1-3 sentences. The concrete real-world goal the user is chasing… Avoid abstract framings like "to understand X"; push for the underlying outcome.}」（teach/MISSION-FORMAT.md）
- **template 裡夾指引註解。** wayfinder 的 map body：`<!-- see "Fog of war": in-scope fog you can't ticket yet; graduates as the frontier advances -->`。
- **用完整範例代替佔位**：RESOURCES-FORMAT、OUT-OF-SCOPE、AGENT-BRIEF 的三個好範例與一個壞範例。
- **明說最小形式就夠**：「That's it.」加上「Only include these when they add genuine value.」（ADR-FORMAT）
- **template 外面補一句所有形式都適用的限制**：「In either form, avoid specific file paths or code snippets: they go stale fast.」（to-tickets）
- **用 XML 風格標籤包起來**：`<spec-template>`、`<question-example>`、`<vertical-slice-rules>`、`<canonical-block>`、`<what-to-do>`。
  【推論】標籤讓模型分得出哪一段是要照抄的形狀、哪一段是規則。Matt 沒有說明用標籤的理由。
- **完成條件對應 template 的段落**：`.agents/writing-docs.md` 的 `## Done when` 逐條對應它的 `<page-template>`。
- **複製型 template 用分界標記**：
  - wizard：「Everything above the "STAGES" marker is the wizard library: do not hand-edit」。
  - hitl-loop 檔頭：「Copy this file, edit the steps below, and run it.」加上兩個 helper 的簽名。

## E4. template 的每個欄位都在引導推導【推論】

欄位問什麼，模型就想什麼。想讓它想到某件事，就給那件事一個欄位。證據：

- to-tickets 的 template 要驗收條件，沒要求它們**會失敗**。說明頁：「The template asks for criteria and says nothing about whether they can fail, so this happens.」有些條件開工前就已經成立。
- 有人加一行「demo path」欄位，回報說能把模型推向垂直切片（`docs/engineering/to-tickets.md`）。
- to-spec 的 template 以 user story 為主，拿來寫重構就很彆扭：「you end up writing stories nobody asked for around decisions that are really about interfaces and invariants」（`docs/engineering/to-spec.md`）。

## E5. 格式檔的內部結構（綜合五份）

下面這個骨架是**從五份格式檔拼出來的**，沒有任何一份完整長這樣。逐段標出處：

```
# <X> Format
放在哪、怎麼編號；延遲建立：第一次需要時才建目錄        ← ADR-FORMAT、LEARNING-RECORD-FORMAT
（可選）一句話：它是什麼、等於哪個東西的什麼             ← LEARNING-RECORD-FORMAT（「They are the teaching equivalent of ADRs」）

## Template                                            ← ADR、LEARNING-RECORD
    （fenced md block，{大括號} 佔位，通常幾行）
That's it. <X> can be a single paragraph. The value is in recording _that_ …, not in filling out sections.   ← ADR

## Optional sections                                   ← ADR、LEARNING-RECORD
Only include these when they add genuine value. Most <X> won't need them.

## Rules            （粗體起頭的條列，每條一句理由）   ← CONTEXT-、GLOSSARY-、MISSION-、RESOURCES-FORMAT（ADR 與 LEARNING-RECORD 沒有）
## Numbering        （掃描現有最大編號 +1）             ← ADR、LEARNING-RECORD
## When to offer / When to write                        ← ADR「When to offer an ADR」（All three must be true）；LEARNING-RECORD「When to write a learning record」（any of these）
### What qualifies                                      ← ADR
### What does _not_ qualify                             ← LEARNING-RECORD
## Supersession     （被推翻時標 superseded，不刪）     ← LEARNING-RECORD（ADR 只把 superseded 放在 Status 選填欄位）
```

## E6. 佔位語法【建議】

Matt 不統一：`{}`、`<>`、`[]`、說明文字都有。自己寫的時候固定成兩種：短欄位用 `{名稱}`，整段內容用一句意圖說明。

---

# Part F　零件與骨架【建議】

以下是我依上面整理的骨架，**不是 Matt 的原檔**。每份後面標出哪裡是**綁**、哪裡是**放**。
這些不是要照填的表單：F10 列出每一塊可以單獨拿去組合的零件。挑零件的依據是 Part 0 第 1 步說出的預設，不是「骨架裡有這一節」。
一份真實 skill 的整體走讀在 F11。

## F1. model-invoked：reference 型（詞彙、紀律）

```markdown
---
name: {skill-name}
description: {leading word 片語}. Use when {情境 A}, {情境 B}, or {使用者會說的詞}.
---

# {Title}

{一到兩句：它是什麼。粗體帶出 **{leading word}**。}

Consult this while running {driver skill}: it is vocabulary, not a session to run.

## Glossary

Use these terms exactly: don't substitute {被禁的同義詞}. Consistent language is the whole point.

**{Term}**: {它是什麼，一到兩句}. _Avoid_: {同義詞}.

## Principles

- **{原則}.** {一句理由。}
- **The {name} test.** {一個模型自己能跑的判斷測試。}

## Anti-patterns

- **{名稱}**: {它是什麼}. The tell: {看到什麼就知道中招}.

## Rejected framings

- **{被否決的框架}**: {為什麼不採用}. {改用什麼。}
```

**綁**：詞彙、被禁的同義詞。**放**：原則怎麼套、測試結果怎麼解讀。

**「不是 process」那一句**：
- 「a reference, not a process」「a reference, not a driver」是**說明頁**的用語（`docs/engineering/codebase-design.md`、`docs/engineering/tdd.md`），Matt 的 SKILL.md 本文沒有這句。
- codebase-design 本文已經說自己是「Shared vocabulary」，還是被當流程跑（issue #449）。所以這一句**單獨擋不住**。
- 真正的護欄在兩處：
  - **呼叫端**寫「it is a reference to consult, not a session to run」（tdd 的寫法，見 F4 第 3 步）；
  - 讓一個 driver skill 帶著它跑。
- 上面骨架裡那一行是我的建議，保留它是因為無害，不是因為它有效。

**Anti-patterns 一節**：只在符合 B4 的條件時才寫。它是給反覆查閱的參考用的辨識器。

## F2. model-invoked：關卡型紀律

```markdown
---
name: {skill-name}
description: {它是什麼}. Use when {情境 A}, or {情境 B}. Don't invoke this for {不觸發的情況}.
---

# {Title}

{一句：它是什麼，粗體帶出 leading word。} Skip phases only when explicitly justified.

{軟依賴，一句散文，例：Use the project's domain glossary and respect ADRs in the area you're touching, if they exist.}

## Phase 1: {承重的那一步}

**This is the skill.** {為什麼這一步決定成敗，一句。}

Ways to {達成}, in roughly this order:

1. {首選}
2. {次選}
3. {最後手段}. Last resort.

### Completion criterion

Phase 1 is done when {可觀察的狀態，寫「什麼必須成立」，含要求量}.

If you catch yourself {預設的失敗動作} before this exists, stop: that is the exact failure this skill prevents.

### When you genuinely cannot {達成}

Stop and say so. List what you tried. Ask the user for {能讓你繼續的東西}. No {Phase 1 的產物}, no Phase 2.

## Phase 2: {名稱}

Generate {3–5 個候選} before {下一步}. {為什麼要多個：單一候選會錨定。}
Each must {可被證偽 / 彼此結構不同}. If you cannot {說出預測}, {丟掉或磨尖}.

Show {候選} to the user before {動手}. Don't block on it; proceed with your ranking if the user is AFK.

Do not proceed to Phase 3 until {這一階段的進入條件}.

## Cleanup

Required before declaring done:

- [ ] {機械可檢查的收尾，例：grep 標記為空}
- [ ] {把最終採用的假設寫進 commit message}
```

**綁**：
- **每一道**階段的進入條件；
- 第一道的完成條件與做不到時的停止方式；
- 預設的失敗在關卡上出現一次（Part 0 第 1 步）；
- 候選數量與「可證偽」；
- 給人看的時點；
- 收尾。

**放**：用哪種做法達成、候選的內容、排序。

- 「proceed with your ranking if the user is AFK」成立，是因為排序可逆、留在工作區內（B4）。換成會寫出 session 的動作，這一句要改成停下來。
- Cleanup 用勾選框是照 diagnosing-bugs 的原樣：那是收尾的機械清單，每一項都必須做完。
- 軟依賴那一行的寫法依你的 repo 有什麼文件而定。`CONTEXT.md`、ADR 是 Matt repo 的慣例，不要照抄成通用 skill 的前提。

## F3. 先分流型

```markdown
---
name: {skill-name}
description: {它是什麼}. Use when {分支 A 的情境}, or {分支 B 的情境}.
---

# {Title}

{一句定義，粗體帶出 leading word。{那個詞} decides the {分支}.}

## Pick a branch

- **"{分支 A 在問的問題}"** → [{A}.md]({A}.md). {它產出什麼。}
- **"{分支 B 在問的問題}"** → [{B}.md]({B}.md). {它產出什麼。}

{選錯的代價，一句。} If it's genuinely ambiguous and the user isn't reachable, default to {預設分支} and state the assumption at the top of the output.

## Rules that apply to both

1. **{規則}.** {理由。}
```

每個分支檔開頭放一段「When this is the right shape」，列三四句使用者會說的話，最後一句指向另一條分支（B2-35）。

**綁**：分支判準、預設、共用規則。**放**：分支內部怎麼做。

需要關卡的分流型 skill：把 F2 的「Phase 1 + Completion criterion + When you genuinely cannot」整塊放進需要它的那一條分支檔；兩條分支都需要時，放在本檔的「Rules that apply to both」之前（F10）。

## F4. user-invoked：編排型，附產出 template

```markdown
---
name: {skill-name}
description: {給人看的一句話：做什麼、產出什麼，跟相近 skill 差在哪}.
disable-model-invocation: true
argument-hint: "{提示人可以傳什麼}"
---

{開頭：定義或工作陳述，例：Do not interview the user; synthesize what you already know.}

The {硬依賴} should have been provided to you. If not, tell the user to run `/{setup-skill}`.

## Process

### 1. {蒐集}

Work from whatever is already in the conversation. If the user passed a reference, fetch it and read its full body and comments.

### 2. {探索}

Read whatever exists; don't assume. {要看什麼，用引導式問題：}

- {問題}
- {問題}

### 3. {起草}

When {某個判斷} is in question, call the Skill tool with "{model-invoked-reference-skill}" for the vocabulary. It is a reference to consult, not a session to run.

{起草規則。預設會往哪個方向錯，規則就要能往回拉。}

### 4. {確認}

Present {草稿的摘要，不是全文}. Lead with the recommended answer so the user can accept it in a word; skip anything exploration already settled.

Ask the user:

- {寫死的問句，對準預設的失敗方向}
- {寫死的問句}

Iterate until the user approves.

### 5. {產出}

Write it using the template below, then {發佈到哪／放在哪，並說出路徑}.

<{output}-template>

## {段落}

{一句意圖：這段寫什麼、從誰的視角、多長。}

## Out of scope

{使用者明確拒絕的東西。}

</{output}-template>

In every form, {所有形式都適用的限制}: {理由}. Exception: {什麼情況下可以破例}.
```

**綁**：
- 硬依賴那一行（用「tell the user to run」，因為 setup 是 user-invoked）；
- 讀完整證據；
- 確認點與寫死的問句；
- 核准前不寫出去；
- 產出的段落、Out of scope；
- 產物放哪要說出來。

**放**：探索路徑、草稿內容、每段的實際內容。

- 每一步都可以加一行 Done when（to-questionnaire、setup-ts-deep-modules 的寫法）。
- 步驟的數量跟著產物走：產物小而一次寫完，就像 handoff 那樣寫成幾句約束，不必有 Process（Part 0）。

## F5. 別名

```markdown
---
name: {alias-name}
description: {給人看的一句話}.
disable-model-invocation: true
---

Call the Skill tool with "{primitive}".
```

兩個以上：`Call the Skill tool twice, for "{a}" and "{b}".`
- 被叫的 primitive 必須是 model-invoked（D2）。
- 一行轉交不保證被叫的 skill 全部載入（B3「前提與交接」，grill-with-docs）。

## F6. 格式檔 `{X}-FORMAT.md`

````markdown
# {X} Format

{X} lives in `{路徑}/` and uses sequential numbering: `0001-slug.md`, `0002-slug.md`.
Create the directory lazily: only when the first {X} is needed.

## Template

```md
# {Short title}

{1-3 sentences: 內容與理由。避開 {常見的空泛寫法}，要 {具體的東西}。}
```

That's it. {X} can be a single paragraph. The value is in recording _that_ {…}, not in filling out sections.

## Optional sections

Only include these when they add genuine value. Most {X} won't need them.

- **{欄位}**: only when {條件}

## Rules

- **{規則}.** {理由。}
- **Keep it short.** If {X} runs past {長度}, it has stopped being {它的用途} and started being {它不該變成的東西}.
- **{X} is {它是什麼} and nothing else.** {它不收哪些東西。}

## When to write one

All three must be true:

1. **{判準}**: {說明}
2. **{判準}**: {說明}
3. **{判準}**: {說明}

### What qualifies

- **{類型}.** "{真實例子}"

### What does _not_ qualify

- {類型}. {為什麼不算}

## Supersession

When a later {X} contradicts an earlier one, mark the old one `Status: superseded by {X}-NNNN` rather than deleting it.
````

SKILL.md 那一步寫：`Use the format in [{X}-FORMAT.md](./{X}-FORMAT.md).`

- 這份骨架是 E5 那個綜合結構的填空版。實際的格式檔只取它用得到的段落。
- 編號用 `0001-` 還是 `01-`：這個編號是給指令用的 ID（`/implement 03`），就照指令好打的方式選（B1-28）。

## F7. 派給 sub-agent 的 brief

```markdown
{背景一句：它在整體裡負責哪一塊。}

**Desired outcome:** {要什麼行為或答案，不寫怎麼做}.

**Technical brief:** {它要看的檔案路徑、耦合細節、相依類別、介面後面是什麼。跟給使用者看的說明分開寫}.

**Reference (pasted in full: you have no other access to it):**
{它需要的那一段 skill 內容，從單一來源現貼}

**Vocabulary:** {這個 skill 的詞彙 + 專案 CONTEXT.md 的詞彙}.

**Constraint for this agent:** {只給這個 agent 的約束，用來逼出分歧}.

**Acceptance:** {可檢查、而且會失敗的條件}.

**Out of scope:** {別碰的東西}.

Cite the source for every claim.
Do not invoke {這個 skill} or spawn additional agents: perform this directly.
Report under {字數} words.
```

**出處分兩類**：
- **Matt 的做法**：
  - 參考整份貼上（code-review：「pasted in full (the sub-agent has no other access to it)」）；
  - 檔案路徑、耦合細節，且與使用者看的說明分開（DESIGN-IT-TWICE）；
  - 兩套詞彙都帶（DESIGN-IT-TWICE）；
  - 每個 agent 不同約束（DESIGN-IT-TWICE）。
- **【建議】**，不是任何上架 brief 的內容：
  - 禁止遞迴，是使用者對 code-review 與 research 事故的修法（D2）；
  - 要求附出處；
  - 字數上限。

**綁**：結果、驗收、範圍、出處、禁止遞迴、篇幅。**放**：實作與探索。

- 會擱置很久才被執行的 brief（貼在 issue 上等 AFK agent）要反過來：不寫檔案路徑與行號，寫介面與行為（B2-2、AGENT-BRIEF）。差別在它會不會在程式碼改變之後才被讀。

## F8. （v1 的發佈前檢查）

v1 在這裡有一份十七項的勾選清單。它已經改成兩個東西：
- Part 0 最後的完成條件（只針對草稿本身）；
- B5 的槓桿索引（每列預設「不用」）。

原因見 C4：勾選框的數量就是要求量，逐項勾會讓 skill 往「每條都加一點」的方向長。原本的每一項都還在：風格項在 A9，機制項在 B5。

## F9. 狀態工作區型

teach、loop-me、writing-beats / writing-shape / writing-fragments 都是這一型：跨好幾個 session，狀態存在一個目錄裡。

```markdown
---
name: {skill-name}
description: {給人看的一句話}, within this workspace.
disable-model-invocation: true
argument-hint: "{這次要做什麼，或什麼都不給}"
---

{工作陳述。This is a stateful request: {它會跨多個 session}.}

If the user did not say where to keep the work, ask once and remember the path.

## Workspace

The state lives in this directory:

- `{主檔}.md`: {它是什麼、用來做什麼}. Use the format in [{X}-FORMAT.md](./{X}-FORMAT.md).
- `./{產物目錄}/*.md`: {一個產物一個檔，怎麼編號}.
- `NOTES.md`: a scratchpad for the user's standing preferences and your working notes.

Create files lazily: only when you have something to write.

## {每次的循環}

1. Read the workspace first. The folder is the continuity, not the conversation.
2. {一次做一步}. Re-read the file from disk before every write; preserve the user's edits.
3. {寫入時機：當下寫，不要最後彙整}.
```

**綁**：
- 狀態只在目錄裡；
- 檔案清單在最前面，每種產物一份格式檔；
- 路徑問一次並記住；
- 寫之前重讀；
- 延遲建立。

**放**：每次循環要做什麼、內容。

出處：
- teach（檔案清單與 `NOTES.md`、「Never trust your parametric knowledge」）；
- writing-beats / writing-shape（「ask once and remember the path」「Re-read the file from disk before every write」）；
- writing-fragments（「Never overwrite the file; only append」）；
- `docs/productivity/teach.md`（「The folder is the continuity, not the conversation.」）；
- loop-me（`argument-hint` 連「不給參數」的分支都寫進去）。

**週期型：同一個檢查每隔一陣子重跑一次**【推論】

它不是一件跨 session 的連續工作（上面那一型），不需要整個工作區。跨次的記憶只要四件事：

- **被拒的不再提**：使用者拒絕、而且理由下次仍成立的，記下來；下次先讀，按概念比對（B2-14）。除非證據變了，否則不再提（本輪 X）。
  - Matt 的 triage 用 `.out-of-scope/` 做同一件事。
  - improve-codebase-architecture 用 ADR：「so future architecture reviews don't re-suggest it」。
- **基準點**：報告寫明這次看的是哪個 commit（本輪 X：「Surveyed: … at {commit}」），下次才知道什麼變了。
- **覆蓋紀錄**：Surveyed / Not surveyed / Left alone（B4-0），下次從沒看過的地方開始。
- **找得到**：放在 repo 既有的決策位置。使用者自選位置時，用可以 grep 的前綴（本輪 X：標題以 `Declined:` 開頭，是 B1-19 的變形）。

## F10. 零件拼接表

每一塊都可以單獨拿去用。挑哪幾塊，由 Part 0 第 1 步的預設決定。

| 零件 | 在哪一份骨架裡 | 什麼時候拿 |
|---|---|---|
| 開頭：定義 + leading word | F1、F2、F3 | 這個 skill 有一個模型已經懂的詞可以承載它 |
| 開頭：工作陳述 + 一句不做什麼 | F4 | 預設是「多做一步」（例：又去訪談使用者） |
| 硬依賴一行 | F4 | 沒有那份設定，輸出就是錯的 |
| 軟依賴一句 | F2 | 有那份文件會更準，沒有也能跑 |
| 呼叫 reference skill 的一行（含「a reference to consult, not a session to run」） | F4 第 3 步 | 要借另一個 skill 的詞彙 |
| 關卡：This is the skill + 完成條件 + 做不到時停 | F2 Phase 1 | 預設會跳過這一步 |
| 預設的失敗在關卡上寫一次 | F2 Phase 1 | 你知道它會怎麼偷跑 |
| 分流：Pick a branch + When this is the right shape | F3 | 兩條路產出不同東西 |
| 候選 + 可證偽 + 給人看 + AFK 預設 | F2 Phase 2 | 預設會錨定在第一個想法 |
| 寫死的問句 + iterate until approved | F4 第 4 步 | 人要在這裡決定，而且預設有已知的偏向 |
| 產出 template + 外部限制 + 例外 | F4 第 5 步 | 下游要讀這份產物 |
| 格式檔 | F6 | 附帶產物有自己的規則與「什麼時候寫」 |
| 機械收尾清單 | F2 Cleanup | 有暫時留下的東西要清掉 |
| sub-agent brief | F7 | 要派 sub-agent |
| 工作區 + 寫前重讀 | F9 | 跨 session |
| 跨次紀錄：被拒的不再提、基準 commit、覆蓋紀錄 | F9 週期型 | 同一個檢查每隔一陣子重跑 |
| 證據欄位 + 等級的成立條件 + Also noticed / Left alone | F4 的 template（照 B4-0 補欄位） | 產物要讓人查得了，而且候選清單要保持短 |

**例：先分流、其中一條有關卡**（i18n 這類 skill）：F3 的開頭與 Pick a branch，加上 F2 的 Phase 1 放進需要它的分支檔，再加 F4 的硬依賴一行。

## F11. 走讀：to-tickets 的結構

用短引文走一遍一份真實的 Matt skill（`engineering/to-tickets/SKILL.md`，user-invoked），看每一塊綁什麼、放什麼。這不是複製品；原文要不要整份帶進來，見附錄 P。

| 區塊 | 原文（節錄） | 綁／放 |
|---|---|---|
| frontmatter | `disable-model-invocation: true`；description 是一長句，說它把什麼切成什麼、兩種 tracker 下 blocking edge 各長什麼樣子 | user-invoked，description 給人看（D1） |
| 開頭 | 「Break a plan, spec, or conversation into a set of **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it.」 | 定義 + leading word（A2）。**tracer bullet** 對準的預設是一次切一層（Part 0 第 1 步） |
| 硬依賴 | 「The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.」 | 綁：沒有 tracker 設定，發佈就是錯的（D2） |
| 1. Gather context | 「Work from whatever is already in the conversation context… fetch it and read its full body and comments.」 | 綁證據來源（B1-30）；放：從哪裡開始 |
| 2. Explore (optional) | 軟依賴「use the project's domain glossary vocabulary, and respect ADRs」；「"Make the change easy, then make the easy change."」 | 放：探索是選配；格言當 leading phrase（A3） |
| 3. Draft vertical slices | `<vertical-slice-rules>` 四條；**blocking edges**；**wide refactor** 例外與 **expand–contract** | 綁：切法規則用 XML 包起來；例外用自己的 leading word 放在規則旁（B2-18） |
| 4. Quiz the user | 每張票列 Title / Blocked by / What it delivers；三個寫死的問句；「Iterate until the user approves the breakdown.」 | 綁：確認點與問句，問句對準過度切分（B2-34、B4）；放：答案 |
| 5. Publish | 依 tracker 分兩條：本地一票一檔 `<NN>-<slug>.md`、真 tracker 用原生 blocking；「Work the **frontier**」；「Do NOT close or modify any parent issue.」 | 綁：產物形狀、編號是給指令用的 ID（B1-28）、不可逆護欄（C7） |
| 兩份 template | `<local-ticket-template>`、`<issue-template>`，佔位是意圖句（「the end-to-end behaviour this ticket makes work, from the user's perspective, not a layer-by-layer implementation list」） | 綁形狀，放內容（E3） |
| 收尾限制 | 「In either form, avoid specific file paths or code snippets: they go stale fast. Exception: if a prototype produced a snippet…」 | 規則 + 理由 + 例外（B2-18） |

**已知缺口**：驗收條件沒有要求「在起點 commit 必須是假的」（E4、附錄 G）。
**它沒有的東西**：Anti-patterns 一節、Why 一節、skill 自己的 Out of scope。垂直切片只在規則裡正向寫一次，沒有再寫成 anti-pattern。

---

# 附錄 G　Matt 自己的已知坑（別照抄）

拿 Matt 的檔案當範例時，這些地方不要照抄。分兩類：Matt 的 repo 自己承認的，和我讀出來的。

### G-a. Matt 的 repo 承認的

| 坑 | 位置 | Matt 那邊的紀錄 |
|---|---|---|
| `GLOSSARY-FORMAT.md` 沒被 SKILL.md 連到，模型讀不到 | productivity/teach/ | issue #559 |
| description 還寫「red-green-refactor」，本文已刪 refactor | engineering/tdd/SKILL.md | issue #589 |
| `./` 同時指 skill 目錄與使用者目錄 | productivity/teach/SKILL.md | issue #377 |
| 派 sub-agent 沒禁止遞迴 | code-review、research | `docs/engineering/code-review.md`「Neither is in the shipped skill yet」；research #530 |
| 覆寫條款放在 agent 自己寫的 Notes | wayfinder | `docs/engineering/wayfinder.md` |
| reference skill 被當流程跑；成因是沒有流程也沒有停止規則，自我描述擋不住 | codebase-design | issue #449（仍開著），修法是指定 driver skill |
| 候選 seam 只給名字不給取捨 | tdd | issue #607 |
| 驗收條件沒要求會失敗 | to-tickets 的 template | `docs/engineering/to-tickets.md` |
| 測驗答案永遠在第一個選項 | teach | issue #335，「still unfixed」 |
| router 回報 user-invoked skill 沒安裝；router 用自己的摘要描述別的 skill | ask-matt | `docs/engineering/ask-matt.md`（兩條都「unfixed」） |
| 對簡單問題過度啟動 | diagnosing-bugs | issue #578，修法「has not landed」 |

### G-b. 我讀出來的【推論】

| 坑 | 位置 | 依據 |
|---|---|---|
| 寫 `/tdd`、`/code-review` 而非 `Call the Skill tool` | engineering/implement/SKILL.md | 兩者都是 model-invoked，依 `.agents/invocation.md` 應寫成呼叫 Skill 工具 |
| router 仍把 diagnosing-bugs 的 post-mortem 導向 improve-codebase-architecture | ask-matt/SKILL.md（「Its post-mortem hands off to /improve-codebase-architecture」） | `.changeset/user-invoked-skill-invocation.md` 已把那個交接整段刪掉：這正是 `CLAUDE.md` 說的「a router that lies」 |
| 設定路徑仍寫死 | code-review/SKILL.md（「If `docs/agents/issue-tracker.md` is missing…」與找 spec 的第一步） | #472 為 wayfinder 修過同一件事（D4） |
| 說明頁落後於 SKILL.md | `docs/engineering/diagnosing-bugs.md`（說秘密不會被遮蔽，但 SKILL.md 已有 Redact 一節；也仍寫 post-mortem 導向 improve-codebase-architecture）、`docs/engineering/improve-codebase-architecture.md` 與 `docs/engineering/codebase-design.md`（仍點名 Claude Code 的 `Agent` 工具，1.2.3 已拿掉）、`docs/engineering/wizard.md`（時間估計的描述） | 說明頁是二手整理（§0） |
| 強度等級只有名字、沒有成立條件；SKILL.md 的「Benefits」與 HTML-REPORT.md 的「Wins（≤6 個字）」定義同一欄卻不同 | improve-codebase-architecture | 本輪驗證（`judge/verdict.md`）：刪死檔拿到 Strong；runner 只能挑一份照做 |
| 「Do NOT propose interfaces yet」卻強制每張卡畫 after 圖；標題點名修法；沒有唯讀條款 | improve-codebase-architecture | 本輪驗證：runner 自己劃界線；在人挑之前錨定答案；sub-agent 在唯讀環境跑了測試 |
| ADR 三條判準寫了兩次 | domain-modeling/SKILL.md 與 ADR-FORMAT.md | C8 的 single source |
| description 只有「Use when…」，沒說它是什麼 | resolving-merge-conflicts/SKILL.md | D1 的 description 寫法 |
| 觸發詞用同義詞堆疊（「"diagnose"/"debug this"」「broken/throwing/failing/slow」） | diagnosing-bugs/SKILL.md | C1「One trigger per branch」 |
| 佔位語法 `{}` `<>` `[]` 混用 | 各 template | E6 |
| 空格連字號留在原處，是 em-dash 規則禁止的盲換 | handoff、teach、to-spec | A4 |
| `misc/` 多是舊寫法：同義詞觸發、`## Steps` 加勾選清單、指令逐條列 | skills/misc/ | 但 `## Steps` 本身不代表舊：in-progress 的 setup-ts-deep-modules 也用 `## Steps`。舊的是整體組合 |

---

# 附錄 K　篇幅參照

**篇幅跟著關卡與 template 走，不跟著類別走。這不是目標。** 決定一句話該不該留的是 no-op 測試（C8），不是行數。這張表只讓你知道「預設動作是刪」（B0）大概落在什麼尺度。數字是 1.2.3 版 SKILL.md 含 frontmatter 的行數。

| 形狀 | 例子 | 行數 | 為什麼是這個長度 |
|---|---|---|---|
| 一行轉交 | grill-me、grill-with-docs、wait-what | 7 | 只有一句呼叫，或一段使用者口吻的話 |
| 背景派工 | research | 12 | 三步，其餘交給背景 agent |
| 純步驟 | resolving-merge-conflicts | 14 | 五個編號步驟，沒有開頭 |
| 沒有 template 的 orchestrator | implement | 15 | 全部委派給別的 skill |
| 沒有步驟的產出 | handoff | 16 | 五句約束 |
| 靠模型已懂的迴圈的紀律 | grilling、tdd | 28、38 | leading word 取代了步驟（B2-1） |
| 分流入口 | prototype | 26 | 本檔只有分流與共用規則，兩條分支在旁檔 |
| 關卡型紀律 | diagnosing-bugs | 138 | 每個階段一道關卡，加上十種回饋迴圈的排序 |
| reference | codebase-design | 114 | 詞彙表、原則、關係、被否決的框架 |
| 帶 template 的 orchestrator | to-tickets、triage、wayfinder | 105、112、128 | 內嵌 template，其餘參考推到旁檔 |
| 狀態工作區 | teach | 140 | 檔案清單、哲學、循環 |
| 參考型的寫作理論 | writing-for-agents | 81 | 參考，另有一份旁檔 |

**本輪驗證：多出來的篇幅從哪來**（`build-D1/notes.md`、`build-D2/notes.md`、`judge/verdict.md`）

同一件工作（解 merge / rebase 衝突）：Matt 原檔 14 行；照 v1 寫的 D1 是兩檔共 117 行；照 v2 寫的 D2 是一檔 70 行。D2 的對照跑（附錄 T2）顯示，多出來的部分在這個三情況的 fixture 上沒有被用到（D2 自己寫：fixture 可能太簡單，這一點沒驗）：

- **模型本來就會的領域知識**：ours/theirs 對照表、diff3、stage 編號、`log --merge`、在 rebase todo 插 `exec`。baseline 沒有這些，也把相容衝突與語意斷裂處理對了。更難的情況（diff3、rebase 中跑檢查）這次沒測。
- **綁在沒出現的預設上**：「讀兩個 intent」那道關卡是承重步驟，這次沒有觀察到它改變行為。
- **冷讀之後往上加**：D2 照冷讀改了五處，C2 也是一條一條補；每一處都讓檔變長，改完都沒有再跑。
- **報告 template**：沒有單獨驗過。
- **唯一量到的行為差異**是「兩邊不相容時停下來問」，而那正是 Matt 原檔選擇不做的事（B4「使用者不在時」）。
- D1 的作者寫：「文件的篇幅本身在推我往長寫」。

篇幅本身不是判準。
- X（SKILL.md 154 行加一份格式檔）比 Matt 的 improve-codebase-architecture（71 行加 6.6 KB 的 HTML-REPORT.md）長，評審卻認為 X 的約束成本較低。差別在那些行綁的是證據還是版面（B4-0）。
- 行數只能比換行習慣相同的檔。C2 的段落沒有硬換行，行數不能跟這張表直接比（`build-C2/notes.md`）。

【推論】要縮，先刪 baseline 已經做對的部分，再刪對照跑證明模型本來就會的領域知識。剩下的，用 C8 的 cache 判準（「the gotcha no config confesses」）決定留不留。

反例要一起看：
- 紀律不一定短（diagnosing-bugs）；
- orchestrator 不一定長（implement）；
- 參考不一定短（codebase-design）。

---

# 附錄 P　待決事項（等擁有者決定）

下面這些不是我能替擁有者決定的。在決定之前，這份文件不收 Matt 的原檔全文，只收引文。

### P1. 要不要把 Matt 的 skill 全文當範例帶進來

Matt 的 repo 是 MIT 授權，帶進來要附授權與出處，並固定在 1.2.3 版。要決定的除了授權，還有「複製他的檔案」算不算違背「不靠 Matt 的 plugin」這個目標。

如果要帶，我會挑這幾份，理由是每份示範一種這份文件用引文教不完整的東西：

| 檔案 | 為什麼 |
|---|---|
| `productivity/grilling/SKILL.md` | 很短的紀律；輪次格式；事實與決定的分工 |
| `engineering/prototype/SKILL.md` + `LOGIC.md` | 分流入口；When this is the right shape；Anti-patterns；預設加說出假設 |
| `engineering/to-tickets/SKILL.md` | 帶兩份 template 的 orchestrator；寫死的問句；例外用 leading word 命名（F11 走讀的對象） |
| `engineering/diagnosing-bugs/SKILL.md` | 每階段都是關卡；承重那一道的標記；可清理的記號 |
| `engineering/tdd/SKILL.md` | leading word 取代步驟之後剩下什麼；anti-pattern 重述主要失敗 |
| `productivity/wait-what/SKILL.md` | 一段話的 skill；使用者口吻；命名聽者的狀態 |
| `productivity/handoff/SKILL.md` | 沒有步驟的產出型 skill |
| `engineering/domain-modeling/ADR-FORMAT.md` | 最小的格式檔 |

理由的共同點：語氣要從整份文字學，碎片學不到（A8「給寫好的完整樣本」本身就是這個主張）。每份都要附一段短註，說明哪裡綁、哪裡放。

### P2. 要不要把理論原文帶進來

候選：`writing-for-agents/SKILL.md`、`SKILL-MECHANICS.md`、`.agents/invocation.md`、`.agents/writing-docs.md`。
- 帶進來的話，Part C 可以縮成一張「Matt 的詞 → 這份文件的條目」對照表，因為轉述本身就是第二份來源，會漂移（C8）。
- 不帶的話，Part C 的轉述就是讀者唯一的一份，所以現在保留全文轉述，並在每個詞引用 Matt 的定義句。

### P3. 照 Matt 的領域內容寫，算風格還是算照抄

build-C1 直接用了 Matt 的 seam 定義、deletion test、`Strong / Worth exploring / Speculative` 三級名稱。這份文件沒劃這條線。

### P4. Negative Space 留不留

它不在 Matt 的現行文字裡（C7），這份文件把它留作 Part 0 第 4 步的名字，並標明來源狀態。

### P5. 偏離 Matt 的做法時，文件要不要站在擁有者那一邊

本輪 D2 唯一量到的行為差異，是「兩邊不相容時停下來問」，而 Matt 的 resolving-merge-conflicts 選擇讓 agent 自己挑、再記下取捨（B4）。擁有者自己的慣例是「決定歸人」。
這份文件要不要在這類分歧上預設擁有者的立場，還是只把兩邊都寫出來，是擁有者的決定。目前是只寫出來。

### 升級成 skill 時要注意的（不是待決，是提醒）

- Part 0 會成為 `SKILL.md` 本體，其他 Part 成為旁檔（開頭那張表）。
- 附錄 K 要從 Part 0 第 5 步指過去，否則它是沒有 pointer 的內容。
- 這份文件是繁體中文。skill 本文要用什麼語言，照擁有者自己的慣例。

---

# 附錄 S　來源與覆蓋

**來源**：plugin `mattpocock-skills` v1.2.3。

**v1 全文讀過的**：
- 全部上架 skill 與旁邊每個檔；`in-progress/`、`misc/`。
- repo 層：`CLAUDE.md`（`AGENTS.md` 是它的軟鏈）、`CONTEXT.md`、`README.md`、`CHANGELOG.md`、`.changeset/`、`.out-of-scope/`。
- `.agents/`：`invocation.md`、`writing-docs.md`、`install-block.md`、兩則 ADR。
- `docs/` 下全部說明頁。

**沒全文讀的**：
- `wizard/template.sh` 與 `hitl-loop.template.sh` 的函式本體（只看了檔頭與分界標記）；
- `dependency-cruiser.config.cjs`、`scripts/*`、`plugin.json`、`package.json`、CI 設定；
- 多數 `agents/openai.yaml` 的內容（只知道它們的角色與 `policy` 欄位）。

**v1、v2 沒做**：實際跑任何 skill。這兩版寫的是「Matt 怎麼寫、他為什麼這樣改、使用者回報了什麼」，不是「這樣寫一定有效」。

**v3 跑過的**：兩組 n=1 的對照（附錄 T2）。
- v2 的 Part 0 被兩位 builder 用來寫過 skill（C2、D2）。
- v3 修訂後的 Part 0（加了 baseline 那一步）還沒有被用過。

**審查**：
- v1 經過一輪對抗式審查：
  - 一份逐句的引文與主張查核（對 1.2.3 原文）；
  - 一份批評（拿三個照 v1 寫出的 skill 與 Matt 的原檔比）；
  - 三位只讀 v1 就動手寫 skill 的人回報的模糊與矛盾；
  - 修訂者對有爭議的主張逐條回原文查過。
- 查核那一方沒讀 `agents/openai.yaml` 的內容、`dependency-cruiser.config.cjs`、`scripts/*`、`plugin.json`、`.github/`，也沒執行任何東西。
- 批評那一方大部分 SKILL.md 沒有全文讀。
- 三位寫 skill 的人裡，有一位的題目（to-tickets）正是 v1 大量引用的 skill，所以那一份產物像 Matt，有一部分是文件剛好收了同名 skill 的碎片，不能拿來證明文件教得好。
- **v3 依本輪驗證修訂**（附錄 T2）：兩組 n=1 的實跑、一位盲評、三位 builder 的回報。v3 新寫的部分是：
  - Part 0 的 baseline 步驟；
  - B4-0、規則衝突順序、探索型 skill 的停止條件；
  - E2 的新判準；
  - F9 週期型；
  - 附錄 K 的篇幅分析；
  - 附錄 T。

  交稿時這些都還沒有人審過。
- **v2 改寫後的文字本身沒有再外審。** 新加的段落（Part 0、A0、B4 的改寫、B5、D7、D8、F9、F10、F11、附錄 K 與 P）是修訂者寫的，是最需要下一輪查的地方。

---

# 附錄 T　測試協定與本輪驗證

## T1. 怎麼跑一次對照【建議】

產物小、一次寫完、錯了便宜（handoff 那一類）時，一次冷讀就夠，不必架 fixture；Part 0 第 1 步照「推的，沒驗」交代。

builder 三次問「no-op 測試實際怎麼跑」（`build-C2/notes.md`、`build-D1/notes.md`、`build-D2/notes.md`）。下面是本輪實際用過的做法。

1. **fixture**：一個可以重建的小情境（拋棄式 repo、一份假資料）。至少放三種情況：
   - 你推的那個預設會出錯的情況；
   - 一個屬於使用者的決定；
   - 一個模型本來就該做對的情況。這是對照組：連它的行為都變了，skill 就是在亂綁。

   任務本來就要讀真 repo 時（盤點、review），用真 repo 的一個固定 commit，唯讀。
2. **兩份獨立副本**：一份給沒有 skill 的 agent（baseline），一份給讀了 skill 的 agent。同一個模型、同一句任務描述。
3. **runner 停在第一個要使用者決定的地方**，把問題寫出來，不替使用者模擬回答。另外記一份 trace：讀了什麼、做了什麼、在哪裡猶豫。
4. **硬邊界要查**：唯讀的任務，就在開工與收工各看一次 `git status`（或等價的檢查）。
5. **比較**：逐個 fixture 情況，看兩份的行為差在哪。行為只該在你綁的地方不同。
   - 綁了卻沒差：no-op 候選（Part 0 第 5 步）。
   - 沒綁卻有差：去找是哪一句在起作用。
   - baseline 本來就做對的：那一部分不綁。
6. **同時比多份 skill 時用盲評**：
   - 評審不知道哪份是從哪來的；
   - 評分標準事先寫好，並寫明它偏向什麼；
   - 評審逐條回 repo 查核產出裡的主張，不是看讀起來像不像；
   - 排名寫成判斷，不寫成事實。
7. **限制照實寫**：各跑幾次、幾個模型、幾位評審。n=1 的結果只說「在這個 fixture、這個模型上」。不要反覆改到跑出乾淨為止（B3「評審與收斂」）。

## T2. 本輪驗證跑了什麼、看到什麼

兩組都是 n=1、一位評審，沒有外審。

**盤點型**（`judge/verdict.md`；三份的輸出與 trace 在 `run/`、`judge/`）
- **任務**：定期盤點 codebase 的結構重構候選，讓使用者挑一個，再想清楚成決策。唯讀，停在第一個使用者決定。
- **三份 skill**：X 照 v2 寫、Z 照 v1 寫、Y 是 Matt 的 improve-codebase-architecture 原檔。各在同一個真 repo、同一個 commit 上跑一次。
- **結果**：盲評排名 X > Z > Y，X 與 Z 在誤差內。三份的具體主張，評審查過的全部屬實；差別在取捨與框法，不在真假。
- **評審自己寫明的限制**：
  - 換一位看重「停點」或「第一手證據」的評審，可能把 Z 排第一；
  - 評分標準對準的是證據有沒有被綁住；
  - Y 的設計是把後續交給其他 skill，這次只跑到它停下的地方。
- 評審的五條教訓寫在 B4-0。
- **不該被排名蓋掉的**：Y 找到兩條另外兩份都沒找到、查證屬實的潛在 bug。它的做法是 sub-agent 先走訪、主線再抽查。
- X 與 Z 的題目都是 v1、v2 常引的 improve-codebase-architecture 的同類，產物像 Matt 有一部分來自文件收的碎片（`build-C2/notes.md`）。

**執行型**（`build-D2/notes.md`）
- **任務**：解 merge / rebase 衝突。
- **fixture**：一次 rebase 的三個 commit：
  - 相容的文字衝突；
  - 文字上乾淨、但另一邊已改名而會壞的呼叫；
  - 兩邊互斥的設定值（EUR 對 JPY）。
- **結果**（baseline 與 with-skill 各跑一次）：
  - 前兩個情況兩份都做對了。
  - 第三個情況，baseline 自己選了一邊並 `--skip` 掉另一邊（有揭露、留了備份分支）；with-skill 停下來問。
- 作者在 Part 0 第 1 步推的預設沒有出現。
- 冷讀提出五處修改，已照改，改完沒有再跑。
- **綁住的步驟輸給了 baseline**：skill 原稿規定「在這一站修」語意斷裂。對照跑之後改成「在引入它的 commit 修」，作者寫：「baseline 的做法其實比我原稿好」（`build-D2/notes.md`）。這是本輪最直接的一例：綁住的程序可能比模型自己的做法差。
- 同一件工作，照 v1 寫的 D1 沒有做對照跑，只驗了 skill 裡的 git 指令（`build-D1/notes.md`）。

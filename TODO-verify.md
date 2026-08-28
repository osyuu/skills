# 待驗清單 — `379d402` 的 10 條修正

**這批修正沒有經過外審。** 它們是照 `review-tail` 的對抗式報告做的，報告本身審的是
`a593275..90ca7c0`（`backup-before-tidy`），**不含這些修正**。換一台 PC 接手時，
從這份清單開始，不要從「測試綠」開始——這批東西的每一個洞都是在全綠的情況下活著的。

改動範圍：`git show 379d402`，五個檔——
`skills/harness/repo-onboard/SKILL.md`、
`skills/harness/arch-guard/{assets/arch-guard-check.sh,scripts/install.sh,tests/run.sh}`、
`skills/workflow/dev-loop/SKILL.md`。
（`6e9dea6` 是 `93b370c` 的 reword，內容 diff 為空，不用重看。）

**2026-08-28 第二輪**：七條待驗全部跑過，兩條是真的、五條清白（下面逐條記結論與方法）。
兩條「還沒做的」也做了。**這一輪同樣沒有外審**——驗證與修正是同一個人做的，
而作者驗證不了自己沒想到的東西。

## 已經跑過的（不用重跑，除非要挑戰結論）

- 七支 skill 的 `tests/run.sh` 全綠：arch-guard 51/0、claim-check 95/0、
  claude-md-hygiene 33/0、comment-budget 26/0、harness-audit 36/0、
  sdd-harness-init 14/0、handoff 9/0
- 六支突變全綠：arch-guard 21/0、claim-check 40/0、claude-md-hygiene 10/0、
  comment-budget 6/0、sdd-harness-init 3/0、hooks 28/0
- `hooks/tests.sh` 29/0

**全綠證明不了這批是對的**——`harness-audit` 量過同一個 repo：190 條斷言綠著，
同時有 8 個 P0 活著,因為 fixture 用的正好是 pattern 清單寫的時候看的那兩個技術棧。

## 七條的結論

### 1. §3 的數字綁死在單一 repo — **成立，已改**
在這台機器的十個 repo 上重量：副檔名 6–43 種、top-level 目錄 1–7 個（原文那個是 16，
是唯一的離群值），`≥3` 砍掉的比例 38%–70%。原文把單一 repo 的總數寫成可對照的預期值，
差一個數量級。**界線 `≥3` 保留**（`writing-for-agents` 要的可判定性在那條規則上，不在總數），
把總數改寫成「量到的範圍」。

### 2. `grep -Fxv -f` 的邊界 — **清白**
實跑四種：空 pattern 檔（BSD 印出全部，方向安全）、`/dev/null` 同上、
路徑含空白／反斜線／非 ASCII（`-F -x` 是固定字串全行比對，全部正確）。

### 3. `awk` 抓不到 `—` / `TODO` / `?` — **成立，已改**
另外量到一件原文沒說的：`cut -f1` 對**沒有 TAB 的行**輸出整行，於是純路徑會被第一條
算成「已歸類」——那種只有 `NF < 2` 看得到。佔位符那串補進 pattern，`dart 測試`、
`flutter test` 這種真歸類不受影響（實跑確認）。**有字但等於沒歸類仍然填得出新花樣**，
這條擋的是已知的那幾種。

### 4. `$G` 的 word-splitting — **成立，是實錯，已改**
zsh **不對未加引號的參數展開做字詞切分**，整串被當成一個指令名：
`zsh:1: no such file or directory: git -c core.quotepath=off ls-files --full-name :/`。
sh／bash 正常，所以讀 code 看不出來。改成 shell 函式，在 sh／bash／zsh ×
`set -u` × `set -f` × `EXTENDED_GLOB` × `IFS=,` 下全部實跑通過。

### 5. arch-guard audit 的非零路徑 — **主結論成立，「沒有第三種」不成立**
- 已填 conf ＋ 有違規時 audit 仍 exit 0（尾端無條件 `exit 0`）→ install.sh
  那句「A non-zero exit means step 1 is not finished」在**正常路徑上**成立。
- **「沒有第三種非零路徑」是錯的**（review 抓到）。至少三條：conf **不可讀**時
  `.` 失敗使 shell 直接中止，audit rc=1 **而且一個 arch-guard 訊息都沒印**——那句
  install.sh 的話在這條路上是誤導；conf 裡有 `exit 3` 則 rc=3 原樣傳出。
  conf 有語法錯誤時變數全沒設，現在會被下面那道閘攔下並回非零，但訊息說的是
  「沒有規則會跑」而**真正的原因是語法錯誤**。
- **新洞**：模板允許不適用的欄位留空，於是「沒有任何規則會跑」是打得出來的狀態，
  而那時每個迴圈都不會進去、尾端照印「共 0 條違規」exit 0——與真的乾淨一模一樣。

### 6. `tests/run.sh` 新加的兩條會不會污染後面 — **結論成立，理由原本寫錯**
- 換成 `exit 1` stub 的那份是 `newrepo2` 開的獨立沙箱，而且是檔案裡最後一條斷言，
  後面只剩 `cd "$WORK"` 與統計。沒有後續使用者。
- 原本寫的理由「每個 `cd` 都帶 `|| exit 1`」**字面不成立**（review 抓到）：檔裡有
  十個 `cd` 沒帶。它們安全是因為全在 `$( )` / `( )` 子 shell 裡且用 `&&` 串——
  失敗就不會執行、也污染不到父層 cwd。**理由寫錯的代價是下一個在頂層加 `cd` 的人
  會以為有人在守**，所以這裡改正。
- 順帶修掉：`_sb`/`_sb2`/`_sb3` 原本開在 `$TMPDIR` 靠明寫的 `rm -rf` 收，
  中途中斷會留下三個目錄；改開在 `$WORK` 底下，由既有的 `trap` 收。

### 7. dev-loop 的新措辭有沒有製造死結 — **成立（措辭），已改**
沒有死結，但原文要求「知道哪一輪是最後一輪」，而那只有事後才知道。
改成「**每一輪 review 派出去之前**清 warn」：review 提的修正本身是 review 之後動的
code，照〈完成的定義〉第 2 條本來就要再派一輪，那一輪的「派出去之前」就是清它的位置。
「最後一次」變成結果而不是前提。

## reviewer 自己標的未驗項

- `claim-check`〈正確性宣稱〉**已實跑 hook 驗過**（不是讀判定式）：造一份
  「Edit 之後下正確性結論、沒派過 agent」的紀錄，走真正的 stdin JSON 路徑，
  中文（`可以 merge`）與英文（`safe to merge`）都開火，log 也寫進去了。
  （驗完把兩行 `probe` 紀錄從 `~/.claude/claim-check.log` 移掉。）
- **Linux 仍全部沒驗**：這台沒有 docker／podman／colima，起不了 GNU coreutils 的環境。
  `sed`／`uniq`／`grep -f 空檔`／`cmp` 在 GNU 下的行為仍是推論。
- `sdd-harness-init` 的 description 加 `ADR` 那行仍只讀了字面、沒測觸發率。
- 日文／英文 trigger 用詞是否地道，**仍需母語者或另一台**。

## 「還沒做的」兩條 — 都做了

- **`claim-check` 的宣稱詞表只認中文**（`harness-audit` 實測的 P0：只認一種語言的規則，
  在另一種語言的 session 永遠零開火）。六條規則 ＋ CHALLENGE ＋ NAMED 副檔名全部
  改成「內建 ＋ conf 附加」，內建補上英文，conf 鍵是 `CLAIM_*_CLAIM_RE`。
  安裝器現在也把 conf 模板佈到 `~/.claude/claim-check.conf`（不覆蓋）——**沒佈出去的話
  這條路只存在於 SKILL.md 裡等人去找**，而它守的正是「恆不開火」那一半。
  - **英文那半沒有真實 session 的校準基準**：這台的紀錄全是中文 session。
    量得到的只有「英文詞表沒有在中文 session 上多開火」（128→129/656）。
    reviewer 進一步量出這個數字的**樣本數**：2637 段 assistant 文字裡，19 條英文
    alternative 總共只匹配 17 次，其中 14 次是舊版就認得的 `BUILD SUCCEEDED`——
    真正「新變得認得」的只有 **3 段**。所以那是三個資料點的量測，不是 656 回合的。
    **英文 session 的誤判率仍然量不到，換一台請在英文 session 上回放再收緊或放寬。**
  - 英文那半收得比中文緊是刻意的（要求帶受詞或狀態詞），三條反例是那個要求的守護者。
- **`sync-check.sh` 不涵蓋使用者層的部署副本**。加了 `UPAIRS` 那半：
  不存在＝沒裝，不出聲；存在且不一致才出聲並給 cp 指令；另有反查抓沒登記的。
  跑起來當場抓到 `~/.claude/hooks/claim-check.py` 落後來源 83 行（就是 TODO 說「今天犯過」
  的那次），已 `cp` 同步。測試用 `SYNC_CHECK_HOME` 隔離，**否則這支測試會去量這台機器
  實際裝了什麼**，換一台就換一個結果。

## 第二輪外審（`626ae93`，兩個唯讀 agent）

`review-shell` 交回 2 個 P1 ＋ 10 個 P2，全部重現後修掉；四項判斷被它逐條攻不破
（`$G` 的五個 shell 維度、dev-loop 的收斂性、數字改寫的可判定性、`SYNC_CHECK_HOME`
的隔離是承重的）。**最貴的一條是我自己引入的**：

- **P1-1 新閘誤殺 `PARTITIONED`-only 的 conf**。sibling 那半只看 `PARTITIONED`、
  **與 `LAYERS` 無關**，而我的條件只看 `LAYERS` 與 `CHOKEPOINTS`。一份抓得到
  sibling 違規的 conf 被整個關掉，warn 模式下畫面只有一行 stderr——我加的守門
  變成了它自己要防的那個東西。判準改成**「這次執行會不會發出任何一次 git grep」**：
  分層要 ≥2 層、`PARTITIONED` 非空、`CHOKEPOINTS` 有有效規則，三者皆不成立才出聲。
- **P1-2 單一 layer 等於零檢查**（`higher` 恆空），而我為了修測試把 `LAYERS_V`
  改成 `"core"`，正好讓那條斷言躺進零檢查狀態、斷言一個必然。改成兩層 ＋ 期望
  `共 1 條違規`。
- P2-3 `all::::::label`（pattern 欄空）被靜默 `continue`；現在出聲。
- P2-4 `$HOME` 未設 ＋ `set -u` → sync-check 在算 `UROOT` 那行整支中止，而 repo
  那半已印完、pre-commit 又是 `|| true`——畫面跟正常一模一樣。改 `${HOME:-/nonexistent}`。
- P2-5 **`—` 放進 `[...]` 在 `LC_ALL=C` 下失效**（bracket expression 是位元組集合），
  於是 SKILL.md 那段點名要擋的 `sed 's/$/\t—/'` 鑽法從 C locale 穿過去。移出自成分支。
- P2-11 ROOT 打錯一個字時每條 grep 都配不到而 stderr 被吞，同樣印「共 0 條違規」。加檢查。
- P2-8/P2-9 六條注入全綠（無守護者）＋ 兩條注入因錯的原因轉紅。測試 44→51、
  注入 15→21；hooks 測試 26→29、注入 25→28。
- 修 P2-11 時**新的 ROOT 閘遮住了既有的 `<TODO>` 守護者**（模板的
  `ROOT="<TODO-source-root>"` 讓 ROOT 的訊息也含 `<TODO`，needle 太寬）——
  注入當場抓到，needle 收緊成「還有未填的 `<TODO>`」。

`review-regex` 交回 4 個 P1 ＋ 6 個 P2，五項判斷被它逐條攻不破（25 處
`(?i:)` 改寫做了結構／差分／大小寫翻轉三種核對後 0 差異；NAMED 擴張的
128→129 它自己重跑後確認、並用「把副檔名還原成 `swift|dart`」證明那個 +1
與擴張無關；`${3:-…}` 在四種 shell 下正確；`zig)|(evil` 是出聲不是靜默；
模板 11 個 key 的例子除 `make` 外全部實跑可用）。

- **P1-1 repo 那份 conf 的空值靜默蓋掉使用者層**。`setdefault` 對「存在但空」
  一樣登錄，而模板是整份含全部 key 的——**把模板複製到 repo ＝ 清空 home 的全部
  設定**，而這次 commit 正好教人這樣做。空值不再登錄。
- **P1-2 測試不隔離 `$HOME`**，所以「沒有 conf 時認不得 X」那幾條會在**填過 conf 的
  機器上**紅，而這台剛好全綠只因為那份 conf 現在是空的；`mutants.sh` 的基準檢查會
  直接 `exit 2`，整套突變在那台機器上永遠跑不起來。**與 GIT_DIR 是同一個形狀，
  換了個變數名。** 兩支測試都改成 export 一個空的 `CLAIM_CHECK_HOME`。
- **P1-3 英文誤中，十種形狀十中十**（`I have not committed the changes`、
  `Their README claims all tests pass`、`Is it fixed?`、`I merged the two config files`）。
  中文靠「已經／了／完」標記完成態，英文沒有，只能反過來排除：加一層**句子層的
  否定／疑問／轉述過濾**，hedge 只回看到**子句邊界**（整句回看會把
  「如果你想先收工，現在是個乾淨的斷點：測試全綠」整條吃掉）。受詞也從
  `the [a-z]+` 收斂成版控名詞。
- **P1-4 恆不開火的殘量**：`lgtm` 小寫 MISS（`LGTM` 留在中文那條 branch、大小寫敏感）、
  `All 75 tests pass.` MISS、`Pushed to feature/x.` MISS。補上，並在 SKILL.md 明說
  **英文內建也只是起點**——原本的措辭讀起來像英文已經蓋好了。
- P2-1 conf 行內註解被吃進 pattern；P2-2 壞 regex 在 import 期 raise → **整支 hook
  一起死**，而 Stop hook 死掉跟沒裝一樣；P2-3 值尾端一個 `|` 會配得到空字串 →
  對每一段文字開火；P2-4 `CLAIM_CHECK_HOME` ≠ `~/.claude` 時佈出去的 conf 永遠讀不到；
  P2-5 **模板自己給的 `make` 例子**會讓 `git commit -m "make sure it works"` 算成
  build 過 → build 規則恆不開火。
- P2-6 明著宣告過的「帶受詞或帶狀態詞」只有三處有反例守著。補齊後才發現
  `(\d+ )?` 那段是**死的**（前綴都是選用的，核心 `tests pass` 本來就配得到），
  簡化掉。claim-check 測試 75→95、注入 27→40。

**hedge 過濾對真實語料的影響量過**：48 份紀錄、661 回合，finding 169→168，
唯一被抑制的是「以及 Pro target **是否**仍 build 成功」——正確的抑制。

## 第三輪外審 —— `review-hedge`(產品行為那半)

4 個 P1 ＋ 10 個 P2，全部重現後修掉；三項判斷被它逐條攻不破（conf 四層防護沒有互相
繞過的組合、`NAMED` 的字串拼接注入是**出聲**不是靜默、markdown 表格列判得對）。

- **P1-1 `claims?` 把這個 repo 自己的識別字當成轉述**。`\b` 在 `claim-check` 的
  `claim` 後面成立，於是「claim-check 的測試全綠」「7 支測試 + spec-claim 全綠」
  被整條 hedge 掉——而那**系統性地發生在最常拿來回放的語料上**。改成排除連字號詞界。
- **P1-2 英文 hedge 缺 `if/when/until/unless/cannot`**。中文的「如果」有收、英文的沒收，
  而這輪同時把 `tests pass` 放寬成不要求 `all`——收緊與放寬疊在同一個位置，把條件句的
  面積放到最大。
- **P1-3 `pushed to \S+` 太寬**（`pushed to the results array` / `to Datadog` / `to the stack`
  全中）。這是**本輪新引入**的誤判面。
- **P1-4 模板的 `cargo fmt` 是第二個 `make` 同型**：裸寫會配到 CI 的 `cargo fmt --check`，
  於是唯讀的格式檢查被算成「改過 code」。內建對 `dart format` 早就明著排除唯讀形式，
  模板的例子沒跟上。
- P2 裡真正改了設計的一條：**hedge 拆成兩類**。否定類要跨子句
  （`I have not, as you asked, committed…` 的插入語會把 `not` 切走），條件類不能跨
  （否則「如果…，測試全綠」的後半被吃掉）；轉折詞之後重新起算。疑問判定也降到子句
  ——原本用整句判，`Tests pass, should I commit?` 會整條被吃掉，而那**只取決於打逗號
  還是句號**。
- 其餘：`assum\w+` 吃掉 `assumeIsolated`；`after`/`once` 在英文技術敘述裡標記的是
  **完成態**不是 hedge，拿掉；中文只收條件詞、漏掉否定（`並沒有`／`不是`／`無法`）；
  `committed the work` 的 `work` 太鬆；`CLAIM_CHECK_HOME` 只在安裝期存在而 hook
  執行期沒有，於是安裝器寫的 conf 永遠讀不到（改成也找腳本自己的上一層）。

測試 95→110、注入 40→53。

**reviewer 量出一件我沒注意的事：語料會消失。** 我先前那個「48 份／661 回合」現在
只剩 **22 份／109 回合**，所以 `128→129` 與 `169→168` 這兩個數字**再也重現不了**。
它自己改用「規則命中數」當樣本（179 次命中、抑制 4 次＝2%，其中 1 次抑制錯、成因就是
P1-1），那是比 finding 數穩定得多的量法。**要精確重現得先凍結語料快照。**

## 第三輪外審 —— `review-harness`(測試基礎設施那半)

2 個 P1（都是 fail-green，都附注入證明）＋ 3 個 P2；七點必查裡四點攻不破。

- **P1-1 結果檔不存在時 `read` 根本不執行，變數沿用上一圈的值。** 上一圈是 `ok`
  就被算成 pass。兩個觸發路徑都實證：job 猝死 → 「28 條注入轉紅，0 條沒有」exit 0，
  與正常跑的 diff 只差一行；**結尾少一個 `wait`** → arch-guard「21 條轉紅，0 條沒有」
  exit 0 而其實 7 個 job 沒跑完。方向還是反的：`r1` 缺會被 `set -u` 吵鬧地打死，
  `r2` 以後缺則靜默通過。六支全中，是並行化**新引進**的形狀。
- **P1-2 `.done` 擋不住部分失敗。** 它只證明 driver 跑到最後一行。有 **31 個 id
  只被 `no` 型斷言消費**，漏寫它們的話 `cat` 回空字串、空字串不含任何 needle → 必過，
  輸出跟乾淨跑逐 byte 相同。**指紋與 no-op 哨兵都掃不到這個盲區**（兩邊都不 FAIL，
  FAIL 集合不變）——這是它們共同的盲點。
- P2-1 `fp.py` 對並行版**靜默產出殘缺指紋**（14 個子 shell 同時 append、一筆記錄拆三次
  write，行交錯與整行遺失），而摘要「N 條, 空集合 0」跟正確結果長得一樣。已強制
  `MUTANT_JOBS=1`。**先前那 68 條基準仍有效**——reviewer 用 `MUTANT_JOBS=1` 重跑後
  與我的逐 byte 相同。
- P2-2 編譯期診斷是「traceback 落點與子進程一致」那條承諾的**例外**（`compile()` 在
  任何 redirect 之外），已寫進註解。P2-3 `$SB/names` 是死碼，已清。

修完之後六支指紋重驗：五支逐 byte 相同；claim-check 的差異全部由這輪新增的 13 條注入
與 15 條斷言解釋，另有一條意外的改善——`repo 層的 conf 有被讀到` 以前是**靠 crash
轉紅**的（拿掉 tuple 的一個元素之後 `for path in (單一表達式)` 造成 import 期 TypeError，
掃掉 45 條無關斷言），修 P2-10 加了第三個元素之後它才開始殺它名字上該殺的那 6 條。
**又一個「紅了但理由不對」的實例。**

reviewer 自己標的限制：`ulimit` 壓不出真實的 fork 失敗（會先打死外層 shell），所以
P1-1 的觸發是**等價注入**證明的、不是真實資源耗盡；Linux/GNU 仍無法驗證。

## 這一輪自己的待驗

- 英文 pattern 的誤判率（見上）。
- `~/.claude/claim-check.conf` 是這輪新佈的（全空 = 只用內建）。它現在**不在**
  `sync-check` 的比對範圍內——`*.conf` 刻意排除，因為那是每個人各自調的。
  代價是模板改了、既有的那份不會跟上，而沒有任何東西會說。
- arch-guard 的「沒有規則可跑」判定用 `grep -cv '^\(#.*\)\?$'` 數有效行。
  BSD grep 2.6.0 與 ugrep 7.8.4 下實跑正確，**GNU grep 沒驗**（同 Linux 那條）。
- `P2-5` 的 locale 修法在 BSD awk 的 C 與 UTF-8 兩個 locale 下實跑一致，
  **gawk / mawk 沒驗**——那是 POSIX bracket expression 的 locale 語意、不是實作差異，
  但仍是推論。

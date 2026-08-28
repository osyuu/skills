# 待驗清單 — `379d402` 的 10 條修正

**這批修正沒有經過外審。** 它們是照 `review-tail` 的對抗式報告做的，報告本身審的是
`a593275..90ca7c0`（`backup-before-tidy`），**不含這些修正**。換一台 PC 接手時，
從這份清單開始，不要從「測試綠」開始——這批東西的每一個洞都是在全綠的情況下活著的。

改動範圍：`git show 379d402`，五個檔——
`skills/harness/repo-onboard/SKILL.md`、
`skills/harness/arch-guard/{assets/arch-guard-check.sh,scripts/install.sh,tests/run.sh}`、
`skills/workflow/dev-loop/SKILL.md`。
（`6e9dea6` 是 `93b370c` 的 reword，內容 diff 為空，不用重看。）

## 已經跑過的（不用重跑，除非要挑戰結論）

- 七支 skill 的 `tests/run.sh` 全綠：arch-guard 40/0、claim-check 52/0、
  claude-md-hygiene 33/0、comment-budget 26/0、harness-audit 36/0、
  sdd-harness-init 14/0、handoff 9/0
- 五支 `tests/mutants.sh` 全綠：arch-guard 12/0、claim-check 14/0、
  claude-md-hygiene 10/0、comment-budget 6/0、sdd-harness-init 3/0
- `grep -Fxv -f` 的四種情境（超集無輸出／缺一筆印那一筆／空歸類被 awk 抓／`sh` 相容）
- arch-guard 未填 conf 時的三模式 exit code 矩陣（warn 0、audit 1、strict 1）
- repo-onboard §3 兩條探針指令在 `sh` 下實跑

**全綠證明不了這批是對的**——`harness-audit` 量過同一個 repo：190 條斷言綠著，
同時有 8 個 P0 活著,因為 fixture 用的正好是 pattern 清單寫的時候看的那兩個技術棧。

## 七條待驗（按我自己的懷疑程度排）

### 1. §3 的數字綁死在單一 repo（我最可能犯的一條）
`skills/harness/repo-onboard/SKILL.md` §3 的「43 種副檔名、16 個 top-level 目錄、
≥3 砍到 20」是我在**一個** repo（puregame365，Flutter）量的。使用者明確要求
「不要拿個別專案的狀況去寫這些 skill」。

判斷：這算不算違反那條？如果算，怎麼改才既保住「界線是可判定的」（`writing-for-agents`
的 completion criteria 要求）又不綁單一 repo。**換一台 PC 的話請在那台的 repo 上重量一次**
——如果數量級差很多，那個 `≥3` 的門檻就是為 Flutter 調的。

### 2. `grep -Fxv -f` 的邊界
`SKILL.md` 完成條件 4。我只驗了乾淨的五行案例。沒驗：
- 歸類欄空掉時 `cut -f1` 出什麼？**沒有 TAB 的行**呢？
- pattern 檔本身是空的：`grep -f /dev/null` 在 BSD 與 GNU 行為一致嗎？
- 路徑含空白、含 `\`、含非 ASCII（`core.quotepath=off` 之後）？

### 3. `awk -F'\t' 'NF < 2 || $2 ~ /^[[:space:]]*$/'` 的價值
同一條完成條件。它抓「歸類欄空殼」，但抓不到歸類欄填 `—` / `TODO` / `?` 這種
「有字但等於沒歸類」的。**已知抓不到**——要判的是這條的價值是不是低到該換寫法，
還是原樣就夠（它至少堵住 `sed 's/$/\t/'` 那種最裸的傾印）。

### 4. `$G` 的 word-splitting
`SKILL.md` §3 用 `G="git -c core.quotepath=off ls-files --full-name :/"` 然後 `$G |`。
沒驗：`set -u` / `set -f`(noglob) / IFS 被改過的 shell；`:/` 不加引號在 zsh 開了
`EXTENDED_GLOB` 時安不安全。

### 5. arch-guard audit 的非零路徑是不是只有一條
`assets/arch-guard-check.sh` 的 `[ "$mode" = "warn" ] || exit 1`，以及
`scripts/install.sh` 我新加的那句
「A non-zero exit means step 1 is not finished」。
- **已填 conf 且有違規時** audit 還是 exit 0 嗎（尾端 `if mode = audit → exit 0`）？
- 有沒有第三種讓 audit 回非零的路徑（git grep 失敗、壞 regex）會讓那句話變成謊話？

### 6. `tests/run.sh` 新加的兩條斷言會不會污染後面
第一版我寫錯過一次：拿掉 `|| true` 照樣綠，因為 warn 模式本來就 exit 0，
那條路根本觀測不到它。現在改成把 checker 換成 `exit 1` 的 stub，注入才轉紅。
待驗：
- 測試中途失敗、`cd "$WORK"` 沒走到時，後面的斷言會不會在錯的目錄跑？
- 我把 `hooks/arch-guard-check.sh` 換成 stub 之後**沒有還原**，那個 sandbox 後面還有沒有人用？

### 7. dev-loop 的新措辭有沒有製造新的死結
`skills/workflow/dev-loop/SKILL.md`〈交付前的整理〉。我把「清 warn」移到
最後一次 review 之前，整理階段限定為不改 tree 的操作。
待驗：**review 本身產生新 warn** 時（reviewer 要求的修正引入註解過長之類），
照現在的文字那條 warn 要在哪裡清？修完 review 發現 → 產生 warn → 整理階段不准改 code。

## reviewer 自己標的未驗項（不是我的懷疑，是它的）

- **Linux 上的行為全部沒驗**：全程 macOS，`comm`/`sort` 是 BSD 版。
  GNU coreutils 的 `comm` 對 unsorted 輸入**會**印 `comm: file N is not in sorted order`
  到 stderr，行為可能不同。（`comm` 已經被換掉了，但 §3 那兩條 `sed`/`uniq` 同樣沒在 GNU 下跑過。）
- `sdd-harness-init` 的 description 加 `ADR` 那行只讀了字面、沒測觸發率。
- `a83559a` 的日文／英文 trigger 用詞是否地道，超出它能驗的範圍——**需要母語者或另一台**。
- `claim-check` 的〈正確性宣稱〉規則只讀了 `claim-check.py:206` 的判定式推論，
  **沒實跑 hook** 去證明 dev-loop 那個死結真的會開火。

## 還沒做的（與這批修正無關，但同樣沒人接手）

- `claim-check` 的 `RULES` 宣稱詞表**只認中文**，英文只有 `LGTM` / `BUILD SUCCEEDED`。
  toolchain 那半已經外部化成 conf（`hooks/claim-check.conf`），宣稱詞彙那半還沒有。
  這是 `harness-audit` 實測出來的 P0：**只認一種語言的規則，在另一種語言的 session 永遠零開火**。
- pre-commit 的 `sync-check.sh` 不涵蓋使用者層的已部署副本
  （`~/.claude/hooks/*.py`）——改了 repo 這份、忘了同步部署那份，沒有任何東西會說話。
  今天實際犯過一次。

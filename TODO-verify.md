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

- 七支 skill 的 `tests/run.sh` 全綠：arch-guard 44/0、claim-check 75/0、
  claude-md-hygiene 33/0、comment-budget 26/0、harness-audit 36/0、
  sdd-harness-init 14/0、handoff 9/0
- 六支突變全綠：arch-guard 15/0、claim-check 27/0、claude-md-hygiene 10/0、
  comment-budget 6/0、sdd-harness-init 3/0、hooks 25/0
- `hooks/tests.sh` 26/0

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

### 5. arch-guard audit 的非零路徑 — **原問題清白，但量到另一個洞**
- 已填 conf ＋ 有違規時 audit 仍 exit 0（尾端無條件 `exit 0`）→ install.sh
  那句「A non-zero exit means step 1 is not finished」成立。
- 沒有第三種非零路徑：壞 regex 讓 `git grep` fatal（訊息進 stderr，設計如此）、
  壞掉的 conf source 失敗，兩者都仍 exit 0。
- **新洞**：`LAYERS=""` ＋ 沒有半條 chokepoint 是模板允許打出來的狀態，而那時兩個
  迴圈一次都不會進去、尾端照印「共 0 條違規」exit 0——與這個 repo 真的乾淨一模一樣。
  處置與未填 `<TODO>` 同一條（出聲；只有 warn 能 exit 0）。註解不算規則。
  四個方向各一條測試 ＋ 三條注入。

### 6. `tests/run.sh` 新加的兩條會不會污染後面 — **清白**
- 每個 `cd` 都帶 `|| exit 1`，走不到就整支中止，不會在錯的目錄跑。
- 換成 `exit 1` stub 的那份是 `newrepo2` 開的獨立沙箱，而且是檔案裡最後一條斷言，
  後面只剩 `cd "$WORK"` 與統計；`trap rm -rf "$WORK"` 收尾。沒有後續使用者。

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
  - **英文那半沒有真實 session 的校準基準**：這台的 46 份紀錄全是中文 session。
    量得到的只有「英文詞表沒有在中文 session 上多開火」——加之前 128/656（19%），
    加之後 129/656（19%），多的那一次是 PitchMonitor 裡一句真的英文宣稱
    （`Baseline locked: 475 tests green`，而其後又改過 code）。**英文 session 的誤判率
    量不到，換一台請在英文 session 上回放一次再收緊或放寬。**
  - 英文那半收得比中文緊是刻意的（要求帶受詞或狀態詞），三條反例是那個要求的守護者。
- **`sync-check.sh` 不涵蓋使用者層的部署副本**。加了 `UPAIRS` 那半：
  不存在＝沒裝，不出聲；存在且不一致才出聲並給 cp 指令；另有反查抓沒登記的。
  跑起來當場抓到 `~/.claude/hooks/claim-check.py` 落後來源 83 行（就是 TODO 說「今天犯過」
  的那次），已 `cp` 同步。測試用 `SYNC_CHECK_HOME` 隔離，**否則這支測試會去量這台機器
  實際裝了什麼**，換一台就換一個結果。

## 這一輪自己的待驗

- 英文 pattern 的誤判率（見上）。
- `~/.claude/claim-check.conf` 是這輪新佈的（全空 = 只用內建）。它現在**不在**
  `sync-check` 的比對範圍內——`*.conf` 刻意排除，因為那是每個人各自調的。
  代價是模板改了、既有的那份不會跟上，而沒有任何東西會說。
- arch-guard 的「沒有規則可跑」判定用 `grep -cv '^\(#.*\)\?$'` 數有效行。
  BSD grep 下實跑正確，GNU 下沒驗（同 Linux 那條）。

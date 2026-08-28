---
name: repo-onboard
description: >-
  讓一個 repo 進入「agent 能在上面可靠工作」的狀態:探測它的技術棧與既有慣例,帶著建議問幾個
  只有人答得出的問題,寫成 per-repo 配置,再據此裝守門並**注入故障驗證每一道在這個技術棧上
  真的會開火**。當你開始在一個沒配置過的 repo 工作、接手一個既有專案、換了機器或開了新
  worktree(配置不會跟過來)時,主動使用。
  也認 onboard this repo / set up this repo / new machine / fresh worktree、
  リポジトリの初期設定 / 環境を整えたい。已經 onboard 過且技術棧沒變的 repo 不用重跑;
  只想盤點守門用 `harness-audit`。**還沒有 code 的 0→1 新 repo 只做探測與問答、不要裝守門**
  ——那時門檻定不出來、層還沒長出來,裝一道不會開火的守門比不裝更糟。
---

# repo-onboard — 讓一個 repo 能被 agent 可靠地工作

**這支解的是一個具體的失效**:跨機共用的 skill 裡寫死了本機知識(工具鏈、副檔名、語言關鍵字、
宣稱詞表)。那些清單搬到別的技術棧就認不得,於是守門**照常執行、輸出看起來正常、實際零效果**
——而且沒有人會發現,因為它跟「這個 repo 很乾淨」長得一模一樣。

配置跟著 repo 走,skill 只帶探測邏輯與問法。

## 1. 探測(先看,不要問使用者你自己查得到的事)

| 看什麼 | 怎麼看 | 決定什麼 |
|---|---|---|
| 技術棧 | 標記檔:`pubspec.yaml` `package.json` `Cargo.toml` `go.mod` `*.xcodeproj` `Package.swift` `pyproject.toml` `build.gradle*` `pom.xml` `Gemfile` | 測試/build/codegen/formatter 的指令、副檔名、語言關鍵字 |
| 既有守門 | `hooks/`、`.git/config` 的 `core.hooksPath`、`.claude/settings.json`、`.claude/settings.local.json` | 哪些已裝、哪些是別人裝的(不要覆蓋) |
| 既有慣例 | `CLAUDE.md` / `AGENTS.md` 與它們 `^@` import 進來的檔、repo 自己的規範文件(`CONTRIBUTING.md`、`docs/`、`conventions/` 之類)、各生態自己的 linter 設定檔 | 這個 repo 適用的 review skill,它的 checklist 哪幾條要**以專案為準** |
| 工作進料 | `git remote -v`、有沒有 issue tracker 相關的本機 skill、本機的暫存/筆記目錄(有的話) | 需求從哪來 |
| 版控佈局 | `git rev-parse --git-common-dir`、`git worktree list` | 是不是 linked worktree(`.git` 是檔案,`.git/info/exclude` 追加會失敗) |
| session 語言 | 使用者的常駐指南、近期對話 | 宣稱詞表要哪一種語言——**只認一種語言的規則,在另一種語言的 session 永遠零開火**。內建中英各一半,其餘語言填進 `claim-check.conf` 的 `CLAIM_*_CLAIM_RE`(repo 的 `hooks/` 或使用者層的 `~/.claude/` 都讀得到)。第 5 步一律用**這個 session 的語言**造違規來驗 |

上面那張表是**起點,不是窮舉**。用一條指令列全,深度無關:

```sh
git ls-files --full-name ':/' | grep -E '(^|/)(pubspec\.yaml|package\.json|pnpm-workspace\.yaml|go\.mod|go\.work|Cargo\.toml|pyproject\.toml|setup\.py|requirements\.txt|Gemfile|Rakefile|.*\.gemspec|pom\.xml|build\.gradle.*|build\.sbt|composer\.json|mix\.exs|Package\.swift|Podfile|.*\.podspec|project\.pbxproj|CMakeLists\.txt|meson\.build|[Mm]akefile|BUILD|BUILD\.bazel|WORKSPACE|Dockerfile|deno\.json|flake\.nix|.*\.tf|.*\.(csproj|sln|vcxproj|fsproj|cabal))$'
```

**這條回 0 筆本身是發現,不是通過**——先確認這個 repo 真的沒有建置檔,再往下走。
`':/'` 不能省:少了它只列 cwd 子樹,在 `packages/api/` 裡跑會只看到那一個。

**每一筆都要在 profile 的盤點區有一行歸類**(認得 → 指令是什麼;不認得 → 問),
格式是 `<路徑><TAB><歸類>`,一行一筆——下面第 4 條要拿它機械比對。

上面那串副檔名是**這次寫下來時的快照**,而生態會長出新的建置檔,清單不會自己跟上。
所以**再做一次不依賴清單的探測**,把判斷權從清單交回現場:

```sh
G() { git -c core.quotepath=off ls-files --full-name ":/"; }  # quotepath 關掉,否則非 ASCII 路徑會被加引號
G | grep / | sed 's#/.*##' | sort -u                          # top-level 目錄(grep / 濾掉根目錄的檔案)
G | sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' | sort | uniq -c | sort -rn
```

**要用函式不能用 `G="git …"` 再 `$G`**:zsh 不對未加引號的參數展開做字詞切分,整串會被
當成一個指令名,回 `no such file or directory: git -c core.quotepath=off …`。這條探測是
給人貼進自己的 shell 跑的,而預設 shell 是 zsh 的機器不在少數。

**問到哪裡為止**:副檔名只問**出現 ≥ 3 個檔**的那些,top-level 目錄則每個都問。
不設界線這一步會爆掉,而副檔名那半大多是 `png`/`ttf`/`gitkeep` 這種與建置鏈無關的。
沒有界線時 agent 會自己決定跳過哪些,而跳過的理由不會寫下來。

**別把總數當預期值**:同一台機器上量十個 repo,副檔名 6–43 種、top-level 目錄
1–7 個(另有一個 16 的離群值),`≥3` 砍掉的比例在 38%–70% 之間。差一個數量級的東西
不能寫成「大約幾種」讓人拿來對照——界線是 `≥3` 這條規則本身,不是任何一個總數。

**這一步防的是部分命中**——`api/go.mod` + `web/package.json` + `svc/Payments.csproj` 的 repo,
前兩個認得就容易當成盤點完了。**缺席不是 `<TODO>`**,所以只查 TODO 的檢查看不到它;
「回 0 筆是發現」那句也攔不住,因為它根本不是 0 筆。
補進 profile 的那些,下面第 4 條允許它比指令輸出多。
monorepo 的建置檔常在 depth 2(`packages/api/package.json`),所以用 `git ls-files`
而不是掃 top-level。

## 2. 帶著建議問(一節一問,預設答案讓人一個字接受)

自己查得出來的不要問。**只問答案在人腦裡的**:

- **守門要不要讓隊友也跑到**——按型別各問各的,因為它們的落點不同,合成一題會記錄到
  一個不會發生的決定:
  - **pre-commit 家族**(分層、註解量、spec drift)落在 `hooks/` + `core.hooksPath`。
    真正的決定是「`hooks/` 進不進版控」。
  - **PostToolUse / Stop 家族**落在 settings 檔。`.claude/settings.json` 是 tracked(隊友也跑),
    `.claude/settings.local.json` 不是(只有你)。**注意各安裝器的預設不一致**,裝之前先看它寫哪。
  - **使用者層的守門**(裝在 `~/.claude/`)跨所有 repo,**這題不該問**——它不是 per-repo 決定。
- **哪些 checklist 條目以專案為準**:探測到的衝突逐條列出來確認。
  **這類衝突通常是通用 checklist 輸**:專案的慣例文件是刻意寫下的決定,checklist 是別處
  帶來的預設值。衝突沒問出來的話,review 會把「專案規範本身」整批報成 anti-pattern,
  而數量大到讀的人只能整份忽略。
- **需求從哪來**:GitHub / GitLab Issues、Jira / Linear 這類 SaaS、公司自架的、本地 markdown。
  記下**怎麼取一張票**——那是後續每一次開發的入口。
- **設計書落點與版控歸屬**:進版控還是本機。`git ls-files docs/design/` 有輸出就別問了。

## 3. 寫 per-repo 配置

**每一項事實要落到真正被讀的那份 conf**,不是集中寫一份。各守門 source 的是自己那份:
分層規則、註解量、spec drift 各有各的 conf,裝的時候那支 skill 會說它讀哪個。
**同一批事實不要兩邊都寫**——存兩份會各自走樣。

`hooks/repo-profile.conf` 是**索引與存放處,不是來源**:記那些沒有任何 conf 收容、
但下一個 session 或換機的你需要知道的事——探測到的技術棧與各自的指令、session 語言、
issue tracker 怎麼取票、設計書落點、**開一個 worktree 要跑哪幾步**(那決定並行的門檻,
而它是 per-repo 的)。**目前沒有任何腳本讀這一份**,它的讀者是人與下一個 agent。

在 `CLAUDE.md` 留一句指標指過去(**只留指標**,清單本身不進 CLAUDE.md——它會漂)。

## 4. 裝守門

**先看有沒有東西可守**——判準是**守門要守的那個結構存不存在**,不是 commit 數也不是檔案總數:
分層守門要「每一層的目錄都存在且各有至少一個原始碼檔」,註解量守門要「有夠多帶註解的檔可以量基準」。
一條都不成立 → **這步停在這裡**,把 §1-§3 的探測結果
交出去,並在 profile 留一行「**守門未裝,重跑 §4 的條件是 ⟨寫下來⟩**」——沒有這行,
停下來的 repo 沒有任何東西會把它叫回來。

(別用 commit 數當主判準:空 repo 上 `git rev-list --count HEAD` 直接 fatal,而
shallow clone 回 1——兩個都正好發生在這個閘瞄準的情境上。)

有 code 了就交給 `harness-audit`:哪些適用這個 repo、哪些漏了、怎麼裝、裝完怎麼驗。
它會動態掃可用的 skill,不維護靜態清單。

## 5. 驗證——這步決定前面四步有沒有意義

**逐道注入故障,確認它在這個 repo 的技術棧上真的開火。**

「裝好了」與「裝了一道永遠不開火的守門」在畫面上完全一樣,而後者比不裝更糟:它讓人以為
那條規則有人在看。實測過的一個例子:某道宣稱守門在某個技術棧上恆開火、與事實無關,
狀態維持四個月沒被發現,而它的測試全綠——因為測試用的就是它認得的那兩個技術棧。

各 skill 的驗法在各自的 SKILL.md;`harness-audit` 的 `verify-guard.sh` 目前只驗得了
pre-commit 型,Stop / PostToolUse 型要用該 skill 自己的方式(例如 `--replay`、開新 session)。

## 完成的定義

**五條全滿足才算 onboard 完**;缺任一條就明說缺哪條,不要說「配好了」。

1. **每一份被守門 source 的 conf 都填過**,而且裡面**沒有別的生態留下的預設值**——
   有些模板出廠就帶著可用但屬於另一個語言的值,且**沒標 `<TODO>`**,只查 TODO 看不到它們。
2. 每一道裝上的守門都**注入過故障並看到它開火**——用這個 repo 的實際技術棧**與這個 session
   的語言**造違規,不是用 skill 範例裡的。
3. 至少一道守門**注入「不該開火」的輸入並確認它沒開火**。單向的綠燈證明不了鑑別力。
4. **指令輸出的每一行都要在盤點區有歸類,且沒有一行的歸類欄是空的**。兩條都跑:

   ```sh
   cut -f1 <盤點區> > /tmp/classified
   grep -Fxv -f /tmp/classified <§1 建置檔那條指令的輸出>   # 漏歸類的會被印出來
   awk -F'\t' 'NF < 2 || $2 ~ /^[[:space:]]*([-?]|—|[Tt][Oo][Dd][Oo]([[:space:]]*[:：].*)?|<[^>]*>|[Nn]\/[Aa])?[[:space:]]*$/' <盤點區>   # 空殼歸類會被印出來
   ```

   **判準是「兩條都無輸出」,不是 exit 0**——`grep` 沒命中時回 1,串成 `&&` 會反過來。
   profile **可以多**(補上清單沒認出來的),**不可以少**。
   (要求兩邊相等會反過來懲罰補漏的人:補一行進去就永遠交不出條件,而唯一走得通的解
   是把它刪掉。`comm` 也不能用:它要求兩邊依同一套 collation 排序,而 `git ls-files`
   出的是 byte order——不一致時它**不報錯**,直接給錯答案,而錯的方向是把已歸類的
   誤報成漏掉。第二條擋的是反方向的鑽法:單向包含允許 `git ls-files | sed 's/$/\t—/'`
   把整個 repo 倒進去,集合條件恆滿足而一行都沒真的歸類。)

   **`—` 必須自成一個分支,不能放進 `[...]`**:bracket expression 在非 UTF-8 locale
   (`LC_ALL=C`,cron 與 CI 的常態)是**位元組集合**,em dash 的三個位元組被拆開、
   `?` 量詞只允許出現一次,於是配不到——而那正好讓上一段點名要擋的
   `sed 's/$/\t—/'` 從 C locale 穿過去。

   **第二條擋的比看起來多一種**:`cut -f1` 對**沒有 TAB 的行**輸出整行,於是一行
   純路徑會被第一條算成「已歸類」——那一種只有 `NF < 2` 看得到。佔位符那一串
   (`—` `-` `?` `TODO` / `TODO: …` `<…>` `n/a`)是量過會被寫出來的實際內容;
   有字但等於沒歸類仍然填得出新的花樣,這條擋的是已知的那幾種,不是全部。
5. `CLAUDE.md` 有指標指向 conf,而且**在 linked worktree 裡也指得到**——git-excluded 的目標
   對隊友、對自己的 worktree 都是懸空指標,而「開了新 worktree」正是這支要服務的情境之一。

配置完成後,開發走 `dev-loop`。

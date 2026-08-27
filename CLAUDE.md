# skills

Osyuu 的個人 Claude Code skill marketplace。撰寫與登錄的房規見 `skills/skill-authoring/SKILL.md`。

## 守門（`hooks/pre-commit`，全部 warn-only）

| 檢查 | 守什麼 |
|---|---|
| comment-budget | 註解區塊 ≥10 行 · 單檔佔比 >40% · 敘事與驗證過程字眼 |
| skill-tests | 改了某 skill 的 `scripts/` 或 `assets/` 就跑它的 `tests/run.sh` |
| marketplace-sync | 新增 `skills/<name>/` 但 `marketplace.json` 沒登錄 |

**fresh clone / 新 worktree 要先跑 `git config core.hooksPath hooks`** —— 此設定不進版控，沒設就是全部靜默失效，而那看起來跟有守門一模一樣。

常駐規範檔的複查走 `.claude/settings.json` 的 PostToolUse hook，不在這張表裡——它在**編輯當下**開火，不等到 commit。

不裝 arch-guard（沒有分層可守）與 sdd-harness-init（沒有設計書）。**裝一道不會開火的守門比不裝更糟**：它讓人以為那條規則有人在看。

## 踩坑

- **改動只對新 session 生效。** skill 全文是在被叫用的那一刻抓進對話的，之後不會換——一個開很久的 session 會一路照當初那份工作，而兩邊都沒有任何訊號。改完想立刻用就開新 session，或在原 session 重新叫一次那個 skill。
- **`install.sh` 一律 idempotent，不覆蓋既有檔案**（保留使用者調過的門檻）。所以改了 `assets/` 裡的 hook 腳本之後，要手動 `cp` 到目的地，否則改的是原始碼、跑的是舊版。
- **新裝且從未叫用過的 skill，清單裡只有名字沒有描述。** 那不是 YAML 壞掉——`~/.claude.json` 的 `skillUsage` 分數為 0 就會被清單預算砍掉描述，而它正需要描述才會被自動觸發。叫用一次就有了。
- **腳本的失敗模式幾乎都是靜默的**：壞掉的 pattern、少一個欄位、多一層跳脫，全都回「沒有發現」，跟真的沒問題長得一樣。所以有 `scripts/` 的 skill 一定要有 `tests/`，而且要跑過失敗路徑，不只成功路徑。
- **假 fixture 的形狀未必等於真實環境的形狀。** 實測踩過：假 plugin cache 每個 plugin 目錄只放一個 skill，真實 cache 因為 `source: "./"` 每個目錄躺著整個 repo 的 skill，於是同一支腳本在測試裡乾淨、在真實環境產出三分之二的幻影。

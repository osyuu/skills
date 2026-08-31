# skills

Osyuu 的個人 Claude Code skill marketplace。這裡只放 `mattpocock-skills` 沒有、
或有但需要按自己專案改的東西；方法論一律用 mattpocock 那套，不複製一份。

## Bucket

`skills/engineering/` 是 promoted，`skills/deprecated/` 不是。
**promoted 的每一支都要在 `.claude-plugin/marketplace.json` 的 `plugins[]` 有一筆，
其餘 bucket 的不得出現在裡面**；每個 bucket 的 `README.md` 列出它底下的每一支。
否決過的路存在 `.out-of-scope/`，一則寫清楚為什麼不做、誰要求過。

## 新機器

`bootstrap/` 是全域環境的單一真相：marketplace、plugin 清單、`~/.claude/CLAUDE.md`、
statusline、settings 片段。新機器 clone 後跑 `sh bootstrap/install.sh`。
**`~/.claude/CLAUDE.md` 是指回 `bootstrap/CLAUDE.md` 的 symlink**——改它就是改這個 repo，
要 commit 才會傳到別台。細節見 `bootstrap/README.md`。

## 寫 skill

判準走 `mattpocock-skills:writing-for-agents`，那份是單一真相——包括 invocation 二分法：
只有模型需要自己伸手拿的才留 `description`，其餘設 `disable-model-invocation: true`
換掉常駐的清單預算。

**SKILL.md 適用跟 code 註解同一套規範**：寫約束與違反的後果，不寫驗證過程、不寫歷史、
不寫推導過程。「實測踩過…」那類句子證明的是作者很認真，不是這支 skill 怎麼運作——
它們屬於 commit message 與 `.out-of-scope/`。

這個 repo 不裝機械守門，沒有 pre-commit。把關靠 review。

## 環境事實（查得到但很貴）

- **改動只對新 session 生效**：skill 全文在被叫用的那一刻抓進對話，之後不會換。
- **`/plugin update` 要手動跑**，追的是 git HEAD 不是 `metadata.version`。
- **從未叫用過的 skill 在清單裡只有名字沒有描述**：`~/.claude.json` 的 `skillUsage`
  分數為 0 會被清單預算砍掉描述。key 是限定名，裸名與讀檔都不算數。

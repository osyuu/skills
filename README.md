# skills

Osyuu 的個人 Claude Code skill marketplace,跨開發環境共用。一個 `marketplace.json`
+ 依用途分類的 `skills/<category>/<name>/`。

只共用 **skills**——`CLAUDE.md`、`settings.json`、memory 各環境需求不同,刻意不納入。

## 安裝

```
/plugin marketplace add Osyuu/skills
/plugin install design-doc@osyuu
/plugin install skill-authoring@osyuu
/plugin install flutter-dart-code-review@osyuu   # 非 Flutter 環境可略
```

更新:`/plugin update`

## 內容

分類的判準見各目錄的 `README.md`。plugin 名稱**不含分類前綴**——安裝指令與
`skillUsage` 的 key 都只認 skill 名,搬目錄不影響。

### `skills/harness/` — 裝守門,留下會自己開火的機制

| plugin | 說明 |
|---|---|
| `arch-guard` | 把分層依賴方向(features→shared→data→core 之類)用 warn-only pre-commit 鎖進 repo;git grep 抓往上/橫向 import,--strict 給 CI。語言無關 |
| `comment-budget` | 註解量的 warn-only pre-commit 守門:過長區塊、單檔註解佔比、敘事/驗證過程字眼 |
| `sdd-harness-init` | 把 decision-log drift 防護(DECISIONS.md + pre-commit + hooksPath)佈進任一 repo,idempotent |
| `claude-md-hygiene` | 審查/重寫 CLAUDE.md,只留穩定規範+指標,把易變狀態外移到 living docs;裝 PostToolUse hook 防第二次腐爛 |
| `claim-check` | 裝 Stop hook,把 agent 自己的宣稱跟它實際跑過的工具呼叫對起來 |
| `harness-audit` | 盤點該裝哪些守門、已裝哪些、漏了哪些,並注入故障驗證每一道真的會開火 |

### `skills/workflow/` — 做事順序,叫用當下做完就結束

| plugin | 說明 |
|---|---|
| `design-doc` | 需求 → 可驗證、可餵實作的詳細設計書(SDD);先逼問模糊點再產契約 |
| `greenfield-flow` | 0→1 專案的進場順序:何時收斂需求、何時打地基、何時**還不要**裝守門 |
| `handoff` | compact / 換 session 之前,把下一個 session 查不到的東西落成記憶檔,並盤點工作區與還活著的 agent |
| `teammate` | 多 agent 協作房規:開幾個由視角決定、派工令必備六條、idle≠交付、review 的 baseline 凍結 |
| `release-assets` | 把使用者會看到的非程式碼交付物交乾淨:release notes、商店截圖、changelog、版本號 |
| `skill-authoring` | 寫/改/審 skill 的房規 + 範本 + 本 marketplace 登錄流程 |

### `skills/review/` — 拿檢查表審既有 code

| plugin | 說明 |
|---|---|
| `flutter-dart-code-review` | 與函式庫無關的 Flutter/Dart code review 檢查表 |

## 維護

- 新增 skill:放進 `skills/<category>/<name>/`,在 `marketplace.json` 的 `plugins[]`
  加一筆(`"skills": ["./skills/<category>/<name>"]`)。房規見
  `skills/workflow/skill-authoring/SKILL.md`。
- 改完 skill 要 bump `.claude-plugin/marketplace.json` 的 `metadata.version` 並 push。
  傳播靠 git HEAD(`autoUpdate` 預設開),version 是給人讀的變更標記。
- 否決過的路連理由存在 `.out-of-scope/`——只記結論會讓人再走一遍。

## 注意

安裝後同名 skill 會由 plugin 提供;若本機 `~/.claude/skills/` 還留著同名實體目錄,兩份會打架,移除本機那份即可。

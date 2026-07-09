# skills

Osyuu 的個人 Claude Code skill marketplace,跨開發環境共用。結構同 [anthropics/skills](https://github.com/anthropics/skills):一個 `marketplace.json` + 平鋪的 `skills/`。

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

| plugin | 說明 |
|---|---|
| `design-doc` | 需求 → 可驗證、可餵實作的詳細設計書(SDD);先逼問模糊點再產契約 |
| `skill-authoring` | 寫/改/審 skill 的房規 + 範本 + 本 marketplace 登錄流程 |
| `flutter-dart-code-review` | 與函式庫無關的 Flutter/Dart code review 檢查表 |

## 維護

- 改完 skill 要 bump `.claude-plugin/marketplace.json` 的 `metadata.version` 並 push,別台 `/plugin update` 才會拉到。
- 新增 skill:放進 `skills/`,在 `marketplace.json` 的 `plugins[]` 加一筆。

## 注意

安裝後同名 skill 會由 plugin 提供;若本機 `~/.claude/skills/` 還留著同名實體目錄,兩份會打架,移除本機那份即可。

# skills

Osyuu 的個人 Claude Code skill marketplace。

方法論走 [`mattpocock-skills`](https://github.com/mattpocock/skills)——訪談收斂、實作、
review、診斷、原型、交接都在那裡。**這個 marketplace 只放那邊沒有、或有但需要按自己
專案改的東西。**

## 安裝

必裝的是 `mattpocock-skills`，這裡的每一支都是疊在它上面的選配：

```
/plugin install mattpocock-skills@claude-plugins-official

/plugin marketplace add osyuu/skills
/plugin install osyuu-skills@osyuu               # release-assets、writing-standalone-skills
/plugin install flutter-dart-code-review@osyuu   # Flutter 專案才需要
/plugin install xcode-ios-pitfalls@osyuu         # Xcode 專案才需要
```

## Skills

| | |
|---|---|
| [`flutter-dart-code-review`](./skills/engineering/flutter-dart-code-review/SKILL.md) | Flutter/Dart review 檢查表，專走一般 review 會略過的無障礙、i18n、widget 慣用法、效能、測試、依賴。`code-review` 的 Standards 軸走 Fowler smell，沒有語言特定的條目 |
| [`xcode-ios-pitfalls`](./skills/engineering/xcode-ios-pitfalls/SKILL.md) | Xcode 建置、簽名與工具鏈裡「編譯成功、測試全綠、執行期或下一次建置才爆」的靜默失效。`code-review` 讀的是 diff，讀不到 build setting 與 plist 的交互作用 |
| [`release-assets`](./skills/engineering/release-assets/SKILL.md) | release notes、商店素材、changelog、版本號。main flow 到 `code-review` 就結束，沒有出貨那一段 |
| [`writing-standalone-skills`](./skills/engineering/writing-standalone-skills/SKILL.md) | 用 Matt 的風格與思路寫新 skill，但產物不依賴 Matt 的 plugin 或 flow，沒裝的隊友也能用。`writing-for-agents` 教怎麼寫，不管產物離開 Matt 的環境後還能不能跑 |

不再使用的在 [`skills/deprecated/`](./skills/deprecated/README.md)，那份 README 寫了各自改用哪一支。

## 用之前

`/plugin update` 要手動跑，開新 session 不會自動拉；而 skill 全文是在被叫用的那一刻抓進
對話的，所以改完要開新 session 或重新叫一次才會生效。

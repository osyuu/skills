# skills

Osyuu 的個人 Claude Code skill marketplace。

方法論走 [`mattpocock-skills`](https://github.com/mattpocock/skills)——訪談收斂、實作、
review、診斷、原型、交接都在那裡。**這個 marketplace 只放那邊沒有、或有但需要按自己
專案改的東西。**

## 安裝

```
/plugin marketplace add osyuu/skills
/plugin install design-doc@osyuu
/plugin install flutter-dart-code-review@osyuu   # 非 Flutter 環境可略
/plugin install xcode-ios-pitfalls@osyuu         # 非 Xcode 環境可略
/plugin install release-assets@osyuu
```

## Skills

| | |
|---|---|
| [`design-doc`](./skills/engineering/design-doc/SKILL.md) | 需求 → 可驗證的介面與行為契約，落在 `docs/design/<slug>.md`。`to-spec` 的模板沒有替代方案、do-nothing baseline 與 drawbacks 這三節，也不回寫版本 |
| [`flutter-dart-code-review`](./skills/engineering/flutter-dart-code-review/SKILL.md) | 與函式庫無關的 Flutter/Dart review 檢查表。`code-review` 的 Standards 軸走 Fowler smell，沒有語言特定的條目 |
| [`xcode-ios-pitfalls`](./skills/engineering/xcode-ios-pitfalls/SKILL.md) | Xcode 建置與簽名裡「編譯成功、測試全綠、裝機或執行期才爆」的三個坑。`code-review` 讀的是 diff，讀不到 build setting 與 plist 的交互作用 |
| [`release-assets`](./skills/engineering/release-assets/SKILL.md) | release notes、商店素材、changelog、版本號。main flow 到 `code-review` 就結束，沒有出貨那一段 |

不再使用的在 [`skills/deprecated/`](./skills/deprecated/README.md)，那份 README 寫了各自改用哪一支。

## 用之前

`/plugin update` 要手動跑，開新 session 不會自動拉；而 skill 全文是在被叫用的那一刻抓進
對話的，所以改完要開新 session 或重新叫一次才會生效。

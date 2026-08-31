# 機械守門（pre-commit / Stop hook / 注入驗證）與自製工作流 skill

不再維護 `arch-guard`、`comment-budget`、`claim-check`、`sdd-harness-init`、
`harness-audit`、`repo-onboard`，以及 `dev-loop`、`greenfield-flow`、`teammate` 的
流程部分。全部進 `skills/deprecated/`。

## 為什麼不做

**守門把模型鎖在同一個地方修。** 每個修正都是新寫的、沒人審過的 code，於是「P0/P1
處理完才算完成」加上「預設要外審」構成一個沒有不動點的遞迴——量到的是一節畫面規格
連跑五輪、約 40 分鐘，作者全程閒置。`dev-loop` 當時的修法是再加一條規則
（〈要不要再跑一次〉），那條沒有解決遞迴，只是要求先報備。

**代價落在模型能發揮的空間上。** 每道守門都要 per-repo 的門檻、詞表、conf；填不對
就靜默失效，填對了就把判斷權從模型手上收回到 grep 上。實際跑下來的結果是 code 寫不出來。

**跨機共用的守門必然帶著本機知識。** `claim-check` 的 Flutter/Dart 工具鏈 pattern
寫死在腳本本體、裝在 `~/.claude/hooks/`，conf 只能附加不能取代——`repo-onboard`
自己的 SKILL.md 開頭點名的就是這個失效，而它沒能防住同一個 marketplace 裡的另一支。

工作流那半的理由不同：`ask-matt` 的 main flow（`grill-with-docs` → `to-spec` →
`to-tickets` → `implement` → `code-review`）覆蓋同樣的路徑，而且維護成本在別人身上。

## 觸發重審的條件

守門那半：無。工作流那半：`ask-matt` 的路線在某個專案型態上明確走不通時，
補的應該是那個型態缺的那一段，不是重建整條 main flow。

## 先前的提議

- 2026-08-31：全套重審。判準是「osyuu 能不能複現 mattpocock」，能複現的一律讓位。

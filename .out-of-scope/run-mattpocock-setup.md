# ~~在本機跑 mattpocock 的 `/setup-matt-pocock-skills`~~（已推翻）

**現況：要跑。** 每個要用 `to-spec` / `to-tickets` / `triage` / `code-review` /
`wayfinder` / `ask-matt` 的 repo，先跑一次 `/setup-matt-pocock-skills`。

## 當初為什麼否決

三個 Section 各自跟當時的既有結構衝突：Section C 的 `CONTEXT.md` + `docs/adr/` 跟
`docs/design/` + `DECISIONS.md` 搶權威位置；Section A 寫一份用不到的 issue tracker
設定；它還會往 CLAUDE.md 追加一整個 `## Agent skills` 區塊。當時只想用
`grill-with-docs`，而那支對 setup 產物零引用。

## 為什麼推翻

**當初擋著的是自製工作流，而那套工作流是錯的**（見
`.out-of-scope/mechanical-guards.md`）。三個衝突現在的狀態：

- `DECISIONS.md` 是 `sdd-harness-init` 的產物，那支已 deprecated，權威衝突消失。
  `CONTEXT.md`（詞彙）、`docs/adr/`（決策）、`docs/design/`（介面契約）管的是三件
  不同的事，可以並存。
- issue tracker 設定不再是「用不到的」——main flow 走 `to-spec` / `to-tickets`
  就要它。個人專案選 local markdown（`.scratch/<feature>/`）。
- `## Agent skills` 區塊正是要的：它是那六支 skill 讀配置的入口。

## 觸發重審的條件

無。

## 先前的提議

- 2026-08-27：讀完 setup skill 全文後放棄執行，改為選擇性吸收。
- 2026-08-31：推翻。理由是自製工作流整批讓位給 `ask-matt` 的 main flow。

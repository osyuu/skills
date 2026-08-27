# 在本機跑 mattpocock 的 `/setup-matt-pocock-skills`

不跑那支 setup skill，即使要用它底下的其他 skill。

## 為什麼不做

它的三個 Section 各自跟既有結構衝突：

- **Section C** 會建立 `CONTEXT.md` + `docs/adr/` 慣例，**跟既有的 `docs/design/`
  與 `DECISIONS.md` 搶同一個權威位置**。同一個 repo 裡兩套決策記錄，比沒有更糟——
  下一個 agent 不知道該讀哪份，而兩份都會半更新。
- **Section A** 會寫一份用不到的 issue tracker 設定。
- 它還會往 CLAUDE.md 追加一整個 `## Agent skills` 區塊。

而真正想要的 `grill-with-docs` **對 setup 產物零引用**，直接打就好。明文要求先跑
setup 的只有 `wayfinder` / `code-review` / `to-tickets` / `ask-matt` / `to-spec` /
`triage` 六支，全是 issue tracker 工作流——那正是這裡不需要的那一半。

**參考它的判準，不跑它的安裝器。** ADR 0001 的 hard / soft dependency 切分、
setup skill 的提問紀律（偵測得出來的別問、先給推薦答案），都已經吸收進
`harness-audit`；`.out-of-scope/` 這個目錄本身也是。

## 觸發重審的條件

改用它的 issue tracker 工作流時（`to-tickets` / `to-spec` / `triage`）——那時 setup
是硬需求，得先解決 `docs/adr/` 與既有 `DECISIONS.md` 的權威衝突。

## 先前的提議

- 2026-08-27，本 repo 與 muster：讀完 setup skill 全文後放棄執行，改為選擇性吸收。

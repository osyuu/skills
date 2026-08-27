# 用正規表達式詞表判「這句是不是當期狀態」

`claude-md-hygiene` 的守門不會用關鍵字／正規表達式詞表去判斷 CLAUDE.md 裡的某一行
是「不變的規範」還是「會過期的當期狀態」。這條路試過，量過，出局。

## 為什麼不做

在本 repo 與 muster、mattpocock 三份真實 CLAUDE.md 上量出來：**漏抓 67%、誤報 25%。**

兩種錯**都收斂不了**，因為分界在語意不在字面：

- 「不准留 TODO」是規則。
- 「TODO: 接上重試」是狀態。

字面完全相同。誤報實例包含 muster 自己 CLAUDE.md 的「別擋 WIP」、以及 mattpocock
CLAUDE.md 裡定義 `deprecated/` 目錄的那行——兩句都是規範，都被詞表當成狀態。
放寬詞表就漏抓更多，收緊就誤報更多，沒有中間值。

**改成 PostToolUse hook**：偵測維持機械（只比對 basename，改到 `CLAUDE.md` /
`AGENTS.md` / `CLAUDE.local.md` 就開火），判斷交給**已經在場的模型**。模型看得見
「不准留 TODO」和「TODO: 接上重試」的差別，詞表看不見。

## 觸發重審的條件

若哪天需要在 **Claude Code 以外的編輯**上也開火——hook 看不到人用編輯器直接改檔，
也看不到別的工具改——詞表是唯一還能用的機制。屆時要連同上面那兩個數字一起接受，
並且明講它會誤報哪一類句子。

## 先前的提議

- 2026-08-27，本 repo 的 hook rework：詞表版做完並上了 pre-commit，量完之後整批刪除，
  換成 `.claude/hooks/claude-md-hygiene-hook.py`。

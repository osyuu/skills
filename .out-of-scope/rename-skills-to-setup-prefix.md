# 把安裝型 skill 全部改名成 `setup-xxx`

不改名。分類靠目錄（`skills/harness/` `skills/workflow/` `skills/review/`），
不靠檔名前綴。

## 為什麼不做

**`skillUsage` 的 key 是限定名，改名等於分數歸零。** 而清單預算已經飽和——分數 0 的
skill 在清單裡**只剩名字沒有描述**，偏偏它正需要描述才會被自動觸發。改名的代價是
每一支都要重新叫用一次才回得到現在的狀態。

語意上也切不乾淨：

- `claude-md-hygiene` 主體是**審查**，裝守門只是 Phase 6。
- `arch-guard` 有持續使用的 `--audit`，不只是一次性安裝。

現有名字本身就是那套共同語言（leading words 一致），改成 `setup-` 前綴反而讓
「這支在做什麼」變模糊。

**替代解法是目錄分類**：零改名、零分數重置，而且 `skillUsage` 的 key 來自 frontmatter
的 `name`，不受路徑影響（已實測確認）。

## 觸發重審的條件

若 Claude Code 改成用**路徑**當 `skillUsage` 的 key，或清單預算不再砍描述，重談。

## 先前的提議

- 2026-08-27，本 repo：提出後量了清單預算的實際行為，改走目錄分類。

<!-- sdd-harness:decision-log:start -->
## 決策記錄 + drift 防護（`docs/design/DECISIONS.md` + `hooks/pre-commit`）
- **翻案 / 新增設計決策的當下**，就 append 一行到 `docs/design/DECISIONS.md`（格式見該檔），標 `- [ ]` 與回寫目標；回寫進目標文件後改 `- [x]`（刻意延後改 `- [~]`）。**未打勾 = 未回寫的 drift**。
- **本專案回寫目標**：<TODO 按骨架填、刪不適用的>API 端點/欄位形狀 → 集中契約（如 `docs/API.md`）或就近的 design doc；資料形狀/migration → schema（`schema.sql`+`migrations/`）；跨層約束 → 本檔。
- `hooks/pre-commit`（`git config core.hooksPath hooks` 共享）在 commit 時**列出未打勾項（僅警告不擋）**；push/merge 前 drain 完。
- **fresh clone / 新 worktree 要先跑一次 `git config core.hooksPath hooks`** 才生效（此設定不進版控）。
<!-- sdd-harness:decision-log:end -->

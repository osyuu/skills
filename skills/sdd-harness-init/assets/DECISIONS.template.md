# 決策記錄（Decision Log）— <PROJECT>

> **用途**：翻案 / 新增設計決策的**當下**就 append 一行到這裡——那一刻 context 最全、動作最小、**寫進檔案即穿過 compact**。這是 spec 回寫的 staging area：之後把每筆 drain 進對應文件、把 `- [ ]` 打勾。

## 慣例
- **翻案當下就寫**，不要留到交付前憑記憶重建（那一刻最不可靠，尤其剛 compact 過）。
- 每筆格式：`- [ ] YYYY-MM-DD | <was X → now Y> | why | → 回寫目標(檔/§，或標 N/A+理由)`
- 回寫進目標文件後把 `- [ ]` 改 `- [x]`，行末補 commit ref。刻意延後的改 `- [~]` 並註明何時收。
- **未打勾的 `- [ ]` = 未回寫的 drift**。`hooks/pre-commit`（`git config core.hooksPath hooks` 共享）在 commit 時**列出未打勾項（僅警告不擋）**；push/merge 前務必 drain 完。
- **本專案回寫目標**：<TODO 按下面骨架填，刪掉不適用的、把佔位路徑換成本 repo 實際檔>
  - API 端點 / 欄位形狀決策 → **有集中契約**（如 `docs/API.md`）就回寫它；**沒有**就「各決策就近回寫到對應 design doc（`docs/design/*`）」。
  - 資料形狀 / 欄位可空性 / migration 決策 → 以 schema 為權威（如 `schema.sql` + `migrations/`）。
  - 跨層工作約束（慣例、狀態機、部署硬規） → 本專案的 CLAUDE 約束檔。
- 「察覺翻案」無法機械化——靠人/agent 自律 + 列進任務 DoD；本檔只保證「已記錄的一定被回寫」。

## 記錄

<!-- 最新的放最上面。格式範例（縮排是為了不被 pre-commit 誤判成待辦；實際條目請頂格 `- [ ]`）：
      - [ ] 2026-01-01 | 分頁形狀 扁平 → 巢狀 {data,pagination} | 統一 envelope、前端零改動 | → docs/API.md §分頁
-->

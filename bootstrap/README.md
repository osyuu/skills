# bootstrap — 新機器的全域環境

```sh
git clone https://github.com/osyuu/skills <任意路徑>   # 路徑自己挑，腳本從自己的位置推導
sh <任意路徑>/bootstrap/install.sh                  # --dry-run 可先看
```

裝好 marketplace 與 plugin 清單，把全域規範與 statusline 接成 symlink，合併 settings。
idempotent，可重跑。

## 為什麼是 symlink

`CLAUDE.md` 與 `statusline.sh` **symlink 指回這個 clone**，不複製。複製會產生第二份，
而兩份不同時**跑的是部署那份、改的是來源那份，畫面上沒有任何差別**——安裝器「已存在就
不覆蓋」正是這個坑的入口。symlink 之後 `git pull` 就是更新，改哪一邊都是同一個檔。

**代價：這個 clone 不能刪或搬。** 懸空的 symlink 等於全域規範整份消失，而且是靜默的
（Claude Code 讀不到就當作沒有）。搬過位置就重跑一次 install.sh。

**維護方向**：編輯 `~/.claude/CLAUDE.md` 就是編輯 `bootstrap/CLAUDE.md`，記得 commit，
否則別台機器 pull 不到。

## settings 的合併規則

`settings.fragment.json` 不含 `enabledPlugins` 與 `extraKnownMarketplaces`（那兩個由
plugin CLI 管）。合併時：缺的鍵補上、dict 逐鍵補、**純量衝突保留本機的值並印出來**，
不自動覆蓋——那台機器可能刻意設了別的。

**片段只放跨機通用的。** 只有某一台裝了的 skill、某個客戶或公司專屬的工具，
它們的 override 不要放進來——那些設定在別台是空轉，而且會讓人以為那些 skill 該存在。
單機限定的設定直接改那台的 `~/.claude/settings.json`，別回寫進片段。

## 這裡不涵蓋的

- **每個 repo 各跑一次 `/mattpocock-skills:setup-matt-pocock-skills`**。它產出 `docs/agents/*.md`，
  並往該 repo 的 CLAUDE.md 注入一個 `## Agent skills` 區塊。**兩種消費方式不同**：
  `code-review` 與 setup 自己**按路徑讀** `docs/agents/issue-tracker.md`（缺了會叫你先跑 setup）；
  `to-spec` / `to-tickets` / `triage` / `wayfinder` 走注入 CLAUDE.md 的那個區塊；`ask-matt` 不讀。
  個人專案的 issue tracker 選 local markdown。

- **從舊版升上來的機器要手動清一次**：早期版本 ship 過十幾支 skill，`/plugin uninstall`
  掉不再列在 `marketplace.json` 裡的那些。**不清的話它們仍然載入、description 仍佔清單預算**，
  而且沒有任何錯誤訊息——你會在一個跟新機器不同的環境上工作而不自知。
- 專案自己的 `CLAUDE.md`。
- `~/.claude/skills/` 底下的本機 skill——那些不跟 plugin 走，要自己搬。

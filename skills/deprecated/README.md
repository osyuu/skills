# deprecated

不再使用，不進 `marketplace.json`。留著是為了 git 以外還查得到內容，不要從這裡叫用。

| 這裡的 | 改用 | |
|---|---|---|
| dev-loop | `implement`（＋ `tdd`、`code-review`） | 執行器降檔與交付前 squash 這兩塊 implement 沒有，已搬進 `~/.claude/CLAUDE.md` |
| greenfield-flow | `wayfinder` | 它的 fog of war ／ decision ticket 覆蓋同一個問題且更細 |
| handoff | `handoff`（mattpocock 那支） | 真正的理由是跨 session 記憶已經是 Claude Code 內建的；兩支功能其實不同 |
| skill-authoring | `writing-for-agents` | marketplace 登錄流程壓進 CLAUDE.md |
| claude-md-hygiene | `writing-for-agents` | 它的 description 明寫涵蓋 AGENTS.md / CLAUDE.md |
| teammate | `code-review` | 背景 agent 的操作面（`idle` ≠ 已交付、worktree 污染）沒有替代品，已搬進 `~/.claude/CLAUDE.md` |
| repo-onboard | `setup-matt-pocock-skills` | 技術棧探測的用途是填守門的 conf，守門沒了目的也沒了 |

以下沒有替代品，是刻意不再做的：arch-guard、comment-budget、claim-check、
sdd-harness-init、harness-audit。理由見 `.out-of-scope/mechanical-guards.md`。

**注意界線**：問題不在 hook 本身。mattpocock 的 `misc/setup-pre-commit` 與
`misc/git-guardrails-claude-code` 也裝 hook，但它們接的是現成工具（prettier、typecheck、
test）或擋固定的危險指令——不需要 per-repo 門檻，失效時會報錯。這裡收掉的是**自製判斷
邏輯 + 每個 repo 都要調校的門檻**，那種失效是靜默的。

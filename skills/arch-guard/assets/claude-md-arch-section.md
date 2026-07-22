<!-- arch-guard: adapt this into the project CLAUDE.md (fill the layer names /
     diagram / table to match arch-layers.conf, then delete this comment). The
     hook enforces it deterministically; this section tells humans+agents the
     rule so new code lands right the first time. -->

## 架構鐵律：單向分層（依賴只准往下，勿逆向/橫向）

**分層 + 依賴方向（箭頭＝允許 import 的方向，只准往下）：**
```
  <TOP>  ─▶  <...>  ─▶  <...>  ─▶  <BOTTOM>
  （下層是葉子，誰都不 import 上層；上層可跨過中層直接依賴更下層）
```
| 層 | 放什麼 | 可依賴 | 禁止 |
|---|---|---|---|
| `<TOP>/` | per-unit 進入點（如 feature 的 View+VM） | 所有下層 | **同層 sibling 互 import**（共享請下沉） |
| `<MID>/` | 跨單元共享（領域感知 widget / app 級 state） | 更下層 | 依賴 `<TOP>` |
| `<...>/` | 領域資料（model / source / repository） | 最底層 | 依賴上面任何層 |
| `<BOTTOM>/` | **領域無關**技術地基（network/storage/util/通用 widget） | 只外部 package | 依賴任何內部層（**葉子**） |

- **鐵律：依賴只准往下。** 往上依賴、同層 sibling 互 import 一律禁止；發現既有的就是**待清違規**（起因通常是「該下沉的共享物留在上層，或該領域無關的東西塞進更上層」）。
- **判準**：一個東西被 **≥2 個上層單元消費 → 下沉**；領域**無關**沉到最底層、領域**感知**沉到中間共享層。單一 owner 的東西留在它自己的單元。
- 由 `hooks/pre-commit`（arch-guard）在 commit 時**列出違規（warn，不擋）**；規則見 `hooks/arch-layers.conf`。**fresh clone / 新 worktree 要跑一次 `git config core.hooksPath hooks`** 才生效。

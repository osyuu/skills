# 安裝器佈線失敗時回 `exit 3`

四支安裝器（`arch-guard` / `comment-budget` / `sdd-harness-init` / `claude-md-hygiene`）
的 `install.sh` 在「檔案寫好了但 git 沒接上」時，一律 `exit 0` 加醒目的
`⚠ 尚未佈線` 訊息，不用非零 exit code。

## 為什麼不做

一度為了「讓 agent 讀得出沒裝成」而改成 `exit 3`。問題出在**組合使用**：

`harness-audit` 的用法是一次裝好幾道守門。上層腳本只要有 `set -e`，第一道遇到
husky 佔用 `core.hooksPath`、或跑在 worktree 裡，整批就中止——**後面幾道連試都沒試**，
而使用者看到的是一個 exit code，不是「哪幾道裝了、哪幾道沒裝」。

更根本的是**不一致本身就是坑**：四支安裝器裡只有一支回非零，另外三支回 0。
呼叫端要嘛全部特判，要嘛（實際會發生的）誰都沒特判。

## 觸發重審的條件

若四支同時改成非零、且 `harness-audit` 的安裝步驟改成逐道獨立呼叫（不吃 `set -e`
的整批中止），可以重談。單獨改一支不行。

## 先前的提議

- 2026-08-27，本 repo：改成 `exit 3` 後在 `harness-audit` 的實測裡撞到批次中止，改回。

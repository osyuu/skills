#!/bin/sh
# 交接前的機械盤點——這些不該靠記憶。
#
# 踩過：收尾時憑印象數「關了幾個 agent」，漏掉一個閒置了好幾小時、最後由使用者手動殺掉。
# 盤點要「列出來」而不是「想一想」。

set -u
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "工作區"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    br=$(git branch --show-current 2>/dev/null)
    printf '  分支 %s @ %s\n' "$br" "$(git log -1 --format='%h %s' 2>/dev/null | cut -c1-56)"
    dirty=$(git status --short 2>/dev/null)
    if [ -n "$dirty" ]; then
        printf '  \033[33m未 commit：\033[0m\n'; printf '%s\n' "$dirty" | sed 's/^/    /'
    else
        printf '  未 commit：無\n'
    fi
    up=$(git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null || true)
    if [ -n "$up" ]; then
        n=$(git rev-list --count "$up".."$br" 2>/dev/null || echo '?')
        [ "$n" = "0" ] && printf '  未 push：無\n' || printf '  \033[33m未 push：%s 個 commit（%s）\033[0m\n' "$n" "$up"
    else
        printf '  \033[33m未 push：這個分支沒有 upstream\033[0m\n'
    fi
    # 臨時 worktree 很容易忘記——它不在 git status 裡，但會留在磁碟上。
    wt=$(git worktree list 2>/dev/null | tail -n +2)
    [ -n "$wt" ] && { printf '  \033[33m額外的 worktree：\033[0m\n'; printf '%s\n' "$wt" | sed 's/^/    /'; }
else
    printf '  （不在 git repo 內）\n'
fi

say "還活著的東西"
# 背景 shell job：只看得到本 shell 的，所以主要靠下面那句提醒。
jobs 2>/dev/null | sed 's/^/  /' || true
printf '  \033[33m→ agent 與背景工作要「列出來」再確認，不要憑印象數。\033[0m\n'
printf '     漏掉的 agent 會閒置到使用者手動殺掉，而它閒置時看起來跟關掉一樣。\n'

say "注入過的故障還原了嗎"
printf '  \033[33m→ 若這個 session 注入過故障：還原之後有沒有「重建」再跑一次？\033[0m\n'
printf '     只還原不重建，測試跑的是舊 binary——綠或紅都不代表現在的程式碼。\n'

say "沒驗的東西"
printf '  \033[33m→ 有哪些是「宣稱完成但沒實際驗過」？（實機、UI、需要人看的）\033[0m\n'
printf '     不寫進交接的話，下一個 session 會當成驗過了。\n'

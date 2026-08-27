# review

**審既有 code 的 skill**：拿一份檢查表對著 diff / 檔案 / 分支逐條看。

跟 `harness/` 的差別在誰在看：這裡是**模型在讀**，harness 是**機器在跑**。
檢查表管得了語意（「這個 widget 每次 rebuild 都重建 controller」），
機械檢查管不了；反過來，檢查表不會在你 commit 的時候自己開火。

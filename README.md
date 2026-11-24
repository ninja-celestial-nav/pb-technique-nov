# The Paddle Review · Technique Edition (技術特輯)

Coach Ninja (NinjaPB) 的北美匹克球八大核心技術雜誌版指南。單檔 `index.html`，中文／英文依瀏覽器語言自動切換（`?lang=en` 或 `?lang=zh` 可強制指定）。

A single-file, bilingual (Traditional Chinese / English) magazine page on eight core pickleball techniques.

- 靜態網站，無需建置；Vercel 直接部署根目錄。
- 頁面導覽：`#1`–`#11`、鍵盤 ← →、右上「目錄」。
- 封面與 Coach's Corner 的背景效果由 WebGPU（[vgpu](https://github.com/vercel-labs/vgpu)）繪製，屬於選用的漸進增強：沒有 WebGPU 或啟用「減少動態」時會自動退回靜態頁面。原始碼在 `src/`（`fx.wgsl` shader 與 `fx.mjs` 進入點；`index.html` 內嵌的是打包後的版本）。

Coach Ninja 為 Six Zero 官方品牌推廣大使；頁面上的折扣碼與連結為其推廣用途。

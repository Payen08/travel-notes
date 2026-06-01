# Travel Notes

旅行记账 PWA，支持行程、支出、预算、AA 分账、Supabase 邮箱密码登录与云同步。

## GitHub Pages

入口文件是 `index.html`，会跳转到 `记账2.html`。

## Supabase

1. 在 Supabase SQL Editor 运行 `supabase-schema.sql`。
2. 按 `SUPABASE_SETUP.md` 配置 Auth Redirect URLs。
3. 在 `记账2.html` 顶部的 `SUPABASE_CONFIG` 填写 Project URL 和 anon/public key。

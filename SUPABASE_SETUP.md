# Supabase Setup

1. Open your Supabase project.
2. Go to SQL Editor and run `supabase-schema.sql`.
3. In Authentication > URL Configuration, set Site URL to your GitHub Pages URL.
4. Add these Redirect URLs:
   - `http://127.0.0.1:8000/auth-callback.html`
   - `http://localhost:8000/auth-callback.html`
   - `https://YOUR_GITHUB_USERNAME.github.io/YOUR_REPO/auth-callback.html`
5. In Authentication > Providers > Email, enable Email + Password.
6. Turn off Confirm email if you want registration to work without waiting for email.
   - This is recommended for this static GitHub Pages version.
   - If Confirm email stays on, Supabase must successfully send the confirmation email before login works.
7. In `记账2.html`, fill `SUPABASE_CONFIG.url` and `SUPABASE_CONFIG.anonKey`.
8. Deploy the folder to GitHub Pages.

After deployment:

- Open the app and go to 旅程设置.
- Register or log in with email + password in 账号与同步.
- After login, click 创建/上传 to create the cloud trip.
- Share the displayed 邀请码 with teammates.
- Teammates log in, enter the invite code, and join the same trip.

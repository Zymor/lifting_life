# Supabase Registration & Email Verification — Setup

The app now performs **real** Supabase Auth registration. Nothing is simulated:
no client-generated OTPs, no local "email sent" toasts, no demo accounts.

## 1. What the code does

| Action | Code path | Supabase call |
| --- | --- | --- |
| CREATE ACCOUNT | `DataService.registerWithEmail` | `auth.signUp(email, password, data: {username, display_name})` |
| Verification screen | `DataService.verifySignupCode` | `auth.verifyOTP(type: OtpType.email, email, token)` |
| Resend code | `DataService.resendSignupCode` | `auth.resend(type: OtpType.signup, email)` |
| Log in | `DataService.signInWithEmail` | `auth.signInWithPassword(email, password)` |
| Session restore | `DataService.tryRestorePersistedSession` | `auth.currentSession` / `refreshSession()` |
| Forgot password | `DataService.sendPasswordResetCode` / `resetPasswordWithCode` | `auth.resetPasswordForEmail` / `verifyOTP(type: OtpType.recovery)` + `updateUser` |

OTP lifetime, attempt limits, resend throttling and email delivery are owned by
Supabase. The Flutter client never sees the code it emailed.

The username is stored in `auth.users.user_metadata` (`username`,
`display_name`) so it survives verification and session restore.

## 2. Required app configuration

The app reads compile-time defines (never commit secrets):

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<public-anon-key>
```

For release builds add the same flags to `flutter build apk|appbundle|ipa|windows`.

**Only the public anon key belongs in the app.** `SupabaseConfig` throws if a
service-role key is supplied, and the client never embeds SMTP/Resend secrets.

Without these values the register screen shows:
`Registration is temporarily unavailable. Please try again later.`
It never fakes success.

## 3. Supabase dashboard settings

### 3.1 Enable email signups + confirmation

Authentication → Providers → **Email**:

- Enable Email provider: **ON**
- **Confirm email: ON**
- Secure email change: ON (recommended)

Authentication → Settings:

- Email OTP expiration: 600 seconds (10 minutes) or your preferred value
- Minimum password length: 8+ (matches client validation)
- Enable leaked-password protection (recommended)

### 3.2 Confirmation email template (must contain `{{ .Token }}`)

Authentication → Emails → **Confirm signup**:

```html
<h2>Verify your Lifting Life account</h2>
<p>Enter this 6-digit code in the app:</p>
<p style="font-size:28px;font-weight:800;letter-spacing:6px">{{ .Token }}</p>
<p>This code expires in 10 minutes. If you did not create this account,
you can safely ignore this email.</p>
```

Rules:

- Use `{{ .Token }}` — **not** `{{ .ConfirmationURL }}` and never a fixed code.
- The same template is used by the "Resend Code" button.
- Do not put the OTP in the subject line.

Recovery uses the **Reset password** template; add `{{ .Token }}` there too if
you want the in-app 6-digit recovery flow instead of a magic link.

### 3.3 Production SMTP

Authentication → Settings → **SMTP Settings** (or Project Settings → Auth):

| Field | Example |
| --- | --- |
| Host | `smtp.resend.com` / `smtp.sendgrid.net` / SES endpoint |
| Port | `465` (SSL) or `587` (STARTTLS) |
| Username | provider username (`resend`, `apikey`, …) |
| Password | provider SMTP key (stored only in Supabase) |
| Sender email | `auth@your-verified-domain.com` |
| Sender name | `Lifting Life` |

Verify the sending domain (SPF + DKIM) with the provider first. Supabase's
default SMTP has strict hourly limits and is not suitable for production.

### 3.4 Rate limits

Authentication → Rate Limits: keep the defaults unless you have a reason to
change them. The app maps `429` / `over_email_send_rate_limit` to
`Too many attempts. Please try again later.`

## 4. Optional: username uniqueness (database change for Agent 1)

The client checks usernames it knows about, but the server must be the source of
truth. To reject duplicates at signup, add to the Supabase SQL editor:

```sql
-- 1. Profiles table (one row per auth user)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null,
  display_name text,
  email_verified boolean not null default false,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now()
);

-- 2. Case-insensitive uniqueness
create unique index if not exists profiles_username_lower_idx
  on public.profiles (lower(username));

-- 3. Create the profile from signup metadata
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Row Level Security
alter table public.profiles enable row level security;

create policy "profiles are readable by everyone"
  on public.profiles for select using (true);

create policy "users update their own profile"
  on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);
```

> A duplicate `username` then fails the insert during signup. Surface it in the
> client as "That username is already taken. Please choose another.".

## 5. Manual test checklist

1. Tap **CREATE ACCOUNT** with invalid data → inline field errors, no request.
2. Valid data → button shows `CREATING ACCOUNT...`, request reaches Supabase.
3. A real email arrives at the entered address with a 6-digit code.
4. Enter the code → `Verify Email` shows `VERIFYING...` → onboarding opens.
5. Wrong code → "Invalid verification code. Please try again."
6. Resend before 60 s → disabled; after → Supabase sends a new code.
7. Kill and relaunch the app → session restores straight to the app.
8. Airplane mode → "Unable to connect. Please try again." and the button
   returns to `CREATE ACCOUNT`.
9. Double-tap the button → only one signup request is sent.

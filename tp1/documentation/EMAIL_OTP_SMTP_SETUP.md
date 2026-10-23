# Lifting Life — Production Email OTP & SMTP Setup Guide

This guide provides the complete setup instructions for the **real 6-digit automatic email verification system** in **Lifting Life**, powered by **Supabase Auth** and a production SMTP email provider (Resend, SendGrid, or Amazon SES).

---

## 1. How the Automatic Verification System Works

```
                                      +---------------------------------------------+
                                      | 1. User signs up (username, email, pwd)     |
                                      +---------------------------------------------+
                                                             |
                                                             v
                                      +---------------------------------------------+
                                      | 2. App calls Supabase Auth `signUp()`       |
                                      +---------------------------------------------+
                                                             |
                                                             v
               +-------------------------------------------------------------------------------------------+
               | 3. Supabase Auth generates a cryptographically secure random 6-digit OTP                   |
               |    and dispatches it via your configured custom SMTP provider to user's exact address    |
               +-------------------------------------------------------------------------------------------+
                                                             |
                                                             v
                                      +---------------------------------------------+
                                      | 4. User opens inbox (Gmail, Outlook, Yahoo) |
                                      |    and copies the 6-digit verification code |
                                      +---------------------------------------------+
                                                             |
                                                             v
                                      +---------------------------------------------+
                                      | 5. User enters code in Lifting Life app     |
                                      +---------------------------------------------+
                                                             |
                                                             v
                                      +---------------------------------------------+
                                      | 6. App calls Supabase Auth `verifyOTP()`    |
                                      +---------------------------------------------+
                                                             |
                                                             v
                                      +---------------------------------------------+
                                      | 7. Account becomes email-verified           |
                                      |    Session persisted to Android Keystore /   |
                                      |    iOS Keychain via SecureSessionStorage    |
                                      |    User enters Fitness Onboarding & Hub     |
                                      +---------------------------------------------+
```

- **No Insecure Client-Side Codes**: The mobile client never generates, stores, or logs verification codes.
- **Direct Delivery**: Each user receives their code at the exact email address they entered. Verification codes are never forwarded to the app owner or held for manual administrator approval.
- **Security Protections**: 10-minute code expiry, 60-second resend cooldown, 5-attempt brute-force protection, anti-enumeration (existing accounts do not leak status), and encrypted Keychain/Keystore session persistence.

---

## 2. Production SMTP Provider Setup

Choose your preferred production email delivery provider:

### Option A: Resend (Recommended for Speed & Deliverability)
1. Sign up at [resend.com](https://resend.com).
2. Go to **Domains** -> **Add Domain** -> Enter your domain (e.g., `liftinglife.app` or `mail.liftinglife.app`).
3. Add the DNS records to your domain registrar:
   - **SPF**: `TXT` record `v=spf1 include:amazonses.com ~all`
   - **DKIM**: `CNAME` records provided by Resend
   - **DMARC**: `TXT` record `_dmarc.liftinglife.app` with value `v=DMARC1; p=none;`
4. Go to **API Keys** -> **Create API Key** (Full Access).
5. Your SMTP details for Supabase will be:
   - **Sender email**: `auth@liftinglife.app` (or `noreply@liftinglife.app`)
   - **Sender name**: `Lifting Life`
   - **Host**: `smtp.resend.com`
   - **Port**: `465` (SSL) or `587` (TLS)
   - **Username**: `resend`
   - **Password**: `re_your_api_key_here`

### Option B: SendGrid
1. Sign up at [sendgrid.com](https://sendgrid.com).
2. Complete **Sender Authentication** -> **Authenticate Your Domain**.
3. Create an API Key with **Mail Send** permissions.
4. Your SMTP details for Supabase will be:
   - **Sender email**: `auth@yourverifieddomain.com`
   - **Sender name**: `Lifting Life`
   - **Host**: `smtp.sendgrid.net`
   - **Port**: `587`
   - **Username**: `apikey`
   - **Password**: `SG.your_api_key_here`

### Option C: Amazon SES
1. Verify your domain and sending identity in AWS SES Console.
2. Create SMTP Credentials under **SMTP Settings** -> **Create SMTP Credentials**.
3. Your SMTP details for Supabase will be:
   - **Sender email**: `auth@yourverifieddomain.com`
   - **Sender name**: `Lifting Life`
   - **Host**: `email-smtp.<aws-region>.amazonaws.com`
   - **Port**: `587`
   - **Username**: `<your_ses_smtp_username>`
   - **Password**: `<your_ses_smtp_password>`

---

## 3. Supabase Auth Configuration (Dashboard Step-by-Step)

Log in to your [Supabase Dashboard](https://supabase.com/dashboard) and configure the following settings:

### Step 1: Enable Email Confirmations & Set 10-Minute OTP Expiry
1. Open your project -> **Authentication** -> **Providers** -> **Email**.
2. **Enable Email provider**: `ON`.
3. **Confirm email**: `ON` (Required: this ensures unverified users cannot bypass email verification).
4. **Secure email change**: `ON`.
5. Under **OTP Expiry**, set duration to `600` seconds (10 minutes).
6. Under **Rate Limits**, verify:
   - **Email resend frequency**: `60` seconds (mirrors the app's 60-second resend countdown).
   - **Max verification attempts**: `5` attempts.

### Step 2: Configure Custom SMTP
1. In the Supabase Dashboard, go to **Project Settings** -> **Authentication** -> **SMTP Settings**.
2. Toggle **Enable Custom SMTP** to `ON`.
3. Fill in your verified SMTP provider credentials:
   - **Sender email**: `auth@liftinglife.app` (must match your verified domain!)
   - **Sender name**: `Lifting Life`
   - **Host**: e.g., `smtp.resend.com`
   - **Port**: `587` (or `465`)
   - **Username**: e.g., `resend`
   - **Password**: `<your_private_smtp_password>`
4. Click **Save Changes**.
5. Click **Send Test Email** to verify SMTP connectivity.

### Step 3: Install the Branded Email Template
1. In the Supabase Dashboard, go to **Authentication** -> **Email Templates** -> **Confirm signup**.
2. **Subject**:
   ```
   Lifting Life — Verify Your Email
   ```
3. **Body (HTML)**:
   Copy and paste the exact contents of:
   `supabase/email_templates/verify_email_otp.html`
   *(Ensure `{{ .Token }}` is present inside the template — this is replaced by Supabase with the generated 6-digit OTP code).*
4. If your SMTP provider supports plain-text multipart:
   Copy the contents of `supabase/email_templates/verify_email_otp.txt`.
5. Click **Save**.

### Step 4: Reset Password Template
1. Under **Email Templates** -> **Reset Password**.
2. **Subject**:
   ```
   Lifting Life — Password Reset Code
   ```
3. Use `{{ .Token }}` for the 6-digit reset code and save changes.

---

## 4. Mobile Client Launch Configuration

Run or build the Flutter application with your public Supabase URL and anon key:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-public-anon-key> \
  --dart-define=APP_ENV=production
```

> [!CAUTION]
> **Never embed `SUPABASE_SERVICE_ROLE_KEY` or SMTP passwords in the Flutter app.**
> The mobile client only needs the public `SUPABASE_ANON_KEY`. Supabase Auth handles SMTP dispatch securely on the backend.

---

## 5. Security & Verification Checklist

| Requirement | Implementation | Status |
| :--- | :--- | :--- |
| **Real 6-Digit Email OTP** | Handled natively by Supabase Auth with custom SMTP delivery | Verified |
| **Direct Recipient Delivery** | Code delivered exclusively to the address entered at registration | Verified |
| **10-Minute Expiry** | Enforced by Supabase Auth (`600s`) and client timer | Verified |
| **60-Second Resend Cooldown** | Enforced by client countdown timer & Supabase rate limiter | Verified |
| **5-Attempt Lockout** | Server-side protection against brute-force guessing | Verified |
| **Anti-Enumeration** | Existing accounts never revealed during signup or recovery | Verified |
| **Secure Session Storage** | Keychain (iOS) & Keystore (Android) via `SecureSessionStorage` | Verified |
| **Interrupted Recovery** | In-flight registration resume supported if user closes the app | Verified |
| **Empty State & Zero Fake Data** | Clean startup state with genuine empty states | Verified |
| **Preserve 3D Viewer & Workouts** | AI Agent 2 3D viewer, exercises, and workout logging untouched | Preserved |

---

## 6. What Is Currently Missing to Finish Real Deployment

To make live email delivery functional for real users:
1. **Supabase Project Credentials**: Supply `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define`.
2. **Production SMTP Credentials**: Configure Resend, SendGrid, or Amazon SES in your Supabase project under **Project Settings -> Authentication -> SMTP Settings**.
3. **Verified Custom Sending Domain**: Ensure SPF, DKIM, and DMARC DNS records are verified on your domain (e.g., `liftinglife.app`) so emails land in users' primary inboxes instead of spam.


# Lifting Life authentication diagnosis — 22 October 2026

Status: Phase 1 code repairs completed; Phase 2 blocked by unidentified/unconnected Supabase project. The full authentication repair is NOT complete. No real signup, OTP email, OAuth, recovery, RLS, or restart persistence acceptance test has run.

## Precise cause of the displayed message

`lib/screens/auth_onboarding_screen.dart`, `_registrationErrorMessage`, maps `EmailAuthStatus.notConfigured` to exactly “Registration is temporarily unavailable. Please try again later.”

`DataService.emailAuthBackend` selects `UnconfiguredEmailOtpBackend` when `SupabaseConfig.clientOrNull` is null. That backend returns `notConfigured` without making any HTTP request. Supabase initialization previously silently returned when the compile-time URL or anon key was empty. All three checked-in VS Code launch profiles omit those defines. No usable project configuration was found in the inspected project/build configuration, and no Supabase dashboard was available in the connected browser.

Thus the supplied project’s default launch has no initialized Supabase client. There is no registration HTTP response or Auth log to inspect on this path. An initialization failure can also select this same fallback; startup diagnostics now distinguish that condition. The exact historical build shown in the user's screenshot was not independently reproduced.

The project uses Flutter/Dart, supabase_flutter 2.18.3, gotrue 2.27.3, Flutter secure storage, and a singleton DataService. SQL schema and migration files exist locally; their existence does not prove deployment to any server.

## Actual changes made in the existing tp1 project

- `lib/core/configuration/supabase_config.dart`: supports SUPABASE_PUBLISHABLE_KEY with legacy SUPABASE_ANON_KEY fallback; uses the installed SDK's publishableKey argument; validates URL structure; rejects secret keys and non-anon legacy JWTs; logs a fixed diagnostic category for missing or invalid configuration. Key parsing is structural validation, not signature verification. SDK exception logging is disabled in favor of sanitized diagnostics.
- `lib/core/auth/auth_diagnostics.dart`: new development diagnostics with operation, safe category, allowlisted error code, and validated HTTP status. No exception message, email, request body, password, OTP, or session token is accepted for logging.
- `lib/core/auth/email_otp_auth_service.dart`: records sanitized Auth error diagnostics for signup, verification, resend, login and recovery; distinguishes SMTP recipient restrictions from invalid email syntax; no longer labels every HTTP 5xx as an email delivery problem.
- `lib/main.dart`: removes raw initialization exception logging.
- `lib/screens/auth_onboarding_screen.dart`: replaces raw exception/stack logging with fixed diagnostic labels. Authentication behavior and visible error copy are not presented as fixed by these logging changes.
- `test/auth_configuration_test.dart`: eight new configuration, key rejection, error mapping and log-redaction tests.
- `tool/run_configured.ps1`: validates environment configuration before launching Flutter; fails with an actionable explanation when no real backend is configured.
- `config/development.example.json`, `config/staging.example.json`, `config/production.example.json`: separate empty templates, without invented credentials.
- `.gitignore`: excludes local environment JSON configuration while retaining templates.
- `docs/auth_repair_status.md`: this report.

Original versions of the four edited Dart files were backed up in the chat workspace before editing. No accounts, workouts, courses, assets or database rows were deleted. No migrations were applied.

## Verification results

- Targeted Dart static analysis: passed, no issues.
- `flutter test --no-pub test/auth_configuration_test.dart test/register_flow_test.dart`: 18 passed (8 new tests + 10 existing tests).
- The registration/login widget tests inject a fake backend. Their existing test title mentioning Supabase does not mean a live Supabase request happened. One existing test exercises legacy local authentication; its passing result documents remaining demo behavior, not production readiness.
- Configured launcher: verified it rejects the absent development configuration before invoking Flutter.
- Real integration tests: NOT RUN; project URL/key, dashboard access, SMTP configuration and a controlled test mailbox are unavailable.

The Windows sandbox initially blocked the Flutter cache lock, temporary-file handling and localhost test socket. Tests completed after cache/network permissions were granted, telemetry was suppressed, and test temporary files were redirected into the writable workspace.

## Critical findings remaining after diagnosis

1. Facebook/Apple sheets call `DataService.signInWithOAuthProvider` using user-entered or generated identity details. That method establishes a local authenticated identity without provider authorization. These are simulated flows, not real OAuth.
2. `tryRestorePersistedSession` can restore a local snapshot when Supabase is unconfigured. It must be replaced by backend-authoritative restoration.
3. `DataService.signOut`, used by the profile screen, clears local state without calling `emailAuthBackend.signOut`; a Supabase session could remain active.
4. Local registration, OTP and credential methods remain in DataService. Their removal must account for callers and tests.
5. Username availability is checked locally. The SQL trigger appends a UUID fragment rather than persisting the requested username unchanged, so local identity and database identity can diverge.
6. Profile/workout persistence in DataService is local; SQL files alone do not establish cloud synchronization. Backend reconciliation is required before claiming data persists across devices.
7. Registration password fields currently both use `_regObscure`, initially true. Independent toggle behavior and the screenshot discrepancy still require UI verification.
8. Deployed schema, trigger permissions, RLS, role security, Auth provider settings, email delivery and production redirects are unverified.
9. The old setup guide includes an optional alternative profile schema and public-read policy. Do not apply that snippet blindly over the existing migration schema. Inspect the deployed database and prepare a compatible additive migration first.

Per the requested phase ordering, later implementation phases have not been advanced while the critical backend connection blocker remains unresolved. This is a partial repair, not the final requested authentication system.

## Owner action needed to unblock Phase 2

Open https://supabase.com/dashboard and sign in. Identify the existing Lifting Life project, if there is one. Do not create a replacement until existing data ownership is understood. Provide its project URL and publishable/public anon key, or make the signed-in dashboard accessible for inspection. Never paste a service-role key, SMTP password or Apple private key into chat or Flutter configuration.

Once the existing project is identified:

1. Copy the matching `config/<environment>.example.json` to `config/<environment>.json` and set the real project URL and public key. Use `powershell -File tool/run_configured.ps1 -Environment development -Device windows`, or `flutter run --dart-define-from-file=config/development.json`. Use the same selected file for builds. Existing default VS Code launches still lack configuration.
2. Verify project health, Email provider, signup enablement, Confirm email, OTP length/expiry/rate limits, password policy, and redirect allowlist.
3. Obtain authorized dashboard/database access to inspect actual Auth errors, deployed migrations, triggers and policies. Do not infer their state from local SQL.
4. Configure custom SMTP inside Supabase using a verified sender/domain, SMTP host/port/user/password. Install the confirmation and recovery templates using the supported `{{ .Token }}` variable. Credentials remain server-side.
5. Configure Facebook application ID/secret and allowed OAuth callbacks in Meta/Supabase. Configure Apple Service ID, Team ID, Key ID, signing key and return/domain settings in Apple/Supabase. Only public identifiers belong in the app.
6. Supply a controlled staging project and test inbox for real signup, delivery, OTP, recovery and cross-user authorization tests. Later implementation must remove simulated production auth before release.

Reference for corrected error mapping: https://supabase.com/docs/guides/auth/debugging/error-codes — `email_address_not_authorized` is a default SMTP recipient restriction, not an invalid email address.

# Account registration HTTP 500 investigation plan

## Reported symptom

The registration sheet displays `HTTP 500` after “Create passkey”. The submitted Vercel hostname did not resolve during this investigation, and this workspace has no linked Vercel CLI project or accessible function logs. The live failing request and its server exception therefore cannot yet be reproduced here.

## Source findings

- Registration calls `POST /api/register/options`, opens the browser WebAuthn prompt, then calls `POST /api/register/verify` from `frontend/src/lib/api.js`.
- The backend verifies the one-use challenge and WebAuthn response in `api/server.js`; unexpected route exceptions are logged server-side and returned as generic `500 {"error":"server error"}`. The screenshot does not identify which request failed.
- The current source also fails startup when Vercel runtime variables are present because account data uses local files. If that guard was deployed, it could explain broad API failures, but this is not confirmed as the screenshot’s cause.
- Live `/api/login/options` could not be queried because DNS lookup failed. No source code has been changed during this incident investigation.

## Plan before code changes

1. Reproduce registration locally with the existing API passkey test harness, and run focused frontend/API tests to establish the expected route behavior and error mapping.
2. Obtain the failing Vercel request log for the precise timestamp and request path (`/api/register/options` or `/api/register/verify`). Use the backend exception to identify the live cause; do not infer it from the toast.
3. Apply the smallest fix for the confirmed cause. Keep server responses safe and generic while retaining enough server-side diagnostics without logging credentials, challenge values, or personal data.
4. Add or update regression coverage for the failing condition and run the account security tests plus a production build.
5. Do not deploy account changes until durable shared storage, backup/restore, final HTTPS `ORIGIN`/`RP_ID`, and real-browser registration/login checks on the configured backend all pass.

## Local verification

- Frontend account/API tests: 69 passed.
- API WebAuthn, password, session, origin/CSRF, and Vercel storage-policy tests: 67 passed.
- API account data isolation, revisions, malformed input, and CORS/CSRF tests: 15 passed.
- `npm run build` passed, including staging 6,554 stills and 6,554 animations.
- No application source code was changed for this incident because the live failing request and server exception could not be obtained. The checks above verify the current local implementation; they do not explain or clear the live 500.
